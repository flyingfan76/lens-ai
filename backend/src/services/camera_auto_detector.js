const EventEmitter = require('events');
const logger = require('../utils/logger');
const fs = require('fs').promises;
const path = require('path');

class CameraAutoDetector extends EventEmitter {
  constructor() {
    super();
    
    // Camera identification database
    this.cameraDatabase = {
      // USB Vendor/Product ID mappings
      usbIds: {
        '04a9': { name: 'canon', display: 'Canon' },
        '04b0': { name: 'nikon', display: 'Nikon' },
        '054c': { name: 'sony', display: 'Sony' },
        '04cb': { name: 'fujifilm', display: 'Fujifilm' },
        '07b4': { name: 'olympus', display: 'Olympus' },
        '04da': { name: 'panasonic', display: 'Panasonic' },
        '05ac': { name: 'apple', display: 'Apple' }, // iPhone cameras
        '18d1': { name: 'google', display: 'Google' } // Pixel cameras
      },
      
      // Model name patterns for enhanced detection
      modelPatterns: {
        canon: [
          { pattern: /EOS R(\d+)/, series: 'EOS R', type: 'mirrorless', level: 'pro' },
          { pattern: /EOS 5D Mark (\w+)/, series: 'EOS 5D', type: 'dslr', level: 'pro' },
          { pattern: /EOS 6D Mark (\w+)/, series: 'EOS 6D', type: 'dslr', level: 'prosumer' },
          { pattern: /EOS 90D/, series: 'EOS 90D', type: 'dslr', level: 'enthusiast' },
          { pattern: /PowerShot/, series: 'PowerShot', type: 'compact', level: 'consumer' }
        ],
        nikon: [
          { pattern: /Z(\d+)/, series: 'Z', type: 'mirrorless', level: 'pro' },
          { pattern: /D850/, series: 'D850', type: 'dslr', level: 'pro' },
          { pattern: /D780/, series: 'D780', type: 'dslr', level: 'prosumer' },
          { pattern: /(?:DSC )?D90/, series: 'D90', type: 'dslr', level: 'enthusiast' },
          { pattern: /D(\d{3,4})/, series: 'D-series', type: 'dslr', level: 'enthusiast' }
        ],
        sony: [
          { pattern: /α7R (\w+)/, series: 'α7R', type: 'mirrorless', level: 'pro' },
          { pattern: /α7 (\w+)/, series: 'α7', type: 'mirrorless', level: 'prosumer' },
          { pattern: /α6(\d+)/, series: 'α6000', type: 'mirrorless', level: 'enthusiast' },
          { pattern: /FX(\d+)/, series: 'FX', type: 'cinema', level: 'pro' }
        ],
        fujifilm: [
          { pattern: /GFX(\d+)/, series: 'GFX', type: 'medium_format', level: 'pro' },
          { pattern: /X-T(\d+)/, series: 'X-T', type: 'mirrorless', level: 'pro' },
          { pattern: /X-H(\d+)/, series: 'X-H', type: 'mirrorless', level: 'pro' },
          { pattern: /X-E(\d+)/, series: 'X-E', type: 'mirrorless', level: 'enthusiast' },
          { pattern: /X100(\w)/, series: 'X100', type: 'compact_pro', level: 'enthusiast' }
        ]
      },
      
      // Network discovery patterns (for wireless cameras)
      networkPatterns: {
        canon: {
          mdnsService: '_canon-eos._tcp',
          httpPort: 8080,
          deviceName: /Canon.*EOS/i
        },
        nikon: {
          mdnsService: '_nikon-http._tcp',
          httpPort: 15740,
          deviceName: /Nikon/i
        },
        sony: {
          mdnsService: '_sony-camera._tcp',
          httpPort: 64321,
          deviceName: /Sony/i
        },
        fujifilm: {
          mdnsService: '_fujifilm-camera._tcp',
          httpPort: 55740,
          deviceName: /FUJIFILM/i
        }
      }
    };
    
    // Auto-configuration profiles
    this.autoConfigProfiles = {
      beginner: {
        priority: ['ease_of_use', 'auto_modes', 'image_stabilization'],
        recommended_modes: ['Auto', 'Program'],
        settings: {
          iso: 'AUTO',
          focus_mode: 'Auto',
          metering_mode: 'Matrix',
          drive_mode: 'Single'
        }
      },
      enthusiast: {
        priority: ['image_quality', 'manual_control', 'creative_features'],
        recommended_modes: ['Aperture Priority', 'Manual'],
        settings: {
          image_quality: 'RAW+JPEG',
          metering_mode: 'Matrix',
          focus_mode: 'Single'
        }
      },
      professional: {
        priority: ['speed', 'reliability', 'customization'],
        recommended_modes: ['Manual', 'Shutter Priority'],
        settings: {
          image_quality: 'RAW',
          drive_mode: 'Continuous High',
          focus_mode: 'Continuous'
        }
      }
    };
    
    // Detection methods
    this.detectionMethods = {
      usb: this.detectUSBCameras.bind(this),
      network: this.detectNetworkCameras.bind(this),
      ptp: this.detectPTPCameras.bind(this),
      gphoto: this.detectGPhotoCameras.bind(this)
    };
    
    this.isScanning = false;
    this.lastScanResults = [];
    this.knownDevices = new Map();
  }

  async detectAllCameras(options = {}) {
    if (this.isScanning) {
      logger.warn('Camera detection already in progress');
      return this.lastScanResults;
    }

    try {
      this.isScanning = true;
      logger.info('Starting comprehensive camera detection...');
      
      const detectionResults = [];
      const methods = options.methods || Object.keys(this.detectionMethods);
      
      // Run all detection methods in parallel
      const detectionPromises = methods.map(async (method) => {
        try {
          const startTime = Date.now();
          const cameras = await this.detectionMethods[method](options);
          const duration = Date.now() - startTime;
          
          return {
            method,
            success: true,
            cameras: cameras || [],
            duration,
            timestamp: new Date().toISOString()
          };
        } catch (error) {
          logger.warn(`Detection method ${method} failed:`, error);
          return {
            method,
            success: false,
            error: error.message,
            cameras: [],
            duration: 0,
            timestamp: new Date().toISOString()
          };
        }
      });
      
      const results = await Promise.all(detectionPromises);
      
      // Merge and deduplicate results
      const allCameras = [];
      const seenDevices = new Set();
      
      for (const result of results) {
        if (result.success) {
          for (const camera of result.cameras) {
            const deviceKey = this.generateDeviceKey(camera);
            if (!seenDevices.has(deviceKey)) {
              seenDevices.add(deviceKey);
              
              // Enhance camera information
              const enhancedCamera = await this.enhanceCameraInformation(camera, result.method);
              allCameras.push(enhancedCamera);
            }
          }
        }
        detectionResults.push(result);
      }
      
      // Store results
      this.lastScanResults = allCameras;
      
      // Update known devices
      this.updateKnownDevices(allCameras);
      
      logger.info(`Camera detection completed: ${allCameras.length} unique cameras found`);
      
      this.emit('detectionComplete', {
        cameras: allCameras,
        methods: detectionResults,
        totalFound: allCameras.length,
        duration: Math.max(...results.map(r => r.duration))
      });
      
      return allCameras;
      
    } catch (error) {
      logger.error('Camera detection failed:', error);
      throw error;
    } finally {
      this.isScanning = false;
    }
  }

  async detectUSBCameras(options = {}) {
    try {
      logger.debug('Detecting USB cameras...');
      
      // On macOS/Linux, read USB devices
      const usbDevices = await this.readUSBDevices();
      const cameras = [];
      
      for (const device of usbDevices) {
        const vendorInfo = this.cameraDatabase.usbIds[device.vendorId];
        if (vendorInfo) {
          cameras.push({
            brand: vendorInfo.name,
            brandDisplay: vendorInfo.display,
            model: device.product || 'Unknown Model',
            serialNumber: device.serial || `USB_${device.vendorId}_${device.productId}`,
            connectionType: 'usb',
            vendorId: device.vendorId,
            productId: device.productId,
            devicePath: device.path,
            detectionMethod: 'usb'
          });
        }
      }
      
      return cameras;
      
    } catch (error) {
      logger.debug('USB detection failed:', error);
      return [];
    }
  }

  async readUSBDevices() {
    try {
      // Try different methods based on platform
      if (process.platform === 'darwin') {
        return await this.readUSBDevicesMacOS();
      } else if (process.platform === 'linux') {
        return await this.readUSBDevicesLinux();
      } else {
        return await this.readUSBDevicesWindows();
      }
    } catch (error) {
      logger.debug('Failed to read USB devices:', error);
      return [];
    }
  }

  async readUSBDevicesMacOS() {
    const { spawn } = require('child_process');
    
    return new Promise((resolve) => {
      const devices = [];
      const process = spawn('system_profiler', ['SPUSBDataType', '-xml']);
      
      let xmlData = '';
      process.stdout.on('data', (data) => {
        xmlData += data.toString();
      });
      
      process.on('close', () => {
        try {
          // Parse XML data using proper XML structure
          // Look for device blocks with vendor_id and product_id
          const deviceBlocks = xmlData.split('<dict>').filter(block => 
            block.includes('vendor_id') && block.includes('product_id')
          );
          
          for (const block of deviceBlocks) {
            const vendorMatch = block.match(/<key>vendor_id<\/key>\s*<string>0x([0-9a-f]{4})/i);
            const productMatch = block.match(/<key>product_id<\/key>\s*<string>0x([0-9a-f]{4})/i);
            const nameMatch = block.match(/<key>_name<\/key>\s*<string>([^<]+)<\/string>/i);
            const serialMatch = block.match(/<key>serial_num<\/key>\s*<string>([^<]+)<\/string>/i);
            
            if (vendorMatch && productMatch) {
              const vendorId = vendorMatch[1].toLowerCase();
              const productId = productMatch[1].toLowerCase();
              const name = nameMatch ? nameMatch[1] : 'Unknown Device';
              const serial = serialMatch ? serialMatch[1] : null;
              
              // Check if this is a known camera vendor
              if (this.cameraDatabase.usbIds[vendorId]) {
                devices.push({
                  vendorId: vendorId,
                  productId: productId,
                  product: name,
                  serial: serial,
                  path: `/dev/usb_${vendorId}_${productId}`
                });
              }
            }
          }
        } catch (error) {
          logger.debug('Error parsing USB XML data:', error);
        }
        
        resolve(devices);
      });
      
      process.on('error', () => resolve(devices));
      
      setTimeout(() => resolve(devices), 5000); // Timeout after 5 seconds
    });
  }

  async readUSBDevicesLinux() {
    try {
      const lsusbOutput = await this.executeCommand('lsusb');
      const devices = [];
      
      const lines = lsusbOutput.split('\n');
      for (const line of lines) {
        const match = line.match(/Bus \d+ Device \d+: ID ([0-9a-f]{4}):([0-9a-f]{4}) (.+)/i);
        if (match) {
          devices.push({
            vendorId: match[1].toLowerCase(),
            productId: match[2].toLowerCase(),
            product: match[3].trim(),
            path: `/dev/bus/usb/${match[1]}/${match[2]}`
          });
        }
      }
      
      return devices;
    } catch (error) {
      return [];
    }
  }

  async readUSBDevicesWindows() {
    // Windows implementation would use WMI or similar
    // For now, return empty array as this requires more complex setup
    return [];
  }

  async detectNetworkCameras(options = {}) {
    try {
      logger.debug('Detecting network cameras...');
      
      // Use mDNS discovery for wireless cameras
      const networkCameras = await this.discoverMDNSCameras();
      const upnpCameras = await this.discoverUPnPCameras();
      
      return [...networkCameras, ...upnpCameras];
      
    } catch (error) {
      logger.debug('Network detection failed:', error);
      return [];
    }
  }

  async discoverMDNSCameras() {
    try {
      const cameras = [];
      
      // Mock mDNS discovery disabled - only show real hardware
      const mockDiscovery = [];
      
      for (const service of mockDiscovery) {
        const brandInfo = Object.values(this.cameraDatabase.usbIds).find(b => b.name === service.brand);
        if (brandInfo) {
          cameras.push({
            brand: service.brand,
            brandDisplay: brandInfo.display,
            model: service.name.split('.')[0],
            connectionType: 'wireless',
            ipAddress: service.addresses[0],
            port: service.port,
            detectionMethod: 'mdns',
            networkInfo: {
              serviceName: service.name,
              addresses: service.addresses
            }
          });
        }
      }
      
      return cameras;
      
    } catch (error) {
      logger.debug('mDNS discovery failed:', error);
      return [];
    }
  }

  async discoverUPnPCameras() {
    // UPnP discovery implementation
    // For now, return empty array
    return [];
  }

  async detectPTPCameras(options = {}) {
    try {
      logger.debug('Detecting PTP cameras...');
      
      // PTP (Picture Transfer Protocol) detection
      // This would typically use libgphoto2 or similar
      return [];
      
    } catch (error) {
      logger.debug('PTP detection failed:', error);
      return [];
    }
  }

  async detectGPhotoCameras(options = {}) {
    try {
      logger.debug('Detecting cameras via gPhoto2...');
      
      // Try to use gphoto2 command line tool
      const gphotoOutput = await this.executeCommand('gphoto2 --list-cameras');
      const cameras = [];
      
      const lines = gphotoOutput.split('\n');
      for (const line of lines) {
        const match = line.match(/^\s*"([^"]+)"\s+\(([^)]+)\)/);
        if (match) {
          const model = match[1];
          const connection = match[2];
          
          // Determine brand from model name
          const brand = this.detectBrandFromModel(model);
          
          if (brand) {
            cameras.push({
              brand: brand.name,
              brandDisplay: brand.display,
              model: model,
              connectionType: connection.includes('usb') ? 'usb' : 'unknown',
              detectionMethod: 'gphoto',
              gphotoSupported: true
            });
          }
        }
      }
      
      return cameras;
      
    } catch (error) {
      logger.debug('gPhoto2 detection failed:', error);
      return [];
    }
  }

  detectBrandFromModel(modelName) {
    const modelLower = modelName.toLowerCase();
    
    // Check against known brand patterns
    for (const [brandKey, brandInfo] of Object.entries(this.cameraDatabase.usbIds)) {
      if (modelLower.includes(brandInfo.name)) {
        return brandInfo;
      }
    }
    
    // Check against model patterns
    for (const [brand, patterns] of Object.entries(this.cameraDatabase.modelPatterns)) {
      for (const pattern of patterns) {
        if (pattern.pattern.test(modelName)) {
          return this.cameraDatabase.usbIds[Object.keys(this.cameraDatabase.usbIds).find(
            key => this.cameraDatabase.usbIds[key].name === brand
          )];
        }
      }
    }
    
    return null;
  }

  async enhanceCameraInformation(camera, detectionMethod) {
    try {
      const enhanced = {
        ...camera,
        detectionMethod,
        enhancedAt: new Date().toISOString()
      };
      
      // Add model-specific information
      if (camera.brand && camera.model) {
        const modelInfo = this.analyzeModel(camera.model, camera.brand);
        enhanced.modelInfo = modelInfo;
        
        // Add capabilities based on model
        enhanced.capabilities = this.getCameraCapabilities(modelInfo, camera.brand);
        
        // Add recommended configuration
        enhanced.autoConfig = this.generateAutoConfiguration(modelInfo, camera.brand);
      }
      
      // Add connection quality score
      enhanced.connectionQuality = this.assessConnectionQuality(camera);
      
      // Add compatibility score
      enhanced.compatibilityScore = this.calculateCompatibilityScore(camera);
      
      return enhanced;
      
    } catch (error) {
      logger.debug('Error enhancing camera information:', error);
      return camera;
    }
  }

  analyzeModel(modelName, brand) {
    const patterns = this.cameraDatabase.modelPatterns[brand] || [];
    
    for (const pattern of patterns) {
      const match = modelName.match(pattern.pattern);
      if (match) {
        return {
          series: pattern.series,
          type: pattern.type,
          level: pattern.level,
          matched: match[0],
          fullModel: modelName,
          generation: this.extractGeneration(match),
          releaseYear: this.estimateReleaseYear(pattern.series, brand)
        };
      }
    }
    
    return {
      series: 'Unknown',
      type: 'unknown',
      level: 'unknown',
      fullModel: modelName
    };
  }

  extractGeneration(match) {
    // Extract generation/version number from regex match
    if (match.length > 1) {
      const version = match[1];
      if (!isNaN(version)) {
        return parseInt(version);
      }
    }
    return null;
  }

  estimateReleaseYear(series, brand) {
    // Estimate release year based on series and brand knowledge
    const yearMap = {
      canon: {
        'EOS R': 2020,
        'EOS 5D': 2016,
        'EOS 6D': 2017
      },
      sony: {
        'α7R': 2019,
        'α7': 2018,
        'α6000': 2017
      },
      fujifilm: {
        'X-T': 2020,
        'GFX': 2021
      }
    };
    
    return yearMap[brand]?.[series] || null;
  }

  getCameraCapabilities(modelInfo, brand) {
    const baseCapabilities = {
      liveView: true,
      remoteCapture: true,
      settingsControl: true,
      wifi: false,
      bluetooth: false,
      touchScreen: false,
      weather_sealing: false
    };
    
    // Enhance based on camera level and type
    if (modelInfo.level === 'pro') {
      baseCapabilities.wifi = true;
      baseCapabilities.bluetooth = true;
      baseCapabilities.weather_sealing = true;
      baseCapabilities.customButtons = true;
    }
    
    if (modelInfo.type === 'mirrorless') {
      baseCapabilities.touchScreen = true;
      baseCapabilities.evf = true;
    }
    
    // Brand-specific capabilities
    if (brand === 'fujifilm') {
      baseCapabilities.filmSimulation = true;
      baseCapabilities.grainEffect = true;
    }
    
    if (brand === 'sony') {
      baseCapabilities.eyeAF = modelInfo.level !== 'consumer';
      baseCapabilities.animalEyeAF = modelInfo.level === 'pro';
    }
    
    return baseCapabilities;
  }

  generateAutoConfiguration(modelInfo, brand, userLevel = 'enthusiast') {
    const profile = this.autoConfigProfiles[userLevel] || this.autoConfigProfiles.enthusiast;
    const config = {
      userLevel,
      profile: profile,
      recommended: {
        ...profile.settings
      },
      optimizations: []
    };
    
    // Model-specific optimizations
    if (modelInfo.type === 'mirrorless') {
      config.optimizations.push('Use electronic viewfinder for precise exposure preview');
      config.recommended.viewfinder = 'electronic';
    }
    
    if (modelInfo.level === 'pro') {
      config.optimizations.push('Enable back-button focus for better focus control');
      config.recommended.back_button_focus = true;
    }
    
    // Brand-specific recommendations
    if (brand === 'fujifilm') {
      config.recommended.film_simulation = 'Classic Chrome';
      config.optimizations.push('Experiment with film simulation modes for unique looks');
    }
    
    if (brand === 'sony') {
      config.optimizations.push('Enable Eye AF for portrait photography');
      config.recommended.eye_af = 'On';
    }
    
    return config;
  }

  assessConnectionQuality(camera) {
    let score = 0.5; // Base score
    
    // Connection type scoring
    if (camera.connectionType === 'usb') score += 0.3;
    else if (camera.connectionType === 'wireless') score += 0.2;
    
    // Additional info scoring
    if (camera.serialNumber && !camera.serialNumber.startsWith('USB_')) score += 0.1;
    if (camera.gphotoSupported) score += 0.2;
    if (camera.ipAddress) score += 0.1;
    
    return Math.min(1.0, score);
  }

  calculateCompatibilityScore(camera) {
    let score = 0.6; // Base score
    
    // Brand recognition
    if (camera.brand && this.cameraDatabase.usbIds[Object.keys(this.cameraDatabase.usbIds).find(
      key => this.cameraDatabase.usbIds[key].name === camera.brand
    )]) {
      score += 0.2;
    }
    
    // Detection method reliability
    const methodScores = {
      usb: 0.2,
      gphoto: 0.15,
      mdns: 0.1,
      upnp: 0.05
    };
    score += methodScores[camera.detectionMethod] || 0;
    
    return Math.min(1.0, Math.round(score * 100) / 100);
  }

  generateDeviceKey(camera) {
    // Generate unique key for deduplication
    if (camera.serialNumber) {
      return `${camera.brand}_${camera.serialNumber}`;
    }
    
    if (camera.vendorId && camera.productId) {
      return `usb_${camera.vendorId}_${camera.productId}`;
    }
    
    if (camera.ipAddress) {
      return `net_${camera.ipAddress}`;
    }
    
    return `${camera.brand}_${camera.model}_${Date.now()}`;
  }

  updateKnownDevices(cameras) {
    for (const camera of cameras) {
      const key = this.generateDeviceKey(camera);
      this.knownDevices.set(key, {
        ...camera,
        lastSeen: new Date().toISOString(),
        timesDetected: (this.knownDevices.get(key)?.timesDetected || 0) + 1
      });
    }
    
    // Clean up old entries (older than 1 hour)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    for (const [key, device] of this.knownDevices) {
      if (new Date(device.lastSeen) < oneHourAgo) {
        this.knownDevices.delete(key);
      }
    }
  }

  async executeCommand(command) {
    const { spawn } = require('child_process');
    
    return new Promise((resolve, reject) => {
      const [cmd, ...args] = command.split(' ');
      const process = spawn(cmd, args);
      
      let output = '';
      let error = '';
      
      process.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      process.stderr.on('data', (data) => {
        error += data.toString();
      });
      
      process.on('close', (code) => {
        if (code === 0) {
          resolve(output);
        } else {
          reject(new Error(`Command failed with code ${code}: ${error}`));
        }
      });
      
      process.on('error', reject);
      
      // Timeout after 10 seconds
      setTimeout(() => {
        process.kill();
        reject(new Error('Command timeout'));
      }, 10000);
    });
  }

  // Public API methods
  getKnownDevices() {
    return Array.from(this.knownDevices.values());
  }

  getDetectionResults() {
    return this.lastScanResults;
  }

  getSupportedBrands() {
    return Object.values(this.cameraDatabase.usbIds);
  }

  async saveDetectionResults(filePath) {
    try {
      const data = {
        timestamp: new Date().toISOString(),
        cameras: this.lastScanResults,
        knownDevices: Array.from(this.knownDevices.values())
      };
      
      await fs.writeFile(filePath, JSON.stringify(data, null, 2));
      return true;
    } catch (error) {
      logger.error('Failed to save detection results:', error);
      return false;
    }
  }

  async loadDetectionResults(filePath) {
    try {
      const data = JSON.parse(await fs.readFile(filePath, 'utf8'));
      this.lastScanResults = data.cameras || [];
      
      if (data.knownDevices) {
        this.knownDevices.clear();
        for (const device of data.knownDevices) {
          const key = this.generateDeviceKey(device);
          this.knownDevices.set(key, device);
        }
      }
      
      return true;
    } catch (error) {
      logger.error('Failed to load detection results:', error);
      return false;
    }
  }
}

module.exports = CameraAutoDetector;