const express = require('express');
const multer = require('multer');
const AutoAdjustmentService = require('../services/auto_adjustment_service');
const logger = require('../utils/logger');

const router = express.Router();

// Configure multer for image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Global auto-adjustment service instance
let autoAdjustmentService = null;

// Initialize auto-adjustment service
async function initializeService() {
  if (!autoAdjustmentService) {
    autoAdjustmentService = new AutoAdjustmentService();
    await autoAdjustmentService.initialize();
  }
  return autoAdjustmentService;
}

// Analyze image and get parameter recommendations
router.post('/analyze', upload.single('image'), async (req, res) => {
  try {
    const service = await initializeService();
    
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided'
      });
    }

    const { 
      currentSettings, 
      cameraBrand, 
      mode, 
      userPreferences,
      constraints 
    } = req.body;

    if (!currentSettings) {
      return res.status(400).json({
        success: false,
        error: 'Current camera settings required'
      });
    }

    // Parse JSON fields
    const parsedSettings = JSON.parse(currentSettings);
    const parsedPreferences = userPreferences ? JSON.parse(userPreferences) : {};
    const parsedConstraints = constraints ? JSON.parse(constraints) : {};

    // Mock camera service for API endpoint
    const mockCameraService = {
      connectedCamera: { brand: cameraBrand || 'canon' },
      getCameraSettings: () => Promise.resolve(parsedSettings),
      setCameraProperty: (prop, value) => Promise.resolve(true)
    };

    const options = {
      mode: mode || 'auto',
      userPreferences: parsedPreferences,
      constraints: parsedConstraints
    };

    const result = await service.analyzeAndAdjust(
      req.file.buffer, 
      mockCameraService, 
      options
    );

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Auto-adjustment analysis failed:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Analysis failed'
    });
  }
});

// Get parameter recommendations without image analysis
router.post('/recommend', async (req, res) => {
  try {
    const service = await initializeService();
    
    const {
      sceneType,
      lightingCondition,
      currentSettings,
      cameraBrand,
      mode,
      userPreferences,
      constraints
    } = req.body;

    if (!currentSettings || !sceneType) {
      return res.status(400).json({
        success: false,
        error: 'Current settings and scene type required'
      });
    }

    // Create mock analysis based on provided scene info
    const mockAnalysis = {
      scene_type: sceneType,
      lighting_condition: lightingCondition || 'normal',
      has_faces: sceneType === 'portrait',
      confidence: 0.8,
      timestamp: Date.now()
    };

    const optimizationEngine = service.optimizationEngine;
    const optimizedSettings = await optimizationEngine.optimize({
      analysis: mockAnalysis,
      currentSettings,
      cameraBrand: cameraBrand || 'canon',
      mode: mode || 'auto',
      constraints: constraints || {},
      userPreferences: userPreferences || {}
    });

    const adjustmentsMade = service.calculateAdjustmentsMade(
      currentSettings, 
      optimizedSettings
    );

    res.json({
      success: true,
      data: {
        originalSettings: currentSettings,
        optimizedSettings,
        adjustmentsMade,
        sceneAnalysis: mockAnalysis,
        recommendations: service.generateRecommendations(mockAnalysis, optimizedSettings)
      }
    });

  } catch (error) {
    logger.error('Parameter recommendation failed:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Recommendation failed'
    });
  }
});

// Start real-time adjustment session
router.post('/realtime/start', async (req, res) => {
  try {
    const service = await initializeService();
    const { cameraBrand, sessionId } = req.body;

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        error: 'Session ID required'
      });
    }

    // Mock camera service for real-time session
    const mockCameraService = {
      connectedCamera: { brand: cameraBrand || 'canon' },
      liveViewSession: true,
      getCameraSettings: async () => ({
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125',
        white_balance: 'auto'
      }),
      setCameraProperty: (prop, value) => {
        logger.debug(`Mock camera: Set ${prop} to ${value}`);
        return Promise.resolve(true);
      },
      startLiveView: () => Promise.resolve(true),
      on: (event, callback) => {
        // Mock live view frames
        if (event === 'liveViewFrame') {
          const interval = setInterval(() => {
            callback({
              data: Buffer.alloc(1024), // Mock frame data
              timestamp: Date.now()
            });
          }, 1000);
          
          // Store interval for cleanup (in production, use session management)
          global.mockLiveViewIntervals = global.mockLiveViewIntervals || new Map();
          global.mockLiveViewIntervals.set(sessionId, interval);
        }
      },
      removeAllListeners: (event) => {
        if (global.mockLiveViewIntervals?.has(sessionId)) {
          clearInterval(global.mockLiveViewIntervals.get(sessionId));
          global.mockLiveViewIntervals.delete(sessionId);
        }
      }
    };

    const options = {
      interval: req.body.interval || 2000,
      sessionId
    };

    await service.startRealtimeAdjustment(mockCameraService, options);

    res.json({
      success: true,
      message: 'Real-time adjustment started',
      sessionId
    });

  } catch (error) {
    logger.error('Failed to start real-time adjustment:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to start real-time adjustment'
    });
  }
});

// Stop real-time adjustment session
router.post('/realtime/stop', async (req, res) => {
  try {
    const service = await initializeService();
    const { sessionId } = req.body;

    await service.stopRealtimeAdjustment();

    // Clean up mock intervals
    if (global.mockLiveViewIntervals?.has(sessionId)) {
      clearInterval(global.mockLiveViewIntervals.get(sessionId));
      global.mockLiveViewIntervals.delete(sessionId);
    }

    res.json({
      success: true,
      message: 'Real-time adjustment stopped'
    });

  } catch (error) {
    logger.error('Failed to stop real-time adjustment:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to stop real-time adjustment'
    });
  }
});

// Get user preferences for auto-adjustment
router.get('/preferences/:userId?', async (req, res) => {
  try {
    const service = await initializeService();
    const userId = req.params.userId || 'default';
    
    const preferences = service.getUserPreferences(userId);
    
    res.json({
      success: true,
      data: preferences
    });

  } catch (error) {
    logger.error('Failed to get user preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve preferences'
    });
  }
});

// Update user preferences for auto-adjustment
router.put('/preferences/:userId?', async (req, res) => {
  try {
    const service = await initializeService();
    const userId = req.params.userId || 'default';
    const preferences = req.body;

    // Validate preferences
    const validPreferences = {
      preferLowISO: Boolean(preferences.preferLowISO),
      maxPreferredISO: parseInt(preferences.maxPreferredISO) || 800,
      preferWideAperture: Boolean(preferences.preferWideAperture),
      autoFocus: Boolean(preferences.autoFocus),
      priorityMode: preferences.priorityMode || 'balanced',
      preserveAperture: Boolean(preferences.preserveAperture),
      allowHighISO: Boolean(preferences.allowHighISO),
      minimumShutterSpeed: preferences.minimumShutterSpeed,
      maxLowLightISO: parseInt(preferences.maxLowLightISO) || 1600,
      minSportsShutter: parseFloat(preferences.minSportsShutter) || 1/500,
      portraitMode: preferences.portraitMode || 'natural'
    };

    service.userPreferences.set(userId, validPreferences);

    res.json({
      success: true,
      message: 'Preferences updated successfully',
      data: validPreferences
    });

  } catch (error) {
    logger.error('Failed to update user preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update preferences'
    });
  }
});

// Get adjustment history for learning insights
router.get('/history/:userId?', async (req, res) => {
  try {
    const service = await initializeService();
    const userId = req.params.userId || 'default';
    const { limit = 50, sceneType, lightingCondition } = req.query;

    // Get analysis history
    const historyEntries = [];
    
    for (const [key, entries] of service.analysisHistory.entries()) {
      if (sceneType || lightingCondition) {
        const [scene, lighting] = key.split('_');
        if (sceneType && scene !== sceneType) continue;
        if (lightingCondition && lighting !== lightingCondition) continue;
      }
      
      historyEntries.push(...entries.slice(-parseInt(limit)));
    }

    // Sort by timestamp (most recent first)
    historyEntries.sort((a, b) => b.timestamp - a.timestamp);

    res.json({
      success: true,
      data: {
        entries: historyEntries.slice(0, parseInt(limit)),
        totalEntries: historyEntries.length,
        userId
      }
    });

  } catch (error) {
    logger.error('Failed to get adjustment history:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve history'
    });
  }
});

// Get adjustment statistics and learning insights
router.get('/stats', async (req, res) => {
  try {
    const service = await initializeService();
    
    const stats = {
      totalAdjustments: 0,
      sceneTypeDistribution: {},
      averageProcessingTime: 0,
      commonAdjustments: {},
      learningInsights: []
    };

    // Calculate statistics from analysis history
    let totalProcessingTime = 0;
    
    for (const [key, entries] of service.analysisHistory.entries()) {
      const [sceneType] = key.split('_');
      
      stats.totalAdjustments += entries.length;
      stats.sceneTypeDistribution[sceneType] = 
        (stats.sceneTypeDistribution[sceneType] || 0) + entries.length;
      
      entries.forEach(entry => {
        if (entry.analysis?.processingTime) {
          totalProcessingTime += entry.analysis.processingTime;
        }
      });
    }

    if (stats.totalAdjustments > 0) {
      stats.averageProcessingTime = totalProcessingTime / stats.totalAdjustments;
    }

    // Generate learning insights
    if (stats.totalAdjustments > 10) {
      const mostCommonScene = Object.keys(stats.sceneTypeDistribution)
        .reduce((a, b) => stats.sceneTypeDistribution[a] > stats.sceneTypeDistribution[b] ? a : b);
      
      stats.learningInsights.push({
        type: 'scene_preference',
        message: `You shoot ${mostCommonScene} scenes most frequently`,
        confidence: 0.8
      });
    }

    res.json({
      success: true,
      data: stats
    });

  } catch (error) {
    logger.error('Failed to get adjustment statistics:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve statistics'
    });
  }
});

// Health check for auto-adjustment service
router.get('/health', async (req, res) => {
  try {
    const service = await initializeService();
    
    res.json({
      success: true,
      data: {
        serviceInitialized: service.isInitialized,
        realtimeActive: service.realTimeAnalysisActive,
        activeSession: service.currentCamera !== null,
        totalAdjustments: Array.from(service.analysisHistory.values())
          .reduce((sum, entries) => sum + entries.length, 0),
        availableModes: Object.values(service.adjustmentModes)
      }
    });

  } catch (error) {
    logger.error('Auto-adjustment health check failed:', error);
    res.status(500).json({
      success: false,
      error: 'Health check failed'
    });
  }
});

// Record user feedback for learning
router.post('/feedback', async (req, res) => {
  try {
    const service = await initializeService();
    const {
      userId,
      sceneType,
      lightingCondition,
      originalSettings,
      suggestedSettings,
      finalSettings,
      userAction,
      confidence,
      processingTime
    } = req.body;

    if (!userId || !userAction || !originalSettings || !suggestedSettings || !finalSettings) {
      return res.status(400).json({
        success: false,
        error: 'Missing required feedback data'
      });
    }

    const feedback = {
      sceneType: sceneType || 'general',
      lightingCondition: lightingCondition || 'normal',
      originalSettings,
      suggestedSettings,
      finalSettings,
      userAction, // 'accepted', 'modified', 'rejected'
      confidence: confidence || 0.5,
      processingTime: processingTime || 0
    };

    service.recordUserFeedback(userId, feedback);

    res.json({
      success: true,
      message: 'Feedback recorded successfully'
    });

  } catch (error) {
    logger.error('Failed to record user feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to record feedback'
    });
  }
});

// Get learning insights for user
router.get('/insights/:userId', async (req, res) => {
  try {
    const service = await initializeService();
    const userId = req.params.userId;

    const insights = service.getLearningInsights(userId);

    res.json({
      success: true,
      data: {
        userId,
        insights,
        totalInsights: insights.length
      }
    });

  } catch (error) {
    logger.error('Failed to get learning insights:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve insights'
    });
  }
});

// Validate camera settings
router.post('/validate', async (req, res) => {
  try {
    const service = await initializeService();
    const { settings, cameraBrand } = req.body;

    if (!settings) {
      return res.status(400).json({
        success: false,
        error: 'Settings object required'
      });
    }

    const engine = service.optimizationEngine;
    const validatedSettings = { ...settings };
    
    // Validate settings bounds
    engine.validateSettingsBounds(validatedSettings, cameraBrand || 'canon');

    const isValid = JSON.stringify(settings) === JSON.stringify(validatedSettings);

    res.json({
      success: true,
      data: {
        originalSettings: settings,
        validatedSettings,
        isValid,
        cameraBrand: cameraBrand || 'canon'
      }
    });

  } catch (error) {
    logger.error('Settings validation failed:', error);
    res.status(500).json({
      success: false,
      error: 'Validation failed'
    });
  }
});

module.exports = router;