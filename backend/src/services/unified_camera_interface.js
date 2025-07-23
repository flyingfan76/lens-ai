const EventEmitter = require('events');
const logger = require('../utils/logger');

/**
 * Unified Camera Interface - Abstract base class for all camera brands
 * Provides a consistent API across Canon, Nikon, Sony, Fujifilm, Olympus, Panasonic, etc.
 */
class UnifiedCameraInterface extends EventEmitter {
  constructor(brand) {
    super();
    this.brand = brand;
    this.isInitialized = false;
    this.connectedCamera = null;
    this.cameraList = [];
    this.liveViewSession = null;
    this.capabilities = {};
    
    // Standardized property names
    this.STANDARD_PROPERTIES = {
      ISO: 'iso',
      APERTURE: 'aperture',
      SHUTTER_SPEED: 'shutter_speed',
      WHITE_BALANCE: 'white_balance',
      FOCUS_MODE: 'focus_mode',
      EXPOSURE_MODE: 'exposure_mode',
      DRIVE_MODE: 'drive_mode',
      METERING_MODE: 'metering_mode',
      FLASH_MODE: 'flash_mode',
      IMAGE_QUALITY: 'image_quality'
    };
    
    // Standardized capability values
    this.STANDARD_VALUES = {
      ISO: ['AUTO', '50', '64', '80', '100', '125', '160', '200', '250', '320', '400', 
            '500', '640', '800', '1000', '1250', '1600', '2000', '2500', '3200', 
            '4000', '5000', '6400', '8000', '10000', '12800', '25600', '51200'],
      
      APERTURE: ['AUTO', 'f/1.0', 'f/1.2', 'f/1.4', 'f/1.8', 'f/2.0', 'f/2.2', 'f/2.5', 
                 'f/2.8', 'f/3.2', 'f/3.5', 'f/4.0', 'f/4.5', 'f/5.0', 'f/5.6', 'f/6.3', 
                 'f/7.1', 'f/8.0', 'f/9.0', 'f/10', 'f/11', 'f/13', 'f/14', 'f/16', 
                 'f/18', 'f/20', 'f/22'],
      
      SHUTTER_SPEED: ['AUTO', '30s', '25s', '20s', '15s', '13s', '10s', '8s', '6s', '5s', '4s', 
                      '3.2s', '2.5s', '2s', '1.6s', '1.3s', '1s', '1/1.3', '1/1.6', '1/2', 
                      '1/2.5', '1/3', '1/4', '1/5', '1/6', '1/8', '1/10', '1/13', '1/15', 
                      '1/20', '1/25', '1/30', '1/40', '1/50', '1/60', '1/80', '1/100', 
                      '1/125', '1/160', '1/200', '1/250', '1/320', '1/400', '1/500', '1/640', 
                      '1/800', '1/1000', '1/1250', '1/1600', '1/2000', '1/2500', '1/3200', 
                      '1/4000', '1/8000'],
      
      WHITE_BALANCE: ['AUTO', 'Daylight', 'Shade', 'Cloudy', 'Tungsten', 'Fluorescent', 
                      'Flash', 'Custom'],
      
      FOCUS_MODE: ['Single', 'Continuous', 'Auto', 'Manual'],
      
      EXPOSURE_MODE: ['Auto', 'Program', 'Aperture Priority', 'Shutter Priority', 'Manual'],
      
      DRIVE_MODE: ['Single', 'Continuous Low', 'Continuous High', 'Self-timer 2s', 
                   'Self-timer 10s', 'Remote'],
      
      METERING_MODE: ['Matrix', 'Center-weighted', 'Spot'],
      
      FLASH_MODE: ['Auto', 'On', 'Off', 'Red-eye Reduction', 'Slow Sync'],
      
      IMAGE_QUALITY: ['RAW', 'JPEG Fine', 'JPEG Normal', 'RAW+JPEG']
    };
  }

  // Abstract methods - must be implemented by subclasses
  async initialize() {
    throw new Error('initialize() must be implemented by subclass');
  }

  async discoverCameras() {
    throw new Error('discoverCameras() must be implemented by subclass');
  }

  async connectToCamera(cameraIndex) {
    throw new Error('connectToCamera() must be implemented by subclass');
  }

  async disconnectCamera() {
    throw new Error('disconnectCamera() must be implemented by subclass');
  }

  async getCameraSettings() {
    throw new Error('getCameraSettings() must be implemented by subclass');
  }

  async setCameraProperty(property, value) {
    throw new Error('setCameraProperty() must be implemented by subclass');
  }

  async startLiveView() {
    throw new Error('startLiveView() must be implemented by subclass');
  }

  async stopLiveView() {
    throw new Error('stopLiveView() must be implemented by subclass');
  }

  async captureImage(settings = {}) {
    throw new Error('captureImage() must be implemented by subclass');
  }

  async terminate() {
    throw new Error('terminate() must be implemented by subclass');
  }

  // Common utility methods available to all implementations
  normalizeProperty(brandProperty, value) {
    // Convert brand-specific property names to standard names
    const standardProperty = this.getStandardPropertyName(brandProperty);
    const standardValue = this.getStandardValue(standardProperty, value);
    
    return {
      property: standardProperty,
      value: standardValue
    };
  }

  getStandardPropertyName(brandProperty) {
    // Map brand-specific property names to standard names
    const propertyMap = this.getPropertyMapping();
    
    for (const [standard, brand] of Object.entries(propertyMap)) {
      if (brand === brandProperty || standard.toLowerCase() === brandProperty.toLowerCase()) {
        return this.STANDARD_PROPERTIES[standard];
      }
    }
    
    return brandProperty.toLowerCase();
  }

  getStandardValue(property, brandValue) {
    // Convert brand-specific values to standard format
    if (!brandValue) return brandValue;
    
    const value = brandValue.toString();
    
    switch (property) {
      case 'iso':
        return this.standardizeISO(value);
      case 'aperture':
        return this.standardizeAperture(value);
      case 'shutter_speed':
        return this.standardizeShutterSpeed(value);
      case 'white_balance':
        return this.standardizeWhiteBalance(value);
      default:
        return value;
    }
  }

  standardizeISO(value) {
    // Remove any prefixes/suffixes and extract numeric value
    const numericValue = value.toString().replace(/[^\d]/g, '');
    
    if (!numericValue) return 'AUTO';
    
    const iso = parseInt(numericValue);
    
    // Round to nearest standard ISO value
    const standardISOs = [50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 
                         800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 
                         8000, 10000, 12800, 25600, 51200, 102400];
    
    let closest = standardISOs[0];
    let minDiff = Math.abs(iso - closest);
    
    for (const standardISO of standardISOs) {
      const diff = Math.abs(iso - standardISO);
      if (diff < minDiff) {
        minDiff = diff;
        closest = standardISO;
      }
    }
    
    return closest.toString();
  }

  standardizeAperture(value) {
    // Normalize aperture format (f/2.8, F2.8, 2.8, etc.)
    let aperture = value.toString().toLowerCase();
    
    // Extract numeric value
    const match = aperture.match(/(\d+\.?\d*)/);
    if (!match) return 'f/4.0';
    
    const fNumber = parseFloat(match[1]);
    
    // Round to nearest standard f-stop
    const standardFStops = [1.0, 1.2, 1.4, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 
                           4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10, 11, 13, 14, 16, 18, 20, 22];
    
    let closest = standardFStops[0];
    let minDiff = Math.abs(fNumber - closest);
    
    for (const fStop of standardFStops) {
      const diff = Math.abs(fNumber - fStop);
      if (diff < minDiff) {
        minDiff = diff;
        closest = fStop;
      }
    }
    
    return `f/${closest === Math.floor(closest) ? closest : closest.toFixed(1)}`;
  }

  standardizeShutterSpeed(value) {
    // Normalize shutter speed format (1/125, 1/125s, 0.008s, etc.)
    let speed = value.toString().toLowerCase().replace(/[s"]/g, '');
    
    // Handle fractional format (1/125)
    if (speed.includes('/')) {
      const [numerator, denominator] = speed.split('/').map(Number);
      if (numerator && denominator) {
        const seconds = numerator / denominator;
        return this.findClosestShutterSpeed(seconds);
      }
    }
    
    // Handle decimal format (0.008)
    const seconds = parseFloat(speed);
    if (!isNaN(seconds)) {
      return this.findClosestShutterSpeed(seconds);
    }
    
    return '1/125';
  }

  findClosestShutterSpeed(seconds) {
    const standardSpeeds = [
      { display: '30s', value: 30 },
      { display: '25s', value: 25 },
      { display: '20s', value: 20 },
      { display: '15s', value: 15 },
      { display: '13s', value: 13 },
      { display: '10s', value: 10 },
      { display: '8s', value: 8 },
      { display: '6s', value: 6 },
      { display: '5s', value: 5 },
      { display: '4s', value: 4 },
      { display: '3.2s', value: 3.2 },
      { display: '2.5s', value: 2.5 },
      { display: '2s', value: 2 },
      { display: '1.6s', value: 1.6 },
      { display: '1.3s', value: 1.3 },
      { display: '1s', value: 1 },
      { display: '1/1.3', value: 1/1.3 },
      { display: '1/1.6', value: 1/1.6 },
      { display: '1/2', value: 0.5 },
      { display: '1/2.5', value: 1/2.5 },
      { display: '1/3', value: 1/3 },
      { display: '1/4', value: 0.25 },
      { display: '1/5', value: 0.2 },
      { display: '1/6', value: 1/6 },
      { display: '1/8', value: 0.125 },
      { display: '1/10', value: 0.1 },
      { display: '1/13', value: 1/13 },
      { display: '1/15', value: 1/15 },
      { display: '1/20', value: 0.05 },
      { display: '1/25', value: 0.04 },
      { display: '1/30', value: 1/30 },
      { display: '1/40', value: 1/40 },
      { display: '1/50', value: 0.02 },
      { display: '1/60', value: 1/60 },
      { display: '1/80', value: 1/80 },
      { display: '1/100', value: 0.01 },
      { display: '1/125', value: 1/125 },
      { display: '1/160', value: 1/160 },
      { display: '1/200', value: 1/200 },
      { display: '1/250', value: 1/250 },
      { display: '1/320', value: 1/320 },
      { display: '1/400', value: 1/400 },
      { display: '1/500', value: 1/500 },
      { display: '1/640', value: 1/640 },
      { display: '1/800', value: 1/800 },
      { display: '1/1000', value: 1/1000 },
      { display: '1/1250', value: 1/1250 },
      { display: '1/1600', value: 1/1600 },
      { display: '1/2000', value: 1/2000 },
      { display: '1/2500', value: 1/2500 },
      { display: '1/3200', value: 1/3200 },
      { display: '1/4000', value: 1/4000 },
      { display: '1/8000', value: 1/8000 }
    ];
    
    let closest = standardSpeeds[0];
    let minDiff = Math.abs(seconds - closest.value);
    
    for (const speed of standardSpeeds) {
      const diff = Math.abs(seconds - speed.value);
      if (diff < minDiff) {
        minDiff = diff;
        closest = speed;
      }
    }
    
    return closest.display;
  }

  standardizeWhiteBalance(value) {
    const wbMap = {
      'auto': 'AUTO',
      'daylight': 'Daylight',
      'sun': 'Daylight',
      'shade': 'Shade',
      'cloudy': 'Cloudy',
      'overcast': 'Cloudy',
      'tungsten': 'Tungsten',
      'incandescent': 'Tungsten',
      'fluorescent': 'Fluorescent',
      'flash': 'Flash',
      'custom': 'Custom',
      'manual': 'Custom'
    };
    
    const normalized = value.toString().toLowerCase();
    
    for (const [key, standard] of Object.entries(wbMap)) {
      if (normalized.includes(key)) {
        return standard;
      }
    }
    
    return value;
  }

  // Brand-specific method to be overridden
  getPropertyMapping() {
    return {};
  }

  // Common validation methods
  validateSettings(settings) {
    const validatedSettings = {};
    const errors = [];
    
    for (const [property, value] of Object.entries(settings)) {
      try {
        const standardized = this.normalizeProperty(property, value);
        const isValid = this.validatePropertyValue(standardized.property, standardized.value);
        
        if (isValid) {
          validatedSettings[standardized.property] = standardized.value;
        } else {
          errors.push(`Invalid value ${value} for property ${property}`);
        }
      } catch (error) {
        errors.push(`Error validating ${property}: ${error.message}`);
      }
    }
    
    return {
      settings: validatedSettings,
      errors,
      isValid: errors.length === 0
    };
  }

  validatePropertyValue(property, value) {
    const standardValues = this.STANDARD_VALUES[property.toUpperCase()];
    
    if (!standardValues) {
      return true; // Allow unknown properties
    }
    
    return standardValues.includes(value) || value === 'AUTO';
  }

  // Camera capability methods
  getSupportedCapabilities() {
    return {
      brand: this.brand,
      properties: Object.keys(this.STANDARD_PROPERTIES),
      values: this.STANDARD_VALUES,
      brandSpecific: this.getBrandSpecificCapabilities()
    };
  }

  getBrandSpecificCapabilities() {
    // Override in brand-specific implementations
    return {};
  }

  // Event handling helpers
  emitStandardEvent(eventType, data) {
    const standardData = {
      ...data,
      brand: this.brand,
      timestamp: new Date().toISOString()
    };
    
    this.emit(eventType, standardData);
  }

  // Utility methods for camera information
  getCameraInfo() {
    if (!this.connectedCamera) {
      return null;
    }
    
    return {
      brand: this.brand,
      model: this.connectedCamera.model || 'Unknown',
      serialNumber: this.connectedCamera.serialNumber || 'Unknown',
      firmware: this.connectedCamera.firmware || 'Unknown',
      connectionType: this.connectedCamera.connectionType || 'unknown',
      capabilities: this.getSupportedCapabilities(),
      status: {
        connected: true,
        liveViewActive: !!this.liveViewSession,
        batteryLevel: this.connectedCamera.batteryLevel || 'unknown',
        memoryCardStatus: this.connectedCamera.memoryCardStatus || 'unknown'
      }
    };
  }

  getConnectionStatus() {
    return {
      brand: this.brand,
      initialized: this.isInitialized,
      connected: !!this.connectedCamera,
      cameraCount: this.cameraList.length,
      liveViewActive: !!this.liveViewSession,
      capabilities: this.getSupportedCapabilities()
    };
  }

  // Batch operations
  async applySettings(settings) {
    const validation = this.validateSettings(settings);
    
    if (!validation.isValid) {
      throw new Error(`Invalid settings: ${validation.errors.join(', ')}`);
    }
    
    const results = {};
    const errors = [];
    
    for (const [property, value] of Object.entries(validation.settings)) {
      try {
        await this.setCameraProperty(property, value);
        results[property] = { success: true, value };
      } catch (error) {
        errors.push({ property, error: error.message });
        results[property] = { success: false, error: error.message };
      }
    }
    
    return {
      success: errors.length === 0,
      results,
      errors
    };
  }

  // Performance monitoring
  async measurePerformance(operation, ...args) {
    const startTime = Date.now();
    let result;
    let error = null;
    
    try {
      result = await operation.apply(this, args);
    } catch (err) {
      error = err;
    }
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    this.emit('performanceMetric', {
      operation: operation.name,
      duration,
      success: !error,
      brand: this.brand,
      timestamp: new Date().toISOString()
    });
    
    if (error) {
      throw error;
    }
    
    return result;
  }
}

module.exports = UnifiedCameraInterface;