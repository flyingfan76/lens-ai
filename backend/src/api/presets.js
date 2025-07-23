const express = require('express');
const multer = require('multer');
const StylePresetService = require('../services/style_preset_service');
const logger = require('../utils/logger');

const router = express.Router();
const presetService = new StylePresetService();

// Configure multer for image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  }
});

// Get all presets with filtering and sorting
router.get('/', async (req, res) => {
  try {
    const filters = {
      category: req.query.category,
      type: req.query.type,
      sceneType: req.query.scene_type,
      lightingCondition: req.query.lighting_condition,
      difficulty: req.query.difficulty,
      featured: req.query.featured === 'true',
      sortBy: req.query.sort_by || 'popularity',
      limit: parseInt(req.query.limit) || 50
    };
    
    const presets = await presetService.getAllPresets(filters);
    res.json({
      success: true,
      count: presets.length,
      data: presets
    });
  } catch (error) {
    logger.error('Failed to get presets:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to retrieve presets' 
    });
  }
});

// Get featured presets
router.get('/featured', async (req, res) => {
  try {
    const presets = await presetService.getAllPresets({ 
      featured: true,
      limit: parseInt(req.query.limit) || 10
    });
    
    res.json({
      success: true,
      data: presets
    });
  } catch (error) {
    logger.error('Failed to get featured presets:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to retrieve featured presets' 
    });
  }
});

// Get preset by ID
router.get('/:presetId', async (req, res) => {
  try {
    const preset = await presetService.getPresetById(req.params.presetId);
    res.json({
      success: true,
      data: preset
    });
  } catch (error) {
    logger.error(`Failed to get preset ${req.params.presetId}:`, error);
    res.status(404).json({ 
      success: false,
      error: 'Preset not found' 
    });
  }
});

// Get recommended presets based on scene analysis
router.post('/recommend', async (req, res) => {
  try {
    const { analysis, userPreferences = {} } = req.body;
    
    if (!analysis) {
      return res.status(400).json({
        success: false,
        error: 'Scene analysis data required'
      });
    }
    
    const recommendations = await presetService.getRecommendedPresets(
      analysis, 
      userPreferences
    );
    
    res.json({
      success: true,
      count: recommendations.length,
      data: recommendations
    });
  } catch (error) {
    logger.error('Failed to get preset recommendations:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to generate recommendations' 
    });
  }
});

// Search presets
router.get('/search/:term', async (req, res) => {
  try {
    const searchTerm = req.params.term;
    const filters = {
      category: req.query.category,
      limit: parseInt(req.query.limit) || 20
    };
    
    const presets = await presetService.searchPresets(searchTerm, filters);
    
    res.json({
      success: true,
      query: searchTerm,
      count: presets.length,
      data: presets
    });
  } catch (error) {
    logger.error('Failed to search presets:', error);
    res.status(500).json({ 
      success: false,
      error: 'Search failed' 
    });
  }
});

// Create new user preset
router.post('/', upload.single('thumbnail'), async (req, res) => {
  try {
    const userId = req.user?.id; // Assumes authentication middleware
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }
    
    const presetData = {
      ...req.body,
      settings: JSON.parse(req.body.settings || '{}'),
      tags: JSON.parse(req.body.tags || '[]'),
      sceneTypes: JSON.parse(req.body.sceneTypes || '[]'),
      lightingConditions: JSON.parse(req.body.lightingConditions || '[]')
    };
    
    // Handle thumbnail upload if provided
    if (req.file) {
      // In production, upload to cloud storage
      presetData.thumbnail = `/uploads/presets/${Date.now()}-${req.file.originalname}`;
    }
    
    const preset = await presetService.createUserPreset(userId, presetData);
    
    res.status(201).json({
      success: true,
      data: preset
    });
  } catch (error) {
    logger.error('Failed to create preset:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to create preset' 
    });
  }
});

// Update preset
router.put('/:presetId', async (req, res) => {
  try {
    const userId = req.user?.id;
    const presetId = req.params.presetId;
    
    // Check if user owns the preset (in production)
    const existingPreset = await presetService.getPresetById(presetId);
    if (existingPreset.metadata.createdBy && 
        existingPreset.metadata.createdBy.toString() !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Not authorized to update this preset'
      });
    }
    
    const updateData = { ...req.body };
    if (req.body.settings) {
      updateData.settings = JSON.parse(req.body.settings);
    }
    
    const preset = await presetService.updatePreset(presetId, updateData);
    
    res.json({
      success: true,
      data: preset
    });
  } catch (error) {
    logger.error(`Failed to update preset ${req.params.presetId}:`, error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update preset' 
    });
  }
});

// Delete preset (soft delete)
router.delete('/:presetId', async (req, res) => {
  try {
    const userId = req.user?.id;
    const presetId = req.params.presetId;
    
    // Check if user owns the preset (in production)
    const existingPreset = await presetService.getPresetById(presetId);
    if (existingPreset.metadata.createdBy && 
        existingPreset.metadata.createdBy.toString() !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Not authorized to delete this preset'
      });
    }
    
    await presetService.deletePreset(presetId);
    
    res.json({
      success: true,
      message: 'Preset deleted successfully'
    });
  } catch (error) {
    logger.error(`Failed to delete preset ${req.params.presetId}:`, error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to delete preset' 
    });
  }
});

// Record preset usage
router.post('/:presetId/use', async (req, res) => {
  try {
    const preset = await presetService.incrementPresetUsage(req.params.presetId);
    res.json({
      success: true,
      data: {
        id: preset.id,
        usageCount: preset.metadata.usageCount
      }
    });
  } catch (error) {
    logger.error(`Failed to record usage for preset ${req.params.presetId}:`, error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to record usage' 
    });
  }
});

// Rate preset
router.post('/:presetId/rate', async (req, res) => {
  try {
    const { rating } = req.body;
    
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        error: 'Rating must be between 1 and 5'
      });
    }
    
    const preset = await presetService.ratePreset(req.params.presetId, rating);
    
    res.json({
      success: true,
      data: {
        id: preset.id,
        averageRating: preset.metadata.rating.average,
        totalRatings: preset.metadata.rating.count
      }
    });
  } catch (error) {
    logger.error(`Failed to rate preset ${req.params.presetId}:`, error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to rate preset' 
    });
  }
});

// Get preset statistics
router.get('/stats/overview', async (req, res) => {
  try {
    const stats = await presetService.getPresetStatistics();
    
    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Failed to get preset statistics:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to retrieve statistics' 
    });
  }
});

// Initialize built-in presets (admin endpoint)
router.post('/admin/initialize', async (req, res) => {
  try {
    // Add admin authentication check here
    await presetService.initializeBuiltInPresets();
    
    res.json({
      success: true,
      message: 'Built-in presets initialized successfully'
    });
  } catch (error) {
    logger.error('Failed to initialize built-in presets:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to initialize presets' 
    });
  }
});

module.exports = router;