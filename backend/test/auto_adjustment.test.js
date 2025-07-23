const AutoAdjustmentService = require('../src/services/auto_adjustment_service');
const { expect } = require('chai');
const sinon = require('sinon');

describe('Auto-Adjustment Service', () => {
  let autoAdjustmentService;
  let mockCameraService;
  let clock;

  beforeEach(() => {
    autoAdjustmentService = new AutoAdjustmentService();
    clock = sinon.useFakeTimers();
    
    // Mock camera service
    mockCameraService = {
      connectedCamera: {
        brand: 'Canon',
        model: 'EOS R5',
        isConnected: true
      },
      getCameraSettings: sinon.stub().resolves({
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125',
        white_balance: 'auto'
      }),
      setCameraProperty: sinon.stub().resolves(true),
      startLiveView: sinon.stub().resolves(true),
      liveViewSession: null,
      on: sinon.stub(),
      removeAllListeners: sinon.stub()
    };
  });

  afterEach(() => {
    clock.restore();
    if (autoAdjustmentService) {
      autoAdjustmentService.removeAllListeners();
      autoAdjustmentService.stopRealtimeAdjustment();
    }
  });

  describe('Initialization', () => {
    it('should initialize successfully', async () => {
      expect(autoAdjustmentService.isInitialized).to.be.true;
      expect(autoAdjustmentService.optimizationEngine).to.not.be.null;
    });

    it('should load default user preferences', async () => {
      const preferences = autoAdjustmentService.getUserPreferences();
      expect(preferences).to.have.property('preferLowISO', true);
      expect(preferences).to.have.property('maxPreferredISO', 800);
    });

    it('should emit initialized event', (done) => {
      const newService = new AutoAdjustmentService();
      newService.on('initialized', () => {
        done();
      });
    });
  });

  describe('Scene Analysis and Optimization', () => {
    beforeEach(async () => {
      // Ensure service is initialized
      await autoAdjustmentService.initialize();
    });

    it('should analyze image and adjust parameters', async () => {
      const mockImageData = Buffer.from('fake-image-data');
      const options = { mode: 'portrait' };

      const result = await autoAdjustmentService.analyzeAndAdjust(
        mockImageData, 
        mockCameraService, 
        options
      );

      expect(result).to.have.property('analysis');
      expect(result).to.have.property('originalSettings');
      expect(result).to.have.property('optimizedSettings');
      expect(result).to.have.property('confidence');
      expect(result).to.have.property('processingTime');
      expect(result.processingTime).to.be.a('number');
    });

    it('should handle missing camera service', async () => {
      try {
        await autoAdjustmentService.analyzeAndAdjust(null, null);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('No camera connected');
      }
    });

    it('should emit adjustmentCompleted event', (done) => {
      autoAdjustmentService.on('adjustmentCompleted', (result) => {
        expect(result).to.have.property('analysis');
        done();
      });

      const mockImageData = Buffer.from('fake-image-data');
      autoAdjustmentService.analyzeAndAdjust(mockImageData, mockCameraService);
    });

    it('should handle analysis errors gracefully', async () => {
      // Mock the advanced analyzer to throw an error
      const originalCallAnalyzer = autoAdjustmentService.callAdvancedAnalyzer;
      autoAdjustmentService.callAdvancedAnalyzer = sinon.stub().rejects(new Error('Analysis failed'));

      const mockImageData = Buffer.from('fake-image-data');
      const result = await autoAdjustmentService.analyzeAndAdjust(mockImageData, mockCameraService);

      expect(result).to.have.property('analysis');
      expect(result.analysis).to.have.property('scene_type', 'general');
      
      autoAdjustmentService.callAdvancedAnalyzer = originalCallAnalyzer;
    });
  });

  describe('Parameter Optimization', () => {
    beforeEach(async () => {
      await autoAdjustmentService.initialize();
    });

    it('should optimize parameters for portrait mode', async () => {
      const analysis = {
        scene_type: 'portrait',
        lighting_condition: 'normal',
        has_faces: true,
        confidence: 0.8
      };

      const currentSettings = {
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125'
      };

      const optimized = await autoAdjustmentService.optimizeParameters(
        analysis, 
        currentSettings, 
        'Canon'
      );

      expect(optimized.aperture).to.equal('f/2.8');
      expect(optimized.focus_mode).to.equal('single');
      expect(optimized.metering_mode).to.equal('spot');
    });

    it('should optimize parameters for landscape mode', async () => {
      const analysis = {
        scene_type: 'landscape',
        lighting_condition: 'bright',
        has_faces: false,
        confidence: 0.9
      };

      const currentSettings = {
        iso: 800,
        aperture: 'f/4.0',
        shutter_speed: '1/125'
      };

      const optimized = await autoAdjustmentService.optimizeParameters(
        analysis, 
        currentSettings, 
        'Canon'
      );

      expect(optimized.aperture).to.equal('f/8.0');
      expect(optimized.iso).to.be.at.most(400);
      expect(optimized.focus_mode).to.equal('hyperfocal');
    });

    it('should optimize parameters for sports mode', async () => {
      const analysis = {
        scene_type: 'sports',
        lighting_condition: 'normal',
        has_faces: false,
        confidence: 0.7
      };

      const currentSettings = {
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125'
      };

      const optimized = await autoAdjustmentService.optimizeParameters(
        analysis, 
        currentSettings, 
        'Canon'
      );

      expect(optimized.shutter_speed).to.equal('1/500');
      expect(optimized.focus_mode).to.equal('continuous');
      expect(optimized.iso).to.be.at.least(800);
    });

    it('should adjust for low light conditions', async () => {
      const analysis = {
        scene_type: 'general',
        lighting_condition: 'dim',
        has_faces: false,
        confidence: 0.6
      };

      const currentSettings = {
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125'
      };

      const optimized = await autoAdjustmentService.optimizeParameters(
        analysis, 
        currentSettings, 
        'Canon'
      );

      expect(optimized.iso).to.be.greaterThan(400);
      expect(optimized.iso).to.be.at.most(1600);
    });
  });

  describe('Settings Validation', () => {
    it('should validate Canon ISO range', () => {
      const settings = { iso: 100000, aperture: 'f/4.0', shutter_speed: '1/125' };
      mockCameraService.connectedCamera.brand = 'Canon';
      
      const validated = autoAdjustmentService.validateSettings(settings, mockCameraService);
      
      expect(validated.iso).to.be.at.most(51200);
      expect(validated.iso).to.be.at.least(50);
    });

    it('should validate Nikon ISO range', () => {
      const settings = { iso: 100000, aperture: 'f/4.0', shutter_speed: '1/125' };
      mockCameraService.connectedCamera.brand = 'Nikon';
      
      const validated = autoAdjustmentService.validateSettings(settings, mockCameraService);
      
      expect(validated.iso).to.be.at.most(25600);
      expect(validated.iso).to.be.at.least(64);
    });

    it('should validate Sony ISO range', () => {
      const settings = { iso: 200000, aperture: 'f/4.0', shutter_speed: '1/125' };
      mockCameraService.connectedCamera.brand = 'Sony';
      
      const validated = autoAdjustmentService.validateSettings(settings, mockCameraService);
      
      expect(validated.iso).to.be.at.most(102400);
      expect(validated.iso).to.be.at.least(50);
    });

    it('should validate aperture values', () => {
      const settings = { iso: 400, aperture: 'f/32.0', shutter_speed: '1/125' };
      
      const validated = autoAdjustmentService.validateSettings(settings, mockCameraService);
      
      expect(validated.aperture).to.equal('f/4.0'); // Should fallback to safe default
    });

    it('should validate shutter speed values', () => {
      const settings = { iso: 400, aperture: 'f/4.0', shutter_speed: '1/8000' };
      
      const validated = autoAdjustmentService.validateSettings(settings, mockCameraService);
      
      expect(validated.shutter_speed).to.equal('1/125'); // Should fallback to safe default
    });
  });

  describe('Real-time Adjustment', () => {
    beforeEach(async () => {
      await autoAdjustmentService.initialize();
    });

    it('should start real-time adjustment', async () => {
      await autoAdjustmentService.startRealtimeAdjustment(mockCameraService);
      
      expect(autoAdjustmentService.realTimeAnalysisActive).to.be.true;
      expect(autoAdjustmentService.currentCamera).to.equal(mockCameraService);
      expect(autoAdjustmentService.analysisInterval).to.not.be.null;
    });

    it('should stop real-time adjustment', async () => {
      await autoAdjustmentService.startRealtimeAdjustment(mockCameraService);
      await autoAdjustmentService.stopRealtimeAdjustment();
      
      expect(autoAdjustmentService.realTimeAnalysisActive).to.be.false;
      expect(autoAdjustmentService.currentCamera).to.be.null;
      expect(autoAdjustmentService.analysisInterval).to.be.null;
    });

    it('should emit realtimeStarted event', (done) => {
      autoAdjustmentService.on('realtimeStarted', () => {
        done();
      });
      
      autoAdjustmentService.startRealtimeAdjustment(mockCameraService);
    });

    it('should emit realtimeStopped event', (done) => {
      autoAdjustmentService.on('realtimeStopped', () => {
        done();
      });
      
      autoAdjustmentService.startRealtimeAdjustment(mockCameraService).then(() => {
        autoAdjustmentService.stopRealtimeAdjustment();
      });
    });

    it('should handle live view frames', async () => {
      await autoAdjustmentService.startRealtimeAdjustment(mockCameraService);
      
      const frameData = {
        data: Buffer.from('frame-data'),
        width: 1920,
        height: 1080,
        timestamp: Date.now()
      };
      
      // Should not throw
      await autoAdjustmentService.handleLiveViewFrame(frameData);
    });

    it('should perform periodic optimization', async () => {
      await autoAdjustmentService.startRealtimeAdjustment(mockCameraService);
      
      // Should not throw
      await autoAdjustmentService.performPeriodicOptimization();
      
      expect(mockCameraService.getCameraSettings.called).to.be.true;
    });
  });

  describe('Learning and Adaptation', () => {
    beforeEach(async () => {
      await autoAdjustmentService.initialize();
    });

    it('should store analysis results for learning', () => {
      const analysis = {
        scene_type: 'portrait',
        lighting_condition: 'normal',
        has_faces: true
      };

      const originalSettings = { iso: 400, aperture: 'f/4.0' };
      const appliedSettings = { iso: 200, aperture: 'f/2.8' };

      autoAdjustmentService.storeAnalysisResult(analysis, originalSettings, appliedSettings);
      
      const key = autoAdjustmentService.generateAnalysisKey(analysis);
      expect(autoAdjustmentService.analysisHistory.has(key)).to.be.true;
      
      const history = autoAdjustmentService.analysisHistory.get(key);
      expect(history).to.have.length(1);
      expect(history[0]).to.have.property('analysis', analysis);
    });

    it('should apply user preferences', () => {
      const baseSettings = { iso: 1600, aperture: 'f/4.0' };
      const analysis = { scene_type: 'portrait', has_faces: true };
      const userPrefs = { preferLowISO: true, maxPreferredISO: 800, preferWideAperture: true };

      const learned = autoAdjustmentService.applyLearningAdjustments(
        baseSettings, 
        analysis, 
        userPrefs
      );

      expect(learned.iso).to.be.at.most(800);
      expect(learned.aperture).to.equal('f/2.8');
    });

    it('should find similar scenes', () => {
      const analysis1 = { scene_type: 'portrait', lighting_condition: 'normal', has_faces: true };
      const analysis2 = { scene_type: 'portrait', lighting_condition: 'normal', has_faces: true };
      
      autoAdjustmentService.storeAnalysisResult(analysis1, {}, {});
      
      const similarScenes = autoAdjustmentService.findSimilarScenes(analysis2);
      expect(similarScenes).to.have.length(1);
    });

    it('should calculate adjustments made', () => {
      const original = { iso: 400, aperture: 'f/4.0', shutter_speed: '1/125' };
      const applied = { iso: 800, aperture: 'f/2.8', shutter_speed: '1/125' };

      const adjustments = autoAdjustmentService.calculateAdjustmentsMade(original, applied);
      
      expect(adjustments).to.have.property('iso');
      expect(adjustments.iso).to.deep.equal({ from: 400, to: 800 });
      expect(adjustments).to.have.property('aperture');
      expect(adjustments.aperture).to.deep.equal({ from: 'f/4.0', to: 'f/2.8' });
      expect(adjustments).to.not.have.property('shutter_speed');
    });
  });

  describe('Recommendations', () => {
    it('should generate recommendations for low light', () => {
      const analysis = { lighting_condition: 'dim', has_faces: false };
      const settings = { iso: 400, aperture: 'f/4.0' };

      const recommendations = autoAdjustmentService.generateRecommendations(analysis, settings);
      
      expect(recommendations).to.be.an('array');
      expect(recommendations[0]).to.have.property('type', 'suggestion');
      expect(recommendations[0].message).to.include('tripod');
    });

    it('should generate recommendations for portrait', () => {
      const analysis = { lighting_condition: 'normal', has_faces: true };
      const settings = { iso: 400, aperture: 'f/8.0' };

      const recommendations = autoAdjustmentService.generateRecommendations(analysis, settings);
      
      expect(recommendations).to.be.an('array');
      expect(recommendations[0]).to.have.property('type', 'tip');
      expect(recommendations[0].message).to.include('bokeh');
    });
  });

  describe('Error Handling', () => {
    it('should handle advanced analysis failures', async () => {
      // Mock advanced analyzer to fail
      const originalCall = autoAdjustmentService.callAdvancedAnalyzer;
      autoAdjustmentService.callAdvancedAnalyzer = sinon.stub().rejects(new Error('Analysis failed'));

      const result = await autoAdjustmentService.performAdvancedAnalysis(null);
      
      expect(result).to.have.property('scene_type', 'general');
      expect(result).to.have.property('confidence', 0.5);
      
      autoAdjustmentService.callAdvancedAnalyzer = originalCall;
    });

    it('should handle parameter optimization failures', async () => {
      // Mock optimization engine to fail
      const originalOptimize = autoAdjustmentService.optimizationEngine.optimize;
      autoAdjustmentService.optimizationEngine.optimize = sinon.stub().rejects(new Error('Optimization failed'));

      const analysis = { scene_type: 'portrait' };
      const currentSettings = { iso: 400 };
      
      const result = await autoAdjustmentService.optimizeParameters(analysis, currentSettings, 'Canon');
      
      expect(result).to.have.property('iso', 400);
      expect(result).to.have.property('aperture', 'f/4.0');
      
      autoAdjustmentService.optimizationEngine.optimize = originalOptimize;
    });

    it('should emit adjustmentError event on failures', (done) => {
      autoAdjustmentService.on('adjustmentError', (error) => {
        expect(error).to.be.an('error');
        done();
      });

      // Trigger an error by passing invalid parameters
      autoAdjustmentService.analyzeAndAdjust(null, null).catch(() => {
        // Expected to fail
      });
    });
  });

  describe('Utility Functions', () => {
    it('should generate valid analysis keys', () => {
      const analysis = { scene_type: 'portrait', lighting_condition: 'normal', has_faces: true };
      const key = autoAdjustmentService.generateAnalysisKey(analysis);
      
      expect(key).to.equal('portrait_normal_true');
    });

    it('should handle null analysis in key generation', () => {
      const key = autoAdjustmentService.generateAnalysisKey(null);
      expect(key).to.equal('unknown_unknown_false');
    });

    it('should validate shutter speeds correctly', () => {
      expect(autoAdjustmentService.isValidShutterSpeed('1/125')).to.be.true;
      expect(autoAdjustmentService.isValidShutterSpeed('1/4000')).to.be.true;
      expect(autoAdjustmentService.isValidShutterSpeed('1/10000')).to.be.false;
      expect(autoAdjustmentService.isValidShutterSpeed('invalid')).to.be.false;
    });

    it('should generate mock histograms', () => {
      const histogram = autoAdjustmentService.generateMockHistogram();
      expect(histogram).to.be.an('array');
      expect(histogram).to.have.length(256);
      expect(histogram[0]).to.be.a('number');
    });
  });

  describe('Integration with Camera Services', () => {
    it('should apply settings to Canon camera', async () => {
      const settings = {
        iso: 800,
        aperture: 'f/2.8',
        shutter_speed: '1/250',
        white_balance: 'daylight'
      };

      const applied = await autoAdjustmentService.applySettings(settings, mockCameraService);
      
      expect(mockCameraService.setCameraProperty.callCount).to.be.greaterThan(0);
      expect(applied).to.have.property('iso', 800);
      expect(applied).to.have.property('aperture', 'f/2.8');
    });

    it('should handle setting application failures gracefully', async () => {
      mockCameraService.setCameraProperty.rejects(new Error('Setting failed'));
      
      const settings = { iso: 800, aperture: 'f/2.8' };
      const applied = await autoAdjustmentService.applySettings(settings, mockCameraService);
      
      // Should return empty object when all settings fail
      expect(Object.keys(applied)).to.have.length(0);
    });

    it('should work with different camera brands', async () => {
      const analysis = { scene_type: 'portrait', lighting_condition: 'normal' };
      const settings = { iso: 400, aperture: 'f/4.0' };

      // Test Sony optimization
      mockCameraService.connectedCamera.brand = 'Sony';
      const sonyOptimized = await autoAdjustmentService.optimizeParameters(
        analysis, 
        { ...settings, iso: 1000 }, 
        'Sony'
      );
      
      expect(sonyOptimized.iso).to.be.greaterThan(1000); // Sony handles high ISO well
    });
  });
});