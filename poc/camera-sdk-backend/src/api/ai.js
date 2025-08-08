const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs').promises;
const { spawn } = require('child_process');
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

// Scene analysis endpoint
router.post('/analyze-scene', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided' });
    }

    // Process image with Sharp
    const imageBuffer = await sharp(req.file.buffer)
      .resize(640, 480, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();

    // Save temporary image file
    const tempImagePath = path.join('/tmp', `analysis_${Date.now()}.jpg`);
    await fs.writeFile(tempImagePath, imageBuffer);

    try {
      // Call Python AI service
      const analysis = await callPythonAnalyzer(tempImagePath);
      
      // Clean up temporary file
      await fs.unlink(tempImagePath);
      
      res.json(analysis);
    } catch (analysisError) {
      // Clean up temporary file on error
      try {
        await fs.unlink(tempImagePath);
      } catch (unlinkError) {
        logger.error('Failed to clean up temp file:', unlinkError);
      }
      throw analysisError;
    }

  } catch (error) {
    logger.error('Scene analysis error:', error);
    res.status(500).json({ 
      error: 'Scene analysis failed',
      fallback: getFallbackAnalysis()
    });
  }
});

// Style preset recommendations (now handled by StylePresetService)
router.get('/presets', async (req, res) => {
  try {
    const StylePresetService = require('../services/style_preset_service');
    const presetService = new StylePresetService();
    
    const filters = {
      category: req.query.category,
      sceneType: req.query.scene_type,
      lightingCondition: req.query.lighting_condition,
      difficulty: req.query.difficulty,
      featured: req.query.featured === 'true',
      sortBy: req.query.sort_by || 'popularity',
      limit: parseInt(req.query.limit) || 50
    };
    
    const presets = await presetService.getAllPresets(filters);
    res.json(presets);
  } catch (error) {
    logger.error('Failed to get presets:', error);
    res.status(500).json({ error: 'Failed to retrieve presets' });
  }
});

// Apply AI recommendations with style preset integration
router.post('/recommend-settings', upload.single('image'), async (req, res) => {
  try {
    const { sceneType, lightingCondition, userPreferences } = req.body;
    
    // Generate basic recommendations
    const recommendations = generateSmartRecommendations({
      sceneType,
      lightingCondition,
      userPreferences: userPreferences ? JSON.parse(userPreferences) : {}
    });

    // Get matching style presets
    const StylePresetService = require('../services/style_preset_service');
    const presetService = new StylePresetService();
    
    try {
      const analysis = {
        scene_type: sceneType,
        lighting_condition: lightingCondition
      };
      
      const suggestedPresets = await presetService.getRecommendedPresets(
        analysis,
        userPreferences ? JSON.parse(userPreferences) : {}
      );
      
      recommendations.suggestedPresets = suggestedPresets.slice(0, 3);
    } catch (presetError) {
      logger.warn('Failed to get preset recommendations:', presetError);
      recommendations.suggestedPresets = [];
    }

    res.json(recommendations);
  } catch (error) {
    logger.error('Settings recommendation error:', error);
    res.status(500).json({ error: 'Failed to generate recommendations' });
  }
});

// Batch analysis for multiple images
router.post('/batch-analyze', upload.array('images', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No image files provided' });
    }

    const analyses = [];
    const tempFiles = [];

    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      
      // Process image
      const imageBuffer = await sharp(file.buffer)
        .resize(640, 480, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 80 })
        .toBuffer();

      // Save temporary file
      const tempImagePath = path.join('/tmp', `batch_${Date.now()}_${i}.jpg`);
      await fs.writeFile(tempImagePath, imageBuffer);
      tempFiles.push(tempImagePath);

      try {
        const analysis = await callPythonAnalyzer(tempImagePath);
        analyses.push({
          filename: file.originalname,
          analysis
        });
      } catch (error) {
        logger.error(`Analysis failed for ${file.originalname}:`, error);
        analyses.push({
          filename: file.originalname,
          error: 'Analysis failed',
          analysis: getFallbackAnalysis()
        });
      }
    }

    // Clean up temporary files
    for (const tempFile of tempFiles) {
      try {
        await fs.unlink(tempFile);
      } catch (error) {
        logger.error('Failed to clean up temp file:', error);
      }
    }

    res.json({ results: analyses });
  } catch (error) {
    logger.error('Batch analysis error:', error);
    res.status(500).json({ error: 'Batch analysis failed' });
  }
});

async function callPythonAnalyzer(imagePath) {
  return new Promise((resolve, reject) => {
    const pythonProcess = spawn('python', [
      path.join(__dirname, '../../ai/inference/analyze_image.py'),
      imagePath
    ]);

    let outputData = '';
    let errorData = '';

    pythonProcess.stdout.on('data', (data) => {
      outputData += data.toString();
    });

    pythonProcess.stderr.on('data', (data) => {
      errorData += data.toString();
    });

    pythonProcess.on('close', (code) => {
      if (code === 0) {
        try {
          const result = JSON.parse(outputData);
          resolve(result);
        } catch (parseError) {
          reject(new Error(`Failed to parse Python output: ${parseError.message}`));
        }
      } else {
        reject(new Error(`Python process failed with code ${code}: ${errorData}`));
      }
    });

    pythonProcess.on('error', (error) => {
      reject(new Error(`Failed to start Python process: ${error.message}`));
    });
  });
}

function generateSmartRecommendations({ sceneType, lightingCondition, userPreferences }) {
  const baseSettings = {
    iso: 400,
    aperture: 'f/4.0',
    shutterSpeed: '1/125',
    whiteBalance: 'auto'
  };

  // Adjust based on scene type
  if (sceneType === 'portrait') {
    baseSettings.aperture = 'f/2.8';
    baseSettings.iso = 200;
  } else if (sceneType === 'landscape') {
    baseSettings.aperture = 'f/8.0';
    baseSettings.iso = 100;
  } else if (sceneType === 'sports') {
    baseSettings.shutterSpeed = '1/500';
    baseSettings.iso = 800;
  }

  // Adjust based on lighting
  if (lightingCondition === 'low_light') {
    baseSettings.iso = Math.min(baseSettings.iso * 2, 1600);
  } else if (lightingCondition === 'bright') {
    baseSettings.iso = 100;
  }

  // Apply user preferences
  if (userPreferences.preferLowISO) {
    baseSettings.iso = Math.min(baseSettings.iso, 400);
  }

  return {
    recommended: baseSettings,
    alternatives: [
      { ...baseSettings, iso: baseSettings.iso * 0.5, name: 'Lower noise' },
      { ...baseSettings, aperture: 'f/2.0', name: 'More bokeh' },
      { ...baseSettings, shutterSpeed: '1/250', name: 'Sharper motion' }
    ],
    explanation: `Optimized for ${sceneType} in ${lightingCondition} lighting conditions.`
  };
}

function getFallbackAnalysis() {
  return {
    sceneType: 'general',
    sceneConfidence: 0.5,
    lightingCondition: 'normal',
    lightingConfidence: 0.5,
    hasFaces: false,
    recommendedSettings: {
      iso: 400,
      aperture: 'f/4.0',
      shutterSpeed: '1/125',
      whiteBalance: 'auto'
    }
  };
}

module.exports = router;