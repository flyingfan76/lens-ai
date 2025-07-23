const EventEmitter = require('events');
const CanonSDKService = require('./canon_sdk_service');
const NikonSDKService = require('./nikon_sdk_service');
const SonySDKService = require('./sony_sdk_service');
const logger = require('../utils/logger');

class CameraManager extends EventEmitter {
  constructor() {
    super();
    
    // SDK instances
    this.canonSDK = new CanonSDKService();
    this.nikonSDK = new NikonSDKService();
    this.sonySDK = new SonySDKService();
    
    // State management
    this.isInitialized = false;
    this.availableCameras = [];
    this.connectedCameras = new Map(); // cameraId -> {sdk, camera}
    this.activeCameraId = null;
    
    // Supported brands
    this.supportedBrands = {
      CANON: 'canon',
      NIKON: 'nikon',
      SONY: 'sony'
    };
    
    this.setupEventHandlers();
  }

  setupEventHandlers() {
    // Canon SDK events
    this.canonSDK.on('camerasDiscovered', (cameras) => {
      this.updateCameraList('canon', cameras);
    });
    
    this.canonSDK.on('cameraConnected', (camera) => {
      this.handleCameraConnected('canon', camera);
    });
    
    this.canonSDK.on('cameraDisconnected', (camera) => {
      this.handleCameraDisconnected('canon', camera);
    });
    
    this.canonSDK.on('liveViewFrame', (frameData) => {
      this.emit('liveViewFrame', frameData);
    });
    
    this.canonSDK.on('imageCaptured', (imageInfo) => {
      this.emit('imageCaptured', { ...imageInfo, brand: 'canon' });
    });
    
    this.canonSDK.on('cameraError', (errorInfo) => {
      this.emit('cameraError', { ...errorInfo, brand: 'canon' });
    });

    // Nikon SDK events
    this.nikonSDK.on('camerasDiscovered', (cameras) => {
      this.updateCameraList('nikon', cameras);
    });
    
    this.nikonSDK.on('cameraConnected', (camera) => {
      this.handleCameraConnected('nikon', camera);
    });
    
    this.nikonSDK.on('cameraDisconnected', (camera) => {
      this.handleCameraDisconnected('nikon', camera);
    });
    
    this.nikonSDK.on('liveViewFrame', (frameData) => {
      this.emit('liveViewFrame', frameData);
    });
    
    this.nikonSDK.on('imageCaptured', (imageInfo) => {
      this.emit('imageCaptured', { ...imageInfo, brand: 'nikon' });
    });
    
    this.nikonSDK.on('cameraError', (errorInfo) => {
      this.emit('cameraError', { ...errorInfo, brand: 'nikon' });
    });
  }

  async initialize() {
    try {
      logger.info('Initializing Camera Manager...');
      
      // Initialize SDKs with timeout
      const initPromises = [
        Promise.race([
          this.canonSDK.initialize(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Canon SDK initialization timeout')), 10000))
        ]).catch(err => {
          logger.warn('Canon SDK initialization failed:', err);
          return false;
        }),
        Promise.race([
          this.nikonSDK.initialize(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Nikon SDK initialization timeout')), 10000))
        ]).catch(err => {
          logger.warn('Nikon SDK initialization failed:', err);
          return false;
        }),
        Promise.race([
          this.sonySDK.initialize(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Sony SDK initialization timeout')), 10000))
        ]).catch(err => {
          logger.warn('Sony SDK initialization failed:', err);
          return false;
        })
      ];
      
      const results = await Promise.all(initPromises);
      const canonInitialized = results[0];
      const nikonInitialized = results[1];
      const sonyInitialized = results[2];
      
      if (!canonInitialized && !nikonInitialized && !sonyInitialized) {
        throw new Error('Failed to initialize any camera SDKs');
      }
      
      this.isInitialized = true;
      
      logger.info(`Camera Manager initialized - Canon: ${canonInitialized}, Nikon: ${nikonInitialized}, Sony: ${sonyInitialized}`);
      
      return {
        success: true,
        canonSupported: canonInitialized,
        nikonSupported: nikonInitialized,
        sonySupported: sonyInitialized
      };
    } catch (error) {
      logger.error('Failed to initialize Camera Manager:', error);
      throw error;
    }
  }

  async discoverAllCameras() {
    if (!this.isInitialized) {
      throw new Error('Camera Manager not initialized');
    }

    try {
      logger.info('Discovering cameras from all brands...');
      
      // Discover cameras with timeout and parallel execution
      const discoveryPromises = [
        Promise.race([
          this.canonSDK.discoverCameras(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Canon discovery timeout')), 5000))
        ]).catch(err => {
          logger.warn('Canon camera discovery failed:', err);
          return [];
        }),
        Promise.race([
          this.nikonSDK.discoverCameras(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Nikon discovery timeout')), 5000))
        ]).catch(err => {
          logger.warn('Nikon camera discovery failed:', err);
          return [];
        }),
        Promise.race([
          this.sonySDK.discoverCameras(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Sony discovery timeout')), 5000))
        ]).catch(err => {
          logger.warn('Sony camera discovery failed:', err);
          return [];
        })
      ];
      
      const results = await Promise.all(discoveryPromises);
      const canonCameras = results[0];
      const nikonCameras = results[1];
      const sonyCameras = results[2];
      
      // Combine and format camera lists
      this.availableCameras = [
        ...canonCameras.map(camera => ({ ...camera, brand: 'canon', id: `canon_${camera.index}` })),
        ...nikonCameras.map(camera => ({ ...camera, brand: 'nikon', id: `nikon_${camera.index}` })),
        ...sonyCameras.map(camera => ({ ...camera, brand: 'sony', id: `sony_${camera.index}` }))
      ];
      
      logger.info(`Discovered ${this.availableCameras.length} total cameras (Canon: ${canonCameras.length}, Nikon: ${nikonCameras.length}, Sony: ${sonyCameras.length})`);
      
      this.emit('allCamerasDiscovered', this.availableCameras);
      
      return this.availableCameras;
    } catch (error) {
      logger.error('Failed to discover cameras:', error);
      throw error;
    }
  }

  updateCameraList(brand, cameras) {
    // Update the unified camera list when individual SDKs discover cameras
    const brandCameras = cameras.map(camera => ({ 
      ...camera, 
      brand, 
      id: `${brand}_${camera.index}` 
    }));
    
    // Remove existing cameras of this brand
    this.availableCameras = this.availableCameras.filter(camera => camera.brand !== brand);
    
    // Add new cameras
    this.availableCameras.push(...brandCameras);
    
    this.emit('cameraListUpdated', this.availableCameras);
  }

  async connectToCamera(cameraId) {
    const camera = this.availableCameras.find(cam => cam.id === cameraId);
    if (!camera) {
      throw new Error(`Camera not found: ${cameraId}`);
    }

    try {
      logger.info(`Connecting to ${camera.brand} camera: ${camera.model}`);
      
      let connectedCamera;
      let sdk;
      
      if (camera.brand === 'canon') {
        sdk = this.canonSDK;
        connectedCamera = await this.canonSDK.connectToCamera(camera.index);
      } else if (camera.brand === 'nikon') {
        sdk = this.nikonSDK;
        connectedCamera = await this.nikonSDK.connectToCamera(camera.index);
      } else {
        throw new Error(`Unsupported camera brand: ${camera.brand}`);
      }
      
      // Store connection info
      this.connectedCameras.set(cameraId, { sdk, camera: connectedCamera, brand: camera.brand });
      this.activeCameraId = cameraId;
      
      logger.info(`Successfully connected to ${camera.brand} camera: ${camera.model}`);
      
      return {
        success: true,
        cameraId,
        cameraInfo: {
          ...connectedCamera,
          brand: camera.brand,
          id: cameraId
        }
      };
    } catch (error) {
      logger.error(`Failed to connect to camera ${cameraId}:`, error);
      throw error;
    }
  }

  async disconnectCamera(cameraId) {
    const connection = this.connectedCameras.get(cameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${cameraId}`);
    }

    try {
      logger.info(`Disconnecting ${connection.brand} camera`);
      
      await connection.sdk.disconnectCamera();
      
      this.connectedCameras.delete(cameraId);
      
      if (this.activeCameraId === cameraId) {
        this.activeCameraId = null;
      }
      
      logger.info(`Disconnected ${connection.brand} camera successfully`);
      
      return { success: true };
    } catch (error) {
      logger.error(`Failed to disconnect camera ${cameraId}:`, error);
      throw error;
    }
  }

  async disconnectAllCameras() {
    const disconnectPromises = [];
    
    for (const [cameraId] of this.connectedCameras) {
      disconnectPromises.push(
        Promise.race([
          this.disconnectCamera(cameraId),
          new Promise((_, reject) => setTimeout(() => reject(new Error(`Disconnect timeout for ${cameraId}`)), 5000))
        ]).catch(error => {
          logger.error(`Failed to disconnect camera ${cameraId}:`, error);
        })
      );
    }
    
    await Promise.all(disconnectPromises);
    
    this.connectedCameras.clear();
    this.activeCameraId = null;
    
    logger.info('All cameras disconnected');
  }

  async setActiveCamera(cameraId) {
    if (!this.connectedCameras.has(cameraId)) {
      throw new Error(`Camera not connected: ${cameraId}`);
    }
    
    this.activeCameraId = cameraId;
    const connection = this.connectedCameras.get(cameraId);
    
    logger.info(`Set active camera to ${connection.brand}: ${connection.camera.model}`);
    
    this.emit('activeCameraChanged', {
      cameraId,
      brand: connection.brand,
      camera: connection.camera
    });
    
    return { success: true, activeCameraId: cameraId };
  }

  getActiveCamera() {
    if (!this.activeCameraId) {
      return null;
    }
    
    const connection = this.connectedCameras.get(this.activeCameraId);
    return connection ? {
      id: this.activeCameraId,
      brand: connection.brand,
      camera: connection.camera,
      sdk: connection.sdk
    } : null;
  }

  async getCameraSettings(cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    if (!targetCameraId) {
      throw new Error('No camera specified and no active camera');
    }
    
    const connection = this.connectedCameras.get(targetCameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }
    
    try {
      const settings = await connection.sdk.getCameraSettings();
      return {
        success: true,
        cameraId: targetCameraId,
        brand: connection.brand,
        settings
      };
    } catch (error) {
      logger.error(`Failed to get settings for camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  async setCameraProperty(property, value, cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    if (!targetCameraId) {
      throw new Error('No camera specified and no active camera');
    }
    
    const connection = this.connectedCameras.get(targetCameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }
    
    try {
      await connection.sdk.setCameraProperty(property, value);
      return {
        success: true,
        cameraId: targetCameraId,
        brand: connection.brand,
        property,
        value
      };
    } catch (error) {
      logger.error(`Failed to set ${property} for camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  async startLiveView(cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    if (!targetCameraId) {
      throw new Error('No camera specified and no active camera');
    }
    
    const connection = this.connectedCameras.get(targetCameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }
    
    try {
      const result = await connection.sdk.startLiveView();
      return {
        ...result,
        cameraId: targetCameraId,
        brand: connection.brand
      };
    } catch (error) {
      logger.error(`Failed to start live view for camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  async stopLiveView(cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    if (!targetCameraId) {
      throw new Error('No camera specified and no active camera');
    }
    
    const connection = this.connectedCameras.get(targetCameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }
    
    try {
      await connection.sdk.stopLiveView();
      return {
        success: true,
        cameraId: targetCameraId,
        brand: connection.brand
      };
    } catch (error) {
      logger.error(`Failed to stop live view for camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  async captureImage(settings = {}, cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    if (!targetCameraId) {
      throw new Error('No camera specified and no active camera');
    }
    
    const connection = this.connectedCameras.get(targetCameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }
    
    try {
      const result = await connection.sdk.captureImage(settings);
      return {
        ...result,
        cameraId: targetCameraId,
        brand: connection.brand
      };
    } catch (error) {
      logger.error(`Failed to capture image with camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  handleCameraConnected(brand, camera) {
    logger.info(`${brand} camera connected: ${camera.model}`);
    this.emit('cameraConnected', { brand, camera });
  }

  handleCameraDisconnected(brand, camera) {
    logger.info(`${brand} camera disconnected: ${camera.model}`);
    
    // Remove from connected cameras
    const cameraId = `${brand}_${camera.index}`;
    this.connectedCameras.delete(cameraId);
    
    if (this.activeCameraId === cameraId) {
      this.activeCameraId = null;
    }
    
    this.emit('cameraDisconnected', { brand, camera });
  }

  getConnectedCameras() {
    const connected = [];
    for (const [cameraId, connection] of this.connectedCameras) {
      connected.push({
        id: cameraId,
        brand: connection.brand,
        camera: connection.camera,
        isActive: cameraId === this.activeCameraId
      });
    }
    return connected;
  }

  getSupportedBrands() {
    return Object.values(this.supportedBrands);
  }

  getStatus() {
    return {
      isInitialized: this.isInitialized,
      availableCameras: this.availableCameras.length,
      connectedCameras: this.connectedCameras.size,
      activeCameraId: this.activeCameraId,
      supportedBrands: this.getSupportedBrands()
    };
  }

  async terminate() {
    try {
      logger.info('Terminating Camera Manager...');
      
      // Disconnect all cameras
      await this.disconnectAllCameras();
      
      // Terminate SDKs
      await Promise.all([
        this.canonSDK.terminate().catch(err => logger.warn('Canon SDK termination error:', err)),
        this.nikonSDK.terminate().catch(err => logger.warn('Nikon SDK termination error:', err))
      ]);
      
      this.isInitialized = false;
      this.availableCameras = [];
      
      logger.info('Camera Manager terminated');
    } catch (error) {
      logger.error('Failed to terminate Camera Manager:', error);
      throw error;
    }
  }
}

module.exports = CameraManager;