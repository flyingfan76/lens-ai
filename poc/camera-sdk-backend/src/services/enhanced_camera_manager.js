const EventEmitter = require('events');
const logger = require('../utils/logger');

// Import unified camera services
const CanonSDKService = require('./canon_sdk_service');
const NikonSDKService = require('./nikon_sdk_service');
const SonySDKService = require('./sony_sdk_service');
const FujifilmSDKService = require('./fujifilm_sdk_service');

class EnhancedCameraManager extends EventEmitter {
  constructor() {
    super();
    
    // Camera service instances
    this.cameraServices = new Map();
    this.availableCameras = [];
    this.connectedCameras = new Map();
    this.activeCameraId = null;
    this.isInitialized = false;
    
    // Supported camera brands with their service classes
    this.supportedBrands = {
      CANON: { class: CanonSDKService, name: 'canon', displayName: 'Canon' },
      NIKON: { class: NikonSDKService, name: 'nikon', displayName: 'Nikon' },
      SONY: { class: SonySDKService, name: 'sony', displayName: 'Sony' },
      FUJIFILM: { class: FujifilmSDKService, name: 'fujifilm', displayName: 'Fujifilm' }
    };
    
    // Camera detection patterns
    this.detectionPatterns = {
      canon: ['EOS', 'PowerShot', 'IXUS'],
      nikon: ['D\\d+', 'Z\\d+', 'COOLPIX'],
      sony: ['α', 'Alpha', 'FX\\d+', 'RX\\d+', 'A\\d+'],
      fujifilm: ['X-[A-Z]\\d+', 'GFX\\d+', 'FinePix']
    };
    
    // Brand-specific capabilities and optimizations
    this.brandCapabilities = {
      canon: {
        maxISO: 51200,
        dualPixelAF: true,
        customFunctions: true,
        lensCorrections: true,
        colorProfiles: ['Standard', 'Portrait', 'Landscape', 'Neutral', 'Faithful']
      },
      nikon: {
        maxISO: 25600,
        matrixMetering: true,
        activeD_Lighting: true,
        pictureControls: true,
        colorProfiles: ['Standard', 'Neutral', 'Vivid', 'Monochrome', 'Portrait', 'Landscape']
      },
      sony: {
        maxISO: 102400,
        eyeAF: true,
        animalEyeAF: true,
        realTimeTracking: true,
        colorProfiles: ['Standard', 'Vivid', 'Neutral', 'Clear', 'Deep', 'Light', 'Portrait', 'Landscape']
      },
      fujifilm: {
        maxISO: 51200,
        filmSimulation: true,
        grainEffect: true,
        colorChrome: true,
        colorProfiles: ['Provia', 'Velvia', 'Astia', 'Classic Chrome', 'Pro Neg.', 'Acros', 'Eterna']
      }
    };
    
    // Performance metrics
    this.performanceMetrics = {
      discoveryTime: {},
      connectionTime: {},
      captureTime: {},
      liveViewLatency: {}
    };
    
    this.initializeServices();
  }

  async initializeServices() {
    try {
      logger.info('Initializing Enhanced Camera Manager with multi-brand support...');
      
      // Initialize all camera services
      const initPromises = [];
      
      for (const [brandKey, brandInfo] of Object.entries(this.supportedBrands)) {
        try {
          const service = new brandInfo.class();
          this.cameraServices.set(brandInfo.name, service);
          
          // Setup event forwarding
          this.setupServiceEventForwarding(service, brandInfo.name);
          
          // Initialize service
          initPromises.push(
            service.initialize()
              .then(() => {
                logger.info(`${brandInfo.displayName} service initialized successfully`);
                return { brand: brandInfo.name, success: true };
              })
              .catch(error => {
                logger.warn(`${brandInfo.displayName} service initialization failed:`, error);
                return { brand: brandInfo.name, success: false, error };
              })
          );
        } catch (error) {
          logger.error(`Failed to create ${brandInfo.displayName} service:`, error);
        }
      }
      
      // Wait for all initializations
      const results = await Promise.all(initPromises);
      
      // Log initialization results
      const successful = results.filter(r => r.success);
      const failed = results.filter(r => !r.success);
      
      logger.info(`Camera services initialized: ${successful.length} successful, ${failed.length} failed`);
      
      if (successful.length === 0) {
        throw new Error('No camera services could be initialized');
      }
      
      this.isInitialized = true;
      
      // Start auto-discovery
      this.startAutoDiscovery();
      
      return {
        success: true,
        initialized: successful.map(r => r.brand),
        failed: failed.map(r => ({ brand: r.brand, error: r.error?.message }))
      };
      
    } catch (error) {
      logger.error('Failed to initialize Enhanced Camera Manager:', error);
      throw error;
    }
  }

  setupServiceEventForwarding(service, brandName) {
    // Forward standardized events from individual services
    service.on('camerasDiscovered', (cameras) => {
      this.handleCamerasDiscovered(brandName, cameras);
    });
    
    service.on('cameraConnected', (camera) => {
      this.handleCameraConnected(brandName, camera);
    });
    
    service.on('cameraDisconnected', (camera) => {
      this.handleCameraDisconnected(brandName, camera);
    });
    
    service.on('liveViewFrame', (frameData) => {
      this.emit('liveViewFrame', { ...frameData, brand: brandName });
    });
    
    service.on('imageCaptured', (imageInfo) => {
      this.emit('imageCaptured', { ...imageInfo, brand: brandName });
    });
    
    service.on('cameraError', (errorInfo) => {
      this.emit('cameraError', { ...errorInfo, brand: brandName });
    });
    
    service.on('performanceMetric', (metric) => {
      this.handlePerformanceMetric(brandName, metric);
    });
  }

  async discoverAllCameras(options = {}) {
    if (!this.isInitialized) {
      throw new Error('Camera Manager not initialized');
    }

    try {
      logger.info('Discovering cameras from all supported brands...');
      const startTime = Date.now();
      
      // Discover cameras from all services in parallel
      const discoveryPromises = [];
      
      for (const [brandName, service] of this.cameraServices) {
        discoveryPromises.push(
          service.discoverCameras()
            .then(cameras => ({ brand: brandName, cameras, success: true }))
            .catch(error => {
              logger.warn(`Camera discovery failed for ${brandName}:`, error);
              return { brand: brandName, cameras: [], success: false, error };
            })
        );
      }
      
      const results = await Promise.all(discoveryPromises);
      const discoveryTime = Date.now() - startTime;
      
      // Process discovery results
      this.availableCameras = [];
      let totalCameras = 0;
      
      for (const result of results) {
        if (result.success && result.cameras.length > 0) {
          const enhancedCameras = result.cameras.map((camera, index) => 
            this.enhanceCameraInfo(camera, result.brand, index)
          );
          
          this.availableCameras.push(...enhancedCameras);
          totalCameras += result.cameras.length;
          
          // Update performance metrics
          this.performanceMetrics.discoveryTime[result.brand] = discoveryTime;
        }
      }
      
      // Auto-detect camera models and enhance information
      await this.autoDetectCameraModels();
      
      logger.info(`Discovery completed: ${totalCameras} cameras found across ${results.filter(r => r.success).length} brands in ${discoveryTime}ms`);
      
      this.emit('allCamerasDiscovered', {
        cameras: this.availableCameras,
        totalCount: totalCameras,
        brandCounts: results.reduce((acc, r) => {
          acc[r.brand] = r.cameras.length;
          return acc;
        }, {}),
        discoveryTime
      });
      
      return this.availableCameras;
      
    } catch (error) {
      logger.error('Failed to discover cameras:', error);
      throw error;
    }
  }

  enhanceCameraInfo(camera, brand, index) {
    const brandCapabilities = this.brandCapabilities[brand] || {};
    const detectedModel = this.detectCameraModel(camera.model || '', brand);
    
    return {
      ...camera,
      id: `${brand}_${index}`,
      brand,
      brandDisplayName: this.supportedBrands[brand.toUpperCase()]?.displayName || brand,
      detectedModel,
      capabilities: {
        ...brandCapabilities,
        ...camera.capabilities
      },
      features: this.getCameraFeatures(detectedModel, brand),
      recommended: this.getCameraRecommendations(detectedModel, brand),
      compatibilityScore: this.calculateCompatibilityScore(camera, brand)
    };
  }

  detectCameraModel(modelString, brand) {
    const patterns = this.detectionPatterns[brand] || [];
    
    for (const pattern of patterns) {
      const regex = new RegExp(pattern, 'i');
      const match = modelString.match(regex);
      if (match) {
        return {
          detected: true,
          series: match[0],
          fullModel: modelString,
          category: this.categorizeCamera(match[0], brand)
        };
      }
    }
    
    return {
      detected: false,
      series: 'Unknown',
      fullModel: modelString,
      category: 'unknown'
    };
  }

  categorizeCamera(series, brand) {
    const categories = {
      canon: {
        'EOS R': 'mirrorless_pro',
        'EOS 5D': 'dslr_pro',
        'EOS 6D': 'dslr_prosumer',
        'EOS 90D': 'dslr_enthusiast',
        'PowerShot': 'compact'
      },
      nikon: {
        'Z9': 'mirrorless_pro',
        'Z7': 'mirrorless_pro',
        'Z6': 'mirrorless_prosumer',
        'Z5': 'mirrorless_enthusiast',
        'D850': 'dslr_pro',
        'D780': 'dslr_prosumer'
      },
      sony: {
        'α7R': 'mirrorless_pro',
        'α7': 'mirrorless_prosumer',
        'α6': 'mirrorless_enthusiast',
        'FX': 'cinema',
        'RX': 'compact_pro'
      },
      fujifilm: {
        'GFX': 'medium_format',
        'X-T': 'mirrorless_pro',
        'X-H': 'mirrorless_pro',
        'X-Pro': 'mirrorless_pro',
        'X-E': 'mirrorless_enthusiast',
        'X100': 'compact_pro'
      }
    };
    
    const brandCategories = categories[brand] || {};
    
    for (const [model, category] of Object.entries(brandCategories)) {
      if (series.includes(model)) {
        return category;
      }
    }
    
    return 'general';
  }

  getCameraFeatures(detectedModel, brand) {
    const baseFeatures = {
      liveView: true,
      remoteCapture: true,
      settingsControl: true,
      autoFocus: true
    };
    
    // Add brand-specific features
    const brandFeatures = {
      canon: {
        dualPixelAF: detectedModel.category !== 'compact',
        touchscreen: true,
        wifi: true,
        bluetooth: detectedModel.category === 'mirrorless_pro'
      },
      nikon: {
        matrixMetering: true,
        activeD_Lighting: true,
        snapBridge: true,
        wifi: true
      },
      sony: {
        eyeAF: detectedModel.category.includes('pro'),
        animalEyeAF: detectedModel.category.includes('pro'),
        realTimeTracking: true,
        wifi: true,
        bluetooth: true
      },
      fujifilm: {
        filmSimulation: true,
        grainEffect: true,
        colorChrome: detectedModel.category !== 'compact_pro',
        wifi: true,
        bluetooth: true
      }
    };
    
    return {
      ...baseFeatures,
      ...brandFeatures[brand]
    };
  }

  getCameraRecommendations(detectedModel, brand) {
    const recommendations = {
      optimal_use_cases: [],
      recommended_settings: {},
      accessories: [],
      tips: []
    };
    
    // Add category-specific recommendations
    switch (detectedModel.category) {
      case 'mirrorless_pro':
      case 'dslr_pro':
        recommendations.optimal_use_cases = ['Professional Photography', 'Studio Work', 'Sports', 'Wildlife'];
        recommendations.recommended_settings = {
          image_quality: 'RAW',
          metering_mode: 'Matrix',
          focus_mode: 'Continuous'
        };
        recommendations.accessories = ['Professional Tripod', 'External Flash', 'Battery Grip'];
        break;
        
      case 'mirrorless_prosumer':
      case 'dslr_prosumer':
        recommendations.optimal_use_cases = ['Portrait Photography', 'Landscapes', 'Events'];
        recommendations.recommended_settings = {
          image_quality: 'RAW+JPEG',
          metering_mode: 'Matrix'
        };
        recommendations.accessories = ['Sturdy Tripod', 'UV Filter'];
        break;
        
      case 'compact_pro':
        recommendations.optimal_use_cases = ['Street Photography', 'Travel', 'Everyday Carry'];
        recommendations.recommended_settings = {
          image_quality: 'JPEG Fine'
        };
        recommendations.accessories = ['Compact Tripod', 'Extra Battery'];
        break;
    }
    
    // Add brand-specific recommendations
    if (brand === 'fujifilm') {
      recommendations.tips.push('Experiment with Film Simulation modes for unique looks');
      recommendations.recommended_settings.film_simulation = 'Classic Chrome';
    }
    
    if (brand === 'sony') {
      recommendations.tips.push('Use Eye AF for portrait photography');
    }
    
    return recommendations;
  }

  calculateCompatibilityScore(camera, brand) {
    let score = 0.5; // Base score
    
    // Increase score based on features
    if (camera.connectionType === 'wifi') score += 0.2;
    if (camera.firmware && camera.firmware !== 'Unknown') score += 0.1;
    if (camera.batteryLevel !== 'unknown') score += 0.1;
    if (camera.memoryCardStatus === 'ready') score += 0.1;
    
    // Brand-specific scoring
    const brandBonus = {
      canon: 0.95,
      nikon: 0.9,
      sony: 0.85,
      fujifilm: 0.8
    };
    
    score = Math.min(1.0, score * (brandBonus[brand] || 0.7));
    
    return Math.round(score * 100) / 100; // Round to 2 decimal places
  }

  async autoDetectCameraModels() {
    // Enhanced auto-detection logic
    for (const camera of this.availableCameras) {
      if (!camera.detectedModel.detected) {
        // Try alternative detection methods
        try {
          // Could implement firmware-based detection, USB vendor ID lookup, etc.
          const alternativeDetection = await this.alternativeModelDetection(camera);
          if (alternativeDetection.detected) {
            camera.detectedModel = alternativeDetection;
            camera.features = this.getCameraFeatures(alternativeDetection, camera.brand);
          }
        } catch (error) {
          logger.debug(`Alternative detection failed for camera ${camera.id}:`, error);
        }
      }
    }
  }

  async alternativeModelDetection(camera) {
    // Placeholder for advanced detection methods
    // Could query camera for additional info, check USB descriptors, etc.
    return camera.detectedModel;
  }

  async connectToCamera(cameraId, options = {}) {
    const camera = this.availableCameras.find(cam => cam.id === cameraId);
    if (!camera) {
      throw new Error(`Camera not found: ${cameraId}`);
    }

    try {
      logger.info(`Connecting to ${camera.brandDisplayName} camera: ${camera.model}`);
      const startTime = Date.now();
      
      const service = this.cameraServices.get(camera.brand);
      if (!service) {
        throw new Error(`Service not available for brand: ${camera.brand}`);
      }
      
      // Connect using brand-specific service
      const connectedCamera = await service.connectToCamera(camera.index);
      
      const connectionTime = Date.now() - startTime;
      this.performanceMetrics.connectionTime[camera.brand] = connectionTime;
      
      // Store enhanced connection info
      const enhancedConnection = {
        ...connectedCamera,
        ...camera,
        connectedAt: new Date().toISOString(),
        connectionTime,
        service
      };
      
      this.connectedCameras.set(cameraId, enhancedConnection);
      this.activeCameraId = cameraId;
      
      logger.info(`Successfully connected to ${camera.brandDisplayName} ${camera.model} in ${connectionTime}ms`);
      
      // Emit enhanced connection event
      this.emit('cameraConnected', {
        cameraId,
        camera: enhancedConnection,
        connectionTime,
        capabilities: camera.capabilities,
        features: camera.features,
        recommendations: camera.recommended
      });
      
      return {
        success: true,
        cameraId,
        cameraInfo: enhancedConnection,
        connectionTime,
        compatibilityScore: camera.compatibilityScore
      };
      
    } catch (error) {
      logger.error(`Failed to connect to camera ${cameraId}:`, error);
      throw error;
    }
  }

  // Enhanced camera operations with brand-aware optimizations
  async getCameraSettings(cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    const connection = this.connectedCameras.get(targetCameraId);
    
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }

    try {
      const rawSettings = await connection.service.getCameraSettings();
      
      // Apply brand-specific enhancements
      const enhancedSettings = this.enhanceSettings(rawSettings, connection.brand);
      
      return {
        success: true,
        cameraId: targetCameraId,
        brand: connection.brand,
        brandDisplayName: connection.brandDisplayName,
        settings: enhancedSettings,
        capabilities: connection.capabilities,
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      logger.error(`Failed to get settings for camera ${targetCameraId}:`, error);
      throw error;
    }
  }

  enhanceSettings(rawSettings, brand) {
    // Add brand-specific setting enhancements
    const enhanced = { ...rawSettings };
    
    // Add brand-specific fields
    if (brand === 'fujifilm') {
      enhanced.brand_specific = {
        film_simulation: rawSettings.film_simulation || 'Provia/Standard',
        grain_effect: rawSettings.grain_effect || 'Off',
        color_chrome: rawSettings.color_chrome || 'Off'
      };
    } else if (brand === 'sony') {
      enhanced.brand_specific = {
        eye_af: rawSettings.eye_af || 'Off',
        real_time_tracking: rawSettings.real_time_tracking || 'Off'
      };
    } else if (brand === 'canon') {
      enhanced.brand_specific = {
        dual_pixel_af: rawSettings.dual_pixel_af || 'On',
        color_space: rawSettings.color_space || 'sRGB'
      };
    } else if (brand === 'nikon') {
      enhanced.brand_specific = {
        active_d_lighting: rawSettings.active_d_lighting || 'Auto',
        picture_control: rawSettings.picture_control || 'Standard'
      };
    }
    
    return enhanced;
  }

  // Performance monitoring and optimization
  handlePerformanceMetric(brand, metric) {
    if (!this.performanceMetrics[metric.operation]) {
      this.performanceMetrics[metric.operation] = {};
    }
    
    this.performanceMetrics[metric.operation][brand] = {
      ...metric,
      timestamp: Date.now()
    };
    
    // Emit aggregated performance data
    this.emit('performanceUpdate', {
      brand,
      operation: metric.operation,
      duration: metric.duration,
      success: metric.success,
      aggregated: this.getAggregatedPerformance()
    });
  }

  getAggregatedPerformance() {
    const aggregated = {};
    
    for (const [operation, brandMetrics] of Object.entries(this.performanceMetrics)) {
      aggregated[operation] = {
        brands: Object.keys(brandMetrics).length,
        avgDuration: 0,
        successRate: 0,
        fastest: null,
        slowest: null
      };
      
      const durations = [];
      let successCount = 0;
      
      for (const [brand, metric] of Object.entries(brandMetrics)) {
        if (typeof metric === 'object' && metric.duration) {
          durations.push({ brand, duration: metric.duration });
          if (metric.success) successCount++;
        } else if (typeof metric === 'number') {
          durations.push({ brand, duration: metric });
          successCount++;
        }
      }
      
      if (durations.length > 0) {
        aggregated[operation].avgDuration = durations.reduce((sum, d) => sum + d.duration, 0) / durations.length;
        aggregated[operation].successRate = successCount / durations.length;
        aggregated[operation].fastest = durations.reduce((min, d) => d.duration < min.duration ? d : min);
        aggregated[operation].slowest = durations.reduce((max, d) => d.duration > max.duration ? d : max);
      }
    }
    
    return aggregated;
  }

  // Auto-discovery for plug-and-play experience
  startAutoDiscovery(interval = 10000) {
    if (this.autoDiscoveryInterval) {
      clearInterval(this.autoDiscoveryInterval);
    }
    
    this.autoDiscoveryInterval = setInterval(async () => {
      try {
        const currentCameraCount = this.availableCameras.length;
        await this.discoverAllCameras();
        
        if (this.availableCameras.length !== currentCameraCount) {
          logger.info(`Camera list updated: ${this.availableCameras.length} cameras available`);
          this.emit('cameraListChanged', {
            previousCount: currentCameraCount,
            currentCount: this.availableCameras.length,
            cameras: this.availableCameras
          });
        }
      } catch (error) {
        logger.debug('Auto-discovery error:', error);
      }
    }, interval);
    
    logger.info(`Auto-discovery started with ${interval}ms interval`);
  }

  stopAutoDiscovery() {
    if (this.autoDiscoveryInterval) {
      clearInterval(this.autoDiscoveryInterval);
      this.autoDiscoveryInterval = null;
      logger.info('Auto-discovery stopped');
    }
  }

  // Event handlers
  handleCamerasDiscovered(brand, cameras) {
    logger.debug(`${brand} cameras discovered:`, cameras.length);
  }

  handleCameraConnected(brand, camera) {
    logger.info(`${brand} camera connected:`, camera.model);
  }

  handleCameraDisconnected(brand, camera) {
    logger.info(`${brand} camera disconnected:`, camera.model);
    
    // Clean up connection records
    for (const [cameraId, connection] of this.connectedCameras) {
      if (connection.brand === brand && connection.serialNumber === camera.serialNumber) {
        this.connectedCameras.delete(cameraId);
        if (this.activeCameraId === cameraId) {
          this.activeCameraId = null;
        }
        break;
      }
    }
  }

  // Status and information methods
  getMultiBrandStatus() {
    const brandStatus = {};
    
    for (const [brandName, service] of this.cameraServices) {
      brandStatus[brandName] = {
        initialized: service.isInitialized,
        availableCameras: this.availableCameras.filter(c => c.brand === brandName).length,
        connectedCameras: Array.from(this.connectedCameras.values()).filter(c => c.brand === brandName).length,
        capabilities: this.brandCapabilities[brandName] || {},
        performance: this.performanceMetrics
      };
    }
    
    return {
      isInitialized: this.isInitialized,
      totalAvailableCameras: this.availableCameras.length,
      totalConnectedCameras: this.connectedCameras.size,
      activeCameraId: this.activeCameraId,
      supportedBrands: Object.keys(this.supportedBrands),
      brandStatus,
      autoDiscoveryActive: !!this.autoDiscoveryInterval
    };
  }

  getSupportedBrandsList() {
    return Object.entries(this.supportedBrands).map(([key, info]) => ({
      key,
      name: info.name,
      displayName: info.displayName,
      capabilities: this.brandCapabilities[info.name] || {},
      initialized: this.cameraServices.has(info.name) && this.cameraServices.get(info.name).isInitialized
    }));
  }

  // Cleanup
  async terminate() {
    try {
      logger.info('Terminating Enhanced Camera Manager...');
      
      this.stopAutoDiscovery();
      
      // Disconnect all cameras
      for (const [cameraId] of this.connectedCameras) {
        try {
          await this.disconnectCamera(cameraId);
        } catch (error) {
          logger.warn(`Error disconnecting camera ${cameraId}:`, error);
        }
      }
      
      // Terminate all services
      const terminatePromises = [];
      for (const [brandName, service] of this.cameraServices) {
        terminatePromises.push(
          service.terminate().catch(error => {
            logger.warn(`Error terminating ${brandName} service:`, error);
          })
        );
      }
      
      await Promise.all(terminatePromises);
      
      // Clear state
      this.cameraServices.clear();
      this.availableCameras = [];
      this.connectedCameras.clear();
      this.activeCameraId = null;
      this.isInitialized = false;
      
      logger.info('Enhanced Camera Manager terminated successfully');
      
    } catch (error) {
      logger.error('Error during Enhanced Camera Manager termination:', error);
      throw error;
    }
  }

  // Forward remaining methods from original camera manager
  async disconnectCamera(cameraId) {
    const connection = this.connectedCameras.get(cameraId);
    if (!connection) {
      throw new Error(`Camera not connected: ${cameraId}`);
    }

    try {
      await connection.service.disconnectCamera();
      this.connectedCameras.delete(cameraId);
      
      if (this.activeCameraId === cameraId) {
        this.activeCameraId = null;
      }
      
      return { success: true };
    } catch (error) {
      logger.error(`Failed to disconnect camera ${cameraId}:`, error);
      throw error;
    }
  }

  async setCameraProperty(property, value, cameraId = null) {
    const targetCameraId = cameraId || this.activeCameraId;
    const connection = this.connectedCameras.get(targetCameraId);
    
    if (!connection) {
      throw new Error(`Camera not connected: ${targetCameraId}`);
    }

    try {
      await connection.service.setCameraProperty(property, value);
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
}

module.exports = EnhancedCameraManager;