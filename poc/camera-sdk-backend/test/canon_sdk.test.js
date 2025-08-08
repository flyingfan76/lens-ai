const CanonSDKService = require('../src/services/canon_sdk_service');
const { expect } = require('chai');
const sinon = require('sinon');

describe('Canon SDK Service', () => {
  let canonSDK;
  let clock;

  beforeEach(() => {
    canonSDK = new CanonSDKService();
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
    if (canonSDK) {
      canonSDK.removeAllListeners();
    }
  });

  describe('Initialization', () => {
    it('should initialize successfully', async () => {
      const result = await canonSDK.initialize();
      expect(result).to.be.true;
      expect(canonSDK.isInitialized).to.be.true;
    });

    it('should handle initialization failure', async () => {
      canonSDK.isInitialized = false;
      canonSDK.loadNativeModule = () => { throw new Error('SDK not found'); };
      
      try {
        await canonSDK.initialize();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Canon SDK not properly loaded');
      }
    });
  });

  describe('Camera Discovery', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
    });

    it('should discover connected cameras', async () => {
      const cameras = await canonSDK.discoverCameras();
      
      expect(cameras).to.be.an('array');
      expect(cameras).to.have.length.at.least(0);
      
      if (cameras.length > 0) {
        expect(cameras[0]).to.have.property('model');
        expect(cameras[0]).to.have.property('serialNumber');
        expect(cameras[0]).to.have.property('firmwareVersion');
        expect(cameras[0]).to.have.property('batteryLevel');
      }
    });

    it('should emit camerasDiscovered event', (done) => {
      canonSDK.on('camerasDiscovered', (cameras) => {
        expect(cameras).to.be.an('array');
        done();
      });
      
      canonSDK.discoverCameras();
    });
  });

  describe('Camera Connection', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
      await canonSDK.discoverCameras();
    });

    it('should connect to first available camera', async () => {
      if (canonSDK.cameraList.length === 0) {
        // Simulate a camera for testing
        canonSDK.cameraList.push({
          index: 0,
          model: 'Canon EOS R5',
          serialNumber: 'CN1234567',
          firmwareVersion: '1.8.1',
          batteryLevel: 85,
          isConnected: false
        });
      }

      const camera = await canonSDK.connectToCamera(0);
      
      expect(camera).to.be.an('object');
      expect(camera.isConnected).to.be.true;
      expect(canonSDK.connectedCamera).to.equal(camera);
    });

    it('should handle invalid camera index', async () => {
      try {
        await canonSDK.connectToCamera(999);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Invalid camera index');
      }
    });

    it('should emit cameraConnected event', (done) => {
      canonSDK.on('cameraConnected', (camera) => {
        expect(camera).to.be.an('object');
        expect(camera.isConnected).to.be.true;
        done();
      });
      
      // Simulate a camera for testing
      canonSDK.cameraList.push({
        index: 0,
        model: 'Canon EOS R5',
        serialNumber: 'CN1234567',
        firmwareVersion: '1.8.1',
        batteryLevel: 85,
        isConnected: false
      });
      
      canonSDK.connectToCamera(0);
    });
  });

  describe('Camera Settings', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
      await canonSDK.discoverCameras();
      
      // Mock a connected camera
      canonSDK.connectedCamera = {
        index: 0,
        model: 'Canon EOS R5',
        isConnected: true
      };
    });

    it('should get camera settings', async () => {
      const settings = await canonSDK.getCameraSettings();
      
      expect(settings).to.be.an('object');
      expect(settings).to.have.property('iso');
      expect(settings).to.have.property('aperture');
      expect(settings).to.have.property('shutter_speed');
      expect(settings).to.have.property('white_balance');
    });

    it('should set camera property', async () => {
      const result = await canonSDK.setCameraProperty('ISO', 800);
      expect(result).to.be.true;
    });

    it('should handle invalid property', async () => {
      try {
        await canonSDK.setCameraProperty('INVALID_PROPERTY', 'value');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Unknown property');
      }
    });

    it('should emit propertyChanged event', (done) => {
      canonSDK.on('propertyChanged', (data) => {
        expect(data).to.have.property('property');
        expect(data).to.have.property('value');
        done();
      });
      
      canonSDK.setCameraProperty('ISO', 800);
    });
  });

  describe('Live View', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
      canonSDK.connectedCamera = {
        index: 0,
        model: 'Canon EOS R5',
        isConnected: true
      };
    });

    it('should start live view', async () => {
      const result = await canonSDK.startLiveView();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('success', true);
      expect(result).to.have.property('streamUrl');
      expect(canonSDK.liveViewSession).to.not.be.null;
    });

    it('should stop live view', async () => {
      await canonSDK.startLiveView();
      await canonSDK.stopLiveView();
      
      expect(canonSDK.liveViewSession).to.be.null;
    });

    it('should emit liveViewStarted event', (done) => {
      canonSDK.on('liveViewStarted', () => {
        done();
      });
      
      canonSDK.startLiveView();
    });
  });

  describe('Image Capture', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
      canonSDK.connectedCamera = {
        index: 0,
        model: 'Canon EOS R5',
        isConnected: true
      };
    });

    it('should capture image', async () => {
      const result = await canonSDK.captureImage();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('id');
      expect(result).to.have.property('filename');
      expect(result).to.have.property('timestamp');
      expect(result).to.have.property('settings');
    });

    it('should capture with custom settings', async () => {
      const customSettings = {
        iso: 800,
        aperture: 'f/2.8'
      };
      
      const result = await canonSDK.captureImage(customSettings);
      expect(result).to.be.an('object');
    });

    it('should emit imageCaptured event', (done) => {
      canonSDK.on('imageCaptured', (imageInfo) => {
        expect(imageInfo).to.have.property('filename');
        done();
      });
      
      canonSDK.captureImage();
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
    });

    it('should handle connection errors', async () => {
      // Mock SDK call to throw error
      const originalSimulateSDKCall = canonSDK.simulateSDKCall;
      canonSDK.simulateSDKCall = sinon.stub().rejects(new Error('Device not found'));
      
      try {
        canonSDK.cameraList.push({ index: 0, model: 'Test Camera' });
        await canonSDK.connectToCamera(0);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Device not found');
      }
      
      canonSDK.simulateSDKCall = originalSimulateSDKCall;
    });

    it('should emit cameraError event', (done) => {
      canonSDK.on('cameraError', (errorInfo) => {
        expect(errorInfo).to.have.property('code');
        expect(errorInfo).to.have.property('message');
        done();
      });
      
      canonSDK.handleConnectionError({ code: 'EDS_ERR_DEVICE_NOT_FOUND' });
    });
  });

  describe('Reconnection Logic', () => {
    beforeEach(async () => {
      await canonSDK.initialize();
      canonSDK.connectedCamera = {
        index: 0,
        model: 'Canon EOS R5',
        isConnected: true
      };
    });

    it('should attempt reconnection on connection loss', (done) => {
      canonSDK.on('connectionLost', () => {
        done();
      });
      
      canonSDK.handleConnectionLoss();
    });

    it('should limit reconnection attempts', async () => {
      canonSDK.maxReconnectAttempts = 2;
      canonSDK.simulateSDKCall = sinon.stub().rejects(new Error('Connection failed'));
      
      try {
        await canonSDK.reconnectCamera();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Maximum reconnection attempts exceeded');
      }
    });
  });

  describe('Cleanup', () => {
    it('should terminate cleanly', async () => {
      await canonSDK.initialize();
      await canonSDK.terminate();
      // Should not throw any errors
    });

    it('should cleanup connection on disconnect', async () => {
      await canonSDK.initialize();
      canonSDK.connectedCamera = { index: 0, model: 'Test', isConnected: true };
      canonSDK.connectionWatchdog = setInterval(() => {}, 1000);
      
      await canonSDK.disconnectCamera();
      
      expect(canonSDK.connectedCamera).to.be.null;
      expect(canonSDK.connectionWatchdog).to.be.null;
    });
  });
});