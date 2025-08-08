const EventEmitter = require('events');
const path = require('path');
const { spawn } = require('child_process');
const axios = require('axios');
const logger = require('../utils/logger');

class NeRFIntegrationService extends EventEmitter {
  constructor(config = {}) {
    super();
    this.nerfServiceUrl = config.nerfServiceUrl || 'http://localhost:8001';
    this.nerfServiceRunning = false;
    this.nerfProcess = null;
    this.connectionRetries = 0;
    this.maxRetries = 5;
    this.retryDelay = 2000;
    
    // NeRF analysis configuration
    this.analysisConfig = {
      enableRealTime: config.enableRealTime || true,
      analysisMode: config.analysisMode || 'real_time', // 'fast', 'real_time', 'quality'
      maxProcessingTime: config.maxProcessingTime || 10000, // ms
      fallbackToTraditional: config.fallbackToTraditional !== false
    };
    
    this.initialize();
  }

  async initialize() {
    try {
      logger.info('Initializing NeRF Integration Service...');
      
      // Start NeRF service if not running
      await this.ensureNeRFServiceRunning();
      
      // Test connection
      await this.testConnection();
      
      logger.info('NeRF Integration Service initialized successfully');
      this.emit('initialized');
      
    } catch (error) {
      logger.warn('NeRF Integration Service initialization failed, running in fallback mode:', error);
      this.emit('fallbackMode', error);
    }
  }

  async ensureNeRFServiceRunning() {
    try {
      // Check if service is already running
      const response = await axios.get(`${this.nerfServiceUrl}/health`, { timeout: 5000 });
      if (response.status === 200) {
        this.nerfServiceRunning = true;
        logger.info('NeRF service is already running');
        return;
      }
    } catch (error) {
      logger.info('NeRF service not running, attempting to start...');
    }

    // Start NeRF service
    await this.startNeRFService();
  }

  async startNeRFService() {
    return new Promise((resolve, reject) => {
      const nerfServicePath = path.join(__dirname, '../../ai/nerf/nerf_service.py');
      
      logger.info('Starting NeRF service...');
      
      this.nerfProcess = spawn('python3', [
        nerfServicePath,
        '--mode', 'serve',
        '--host', '0.0.0.0',
        '--port', '8001'
      ], {
        stdio: ['pipe', 'pipe', 'pipe'],
        detached: false,
        env: { ...process.env, PYTHONPATH: path.join(__dirname, '../../ai') }
      });

      let serviceStarted = false;
      const startupTimeout = setTimeout(() => {
        if (!serviceStarted) {
          logger.error('NeRF service startup timeout');
          reject(new Error('NeRF service startup timeout'));
        }
      }, 30000); // 30 second timeout

      this.nerfProcess.stdout.on('data', (data) => {
        const output = data.toString();
        logger.debug(`NeRF service: ${output}`);
        
        // Look for service ready indicators
        if (output.includes('Application startup complete') || output.includes('Uvicorn running')) {
          serviceStarted = true;
          clearTimeout(startupTimeout);
          this.nerfServiceRunning = true;
          logger.info('NeRF service started successfully');
          
          // Wait a moment for full initialization
          setTimeout(() => resolve(), 2000);
        }
      });

      this.nerfProcess.stderr.on('data', (data) => {
        logger.warn(`NeRF service error: ${data.toString()}`);
      });

      this.nerfProcess.on('close', (code) => {
        logger.warn(`NeRF service process exited with code ${code}`);
        this.nerfServiceRunning = false;
        this.nerfProcess = null;
        
        if (!serviceStarted) {
          clearTimeout(startupTimeout);
          reject(new Error(`NeRF service failed to start (exit code: ${code})`));
        }
      });

      this.nerfProcess.on('error', (error) => {
        logger.error('Failed to start NeRF service:', error);
        clearTimeout(startupTimeout);
        if (!serviceStarted) {
          reject(error);
        }
      });
    });
  }

  async testConnection() {
    let retries = 0;
    while (retries < this.maxRetries) {
      try {
        const response = await axios.get(`${this.nerfServiceUrl}/health`, { timeout: 5000 });
        if (response.status === 200) {
          logger.info('NeRF service connection test successful');
          return response.data;
        }
      } catch (error) {
        retries++;
        logger.warn(`NeRF service connection attempt ${retries} failed:`, error.message);
        
        if (retries < this.maxRetries) {
          await new Promise(resolve => setTimeout(resolve, this.retryDelay));
        }
      }
    }
    
    throw new Error('Failed to connect to NeRF service after maximum retries');
  }

  async analyzeImageWithNeRF(imageData, options = {}) {
    if (!this.nerfServiceRunning && this.analysisConfig.fallbackToTraditional) {
      logger.warn('NeRF service not available, using traditional analysis');
      return null; // Will trigger fallback in calling service
    }

    try {
      const analysisOptions = {
        analysisMode: options.analysisMode || this.analysisConfig.analysisMode,
        optimizeCameraParams: options.optimizeCameraParams !== false,
        ...options
      };

      let analysisResult;

      if (Buffer.isBuffer(imageData)) {
        // Handle binary image data upload
        analysisResult = await this.analyzeImageUpload(imageData, analysisOptions);
      } else if (typeof imageData === 'string') {
        // Handle image file path
        analysisResult = await this.analyzeImagePath(imageData, analysisOptions);
      } else {
        throw new Error('Invalid image data format');
      }

      // Transform NeRF result for backend compatibility
      return this.transformNeRFResultForBackend(analysisResult);

    } catch (error) {
      logger.error('NeRF image analysis failed:', error);
      
      if (this.analysisConfig.fallbackToTraditional) {
        logger.info('Falling back to traditional analysis');
        return null; // Trigger fallback
      }
      
      throw error;
    }
  }

  async analyzeImageUpload(imageBuffer, options) {
    const FormData = require('form-data');
    const form = new FormData();
    
    form.append('file', imageBuffer, {
      filename: 'image.jpg',
      contentType: 'image/jpeg'
    });

    const response = await axios.post(`${this.nerfServiceUrl}/analyze/upload`, form, {
      headers: {
        ...form.getHeaders(),
      },
      timeout: this.analysisConfig.maxProcessingTime,
      maxContentLength: 50 * 1024 * 1024 // 50MB max
    });

    return response.data;
  }

  async analyzeImagePath(imagePath, options) {
    const requestData = {
      image_path: imagePath,
      analysis_mode: options.analysisMode,
      optimize_camera_params: options.optimizeCameraParams
    };

    // Add camera data if provided
    if (options.cameraData) {
      if (options.cameraData.poses) {
        requestData.camera_poses = options.cameraData.poses;
      }
      if (options.cameraData.intrinsics) {
        requestData.camera_intrinsics = options.cameraData.intrinsics;
      }
    }

    const response = await axios.post(`${this.nerfServiceUrl}/analyze`, requestData, {
      timeout: this.analysisConfig.maxProcessingTime,
      headers: { 'Content-Type': 'application/json' }
    });

    return response.data;
  }

  transformNeRFResultForBackend(nerfResult) {
    try {
      // Transform NeRF analysis result to match expected backend format
      const enhanced = {
        // Basic scene information (compatible with existing system)
        scene_type: this.mapNeRFSceneType(nerfResult),
        scene_confidence: this.calculateSceneConfidence(nerfResult),
        lighting_condition: this.mapNeRFLighting(nerfResult),
        lighting_confidence: this.calculateLightingConfidence(nerfResult),
        
        // Enhanced 3D analysis data
        nerf_analysis: {
          enabled: true,
          processing_time: nerfResult.processing_time || 0,
          analysis_type: nerfResult.analysis_type || 'nerf_3d',
          
          // Depth information
          depth_available: !!nerfResult.depth_analysis,
          scene_bounds: nerfResult.depth_analysis?.depth_distribution || {},
          depth_complexity: nerfResult.depth_analysis?.depth_complexity || 0,
          
          // 3D scene structure
          focal_regions: this.extractFocalRegions(nerfResult),
          depth_layers: nerfResult.depth_analysis?.depth_layers || [],
          
          // Enhanced lighting analysis
          lighting_3d: {
            distribution: nerfResult.lighting_analysis?.lighting_distribution || {},
            quality_score: nerfResult.lighting_analysis?.lighting_quality?.quality_score || 0.5,
            recommendations: nerfResult.lighting_analysis?.lighting_recommendations || []
          },
          
          // Composition analysis
          composition_3d: {
            score: nerfResult.composition_analysis?.composition_score || 0.5,
            subject_isolation: nerfResult.composition_analysis?.subject_isolation || {},
            depth_layers_composition: nerfResult.composition_analysis?.depth_layers_composition || {}
          }
        },
        
        // Enhanced camera recommendations
        enhanced_recommendations: this.extractCameraRecommendations(nerfResult),
        
        // Advanced metrics for the existing system
        advanced_metrics: {
          nerf_confidence: this.calculateOverallNeRFConfidence(nerfResult),
          depth_understanding_score: this.calculateDepthScore(nerfResult),
          scene_3d_score: this.calculateScene3DScore(nerfResult),
          optimization_quality: this.assessOptimizationQuality(nerfResult)
        },
        
        // Compatibility fields
        has_faces: this.detectFacesFromNeRF(nerfResult),
        face_count: this.countFacesFromNeRF(nerfResult),
        face_regions: this.extractFaceRegions(nerfResult),
        dominant_colors: this.extractDominantColors(nerfResult),
        brightness_level: this.calculateBrightnessFromNeRF(nerfResult),
        contrast_level: this.calculateContrastFromNeRF(nerfResult)
      };

      // Ensure backward compatibility
      this.ensureBackwardCompatibility(enhanced);
      
      return enhanced;
      
    } catch (error) {
      logger.error('Error transforming NeRF result:', error);
      return this.createFallbackResult();
    }
  }

  mapNeRFSceneType(nerfResult) {
    // Map NeRF analysis to traditional scene types
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    const depthComplexity = nerfResult.depth_analysis?.depth_complexity || 0;
    
    if (focalRegions.length > 0) {
      const mainFocus = focalRegions[0];
      
      // Use depth and focus information to infer scene type
      if (mainFocus.depth < 2 && focalRegions.length === 1) {
        return 'portrait';
      } else if (depthComplexity > 5) {
        return 'landscape';
      } else if (mainFocus.focus_score > 0.8 && mainFocus.depth < 1) {
        return 'macro';
      }
    }
    
    // Check lighting for low light scenes
    const lightingQuality = nerfResult.lighting_analysis?.lighting_quality?.quality_score || 0.5;
    if (lightingQuality < 0.3) {
      return 'low_light';
    }
    
    return 'general';
  }

  mapNeRFLighting(nerfResult) {
    const lightingAnalysis = nerfResult.lighting_analysis;
    
    if (!lightingAnalysis) {
      return 'normal';
    }
    
    const qualityScore = lightingAnalysis.lighting_quality?.quality_score || 0.5;
    const distribution = lightingAnalysis.lighting_distribution || {};
    
    if (qualityScore < 0.3 || distribution.uniform_lighting === false) {
      return 'dim';
    } else if (qualityScore > 0.8) {
      return 'bright';
    }
    
    return 'normal';
  }

  extractFocalRegions(nerfResult) {
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    
    return focalRegions.map(region => ({
      depth: region.depth,
      focus_score: region.focus_score,
      size_ratio: region.size_ratio,
      suggested_aperture: this.suggestApertureForDepth(region.depth, region.focus_score),
      suggested_focus_distance: region.depth
    }));
  }

  extractCameraRecommendations(nerfResult) {
    const cameraOpt = nerfResult.camera_optimization || {};
    const recommendations = {};
    
    // Extract exposure recommendations
    if (cameraOpt.exposure) {
      recommendations.exposure = {
        iso_adjustment: cameraOpt.exposure.iso_adjustment,
        iso_reason: cameraOpt.exposure.iso_reason,
        exposure_compensation: this.calculateExposureCompensation(cameraOpt.exposure)
      };
    }
    
    // Extract focus recommendations
    if (cameraOpt.focus) {
      recommendations.focus = {
        optimal_distance: cameraOpt.focus.optimal_focus_distance,
        focus_mode: cameraOpt.focus.focus_mode,
        focus_point: cameraOpt.focus.focus_point,
        reason: cameraOpt.focus.reason
      };
    }
    
    // Extract depth of field recommendations
    if (cameraOpt.depth_of_field) {
      recommendations.aperture = {
        suggested_aperture: cameraOpt.depth_of_field.aperture,
        aperture_reason: cameraOpt.depth_of_field.reason,
        dof_effect: this.analyzeDOFEffect(cameraOpt.depth_of_field)
      };
    }
    
    // Extract composition recommendations
    if (cameraOpt.composition) {
      recommendations.composition = {
        suggestions: cameraOpt.composition.composition_suggestions || [],
        framing_advice: this.generateFramingAdvice(nerfResult),
        subject_placement: this.analyzeSubjectPlacement(nerfResult)
      };
    }
    
    return recommendations;
  }

  // Helper methods for transformation
  calculateSceneConfidence(nerfResult) {
    const factors = [
      nerfResult.depth_analysis?.depth_complexity || 0,
      nerfResult.composition_analysis?.composition_score || 0.5,
      nerfResult.lighting_analysis?.lighting_quality?.quality_score || 0.5
    ];
    
    return factors.reduce((sum, val) => sum + val, 0) / factors.length;
  }

  calculateLightingConfidence(nerfResult) {
    return nerfResult.lighting_analysis?.lighting_quality?.quality_score || 0.5;
  }

  calculateOverallNeRFConfidence(nerfResult) {
    if (nerfResult.status !== 'success') {
      return 0.1;
    }
    
    const scores = [
      this.calculateSceneConfidence(nerfResult),
      this.calculateLightingConfidence(nerfResult),
      nerfResult.composition_analysis?.composition_score || 0.5
    ];
    
    return scores.reduce((sum, score) => sum + score, 0) / scores.length;
  }

  calculateDepthScore(nerfResult) {
    const depthAnalysis = nerfResult.depth_analysis;
    if (!depthAnalysis) return 0.3;
    
    const complexity = depthAnalysis.depth_complexity || 0;
    const layers = depthAnalysis.depth_layers?.length || 0;
    
    return Math.min(1.0, (complexity / 10) * 0.7 + (layers / 5) * 0.3);
  }

  calculateScene3DScore(nerfResult) {
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    const depthScore = this.calculateDepthScore(nerfResult);
    const compositionScore = nerfResult.composition_analysis?.composition_score || 0.5;
    
    const regionScore = focalRegions.length > 0 ? focalRegions[0].focus_score : 0.3;
    
    return (depthScore * 0.4 + compositionScore * 0.4 + regionScore * 0.2);
  }

  assessOptimizationQuality(nerfResult) {
    const hasRecommendations = Object.keys(nerfResult.camera_optimization || {}).length > 0;
    const processingTime = nerfResult.processing_time || 0;
    
    if (!hasRecommendations) return 0.2;
    
    // Quality decreases with longer processing times
    const timeScore = Math.max(0.1, 1.0 - (processingTime / 10000));
    const recommendationScore = hasRecommendations ? 0.8 : 0.2;
    
    return (timeScore * 0.3 + recommendationScore * 0.7);
  }

  // Compatibility methods
  detectFacesFromNeRF(nerfResult) {
    // Simplified face detection based on focal regions and scene type
    const sceneType = this.mapNeRFSceneType(nerfResult);
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    
    return sceneType === 'portrait' && focalRegions.length > 0;
  }

  countFacesFromNeRF(nerfResult) {
    return this.detectFacesFromNeRF(nerfResult) ? 1 : 0;
  }

  extractFaceRegions(nerfResult) {
    if (!this.detectFacesFromNeRF(nerfResult)) return [];
    
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    if (focalRegions.length === 0) return [];
    
    // Create mock face region based on main focal region
    return [{
      x: 0.5, // Center - would need actual position data
      y: 0.5,
      width: 0.2,
      height: 0.2,
      confidence: focalRegions[0].focus_score
    }];
  }

  extractDominantColors(nerfResult) {
    // Mock dominant colors - would need actual color analysis from NeRF
    return [[128, 128, 128]]; // Gray fallback
  }

  calculateBrightnessFromNeRF(nerfResult) {
    const lightingQuality = nerfResult.lighting_analysis?.lighting_quality?.quality_score;
    return lightingQuality || 0.5;
  }

  calculateContrastFromNeRF(nerfResult) {
    const depthComplexity = nerfResult.depth_analysis?.depth_complexity || 0;
    return Math.min(1.0, depthComplexity / 10);
  }

  // Utility methods
  suggestApertureForDepth(depth, focusScore) {
    if (depth < 1 && focusScore > 0.8) {
      return 'f/2.8'; // Close subject, shallow DOF
    } else if (depth > 5) {
      return 'f/8.0'; // Distant subject, deeper DOF
    }
    return 'f/4.0'; // Balanced
  }

  calculateExposureCompensation(exposure) {
    if (exposure.iso_adjustment === 'increase') {
      return '+0.7';
    } else if (exposure.iso_adjustment === 'decrease') {
      return '-0.7';
    }
    return '0.0';
  }

  analyzeDOFEffect(dofSettings) {
    const aperture = dofSettings.aperture;
    const fStop = parseFloat(aperture.replace('f/', ''));
    
    if (fStop <= 2.8) {
      return 'shallow';
    } else if (fStop >= 8.0) {
      return 'deep';
    }
    return 'moderate';
  }

  generateFramingAdvice(nerfResult) {
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    const advice = [];
    
    if (focalRegions.length > 1) {
      advice.push('Multiple subjects detected - consider rule of thirds');
    }
    
    const composition = nerfResult.composition_analysis?.depth_layers_composition;
    if (composition?.foreground_ratio < 0.2) {
      advice.push('Consider adding foreground elements for depth');
    }
    
    return advice;
  }

  analyzeSubjectPlacement(nerfResult) {
    const focalRegions = nerfResult.scene_analysis?.focal_regions || [];
    
    if (focalRegions.length === 0) {
      return 'No clear subject detected';
    }
    
    const mainSubject = focalRegions[0];
    if (mainSubject.depth < 2) {
      return 'Subject in foreground - good isolation';
    } else if (mainSubject.depth > 5) {
      return 'Subject in background - consider moving closer';
    }
    
    return 'Subject well positioned';
  }

  ensureBackwardCompatibility(enhanced) {
    // Ensure all required fields exist for backward compatibility
    enhanced.scene_type = enhanced.scene_type || 'general';
    enhanced.scene_confidence = enhanced.scene_confidence || 0.5;
    enhanced.lighting_condition = enhanced.lighting_condition || 'normal';
    enhanced.lighting_confidence = enhanced.lighting_confidence || 0.5;
    enhanced.has_faces = enhanced.has_faces || false;
    enhanced.face_count = enhanced.face_count || 0;
    enhanced.face_regions = enhanced.face_regions || [];
    enhanced.dominant_colors = enhanced.dominant_colors || [[128, 128, 128]];
    enhanced.brightness_level = enhanced.brightness_level || 0.5;
    enhanced.contrast_level = enhanced.contrast_level || 0.3;
  }

  createFallbackResult() {
    return {
      scene_type: 'general',
      scene_confidence: 0.3,
      lighting_condition: 'normal',
      lighting_confidence: 0.3,
      has_faces: false,
      face_count: 0,
      face_regions: [],
      dominant_colors: [[128, 128, 128]],
      brightness_level: 0.5,
      contrast_level: 0.3,
      nerf_analysis: {
        enabled: false,
        error: 'NeRF analysis failed, using fallback'
      },
      enhanced_recommendations: {},
      advanced_metrics: {
        nerf_confidence: 0.1,
        depth_understanding_score: 0.1,
        scene_3d_score: 0.1,
        optimization_quality: 0.1
      }
    };
  }

  // Service management methods
  async stopNeRFService() {
    if (this.nerfProcess) {
      logger.info('Stopping NeRF service...');
      this.nerfProcess.kill('SIGTERM');
      
      // Wait for graceful shutdown
      await new Promise(resolve => {
        this.nerfProcess.on('close', () => {
          logger.info('NeRF service stopped');
          resolve();
        });
        
        // Force kill if not stopped within 10 seconds
        setTimeout(() => {
          if (this.nerfProcess) {
            this.nerfProcess.kill('SIGKILL');
          }
          resolve();
        }, 10000);
      });
      
      this.nerfProcess = null;
      this.nerfServiceRunning = false;
    }
  }

  async restartNeRFService() {
    await this.stopNeRFService();
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    await this.startNeRFService();
  }

  getServiceStatus() {
    return {
      running: this.nerfServiceRunning,
      url: this.nerfServiceUrl,
      config: this.analysisConfig,
      processId: this.nerfProcess ? this.nerfProcess.pid : null
    };
  }

  // Event cleanup
  async cleanup() {
    await this.stopNeRFService();
    this.removeAllListeners();
  }
}

module.exports = NeRFIntegrationService;