const logger = require('../utils/logger');

class AISuggestionService {
  constructor() {
    this.suggestionTypes = {
      CAMERA_SETTINGS: 'camera_settings',
      COMPOSITION: 'composition',
      TECHNIQUE: 'technique',
      TIMING: 'timing',
      CREATIVE: 'creative'
    };
  }

  async analyzeScene(imageData, sceneAnalysis, cameraModel) {
    try {
      logger.info('Starting AI scene analysis for suggestions');
      
      // Simulate AI analysis - in production, this would call actual AI service
      const suggestions = await this.generateSuggestions(sceneAnalysis, cameraModel);
      
      return {
        success: true,
        suggestions: suggestions,
        analysisTimestamp: new Date().toISOString(),
        confidence: this.calculateOverallConfidence(suggestions)
      };
    } catch (error) {
      logger.error('Failed to analyze scene for AI suggestions:', error);
      throw error;
    }
  }

  async generateSuggestions(sceneAnalysis, cameraModel) {
    const suggestions = [];
    
    // Camera Settings Suggestions
    const cameraSettings = await this.generateCameraSettingsSuggestions(sceneAnalysis, cameraModel);
    if (cameraSettings.length > 0) {
      suggestions.push(...cameraSettings);
    }

    // Composition Suggestions
    const composition = await this.generateCompositionSuggestions(sceneAnalysis);
    if (composition.length > 0) {
      suggestions.push(...composition);
    }

    // Technique Suggestions
    const technique = await this.generateTechniqueSuggestions(sceneAnalysis);
    if (technique.length > 0) {
      suggestions.push(...technique);
    }

    // Timing Suggestions
    const timing = await this.generateTimingSuggestions(sceneAnalysis);
    if (timing.length > 0) {
      suggestions.push(...timing);
    }

    // Creative Suggestions
    const creative = await this.generateCreativeSuggestions(sceneAnalysis);
    if (creative.length > 0) {
      suggestions.push(...creative);
    }

    // Sort by priority and confidence
    return suggestions
      .sort((a, b) => b.priority * b.confidence - a.priority * a.confidence)
      .slice(0, 5); // Limit to top 5 suggestions
  }

  async generateCameraSettingsSuggestions(sceneAnalysis, cameraModel) {
    const suggestions = [];
    const { lighting_condition, subject_distance, movement_detected } = sceneAnalysis;

    // ISO Suggestions
    if (lighting_condition === 'dim' || lighting_condition === 'very_dark') {
      suggestions.push({
        id: `iso_${Date.now()}`,
        type: this.suggestionTypes.CAMERA_SETTINGS,
        category: 'iso',
        title: 'Increase ISO',
        message: 'Low light detected. Consider ISO 1600-3200',
        icon: 'iso',
        priority: 0.9,
        confidence: 0.85,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            iso: 1600
          }
        },
        explanation: 'Higher ISO will brighten the image in low light conditions'
      });
    }

    // Aperture Suggestions
    if (subject_distance === 'close' && sceneAnalysis.scene_type === 'portrait') {
      suggestions.push({
        id: `aperture_${Date.now()}`,
        type: this.suggestionTypes.CAMERA_SETTINGS,
        category: 'aperture',
        title: 'Wide Aperture',
        message: 'Try f/2.8 or wider for shallow depth of field',
        icon: 'aperture',
        priority: 0.8,
        confidence: 0.9,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            aperture: 'f/2.8'
          }
        },
        explanation: 'Wide aperture creates beautiful background blur (bokeh)'
      });
    }

    // Shutter Speed Suggestions
    if (movement_detected) {
      suggestions.push({
        id: `shutter_${Date.now()}`,
        type: this.suggestionTypes.CAMERA_SETTINGS,
        category: 'shutter_speed',
        title: 'Faster Shutter',
        message: 'Use 1/500s or faster to freeze motion',
        icon: 'shutter_speed',
        priority: 0.95,
        confidence: 0.8,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            shutterSpeed: '1/500'
          }
        },
        explanation: 'Fast shutter speed prevents motion blur'
      });
    }

    // White Balance Suggestions
    if (lighting_condition === 'mixed' || lighting_condition === 'tungsten') {
      suggestions.push({
        id: `wb_${Date.now()}`,
        type: this.suggestionTypes.CAMERA_SETTINGS,
        category: 'white_balance',
        title: 'Adjust White Balance',
        message: 'Mixed lighting detected. Try tungsten mode + M2',
        icon: 'wb_sunny',
        priority: 0.7,
        confidence: 0.75,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            whiteBalance: {
              mode: 'tungsten',
              shift: {
                magentaGreen: 2,
                blueAmber: 0
              }
            }
          }
        },
        explanation: 'Corrects color cast from artificial lighting'
      });
    }

    return suggestions;
  }

  async generateCompositionSuggestions(sceneAnalysis) {
    const suggestions = [];
    const { composition_analysis, subject_position } = sceneAnalysis;

    if (subject_position === 'center') {
      suggestions.push({
        id: `composition_${Date.now()}`,
        type: this.suggestionTypes.COMPOSITION,
        category: 'rule_of_thirds',
        title: 'Rule of thirds',
        message: 'Try placing subject on grid intersection',
        icon: 'grid_on',
        priority: 0.6,
        confidence: 0.7,
        actionable: false,
        visual: {
          type: 'overlay',
          overlay: 'rule_of_thirds_highlight'
        },
        explanation: 'Creates more dynamic and visually interesting composition'
      });
    }

    if (sceneAnalysis.scene_type === 'landscape' && sceneAnalysis.horizon_detected) {
      suggestions.push({
        id: `horizon_${Date.now()}`,
        type: this.suggestionTypes.COMPOSITION,
        category: 'horizon',
        title: 'Horizon placement',
        message: 'Consider lowering horizon for more sky drama',
        icon: 'landscape',
        priority: 0.5,
        confidence: 0.8,
        actionable: false,
        visual: {
          type: 'overlay',
          overlay: 'horizon_guide'
        },
        explanation: 'Lower horizon emphasizes dramatic sky elements'
      });
    }

    if (sceneAnalysis.subject_distance === 'far') {
      suggestions.push({
        id: `distance_${Date.now()}`,
        type: this.suggestionTypes.COMPOSITION,
        category: 'framing',
        title: 'Get closer',
        message: 'Move closer to fill the frame with your subject',
        icon: 'zoom_in',
        priority: 0.8,
        confidence: 0.85,
        actionable: false,
        visual: {
          type: 'frame_guide',
          overlay: 'closer_framing'
        },
        explanation: 'Closer framing creates more impact and eliminates distractions'
      });
    }

    return suggestions;
  }

  async generateTechniqueSuggestions(sceneAnalysis) {
    const suggestions = [];
    const { scene_type, lighting_condition } = sceneAnalysis;

    if (scene_type === 'portrait' && lighting_condition === 'bright') {
      suggestions.push({
        id: `technique_${Date.now()}`,
        type: this.suggestionTypes.TECHNIQUE,
        category: 'lighting',
        title: 'Find open shade',
        message: 'Look for even lighting under overcast sky or shade',
        icon: 'wb_shade',
        priority: 0.7,
        confidence: 0.8,
        actionable: false,
        explanation: 'Avoids harsh shadows and provides flattering portrait lighting'
      });
    }

    if (scene_type === 'landscape' && sceneAnalysis.depth_of_field === 'shallow') {
      suggestions.push({
        id: `hyperfocal_${Date.now()}`,
        type: this.suggestionTypes.TECHNIQUE,
        category: 'focus',
        title: 'Hyperfocal focusing',
        message: 'Try f/8-f/11 and focus 1/3 into the scene',
        icon: 'center_focus_strong',
        priority: 0.6,
        confidence: 0.75,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            aperture: 'f/8',
            focusMode: 'hyperfocal'
          }
        },
        explanation: 'Maximizes depth of field for sharp foreground and background'
      });
    }

    return suggestions;
  }

  async generateTimingSuggestions(sceneAnalysis) {
    const suggestions = [];
    const currentTime = new Date();
    const hour = currentTime.getHours();

    if ((hour >= 16 && hour <= 18) || (hour >= 6 && hour <= 8)) {
      suggestions.push({
        id: `timing_${Date.now()}`,
        type: this.suggestionTypes.TIMING,
        category: 'golden_hour',
        title: 'Golden hour opportunity',
        message: 'Perfect timing for warm, soft lighting',
        icon: 'wb_sunny',
        priority: 0.8,
        confidence: 0.9,
        actionable: false,
        explanation: 'Golden hour provides the most flattering natural lighting'
      });
    }

    if (sceneAnalysis.weather === 'overcast' && sceneAnalysis.scene_type === 'portrait') {
      suggestions.push({
        id: `overcast_${Date.now()}`,
        type: this.suggestionTypes.TIMING,
        category: 'weather',
        title: 'Perfect portrait weather',
        message: 'Overcast sky acts as giant softbox',
        icon: 'cloud',
        priority: 0.7,
        confidence: 0.85,
        actionable: false,
        explanation: 'Clouds diffuse sunlight creating even, flattering illumination'
      });
    }

    return suggestions;
  }

  async generateCreativeSuggestions(sceneAnalysis) {
    const suggestions = [];
    const { scene_type, lighting_condition } = sceneAnalysis;

    if (lighting_condition === 'backlight') {
      suggestions.push({
        id: `creative_${Date.now()}`,
        type: this.suggestionTypes.CREATIVE,
        category: 'silhouette',
        title: 'Try a silhouette',
        message: 'Expose for background to create dramatic silhouette',
        icon: 'brightness_low',
        priority: 0.6,
        confidence: 0.7,
        actionable: true,
        action: {
          type: 'apply_settings',
          settings: {
            exposureCompensation: '-1.3',
            meteringMode: 'spot'
          }
        },
        explanation: 'Creates dramatic contrast and artistic mood'
      });
    }

    if (scene_type === 'architecture' && sceneAnalysis.symmetry_detected) {
      suggestions.push({
        id: `symmetry_${Date.now()}`,
        type: this.suggestionTypes.CREATIVE,
        category: 'symmetry',
        title: 'Perfect symmetry',
        message: 'Center composition to emphasize symmetrical elements',
        icon: 'architecture',
        priority: 0.5,
        confidence: 0.8,
        actionable: false,
        visual: {
          type: 'overlay',
          overlay: 'center_guide'
        },
        explanation: 'Symmetrical composition creates powerful visual impact'
      });
    }

    return suggestions;
  }

  calculateOverallConfidence(suggestions) {
    if (suggestions.length === 0) return 0;
    
    const totalConfidence = suggestions.reduce((sum, suggestion) => sum + suggestion.confidence, 0);
    return Math.round((totalConfidence / suggestions.length) * 100) / 100;
  }

  // Cost optimization: Cache recent suggestions to avoid redundant AI calls
  getCachedSuggestions(sceneHash) {
    // Implementation would check cache for similar scene analysis
    return null;
  }

  cacheResult(sceneHash, suggestions) {
    // Implementation would cache the result for similar scenes
    logger.debug(`Caching AI suggestions for scene hash: ${sceneHash}`);
  }
}

module.exports = AISuggestionService;