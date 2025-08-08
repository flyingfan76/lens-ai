const express = require('express');
const logger = require('../utils/logger');
const CameraManager = require('../services/camera_manager');

const router = express.Router();
const cameraManager = new CameraManager();

// Set up Camera Manager event handlers for WebSocket integration
// We'll set up the WebSocket service connection after router is attached to app

cameraManager.on('cameraConnected', (data) => {
  logger.info(`Camera connected: ${data.brand} ${data.camera.model}`);
});

cameraManager.on('cameraDisconnected', (data) => {
  logger.info(`Camera disconnected: ${data.brand} ${data.camera.model}`);
});

cameraManager.on('cameraError', (errorInfo) => {
  logger.error(`Camera error [${errorInfo.brand}]:`, errorInfo);
});

// Initialize Camera Manager on startup
(async () => {
  try {
    const result = await cameraManager.initialize();
    logger.info('Camera Manager initialized:', result);
  } catch (error) {
    logger.error('Camera Manager initialization failed:', error);
  }
})();

// Camera discovery endpoint
router.get('/discover', async (req, res) => {
  try {
    logger.info('Discovering available cameras from all brands...');
    
    // Try auto-detection first
    let cameras;
    try {
      cameras = await cameraManager.discoverAllCameras();
    } catch (autoDetectError) {
      logger.warn('Auto-detection failed, using available cameras list:', autoDetectError);
      cameras = cameraManager.availableCameras || [];
    }
    
    // If no cameras found via auto-detection, include manually registered cameras
    if (cameras.length === 0 && cameraManager.availableCameras) {
      cameras = cameraManager.availableCameras;
      logger.info(`Using ${cameras.length} manually registered cameras`);
    }
    
    res.json({
      success: true,
      cameras: cameras.map(camera => ({
        id: camera.id,
        brand: camera.brand,
        model: camera.model,
        serialNumber: camera.serialNumber,
        firmwareVersion: camera.firmwareVersion,
        batteryLevel: camera.batteryLevel,
        isConnected: camera.isConnected,
        connectionType: camera.connectionType,
        modelInfo: camera.modelInfo,
        detectionMethod: camera.detectionMethod,
        autoConfig: camera.autoConfig,
        connectionQuality: camera.connectionQuality,
        compatibilityScore: camera.compatibilityScore,
        capabilities: camera.capabilities || {
          liveView: true,
          remoteCapture: true,
          bulbMode: true,
          videoRecording: true
        }
      }))
    });
  } catch (error) {
    logger.error('Camera discovery error:', error);
    res.status(500).json({ error: 'Failed to discover cameras' });
  }
});

// Manual camera registration for testing (when auto-detection fails)
router.post('/register-test-camera', async (req, res) => {
  try {
    logger.info('Manually registering test camera for development...');
    
    // Create a test camera entry
    const testCamera = {
      id: 'nikon_000009171582_test',
      brand: 'nikon',
      model: 'NIKON DSC D90',
      serialNumber: '000009171582',
      connectionType: 'usb',
      isConnected: false,
      detectionMethod: 'manual_test',
      connectionQuality: 0.9,
      compatibilityScore: 1,
      capabilities: {
        liveView: true,
        remoteCapture: true,
        settingsControl: true,
        wifi: false,
        bluetooth: false,
        touchScreen: false,
        weather_sealing: false
      },
      modelInfo: {
        series: 'D90',
        type: 'dslr',
        level: 'enthusiast',
        matched: 'DSC D90',
        fullModel: 'NIKON DSC D90'
      },
      autoConfig: {
        userLevel: 'enthusiast',
        profile: {
          priority: ['image_quality', 'manual_control', 'creative_features'],
          recommended_modes: ['Aperture Priority', 'Manual'],
          settings: {
            image_quality: 'RAW+JPEG',
            metering_mode: 'Matrix',
            focus_mode: 'Single'
          }
        }
      }
    };
    
    // Initialize available cameras array if needed
    if (!cameraManager.availableCameras) {
      cameraManager.availableCameras = [];
    }
    
    // Remove any existing test camera with same ID
    cameraManager.availableCameras = cameraManager.availableCameras.filter(
      camera => camera.id !== testCamera.id
    );
    
    // Add new test camera
    cameraManager.availableCameras.push(testCamera);
    
    logger.info(`Available cameras count: ${cameraManager.availableCameras.length}`);
    
    logger.info('Test camera registered successfully');
    
    res.json({
      success: true,
      message: 'Test camera registered for development',
      camera: testCamera
    });
    
  } catch (error) {
    logger.error('Test camera registration error:', error);
    res.status(500).json({ error: 'Failed to register test camera' });
  }
});

// Debug endpoint to see available cameras
router.get('/debug/available', (req, res) => {
  try {
    const cameras = cameraManager.availableCameras || [];
    res.json({
      success: true,
      count: cameras.length,
      cameras: cameras.map(camera => ({
        id: camera.id,
        brand: camera.brand,
        model: camera.model,
        detectionMethod: camera.detectionMethod,
        connectionType: camera.connectionType
      }))
    });
  } catch (error) {
    logger.error('Debug cameras error:', error);
    res.status(500).json({ error: 'Failed to get debug info' });
  }
});

// Get camera manager status
router.get('/status', (req, res) => {
  try {
    const status = cameraManager.getStatus();
    const connectedCameras = cameraManager.getConnectedCameras();
    
    res.json({
      success: true,
      status: {
        ...status,
        connectedCameras
      }
    });
  } catch (error) {
    logger.error('Error getting camera status:', error);
    res.status(500).json({ error: 'Failed to get camera status' });
  }
});

// Camera connection endpoints
router.post('/connect', async (req, res) => {
  try {
    const { cameraId } = req.body;
    
    if (!cameraId) {
      return res.status(400).json({ error: 'Camera ID is required' });
    }
    
    logger.info(`Attempting to connect to camera: ${cameraId}`);
    
    const result = await cameraManager.connectToCamera(cameraId);
    
    res.json({
      success: true,
      cameraId: result.cameraId,
      cameraInfo: {
        id: result.cameraInfo.id,
        brand: result.cameraInfo.brand,
        model: result.cameraInfo.model,
        serialNumber: result.cameraInfo.serialNumber,
        firmware: result.cameraInfo.firmwareVersion,
        batteryLevel: result.cameraInfo.batteryLevel,
        memoryCard: {
          total: '64GB',
          used: '12GB',
          available: '52GB'
        }
      },
      capabilities: result.cameraInfo.capabilities || {
        liveView: true,
        remoteCapture: true,
        bulbMode: true,
        videoRecording: true
      }
    });
  } catch (error) {
    logger.error('Camera connection error:', error);
    res.status(500).json({ error: 'Failed to connect to camera' });
  }
});

// Set active camera
router.post('/set-active', async (req, res) => {
  try {
    const { cameraId } = req.body;
    
    if (!cameraId) {
      return res.status(400).json({ error: 'Camera ID is required' });
    }
    
    const result = await cameraManager.setActiveCamera(cameraId);
    
    res.json(result);
  } catch (error) {
    logger.error('Set active camera error:', error);
    res.status(500).json({ error: 'Failed to set active camera' });
  }
});

router.post('/disconnect', async (req, res) => {
  try {
    const { cameraId } = req.body;
    
    if (cameraId) {
      logger.info(`Disconnecting camera: ${cameraId}`);
      await cameraManager.disconnectCamera(cameraId);
    } else {
      logger.info('Disconnecting all cameras');
      await cameraManager.disconnectAllCameras();
    }
    
    res.json({ success: true, message: 'Camera(s) disconnected' });
  } catch (error) {
    logger.error('Camera disconnection error:', error);
    res.status(500).json({ error: 'Failed to disconnect camera' });
  }
});

// Camera settings endpoints
router.get('/settings', async (req, res) => {
  try {
    const { cameraId } = req.query;
    const result = await cameraManager.getCameraSettings(cameraId);
    
    res.json({
      success: true,
      cameraId: result.cameraId,
      brand: result.brand,
      settings: {
        ...result.settings,
        focusMode: 'single',
        meteringMode: 'matrix',
        imageQuality: result.brand === 'nikon' ? 'NEF+JPEG' : 'RAW+JPEG',
        colorSpace: result.brand === 'nikon' ? 'Adobe RGB' : 'sRGB'
      }
    });
  } catch (error) {
    logger.error('Error getting camera settings:', error);
    res.status(500).json({ error: 'Failed to get camera settings' });
  }
});

router.put('/settings', async (req, res) => {
  try {
    const { cameraId, settings } = req.body;
    
    logger.info('Updating camera settings:', { cameraId, settings });
    
    // Apply each setting to the camera
    const appliedSettings = {};
    for (const [property, value] of Object.entries(settings)) {
      try {
        await cameraManager.setCameraProperty(property, value, cameraId);
        appliedSettings[property] = value;
      } catch (error) {
        logger.warn(`Failed to set ${property} to ${value}:`, error);
      }
    }
    
    res.json({
      success: true,
      cameraId: cameraId || cameraManager.activeCameraId,
      appliedSettings,
      message: 'Camera settings updated'
    });
  } catch (error) {
    logger.error('Error updating camera settings:', error);
    res.status(500).json({ error: 'Failed to update camera settings' });
  }
});

// Live view endpoints
router.get('/liveview/start', async (req, res) => {
  try {
    const { cameraId } = req.query;
    logger.info('Starting live view', { cameraId });
    
    const result = await cameraManager.startLiveView(cameraId);
    
    // Notify WebSocket service that live view has started
    const webSocketService = res.app.locals.webSocketService;
    if (webSocketService) {
      webSocketService.startLiveViewStream();
    }
    
    res.json({
      success: true,
      cameraId: result.cameraId,
      brand: result.brand,
      ...result,
      // Override streamUrl to use the correct port (spread result first, then override)
      streamUrl: `ws://localhost:${process.env.PORT || 3000}/liveview`
    });
  } catch (error) {
    logger.error('Error starting live view:', error);
    res.status(500).json({ error: 'Failed to start live view' });
  }
});

router.get('/liveview/stop', async (req, res) => {
  try {
    const { cameraId } = req.query;
    logger.info('Stopping live view', { cameraId });
    
    const result = await cameraManager.stopLiveView(cameraId);
    
    // Notify WebSocket service that live view has stopped
    const webSocketService = res.app.locals.webSocketService;
    if (webSocketService) {
      webSocketService.stopLiveViewStream();
    }
    
    res.json({
      success: true,
      cameraId: result.cameraId,
      brand: result.brand,
      message: 'Live view stopped'
    });
  } catch (error) {
    logger.error('Error stopping live view:', error);
    res.status(500).json({ error: 'Failed to stop live view' });
  }
});

router.post('/capture', async (req, res) => {
  try {
    const { cameraId, settings = {} } = req.body;
    
    logger.info('Capturing image', { cameraId, settings });
    
    const captureResult = await cameraManager.captureImage(settings, cameraId);
    
    res.json({
      success: true,
      cameraId: captureResult.cameraId,
      brand: captureResult.brand,
      imageId: captureResult.id,
      filename: captureResult.filename,
      metadata: {
        timestamp: captureResult.timestamp,
        settings: captureResult.settings,
        fileSize: captureResult.metadata.fileSize,
        dimensions: captureResult.metadata.dimensions,
        format: captureResult.metadata.format || (captureResult.brand === 'nikon' ? 'NEF' : 'CR3')
      }
    });
  } catch (error) {
    logger.error('Error capturing image:', error);
    res.status(500).json({ error: 'Failed to capture image' });
  }
});

function validateCameraSettings(settings) {
  const validated = {};
  
  if (settings.iso && settings.iso >= 100 && settings.iso <= 25600) {
    validated.iso = settings.iso;
  }
  
  if (settings.aperture && /^f\/\d+(\.\d+)?$/.test(settings.aperture)) {
    validated.aperture = settings.aperture;
  }
  
  if (settings.shutterSpeed) {
    validated.shutterSpeed = settings.shutterSpeed;
  }
  
  if (settings.whiteBalance) {
    validated.whiteBalance = settings.whiteBalance;
  }
  
  return validated;
}

// Export both router and camera manager for WebSocket integration
router.cameraManager = cameraManager;
module.exports = router;