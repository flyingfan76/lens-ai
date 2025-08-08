const logger = require('../utils/logger');

class CameraSDKService {
  constructor() {
    this.connectedCamera = null;
    this.cameraCapabilities = null;
    this.sdkAdapters = {
      canon: new CanonSDKAdapter(),
      nikon: new NikonSDKAdapter(),
      sony: new SonySDKAdapter(),
      fujifilm: new FujifilmSDKAdapter()
    };
  }

  async detectConnectedCamera() {
    try {
      logger.info('Detecting connected cameras...');
      
      // Try each SDK to detect connected cameras
      for (const [brand, adapter] of Object.entries(this.sdkAdapters)) {
        const cameras = await adapter.detectCameras();
        if (cameras.length > 0) {
          this.connectedCamera = {
            brand: brand,
            model: cameras[0].model,
            serialNumber: cameras[0].serialNumber,
            adapter: adapter
          };
          
          this.cameraCapabilities = await adapter.getCapabilities();
          logger.info(`Connected to ${brand} ${cameras[0].model}`);
          return this.connectedCamera;
        }
      }
      
      logger.warn('No cameras detected');
      return null;
    } catch (error) {
      logger.error('Failed to detect camera:', error);
      throw error;
    }
  }

  async applyCameraSettings(settings) {
    try {
      if (!this.connectedCamera) {
        throw new Error('No camera connected');
      }

      logger.info('Applying camera settings:', settings);
      const adapter = this.connectedCamera.adapter;
      const results = {};

      // Apply ISO
      if (settings.iso) {
        results.iso = await adapter.setISO(settings.iso);
      }

      // Apply Aperture
      if (settings.aperture) {
        results.aperture = await adapter.setAperture(settings.aperture);
      }

      // Apply Shutter Speed
      if (settings.shutterSpeed) {
        results.shutterSpeed = await adapter.setShutterSpeed(settings.shutterSpeed);
      }

      // Apply White Balance
      if (settings.whiteBalance) {
        results.whiteBalance = await adapter.setWhiteBalance(settings.whiteBalance);
      }

      // Apply Exposure Compensation
      if (settings.exposureCompensation) {
        results.exposureCompensation = await adapter.setExposureCompensation(settings.exposureCompensation);
      }

      // Apply Focus Mode
      if (settings.focusMode) {
        results.focusMode = await adapter.setFocusMode(settings.focusMode);
      }

      // Apply Metering Mode
      if (settings.meteringMode) {
        results.meteringMode = await adapter.setMeteringMode(settings.meteringMode);
      }

      logger.info('Settings applied successfully:', results);
      return {
        success: true,
        appliedSettings: results,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Failed to apply camera settings:', error);
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async getCurrentSettings() {
    try {
      if (!this.connectedCamera) {
        throw new Error('No camera connected');
      }

      const adapter = this.connectedCamera.adapter;
      
      const settings = {
        iso: await adapter.getISO(),
        aperture: await adapter.getAperture(),
        shutterSpeed: await adapter.getShutterSpeed(),
        whiteBalance: await adapter.getWhiteBalance(),
        exposureCompensation: await adapter.getExposureCompensation(),
        focusMode: await adapter.getFocusMode(),
        meteringMode: await adapter.getMeteringMode()
      };

      return settings;
    } catch (error) {
      logger.error('Failed to get current settings:', error);
      throw error;
    }
  }

  async capturePhoto() {
    try {
      if (!this.connectedCamera) {
        throw new Error('No camera connected');
      }

      logger.info('Capturing photo...');
      const adapter = this.connectedCamera.adapter;
      const result = await adapter.capturePhoto();

      return {
        success: true,
        filename: result.filename,
        path: result.path,
        thumbnail: result.thumbnail,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Failed to capture photo:', error);
      throw error;
    }
  }

  getConnectedCameraInfo() {
    return this.connectedCamera;
  }

  getCameraCapabilities() {
    return this.cameraCapabilities;
  }
}

// Base SDK Adapter Class
class BaseSDKAdapter {
  async detectCameras() {
    throw new Error('detectCameras must be implemented by subclass');
  }

  async getCapabilities() {
    throw new Error('getCapabilities must be implemented by subclass');
  }

  async setISO(iso) {
    throw new Error('setISO must be implemented by subclass');
  }

  async setAperture(aperture) {
    throw new Error('setAperture must be implemented by subclass');
  }

  async setShutterSpeed(speed) {
    throw new Error('setShutterSpeed must be implemented by subclass');
  }

  async setWhiteBalance(wb) {
    throw new Error('setWhiteBalance must be implemented by subclass');
  }

  async setExposureCompensation(compensation) {
    throw new Error('setExposureCompensation must be implemented by subclass');
  }

  async setFocusMode(mode) {
    throw new Error('setFocusMode must be implemented by subclass');
  }

  async setMeteringMode(mode) {
    throw new Error('setMeteringMode must be implemented by subclass');
  }

  async capturePhoto() {
    throw new Error('capturePhoto must be implemented by subclass');
  }
}

// Canon SDK Adapter
class CanonSDKAdapter extends BaseSDKAdapter {
  async detectCameras() {
    // Simulate Canon SDK call
    // In production: const cameras = await CanonSDK.getCameraList();
    return [
      {
        model: 'EOS R5',
        serialNumber: 'ABC123456789'
      }
    ];
  }

  async getCapabilities() {
    return {
      iso: { min: 100, max: 51200, values: [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200] },
      aperture: { min: 1.2, max: 22, values: ['f/1.2', 'f/1.4', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16', 'f/22'] },
      shutterSpeed: { min: 30, max: 8000, values: ['30s', '15s', '8s', '4s', '2s', '1s', '1/2', '1/4', '1/8', '1/15', '1/30', '1/60', '1/125', '1/250', '1/500', '1/1000', '1/2000', '1/4000', '1/8000'] },
      whiteBalance: {
        modes: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade', 'custom'],
        kelvinRange: { min: 2500, max: 10000 },
        shiftRange: { magentaGreen: [-9, 9], blueAmber: [-9, 9] }
      }
    };
  }

  async setISO(iso) {
    logger.debug(`Canon SDK: Setting ISO to ${iso}`);
    // In production: await CanonSDK.setISO(iso);
    return { success: true, value: iso };
  }

  async setAperture(aperture) {
    logger.debug(`Canon SDK: Setting aperture to ${aperture}`);
    // In production: await CanonSDK.setAperture(aperture);
    return { success: true, value: aperture };
  }

  async setShutterSpeed(speed) {
    logger.debug(`Canon SDK: Setting shutter speed to ${speed}`);
    // In production: await CanonSDK.setShutterSpeed(speed);
    return { success: true, value: speed };
  }

  async setWhiteBalance(wb) {
    logger.debug(`Canon SDK: Setting white balance:`, wb);
    // In production: 
    // await CanonSDK.setWhiteBalanceMode(wb.mode);
    // if (wb.mode === 'custom') await CanonSDK.setColorTemperature(wb.kelvin);
    // if (wb.shift) await CanonSDK.setWBShift(wb.shift.magentaGreen, wb.shift.blueAmber);
    return { success: true, value: wb };
  }

  async setExposureCompensation(compensation) {
    logger.debug(`Canon SDK: Setting exposure compensation to ${compensation}`);
    // In production: await CanonSDK.setExposureCompensation(compensation);
    return { success: true, value: compensation };
  }

  async setFocusMode(mode) {
    logger.debug(`Canon SDK: Setting focus mode to ${mode}`);
    // In production: await CanonSDK.setFocusMode(mode);
    return { success: true, value: mode };
  }

  async setMeteringMode(mode) {
    logger.debug(`Canon SDK: Setting metering mode to ${mode}`);
    // In production: await CanonSDK.setMeteringMode(mode);
    return { success: true, value: mode };
  }

  async capturePhoto() {
    logger.debug('Canon SDK: Capturing photo');
    // In production: const result = await CanonSDK.takePicture();
    return {
      filename: `IMG_${Date.now()}.CR3`,
      path: `/photos/IMG_${Date.now()}.CR3`,
      thumbnail: `/thumbnails/IMG_${Date.now()}_thumb.jpg`
    };
  }

  async getISO() {
    // In production: return await CanonSDK.getISO();
    return 400;
  }

  async getAperture() {
    // In production: return await CanonSDK.getAperture();
    return 'f/2.8';
  }

  async getShutterSpeed() {
    // In production: return await CanonSDK.getShutterSpeed();
    return '1/125';
  }

  async getWhiteBalance() {
    // In production: return await CanonSDK.getWhiteBalance();
    return {
      mode: 'daylight',
      kelvin: 5500,
      shift: { magentaGreen: 0, blueAmber: 0 }
    };
  }

  async getExposureCompensation() {
    // In production: return await CanonSDK.getExposureCompensation();
    return '0.0';
  }

  async getFocusMode() {
    // In production: return await CanonSDK.getFocusMode();
    return 'single';
  }

  async getMeteringMode() {
    // In production: return await CanonSDK.getMeteringMode();
    return 'matrix';
  }
}

// Nikon SDK Adapter
class NikonSDKAdapter extends BaseSDKAdapter {
  async detectCameras() {
    // Simulate Nikon SDK call
    return [
      {
        model: 'Z9',
        serialNumber: 'NIK987654321'
      }
    ];
  }

  async getCapabilities() {
    return {
      iso: { min: 64, max: 25600, values: [64, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600] },
      aperture: { min: 1.4, max: 22, values: ['f/1.4', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16', 'f/22'] },
      shutterSpeed: { min: 30, max: 8000, values: ['30s', '15s', '8s', '4s', '2s', '1s', '1/2', '1/4', '1/8', '1/15', '1/30', '1/60', '1/125', '1/250', '1/500', '1/1000', '1/2000', '1/4000', '1/8000'] },
      whiteBalance: {
        modes: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade', 'custom'],
        kelvinRange: { min: 2500, max: 10000 },
        shiftRange: { magentaGreen: [-6, 6], blueAmber: [-6, 6] } // Nikon has limited range
      }
    };
  }

  // Similar implementation to Canon but with Nikon-specific SDK calls
  async setISO(iso) {
    logger.debug(`Nikon SDK: Setting ISO to ${iso}`);
    return { success: true, value: iso };
  }

  async setAperture(aperture) {
    logger.debug(`Nikon SDK: Setting aperture to ${aperture}`);
    return { success: true, value: aperture };
  }

  async setShutterSpeed(speed) {
    logger.debug(`Nikon SDK: Setting shutter speed to ${speed}`);
    return { success: true, value: speed };
  }

  async setWhiteBalance(wb) {
    logger.debug(`Nikon SDK: Setting white balance:`, wb);
    // Nikon specific: Clamp shift values to [-6, 6] range
    if (wb.shift) {
      wb.shift.magentaGreen = Math.max(-6, Math.min(6, wb.shift.magentaGreen));
      wb.shift.blueAmber = Math.max(-6, Math.min(6, wb.shift.blueAmber));
    }
    return { success: true, value: wb };
  }

  async setExposureCompensation(compensation) {
    logger.debug(`Nikon SDK: Setting exposure compensation to ${compensation}`);
    return { success: true, value: compensation };
  }

  async setFocusMode(mode) {
    logger.debug(`Nikon SDK: Setting focus mode to ${mode}`);
    return { success: true, value: mode };
  }

  async setMeteringMode(mode) {
    logger.debug(`Nikon SDK: Setting metering mode to ${mode}`);
    return { success: true, value: mode };
  }

  async capturePhoto() {
    logger.debug('Nikon SDK: Capturing photo');
    return {
      filename: `DSC_${Date.now()}.NEF`,
      path: `/photos/DSC_${Date.now()}.NEF`,
      thumbnail: `/thumbnails/DSC_${Date.now()}_thumb.jpg`
    };
  }

  async getISO() { return 400; }
  async getAperture() { return 'f/2.8'; }
  async getShutterSpeed() { return '1/125'; }
  async getWhiteBalance() {
    return {
      mode: 'daylight',
      kelvin: 5500,
      shift: { magentaGreen: 0, blueAmber: 0 }
    };
  }
  async getExposureCompensation() { return '0.0'; }
  async getFocusMode() { return 'single'; }
  async getMeteringMode() { return 'matrix'; }
}

// Sony SDK Adapter
class SonySDKAdapter extends BaseSDKAdapter {
  async detectCameras() {
    return [
      {
        model: 'α7R V',
        serialNumber: 'SNY555666777'
      }
    ];
  }

  async getCapabilities() {
    return {
      iso: { min: 100, max: 102400, values: [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200, 102400] },
      aperture: { min: 1.4, max: 22, values: ['f/1.4', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16', 'f/22'] },
      shutterSpeed: { min: 30, max: 8000, values: ['30s', '15s', '8s', '4s', '2s', '1s', '1/2', '1/4', '1/8', '1/15', '1/30', '1/60', '1/125', '1/250', '1/500', '1/1000', '1/2000', '1/4000', '1/8000'] },
      whiteBalance: {
        modes: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade', 'custom'],
        kelvinRange: { min: 2500, max: 9900 },
        shiftRange: { magentaGreen: [-9, 9], blueAmber: [-9, 9] }
      }
    };
  }

  // Sony-specific implementations
  async setISO(iso) {
    logger.debug(`Sony SDK: Setting ISO to ${iso}`);
    return { success: true, value: iso };
  }

  async setAperture(aperture) {
    logger.debug(`Sony SDK: Setting aperture to ${aperture}`);
    return { success: true, value: aperture };
  }

  async setShutterSpeed(speed) {
    logger.debug(`Sony SDK: Setting shutter speed to ${speed}`);
    return { success: true, value: speed };
  }

  async setWhiteBalance(wb) {
    logger.debug(`Sony SDK: Setting white balance:`, wb);
    return { success: true, value: wb };
  }

  async setExposureCompensation(compensation) {
    logger.debug(`Sony SDK: Setting exposure compensation to ${compensation}`);
    return { success: true, value: compensation };
  }

  async setFocusMode(mode) {
    logger.debug(`Sony SDK: Setting focus mode to ${mode}`);
    return { success: true, value: mode };
  }

  async setMeteringMode(mode) {
    logger.debug(`Sony SDK: Setting metering mode to ${mode}`);
    return { success: true, value: mode };
  }

  async capturePhoto() {
    logger.debug('Sony SDK: Capturing photo');
    return {
      filename: `DSC${Date.now()}.ARW`,
      path: `/photos/DSC${Date.now()}.ARW`,
      thumbnail: `/thumbnails/DSC${Date.now()}_thumb.jpg`
    };
  }

  async getISO() { return 400; }
  async getAperture() { return 'f/2.8'; }
  async getShutterSpeed() { return '1/125'; }
  async getWhiteBalance() {
    return {
      mode: 'daylight',
      kelvin: 5500,
      shift: { magentaGreen: 0, blueAmber: 0 }
    };
  }
  async getExposureCompensation() { return '0.0'; }
  async getFocusMode() { return 'single'; }
  async getMeteringMode() { return 'matrix'; }
}

// Fujifilm SDK Adapter
class FujifilmSDKAdapter extends BaseSDKAdapter {
  async detectCameras() {
    return [
      {
        model: 'X-T5',
        serialNumber: 'FUJI111222333'
      }
    ];
  }

  async getCapabilities() {
    return {
      iso: { min: 160, max: 12800, values: [160, 200, 400, 800, 1600, 3200, 6400, 12800] },
      aperture: { min: 1.4, max: 16, values: ['f/1.4', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16'] },
      shutterSpeed: { min: 30, max: 8000, values: ['30s', '15s', '8s', '4s', '2s', '1s', '1/2', '1/4', '1/8', '1/15', '1/30', '1/60', '1/125', '1/250', '1/500', '1/1000', '1/2000', '1/4000', '1/8000'] },
      whiteBalance: {
        modes: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade', 'custom'],
        kelvinRange: { min: 2500, max: 10000 },
        shiftRange: { magentaGreen: [-9, 9], blueAmber: [-9, 9] }
      }
    };
  }

  // Fujifilm-specific implementations
  async setISO(iso) {
    logger.debug(`Fujifilm SDK: Setting ISO to ${iso}`);
    return { success: true, value: iso };
  }

  async setAperture(aperture) {
    logger.debug(`Fujifilm SDK: Setting aperture to ${aperture}`);
    return { success: true, value: aperture };
  }

  async setShutterSpeed(speed) {
    logger.debug(`Fujifilm SDK: Setting shutter speed to ${speed}`);
    return { success: true, value: speed };
  }

  async setWhiteBalance(wb) {
    logger.debug(`Fujifilm SDK: Setting white balance:`, wb);
    return { success: true, value: wb };
  }

  async setExposureCompensation(compensation) {
    logger.debug(`Fujifilm SDK: Setting exposure compensation to ${compensation}`);
    return { success: true, value: compensation };
  }

  async setFocusMode(mode) {
    logger.debug(`Fujifilm SDK: Setting focus mode to ${mode}`);
    return { success: true, value: mode };
  }

  async setMeteringMode(mode) {
    logger.debug(`Fujifilm SDK: Setting metering mode to ${mode}`);
    return { success: true, value: mode };
  }

  async capturePhoto() {
    logger.debug('Fujifilm SDK: Capturing photo');
    return {
      filename: `DSCF${Date.now()}.RAF`,
      path: `/photos/DSCF${Date.now()}.RAF`,
      thumbnail: `/thumbnails/DSCF${Date.now()}_thumb.jpg`
    };
  }

  async getISO() { return 400; }
  async getAperture() { return 'f/2.8'; }
  async getShutterSpeed() { return '1/125'; }
  async getWhiteBalance() {
    return {
      mode: 'daylight',
      kelvin: 5500,
      shift: { magentaGreen: 0, blueAmber: 0 }
    };
  }
  async getExposureCompensation() { return '0.0'; }
  async getFocusMode() { return 'single'; }
  async getMeteringMode() { return 'matrix'; }
}

module.exports = CameraSDKService;