const EventEmitter = require('events');
const path = require('path');
const { spawn } = require('child_process');
const logger = require('../utils/logger');
const LearningEngine = require('./learning_engine');
const NeRFIntegrationService = require('./nerf_integration_service');
const BrandSpecificOptimizer = require('./brand_specific_optimizer');

class AutoAdjustmentService extends EventEmitter {
  constructor() {
    super();
    this.isInitialized = false;
    this.currentCamera = null;
    this.analysisHistory = new Map();
    this.userPreferences = new Map();
    this.optimizationEngine = null;
    this.learningEngine = new LearningEngine();
    this.realTimeAnalysisActive = false;
    this.analysisInterval = null;
    
    // Initialize NeRF Integration Service
    this.nerfService = new NeRFIntegrationService({
      enableRealTime: true,
      analysisMode: 'real_time',
      fallbackToTraditional: true
    });
    
    // Initialize Brand-Specific Optimizer
    this.brandOptimizer = new BrandSpecificOptimizer();
    
    // Optimization parameters
    this.optimizationConfig = {
      exposureWeight: 0.4,
      focusWeight: 0.3,
      noiseWeight: 0.2,
      speedWeight: 0.1,
      adaptationRate: 0.1,
      confidenceThreshold: 0.7
    };
    
    // Supported adjustment modes
    this.adjustmentModes = {
      AUTO: 'auto',
      PORTRAIT: 'portrait',
      LANDSCAPE: 'landscape',
      SPORTS: 'sports',
      MACRO: 'macro',
      LOW_LIGHT: 'low_light',
      CREATIVE: 'creative'
    };
    
    this.initialize();
  }

  async initialize() {
    try {
      logger.info('Initializing Auto-Adjustment Service...');
      
      // Load user preferences from storage
      await this.loadUserPreferences();
      
      // Initialize optimization engine
      this.optimizationEngine = new ParameterOptimizationEngine();
      
      this.isInitialized = true;
      logger.info('Auto-Adjustment Service initialized successfully');
      
      this.emit('initialized');
    } catch (error) {
      logger.error('Failed to initialize Auto-Adjustment Service:', error);
      throw error;
    }
  }

  async analyzeAndAdjust(imageData, cameraService, options = {}) {
    if (!this.isInitialized) {
      throw new Error('Auto-Adjustment Service not initialized');
    }

    if (!cameraService || !cameraService.connectedCamera) {
      throw new Error('No camera connected');
    }

    try {
      logger.info('Starting intelligent parameter adjustment...');
      
      const analysisStart = Date.now();
      
      // Perform comprehensive scene analysis
      const sceneAnalysis = await this.performAdvancedAnalysis(imageData, options);
      
      // Get current camera settings
      const currentSettings = await cameraService.getCameraSettings();
      
      // Generate optimal parameters
      let optimizedSettings = await this.optimizeParameters(
        sceneAnalysis, 
        currentSettings, 
        cameraService.connectedCamera.brand,
        options
      );

      // Apply personalized learning if user ID is provided
      if (options.userId) {
        optimizedSettings = this.learningEngine.generatePersonalizedRecommendations(
          options.userId,
          sceneAnalysis,
          optimizedSettings
        );
      }
      
      // Get style preset recommendations
      let suggestedPresets = [];
      try {
        const StylePresetService = require('./style_preset_service');
        const presetService = new StylePresetService();
        
        suggestedPresets = await presetService.getRecommendedPresets(
          sceneAnalysis,
          options.userPreferences || {}
        );
      } catch (presetError) {
        logger.warn('Failed to get style preset recommendations:', presetError);
      }
      
      // Validate and apply settings
      const validatedSettings = this.validateSettings(optimizedSettings, cameraService);
      const appliedSettings = await this.applySettings(validatedSettings, cameraService);
      
      const analysisTime = Date.now() - analysisStart;
      
      // Store analysis for learning
      this.storeAnalysisResult(sceneAnalysis, currentSettings, appliedSettings);
      
      const result = {
        analysis: sceneAnalysis,
        originalSettings: currentSettings,
        optimizedSettings: appliedSettings,
        adjustmentsMade: this.calculateAdjustmentsMade(currentSettings, appliedSettings),
        confidence: sceneAnalysis.confidence,
        processingTime: analysisTime,
        recommendations: this.generateRecommendations(sceneAnalysis, appliedSettings),
        suggestedPresets: suggestedPresets.slice(0, 3)
      };
      
      logger.info(`Parameter adjustment completed in ${analysisTime}ms`);
      this.emit('adjustmentCompleted', result);
      
      return result;
      
    } catch (error) {
      logger.error('Auto-adjustment failed:', error);
      this.emit('adjustmentError', error);
      throw error;
    }
  }

  async performAdvancedAnalysis(imageData, options = {}) {
    try {
      // Try NeRF analysis first for 3D scene understanding
      let nerfAnalysis = null;
      try {
        logger.info('Attempting NeRF-based 3D scene analysis...');
        nerfAnalysis = await this.nerfService.analyzeImageWithNeRF(imageData, {
          analysisMode: options.nerfMode || 'real_time',
          optimizeCameraParams: true,
          cameraData: options.cameraData
        });
        
        if (nerfAnalysis) {
          logger.info('NeRF analysis successful, using enhanced 3D recommendations');
          
          // Combine with traditional analysis for complete coverage
          const traditionalAnalysis = await this.callAdvancedAnalyzer(imageData, options);
          const realtimeAnalysis = await this.performRealtimeAnalysis(imageData);
          
          // Create comprehensive analysis combining all methods
          const combinedAnalysis = {
            // Use NeRF results as primary
            ...nerfAnalysis,
            
            // Add traditional analysis details
            histogram: realtimeAnalysis.histogram,
            exposureAnalysis: realtimeAnalysis.exposure,
            focusAnalysis: realtimeAnalysis.focus,
            noiseAnalysis: realtimeAnalysis.noise,
            
            // Enhanced confidence scoring
            confidence: Math.max(
              nerfAnalysis.advanced_metrics?.nerf_confidence || 0.5,
              nerfAnalysis.scene_confidence || 0.5
            ),
            
            // Analysis metadata
            timestamp: Date.now(),
            analysis_type: 'nerf_enhanced',
            processing_methods: ['nerf_3d', 'traditional_cv', 'realtime'],
            
            // Ensure backward compatibility
            scene_type: nerfAnalysis.scene_type || 'general',
            lighting_condition: nerfAnalysis.lighting_condition || 'normal',
            has_faces: nerfAnalysis.has_faces || false
          };
          
          return combinedAnalysis;
        }
      } catch (nerfError) {
        logger.warn('NeRF analysis failed, falling back to traditional methods:', nerfError.message);
      }
      
      // Fallback to traditional analysis if NeRF fails
      logger.info('Using traditional computer vision analysis');
      const analysis = await this.callAdvancedAnalyzer(imageData, options);
      const realtimeAnalysis = await this.performRealtimeAnalysis(imageData);
      
      // Combine traditional analyses
      const combinedAnalysis = {
        ...analysis,
        histogram: realtimeAnalysis.histogram,
        exposureAnalysis: realtimeAnalysis.exposure,
        focusAnalysis: realtimeAnalysis.focus,
        noiseAnalysis: realtimeAnalysis.noise,
        confidence: Math.min(
          analysis.scene_confidence || 0.5, 
          realtimeAnalysis.confidence || 0.5
        ),
        timestamp: Date.now(),
        analysis_type: 'traditional',
        processing_methods: ['traditional_cv', 'realtime'],
        // Ensure required fields exist
        scene_type: analysis.scene_type || 'general',
        lighting_condition: analysis.lighting_condition || 'normal',
        has_faces: analysis.has_faces || false
      };
      
      return combinedAnalysis;
      
    } catch (error) {
      logger.error('All analysis methods failed:', error);
      return this.getFallbackAnalysis();
    }
  }

  async performRealtimeAnalysis(imageData) {
    try {
      // Use advanced image analyzer for real-time analysis
      const AdvancedImageAnalyzer = require('./advanced_image_analyzer');
      const analyzer = new AdvancedImageAnalyzer();
      
      const analysis = await analyzer.analyzeImage(imageData);
      
      return {
        histogram: analysis.histogram.histograms,
        exposure: {
          overexposed: analysis.exposure.overexposed,
          underexposed: analysis.exposure.underexposed,
          wellExposed: analysis.exposure.wellExposed,
          dynamicRange: analysis.exposure.dynamicRange,
          clipping: analysis.exposure.clipping
        },
        focus: {
          sharpness: analysis.focus.overallSharpness,
          focusPoints: [{
            x: analysis.focus.bestFocusPoint.x,
            y: analysis.focus.bestFocusPoint.y,
            confidence: analysis.focus.bestFocusPoint.confidence
          }],
          depth: analysis.focus.focusDistribution?.uniformity || 'medium'
        },
        noise: {
          level: analysis.noise.level,
          type: analysis.noise.type,
          distribution: analysis.noise.distribution
        },
        confidence: analysis.confidence,
        recommendations: [
          analysis.exposure.recommendation,
          analysis.focus.recommendation,
          analysis.noise.recommendation,
          analysis.color.recommendation
        ].filter(rec => rec.priority !== 'low')
      };
    } catch (error) {
      logger.error('Real-time analysis failed, using fallback:', error);
      // Fallback to mock data
      return {
        histogram: {
          red: this.generateMockHistogram(),
          green: this.generateMockHistogram(),
          blue: this.generateMockHistogram(),
          luminance: this.generateMockHistogram()
        },
        exposure: {
          overexposed: 0.05,
          underexposed: 0.08,
          wellExposed: 0.87,
          dynamicRange: 8.5,
          clipping: { highlights: 0.02, shadows: 0.03 }
        },
        focus: {
          sharpness: 0.85,
          focusPoints: [{ x: 0.5, y: 0.5, confidence: 0.9 }],
          depth: 'medium'
        },
        noise: {
          level: 0.15,
          type: 'gaussian',
          distribution: 'uniform'
        },
        confidence: 0.5
      };
    }
  }

  async optimizeParameters(analysis, currentSettings, cameraBrand, options = {}) {
    try {
      const mode = options.mode || this.adjustmentModes.AUTO;
      const userPrefs = this.getUserPreferences(options.userId);
      
      // Multi-layered optimization approach
      let optimized;
      
      // Step 1: Traditional optimization as foundation
      optimized = await this.optimizationEngine.optimize({
        analysis,
        currentSettings,
        cameraBrand,
        mode,
        userPreferences: userPrefs,
        constraints: options.constraints || {}
      });
      
      // Step 2: Apply brand-specific optimizations
      if (cameraBrand) {
        logger.info(`Applying ${cameraBrand}-specific optimizations`);
        try {
          const brandOptimized = await this.brandOptimizer.optimizeForBrand(
            cameraBrand,
            analysis,
            optimized,
            userPrefs
          );
          
          if (brandOptimized.success) {
            optimized = {
              ...optimized,
              ...brandOptimized.optimized_settings
            };
            
            // Store brand-specific insights
            analysis.brand_optimization = brandOptimized;
            logger.info(`Brand-specific optimization completed with confidence: ${brandOptimized.confidence}`);
          }
        } catch (brandError) {
          logger.warn(`Brand-specific optimization failed for ${cameraBrand}:`, brandError);
        }
      }
      
      // Step 3: Apply NeRF enhancements if available
      if (analysis.analysis_type === 'nerf_enhanced' && analysis.enhanced_recommendations) {
        logger.info('Applying NeRF-enhanced optimizations');
        optimized = this.applyNeRFEnhancements(optimized, analysis, userPrefs);
      }
      
      // Apply user learning adjustments
      const learned = this.applyLearningAdjustments(optimized, analysis, userPrefs);
      
      return learned;
      
    } catch (error) {
      logger.error('Parameter optimization failed:', error);
      return this.generateFallbackSettings(analysis, currentSettings);
    }
  }

  validateSettings(settings, cameraService) {
    const cameraBrand = cameraService.connectedCamera.brand.toLowerCase();
    const validated = { ...settings };
    
    // Validate ISO range
    if (cameraBrand === 'canon') {
      validated.iso = Math.max(50, Math.min(51200, validated.iso));
    } else if (cameraBrand === 'nikon') {
      validated.iso = Math.max(64, Math.min(25600, validated.iso));
    } else if (cameraBrand === 'sony') {
      validated.iso = Math.max(50, Math.min(102400, validated.iso));
    }
    
    // Validate aperture values
    const validApertures = ['f/1.4', 'f/1.8', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16', 'f/22'];
    if (!validApertures.includes(validated.aperture)) {
      validated.aperture = 'f/4.0'; // Safe default
    }
    
    // Validate shutter speed
    if (!this.isValidShutterSpeed(validated.shutter_speed)) {
      validated.shutter_speed = '1/125'; // Safe default
    }
    
    return validated;
  }

  async applySettings(settings, cameraService) {
    const appliedSettings = {};
    const settingsToApply = [
      'iso', 'aperture', 'shutter_speed', 'white_balance', 
      'focus_mode', 'metering_mode', 'exposure_mode'
    ];
    
    for (const setting of settingsToApply) {
      if (settings[setting] !== undefined) {
        try {
          await cameraService.setCameraProperty(setting, settings[setting]);
          appliedSettings[setting] = settings[setting];
          logger.debug(`Applied ${setting}: ${settings[setting]}`);
        } catch (error) {
          logger.warn(`Failed to apply ${setting}:`, error);
          // Continue with other settings
        }
      }
    }
    
    return appliedSettings;
  }

  async startRealtimeAdjustment(cameraService, options = {}) {
    if (this.realTimeAnalysisActive) {
      logger.warn('Real-time analysis already active');
      return;
    }
    
    this.currentCamera = cameraService;
    this.realTimeAnalysisActive = true;
    
    logger.info('Starting real-time parameter adjustment...');
    
    // Start live view if not already active
    if (!cameraService.liveViewSession) {
      await cameraService.startLiveView();
    }
    
    // Listen for live view frames
    cameraService.on('liveViewFrame', this.handleLiveViewFrame.bind(this));
    
    // Start periodic optimization
    this.analysisInterval = setInterval(async () => {
      if (this.realTimeAnalysisActive && this.currentCamera) {
        try {
          await this.performPeriodicOptimization();
        } catch (error) {
          logger.error('Periodic optimization failed:', error);
        }
      }
    }, options.interval || 2000); // Every 2 seconds
    
    this.emit('realtimeStarted');
  }

  async stopRealtimeAdjustment() {
    if (!this.realTimeAnalysisActive) {
      return;
    }
    
    this.realTimeAnalysisActive = false;
    
    if (this.analysisInterval) {
      clearInterval(this.analysisInterval);
      this.analysisInterval = null;
    }
    
    if (this.currentCamera) {
      this.currentCamera.removeAllListeners('liveViewFrame');
      this.currentCamera = null;
    }
    
    logger.info('Real-time parameter adjustment stopped');
    this.emit('realtimeStopped');
  }

  async handleLiveViewFrame(frameData) {
    if (!this.realTimeAnalysisActive) return;
    
    try {
      // Analyze frame for real-time adjustments
      const quickAnalysis = await this.performQuickAnalysis(frameData.data);
      
      // Check if significant adjustment is needed
      if (this.shouldTriggerAdjustment(quickAnalysis)) {
        logger.debug('Triggering real-time adjustment based on frame analysis');
        await this.performQuickAdjustment(quickAnalysis);
      }
      
    } catch (error) {
      logger.error('Live view frame analysis failed:', error);
    }
  }

  async performPeriodicOptimization() {
    if (!this.currentCamera || !this.realTimeAnalysisActive) return;
    
    try {
      // Get current settings
      const currentSettings = await this.currentCamera.getCameraSettings();
      
      // Perform lightweight analysis
      const analysis = await this.performLightweightAnalysis();
      
      // Check if optimization is needed
      if (this.needsOptimization(analysis, currentSettings)) {
        const optimized = await this.optimizeParameters(
          analysis, 
          currentSettings, 
          this.currentCamera.connectedCamera.brand
        );
        
        await this.applySettings(optimized, this.currentCamera);
        
        this.emit('realtimeAdjustment', {
          analysis,
          settings: optimized,
          timestamp: Date.now()
        });
      }
      
    } catch (error) {
      logger.error('Periodic optimization failed:', error);
    }
  }

  // Learning and Adaptation Methods
  storeAnalysisResult(analysis, originalSettings, appliedSettings) {
    const key = this.generateAnalysisKey(analysis);
    
    if (!this.analysisHistory.has(key)) {
      this.analysisHistory.set(key, []);
    }
    
    this.analysisHistory.get(key).push({
      analysis,
      originalSettings,
      appliedSettings,
      timestamp: Date.now()
    });
    
    // Keep only recent history (last 100 entries per key)
    const history = this.analysisHistory.get(key);
    if (history.length > 100) {
      history.splice(0, history.length - 100);
    }
  }

  applyLearningAdjustments(baseSettings, analysis, userPreferences) {
    const learned = { ...baseSettings };
    
    try {
      // Ensure ISO is a number
      if (typeof learned.iso === 'string') {
        learned.iso = parseInt(learned.iso) || 400;
      }
      
      // Apply user preference adjustments safely
      if (userPreferences && userPreferences.preferLowISO) {
        learned.iso = Math.min(learned.iso, userPreferences.maxPreferredISO || 800);
      }
      
      if (userPreferences && userPreferences.preferWideAperture && 
          analysis && analysis.scene_type === 'portrait') {
        learned.aperture = 'f/2.8';
      }
      
      // Apply historical learning with error handling
      if (analysis) {
        const similarScenes = this.findSimilarScenes(analysis);
        if (similarScenes && similarScenes.length > 0) {
          const avgAdjustments = this.calculateAverageAdjustments(similarScenes);
          if (avgAdjustments && typeof avgAdjustments.iso === 'number') {
            const adjustment = 1 + (avgAdjustments.iso * this.optimizationConfig.adaptationRate);
            learned.iso = Math.round(Math.max(50, Math.min(6400, learned.iso * adjustment)));
          }
        }
      }
    } catch (error) {
      logger.error('Error applying learning adjustments:', error);
      // Return base settings if learning fails
    }
    
    return learned;
  }

  // Utility Methods
  generateAnalysisKey(analysis) {
    if (!analysis) {
      return 'unknown_unknown_false';
    }
    
    const sceneType = analysis.scene_type || 'unknown';
    const lighting = analysis.lighting_condition || 'unknown';
    const hasFaces = analysis.has_faces || false;
    
    return `${sceneType}_${lighting}_${hasFaces}`;
  }

  findSimilarScenes(analysis) {
    const key = this.generateAnalysisKey(analysis);
    return this.analysisHistory.get(key) || [];
  }

  calculateAverageAdjustments(scenes) {
    if (!scenes || scenes.length === 0) {
      return { iso: 0, aperture: 0, shutter: 0 };
    }

    const adjustments = { iso: 0, aperture: 0, shutter: 0, count: 0 };
    
    scenes.forEach(scene => {
      try {
        if (scene.originalSettings && scene.appliedSettings) {
          // Calculate ISO adjustment ratio
          if (scene.originalSettings.iso && scene.appliedSettings.iso) {
            const isoRatio = scene.appliedSettings.iso / scene.originalSettings.iso;
            adjustments.iso += (isoRatio - 1);
          }
          
          // Count valid adjustments
          adjustments.count++;
        }
      } catch (error) {
        logger.warn('Error calculating adjustment for scene:', error);
      }
    });
    
    // Average the adjustments
    if (adjustments.count > 0) {
      adjustments.iso /= adjustments.count;
      adjustments.aperture /= adjustments.count;
      adjustments.shutter /= adjustments.count;
    }
    
    return adjustments;
  }

  calculateAdjustmentsMade(original, applied) {
    const adjustments = {};
    
    Object.keys(applied).forEach(key => {
      if (original[key] !== applied[key]) {
        adjustments[key] = {
          from: original[key],
          to: applied[key]
        };
      }
    });
    
    return adjustments;
  }

  generateRecommendations(analysis, settings) {
    const recommendations = [];
    
    if (analysis.lighting_condition === 'dim' && settings.iso < 800) {
      recommendations.push({
        type: 'suggestion',
        message: 'Consider using a tripod for sharper images in low light',
        priority: 'medium'
      });
    }
    
    if (analysis.has_faces && settings.aperture === 'f/8.0') {
      recommendations.push({
        type: 'tip',
        message: 'Try a wider aperture like f/2.8 for better portrait bokeh',
        priority: 'low'
      });
    }
    
    return recommendations;
  }

  async callAdvancedAnalyzer(imageData, options = {}) {
    try {
      // Check if advanced analyzer exists, fallback to existing scene analyzer
      const analyzerPath = path.join(__dirname, '../../ai/inference/scene_analyzer.py');
      
      return new Promise((resolve, reject) => {
        const pythonProcess = spawn('python3', [
          analyzerPath,
          '--mode', options.mode || 'auto'
        ], {
          stdio: ['pipe', 'pipe', 'pipe']
        });

        let outputData = '';
        let errorData = '';
        let hasResolved = false;

        const timeout = setTimeout(() => {
          if (!hasResolved) {
            pythonProcess.kill('SIGTERM');
            hasResolved = true;
            logger.warn('Python analyzer timeout, using fallback');
            resolve(this.getFallbackAnalysis());
          }
        }, 5000); // 5 second timeout

        pythonProcess.stdout.on('data', (data) => {
          outputData += data.toString();
        });

        pythonProcess.stderr.on('data', (data) => {
          errorData += data.toString();
        });

        pythonProcess.on('close', (code) => {
          clearTimeout(timeout);
          if (hasResolved) return;
          hasResolved = true;
          
          if (code === 0 && outputData.trim()) {
            try {
              const result = JSON.parse(outputData.trim());
              resolve(result);
            } catch (parseError) {
              logger.error(`Failed to parse analysis output: ${parseError.message}`);
              resolve(this.getFallbackAnalysis());
            }
          } else {
            logger.warn(`Analysis process failed with code ${code}: ${errorData}`);
            resolve(this.getFallbackAnalysis());
          }
        });

        pythonProcess.on('error', (error) => {
          clearTimeout(timeout);
          if (hasResolved) return;
          hasResolved = true;
          logger.error(`Failed to start analysis process: ${error.message}`);
          resolve(this.getFallbackAnalysis());
        });

        // Handle image data input safely
        try {
          if (imageData) {
            if (Buffer.isBuffer(imageData)) {
              pythonProcess.stdin.write(imageData);
            } else if (typeof imageData === 'string') {
              pythonProcess.stdin.write(imageData, 'utf8');
            }
          }
          pythonProcess.stdin.end();
        } catch (stdinError) {
          logger.error('Error writing to Python process stdin:', stdinError);
          clearTimeout(timeout);
          if (!hasResolved) {
            hasResolved = true;
            resolve(this.getFallbackAnalysis());
          }
        }
      });
    } catch (error) {
      logger.error('Advanced analyzer setup failed:', error);
      return this.getFallbackAnalysis();
    }
  }

  // Helper methods for real-time analysis
  performQuickAnalysis() {
    // Simulate quick frame analysis
    return Promise.resolve({
      brightness: Math.random(),
      contrast: Math.random(),
      hasMotion: Math.random() > 0.7,
      focusQuality: Math.random()
    });
  }

  shouldTriggerAdjustment(analysis) {
    return analysis.brightness < 0.3 || analysis.brightness > 0.8 || 
           analysis.contrast < 0.2 || analysis.focusQuality < 0.6;
  }

  performQuickAdjustment(analysis) {
    // Implement quick adjustment logic
    return Promise.resolve();
  }

  performLightweightAnalysis() {
    // Simplified analysis for periodic optimization
    return Promise.resolve({
      scene_type: 'general',
      lighting_condition: 'normal',
      confidence: 0.7
    });
  }

  needsOptimization() {
    return Math.random() > 0.8; // Simplified logic
  }

  generateMockHistogram() {
    return Array.from({ length: 256 }, () => Math.floor(Math.random() * 1000));
  }

  isValidShutterSpeed(speed) {
    const validSpeeds = [
      '1/4000', '1/3200', '1/2500', '1/2000', '1/1600', '1/1250', '1/1000',
      '1/800', '1/640', '1/500', '1/400', '1/320', '1/250', '1/200', '1/160',
      '1/125', '1/100', '1/80', '1/60', '1/50', '1/40', '1/30', '1/25', '1/20',
      '1/15', '1/13', '1/10', '1/8', '1/6', '1/5', '1/4', '1/3', '1/2.5', '1/2'
    ];
    return validSpeeds.includes(speed);
  }

  getFallbackAnalysis() {
    return {
      scene_type: 'general',
      scene_confidence: 0.5,
      lighting_condition: 'normal',
      lighting_confidence: 0.5,
      has_faces: false,
      confidence: 0.5
    };
  }

  generateFallbackSettings(analysis, currentSettings) {
    return {
      iso: 400,
      aperture: 'f/4.0',
      shutter_speed: '1/125',
      white_balance: 'auto'
    };
  }

  async loadUserPreferences() {
    // In production, load from database
    this.userPreferences.set('default', {
      preferLowISO: true,
      maxPreferredISO: 800,
      preferWideAperture: false,
      autoFocus: true
    });
  }

  getUserPreferences(userId = 'default') {
    return this.userPreferences.get(userId) || this.userPreferences.get('default');
  }

  // Record user feedback for learning
  recordUserFeedback(userId, feedback) {
    try {
      this.learningEngine.recordUserFeedback(userId, feedback);
      logger.info(`User feedback recorded for ${userId}: ${feedback.userAction}`);
    } catch (error) {
      logger.error('Failed to record user feedback:', error);
    }
  }

  // Get learning insights for user
  getLearningInsights(userId) {
    try {
      return this.learningEngine.getLearningInsights(userId);
    } catch (error) {
      logger.error('Failed to get learning insights:', error);
      return [];
    }
  }

  applyNeRFEnhancements(baseSettings, analysis, userPrefs) {
    try {
      const enhanced = { ...baseSettings };
      const nerfRecs = analysis.enhanced_recommendations || {};
      const nerfAnalysis = analysis.nerf_analysis || {};
      
      // Apply exposure recommendations from NeRF 3D analysis
      if (nerfRecs.exposure) {
        if (nerfRecs.exposure.iso_adjustment === 'increase' && !userPrefs.preferLowISO) {
          const currentISO = parseInt(enhanced.iso) || 400;
          enhanced.iso = Math.min(currentISO * 1.3, 1600);
          logger.debug('NeRF: Increased ISO based on 3D lighting analysis');
        } else if (nerfRecs.exposure.iso_adjustment === 'decrease') {
          const currentISO = parseInt(enhanced.iso) || 400;
          enhanced.iso = Math.max(currentISO * 0.8, 100);
          logger.debug('NeRF: Decreased ISO based on 3D lighting analysis');
        }
      }
      
      // Apply focus recommendations from NeRF depth analysis
      if (nerfRecs.focus && nerfRecs.focus.optimal_distance) {
        enhanced.focus_mode = nerfRecs.focus.focus_mode || enhanced.focus_mode;
        
        // Use 3D depth information for better focus decisions
        if (nerfAnalysis.focal_regions && nerfAnalysis.focal_regions.length > 0) {
          const mainFocus = nerfAnalysis.focal_regions[0];
          if (mainFocus.suggested_aperture && !userPrefs.preserveAperture) {
            enhanced.aperture = mainFocus.suggested_aperture;
            logger.debug(`NeRF: Set aperture to ${enhanced.aperture} for optimal subject isolation`);
          }
        }
      }
      
      // Apply aperture recommendations from NeRF depth of field analysis
      if (nerfRecs.aperture && nerfRecs.aperture.suggested_aperture) {
        if (!userPrefs.preserveAperture) {
          enhanced.aperture = nerfRecs.aperture.suggested_aperture;
          logger.debug(`NeRF: Applied aperture ${enhanced.aperture} for depth of field optimization`);
        }
      }
      
      // Apply composition-based adjustments
      if (nerfRecs.composition && nerfRecs.composition.suggestions) {
        // Composition suggestions affect metering mode
        const suggestions = nerfRecs.composition.suggestions;
        if (suggestions.includes('Multiple subjects detected')) {
          enhanced.metering_mode = 'matrix';
        } else if (suggestions.includes('Clear subject isolation')) {
          enhanced.metering_mode = 'spot';
        }
      }
      
      // Use 3D scene understanding for advanced optimizations
      if (nerfAnalysis.depth_available && nerfAnalysis.scene_bounds) {
        const sceneDepth = nerfAnalysis.scene_bounds.median || 5;
        
        // Optimize shutter speed based on scene depth and potential motion
        if (sceneDepth < 2 && analysis.scene_type === 'portrait') {
          // Close portraits - prioritize avoiding camera shake
          const currentShutter = this.parseShutterSpeed(enhanced.shutter_speed);
          if (currentShutter > 1/125) {
            enhanced.shutter_speed = '1/125';
            logger.debug('NeRF: Adjusted shutter speed for close portrait');
          }
        } else if (sceneDepth > 10 && analysis.scene_type === 'landscape') {
          // Distant landscapes - can use slower shutter if needed
          const currentISO = parseInt(enhanced.iso);
          if (currentISO > 400) {
            enhanced.iso = Math.max(currentISO * 0.8, 200);
            enhanced.shutter_speed = '1/60'; // Allow slower shutter for better quality
            logger.debug('NeRF: Optimized for distant landscape scene');
          }
        }
      }
      
      // Apply lighting quality optimizations
      if (nerfAnalysis.lighting_3d && nerfAnalysis.lighting_3d.quality_score < 0.5) {
        // Poor lighting detected by 3D analysis
        if (!userPrefs.preferLowISO) {
          const currentISO = parseInt(enhanced.iso);
          enhanced.iso = Math.min(currentISO * 1.2, 800);
          logger.debug('NeRF: Increased ISO due to poor 3D lighting analysis');
        }
      }
      
      return enhanced;
      
    } catch (error) {
      logger.error('Error applying NeRF enhancements:', error);
      return baseSettings; // Return original settings if enhancement fails
    }
  }

  parseShutterSpeed(shutterSpeedStr) {
    // Convert shutter speed string to seconds (helper method)
    if (shutterSpeedStr.includes('/')) {
      const [numerator, denominator] = shutterSpeedStr.split('/').map(Number);
      return numerator / denominator;
    }
    return parseFloat(shutterSpeedStr);
  }

  // Get NeRF service status for monitoring
  getNeRFServiceStatus() {
    return this.nerfService.getServiceStatus();
  }

  // Cleanup method
  async cleanup() {
    try {
      await this.stopRealtimeAdjustment();
      
      if (this.nerfService) {
        await this.nerfService.cleanup();
      }
      
      this.removeAllListeners();
      logger.info('Auto-Adjustment Service cleaned up successfully');
    } catch (error) {
      logger.error('Error during cleanup:', error);
    }
  }
}

// Parameter Optimization Engine
class ParameterOptimizationEngine {
  constructor() {
    this.exposureTriangleWeights = {
      iso: 0.3,
      aperture: 0.4,
      shutterSpeed: 0.3
    };
    
    // Advanced optimization parameters
    this.optimizationStrategies = {
      exposure_priority: { iso: 0.2, aperture: 0.3, shutterSpeed: 0.5 },
      aperture_priority: { iso: 0.3, aperture: 0.6, shutterSpeed: 0.1 },
      iso_priority: { iso: 0.6, aperture: 0.2, shutterSpeed: 0.2 },
      balanced: { iso: 0.33, aperture: 0.34, shutterSpeed: 0.33 }
    };
    
    // Camera-specific ISO performance curves
    this.isoPerformanceCurves = {
      canon: { native: 100, excellent: [100, 200, 400], good: [800, 1600], acceptable: [3200, 6400] },
      nikon: { native: 64, excellent: [64, 100, 200], good: [400, 800, 1600], acceptable: [3200, 6400] },
      sony: { native: 100, excellent: [100, 200, 400, 800], good: [1600, 3200], acceptable: [6400, 12800] }
    };
  }

  async optimize({ analysis, currentSettings, cameraBrand, mode, constraints, userPreferences = {} }) {
    const optimized = { ...currentSettings };
    
    // Determine optimization strategy
    const strategy = this.determineOptimizationStrategy(analysis, mode, userPreferences);
    
    // Apply intelligent exposure triangle optimization
    await this.optimizeExposureTriangle(optimized, analysis, strategy, cameraBrand);
    
    // Optimize based on scene type with advanced logic
    this.optimizeForSceneAdvanced(optimized, analysis, userPreferences);
    
    // Optimize based on image analysis feedback
    this.optimizeFromImageAnalysis(optimized, analysis);
    
    // Apply mode-specific optimizations
    this.optimizeForMode(optimized, mode, analysis);
    
    // Apply camera brand specific adjustments
    this.optimizeForCamera(optimized, cameraBrand);
    
    // Apply user constraints and preferences
    this.applyConstraints(optimized, constraints);
    this.applyUserPreferences(optimized, userPreferences);
    
    // Validate and ensure settings are within bounds
    this.validateSettingsBounds(optimized, cameraBrand);
    
    return optimized;
  }

  determineOptimizationStrategy(analysis, mode, userPreferences) {
    // Determine strategy based on scene analysis and user preferences
    if (userPreferences.priorityMode) {
      return userPreferences.priorityMode;
    }
    
    // Auto-determine strategy based on scene characteristics
    if (analysis.exposureAnalysis?.underexposed > 0.2 || analysis.exposureAnalysis?.overexposed > 0.2) {
      return 'exposure_priority';
    }
    
    if (analysis.scene_type === 'portrait' || analysis.has_faces) {
      return 'aperture_priority';
    }
    
    if (analysis.scene_type === 'sports' || analysis.focusAnalysis?.depth === 'varied') {
      return 'exposure_priority'; // For fast shutter speeds
    }
    
    if (analysis.noiseAnalysis?.level > 0.3) {
      return 'iso_priority';
    }
    
    return 'balanced';
  }

  async optimizeExposureTriangle(settings, analysis, strategy, cameraBrand) {
    const currentEV = this.calculateExposureValue(settings);
    const targetEV = this.calculateTargetEV(analysis, currentEV);
    const evDifference = targetEV - currentEV;
    
    if (Math.abs(evDifference) < 0.1) {
      return; // No significant adjustment needed
    }
    
    // Distribute EV adjustment across exposure triangle based on strategy
    const weights = this.optimizationStrategies[strategy] || this.optimizationStrategies.balanced;
    
    // Calculate optimal distribution
    const adjustments = this.calculateOptimalAdjustments(evDifference, weights, settings, analysis, cameraBrand);
    
    // Apply adjustments
    this.applyExposureAdjustments(settings, adjustments, cameraBrand);
  }

  calculateExposureValue(settings) {
    // Convert camera settings to EV
    const apertureNum = parseFloat(settings.aperture.replace('f/', ''));
    const shutterSpeed = this.parseShutterSpeed(settings.shutter_speed);
    const iso = parseInt(settings.iso);
    
    // EV = log2(N²/t) where N = f-number, t = shutter speed in seconds
    const ev = Math.log2((apertureNum * apertureNum) / shutterSpeed) - Math.log2(iso / 100);
    return ev;
  }

  calculateTargetEV(analysis, currentEV) {
    let targetEV = currentEV;
    
    // Adjust based on exposure analysis
    if (analysis.exposureAnalysis) {
      const { underexposed, overexposed, averageBrightness } = analysis.exposureAnalysis;
      
      if (underexposed > 0.3) {
        targetEV -= 1.5; // Increase exposure significantly
      } else if (underexposed > 0.15) {
        targetEV -= 0.7; // Increase exposure moderately
      } else if (overexposed > 0.2) {
        targetEV += 1.0; // Decrease exposure significantly
      } else if (overexposed > 0.1) {
        targetEV += 0.5; // Decrease exposure moderately
      } else if (averageBrightness < 0.3) {
        targetEV -= 0.3; // Slight increase for dark images
      } else if (averageBrightness > 0.7) {
        targetEV += 0.3; // Slight decrease for bright images
      }
    }
    
    // Adjust based on histogram analysis
    if (analysis.histogram?.distribution) {
      const { shadows, highlights } = analysis.histogram.distribution;
      if (shadows > 0.6) {
        targetEV -= 0.5; // Image too dark
      } else if (highlights > 0.6) {
        targetEV += 0.5; // Image too bright
      }
    }
    
    return targetEV;
  }

  calculateOptimalAdjustments(evDifference, weights, currentSettings, analysis, cameraBrand) {
    const adjustments = { iso: 0, aperture: 0, shutterSpeed: 0 };
    
    // Get camera-specific ISO performance
    const isoPerf = this.isoPerformanceCurves[cameraBrand?.toLowerCase()] || this.isoPerformanceCurves.canon;
    const currentISO = parseInt(currentSettings.iso);
    
    // Prioritize adjustments based on weights and current settings
    let remainingEV = evDifference;
    
    // ISO adjustment (logarithmic)
    if (Math.abs(remainingEV) > 0 && weights.iso > 0) {
      const maxISOAdjustment = this.calculateMaxISOAdjustment(currentISO, isoPerf, analysis);
      const isoEVContribution = remainingEV * weights.iso;
      const clampedISOEV = Math.max(-maxISOAdjustment, Math.min(maxISOAdjustment, isoEVContribution));
      
      adjustments.iso = clampedISOEV;
      remainingEV -= clampedISOEV;
    }
    
    // Aperture adjustment
    if (Math.abs(remainingEV) > 0 && weights.aperture > 0) {
      const maxApertureAdjustment = this.calculateMaxApertureAdjustment(currentSettings.aperture, analysis);
      const apertureEVContribution = remainingEV * (weights.aperture / (weights.aperture + weights.shutterSpeed));
      const clampedApertureEV = Math.max(-maxApertureAdjustment, Math.min(maxApertureAdjustment, apertureEVContribution));
      
      adjustments.aperture = clampedApertureEV;
      remainingEV -= clampedApertureEV;
    }
    
    // Shutter speed adjustment (remaining EV)
    if (Math.abs(remainingEV) > 0 && weights.shutterSpeed > 0) {
      adjustments.shutterSpeed = remainingEV;
    }
    
    return adjustments;
  }

  calculateMaxISOAdjustment(currentISO, isoPerf, analysis) {
    // Limit ISO changes based on noise analysis and camera performance
    const noiseLevel = analysis.noiseAnalysis?.level || 0.2;
    
    let maxISO = 1600; // Conservative default
    
    if (noiseLevel < 0.1) {
      maxISO = Math.max(...isoPerf.acceptable);
    } else if (noiseLevel < 0.2) {
      maxISO = Math.max(...isoPerf.good);
    } else {
      maxISO = Math.max(...isoPerf.excellent);
    }
    
    // Convert to EV change
    const maxISOEV = Math.log2(maxISO / currentISO);
    const minISOEV = Math.log2(Math.min(...isoPerf.excellent) / currentISO);
    
    return Math.max(Math.abs(maxISOEV), Math.abs(minISOEV));
  }

  calculateMaxApertureAdjustment(currentAperture, analysis) {
    // Limit aperture changes based on scene requirements
    const currentF = parseFloat(currentAperture.replace('f/', ''));
    
    let maxF = 22; // Wide open limit
    let minF = 1.4; // Stopped down limit
    
    // Adjust limits based on scene analysis
    if (analysis.scene_type === 'portrait' || analysis.has_faces) {
      maxF = 5.6; // Keep reasonable DOF for portraits
    } else if (analysis.scene_type === 'landscape') {
      minF = 5.6; // Ensure good overall sharpness
    } else if (analysis.focusAnalysis?.sharpness < 0.5) {
      minF = Math.max(minF, currentF * 1.4); // Stop down to improve sharpness
    }
    
    const maxFEV = Math.log2(maxF / currentF) * 2; // f-stop to EV conversion
    const minFEV = Math.log2(minF / currentF) * 2;
    
    return Math.max(Math.abs(maxFEV), Math.abs(minFEV));
  }

  applyExposureAdjustments(settings, adjustments, cameraBrand) {
    // Apply ISO adjustment
    if (adjustments.iso !== 0) {
      const currentISO = parseInt(settings.iso);
      const newISO = Math.round(currentISO * Math.pow(2, adjustments.iso));
      settings.iso = this.roundToValidISO(newISO, cameraBrand);
    }
    
    // Apply aperture adjustment
    if (adjustments.aperture !== 0) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      const newF = currentF * Math.pow(2, adjustments.aperture / 2);
      settings.aperture = this.roundToValidAperture(newF);
    }
    
    // Apply shutter speed adjustment
    if (adjustments.shutterSpeed !== 0) {
      const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
      const newShutter = currentShutter / Math.pow(2, adjustments.shutterSpeed);
      settings.shutter_speed = this.roundToValidShutterSpeed(newShutter);
    }
  }

  optimizeFromImageAnalysis(settings, analysis) {
    // Apply optimizations based on detailed image analysis
    
    // Focus optimization
    if (analysis.focusAnalysis) {
      const { overallSharpness, recommendation } = analysis.focusAnalysis;
      
      if (recommendation?.type === 'refocus' || overallSharpness < 0.4) {
        // Suggest stopping down aperture for better sharpness
        const currentF = parseFloat(settings.aperture.replace('f/', ''));
        if (currentF < 5.6) {
          settings.aperture = `f/${Math.min(currentF * 1.4, 5.6).toFixed(1)}`;
        }
      }
    }
    
    // Noise optimization
    if (analysis.noiseAnalysis) {
      const { level, recommendation } = analysis.noiseAnalysis;
      
      if (recommendation?.type === 'reduce_iso' && level > 0.3) {
        // Reduce ISO to minimize noise
        const currentISO = parseInt(settings.iso);
        settings.iso = Math.max(currentISO * 0.7, 100);
      }
    }
    
    // Color optimization
    if (analysis.color?.recommendation) {
      const { type } = analysis.color.recommendation;
      
      if (type === 'adjust_wb') {
        // Auto white balance for color cast issues
        settings.white_balance = 'auto';
      }
    }
  }

  optimizeForScene(settings, sceneType, analysis) {
    // Ensure ISO is a number for calculations
    if (typeof settings.iso === 'string') {
      settings.iso = parseInt(settings.iso) || 400;
    }
    if (!settings.iso || settings.iso < 50) {
      settings.iso = 400;
    }

    switch (sceneType) {
      case 'portrait':
        settings.aperture = 'f/2.8';
        settings.focus_mode = 'single';
        if (analysis && analysis.has_faces) {
          settings.metering_mode = 'spot';
        }
        break;
        
      case 'landscape':
        settings.aperture = 'f/8.0';
        settings.iso = Math.min(settings.iso, 400);
        settings.focus_mode = 'hyperfocal';
        break;
        
      case 'sports':
        settings.shutter_speed = '1/500';
        settings.focus_mode = 'continuous';
        settings.iso = Math.max(settings.iso, 800);
        break;
        
      case 'macro':
        settings.aperture = 'f/5.6';
        settings.focus_mode = 'manual';
        settings.shutter_speed = '1/250';
        break;
        
      case 'low_light':
        settings.iso = Math.min(settings.iso * 1.5, 1600);
        settings.aperture = 'f/2.8';
        break;
        
      default:
        // Keep current settings for unknown scene types
        break;
    }
  }

  optimizeForLighting(settings, lighting, analysis) {
    // Ensure settings.iso is a number
    if (typeof settings.iso === 'string') {
      settings.iso = parseInt(settings.iso) || 400;
    }
    if (!settings.iso || settings.iso < 50) {
      settings.iso = 400;
    }

    switch (lighting) {
      case 'bright':
        settings.iso = 100;
        break;
        
      case 'dim':
      case 'very_dark':
        settings.iso = Math.min(settings.iso * 2, 1600);
        break;
        
      case 'normal':
        settings.iso = Math.max(200, Math.min(settings.iso, 800));
        break;
        
      default:
        // Keep current ISO for unknown lighting conditions
        break;
    }
  }

  optimizeForMode() {
    // Mode-specific optimizations would go here
  }

  optimizeForCamera(settings, brand) {
    // Camera brand specific optimizations
    if (brand && brand.toLowerCase() === 'sony') {
      // Sony cameras handle high ISO well
      if (settings.iso > 800) {
        settings.iso = Math.min(settings.iso * 1.2, 3200);
      }
    }
  }

  // Additional helper methods for the enhanced optimization engine
  parseShutterSpeed(shutterSpeedStr) {
    // Convert shutter speed string to seconds
    if (shutterSpeedStr.includes('/')) {
      const [numerator, denominator] = shutterSpeedStr.split('/').map(Number);
      return numerator / denominator;
    }
    return parseFloat(shutterSpeedStr);
  }

  roundToValidISO(iso, cameraBrand) {
    // Round to valid ISO values for the camera brand
    const validISOs = [50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800, 16000, 20000, 25600];
    
    // Find closest valid ISO
    let closest = validISOs[0];
    let minDiff = Math.abs(iso - closest);
    
    for (const validISO of validISOs) {
      const diff = Math.abs(iso - validISO);
      if (diff < minDiff) {
        minDiff = diff;
        closest = validISO;
      }
    }
    
    return closest;
  }

  roundToValidAperture(fNumber) {
    // Round to valid f-stop values
    const validFStops = [1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10, 11, 13, 14, 16, 18, 20, 22];
    
    let closest = validFStops[0];
    let minDiff = Math.abs(fNumber - closest);
    
    for (const validF of validFStops) {
      const diff = Math.abs(fNumber - validF);
      if (diff < minDiff) {
        minDiff = diff;
        closest = validF;
      }
    }
    
    return `f/${closest}`;
  }

  roundToValidShutterSpeed(seconds) {
    // Round to valid shutter speed values
    const validSpeeds = [
      1/4000, 1/3200, 1/2500, 1/2000, 1/1600, 1/1250, 1/1000, 1/800, 1/640, 1/500,
      1/400, 1/320, 1/250, 1/200, 1/160, 1/125, 1/100, 1/80, 1/60, 1/50, 1/40,
      1/30, 1/25, 1/20, 1/15, 1/13, 1/10, 1/8, 1/6, 1/5, 1/4, 1/3, 1/2.5, 1/2,
      1/1.6, 1/1.3, 1, 1.3, 1.6, 2, 2.5, 3, 4, 5, 6, 8, 10, 13, 15, 20, 25, 30
    ];
    
    let closest = validSpeeds[0];
    let minDiff = Math.abs(seconds - closest);
    
    for (const validSpeed of validSpeeds) {
      const diff = Math.abs(seconds - validSpeed);
      if (diff < minDiff) {
        minDiff = diff;
        closest = validSpeed;
      }
    }
    
    // Format as fraction if less than 1 second
    if (closest < 1) {
      const denominator = Math.round(1 / closest);
      return `1/${denominator}`;
    } else {
      return closest.toString();
    }
  }

  optimizeForSceneAdvanced(settings, analysis, userPreferences) {
    // Enhanced scene-based optimization
    const sceneType = analysis.scene_type;
    
    switch (sceneType) {
      case 'portrait':
        this.optimizeForPortrait(settings, analysis, userPreferences);
        break;
      case 'landscape':
        this.optimizeForLandscape(settings, analysis, userPreferences);
        break;
      case 'sports':
        this.optimizeForSports(settings, analysis, userPreferences);
        break;
      case 'macro':
        this.optimizeForMacro(settings, analysis, userPreferences);
        break;
      case 'low_light':
        this.optimizeForLowLight(settings, analysis, userPreferences);
        break;
      default:
        this.optimizeForGeneral(settings, analysis, userPreferences);
    }
  }

  optimizeForPortrait(settings, analysis, userPreferences) {
    // Portrait-specific optimizations
    if (!userPreferences.preserveAperture) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      if (currentF > 2.8) {
        settings.aperture = 'f/2.8'; // Shallow DOF for portraits
      }
    }
    
    settings.focus_mode = 'single';
    
    if (analysis.has_faces && analysis.focusAnalysis?.bestFocusPoint) {
      settings.metering_mode = 'spot';
    }
    
    // Optimize for skin tones
    if (userPreferences.portraitMode !== 'natural') {
      settings.color_profile = 'portrait';
    }
  }

  optimizeForLandscape(settings, analysis, userPreferences) {
    // Landscape-specific optimizations
    if (!userPreferences.preserveAperture) {
      settings.aperture = 'f/8.0'; // Sweet spot for sharpness
    }
    
    settings.focus_mode = 'hyperfocal';
    
    // Keep ISO low for maximum image quality
    const currentISO = parseInt(settings.iso);
    if (currentISO > 400 && !userPreferences.allowHighISO) {
      settings.iso = Math.min(currentISO, 400);
    }
  }

  optimizeForSports(settings, analysis, userPreferences) {
    // Sports-specific optimizations
    const minShutterSpeed = userPreferences.minSportsShutter || 1/500;
    const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
    
    if (currentShutter > minShutterSpeed) {
      settings.shutter_speed = '1/500';
    }
    
    settings.focus_mode = 'continuous';
    settings.metering_mode = 'matrix';
    
    // Allow higher ISO for faster shutter speeds
    if (currentShutter > minShutterSpeed) {
      const currentISO = parseInt(settings.iso);
      settings.iso = Math.min(currentISO * 2, 3200);
    }
  }

  optimizeForMacro(settings, analysis, userPreferences) {
    // Macro-specific optimizations
    settings.aperture = 'f/5.6'; // Balance DOF and sharpness
    settings.focus_mode = 'manual';
    
    const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
    if (currentShutter > 1/125) {
      settings.shutter_speed = '1/250'; // Minimize camera shake
    }
  }

  optimizeForLowLight(settings, analysis, userPreferences) {
    // Low light optimizations
    const currentISO = parseInt(settings.iso);
    const maxISO = userPreferences.maxLowLightISO || 1600;
    
    settings.iso = Math.min(currentISO * 1.5, maxISO);
    
    const currentF = parseFloat(settings.aperture.replace('f/', ''));
    if (currentF > 2.8 && !userPreferences.preserveAperture) {
      settings.aperture = 'f/2.8';
    }
  }

  optimizeForGeneral(settings, analysis, userPreferences) {
    // General optimizations based on image analysis
    if (analysis.exposureAnalysis?.underexposed > 0.2) {
      // Prioritize fixing underexposure
      const currentISO = parseInt(settings.iso);
      settings.iso = Math.min(currentISO * 1.3, 800);
    }
  }

  applyUserPreferences(settings, userPreferences) {
    // Apply user-specific preferences
    if (userPreferences.preferLowISO) {
      const currentISO = parseInt(settings.iso);
      const maxPreferred = userPreferences.maxPreferredISO || 800;
      settings.iso = Math.min(currentISO, maxPreferred);
    }
    
    if (userPreferences.preferWideAperture && !userPreferences.preserveAperture) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      if (currentF > 2.8) {
        settings.aperture = 'f/2.8';
      }
    }
    
    if (userPreferences.minimumShutterSpeed) {
      const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
      const minShutter = this.parseShutterSpeed(userPreferences.minimumShutterSpeed);
      if (currentShutter > minShutter) {
        settings.shutter_speed = userPreferences.minimumShutterSpeed;
      }
    }
  }

  validateSettingsBounds(settings, cameraBrand) {
    // Ensure all settings are within camera capabilities
    const currentISO = parseInt(settings.iso);
    const isoLimits = this.isoPerformanceCurves[cameraBrand?.toLowerCase()] || this.isoPerformanceCurves.canon;
    
    const minISO = Math.min(...isoLimits.excellent);
    const maxISO = Math.max(...isoLimits.acceptable);
    
    settings.iso = Math.max(minISO, Math.min(maxISO, currentISO));
    
    // Validate aperture range (camera-dependent, using common range)
    const currentF = parseFloat(settings.aperture.replace('f/', ''));
    const validatedF = Math.max(1.4, Math.min(22, currentF));
    settings.aperture = `f/${validatedF}`;
    
    // Validate shutter speed range
    const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
    const validatedShutter = Math.max(1/4000, Math.min(30, currentShutter));
    settings.shutter_speed = this.roundToValidShutterSpeed(validatedShutter);
  }

  applyConstraints(settings, constraints) {
    if (constraints && constraints.maxISO) {
      const currentISO = parseInt(settings.iso);
      settings.iso = Math.min(currentISO, constraints.maxISO);
    }
    
    if (constraints && constraints.minShutterSpeed) {
      const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
      const minShutter = this.parseShutterSpeed(constraints.minShutterSpeed);
      if (currentShutter > minShutter) {
        settings.shutter_speed = constraints.minShutterSpeed;
      }
    }
    
    if (constraints && constraints.maxAperture) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      const maxF = parseFloat(constraints.maxAperture.replace('f/', ''));
      if (currentF > maxF) {
        settings.aperture = constraints.maxAperture;
      }
    }
    
    if (constraints && constraints.minAperture) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      const minF = parseFloat(constraints.minAperture.replace('f/', ''));
      if (currentF < minF) {
        settings.aperture = constraints.minAperture;
      }
    }
  }
}

module.exports = AutoAdjustmentService;