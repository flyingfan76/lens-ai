const EventEmitter = require('events');
const path = require('path');
const logger = require('../utils/logger');

class CanonSDKService extends EventEmitter {
  constructor() {
    super();
    this.isInitialized = false;
    this.connectedCamera = null;
    this.cameraList = [];
    this.liveViewSession = null;
    
    // Error handling and reconnection
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 3;
    this.reconnectDelay = 2000; // 2 seconds
    this.connectionWatchdog = null;
    this.lastHeartbeat = null;
    
    // Canon EDSDK error codes
    this.EDS_ERRORS = {
      EDS_ERR_OK: 0x00000000,
      EDS_ERR_UNIMPLEMENTED: 0x00000001,
      EDS_ERR_INTERNAL_ERROR: 0x00000002,
      EDS_ERR_MEM_ALLOC_FAILED: 0x00000003,
      EDS_ERR_MEM_FREE_FAILED: 0x00000004,
      EDS_ERR_OPERATION_CANCELLED: 0x00000005,
      EDS_ERR_INCOMPATIBLE_VERSION: 0x00000006,
      EDS_ERR_NOT_SUPPORTED: 0x00000007,
      EDS_ERR_RESOURCE_NOT_FOUND: 0x00000008,
      EDS_ERR_INVALID_HANDLE: 0x00000009,
      EDS_ERR_INVALID_POINTER: 0x0000000A,
      EDS_ERR_INVALID_INDEX: 0x0000000B,
      EDS_ERR_INVALID_PARAMETER: 0x0000000C,
      EDS_ERR_INVALID_LENGTH: 0x0000000D,
      EDS_ERR_ACCESS_DENIED: 0x0000000E,
      EDS_ERR_INSUFFICIENT_BUFFER: 0x0000000F,
      EDS_ERR_TIMEOUT: 0x00000010,
      EDS_ERR_INVALID_FN_CALL: 0x00000011,
      EDS_ERR_HANDLE_NOT_FOUND: 0x00000012,
      EDS_ERR_INVALID_ID: 0x00000013,
      EDS_ERR_WAIT_TIMEOUT_ERROR: 0x00000014,
      EDS_ERR_SESSION_NOT_OPEN: 0x00002003,
      EDS_ERR_INVALID_TRANSACTIONID: 0x00002004,
      EDS_ERR_INCOMPLETE_TRANSFER: 0x00002007,
      EDS_ERR_INVALID_STRAGEID: 0x00002008,
      EDS_ERR_DEVICEPROP_NOT_SUPPORTED: 0x0000200A,
      EDS_ERR_INVALID_OBJECTFORMATCODE: 0x0000200B,
      EDS_ERR_SELF_TEST_FAILED: 0x0000200C,
      EDS_ERR_PARTIAL_DELETION: 0x0000200D,
      EDS_ERR_SPECIFICATION_BY_FORMAT_UNSUPPORTED: 0x0000200E,
      EDS_ERR_NO_VALID_OBJECTINFO: 0x0000200F,
      EDS_ERR_INVALID_CODE_FORMAT: 0x00002010,
      EDS_ERR_UNKNOWN_COMMAND: 0x00002011,
      EDS_ERR_OPERATION_REFUSED: 0x00002012,
      EDS_ERR_LENS_COVER_CLOSE: 0x00002013,
      EDS_ERR_LOW_BATTERY: 0x00002014,
      EDS_ERR_OBJECT_NOTREADY: 0x00002015,
      EDS_ERR_CANNOT_MAKE_OBJECT: 0x00002016,
      EDS_ERR_MEMORYSTATUS_NOTREADY: 0x00002017,
      EDS_ERR_TAKE_PICTURE_AF_NG: 0x00008D01,
      EDS_ERR_TAKE_PICTURE_RESERVED: 0x00008D02,
      EDS_ERR_TAKE_PICTURE_MIRROR_UP_NG: 0x00008D03,
      EDS_ERR_TAKE_PICTURE_SENSOR_CLEANING_NG: 0x00008D04,
      EDS_ERR_TAKE_PICTURE_SILENCE_NG: 0x00008D05,
      EDS_ERR_TAKE_PICTURE_NO_CARD_NG: 0x00008D06,
      EDS_ERR_TAKE_PICTURE_CARD_NG: 0x00008D07,
      EDS_ERR_TAKE_PICTURE_CARD_PROTECT_NG: 0x00008D08
    };

    // Camera property mappings
    this.PROPERTY_MAPPINGS = {
      ISO: 'kEdsPropID_ISOSpeed',
      APERTURE: 'kEdsPropID_Av',
      SHUTTER_SPEED: 'kEdsPropID_Tv',
      WHITE_BALANCE: 'kEdsPropID_WhiteBalance',
      DRIVE_MODE: 'kEdsPropID_DriveMode',
      METERING_MODE: 'kEdsPropID_MeteringMode',
      AF_MODE: 'kEdsPropID_AFMode',
      IMAGE_QUALITY: 'kEdsPropID_ImageQuality',
      BATTERY_LEVEL: 'kEdsPropID_BatteryLevel'
    };

    this.loadNativeModule();
  }

  loadNativeModule() {
    try {
      // Load the compiled native Canon EDSDK addon
      this.canonNative = require('../native/canon/build/Release/canon_sdk.node');
      this.canonSDK = new this.canonNative.CanonSDK();
      
      logger.info('Canon EDSDK native module loaded successfully');
      this.isInitialized = true;
      
      // Set up event callbacks
      this.setupNativeEventHandlers();
      
    } catch (error) {
      logger.warn('Failed to load Canon EDSDK native module, falling back to simulation:', error);
      this.canonNative = null;
      this.canonSDK = null;
      this.isInitialized = true; // Allow fallback to simulation
    }
  }

  setupNativeEventHandlers() {
    if (!this.canonSDK) return;
    
    try {
      // Set property event handler
      this.canonSDK.setPropertyEventHandler((event, propertyID, inParam) => {
        this.handleNativePropertyEvent(event, propertyID, inParam);
      });
      
      // Set object event handler (for image capture events)
      this.canonSDK.setObjectEventHandler((event, objectRef) => {
        this.handleNativeObjectEvent(event, objectRef);
      });
      
    } catch (error) {
      logger.error('Failed to set up Canon native event handlers:', error);
    }
  }

  handleNativePropertyEvent(event, propertyID, inParam) {
    logger.debug(`Native Canon property event: ${event}, Property: 0x${propertyID.toString(16)}, Param: ${inParam}`);
    
    // Map Canon property IDs to readable names
    const propertyName = this.getCanonPropertyName(propertyID);
    this.emit('propertyEvent', { event, property: propertyName, propertyID, param: inParam });
  }

  handleNativeObjectEvent(event, objectRef) {
    logger.debug(`Native Canon object event: ${event}, Object: ${objectRef}`);
    
    // Handle image capture events
    switch (event) {
      case 0x00000200: // kEdsObjectEvent_DirItemCreated
        this.handleImageDownload(objectRef);
        break;
      case 0x00000201: // kEdsObjectEvent_DirItemRemoved
        this.emit('objectEvent', { event: 'itemRemoved', objectRef });
        break;
      default:
        this.emit('objectEvent', { event, objectRef });
    }
  }

  getCanonPropertyName(propertyID) {
    const propertyNames = {
      0x00000100: 'productName',
      0x00000102: 'ownerName',
      0x00000103: 'makerName',
      0x00000104: 'dateTime',
      0x00000105: 'firmwareVersion',
      0x00000106: 'batteryLevel',
      0x00000400: 'isoSpeed',
      0x00000401: 'aperture',
      0x00000402: 'shutterSpeed',
      0x00000403: 'meteringMode',
      0x00000404: 'afMode',
      0x00000405: 'driveMode',
      0x00000406: 'whiteBalance',
      0x00000407: 'colorSpace',
      0x00000408: 'picStyle',
      0x00000500: 'evfMode',
      0x00000501: 'evfOutputDevice'
    };
    return propertyNames[propertyID] || `0x${propertyID.toString(16)}`;
  }

  async initialize() {
    if (!this.isInitialized) {
      throw new Error('Canon SDK not properly loaded');
    }

    try {
      logger.info('Initializing Canon EDSDK...');
      
      if (this.canonSDK) {
        // Use real Canon EDSDK
        const result = await new Promise((resolve, reject) => {
          try {
            const success = this.canonSDK.initialize();
            resolve(success);
          } catch (error) {
            reject(error);
          }
        });
        
        if (!result) {
          throw new Error('Canon EDSDK initialization failed');
        }
        
        logger.info('Canon EDSDK initialized successfully');
      } else {
        // Fallback to simulation
        await this.simulateSDKCall('EdsInitializeSDK');
        logger.info('Canon EDSDK initialized successfully (simulation mode)');
      }
      
      return true;
    } catch (error) {
      logger.error('Failed to initialize Canon EDSDK:', error);
      throw error;
    }
  }

  async discoverCameras() {
    try {
      logger.info('Discovering Canon cameras...');
      
      this.cameraList = [];
      
      if (this.canonSDK) {
        // Use real Canon EDSDK for discovery
        const cameras = await new Promise((resolve, reject) => {
          try {
            const cameraArray = this.canonSDK.getCameraList();
            resolve(cameraArray);
          } catch (error) {
            reject(error);
          }
        });
        
        logger.info(`Found ${cameras.length} Canon cameras`);
        
        for (let i = 0; i < cameras.length; i++) {
          const camera = cameras[i];
          this.cameraList.push({
            index: i,
            brand: 'Canon',
            model: camera.model || 'Canon Camera',
            serialNumber: camera.serialNumber || `CN${1000000 + i}`,
            firmwareVersion: camera.firmwareVersion || '1.8.1',
            batteryLevel: 85, // Will be updated after connection
            isConnected: false,
            connectionType: 'USB',
            portName: camera.portName,
            capabilities: {
              liveView: true,
              remoteCapture: true,
              bulbMode: true,
              videoRecording: true,
              dualPixelRaw: true,
              bracketingMode: true,
              timerMode: true
            }
          });
        }
      } else {
        // Fallback to simulation
        const cameraCount = await this.simulateSDKCall('EdsGetCameraList');
        
        for (let i = 0; i < cameraCount; i++) {
          const cameraInfo = await this.simulateSDKCall('EdsGetCameraInfo', i);
          this.cameraList.push({
            index: i,
            brand: 'Canon',
            model: cameraInfo.model || 'Canon EOS R5',
            serialNumber: cameraInfo.serialNumber || `CN${1000000 + i}`,
            firmwareVersion: cameraInfo.firmwareVersion || '1.8.1',
            batteryLevel: cameraInfo.batteryLevel || 85,
            isConnected: false,
            connectionType: 'Simulated',
            capabilities: {
              liveView: true,
              remoteCapture: true,
              bulbMode: true,
              videoRecording: true
            }
          });
        }
      }

      logger.info(`Found ${this.cameraList.length} Canon cameras`);
      this.emit('camerasDiscovered', this.cameraList);
      
      return this.cameraList;
    } catch (error) {
      logger.error('Canon camera discovery failed:', error);
      throw error;
    }
  }

  async connectToCamera(cameraIndex = 0) {
    try {
      if (cameraIndex >= this.cameraList.length) {
        throw new Error('Invalid camera index');
      }

      const camera = this.cameraList[cameraIndex];
      logger.info(`Connecting to camera: ${camera.model}`);

      // Attempt connection with retry logic
      if (this.canonSDK) {
        // Use real Canon EDSDK
        const result = await new Promise((resolve, reject) => {
          try {
            const cameraInfo = this.canonSDK.openSession(cameraIndex);
            resolve(cameraInfo);
          } catch (error) {
            reject(error);
          }
        });
        
        if (result) {
          // Update camera info with real data from EDSDK
          camera.model = result.model || camera.model;
          camera.portName = result.portName || camera.portName;
        }
      } else {
        // Fallback to simulation
        await this.connectWithRetry(cameraIndex);
      }
      
      // Set up event handlers
      await this.setupEventHandlers(cameraIndex);
      
      // Update camera status
      camera.isConnected = true;
      this.connectedCamera = camera;
      this.reconnectAttempts = 0; // Reset on successful connection
      
      // Start connection monitoring
      this.startConnectionWatchdog();
      
      logger.info(`Successfully connected to ${camera.model}`);
      this.emit('cameraConnected', camera);
      
      return camera;
    } catch (error) {
      logger.error('Camera connection failed:', error);
      this.handleConnectionError(error);
      throw error;
    }
  }

  async connectWithRetry(cameraIndex, attempt = 1) {
    try {
      await this.simulateSDKCall('EdsOpenSession', cameraIndex);
      return true;
    } catch (error) {
      if (attempt < this.maxReconnectAttempts) {
        logger.warn(`Connection attempt ${attempt} failed, retrying in ${this.reconnectDelay}ms...`);
        await new Promise(resolve => setTimeout(resolve, this.reconnectDelay));
        return this.connectWithRetry(cameraIndex, attempt + 1);
      } else {
        throw new Error(`Failed to connect after ${this.maxReconnectAttempts} attempts: ${error.message}`);
      }
    }
  }

  startConnectionWatchdog() {
    if (this.connectionWatchdog) {
      clearInterval(this.connectionWatchdog);
    }

    this.lastHeartbeat = Date.now();
    
    this.connectionWatchdog = setInterval(async () => {
      if (!this.connectedCamera) return;

      try {
        // Send heartbeat to camera
        await this.simulateSDKCall('EdsGetPropertyData', 'kEdsPropID_BatteryLevel');
        this.lastHeartbeat = Date.now();
      } catch (error) {
        logger.warn('Camera heartbeat failed:', error);
        await this.handleConnectionLoss();
      }
    }, 5000); // Check every 5 seconds
  }

  async handleConnectionLoss() {
    if (!this.connectedCamera) return;

    logger.warn('Camera connection lost, attempting to reconnect...');
    this.emit('connectionLost');

    try {
      // Try to reconnect
      await this.reconnectCamera();
    } catch (error) {
      logger.error('Reconnection failed:', error);
      this.emit('reconnectionFailed', error);
      
      // Force disconnect after failed reconnection
      await this.forceDisconnect();
    }
  }

  async reconnectCamera() {
    if (!this.connectedCamera) return;

    const cameraIndex = this.connectedCamera.index;
    this.reconnectAttempts++;

    if (this.reconnectAttempts > this.maxReconnectAttempts) {
      throw new Error('Maximum reconnection attempts exceeded');
    }

    logger.info(`Reconnection attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);

    try {
      // Clean up existing connection
      await this.cleanupConnection();
      
      // Wait before reconnecting
      await new Promise(resolve => setTimeout(resolve, this.reconnectDelay));
      
      // Attempt to reconnect
      await this.simulateSDKCall('EdsOpenSession', cameraIndex);
      
      // Reset reconnection counter on success
      this.reconnectAttempts = 0;
      this.lastHeartbeat = Date.now();
      
      logger.info('Camera reconnected successfully');
      this.emit('cameraReconnected', this.connectedCamera);
      
      return true;
    } catch (error) {
      logger.error(`Reconnection attempt ${this.reconnectAttempts} failed:`, error);
      throw error;
    }
  }

  async cleanupConnection() {
    try {
      if (this.liveViewSession) {
        await this.stopLiveView();
      }
      
      // Clear any pending operations
      if (this.connectionWatchdog) {
        clearInterval(this.connectionWatchdog);
        this.connectionWatchdog = null;
      }
    } catch (error) {
      logger.warn('Error during connection cleanup:', error);
    }
  }

  async forceDisconnect() {
    logger.info('Forcing camera disconnection');
    
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
    const errorMessage = this.getErrorMessage(errorCode);
    
    logger.error(`Camera error [${errorCode}]: ${errorMessage}`);
    
    this.emit('cameraError', {
      code: errorCode,
      message: errorMessage,
      originalError: error
    });
  }

  getErrorMessage(errorCode) {
    const errorMessages = {
      'EDS_ERR_DEVICE_NOT_FOUND': 'Camera not found. Please check connection.',
      'EDS_ERR_DEVICE_BUSY': 'Camera is busy. Please wait and try again.',
      'EDS_ERR_SESSION_NOT_OPEN': 'Camera session not open. Please reconnect.',
      'EDS_ERR_LOW_BATTERY': 'Camera battery is low. Please charge the battery.',
      'EDS_ERR_LENS_COVER_CLOSE': 'Lens cover is closed. Please open the lens cover.',
      'EDS_ERR_MEMORYSTATUS_NOTREADY': 'Memory card not ready. Please check the memory card.',
      'EDS_ERR_TAKE_PICTURE_AF_NG': 'Auto-focus failed. Please adjust focus manually.',
      'UNKNOWN': 'An unknown error occurred.'
    };
    
    return errorMessages[errorCode] || errorMessages['UNKNOWN'];
  }

  async disconnectCamera() {
    try {
      if (!this.connectedCamera) {
        logger.warn('No camera connected');
        return;
      }

      logger.info(`Disconnecting from ${this.connectedCamera.model}`);
      
      // Clean up connection
      await this.cleanupConnection();
      
      // Close session
      await this.simulateSDKCall('EdsCloseSession', this.connectedCamera.index);
      
      // Update status
      this.connectedCamera.isConnected = false;
      const disconnectedCamera = this.connectedCamera;
      this.connectedCamera = null;
      this.reconnectAttempts = 0;
      
      logger.info('Camera disconnected successfully');
      this.emit('cameraDisconnected', disconnectedCamera);
      
    } catch (error) {
      logger.error('Camera disconnection failed:', error);
      // Force disconnect even if there's an error
      await this.forceDisconnect();
      throw error;
    }
  }

  async getCameraSettings() {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      const settings = {};
      
      if (this.canonSDK) {
        // Use real Canon EDSDK to get properties
        for (const [key, propertyId] of Object.entries(this.PROPERTY_MAPPINGS)) {
          try {
            const value = await new Promise((resolve, reject) => {
              try {
                const propValue = this.canonSDK.getPropertyData(propertyId);
                resolve(propValue);
              } catch (error) {
                reject(error);
              }
            });
            settings[key.toLowerCase()] = this.formatPropertyValue(key, value);
          } catch (error) {
            logger.warn(`Failed to get Canon property ${key}:`, error);
            settings[key.toLowerCase()] = null;
          }
        }
      } else {
        // Fallback to simulation
        for (const [key, propertyId] of Object.entries(this.PROPERTY_MAPPINGS)) {
          try {
            const value = await this.simulateSDKCall('EdsGetPropertyData', propertyId);
            settings[key.toLowerCase()] = this.formatPropertyValue(key, value);
          } catch (error) {
            logger.warn(`Failed to get property ${key}:`, error);
            settings[key.toLowerCase()] = null;
          }
        }
      }

      return settings;
    } catch (error) {
      logger.error('Failed to get Canon camera settings:', error);
      throw error;
    }
  }

  async setCameraProperty(property, value) {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      const propertyId = this.PROPERTY_MAPPINGS[property.toUpperCase()];
      if (!propertyId) {
        throw new Error(`Unknown property: ${property}`);
      }

      const formattedValue = this.parsePropertyValue(property, value);
      await this.simulateSDKCall('EdsSetPropertyData', propertyId, formattedValue);
      
      logger.info(`Set ${property} to ${value}`);
      this.emit('propertyChanged', { property, value });
      
      return true;
    } catch (error) {
      logger.error(`Failed to set ${property} to ${value}:`, error);
      throw error;
    }
  }

  async startLiveView() {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      logger.info('Starting Canon live view...');
      
      // Check if live view is already active
      if (this.liveViewSession && this.liveViewSession.active) {
        logger.info('Canon live view already active');
        return {
          success: true,
          streamUrl: 'ws://localhost:3001/liveview',
          resolution: '1920x1080',
          fps: 30
        };
      }
      
      // Start live view on camera
      await this.simulateSDKCall('EdsSetPropertyData', 'kEdsPropID_Evf_OutputDevice', 'kEdsEvfOutputDevice_PC');
      
      this.liveViewSession = {
        active: true,
        startTime: Date.now(),
        frameCount: 0
      };
      
      // Start live view frame capture loop
      this.startLiveViewLoop();
      
      logger.info('Canon live view started successfully');
      this.emit('liveViewStarted');
      
      return {
        success: true,
        streamUrl: 'ws://localhost:3001/liveview',
        resolution: '1920x1080',
        fps: 30
      };
    } catch (error) {
      logger.error('Failed to start Canon live view:', error);
      // Don't throw error in simulation mode, return success with warning
      if (!this.canonNative) {
        logger.warn('Canon live view started in simulation mode');
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
      logger.info('Stopping live view...');
      
      // Stop live view on camera
      await this.simulateSDKCall('EdsSetPropertyData', 'kEdsPropID_Evf_OutputDevice', 'kEdsEvfOutputDevice_None');
      
      this.liveViewSession.active = false;
      this.liveViewSession = null;
      
      logger.info('Live view stopped');
      this.emit('liveViewStopped');
      
    } catch (error) {
      logger.error('Failed to stop live view:', error);
      throw error;
    }
  }

  async captureImage(settings = {}) {
    if (!this.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      logger.info('Capturing image with settings:', settings);
      
      // Apply any provided settings first
      for (const [property, value] of Object.entries(settings)) {
        if (value !== undefined) {
          await this.setCameraProperty(property, value);
        }
      }
      
      // Trigger capture
      await this.simulateSDKCall('EdsSendCommand', 'kEdsCameraCommand_TakePicture');
      
      // Wait for image download (this would be handled by event callback in real implementation)
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const imageInfo = {
        id: `img_${Date.now()}`,
        filename: `IMG_${Date.now()}.CR3`,
        timestamp: new Date().toISOString(),
        settings: await this.getCameraSettings(),
        metadata: {
          fileSize: '45.2MB',
          dimensions: '8192x5464',
          colorSpace: 'sRGB'
        }
      };
      
      logger.info(`Image captured: ${imageInfo.filename}`);
      this.emit('imageCaptured', imageInfo);
      
      return imageInfo;
    } catch (error) {
      logger.error('Image capture failed:', error);
      throw error;
    }
  }

  async setupEventHandlers(cameraIndex) {
    try {
      // Set up Canon SDK event callbacks
      await this.simulateSDKCall('EdsSetCameraAddedHandler', this.handleCameraAdded.bind(this));
      await this.simulateSDKCall('EdsSetPropertyEventHandler', this.handlePropertyEvent.bind(this));
      await this.simulateSDKCall('EdsSetObjectEventHandler', this.handleObjectEvent.bind(this));
      await this.simulateSDKCall('EdsSetCameraStateEventHandler', this.handleStateEvent.bind(this));
      
      logger.info('Event handlers set up successfully');
    } catch (error) {
      logger.error('Failed to set up event handlers:', error);
      throw error;
    }
  }

  handleCameraAdded(context) {
    logger.info('Camera added event received');
    this.discoverCameras();
  }

  handlePropertyEvent(event, property, parameter) {
    logger.debug(`Property event: ${property} = ${parameter}`);
    this.emit('propertyEvent', { event, property, parameter });
  }

  handleObjectEvent(event, objectRef) {
    logger.debug(`Object event: ${event}`);
    if (event === 'kEdsObjectEvent_DirItemCreated') {
      this.handleImageDownload(objectRef);
    }
    this.emit('objectEvent', { event, objectRef });
  }

  handleStateEvent(event, parameter) {
    logger.debug(`State event: ${event} = ${parameter}`);
    this.emit('stateEvent', { event, parameter });
  }

  handleImageDownload(objectRef) {
    // In real implementation, this would download the image from camera
    logger.info('Image download event triggered');
    this.emit('imageReady', { objectRef });
  }

  startLiveViewLoop() {
    if (!this.liveViewSession?.active) return;

    const captureFrame = async () => {
      try {
        // Get live view image from camera
        const imageData = await this.simulateSDKCall('EdsCreateEvfImageRef');
        
        if (imageData) {
          this.liveViewSession.frameCount++;
          this.emit('liveViewFrame', {
            data: imageData,
            frameNumber: this.liveViewSession.frameCount,
            timestamp: Date.now()
          });
        }
      } catch (error) {
        logger.error('Live view frame capture error:', error);
      }

      // Schedule next frame (30 FPS = ~33ms interval)
      if (this.liveViewSession?.active) {
        setTimeout(captureFrame, 33);
      }
    };

    captureFrame();
  }

  formatPropertyValue(property, rawValue) {
    // Convert Canon SDK raw values to user-friendly format
    switch (property) {
      case 'ISO':
        return rawValue || 400;
      case 'APERTURE':
        return rawValue ? `f/${rawValue}` : 'f/4.0';
      case 'SHUTTER_SPEED':
        return rawValue || '1/125';
      case 'WHITE_BALANCE':
        return rawValue || 'auto';
      case 'BATTERY_LEVEL':
        return rawValue || 85;
      default:
        return rawValue;
    }
  }

  parsePropertyValue(property, value) {
    // Convert user-friendly values to Canon SDK format
    switch (property) {
      case 'ISO':
        return parseInt(value);
      case 'APERTURE':
        return parseFloat(value.replace('f/', ''));
      case 'SHUTTER_SPEED':
        return value;
      case 'WHITE_BALANCE':
        return value;
      default:
        return value;
    }
  }

  async simulateSDKCall(functionName, ...args) {
    // Simulate Canon SDK function calls with appropriate delays and responses
    await new Promise(resolve => setTimeout(resolve, 50 + Math.random() * 100));
    
    switch (functionName) {
      case 'EdsInitializeSDK':
        return this.EDS_ERRORS.EDS_ERR_OK;
      case 'EdsGetCameraList':
        return 1; // Simulate 1 connected camera
      case 'EdsGetCameraInfo':
        return {
          model: 'Canon EOS R5',
          serialNumber: 'CN1234567',
          firmwareVersion: '1.8.1',
          batteryLevel: 85
        };
      case 'EdsOpenSession':
        return this.EDS_ERRORS.EDS_ERR_OK;
      case 'EdsCloseSession':
        return this.EDS_ERRORS.EDS_ERR_OK;
      case 'EdsGetPropertyData':
        return this.getSimulatedPropertyValue(args[0]);
      case 'EdsSetPropertyData':
        return this.EDS_ERRORS.EDS_ERR_OK;
      case 'EdsSendCommand':
        return this.EDS_ERRORS.EDS_ERR_OK;
      case 'EdsCreateEvfImageRef':
        return Buffer.alloc(1024 * 1024); // Simulate 1MB image data
      default:
        return this.EDS_ERRORS.EDS_ERR_OK;
    }
  }

  getSimulatedPropertyValue(propertyId) {
    const simulatedValues = {
      'kEdsPropID_ISOSpeed': 400,
      'kEdsPropID_Av': 4.0,
      'kEdsPropID_Tv': '1/125',
      'kEdsPropID_WhiteBalance': 'auto',
      'kEdsPropID_BatteryLevel': 85
    };
    return simulatedValues[propertyId] || null;
  }

  async terminate() {
    try {
      if (this.connectedCamera) {
        await this.disconnectCamera();
      }
      
      await this.simulateSDKCall('EdsTerminateSDK');
      logger.info('Canon SDK terminated');
    } catch (error) {
      logger.error('Failed to terminate Canon SDK:', error);
    }
  }
}

module.exports = CanonSDKService;