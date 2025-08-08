const SonySDKService = require('../src/services/sony_sdk_service');
const { expect } = require('chai');
const sinon = require('sinon');

describe('Sony SDK Service', () => {
  let sonySDK;
  let clock;

  beforeEach(() => {
    sonySDK = new SonySDKService();
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
    if (sonySDK) {
      sonySDK.removeAllListeners();
    }
  });

  describe('Initialization', () => {
    it('should initialize successfully', async () => {
      const result = await sonySDK.initialize();
      expect(result).to.be.true;
      expect(sonySDK.isInitialized).to.be.true;
    });

    it('should handle initialization failure', async () => {
      sonySDK.isInitialized = false;
      sonySDK.loadNativeModule = () => { throw new Error('Sony SDK not found'); };
      
      try {
        await sonySDK.initialize();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Sony SDK not properly loaded');
      }
    });

    it('should load native module successfully', () => {
      expect(sonySDK.isInitialized).to.be.true;
    });

    it('should handle native module load failure gracefully', () => {
      const newSonySDK = new SonySDKService();
      newSonySDK.loadNativeModule = () => { 
        throw new Error('Native module not found'); 
      };
      expect(newSonySDK.isInitialized).to.be.false;
    });
  });

  describe('Camera Discovery', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
    });

    it('should discover connected Sony cameras', async () => {
      const cameras = await sonySDK.discoverCameras();
      
      expect(cameras).to.be.an('array');
      expect(cameras).to.have.length.at.least(0);
      
      if (cameras.length > 0) {
        expect(cameras[0]).to.have.property('brand', 'Sony');
        expect(cameras[0]).to.have.property('model');
        expect(cameras[0]).to.have.property('serialNumber');
        expect(cameras[0]).to.have.property('firmwareVersion');
        expect(cameras[0]).to.have.property('batteryLevel');
        expect(cameras[0]).to.have.property('connectionType');
        expect(cameras[0]).to.have.property('capabilities');
        expect(cameras[0].capabilities).to.have.property('liveView', true);
        expect(cameras[0].capabilities).to.have.property('wirelessTransfer', true);
      }
    });

    it('should emit camerasDiscovered event', (done) => {
      sonySDK.on('camerasDiscovered', (cameras) => {
        expect(cameras).to.be.an('array');
        done();
      });
      
      sonySDK.discoverCameras();
    });

    it('should handle discovery errors gracefully', async () => {
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Network error'));
      
      try {
        await sonySDK.discoverCameras();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Sony camera discovery failed');
      }
    });
  });

  describe('Camera Connection', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
      await sonySDK.discoverCameras();
    });

    it('should connect to first available Sony camera', async () => {
      if (sonySDK.cameraList.length === 0) {
        // Simulate a Sony camera for testing
        sonySDK.cameraList.push({
          index: 0,
          brand: 'Sony',
          model: 'Sony α7R V',
          serialNumber: 'SN3234567',
          firmwareVersion: '2.00',
          batteryLevel: 95,
          isConnected: false,
          connectionType: 'WiFi'
        });
      }

      const camera = await sonySDK.connectToCamera(0);
      
      expect(camera).to.be.an('object');
      expect(camera.brand).to.equal('Sony');
      expect(camera.isConnected).to.be.true;
      expect(sonySDK.connectedCamera).to.equal(camera);
    });

    it('should handle invalid camera index', async () => {
      try {
        await sonySDK.connectToCamera(999);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Invalid camera index');
      }
    });

    it('should emit cameraConnected event', (done) => {
      sonySDK.on('cameraConnected', (camera) => {
        expect(camera).to.be.an('object');
        expect(camera.brand).to.equal('Sony');
        expect(camera.isConnected).to.be.true;
        done();
      });
      
      // Simulate a Sony camera for testing
      sonySDK.cameraList.push({
        index: 0,
        brand: 'Sony',
        model: 'Sony α7R V',
        serialNumber: 'SN3234567',
        firmwareVersion: '2.00',
        batteryLevel: 95,
        isConnected: false,
        connectionType: 'WiFi'
      });
      
      sonySDK.connectToCamera(0);
    });

    it('should handle connection retry logic', async () => {
      sonySDK.cameraList.push({
        index: 0,
        model: 'Sony α7R V',
        isConnected: false
      });

      const originalConnect = sonySDK.connectWithRetry;
      let attemptCount = 0;
      sonySDK.connectWithRetry = async (index, attempt = 1) => {
        attemptCount = attempt;
        if (attempt < 2) {
          throw new Error('Connection failed');
        }
        return true;
      };

      await sonySDK.connectToCamera(0);
      expect(attemptCount).to.be.at.least(1);
      
      sonySDK.connectWithRetry = originalConnect;
    });
  });

  describe('Camera Settings', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
      await sonySDK.discoverCameras();
      
      // Mock a connected Sony camera
      sonySDK.connectedCamera = {
        index: 0,
        brand: 'Sony',
        model: 'Sony α7R V',
        isConnected: true
      };
    });

    it('should get Sony camera settings', async () => {
      const settings = await sonySDK.getCameraSettings();
      
      expect(settings).to.be.an('object');
      expect(settings).to.have.property('iso');
      expect(settings).to.have.property('aperture');
      expect(settings).to.have.property('shutter_speed');
      expect(settings).to.have.property('white_balance');
      expect(settings).to.have.property('focus_mode');
      expect(settings).to.have.property('exposure_mode');
    });

    it('should set Sony camera property', async () => {
      const result = await sonySDK.setCameraProperty('ISO', '800');
      expect(result).to.be.true;
    });

    it('should handle Sony-specific property values', async () => {
      await sonySDK.setCameraProperty('WHITE_BALANCE', 'Daylight');
      await sonySDK.setCameraProperty('FOCUS_MODE', 'AF-C');
      await sonySDK.setCameraProperty('EXPOSURE_MODE', 'Aperture Priority');
    });

    it('should handle invalid Sony property', async () => {
      try {
        await sonySDK.setCameraProperty('INVALID_SONY_PROPERTY', 'value');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Unknown Sony property');
      }
    });

    it('should emit propertyChanged event', (done) => {
      sonySDK.on('propertyChanged', (data) => {
        expect(data).to.have.property('property');
        expect(data).to.have.property('value');
        done();
      });
      
      sonySDK.setCameraProperty('ISO', '800');
    });

    it('should validate Sony capability values', () => {
      expect(sonySDK.CAPABILITY_VALUES.ISO).to.include('800');
      expect(sonySDK.CAPABILITY_VALUES.WHITE_BALANCE).to.include('Daylight');
      expect(sonySDK.CAPABILITY_VALUES.FOCUS_MODE).to.include('AF-C');
    });
  });

  describe('Live View', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = {
        index: 0,
        brand: 'Sony',
        model: 'Sony α7R V',
        isConnected: true
      };
    });

    it('should start Sony live view', async () => {
      const result = await sonySDK.startLiveView();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('success', true);
      expect(result).to.have.property('streamUrl');
      expect(result).to.have.property('resolution', '1920x1080');
      expect(result).to.have.property('fps', 30);
      expect(sonySDK.liveViewSession).to.not.be.null;
    });

    it('should stop Sony live view', async () => {
      await sonySDK.startLiveView();
      await sonySDK.stopLiveView();
      
      expect(sonySDK.liveViewSession).to.be.null;
    });

    it('should emit liveViewStarted event', (done) => {
      sonySDK.on('liveViewStarted', () => {
        done();
      });
      
      sonySDK.startLiveView();
    });

    it('should emit liveViewStopped event', (done) => {
      sonySDK.on('liveViewStopped', () => {
        done();
      });
      
      sonySDK.startLiveView().then(() => {
        sonySDK.stopLiveView();
      });
    });

    it('should handle native live view events', () => {
      const mockImageData = Buffer.alloc(1024);
      sonySDK.liveViewSession = { active: true };
      
      sonySDK.on('liveViewFrame', (frameData) => {
        expect(frameData).to.have.property('data');
        expect(frameData).to.have.property('width');
        expect(frameData).to.have.property('height');
        expect(frameData).to.have.property('frameNumber');
        expect(frameData).to.have.property('timestamp');
      });
      
      sonySDK.handleNativeLiveView(mockImageData, 1920, 1080, 1);
    });
  });

  describe('Image Capture', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = {
        index: 0,
        brand: 'Sony',
        model: 'Sony α7R V',
        isConnected: true
      };
    });

    it('should capture image with Sony camera', async () => {
      const result = await sonySDK.captureImage();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('id');
      expect(result).to.have.property('filename');
      expect(result).to.have.property('timestamp');
      expect(result).to.have.property('settings');
      expect(result).to.have.property('metadata');
      expect(result.filename).to.match(/^DSC\d+\.ARW$/);
      expect(result.metadata.format).to.equal('ARW (RAW)');
    });

    it('should capture with custom Sony settings', async () => {
      const customSettings = {
        iso: '1600',
        aperture: 'F2.8',
        white_balance: 'Daylight'
      };
      
      const result = await sonySDK.captureImage(customSettings);
      expect(result).to.be.an('object');
      expect(result).to.have.property('settings');
    });

    it('should emit imageCaptured event', (done) => {
      sonySDK.on('imageCaptured', (imageInfo) => {
        expect(imageInfo).to.have.property('filename');
        expect(imageInfo.filename).to.match(/^DSC\d+\.ARW$/);
        expect(imageInfo).to.have.property('metadata');
        done();
      });
      
      sonySDK.captureImage();
    });

    it('should handle capture errors', async () => {
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Capture failed'));
      
      try {
        await sonySDK.captureImage();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Sony image capture failed');
      }
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
    });

    it('should handle Sony connection errors', async () => {
      const originalSimulateSDKCall = sonySDK.simulateSDKCall;
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Network timeout'));
      
      try {
        sonySDK.cameraList.push({ index: 0, model: 'Sony α7R V' });
        await sonySDK.connectToCamera(0);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Network timeout');
      }
      
      sonySDK.simulateSDKCall = originalSimulateSDKCall;
    });

    it('should emit cameraError event', (done) => {
      sonySDK.on('cameraError', (errorInfo) => {
        expect(errorInfo).to.have.property('code');
        expect(errorInfo).to.have.property('message');
        done();
      });
      
      sonySDK.handleConnectionError({ code: 'NETWORK_ERROR' });
    });

    it('should handle Sony-specific error codes', () => {
      const networkError = sonySDK.getSonyErrorMessage('NETWORK_ERROR');
      const timeoutError = sonySDK.getSonyErrorMessage('TIMEOUT');
      const authError = sonySDK.getSonyErrorMessage('UNAUTHORIZED');
      
      expect(networkError).to.include('Network error');
      expect(timeoutError).to.include('timeout');
      expect(authError).to.include('Unauthorized');
    });

    it('should handle unknown Sony errors', () => {
      const unknownError = sonySDK.getSonyErrorMessage('UNKNOWN_CODE');
      expect(unknownError).to.include('unknown');
    });
  });

  describe('Connection Monitoring', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = {
        index: 0,
        brand: 'Sony',
        model: 'Sony α7R V',
        isConnected: true
      };
    });

    it('should start connection watchdog', () => {
      sonySDK.startConnectionWatchdog();
      expect(sonySDK.connectionWatchdog).to.not.be.null;
      expect(sonySDK.lastHeartbeat).to.not.be.null;
    });

    it('should attempt reconnection on connection loss', (done) => {
      sonySDK.on('connectionLost', () => {
        done();
      });
      
      sonySDK.handleConnectionLoss();
    });

    it('should limit Sony reconnection attempts', async () => {
      sonySDK.maxReconnectAttempts = 2;
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Network unavailable'));
      
      try {
        await sonySDK.reconnectCamera();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Maximum Sony reconnection attempts exceeded');
      }
    });

    it('should handle successful reconnection', async () => {
      sonySDK.reconnectAttempts = 1;
      const result = await sonySDK.reconnectCamera();
      expect(result).to.be.true;
      expect(sonySDK.reconnectAttempts).to.equal(0);
    });

    it('should emit reconnectionFailed event', (done) => {
      sonySDK.maxReconnectAttempts = 1;
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Connection failed'));
      
      sonySDK.on('reconnectionFailed', (error) => {
        expect(error).to.be.an('error');
        done();
      });
      
      sonySDK.handleConnectionLoss();
    });
  });

  describe('Native Event Handling', () => {
    beforeEach(async () => {
      await sonySDK.initialize();
    });

    it('should handle native Sony events', () => {
      sonySDK.on('cameraConnected', () => {
        // Event should be emitted
      });
      
      sonySDK.on('propertyEvent', (data) => {
        expect(data).to.have.property('api');
        expect(data).to.have.property('command');
        expect(data).to.have.property('param');
      });
      
      // Simulate native events
      sonySDK.handleNativeEvent(1, 1, 0); // Camera connected
      sonySDK.handleNativeEvent(1, 3, 'ISO'); // Property changed
    });

    it('should map native events correctly', () => {
      let eventFired = false;
      
      sonySDK.on('cameraDisconnected', () => {
        eventFired = true;
      });
      
      sonySDK.handleNativeEvent(1, 2, 0); // Camera disconnected
      expect(eventFired).to.be.true;
    });
  });

  describe('Property Value Formatting', () => {
    it('should format Sony property values correctly', () => {
      expect(sonySDK.formatPropertyValue('ISO', 800)).to.equal(800);
      expect(sonySDK.formatPropertyValue('APERTURE', 'F4.0')).to.equal('F4.0');
      expect(sonySDK.formatPropertyValue('WHITE_BALANCE', 'Daylight')).to.equal('Daylight');
      expect(sonySDK.formatPropertyValue('FOCUS_MODE', 'AF-S')).to.equal('AF-S');
    });

    it('should parse Sony property values correctly', () => {
      expect(sonySDK.parsePropertyValue('ISO', 800)).to.equal('800');
      expect(sonySDK.parsePropertyValue('APERTURE', '4.0')).to.equal('F4.0');
      expect(sonySDK.parsePropertyValue('APERTURE', 'F2.8')).to.equal('F2.8');
    });

    it('should get Sony property IDs', () => {
      expect(sonySDK.getSonyPropertyId('ISO')).to.equal(0x80000001);
      expect(sonySDK.getSonyPropertyId('APERTURE')).to.equal(0x80000002);
      expect(sonySDK.getSonyPropertyId('INVALID')).to.equal(0);
    });
  });

  describe('Cleanup', () => {
    it('should terminate Sony SDK cleanly', async () => {
      await sonySDK.initialize();
      await sonySDK.terminate();
      // Should not throw any errors
    });

    it('should cleanup Sony connection on disconnect', async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = { 
        index: 0, 
        brand: 'Sony',
        model: 'Sony α7R V', 
        isConnected: true 
      };
      sonySDK.connectionWatchdog = setInterval(() => {}, 10000);
      
      await sonySDK.disconnectCamera();
      
      expect(sonySDK.connectedCamera).to.be.null;
      expect(sonySDK.connectionWatchdog).to.be.null;
    });

    it('should force disconnect on cleanup failure', async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = { 
        index: 0, 
        brand: 'Sony',
        model: 'Sony α7R V', 
        isConnected: true 
      };
      
      // Mock cleanup failure
      sonySDK.simulateSDKCall = sinon.stub().rejects(new Error('Cleanup failed'));
      
      await sonySDK.forceDisconnect();
      expect(sonySDK.connectedCamera).to.be.null;
    });

    it('should handle live view cleanup', async () => {
      await sonySDK.initialize();
      sonySDK.connectedCamera = { index: 0, model: 'Sony α7R V', isConnected: true };
      
      await sonySDK.startLiveView();
      await sonySDK.cleanupConnection();
      
      expect(sonySDK.liveViewSession).to.be.null;
    });
  });

  describe('Simulation Mode', () => {
    it('should simulate Sony SDK calls correctly', async () => {
      const initResult = await sonySDK.simulateSDKCall('initialize');
      expect(initResult).to.be.true;
      
      const cameraCount = await sonySDK.simulateSDKCall('discoverCameras');
      expect(cameraCount).to.equal(1);
      
      const cameraInfo = await sonySDK.simulateSDKCall('getCameraInfo', 0);
      expect(cameraInfo).to.have.property('model', 'Sony α7R V');
      expect(cameraInfo).to.have.property('serialNumber', 'SN3234567');
    });

    it('should provide simulated Sony property values', () => {
      const isoValue = sonySDK.getSimulatedSonyPropertyValue('setIsoSpeedRate');
      const apertureValue = sonySDK.getSimulatedSonyPropertyValue('setFNumber');
      
      expect(isoValue).to.equal('400');
      expect(apertureValue).to.equal('F4.0');
    });

    it('should handle unknown simulated calls', async () => {
      const result = await sonySDK.simulateSDKCall('unknownFunction');
      expect(result).to.be.true;
    });
  });
});