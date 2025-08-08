const EventEmitter = require('events');
const logger = require('../utils/logger');

class SonySDKService extends EventEmitter {
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

    // Sony Camera Remote API property mappings
    this.PROPERTY_MAPPINGS = {
      ISO: 'setIsoSpeedRate',
      APERTURE: 'setFNumber',
      SHUTTER_SPEED: 'setShutterSpeed',
      WHITE_BALANCE: 'setWhiteBalance',
      DRIVE_MODE: 'setStillCaptureMode',
      FOCUS_MODE: 'setFocusMode',
      EXPOSURE_MODE: 'setExposureMode',
      FLASH_MODE: 'setFlashMode',
      ZOOM: 'setZoomSetting'
    };

    // Sony-specific capability values
    this.CAPABILITY_VALUES = {
      ISO: ['AUTO', '50', '64', '80', '100', '125', '160', '200', '250', '320', '400', 
            '500', '640', '800', '1000', '1250', '1600', '2000', '2500', '3200', '4000', 
            '5000', '6400', '8000', '10000', '12800', '25600', '51200', '102400'],
      
      APERTURE: ['AUTO', 'F1.4', 'F1.8', 'F2.0', 'F2.8', 'F3.5', 'F4.0', 'F5.0', 'F5.6', 
                 'F6.3', 'F7.1', 'F8.0', 'F9.0', 'F10', 'F11', 'F13', 'F14', 'F16', 'F18', 'F20', 'F22'],
      
      SHUTTER_SPEED: ['AUTO', '30\"', '25\"', '20\"', '15\"', '13\"', '10\"', '8\"', '6\"', '5\"', '4\"', 
                      '3.2\"', '2.5\"', '2\"', '1.6\"', '1.3\"', '1\"', '1/1.3', '1/1.6', '1/2', '1/2.5', 
                      '1/3', '1/4', '1/5', '1/6', '1/8', '1/10', '1/13', '1/15', '1/20', '1/25', '1/30', 
                      '1/40', '1/50', '1/60', '1/80', '1/100', '1/125', '1/160', '1/200', '1/250', '1/320', 
                      '1/400', '1/500', '1/640', '1/800', '1/1000', '1/1250', '1/1600', '1/2000', '1/2500', 
                      '1/3200', '1/4000'],
      
      WHITE_BALANCE: ['Auto WB', 'Daylight', 'Shade', 'Cloudy', 'Incandescent', 
                      'Fluorescent: Warm White', 'Fluorescent: Cool White', 'Fluorescent: Day White', 
                      'Fluorescent: Daylight', 'Flash', 'Color Temperature', 'Color Filter'],
      
      FOCUS_MODE: ['AF-S', 'AF-C', 'DMF', 'Manual Focus'],
      
      EXPOSURE_MODE: ['Program Auto', 'Aperture Priority', 'Shutter Priority', 'Manual Exposure', 
                      'Intelligent Auto', 'Superior Auto']
    };

    this.loadNativeModule();
  }

  loadNativeModule() {
    try {
      // Load the compiled native Sony Camera Remote SDK addon
      this.sonyNative = require('../native/sony/build/Release/sony_sdk.node');
      this.sonySDK = new this.sonyNative.SonySDK();
      
      logger.info('Sony Camera Remote SDK native module loaded successfully');
      this.isInitialized = true;
      
      // Set up event callbacks
      this.setupNativeEventHandlers();
      
    } catch (error) {
      logger.warn('Failed to load Sony SDK native module, falling back to simulation:', error);
      this.sonyNative = null;
      this.sonySDK = null;
      this.isInitialized = true; // Allow fallback to simulation
    }
  }

  setupNativeEventHandlers() {
    if (!this.sonySDK) return;
    
    try {
      // Set event callback for camera events
      this.sonySDK.setEventCallback((api, command, param) => {
        this.handleNativeEvent(api, command, param);
      });
      
      // Set live view callback
      this.sonySDK.setLiveViewCallback((imageData, width, height, frameNumber) => {
        this.handleNativeLiveView(imageData, width, height, frameNumber);
      });
      
    } catch (error) {
      logger.error('Failed to set up Sony native event handlers:', error);
    }
  }

  handleNativeEvent(api, command, param) {
    logger.debug(`Native Sony event: API=${api}, Command=${command}, Param=${param}`);
    
    // Map native events to our event system
    switch (command) {
      case 1: // Camera connected
        this.emit('cameraConnected');
        break;
      case 2: // Camera disconnected
        this.emit('cameraDisconnected');
        break;
      case 3: // Property changed
        this.emit('propertyEvent', { api, command, param });
        break;
      case 4: // Image captured
        this.emit('imageCaptured', { param });
        break;
      default:
        this.emit('sonyEvent', { api, command, param });
    }
  }

  handleNativeLiveView(imageData, width, height, frameNumber) {
    if (this.liveViewSession?.active) {
      this.emit('liveViewFrame', {
        data: imageData,
        width,
        height,
        frameNumber,
        timestamp: Date.now()
      });
    }
  }

  async initialize() {
    if (!this.isInitialized) {
      throw new Error('Sony SDK not properly loaded');
    }

    try {
      logger.info('Initializing Sony Camera Remote SDK...');
      
      if (this.sonySDK) {
        // Use real Sony Camera Remote SDK
        const result = await new Promise((resolve, reject) => {
          try {
            const success = this.sonySDK.initialize();
            resolve(success);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error('Sony Camera Remote SDK initialization failed');
        }
        
        logger.info('Sony Camera Remote SDK initialized successfully');
      } else {
        // Fallback to simulation
        await this.simulateSDKCall('initialize');
        logger.info('Sony SDK initialized successfully (simulation mode)');
      }
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize Sony SDK:', error);
      throw error;
    }
  }

  async discoverCameras() {
    try {
      logger.info('Discovering Sony cameras...');
      
      this.cameraList = [];
      
      if (this.sonySDK) {
        // Use real Sony Camera Remote SDK for discovery
        const cameras = await new Promise((resolve, reject) => {
          try {
            const cameraArray = this.sonySDK.discoverCameras();
            resolve(cameraArray);
          } catch (error) {
            reject(error);
          }
        });
        
        logger.info(`Found ${cameras.length} Sony cameras`);
        
        for (let i = 0; i < cameras.length; i++) {
          const camera = cameras[i];
          this.cameraList.push({
            index: i,
            brand: 'Sony',
            model: camera.model || 'Sony Camera',
            serialNumber: camera.serialNumber || `SN${3000000 + i}`,
            firmwareVersion: camera.firmwareVersion || '1.0.0',
            batteryLevel: 95, // Will be updated after connection
            isConnected: false,
            connectionType: camera.connectionType || 'WiFi',
            ipAddress: camera.ipAddress,
            capabilities: {
              liveView: true,
              remoteCapture: true,
              bulbMode: true,
              videoRecording: true,
              wirelessTransfer: true,
              intervalTimer: true,
              bracketing: true,
              focusPeaking: true,
              zebra: true,
              histogram: true
            }
          });
        }
      } else {
        // Fallback to simulation
        const cameraCount = await this.simulateSDKCall('discoverCameras');
        
        for (let i = 0; i < cameraCount; i++) {
          const cameraInfo = await this.simulateSDKCall('getCameraInfo', i);
          this.cameraList.push({
            index: i,
            brand: 'Sony',
            model: cameraInfo.model || 'Sony α7R V',
            serialNumber: cameraInfo.serialNumber || `SN${3000000 + i}`,
            firmwareVersion: cameraInfo.firmwareVersion || '2.00',
            batteryLevel: cameraInfo.batteryLevel || 95,
            isConnected: false,
            connectionType: 'Simulated',
            capabilities: {
              liveView: true,
              remoteCapture: true,
              bulbMode: true,
              videoRecording: true,
              wirelessTransfer: true,
              intervalTimer: true
            }
          });
        }
      }

      logger.info(`Found ${this.cameraList.length} Sony cameras`);
      this.emit('camerasDiscovered', this.cameraList);
      
      return this.cameraList;
    } catch (error) {
      logger.error('Sony camera discovery failed:', error);
      throw error;
    }
  }

  async connectToCamera(cameraIndex = 0) {
    try {
      if (cameraIndex >= this.cameraList.length) {
        throw new Error('Invalid camera index');
      }

      const camera = this.cameraList[cameraIndex];
      logger.info(`Connecting to Sony camera: ${camera.model}`);

      if (this.sonySDK) {
        // Use real Sony SDK for connection
        const result = await new Promise((resolve, reject) => {
          try {
            const cameraInfo = this.sonySDK.connectCamera(cameraIndex);
            resolve(cameraInfo);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error('Sony camera connection failed');
        }
        
        // Update camera info with real data
        camera.model = result.model || camera.model;
        camera.serialNumber = result.serialNumber || camera.serialNumber;
        camera.firmwareVersion = result.firmwareVersion || camera.firmwareVersion;
      } else {
        // Simulate connection
        await this.connectWithRetry(cameraIndex);
      }
      
      // Set up event handlers and monitoring
      await this.setupEventHandlers(cameraIndex);
      
      // Update camera status
      camera.isConnected = true;
      this.connectedCamera = camera;
      this.reconnectAttempts = 0;
      
      // Start connection monitoring
      this.startConnectionWatchdog();
      
      logger.info(`Successfully connected to Sony ${camera.model}`);
      this.emit('cameraConnected', camera);
      
      return camera;
    } catch (error) {
      logger.error('Sony camera connection failed:', error);
      this.handleConnectionError(error);
      throw error;
    }
  }

  async connectWithRetry(cameraIndex, attempt = 1) {
    try {
      await this.simulateSDKCall('connectCamera', cameraIndex);
      return true;
    } catch (error) {
      if (attempt < this.maxReconnectAttempts) {
        logger.warn(`Sony connection attempt ${attempt} failed, retrying in ${this.reconnectDelay}ms...`);
        await new Promise(resolve => setTimeout(resolve, this.reconnectDelay));
        return this.connectWithRetry(cameraIndex, attempt + 1);
      } else {
        throw new Error(`Failed to connect to Sony camera after ${this.maxReconnectAttempts} attempts: ${error.message}`);
      }
    }
  }

  async disconnectCamera() {
    try {
      if (!this.connectedCamera) {
        logger.warn('No Sony camera connected');
        return;
      }

      logger.info(`Disconnecting from Sony ${this.connectedCamera.model}`);
      
      await this.cleanupConnection();
      
      if (this.sonySDK) {
        await new Promise((resolve) => {
          try {
            this.sonySDK.disconnectCamera();
            resolve();
          } catch (error) {
            logger.warn('Sony disconnect error:', error);
            resolve(); // Continue with cleanup
          }
        });
      } else {
        await this.simulateSDKCall('disconnectCamera');
      }
      
      this.connectedCamera.isConnected = false;
      const disconnectedCamera = this.connectedCamera;
      this.connectedCamera = null;
      this.reconnectAttempts = 0;
      
      logger.info('Sony camera disconnected successfully');
      this.emit('cameraDisconnected', disconnectedCamera);
      
    } catch (error) {
      logger.error('Sony camera disconnection failed:', error);
      await this.forceDisconnect();
      throw error;
    }
  }

  async getCameraSettings() {
    if (!this.connectedCamera) {
      throw new Error('No Sony camera connected');
    }

    try {
      const settings = {};
      
      if (this.sonySDK) {
        // Get properties from real Sony SDK
        const properties = await new Promise((resolve, reject) => {
          try {
            const props = this.sonySDK.getDeviceProperties();
            resolve(props);
          } catch (error) {
            reject(error);
          }
        });
        
        // Map Sony properties to our standard format
        settings.iso = this.parseSonyProperty(properties, 'isoSpeedRate');
        settings.aperture = this.parseSonyProperty(properties, 'fNumber');
        settings.shutter_speed = this.parseSonyProperty(properties, 'shutterSpeed');
        settings.white_balance = this.parseSonyProperty(properties, 'whiteBalance');
        settings.focus_mode = this.parseSonyProperty(properties, 'focusMode');
        settings.exposure_mode = this.parseSonyProperty(properties, 'exposureMode');
      } else {
        // Simulation fallback
        for (const [key, apiMethod] of Object.entries(this.PROPERTY_MAPPINGS)) {
          try {
            const value = await this.simulateSDKCall('getProperty', apiMethod);
            settings[key.toLowerCase()] = this.formatPropertyValue(key, value);
          } catch (error) {
            logger.warn(`Failed to get Sony property ${key}:`, error);
            settings[key.toLowerCase()] = null;
          }
        }
      }

      return settings;
    } catch (error) {
      logger.error('Failed to get Sony camera settings:', error);
      throw error;
    }
  }

  async setCameraProperty(property, value) {
    if (!this.connectedCamera) {
      throw new Error('No Sony camera connected');
    }

    try {
      const apiMethod = this.PROPERTY_MAPPINGS[property.toUpperCase()];
      if (!apiMethod) {
        throw new Error(`Unknown Sony property: ${property}`);
      }

      if (this.sonySDK) {
        // Use real Sony SDK
        const propertyId = this.getSonyPropertyId(property);
        const formattedValue = this.parsePropertyValue(property, value);
        
        const result = await new Promise((resolve, reject) => {
          try {
            const success = this.sonySDK.setDeviceProperty(propertyId, formattedValue);
            resolve(success);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error(`Failed to set Sony ${property}`);
        }
      } else {
        // Simulation fallback
        await this.simulateSDKCall('setProperty', apiMethod, this.parsePropertyValue(property, value));
      }
      
      logger.info(`Set Sony ${property} to ${value}`);
      this.emit('propertyChanged', { property, value });
      
      return true;
    } catch (error) {
      logger.error(`Failed to set Sony ${property} to ${value}:`, error);
      throw error;
    }
  }

  async startLiveView() {
    if (!this.connectedCamera) {
      throw new Error('No Sony camera connected');
    }

    try {
      logger.info('Starting Sony live view...');
      
      // Check if live view is already active
      if (this.liveViewSession && this.liveViewSession.active) {
        logger.info('Sony live view already active');
        return {
          success: true,
          streamUrl: 'ws://localhost:3001/liveview',
          resolution: '1920x1080',
          fps: 30
        };
      }
      
      if (this.sonySDK) {
        // Use real Sony SDK
        const result = await new Promise((resolve, reject) => {
          try {
            const success = this.sonySDK.startLiveView();
            resolve(success);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error('Failed to start Sony live view');
        }
      } else {
        // Simulation
        await this.simulateSDKCall('startLiveView');
      }
      
      this.liveViewSession = {
        active: true,
        startTime: Date.now(),
        frameCount: 0
      };
      
      if (!this.sonySDK) {
        this.startLiveViewLoop();
      }
      
      logger.info('Sony live view started successfully');
      this.emit('liveViewStarted');
      
      return {
        success: true,
        streamUrl: 'ws://localhost:3001/liveview',
        resolution: '1920x1080',
        fps: 30
      };
    } catch (error) {
      logger.error('Failed to start Sony live view:', error);
      // Don't throw error in simulation mode, return success with warning
      if (!this.sonySDK) {
        logger.warn('Sony live view started in simulation mode');
        this.liveViewSession = {
          active: true,
          startTime: Date.now(),
          frameCount: 0
        };
        this.startLiveViewLoop();
        return {
          success: true,
          streamUrl: 'ws://localhost:3001/liveview',
          resolution: '1920x1080',
          fps: 30,
          simulation: true
        };
      }
      throw error;
    }
  }

  async stopLiveView() {
    if (!this.liveViewSession) {
      return;
    }

    try {
      logger.info('Stopping Sony live view...');
      
      if (this.sonySDK) {
        await new Promise((resolve) => {
          try {
            this.sonySDK.stopLiveView();
            resolve();
          } catch (error) {
            logger.warn('Sony stop live view error:', error);
            resolve();
          }
        });
      } else {
        await this.simulateSDKCall('stopLiveView');
      }
      
      this.liveViewSession.active = false;
      this.liveViewSession = null;
      
      logger.info('Sony live view stopped');
      this.emit('liveViewStopped');
      
    } catch (error) {
      logger.error('Failed to stop Sony live view:', error);
      throw error;
    }
  }

  async captureImage(settings = {}) {
    if (!this.connectedCamera) {
      throw new Error('No Sony camera connected');
    }

    try {
      logger.info('Capturing image with Sony camera, settings:', settings);
      
      // Apply settings first
      for (const [property, value] of Object.entries(settings)) {
        if (value !== undefined) {
          await this.setCameraProperty(property, value);
        }
      }
      
      let result;
      if (this.sonySDK) {
        // Use real Sony SDK
        result = await new Promise((resolve, reject) => {
          try {
            const success = this.sonySDK.takePicture();
            resolve(success);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error('Sony image capture failed');
        }
      } else {
        // Simulation
        await this.simulateSDKCall('takePicture');
      }
      
      // Wait for image processing
      await new Promise(resolve => setTimeout(resolve, 800));
      
      const imageInfo = {
        id: `sony_img_${Date.now()}`,
        filename: `DSC${String(Date.now()).slice(-5)}.ARW`,
        timestamp: new Date().toISOString(),
        settings: await this.getCameraSettings(),
        metadata: {
          fileSize: '38.5MB',
          dimensions: '7952x5304',
          colorSpace: 'sRGB',
          format: 'ARW (RAW)'
        }
      };
      
      logger.info(`Sony image captured: ${imageInfo.filename}`);
      this.emit('imageCaptured', imageInfo);
      
      return imageInfo;
    } catch (error) {
      logger.error('Sony image capture failed:', error);
      throw error;
    }
  }

  // Helper methods for Sony-specific functionality
  getSonyPropertyId(property) {
    const propertyIds = {
      'ISO': 0x80000001,
      'APERTURE': 0x80000002,
      'SHUTTER_SPEED': 0x80000003,
      'WHITE_BALANCE': 0x80000004,
      'FOCUS_MODE': 0x80000005,
      'EXPOSURE_MODE': 0x80000006
    };
    return propertyIds[property.toUpperCase()] || 0;
  }

  parseSonyProperty(properties, propertyName) {
    // Parse Sony SDK property format to our standard format
    if (properties && properties[propertyName]) {
      return properties[propertyName].current || properties[propertyName];
    }
    return null;
  }

  formatPropertyValue(property, rawValue) {
    switch (property) {
      case 'ISO':
        return rawValue || 400;
      case 'APERTURE':
        return rawValue || 'F4.0';
      case 'SHUTTER_SPEED':
        return rawValue || '1/125';
      case 'WHITE_BALANCE':
        return rawValue || 'Auto WB';
      case 'FOCUS_MODE':
        return rawValue || 'AF-S';
      case 'EXPOSURE_MODE':
        return rawValue || 'Program Auto';
      default:
        return rawValue;
    }
  }

  parsePropertyValue(property, value) {
    // Convert user-friendly values to Sony API format
    switch (property) {
      case 'ISO':
        return String(value);
      case 'APERTURE':
        return value.startsWith('F') ? value : `F${value}`;
      case 'SHUTTER_SPEED':
        return value;
      case 'WHITE_BALANCE':
        return value;
      default:
        return value;
    }
  }

  // Inherit common methods from base class (connection monitoring, error handling, etc.)
  startConnectionWatchdog() {
    if (this.connectionWatchdog) {
      clearInterval(this.connectionWatchdog);
    }

    this.lastHeartbeat = Date.now();
    
    this.connectionWatchdog = setInterval(async () => {
      if (!this.connectedCamera) return;

      try {
        // Send heartbeat to Sony camera
        if (this.sonySDK) {
          await new Promise((resolve) => {
            try {
              // Check if camera is still responding
              this.sonySDK.getDeviceProperties();
              resolve();
            } catch (error) {
              throw error;
            }
          });
        } else {
          await this.simulateSDKCall('heartbeat');
        }
        this.lastHeartbeat = Date.now();
      } catch (error) {
        logger.warn('Sony camera heartbeat failed:', error);
        await this.handleConnectionLoss();
      }
    }, 10000); // Check every 10 seconds for Sony (network-based)
  }

  async handleConnectionLoss() {
    if (!this.connectedCamera) return;

    logger.warn('Sony camera connection lost, attempting to reconnect...');
    this.emit('connectionLost');

    try {
      await this.reconnectCamera();
    } catch (error) {
      logger.error('Sony reconnection failed:', error);
      this.emit('reconnectionFailed', error);
      await this.forceDisconnect();
    }
  }

  async cleanupConnection() {
    try {
      if (this.liveViewSession) {
        await this.stopLiveView();
      }
      
      if (this.connectionWatchdog) {
        clearInterval(this.connectionWatchdog);
        this.connectionWatchdog = null;
      }
    } catch (error) {
      logger.warn('Error during Sony connection cleanup:', error);
    }
  }

  async forceDisconnect() {
    logger.info('Forcing Sony camera disconnection');
    
    await this.cleanupConnection();
    
    if (this.connectedCamera) {
      this.connectedCamera.isConnected = false;
      const disconnectedCamera = this.connectedCamera;
      this.connectedCamera = null;
      this.emit('cameraDisconnected', disconnectedCamera);
    }
    
    this.reconnectAttempts = 0;
  }

  handleConnectionError(error) {
    const errorCode = error.code || 'UNKNOWN';
    const errorMessage = this.getSonyErrorMessage(errorCode);
    
    logger.error(`Sony camera error [${errorCode}]: ${errorMessage}`);
    
    this.emit('cameraError', {
      code: errorCode,
      message: errorMessage,
      originalError: error
    });
  }

  getSonyErrorMessage(errorCode) {
    const errorMessages = {
      'TIMEOUT': 'Sony camera connection timeout. Check network connection.',
      'NETWORK_ERROR': 'Network error communicating with Sony camera.',
      'CAMERA_BUSY': 'Sony camera is busy. Please wait and try again.',
      'INVALID_REQUEST': 'Invalid request sent to Sony camera.',
      'UNAUTHORIZED': 'Unauthorized access to Sony camera. Check pairing.',
      'SERVICE_UNAVAILABLE': 'Sony camera service unavailable.',
      'UNKNOWN': 'An unknown Sony camera error occurred.'
    };
    
    return errorMessages[errorCode] || errorMessages['UNKNOWN'];
  }

  // Simulation methods (fallback when native SDK not available)
  async simulateSDKCall(functionName, ...args) {
    await new Promise(resolve => setTimeout(resolve, 100 + Math.random() * 200));
    
    switch (functionName) {
      case 'initialize':
        return true;
      case 'discoverCameras':
        return 1; // Simulate 1 Sony camera
      case 'getCameraInfo':
        return {
          model: 'Sony α7R V',
          serialNumber: 'SN3234567',
          firmwareVersion: '2.00',
          batteryLevel: 95
        };
      case 'connectCamera':
        return true;
      case 'disconnectCamera':
        return true;
      case 'getProperty':
        return this.getSimulatedSonyPropertyValue(args[0]);
      case 'setProperty':
        return true;
      case 'startLiveView':
        return true;
      case 'stopLiveView':
        return true;
      case 'takePicture':
        return true;
      case 'heartbeat':
        return true;
      default:
        return true;
    }
  }

  getSimulatedSonyPropertyValue(propertyMethod) {
    const simulatedValues = {
      'setIsoSpeedRate': '400',
      'setFNumber': 'F4.0',
      'setShutterSpeed': '1/125',
      'setWhiteBalance': 'Auto WB',
      'setFocusMode': 'AF-S',
      'setExposureMode': 'Program Auto'
    };
    return simulatedValues[propertyMethod] || null;
  }

  startLiveViewLoop() {
    if (!this.liveViewSession?.active) return;

    const captureFrame = async () => {
      try {
        const imageData = Buffer.alloc(1024 * 800); // Simulate 800KB JPEG
        
        if (imageData) {
          this.liveViewSession.frameCount++;
          this.emit('liveViewFrame', {
            data: imageData,
            frameNumber: this.liveViewSession.frameCount,
            timestamp: Date.now()
          });
        }
      } catch (error) {
        logger.error('Sony live view frame capture error:', error);
      }

      if (this.liveViewSession?.active) {
        setTimeout(captureFrame, 33);
      }
    };

    captureFrame();
  }

  async setupEventHandlers(cameraIndex) {
    try {
      // Sony event handlers are set up in native module
      logger.info('Sony event handlers set up successfully');
    } catch (error) {
      logger.error('Failed to set up Sony event handlers:', error);
      throw error;
    }
  }

  async reconnectCamera() {
    if (!this.connectedCamera) return;

    const cameraIndex = this.connectedCamera.index;
    this.reconnectAttempts++;

    if (this.reconnectAttempts > this.maxReconnectAttempts) {
      throw new Error('Maximum Sony reconnection attempts exceeded');
    }

    logger.info(`Sony reconnection attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);

    try {
      await this.cleanupConnection();
      await new Promise(resolve => setTimeout(resolve, this.reconnectDelay));
      
      if (this.sonySDK) {
        await new Promise((resolve, reject) => {
          try {
            const result = this.sonySDK.connectCamera(cameraIndex);
            resolve(result);
          } catch (error) {
            reject(error);
          }
        });
      } else {
        await this.simulateSDKCall('connectCamera', cameraIndex);
      }
      
      this.reconnectAttempts = 0;
      this.lastHeartbeat = Date.now();
      
      logger.info('Sony camera reconnected successfully');
      this.emit('cameraReconnected', this.connectedCamera);
      
      return true;
    } catch (error) {
      logger.error(`Sony reconnection attempt ${this.reconnectAttempts} failed:`, error);
      throw error;
    }
  }

  async terminate() {
    try {
      if (this.connectedCamera) {
        await this.disconnectCamera();
      }
      
      if (this.sonySDK) {
        this.sonySDK.terminate();
      }
      
      logger.info('Sony SDK terminated');
    } catch (error) {
      logger.error('Failed to terminate Sony SDK:', error);
    }
  }
}

module.exports = SonySDKService;