const CameraManager = require('../src/services/camera_manager');
const { expect } = require('chai');
const sinon = require('sinon');

describe('Camera Manager', () => {
  let cameraManager;
  let clock;

  beforeEach(() => {
    cameraManager = new CameraManager();
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
    if (cameraManager) {
      cameraManager.removeAllListeners();
    }
  });

  describe('Initialization', () => {
    it('should initialize both Canon and Nikon SDKs', async () => {
      const result = await cameraManager.initialize();
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('success', true);
      expect(result).to.have.property('canonSupported');
      expect(result).to.have.property('nikonSupported');
      expect(cameraManager.isInitialized).to.be.true;
    });

    it('should handle partial SDK initialization failure', async () => {
      // Mock one SDK to fail
      sinon.stub(cameraManager.canonSDK, 'initialize').rejects(new Error('Canon SDK failed'));
      
      const result = await cameraManager.initialize();
      expect(result.success).to.be.true;
      expect(result.canonSupported).to.be.false;
      expect(result.nikonSupported).to.be.true;
    });
  });

  describe('Multi-Brand Camera Discovery', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
    });

    it('should discover cameras from all brands', async () => {
      const cameras = await cameraManager.discoverAllCameras();
      
      expect(cameras).to.be.an('array');
      expect(cameraManager.availableCameras).to.have.length.at.least(0);
      
      // Check that cameras have brand and unified ID
      cameras.forEach(camera => {
        expect(camera).to.have.property('brand');
        expect(camera).to.have.property('id');
        expect(camera.id).to.include(camera.brand);
      });
    });

    it('should emit allCamerasDiscovered event', (done) => {
      cameraManager.on('allCamerasDiscovered', (cameras) => {
        expect(cameras).to.be.an('array');
        done();
      });
      
      cameraManager.discoverAllCameras();
    });

    it('should update camera list when individual SDKs discover cameras', () => {
      const canonCameras = [
        { index: 0, model: 'Canon EOS R5', brand: 'canon' }
      ];
      const nikonCameras = [
        { index: 0, model: 'Nikon Z9', brand: 'nikon' }
      ];
      
      cameraManager.updateCameraList('canon', canonCameras);
      cameraManager.updateCameraList('nikon', nikonCameras);
      
      expect(cameraManager.availableCameras).to.have.length(2);
      expect(cameraManager.availableCameras[0].id).to.equal('canon_0');
      expect(cameraManager.availableCameras[1].id).to.equal('nikon_0');
    });
  });

  describe('Multi-Brand Camera Connection', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
      
      // Mock available cameras
      cameraManager.availableCameras = [
        { id: 'canon_0', brand: 'canon', index: 0, model: 'Canon EOS R5' },
        { id: 'nikon_0', brand: 'nikon', index: 0, model: 'Nikon Z9' }
      ];
    });

    it('should connect to Canon camera', async () => {
      sinon.stub(cameraManager.canonSDK, 'connectToCamera').resolves({
        model: 'Canon EOS R5',
        isConnected: true
      });
      
      const result = await cameraManager.connectToCamera('canon_0');
      
      expect(result.success).to.be.true;
      expect(result.cameraId).to.equal('canon_0');
      expect(cameraManager.connectedCameras.has('canon_0')).to.be.true;
      expect(cameraManager.activeCameraId).to.equal('canon_0');
    });

    it('should connect to Nikon camera', async () => {
      sinon.stub(cameraManager.nikonSDK, 'connectToCamera').resolves({
        model: 'Nikon Z9',
        isConnected: true
      });
      
      const result = await cameraManager.connectToCamera('nikon_0');
      
      expect(result.success).to.be.true;
      expect(result.cameraId).to.equal('nikon_0');
      expect(cameraManager.connectedCameras.has('nikon_0')).to.be.true;
      expect(cameraManager.activeCameraId).to.equal('nikon_0');
    });

    it('should handle unsupported camera brand', async () => {
      cameraManager.availableCameras.push({
        id: 'sony_0', 
        brand: 'sony', 
        index: 0, 
        model: 'Sony A7R V'
      });
      
      try {
        await cameraManager.connectToCamera('sony_0');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Unsupported camera brand');
      }
    });

    it('should disconnect specific camera', async () => {
      // First connect
      sinon.stub(cameraManager.canonSDK, 'connectToCamera').resolves({
        model: 'Canon EOS R5',
        isConnected: true
      });
      sinon.stub(cameraManager.canonSDK, 'disconnectCamera').resolves();
      
      await cameraManager.connectToCamera('canon_0');
      await cameraManager.disconnectCamera('canon_0');
      
      expect(cameraManager.connectedCameras.has('canon_0')).to.be.false;
      expect(cameraManager.activeCameraId).to.be.null;
    });
  });

  describe('Active Camera Management', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
      
      // Mock connected cameras
      cameraManager.connectedCameras.set('canon_0', {
        sdk: cameraManager.canonSDK,
        camera: { model: 'Canon EOS R5' },
        brand: 'canon'
      });
      cameraManager.connectedCameras.set('nikon_0', {
        sdk: cameraManager.nikonSDK,
        camera: { model: 'Nikon Z9' },
        brand: 'nikon'
      });
    });

    it('should set active camera', async () => {
      const result = await cameraManager.setActiveCamera('canon_0');
      
      expect(result.success).to.be.true;
      expect(cameraManager.activeCameraId).to.equal('canon_0');
    });

    it('should get active camera info', () => {
      cameraManager.activeCameraId = 'canon_0';
      
      const activeCamera = cameraManager.getActiveCamera();
      
      expect(activeCamera).to.not.be.null;
      expect(activeCamera.id).to.equal('canon_0');
      expect(activeCamera.brand).to.equal('canon');
    });

    it('should return null when no active camera', () => {
      const activeCamera = cameraManager.getActiveCamera();
      expect(activeCamera).to.be.null;
    });

    it('should emit activeCameraChanged event', (done) => {
      cameraManager.on('activeCameraChanged', (data) => {
        expect(data.cameraId).to.equal('nikon_0');
        expect(data.brand).to.equal('nikon');
        done();
      });
      
      cameraManager.setActiveCamera('nikon_0');
    });
  });

  describe('Camera Operations', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
      
      // Mock connected camera
      cameraManager.connectedCameras.set('canon_0', {
        sdk: cameraManager.canonSDK,
        camera: { model: 'Canon EOS R5' },
        brand: 'canon'
      });
      cameraManager.activeCameraId = 'canon_0';
    });

    it('should get camera settings', async () => {
      sinon.stub(cameraManager.canonSDK, 'getCameraSettings').resolves({
        iso: 400,
        aperture: 'f/4.0'
      });
      
      const result = await cameraManager.getCameraSettings();
      
      expect(result.success).to.be.true;
      expect(result.cameraId).to.equal('canon_0');
      expect(result.brand).to.equal('canon');
      expect(result.settings).to.have.property('iso', 400);
    });

    it('should set camera property', async () => {
      sinon.stub(cameraManager.canonSDK, 'setCameraProperty').resolves();
      
      const result = await cameraManager.setCameraProperty('ISO', 800);
      
      expect(result.success).to.be.true;
      expect(result.cameraId).to.equal('canon_0');
      expect(result.property).to.equal('ISO');
      expect(result.value).to.equal(800);
    });

    it('should start live view', async () => {
      sinon.stub(cameraManager.canonSDK, 'startLiveView').resolves({
        success: true,
        streamUrl: 'ws://localhost:3000/liveview'
      });
      
      const result = await cameraManager.startLiveView();
      
      expect(result.success).to.be.true;
      expect(result.cameraId).to.equal('canon_0');
      expect(result.brand).to.equal('canon');
    });

    it('should capture image', async () => {
      sinon.stub(cameraManager.canonSDK, 'captureImage').resolves({
        id: 'img_123',
        filename: 'IMG_123.CR3'
      });
      
      const result = await cameraManager.captureImage({ iso: 800 });
      
      expect(result.id).to.equal('img_123');
      expect(result.cameraId).to.equal('canon_0');
      expect(result.brand).to.equal('canon');
    });
  });

  describe('Event Forwarding', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
    });

    it('should forward Canon SDK events', (done) => {
      cameraManager.on('imageCaptured', (data) => {
        expect(data.brand).to.equal('canon');
        done();
      });
      
      cameraManager.canonSDK.emit('imageCaptured', { filename: 'test.cr3' });
    });

    it('should forward Nikon SDK events', (done) => {
      cameraManager.on('imageCaptured', (data) => {
        expect(data.brand).to.equal('nikon');
        done();
      });
      
      cameraManager.nikonSDK.emit('imageCaptured', { filename: 'test.nef' });
    });

    it('should handle camera connection events', (done) => {
      cameraManager.on('cameraConnected', (data) => {
        expect(data.brand).to.equal('canon');
        expect(data.camera.model).to.equal('Canon EOS R5');
        done();
      });
      
      cameraManager.canonSDK.emit('cameraConnected', { model: 'Canon EOS R5' });
    });
  });

  describe('Status and Information', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
    });

    it('should get manager status', () => {
      const status = cameraManager.getStatus();
      
      expect(status).to.have.property('isInitialized', true);
      expect(status).to.have.property('availableCameras');
      expect(status).to.have.property('connectedCameras');
      expect(status).to.have.property('supportedBrands');
      expect(status.supportedBrands).to.include('canon');
      expect(status.supportedBrands).to.include('nikon');
    });

    it('should get connected cameras list', () => {
      cameraManager.connectedCameras.set('canon_0', {
        camera: { model: 'Canon EOS R5' },
        brand: 'canon'
      });
      cameraManager.activeCameraId = 'canon_0';
      
      const connected = cameraManager.getConnectedCameras();
      
      expect(connected).to.have.length(1);
      expect(connected[0].id).to.equal('canon_0');
      expect(connected[0].isActive).to.be.true;
    });

    it('should get supported brands', () => {
      const brands = cameraManager.getSupportedBrands();
      expect(brands).to.include('canon');
      expect(brands).to.include('nikon');
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await cameraManager.initialize();
    });

    it('should handle camera not found error', async () => {
      try {
        await cameraManager.connectToCamera('nonexistent_camera');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('Camera not found');
      }
    });

    it('should handle operations without active camera', async () => {
      try {
        await cameraManager.getCameraSettings();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.include('No camera specified and no active camera');
      }
    });

    it('should forward camera errors with brand information', (done) => {
      cameraManager.on('cameraError', (errorInfo) => {
        expect(errorInfo.brand).to.equal('nikon');
        done();
      });
      
      cameraManager.nikonSDK.emit('cameraError', { message: 'Test error' });
    });
  });

  describe('Cleanup', () => {
    it('should terminate all SDKs', async () => {
      await cameraManager.initialize();
      
      sinon.stub(cameraManager.canonSDK, 'terminate').resolves();
      sinon.stub(cameraManager.nikonSDK, 'terminate').resolves();
      
      await cameraManager.terminate();
      
      expect(cameraManager.isInitialized).to.be.false;
      expect(cameraManager.availableCameras).to.have.length(0);
    });

    it('should disconnect all cameras on termination', async () => {
      await cameraManager.initialize();
      
      // Mock connected cameras
      cameraManager.connectedCameras.set('canon_0', {
        sdk: { disconnectCamera: sinon.stub().resolves() },
        camera: { model: 'Canon EOS R5' },
        brand: 'canon'
      });
      
      await cameraManager.terminate();
      
      expect(cameraManager.connectedCameras.size).to.equal(0);
    });
  });
});