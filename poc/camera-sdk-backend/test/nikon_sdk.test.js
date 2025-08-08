const NikonSDKService = require('../src/services/nikon_sdk_service');
const { expect } = require('chai');
const sinon = require('sinon');

describe('Nikon SDK Service', () => {
  let nikonSDK;
  let clock;

  beforeEach(() => {
    nikonSDK = new NikonSDKService();
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
    if (nikonSDK) {
      nikonSDK.removeAllListeners();
    }
  });

  describe('Initialization', () => {
    it('should initialize successfully', async () => {
      const result = await nikonSDK.initialize();
      expect(result).to.be.true;
      expect(nikonSDK.isInitialized).to.be.true;
    });

    it('should handle initialization failure', async () => {
      nikonSDK.isInitialized = false;
      nikonSDK.loadNativeModule = () => { throw new Error('Nikon SDK not found'); };
      
      try {
        await nikonSDK.initialize();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Nikon SDK not properly loaded');
      }
    });
  });

  describe('Camera Discovery', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
    });

    it('should discover connected Nikon cameras', async () => {
      const cameras = await nikonSDK.discoverCameras();
      
      expect(cameras).to.be.an('array');
      expect(cameras).to.have.length.at.least(0);
      
      if (cameras.length > 0) {
        expect(cameras[0]).to.have.property('brand', 'Nikon');
        expect(cameras[0]).to.have.property('model');
        expect(cameras[0]).to.have.property('serialNumber');
        expect(cameras[0]).to.have.property('firmwareVersion');
        expect(cameras[0]).to.have.property('batteryLevel');
        expect(cameras[0]).to.have.property('capabilities');
      }
    });

    it('should emit camerasDiscovered event', (done) => {
      nikonSDK.on('camerasDiscovered', (cameras) => {
        expect(cameras).to.be.an('array');
        cameras.forEach(camera => {
          expect(camera.brand).to.equal('Nikon');
        });
        done();
      });
      
      nikonSDK.discoverCameras();
    });
  });

  describe('Camera Connection', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
      await nikonSDK.discoverCameras();
    });

    it('should connect to first available Nikon camera', async () => {
      if (nikonSDK.cameraList.length === 0) {
        // Simulate a Nikon camera for testing
        nikonSDK.cameraList.push({
          index: 0,
          brand: 'Nikon',
          model: 'Nikon Z9',
          serialNumber: 'NK2345678',
          firmwareVersion: '4.00',
          batteryLevel: 90,
          isConnected: false
        });
      }

      const camera = await nikonSDK.connectToCamera(0);
      
      expect(camera).to.be.an('object');
      expect(camera.isConnected).to.be.true;
      expect(camera.brand).to.equal('Nikon');
      expect(nikonSDK.connectedCamera).to.equal(camera);
    });

    it('should handle invalid camera index', async () => {
      try {
        await nikonSDK.connectToCamera(999);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Invalid camera index');
      }
    });

    it('should emit cameraConnected event', (done) => {
      nikonSDK.on('cameraConnected', (camera) => {
        expect(camera).to.be.an('object');
        expect(camera.isConnected).to.be.true;
        expect(camera.brand).to.equal('Nikon');
        done();
      });
      
      // Simulate a Nikon camera for testing
      nikonSDK.cameraList.push({
        index: 0,
        brand: 'Nikon',
        model: 'Nikon Z9',
        serialNumber: 'NK2345678',
        firmwareVersion: '4.00',
        batteryLevel: 90,
        isConnected: false
      });
      
      nikonSDK.connectToCamera(0);
    });
  });

  describe('Nikon-Specific Features', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
      nikonSDK.connectedCamera = {
        index: 0,
        brand: 'Nikon',
        model: 'Nikon Z9',
        isConnected: true
      };
    });

    it('should get Nikon camera settings', async () => {
      const settings = await nikonSDK.getCameraSettings();
      
      expect(settings).to.be.an('object');
      expect(settings).to.have.property('iso');
      expect(settings).to.have.property('aperture');
      expect(settings).to.have.property('shutter_speed');
      expect(settings).to.have.property('white_balance');
    });

    it('should set Nikon camera property', async () => {
      const result = await nikonSDK.setCameraProperty('ISO', 800);
      expect(result).to.be.true;
    });

    it('should handle Nikon-specific property names', async () => {
      // Test Nikon-specific properties
      const isoResult = await nikonSDK.setCameraProperty('ISO', 1600);
      expect(isoResult).to.be.true;
    });

    it('should emit nikonEvent for Nikon-specific events', (done) => {
      nikonSDK.on('nikonEvent', (data) => {
        expect(data).to.have.property('event');
        expect(data).to.have.property('param');
        done();
      });
      
      nikonSDK.handleNikonEvent('kNkMAIDEvent_CapabilityChanged', 'test_param');
    });
  });

  describe('Nikon Live View', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
      nikonSDK.connectedCamera = {
        index: 0,
        brand: 'Nikon',
        model: 'Nikon Z9',
        isConnected: true
      };
    });

    it('should start Nikon live view', async () => {
      const result = await nikonSDK.startLiveView();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('success', true);
      expect(result).to.have.property('streamUrl');
      expect(result.resolution).to.equal('1920x1280'); // Nikon-specific resolution
      expect(nikonSDK.liveViewSession).to.not.be.null;
    });

    it('should stop Nikon live view', async () => {
      await nikonSDK.startLiveView();
      await nikonSDK.stopLiveView();
      
      expect(nikonSDK.liveViewSession).to.be.null;
    });

    it('should emit liveViewStarted event', (done) => {
      nikonSDK.on('liveViewStarted', () => {
        done();
      });
      
      nikonSDK.startLiveView();
    });
  });

  describe('Nikon Image Capture', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
      nikonSDK.connectedCamera = {
        index: 0,
        brand: 'Nikon',
        model: 'Nikon Z9',
        isConnected: true
      };
    });

    it('should capture image with Nikon camera', async () => {
      const result = await nikonSDK.captureImage();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('id');
      expect(result).to.have.property('filename');
      expect(result.filename).to.include('DSC_'); // Nikon naming convention
      expect(result.filename).to.include('.NEF'); // Nikon RAW format
      expect(result).to.have.property('timestamp');
      expect(result).to.have.property('settings');
      expect(result.metadata.format).to.equal('NEF (RAW)');
    });

    it('should capture with Nikon custom settings', async () => {
      const customSettings = {
        iso: 1600,
        aperture: 'f/2.8'
      };
      
      const result = await nikonSDK.captureImage(customSettings);
      expect(result).to.be.an('object');
      expect(result.metadata.dimensions).to.equal('8256x5504'); // Nikon Z9 resolution
    });

    it('should emit imageCaptured event', (done) => {
      nikonSDK.on('imageCaptured', (imageInfo) => {
        expect(imageInfo).to.have.property('filename');
        expect(imageInfo.filename).to.include('.NEF');
        done();
      });
      
      nikonSDK.captureImage();
    });
  });

  describe('Nikon Error Handling', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
    });

    it('should handle Nikon-specific errors', async () => {
      const originalSimulateSDKCall = nikonSDK.simulateSDKCall;
      nikonSDK.simulateSDKCall = sinon.stub().rejects({ 
        code: 'kNkMAIDResult_DeviceBusy' 
      });
      
      try {
        nikonSDK.cameraList.push({ index: 0, model: 'Test Nikon Camera' });
        await nikonSDK.connectToCamera(0);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Device');
      }
      
      nikonSDK.simulateSDKCall = originalSimulateSDKCall;
    });

    it('should provide Nikon-specific error messages', () => {
      const errorMessage = nikonSDK.getNikonErrorMessage('kNkMAIDResult_BatteryLow');
      expect(errorMessage).to.include('battery');
      expect(errorMessage).to.include('low');
    });

    it('should emit cameraError event with Nikon context', (done) => {
      nikonSDK.on('cameraError', (errorInfo) => {
        expect(errorInfo).to.have.property('code');
        expect(errorInfo).to.have.property('message');
        expect(errorInfo.message).to.include('Nikon');
        done();
      });
      
      nikonSDK.handleConnectionError({ code: 'kNkMAIDResult_HardwareError' });
    });
  });

  describe('Nikon Reconnection Logic', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
      nikonSDK.connectedCamera = {
        index: 0,
        brand: 'Nikon',
        model: 'Nikon Z9',
        isConnected: true
      };
    });

    it('should attempt Nikon camera reconnection on connection loss', (done) => {
      nikonSDK.on('connectionLost', () => {
        done();
      });
      
      nikonSDK.handleConnectionLoss();
    });

    it('should limit Nikon reconnection attempts', async () => {
      nikonSDK.maxReconnectAttempts = 2;
      nikonSDK.simulateSDKCall = sinon.stub().rejects(new Error('Nikon connection failed'));
      
      try {
        await nikonSDK.reconnectCamera();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Maximum');
        expect(error.message).to.include('Nikon');
      }
    });
  });

  describe('Nikon Progress Events', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
    });

    it('should handle Nikon progress events', (done) => {
      nikonSDK.on('progressEvent', (data) => {
        expect(data).to.have.property('command');
        expect(data).to.have.property('progress');
        done();
      });
      
      nikonSDK.handleProgressEvent('kNkMAIDCommand_Capture', 50, 'test_data');
    });

    it('should handle battery warning events', (done) => {
      nikonSDK.on('batteryWarning', (data) => {
        expect(data).to.have.property('level', 'low');
        done();
      });
      
      nikonSDK.handleNikonEvent('kNkMAIDEvent_WarnLowBattery', null);
    });
  });

  describe('Nikon Cleanup', () => {
    it('should terminate Nikon SDK cleanly', async () => {
      await nikonSDK.initialize();
      await nikonSDK.terminate();
      // Should not throw any errors
    });

    it('should cleanup Nikon connection on disconnect', async () => {
      await nikonSDK.initialize();
      nikonSDK.connectedCamera = { 
        index: 0, 
        brand: 'Nikon', 
        model: 'Nikon Z9', 
        isConnected: true 
      };
      nikonSDK.connectionWatchdog = setInterval(() => {}, 1000);
      
      await nikonSDK.disconnectCamera();
      
      expect(nikonSDK.connectedCamera).to.be.null;
      expect(nikonSDK.connectionWatchdog).to.be.null;
    });
  });

  describe('Nikon SDK Simulation', () => {
    beforeEach(async () => {
      await nikonSDK.initialize();
    });

    it('should simulate Nikon SDK calls correctly', async () => {
      const result = await nikonSDK.simulateSDKCall('NkMAID_Initialize');
      expect(result).to.equal(nikonSDK.NIKON_ERRORS.kNkMAIDResult_NoError);
    });

    it('should return Nikon-specific simulated values', async () => {
      const batteryLevel = await nikonSDK.simulateSDKCall('NkMAID_GetCapInfo', 'kNkMAIDCapability_BatteryPack');
      expect(batteryLevel).to.equal(90); // Nikon default battery level
    });

    it('should simulate Nikon camera info', async () => {
      const cameraInfo = await nikonSDK.simulateSDKCall('NkMAID_GetDeviceInfo', 0);
      expect(cameraInfo.model).to.equal('Nikon Z9');
      expect(cameraInfo.serialNumber).to.include('NK');
      expect(cameraInfo.firmwareVersion).to.equal('4.00');
    });
  });
});