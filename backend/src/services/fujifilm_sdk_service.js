const EventEmitter = require('events');
const logger = require('../utils/logger');

class FujifilmSDKService extends EventEmitter {
  constructor() {
    super();
    this.isInitialized = false;
    this.connectedCamera = null;
    this.cameraList = [];
    this.liveViewSession = null;
    
    // Error handling and reconnection
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 3;
    this.reconnectDelay = 2000;
    this.connectionWatchdog = null;
    this.lastHeartbeat = null;

    // Fujifilm-specific property mappings (via wireless communication)
    this.PROPERTY_MAPPINGS = {
      ISO: 'iso_speed',
      APERTURE: 'aperture_value',
      SHUTTER_SPEED: 'shutter_speed',
      WHITE_BALANCE: 'white_balance',
      DRIVE_MODE: 'drive_mode',
      FOCUS_MODE: 'focus_mode',
      EXPOSURE_MODE: 'exposure_mode',
      FILM_SIMULATION: 'film_simulation', // Fujifilm exclusive
      GRAIN_EFFECT: 'grain_effect', // Fujifilm exclusive
      COLOR_CHROME: 'color_chrome_effect', // Fujifilm exclusive
      FLASH_MODE: 'flash_mode',
      METERING_MODE: 'metering_mode'
    };

    // Fujifilm-specific capability values
    this.CAPABILITY_VALUES = {
      ISO: ['AUTO', '80', '100', '125', '160', '200', '250', '320', '400', '500', 
            '640', '800', '1000', '1250', '1600', '2000', '2500', '3200', '4000', 
            '5000', '6400', '8000', '10000', '12800', '25600', '51200'],
      
      APERTURE: ['F1.0', 'F1.4', 'F1.8', 'F2.0', 'F2.8', 'F3.2', 'F3.5', 'F4.0', 
                 'F4.5', 'F5.0', 'F5.6', 'F6.3', 'F7.1', 'F8.0', 'F9.0', 'F10', 'F11', 
                 'F13', 'F14', 'F16', 'F18', 'F20', 'F22'],
      
      SHUTTER_SPEED: ['AUTO', '30s', '25s', '20s', '15s', '13s', '10s', '8s', '6s', '5s', 
                      '4s', '3.2s', '2.5s', '2s', '1.6s', '1.3s', '1s', '1/1.3', '1/1.6', 
                      '1/2', '1/2.5', '1/3', '1/4', '1/5', '1/6', '1/8', '1/10', '1/13', 
                      '1/15', '1/20', '1/25', '1/30', '1/40', '1/50', '1/60', '1/80', 
                      '1/100', '1/125', '1/160', '1/200', '1/250', '1/320', '1/400', 
                      '1/500', '1/640', '1/800', '1/1000', '1/1250', '1/1600', '1/2000', 
                      '1/2500', '1/3200', '1/4000', '1/8000'],
      
      WHITE_BALANCE: ['AUTO', 'Daylight', 'Shade', 'Fluorescent1', 'Fluorescent2', 
                      'Fluorescent3', 'Incandescent', 'Underwater', 'Custom1', 'Custom2', 'Custom3'],
      
      FOCUS_MODE: ['AF-S', 'AF-C', 'Manual'],
      
      EXPOSURE_MODE: ['Program', 'Aperture Priority', 'Shutter Priority', 'Manual'],
      
      // Fujifilm's famous film simulation modes
      FILM_SIMULATION: ['Provia/Standard', 'Velvia/Vivid', 'Astia/Soft', 'Classic Chrome', 
                        'Pro Neg. Hi', 'Pro Neg. Std', 'Classic Neg.', 'Eterna/Cinema', 
                        'Eterna Bleach Bypass', 'Acros', 'Acros+Ye Filter', 'Acros+R Filter', 
                        'Acros+G Filter', 'Monochrome', 'Monochrome+Ye Filter', 'Monochrome+R Filter', 
                        'Monochrome+G Filter', 'Sepia'],
      
      GRAIN_EFFECT: ['Off', 'Weak', 'Strong'],
      COLOR_CHROME: ['Off', 'Weak', 'Strong'],
      
      DRIVE_MODE: ['Single', 'Continuous Low', 'Continuous High', 'Self-timer 2s', 
                   'Self-timer 10s', 'Interval Timer', 'Multiple Exposure'],
      
      METERING_MODE: ['Multi', 'Spot', 'Average', 'Center-weighted']
    };

    // Fujifilm camera series mapping
    this.CAMERA_SERIES = {
      'X-T': ['X-T5', 'X-T4', 'X-T3', 'X-T30 II', 'X-T30'],
      'X-H': ['X-H2S', 'X-H2', 'X-H1'],
      'X-Pro': ['X-Pro3', 'X-Pro2'],
      'X-E': ['X-E4', 'X-E3'],
      'X-S': ['X-S20', 'X-S10'],
      'GFX': ['GFX100S', 'GFX100', 'GFX50S II', 'GFX50S', 'GFX50R'],
      'X100': ['X100V', 'X100F']
    };

    this.loadNativeModule();
  }

  loadNativeModule() {
    try {
      // Load the compiled native Fujifilm SDK addon (would need to be developed)
      this.fujiNative = require('../native/fujifilm/build/Release/fujifilm_sdk.node');
      this.fujiSDK = new this.fujiNative.FujifilmSDK();
      
      logger.info('Fujifilm SDK native module loaded successfully');
      this.isInitialized = true;
      
      // Set up event callbacks
      this.setupNativeEventHandlers();
      
    } catch (error) {
      logger.warn('Failed to load Fujifilm SDK native module, using wireless fallback:', error);
      this.fujiNative = null;
      this.fujiSDK = null;
      
      // Fallback to wireless HTTP API (Fujifilm cameras support HTTP remote control)
      this.initializeWirelessAPI();
    }
  }

  async initializeWirelessAPI() {
    try {
      this.wirelessAPI = {
        baseURL: null, // Will be discovered via UPnP/mDNS
        sessionId: null,
        connected: false
      };
      
      logger.info('Fujifilm wireless API initialized');
      this.isInitialized = true;
      
    } catch (error) {
      logger.error('Failed to initialize Fujifilm wireless API:', error);
      this.isInitialized = false;
    }
  }

  setupNativeEventHandlers() {
    if (!this.fujiSDK) return;
    
    try {
      // Set event callback for camera events
      this.fujiSDK.setEventCallback((eventType, data) => {
        this.handleNativeEvent(eventType, data);
      });
      
      // Set live view callback
      this.fujiSDK.setLiveViewCallback((imageData, width, height, frameNumber) => {
        this.handleNativeLiveView(imageData, width, height, frameNumber);
      });
      
    } catch (error) {
      logger.error('Failed to set up Fujifilm native event handlers:', error);
    }
  }

  async initialize() {
    try {
      logger.info('Initializing Fujifilm SDK Service...');
      
      if (this.fujiSDK) {
        // Native SDK initialization
        await this.fujiSDK.initialize();
      } else {
        // Wireless API initialization
        await this.discoverWirelessCameras();
      }
      
      logger.info('Fujifilm SDK Service initialized successfully');
      return true;
      
    } catch (error) {
      logger.error('Failed to initialize Fujifilm SDK Service:', error);
      throw error;
    }
  }

  async discoverCameras() {
    if (!this.isInitialized) {
      throw new Error('Fujifilm SDK not initialized');
    }

    try {
      logger.info('Discovering Fujifilm cameras...');
      
      let cameras = [];
      
      if (this.fujiSDK) {
        // Native SDK discovery
        cameras = await this.fujiSDK.getCameraList();
      } else {
        // Wireless discovery using UPnP/mDNS
        cameras = await this.discoverWirelessCameras();
      }
      
      this.cameraList = cameras.map((camera, index) => ({
        index,
        model: camera.model || 'Unknown Fujifilm Camera',
        serialNumber: camera.serialNumber || `FUJI_${index}`,
        firmware: camera.firmware || '1.0.0',
        connectionType: this.fujiSDK ? 'usb' : 'wireless',
        capabilities: this.getCameraCapabilities(camera.model),
        batteryLevel: camera.batteryLevel || 'unknown',
        memoryCardStatus: camera.memoryCardStatus || 'unknown'
      }));
      
      logger.info(`Discovered ${cameras.length} Fujifilm cameras`);
      this.emit('camerasDiscovered', this.cameraList);
      
      return this.cameraList;
      
    } catch (error) {
      logger.error('Failed to discover Fujifilm cameras:', error);
      throw error;
    }
  }

  async discoverWirelessCameras() {
    try {
      // Simulate UPnP/mDNS discovery for Fujifilm cameras
      // In real implementation, this would use network discovery protocols
      
      const mockCameras = [
        {
          model: 'X-T4',
          serialNumber: 'FUJI_XT4_001',
          ipAddress: '192.168.1.100',
          port: 55740, // Standard Fujifilm HTTP port
          firmware: '1.30'
        }
      ];
      
      // Test connectivity to each discovered camera
      const validCameras = [];
      for (const camera of mockCameras) {
        try {
          // Would test HTTP connection here
          validCameras.push(camera);
        } catch (error) {
          logger.warn(`Fujifilm camera ${camera.model} not accessible:`, error);
        }
      }
      
      return validCameras;
      
    } catch (error) {
      logger.error('Wireless camera discovery failed:', error);
      return [];
    }
  }

  getCameraCapabilities(model) {
    // Return capabilities based on camera model
    const baseCapabilities = { ...this.CAPABILITY_VALUES };
    
    // Adjust capabilities based on specific model
    if (model && model.includes('GFX')) {
      // Medium format cameras have different ISO range
      baseCapabilities.ISO = ['64', '80', '100', '125', '160', '200', '250', '320', 
                             '400', '500', '640', '800', '1000', '1250', '1600', 
                             '2000', '2500', '3200', '4000', '5000', '6400', '12800'];
    }
    
    if (model && (model.includes('X100') || model.includes('X-E'))) {
      // Fixed lens cameras may have limited aperture range
      baseCapabilities.APERTURE = ['F2.0', 'F2.8', 'F4.0', 'F5.6', 'F8.0', 'F11', 'F16'];
    }
    
    return baseCapabilities;
  }

  async connectToCamera(cameraIndex) {
    const camera = this.cameraList[cameraIndex];
    if (!camera) {
      throw new Error(`Camera not found at index: ${cameraIndex}`);
    }

    try {
      logger.info(`Connecting to Fujifilm camera: ${camera.model}`);
      
      if (this.fujiSDK) {
        // Native SDK connection
        this.connectedCamera = await this.fujiSDK.openSession(cameraIndex);
      } else {
        // Wireless connection
        this.connectedCamera = await this.connectWireless(camera);
      }
      
      // Enhanced camera info with Fujifilm-specific features
      const enhancedCamera = {
        ...this.connectedCamera,
        brand: 'fujifilm',
        model: camera.model,
        serialNumber: camera.serialNumber,
        capabilities: camera.capabilities,
        filmSimulationSupport: true,
        grainEffectSupport: true,
        colorChromeSupport: model && !model.includes('X-E3'), // Most recent models support it
        intervalTimerSupport: true,
        multipleExposureSupport: true
      };
      
      this.connectedCamera = enhancedCamera;
      
      logger.info(`Successfully connected to Fujifilm ${camera.model}`);
      this.emit('cameraConnected', enhancedCamera);
      
      return enhancedCamera;
      
    } catch (error) {
      logger.error(`Failed to connect to Fujifilm camera at index ${cameraIndex}:`, error);
      throw error;
    }
  }

  async connectWireless(camera) {
    try {
      // Establish wireless connection using HTTP API
      const baseURL = `http://${camera.ipAddress}:${camera.port}`;
      
      // Initialize session
      const sessionResponse = await this.makeHTTPRequest(`${baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'startSession',
          params: []
        })
      });
      
      if (sessionResponse.error) {
        throw new Error(`Session start failed: ${sessionResponse.error.message}`);
      }
      
      this.wirelessAPI.baseURL = baseURL;
      this.wirelessAPI.sessionId = sessionResponse.result[0];
      this.wirelessAPI.connected = true;
      
      return {
        connectionType: 'wireless',
        sessionId: this.wirelessAPI.sessionId,
        ipAddress: camera.ipAddress,
        model: camera.model
      };
      
    } catch (error) {
      logger.error('Wireless connection failed:', error);
      throw error;
    }
  }

  async makeHTTPRequest(url, options) {
    // Simplified HTTP request - would use proper HTTP client in real implementation
    try {
      const response = await fetch(url, {
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        },
        body: options.body
      });
      
      return await response.json();
    } catch (error) {
      throw new Error(`HTTP request failed: ${error.message}`);
    }
  }

  async getCameraSettings() {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      let settings;
      
      if (this.fujiSDK) {
        // Native SDK settings retrieval
        settings = await this.fujiSDK.getAllSettings();
      } else {
        // Wireless settings retrieval
        settings = await this.getWirelessSettings();
      }
      
      // Normalize settings format
      return {
        iso: settings.iso_speed || 'AUTO',
        aperture: settings.aperture_value || 'F4.0',
        shutter_speed: settings.shutter_speed || '1/125',
        white_balance: settings.white_balance || 'AUTO',
        exposure_mode: settings.exposure_mode || 'Program',
        focus_mode: settings.focus_mode || 'AF-S',
        drive_mode: settings.drive_mode || 'Single',
        metering_mode: settings.metering_mode || 'Multi',
        
        // Fujifilm-specific settings
        film_simulation: settings.film_simulation || 'Provia/Standard',
        grain_effect: settings.grain_effect || 'Off',
        color_chrome: settings.color_chrome_effect || 'Off',
        dynamic_range: settings.dynamic_range || 'AUTO',
        highlight_tone: settings.highlight_tone || '0',
        shadow_tone: settings.shadow_tone || '0'
      };
      
    } catch (error) {
      logger.error('Failed to get Fujifilm camera settings:', error);
      throw error;
    }
  }

  async getWirelessSettings() {
    if (!this.wirelessAPI.connected) {
      throw new Error('Wireless connection not established');
    }

    try {
      const response = await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'getCurrentSettings',
          params: []
        })
      });
      
      if (response.error) {
        throw new Error(`Settings retrieval failed: ${response.error.message}`);
      }
      
      return response.result[0];
      
    } catch (error) {
      logger.error('Wireless settings retrieval failed:', error);
      throw error;
    }
  }

  async setCameraProperty(property, value) {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      const propertyName = this.PROPERTY_MAPPINGS[property.toUpperCase()];
      if (!propertyName) {
        throw new Error(`Unsupported property: ${property}`);
      }
      
      logger.info(`Setting Fujifilm camera ${property} to ${value}`);
      
      if (this.fujiSDK) {
        // Native SDK property setting
        await this.fujiSDK.setProperty(propertyName, value);
      } else {
        // Wireless property setting
        await this.setWirelessProperty(propertyName, value);
      }
      
      logger.info(`Successfully set ${property} to ${value}`);
      return { success: true, property, value };
      
    } catch (error) {
      logger.error(`Failed to set Fujifilm camera property ${property}:`, error);
      throw error;
    }
  }

  async setWirelessProperty(propertyName, value) {
    if (!this.wirelessAPI.connected) {
      throw new Error('Wireless connection not established');
    }

    try {
      const response = await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'setParameter',
          params: [propertyName, value]
        })
      });
      
      if (response.error) {
        throw new Error(`Property setting failed: ${response.error.message}`);
      }
      
      return response.result;
      
    } catch (error) {
      logger.error('Wireless property setting failed:', error);
      throw error;
    }
  }

  async startLiveView() {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      logger.info('Starting Fujifilm live view...');
      
      if (this.fujiSDK) {
        // Native SDK live view
        this.liveViewSession = await this.fujiSDK.startLiveView();
      } else {
        // Wireless live view
        await this.startWirelessLiveView();
      }
      
      logger.info('Fujifilm live view started successfully');
      return { success: true, sessionId: this.liveViewSession?.id };
      
    } catch (error) {
      logger.error('Failed to start Fujifilm live view:', error);
      throw error;
    }
  }

  async startWirelessLiveView() {
    if (!this.wirelessAPI.connected) {
      throw new Error('Wireless connection not established');
    }

    try {
      const response = await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'startLiveView',
          params: []
        })
      });
      
      if (response.error) {
        throw new Error(`Live view start failed: ${response.error.message}`);
      }
      
      this.liveViewSession = {
        id: response.result[0],
        streamUrl: `${this.wirelessAPI.baseURL}/liveview`,
        active: true
      };
      
      // Start receiving live view frames
      this.startLiveViewStream();
      
    } catch (error) {
      logger.error('Wireless live view start failed:', error);
      throw error;
    }
  }

  startLiveViewStream() {
    // Implement live view streaming for wireless connection
    // This would typically involve setting up a WebSocket or HTTP stream
    setInterval(() => {
      if (this.liveViewSession?.active) {
        // Emit mock live view frame
        this.emit('liveViewFrame', {
          data: Buffer.alloc(1024), // Mock frame data
          width: 1920,
          height: 1080,
          format: 'jpeg',
          timestamp: Date.now()
        });
      }
    }, 33); // ~30 FPS
  }

  async captureImage(settings = {}) {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      logger.info('Capturing image with Fujifilm camera...');
      
      // Apply any temporary settings
      if (Object.keys(settings).length > 0) {
        for (const [property, value] of Object.entries(settings)) {
          await this.setCameraProperty(property, value);
        }
      }
      
      let captureResult;
      
      if (this.fujiSDK) {
        // Native SDK capture
        captureResult = await this.fujiSDK.takePicture();
      } else {
        // Wireless capture
        captureResult = await this.captureWireless();
      }
      
      const imageInfo = {
        success: true,
        filename: captureResult.filename || `fuji_${Date.now()}.jpg`,
        filepath: captureResult.filepath,
        size: captureResult.size || 0,
        timestamp: new Date().toISOString(),
        settings: await this.getCameraSettings(),
        brand: 'fujifilm',
        model: this.connectedCamera.model
      };
      
      logger.info(`Image captured successfully: ${imageInfo.filename}`);
      this.emit('imageCaptured', imageInfo);
      
      return imageInfo;
      
    } catch (error) {
      logger.error('Failed to capture image with Fujifilm camera:', error);
      throw error;
    }
  }

  async captureWireless() {
    if (!this.wirelessAPI.connected) {
      throw new Error('Wireless connection not established');
    }

    try {
      const response = await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'takePicture',
          params: []
        })
      });
      
      if (response.error) {
        throw new Error(`Wireless capture failed: ${response.error.message}`);
      }
      
      return {
        filename: response.result.filename,
        filepath: response.result.url,
        size: response.result.size
      };
      
    } catch (error) {
      logger.error('Wireless capture failed:', error);
      throw error;
    }
  }

  async stopLiveView() {
    if (!this.liveViewSession) {
      return { success: true };
    }

    try {
      logger.info('Stopping Fujifilm live view...');
      
      if (this.fujiSDK) {
        await this.fujiSDK.stopLiveView();
      } else {
        await this.stopWirelessLiveView();
      }
      
      this.liveViewSession = null;
      
      logger.info('Fujifilm live view stopped successfully');
      return { success: true };
      
    } catch (error) {
      logger.error('Failed to stop Fujifilm live view:', error);
      throw error;
    }
  }

  async stopWirelessLiveView() {
    if (!this.wirelessAPI.connected || !this.liveViewSession) {
      return;
    }

    try {
      const response = await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'stopLiveView',
          params: []
        })
      });
      
      if (response.error) {
        logger.warn(`Live view stop warning: ${response.error.message}`);
      }
      
      this.liveViewSession.active = false;
      
    } catch (error) {
      logger.error('Wireless live view stop failed:', error);
    }
  }

  async disconnectCamera() {
    if (!this.connectedCamera) {
      return { success: true };
    }

    try {
      logger.info('Disconnecting Fujifilm camera...');
      
      // Stop live view if active
      await this.stopLiveView();
      
      if (this.fujiSDK) {
        await this.fujiSDK.closeSession();
      } else {
        await this.disconnectWireless();
      }
      
      this.connectedCamera = null;
      
      logger.info('Fujifilm camera disconnected successfully');
      this.emit('cameraDisconnected', { brand: 'fujifilm' });
      
      return { success: true };
      
    } catch (error) {
      logger.error('Failed to disconnect Fujifilm camera:', error);
      throw error;
    }
  }

  async disconnectWireless() {
    if (!this.wirelessAPI.connected) {
      return;
    }

    try {
      await this.makeHTTPRequest(`${this.wirelessAPI.baseURL}/cam.cgi`, {
        method: 'POST',
        body: JSON.stringify({
          id: 1,
          method: 'stopSession',
          params: []
        })
      });
      
      this.wirelessAPI.connected = false;
      this.wirelessAPI.sessionId = null;
      
    } catch (error) {
      logger.error('Wireless disconnection failed:', error);
    }
  }

  handleNativeEvent(eventType, data) {
    try {
      switch (eventType) {
        case 'camera_added':
          this.emit('cameraConnected', data);
          break;
        case 'camera_removed':
          this.emit('cameraDisconnected', data);
          break;
        case 'property_changed':
          this.emit('propertyChanged', data);
          break;
        case 'error':
          this.emit('cameraError', data);
          break;
        default:
          logger.debug(`Unknown Fujifilm event: ${eventType}`, data);
      }
    } catch (error) {
      logger.error('Error handling Fujifilm native event:', error);
    }
  }

  handleNativeLiveView(imageData, width, height, frameNumber) {
    try {
      this.emit('liveViewFrame', {
        data: imageData,
        width,
        height,
        frameNumber,
        format: 'jpeg',
        timestamp: Date.now()
      });
    } catch (error) {
      logger.error('Error handling Fujifilm live view frame:', error);
    }
  }

  async terminate() {
    try {
      logger.info('Terminating Fujifilm SDK Service...');
      
      await this.disconnectCamera();
      
      if (this.fujiSDK) {
        await this.fujiSDK.terminate();
      }
      
      this.isInitialized = false;
      this.cameraList = [];
      
      logger.info('Fujifilm SDK Service terminated successfully');
      
    } catch (error) {
      logger.error('Failed to terminate Fujifilm SDK Service:', error);
      throw error;
    }
  }

  // Fujifilm-specific utility methods
  async setFilmSimulation(simulation) {
    return await this.setCameraProperty('FILM_SIMULATION', simulation);
  }

  async setGrainEffect(effect) {
    return await this.setCameraProperty('GRAIN_EFFECT', effect);
  }

  async setColorChrome(effect) {
    return await this.setCameraProperty('COLOR_CHROME', effect);
  }

  getSupportedFilmSimulations() {
    return this.CAPABILITY_VALUES.FILM_SIMULATION;
  }

  getCameraSeriesInfo(model) {
    for (const [series, models] of Object.entries(this.CAMERA_SERIES)) {
      if (models.some(m => model.includes(m))) {
        return {
          series,
          models: models.filter(m => model.includes(m))
        };
      }
    }
    return null;
  }
}

module.exports = FujifilmSDKService;