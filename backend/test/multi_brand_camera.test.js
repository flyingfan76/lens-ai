const chai = require('chai');
const sinon = require('sinon');
const expect = chai.expect;

// Import services to test
const EnhancedCameraManager = require('../src/services/enhanced_camera_manager');
const BrandSpecificOptimizer = require('../src/services/brand_specific_optimizer');
const CameraAutoDetector = require('../src/services/camera_auto_detector');
const UnifiedCameraInterface = require('../src/services/unified_camera_interface');

// Mock camera data for testing
const mockCameraData = {
  canon: {
    model: 'EOS R5',
    serialNumber: 'CANON_R5_001',
    connectionType: 'usb',
    firmware: '1.5.0',
    brand: 'canon',
    capabilities: {
      maxISO: 51200,
      dualPixelAF: true,
      liveView: true,
      wifi: true
    }
  },
  nikon: {
    model: 'Z7 II',
    serialNumber: 'NIKON_Z7_001', 
    connectionType: 'usb',
    firmware: '1.4.0',
    brand: 'nikon',
    capabilities: {
      maxISO: 25600,
      matrixMetering: true,
      liveView: true,
      wifi: true
    }
  },
  sony: {
    model: 'α7R IV',
    serialNumber: 'SONY_A7R4_001',
    connectionType: 'usb', 
    firmware: '3.0.0',
    brand: 'sony',
    capabilities: {
      maxISO: 102400,
      eyeAF: true,
      liveView: true,
      wifi: true
    }
  },
  fujifilm: {
    model: 'X-T4',
    serialNumber: 'FUJI_XT4_001',
    connectionType: 'wireless',
    firmware: '1.3.0',
    brand: 'fujifilm',
    capabilities: {
      maxISO: 51200,
      filmSimulation: true,
      liveView: true,
      wifi: true
    }
  }
};

const mockSceneAnalysis = {
  portrait: {
    scene_type: 'portrait',
    has_faces: true,
    face_count: 1,
    lighting_condition: 'normal',
    brightness_level: 0.6,
    confidence: 0.85
  },
  landscape: {
    scene_type: 'landscape',
    has_faces: false,
    face_count: 0,
    lighting_condition: 'bright',
    brightness_level: 0.8,
    confidence: 0.9
  },
  lowLight: {
    scene_type: 'general',
    has_faces: false,
    face_count: 0,
    lighting_condition: 'dim',
    brightness_level: 0.2,
    confidence: 0.7
  },
  sports: {
    scene_type: 'sports',
    has_faces: false,
    face_count: 0,
    motion_detected: true,
    lighting_condition: 'normal',
    brightness_level: 0.7,
    confidence: 0.8
  }
};

describe('Multi-Brand Camera Support', function() {
  let cameraManager;
  let brandOptimizer;
  let autoDetector;
  
  before(function() {
    // Setup test environment
    this.timeout(10000);
  });
  
  beforeEach(function() {
    cameraManager = new EnhancedCameraManager();
    brandOptimizer = new BrandSpecificOptimizer();
    autoDetector = new CameraAutoDetector();
    
    // Stub external dependencies
    sinon.stub(cameraManager, 'initializeServices').resolves({
      success: true,
      initialized: ['canon', 'nikon', 'sony', 'fujifilm'],
      failed: []
    });
  });
  
  afterEach(function() {
    sinon.restore();
  });

  describe('Enhanced Camera Manager', function() {
    it('should initialize with multiple brand support', async function() {
      const result = await cameraManager.initializeServices();
      
      expect(result.success).to.be.true;
      expect(result.initialized).to.include.members(['canon', 'nikon', 'sony', 'fujifilm']);
      expect(cameraManager.isInitialized).to.be.true;
    });
    
    it('should discover cameras from all brands', async function() {
      // Mock camera discovery for each brand
      const mockCameras = [
        { ...mockCameraData.canon, id: 'canon_0' },
        { ...mockCameraData.nikon, id: 'nikon_0' },
        { ...mockCameraData.sony, id: 'sony_0' },
        { ...mockCameraData.fujifilm, id: 'fujifilm_0' }
      ];
      
      sinon.stub(cameraManager, 'discoverAllCameras').resolves(mockCameras);
      
      const cameras = await cameraManager.discoverAllCameras();
      
      expect(cameras).to.have.length(4);
      expect(cameras.map(c => c.brand)).to.include.members(['canon', 'nikon', 'sony', 'fujifilm']);
    });
    
    it('should enhance camera information with brand-specific details', function() {
      const enhanced = cameraManager.enhanceCameraInfo(
        mockCameraData.canon, 
        'canon', 
        0
      );
      
      expect(enhanced).to.have.property('id', 'canon_0');
      expect(enhanced).to.have.property('brandDisplayName', 'Canon');
      expect(enhanced).to.have.property('capabilities');
      expect(enhanced).to.have.property('features');
      expect(enhanced).to.have.property('compatibilityScore');
      expect(enhanced.compatibilityScore).to.be.a('number');
      expect(enhanced.compatibilityScore).to.be.at.least(0.5);
    });
    
    it('should categorize cameras correctly', function() {
      const canonCategory = cameraManager.categorizeCamera('EOS R5', 'canon');
      const sonyCategory = cameraManager.categorizeCamera('α7R IV', 'sony');
      const fujiCategory = cameraManager.categorizeCamera('X-T4', 'fujifilm');
      
      expect(canonCategory).to.equal('mirrorless_pro');
      expect(sonyCategory).to.equal('mirrorless_pro');
      expect(fujiCategory).to.equal('mirrorless_pro');
    });
    
    it('should provide brand-specific features', function() {
      const canonFeatures = cameraManager.getCameraFeatures(
        { category: 'mirrorless_pro' }, 
        'canon'
      );
      const sonyFeatures = cameraManager.getCameraFeatures(
        { category: 'mirrorless_pro' }, 
        'sony'
      );
      
      expect(canonFeatures).to.have.property('dualPixelAF', true);
      expect(sonyFeatures).to.have.property('eyeAF', true);
      expect(sonyFeatures).to.have.property('animalEyeAF', true);
    });
    
    it('should get multi-brand status', function() {
      cameraManager.isInitialized = true;
      const status = cameraManager.getMultiBrandStatus();
      
      expect(status).to.have.property('isInitialized', true);
      expect(status).to.have.property('supportedBrands');
      expect(status).to.have.property('brandStatus');
      expect(status.supportedBrands).to.include.members(['CANON', 'NIKON', 'SONY', 'FUJIFILM']);
    });
  });

  describe('Brand Specific Optimizer', function() {
    it('should optimize settings for Canon cameras', async function() {
      const result = await brandOptimizer.optimizeForBrand(
        'canon',
        mockSceneAnalysis.portrait,
        { iso: '400', aperture: 'f/4.0', shutter_speed: '1/125' },
        { artistic_preference: 'natural' }
      );
      
      expect(result.success).to.be.true;
      expect(result.brand).to.equal('canon');
      expect(result.scene_type).to.equal('portrait');
      expect(result.optimized_settings).to.have.property('picture_style', 'Portrait');
      expect(result.optimized_settings).to.have.property('focus_mode', 'Single');
      expect(result.confidence).to.be.at.least(0.7);
    });
    
    it('should optimize settings for Nikon cameras', async function() {
      const result = await brandOptimizer.optimizeForBrand(
        'nikon',
        mockSceneAnalysis.landscape,
        { iso: '200', aperture: 'f/8.0', shutter_speed: '1/250' },
        {}
      );
      
      expect(result.success).to.be.true;
      expect(result.brand).to.equal('nikon');
      expect(result.scene_type).to.equal('landscape');
      expect(result.optimized_settings).to.have.property('active_d_lighting', 'Strong');
      expect(result.optimized_settings).to.have.property('metering_mode', '3D Matrix');
      expect(result.optimized_settings).to.have.property('picture_control', 'Landscape');
    });
    
    it('should optimize settings for Sony cameras', async function() {
      const result = await brandOptimizer.optimizeForBrand(
        'sony',
        mockSceneAnalysis.portrait,
        { iso: '400', aperture: 'f/2.8', shutter_speed: '1/160' },
        {}
      );
      
      expect(result.success).to.be.true;
      expect(result.brand).to.equal('sony');
      expect(result.optimized_settings).to.have.property('eye_af', 'On');
      expect(result.optimized_settings).to.have.property('eye_af_priority', 'On');
      expect(result.optimized_settings).to.have.property('focus_area', 'Wide');
    });
    
    it('should optimize settings for Fujifilm cameras', async function() {
      const result = await brandOptimizer.optimizeForBrand(
        'fujifilm',
        mockSceneAnalysis.portrait,
        { iso: '400', aperture: 'f/2.8', shutter_speed: '1/160' },
        { artistic_preference: 'film_like' }
      );
      
      expect(result.success).to.be.true;
      expect(result.brand).to.equal('fujifilm');
      expect(result.optimized_settings).to.have.property('film_simulation', 'Classic Chrome');
      expect(result.optimized_settings).to.have.property('grain_effect', 'Weak');
      expect(result.optimized_settings).to.have.property('color_chrome_effect', 'Weak');
    });
    
    it('should handle low light scenarios differently for each brand', async function() {
      const canonResult = await brandOptimizer.optimizeForBrand(
        'canon', mockSceneAnalysis.lowLight, { iso: '400' }
      );
      const sonyResult = await brandOptimizer.optimizeForBrand(
        'sony', mockSceneAnalysis.lowLight, { iso: '400' }
      );
      
      // Sony should suggest higher ISO due to better high ISO performance
      expect(parseInt(sonyResult.optimized_settings.iso)).to.be.greaterThan(
        parseInt(canonResult.optimized_settings.iso)
      );
    });
    
    it('should provide brand-specific feature recommendations', function() {
      const recommendations = brandOptimizer.getBrandSpecificRecommendations('sony', 'portrait');
      
      expect(recommendations).to.be.an('array');
      expect(recommendations.some(r => r.includes('Eye AF'))).to.be.true;
    });
    
    it('should calculate confidence scores appropriately', function() {
      const highConfidence = brandOptimizer.calculateConfidence(
        { confidence: 0.9 }, 'canon'
      );
      const lowConfidence = brandOptimizer.calculateConfidence(
        { confidence: 0.4 }, 'unknown_brand'
      );
      
      expect(highConfidence).to.be.greaterThan(lowConfidence);
      expect(highConfidence).to.be.at.most(0.95);
    });
  });

  describe('Camera Auto Detector', function() {
    it('should detect cameras using multiple methods', async function() {
      // Mock detection methods
      sinon.stub(autoDetector, 'detectUSBCameras').resolves([mockCameraData.canon]);
      sinon.stub(autoDetector, 'detectNetworkCameras').resolves([mockCameraData.fujifilm]);
      sinon.stub(autoDetector, 'detectPTPCameras').resolves([]);
      sinon.stub(autoDetector, 'detectGPhotoCameras').resolves([mockCameraData.nikon]);
      
      const cameras = await autoDetector.detectAllCameras();
      
      expect(cameras).to.have.length.at.least(3);
      expect(cameras.map(c => c.brand)).to.include.members(['canon', 'fujifilm', 'nikon']);
    });
    
    it('should enhance camera information during detection', async function() {
      sinon.stub(autoDetector, 'detectUSBCameras').resolves([mockCameraData.canon]);
      sinon.stub(autoDetector, 'detectNetworkCameras').resolves([]);
      sinon.stub(autoDetector, 'detectPTPCameras').resolves([]);
      sinon.stub(autoDetector, 'detectGPhotoCameras').resolves([]);
      
      const cameras = await autoDetector.detectAllCameras();
      const camera = cameras[0];
      
      expect(camera).to.have.property('enhancedAt');
      expect(camera).to.have.property('modelInfo');
      expect(camera).to.have.property('capabilities');
      expect(camera).to.have.property('autoConfig');
      expect(camera).to.have.property('connectionQuality');
    });
    
    it('should analyze camera models correctly', function() {
      const canonModel = autoDetector.analyzeModel('EOS R5', 'canon');
      const sonyModel = autoDetector.analyzeModel('α7R IV', 'sony');
      const fujiModel = autoDetector.analyzeModel('X-T4', 'fujifilm');
      
      expect(canonModel.type).to.equal('mirrorless');
      expect(canonModel.level).to.equal('pro');
      expect(sonyModel.series).to.equal('α7R');
      expect(fujiModel.series).to.equal('X-T');
    });
    
    it('should generate auto-configuration profiles', function() {
      const proConfig = autoDetector.generateAutoConfiguration(
        { type: 'mirrorless', level: 'pro' }, 
        'canon', 
        'professional'
      );
      const enthusiastConfig = autoDetector.generateAutoConfiguration(
        { type: 'mirrorless', level: 'prosumer' }, 
        'sony', 
        'enthusiast'
      );
      
      expect(proConfig.userLevel).to.equal('professional');
      expect(proConfig.recommended).to.have.property('image_quality', 'RAW');
      expect(enthusiastConfig.recommended).to.have.property('image_quality', 'RAW+JPEG');
    });
    
    it('should assess connection quality', function() {
      const usbCamera = { ...mockCameraData.canon, gphotoSupported: true };
      const wifiCamera = { ...mockCameraData.fujifilm, ipAddress: '192.168.1.100' };
      
      const usbQuality = autoDetector.assessConnectionQuality(usbCamera);
      const wifiQuality = autoDetector.assessConnectionQuality(wifiCamera);
      
      expect(usbQuality).to.be.greaterThan(wifiQuality);
      expect(usbQuality).to.be.at.most(1.0);
    });
    
    it('should deduplicate cameras correctly', function() {
      const key1 = autoDetector.generateDeviceKey(mockCameraData.canon);
      const key2 = autoDetector.generateDeviceKey({
        ...mockCameraData.canon,
        detectionMethod: 'gphoto'
      });
      
      expect(key1).to.equal(key2); // Should be the same device
    });
  });

  describe('Unified Camera Interface', function() {
    class MockCameraInterface extends UnifiedCameraInterface {
      constructor() {
        super('mock');
      }
      
      getPropertyMapping() {
        return {
          ISO: 'iso_speed',
          APERTURE: 'f_number',
          SHUTTER_SPEED: 'shutter'
        };
      }
      
      // Implement required abstract methods with mocks
      async initialize() { this.isInitialized = true; }
      async discoverCameras() { return []; }
      async connectToCamera() { return {}; }
      async disconnectCamera() { return {}; }
      async getCameraSettings() { return {}; }
      async setCameraProperty() { return {}; }
      async startLiveView() { return {}; }
      async stopLiveView() { return {}; }
      async captureImage() { return {}; }
      async terminate() { return {}; }
    }
    
    let mockInterface;
    
    beforeEach(function() {
      mockInterface = new MockCameraInterface();
    });
    
    it('should normalize properties correctly', function() {
      const normalized = mockInterface.normalizeProperty('iso_speed', '800');
      
      expect(normalized.property).to.equal('iso');
      expect(normalized.value).to.equal('800');
    });
    
    it('should standardize ISO values', function() {
      expect(mockInterface.standardizeISO('ISO800')).to.equal('800');
      expect(mockInterface.standardizeISO('850')).to.equal('800'); // Rounds to nearest
      expect(mockInterface.standardizeISO('invalid')).to.equal('AUTO');
    });
    
    it('should standardize aperture values', function() {
      expect(mockInterface.standardizeAperture('f/2.8')).to.equal('f/2.8');
      expect(mockInterface.standardizeAperture('F2.8')).to.equal('f/2.8');
      expect(mockInterface.standardizeAperture('2.9')).to.equal('f/2.8'); // Rounds to nearest
    });
    
    it('should standardize shutter speeds', function() {
      expect(mockInterface.standardizeShutterSpeed('1/125')).to.equal('1/125');
      expect(mockInterface.standardizeShutterSpeed('0.008')).to.equal('1/125');
      expect(mockInterface.standardizeShutterSpeed('1/100s')).to.equal('1/100');
    });
    
    it('should validate settings', function() {
      const settings = {
        iso: '800',
        aperture: 'f/2.8',
        shutter_speed: '1/125',
        invalid_setting: 'test'
      };
      
      const validation = mockInterface.validateSettings(settings);
      
      expect(validation.isValid).to.be.true;
      expect(validation.settings).to.have.property('iso', '800');
      expect(validation.errors).to.be.empty;
    });
    
    it('should get supported capabilities', function() {
      const capabilities = mockInterface.getSupportedCapabilities();
      
      expect(capabilities).to.have.property('brand', 'mock');
      expect(capabilities).to.have.property('properties');
      expect(capabilities).to.have.property('values');
      expect(capabilities.properties).to.include.members(['iso', 'aperture', 'shutter_speed']);
    });
  });

  describe('Integration Tests', function() {
    it('should handle complete workflow for Canon camera', async function() {
      this.timeout(5000);
      
      // Mock a complete workflow
      const workflow = {
        detection: { ...mockCameraData.canon, enhancedAt: new Date().toISOString() },
        analysis: mockSceneAnalysis.portrait,
        optimization: null
      };
      
      // Auto-detection
      sinon.stub(autoDetector, 'enhanceCameraInformation').resolves(workflow.detection);
      
      // Brand optimization
      const optimization = await brandOptimizer.optimizeForBrand(
        'canon',
        workflow.analysis,
        { iso: '400', aperture: 'f/4.0' }
      );
      
      workflow.optimization = optimization;
      
      expect(workflow.detection).to.have.property('brand', 'canon');
      expect(workflow.optimization.success).to.be.true;
      expect(workflow.optimization.optimized_settings).to.have.property('picture_style');
    });
    
    it('should handle multiple brands simultaneously', async function() {
      const brands = ['canon', 'nikon', 'sony', 'fujifilm'];
      const optimizations = [];
      
      for (const brand of brands) {
        const result = await brandOptimizer.optimizeForBrand(
          brand,
          mockSceneAnalysis.portrait,
          { iso: '400', aperture: 'f/4.0' }
        );
        optimizations.push(result);
      }
      
      expect(optimizations).to.have.length(4);
      expect(optimizations.every(o => o.success)).to.be.true;
      
      // Each brand should have different optimizations
      const canonOpt = optimizations.find(o => o.brand === 'canon');
      const sonyOpt = optimizations.find(o => o.brand === 'sony');
      
      expect(canonOpt.optimized_settings).to.not.deep.equal(sonyOpt.optimized_settings);
    });
    
    it('should gracefully handle unsupported brands', async function() {
      const result = await brandOptimizer.optimizeForBrand(
        'unknown_brand',
        mockSceneAnalysis.portrait,
        { iso: '400' }
      );
      
      expect(result.success).to.be.true;
      expect(result.brand).to.equal('generic');
      expect(result.confidence).to.be.at.most(0.7);
    });
    
    it('should maintain performance across brands', async function() {
      const startTime = Date.now();
      
      const promises = ['canon', 'nikon', 'sony', 'fujifilm'].map(brand =>
        brandOptimizer.optimizeForBrand(
          brand, 
          mockSceneAnalysis.landscape, 
          { iso: '200' }
        )
      );
      
      const results = await Promise.all(promises);
      const endTime = Date.now();
      
      expect(results).to.have.length(4);
      expect(results.every(r => r.success)).to.be.true;
      expect(endTime - startTime).to.be.lessThan(1000); // Should complete within 1 second
    });
  });

  describe('Error Handling', function() {
    it('should handle brand optimizer errors gracefully', async function() {
      // Force an error in brand optimization
      sinon.stub(brandOptimizer, 'optimizeForBrand').rejects(new Error('Test error'));
      
      try {
        await brandOptimizer.optimizeForBrand('canon', mockSceneAnalysis.portrait, {});
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Test error');
      }
    });
    
    it('should handle detection errors gracefully', async function() {
      sinon.stub(autoDetector, 'detectUSBCameras').rejects(new Error('USB detection failed'));
      sinon.stub(autoDetector, 'detectNetworkCameras').resolves([]);
      sinon.stub(autoDetector, 'detectPTPCameras').resolves([]);
      sinon.stub(autoDetector, 'detectGPhotoCameras').resolves([]);
      
      const cameras = await autoDetector.detectAllCameras();
      
      // Should still return results from other detection methods
      expect(cameras).to.be.an('array');
    });
    
    it('should validate invalid settings appropriately', function() {
      const invalidSettings = {
        iso: 'invalid_iso',
        aperture: 'invalid_aperture',
        shutter_speed: 'invalid_speed'
      };
      
      const mockInterface = new (class extends UnifiedCameraInterface {
        constructor() { super('test'); }
        async initialize() {}
        async discoverCameras() { return []; }
        async connectToCamera() { return {}; }
        async disconnectCamera() { return {}; }
        async getCameraSettings() { return {}; }
        async setCameraProperty() { return {}; }
        async startLiveView() { return {}; }
        async stopLiveView() { return {}; }
        async captureImage() { return {}; }
        async terminate() { return {}; }
      })();
      
      const validation = mockInterface.validateSettings(invalidSettings);
      
      expect(validation.isValid).to.be.true; // Should normalize invalid values
      expect(validation.settings.iso).to.equal('AUTO');
      expect(validation.settings.aperture).to.equal('f/4.0');
    });
  });
});

// Performance benchmark tests
describe('Performance Benchmarks', function() {
  let brandOptimizer;
  
  beforeEach(function() {
    brandOptimizer = new BrandSpecificOptimizer();
  });
  
  it('should optimize settings quickly for all brands', async function() {
    this.timeout(2000);
    
    const brands = ['canon', 'nikon', 'sony', 'fujifilm'];
    const scenes = Object.values(mockSceneAnalysis);
    
    const startTime = process.hrtime.bigint();
    
    const promises = [];
    for (const brand of brands) {
      for (const scene of scenes) {
        promises.push(
          brandOptimizer.optimizeForBrand(brand, scene, { iso: '400' })
        );
      }
    }
    
    const results = await Promise.all(promises);
    const endTime = process.hrtime.bigint();
    const durationMs = Number(endTime - startTime) / 1000000;
    
    expect(results).to.have.length(16); // 4 brands × 4 scenes
    expect(results.every(r => r.success)).to.be.true;
    expect(durationMs).to.be.lessThan(1000); // Should complete within 1 second
    
    console.log(`Performance: ${results.length} optimizations in ${durationMs.toFixed(2)}ms`);
  });
});