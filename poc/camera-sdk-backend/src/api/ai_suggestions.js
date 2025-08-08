const express = require('express');
const AISuggestionService = require('../services/ai_suggestion_service');
const CameraSDKService = require('../services/camera_sdk_service');
const logger = require('../utils/logger');

const router = express.Router();
const aiService = new AISuggestionService();
const cameraService = new CameraSDKService();

// Get AI suggestions based on scene analysis
router.post('/analyze', async (req, res) => {
  try {
    const { imageData, sceneAnalysis, cameraModel } = req.body;
    
    if (!sceneAnalysis) {
      return res.status(400).json({
        success: false,
        error: 'Scene analysis data required'
      });
    }
    
    const result = await aiService.analyzeScene(imageData, sceneAnalysis, cameraModel);
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Failed to analyze scene for AI suggestions:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to generate AI suggestions' 
    });
  }
});

// Apply suggested camera settings via SDK
router.post('/apply-settings', async (req, res) => {
  try {
    const { settings } = req.body;
    
    if (!settings) {
      return res.status(400).json({
        success: false,
        error: 'Camera settings required'
      });
    }
    
    const result = await cameraService.applyCameraSettings(settings);
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Failed to apply camera settings:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to apply camera settings' 
    });
  }
});

// Get current camera settings
router.get('/camera/settings', async (req, res) => {
  try {
    const settings = await cameraService.getCurrentSettings();
    
    res.json({
      success: true,
      data: settings
    });
  } catch (error) {
    logger.error('Failed to get camera settings:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to retrieve camera settings' 
    });
  }
});

// Get connected camera info
router.get('/camera/info', async (req, res) => {
  try {
    const cameraInfo = cameraService.getConnectedCameraInfo();
    const capabilities = cameraService.getCameraCapabilities();
    
    res.json({
      success: true,
      data: {
        camera: cameraInfo,
        capabilities: capabilities
      }
    });
  } catch (error) {
    logger.error('Failed to get camera info:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to retrieve camera information' 
    });
  }
});

// Detect and connect to camera
router.post('/camera/connect', async (req, res) => {
  try {
    const camera = await cameraService.detectConnectedCamera();
    
    res.json({
      success: true,
      data: {
        connected: camera !== null,
        camera: camera
      }
    });
  } catch (error) {
    logger.error('Failed to connect to camera:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to connect to camera' 
    });
  }
});

// Capture photo via SDK
router.post('/camera/capture', async (req, res) => {
  try {
    const result = await cameraService.capturePhoto();
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Failed to capture photo:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to capture photo' 
    });
  }
});

module.exports = router;