const sharp = require('sharp');
const logger = require('../utils/logger');

class AdvancedImageAnalyzer {
  constructor() {
    this.histogramCache = new Map();
    this.analysisConfig = {
      histogramBins: 256,
      focusRegions: 9, // 3x3 grid for focus analysis
      exposureThresholds: {
        underexposed: 0.1,
        overexposed: 0.9,
        wellExposed: { min: 0.2, max: 0.8 }
      },
      noiseThresholds: {
        low: 0.05,
        medium: 0.15,
        high: 0.3
      }
    };
  }

  async analyzeImage(imageBuffer, options = {}) {
    try {
      logger.debug('Starting advanced image analysis...');
      const startTime = Date.now();

      // Convert to processable format
      const sharpImage = sharp(imageBuffer);
      const metadata = await sharpImage.metadata();
      
      // Perform parallel analyses
      const [
        histogramAnalysis,
        exposureAnalysis,
        focusAnalysis,
        noiseAnalysis,
        colorAnalysis
      ] = await Promise.all([
        this.analyzeHistogram(sharpImage, metadata),
        this.analyzeExposure(sharpImage, metadata),
        this.analyzeFocus(sharpImage, metadata),
        this.analyzeNoise(sharpImage, metadata),
        this.analyzeColorBalance(sharpImage, metadata)
      ]);

      const processingTime = Date.now() - startTime;
      
      const analysis = {
        timestamp: Date.now(),
        processingTime,
        imageMetadata: {
          width: metadata.width,
          height: metadata.height,
          format: metadata.format,
          colorSpace: metadata.space,
          hasAlpha: metadata.hasAlpha
        },
        histogram: histogramAnalysis,
        exposure: exposureAnalysis,
        focus: focusAnalysis,
        noise: noiseAnalysis,
        color: colorAnalysis,
        overallQuality: this.calculateOverallQuality({
          exposure: exposureAnalysis,
          focus: focusAnalysis,
          noise: noiseAnalysis
        }),
        confidence: this.calculateConfidence({
          histogram: histogramAnalysis,
          exposure: exposureAnalysis,
          focus: focusAnalysis
        })
      };

      logger.debug(`Image analysis completed in ${processingTime}ms`);
      return analysis;

    } catch (error) {
      logger.error('Advanced image analysis failed:', error);
      return this.getFallbackAnalysis();
    }
  }

  async analyzeHistogram(sharpImage, metadata) {
    try {
      // Optimize: Use smaller image for histogram calculation if image is too large
      const { width, height } = metadata;
      const shouldDownsample = width * height > 2000000; // 2MP threshold
      
      const processingImage = shouldDownsample 
        ? sharpImage.resize(Math.min(1000, Math.floor(width / 2)), Math.min(1000, Math.floor(height / 2)), { 
            kernel: sharp.kernel.nearest,
            fastShrinkOnLoad: false 
          })
        : sharpImage;
        
      const { data } = await processingImage
        .raw()
        .toBuffer({ resolveWithObject: true });

      const channels = metadata.channels || 3;
      const pixelCount = data.length / channels;
      
      // Use typed arrays for better performance
      const histograms = {
        red: new Uint32Array(256),
        green: new Uint32Array(256),
        blue: new Uint32Array(256),
        luminance: new Uint32Array(256)
      };

      // Optimized histogram calculation with chunked processing
      const chunkSize = 3072; // Process in 1KB chunks
      for (let offset = 0; offset < data.length; offset += chunkSize) {
        const chunkEnd = Math.min(offset + chunkSize, data.length);
        
        for (let i = offset; i < chunkEnd; i += channels) {
          const r = data[i];
          const g = data[i + 1];
          const b = data[i + 2];
          
          histograms.red[r]++;
          histograms.green[g]++;
          histograms.blue[b]++;
          
          // Optimized luminance calculation with bit operations
          const luminance = ((r * 54 + g * 183 + b * 19) >> 8); // Approximation of ITU-R BT.709
          histograms.luminance[Math.min(255, luminance)]++;
        }
        
        // Yield control periodically for non-blocking processing
        if (offset % (chunkSize * 10) === 0) {
          await new Promise(resolve => setImmediate(resolve));
        }
      }

      // Convert to normalized arrays only for return
      const normalizedHistograms = {
        red: Array.from(histograms.red).map(count => count / pixelCount),
        green: Array.from(histograms.green).map(count => count / pixelCount),
        blue: Array.from(histograms.blue).map(count => count / pixelCount),
        luminance: Array.from(histograms.luminance).map(count => count / pixelCount)
      };

      return {
        histograms: normalizedHistograms,
        statistics: this.calculateHistogramStatistics(normalizedHistograms),
        distribution: this.analyzeDistribution(normalizedHistograms.luminance)
      };

    } catch (error) {
      logger.error('Histogram analysis failed:', error);
      return this.getDefaultHistogram();
    }
  }

  async analyzeExposure(sharpImage, metadata) {
    try {
      // Convert to grayscale for exposure analysis
      const { data } = await sharpImage
        .greyscale()
        .raw()
        .toBuffer({ resolveWithObject: true });

      const pixelCount = data.length;
      let underexposed = 0;
      let overexposed = 0;
      let wellExposed = 0;
      let totalBrightness = 0;

      const { underexposed: underThreshold, overexposed: overThreshold, wellExposed } = 
        this.analysisConfig.exposureThresholds;

      for (let i = 0; i < pixelCount; i++) {
        const brightness = data[i] / 255;
        totalBrightness += brightness;

        if (brightness < underThreshold) {
          underexposed++;
        } else if (brightness > overThreshold) {
          overexposed++;
        } else if (brightness >= wellExposed.min && brightness <= wellExposed.max) {
          wellExposed++;
        }
      }

      const averageBrightness = totalBrightness / pixelCount;
      
      // Calculate dynamic range
      const sortedPixels = Array.from(data).sort((a, b) => a - b);
      const darkest = sortedPixels[Math.floor(pixelCount * 0.01)] / 255; // 1st percentile
      const brightest = sortedPixels[Math.floor(pixelCount * 0.99)] / 255; // 99th percentile
      const dynamicRange = brightest - darkest;

      return {
        averageBrightness,
        underexposed: underexposed / pixelCount,
        overexposed: overexposed / pixelCount,
        wellExposed: wellExposed / pixelCount,
        dynamicRange,
        clipping: {
          highlights: (data.filter(p => p >= 250).length) / pixelCount,
          shadows: (data.filter(p => p <= 5).length) / pixelCount
        },
        recommendation: this.generateExposureRecommendation(averageBrightness, {
          underexposed: underexposed / pixelCount,
          overexposed: overexposed / pixelCount
        })
      };

    } catch (error) {
      logger.error('Exposure analysis failed:', error);
      return this.getDefaultExposure();
    }
  }

  async analyzeFocus(sharpImage, metadata) {
    try {
      // Optimize: Downscale for focus analysis if image is large
      const { width, height } = metadata;
      const shouldDownsample = width * height > 1000000; // 1MP threshold
      
      const processingImage = shouldDownsample 
        ? sharpImage.resize(Math.min(800, Math.floor(width / 2)), Math.min(600, Math.floor(height / 2)), { 
            kernel: sharp.kernel.nearest,
            fastShrinkOnLoad: false 
          })
        : sharpImage;
      
      const { data } = await processingImage
        .greyscale()
        .raw()
        .toBuffer({ resolveWithObject: true });

      const actualWidth = shouldDownsample ? Math.min(800, Math.floor(width / 2)) : width;
      const actualHeight = shouldDownsample ? Math.min(600, Math.floor(height / 2)) : height;
      
      // Calculate focus regions (3x3 grid) with optimized processing
      const regionWidth = Math.floor(actualWidth / 3);
      const regionHeight = Math.floor(actualHeight / 3);
      const focusRegions = [];

      // Process regions in parallel for better performance
      const regionPromises = [];
      
      for (let row = 0; row < 3; row++) {
        for (let col = 0; col < 3; col++) {
          const startX = col * regionWidth;
          const startY = row * regionHeight;
          const endX = Math.min(startX + regionWidth, actualWidth);
          const endY = Math.min(startY + regionHeight, actualHeight);
          
          regionPromises.push(
            this.calculateRegionSharpnessOptimized(
              data, actualWidth, actualHeight, startX, startY, endX, endY
            ).then(sharpness => ({
              x: startX / actualWidth,
              y: startY / actualHeight,
              width: (endX - startX) / actualWidth,
              height: (endY - startY) / actualHeight,
              sharpness,
              confidence: Math.min(sharpness / 100, 1.0) // Normalize to 0-1
            }))
          );
        }
      }
      
      const calculatedRegions = await Promise.all(regionPromises);
      focusRegions.push(...calculatedRegions);

      // Find best focus region
      const bestFocusRegion = focusRegions.reduce((best, current) => 
        current.sharpness > best.sharpness ? current : best
      );

      const overallSharpness = focusRegions.reduce((sum, region) => 
        sum + region.sharpness, 0) / focusRegions.length;

      return {
        overallSharpness: overallSharpness / 100, // Normalize to 0-1
        focusRegions,
        bestFocusPoint: {
          x: bestFocusRegion.x + bestFocusRegion.width / 2,
          y: bestFocusRegion.y + bestFocusRegion.height / 2,
          confidence: bestFocusRegion.confidence
        },
        focusDistribution: this.analyzeFocusDistribution(focusRegions),
        recommendation: this.generateFocusRecommendation(overallSharpness, focusRegions)
      };

    } catch (error) {
      logger.error('Focus analysis failed:', error);
      return this.getDefaultFocus();
    }
  }

  async analyzeNoise(sharpImage, metadata) {
    try {
      // Analyze noise using local standard deviation
      const { data } = await sharpImage
        .greyscale()
        .raw()
        .toBuffer({ resolveWithObject: true });

      const width = metadata.width;
      const height = metadata.height;
      const windowSize = 5; // 5x5 window for noise analysis
      
      let totalVariance = 0;
      let sampleCount = 0;
      
      // Sample noise from multiple regions
      for (let y = windowSize; y < height - windowSize; y += windowSize * 2) {
        for (let x = windowSize; x < width - windowSize; x += windowSize * 2) {
          const variance = this.calculateLocalVariance(data, width, x, y, windowSize);
          totalVariance += variance;
          sampleCount++;
        }
      }

      const averageNoise = Math.sqrt(totalVariance / sampleCount) / 255; // Normalize to 0-1
      const noiseLevel = this.categorizeNoiseLevel(averageNoise);

      return {
        level: averageNoise,
        category: noiseLevel,
        distribution: 'uniform', // Simplified
        type: 'gaussian', // Simplified
        recommendation: this.generateNoiseRecommendation(averageNoise, noiseLevel)
      };

    } catch (error) {
      logger.error('Noise analysis failed:', error);
      return this.getDefaultNoise();
    }
  }

  async analyzeColorBalance(sharpImage, metadata) {
    try {
      const { data } = await sharpImage
        .raw()
        .toBuffer({ resolveWithObject: true });

      const channels = metadata.channels || 3;
      const pixelCount = data.length / channels;
      
      let rSum = 0, gSum = 0, bSum = 0;
      let rMax = 0, gMax = 0, bMax = 0;
      let rMin = 255, gMin = 255, bMin = 255;

      for (let i = 0; i < data.length; i += channels) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        
        rSum += r; gSum += g; bSum += b;
        rMax = Math.max(rMax, r); gMax = Math.max(gMax, g); bMax = Math.max(bMax, b);
        rMin = Math.min(rMin, r); gMin = Math.min(gMin, g); bMin = Math.min(bMin, b);
      }

      const averages = {
        red: rSum / pixelCount,
        green: gSum / pixelCount,
        blue: bSum / pixelCount
      };

      const colorCast = this.detectColorCast(averages);
      const saturation = this.calculateSaturation(data, channels);

      return {
        averages,
        ranges: {
          red: { min: rMin, max: rMax },
          green: { min: gMin, max: gMax },
          blue: { min: bMax, max: bMax }
        },
        colorCast,
        saturation,
        temperature: this.estimateColorTemperature(averages),
        recommendation: this.generateColorRecommendation(colorCast, saturation)
      };

    } catch (error) {
      logger.error('Color analysis failed:', error);
      return this.getDefaultColor();
    }
  }

  // Helper methods
  calculateRegionSharpness(data, width, height, startX, startY, endX, endY) {
    let sharpness = 0;
    let count = 0;

    // Apply Laplacian filter
    for (let y = startY + 1; y < endY - 1; y++) {
      for (let x = startX + 1; x < endX - 1; x++) {
        const idx = y * width + x;
        const laplacian = Math.abs(
          -4 * data[idx] + 
          data[idx - 1] + data[idx + 1] + 
          data[idx - width] + data[idx + width]
        );
        sharpness += laplacian;
        count++;
      }
    }

    return count > 0 ? sharpness / count : 0;
  }
  
  async calculateRegionSharpnessOptimized(data, width, height, startX, startY, endX, endY) {
    return new Promise((resolve) => {
      setImmediate(() => {
        let sharpness = 0;
        let count = 0;
        
        // Optimized Laplacian filter with sampling for large regions
        const sampleStep = Math.max(1, Math.floor((endX - startX) / 50)); // Sample every N pixels for large regions
        
        for (let y = startY + 1; y < endY - 1; y += sampleStep) {
          for (let x = startX + 1; x < endX - 1; x += sampleStep) {
            const idx = y * width + x;
            
            // Simplified Laplacian for speed (using only horizontal/vertical neighbors)
            const laplacian = Math.abs(
              -4 * data[idx] + 
              data[idx - 1] + data[idx + 1] + 
              data[idx - width] + data[idx + width]
            );
            
            sharpness += laplacian;
            count++;
          }
        }
        
        resolve(count > 0 ? sharpness / count : 0);
      });
    });
  }

  calculateLocalVariance(data, width, x, y, windowSize) {
    const halfWindow = Math.floor(windowSize / 2);
    let sum = 0;
    let sumSquares = 0;
    let count = 0;

    for (let dy = -halfWindow; dy <= halfWindow; dy++) {
      for (let dx = -halfWindow; dx <= halfWindow; dx++) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < width && ny < data.length / width) {
          const value = data[ny * width + nx];
          sum += value;
          sumSquares += value * value;
          count++;
        }
      }
    }

    const mean = sum / count;
    const variance = (sumSquares / count) - (mean * mean);
    return variance;
  }

  calculateHistogramStatistics(histograms) {
    const stats = {};
    
    Object.keys(histograms).forEach(channel => {
      const hist = histograms[channel];
      let mean = 0;
      let variance = 0;
      
      // Calculate mean
      hist.forEach((value, index) => {
        mean += value * index;
      });
      
      // Calculate variance
      hist.forEach((value, index) => {
        variance += value * Math.pow(index - mean, 2);
      });
      
      stats[channel] = {
        mean: mean / 255, // Normalize to 0-1
        variance: variance / (255 * 255),
        stdDev: Math.sqrt(variance) / 255
      };
    });
    
    return stats;
  }

  analyzeDistribution(luminanceHist) {
    const total = luminanceHist.reduce((sum, val) => sum + val, 0);
    const shadows = luminanceHist.slice(0, 85).reduce((sum, val) => sum + val, 0) / total;
    const midtones = luminanceHist.slice(85, 170).reduce((sum, val) => sum + val, 0) / total;
    const highlights = luminanceHist.slice(170, 256).reduce((sum, val) => sum + val, 0) / total;
    
    return {
      shadows,
      midtones,
      highlights,
      balance: this.categorizeDistribution({ shadows, midtones, highlights })
    };
  }

  generateExposureRecommendation(brightness, exposure) {
    if (exposure.underexposed > 0.3) {
      return { type: 'increase_exposure', priority: 'high', message: 'Image is significantly underexposed' };
    } else if (exposure.overexposed > 0.2) {
      return { type: 'decrease_exposure', priority: 'high', message: 'Image has significant overexposure' };
    } else if (brightness < 0.3) {
      return { type: 'increase_exposure', priority: 'medium', message: 'Consider increasing exposure slightly' };
    } else if (brightness > 0.7) {
      return { type: 'decrease_exposure', priority: 'medium', message: 'Consider decreasing exposure slightly' };
    }
    return { type: 'maintain', priority: 'low', message: 'Exposure looks good' };
  }

  categorizeNoiseLevel(noiseValue) {
    const { low, medium, high } = this.analysisConfig.noiseThresholds;
    if (noiseValue < low) return 'low';
    if (noiseValue < medium) return 'medium';
    if (noiseValue < high) return 'high';
    return 'very_high';
  }

  calculateOverallQuality({ exposure, focus, noise }) {
    const exposureScore = 1 - (exposure.underexposed + exposure.overexposed);
    const focusScore = focus.overallSharpness;
    const noiseScore = 1 - Math.min(noise.level * 2, 1); // Penalty for noise
    
    return {
      overall: (exposureScore * 0.4 + focusScore * 0.4 + noiseScore * 0.2),
      breakdown: {
        exposure: exposureScore,
        focus: focusScore,
        noise: noiseScore
      }
    };
  }

  calculateConfidence({ histogram, exposure, focus }) {
    let confidence = 0.5; // Base confidence
    
    // Increase confidence based on histogram distribution
    if (histogram.distribution.balance === 'balanced') {
      confidence += 0.2;
    }
    
    // Increase confidence based on exposure quality
    if (exposure.wellExposed > 0.7) {
      confidence += 0.2;
    }
    
    // Increase confidence based on focus quality
    if (focus.overallSharpness > 0.7) {
      confidence += 0.1;
    }
    
    return Math.min(confidence, 1.0);
  }

  // Fallback methods
  getFallbackAnalysis() {
    return {
      timestamp: Date.now(),
      processingTime: 0,
      confidence: 0.3,
      histogram: this.getDefaultHistogram(),
      exposure: this.getDefaultExposure(),
      focus: this.getDefaultFocus(),
      noise: this.getDefaultNoise(),
      color: this.getDefaultColor(),
      overallQuality: { overall: 0.5, breakdown: { exposure: 0.5, focus: 0.5, noise: 0.5 } }
    };
  }

  getDefaultHistogram() {
    return {
      histograms: {
        red: new Array(256).fill(1/256),
        green: new Array(256).fill(1/256),
        blue: new Array(256).fill(1/256),
        luminance: new Array(256).fill(1/256)
      },
      statistics: {
        red: { mean: 0.5, variance: 0.1, stdDev: 0.3 },
        green: { mean: 0.5, variance: 0.1, stdDev: 0.3 },
        blue: { mean: 0.5, variance: 0.1, stdDev: 0.3 },
        luminance: { mean: 0.5, variance: 0.1, stdDev: 0.3 }
      },
      distribution: { shadows: 0.33, midtones: 0.34, highlights: 0.33, balance: 'balanced' }
    };
  }

  getDefaultExposure() {
    return {
      averageBrightness: 0.5,
      underexposed: 0.1,
      overexposed: 0.1,
      wellExposed: 0.8,
      dynamicRange: 0.8,
      clipping: { highlights: 0.02, shadows: 0.03 },
      recommendation: { type: 'maintain', priority: 'low', message: 'Exposure analysis unavailable' }
    };
  }

  getDefaultFocus() {
    return {
      overallSharpness: 0.7,
      focusRegions: [],
      bestFocusPoint: { x: 0.5, y: 0.5, confidence: 0.5 },
      recommendation: { type: 'maintain', priority: 'low', message: 'Focus analysis unavailable' }
    };
  }

  getDefaultNoise() {
    return {
      level: 0.15,
      category: 'medium',
      distribution: 'uniform',
      type: 'gaussian',
      recommendation: { type: 'maintain', priority: 'low', message: 'Noise analysis unavailable' }
    };
  }

  getDefaultColor() {
    return {
      averages: { red: 128, green: 128, blue: 128 },
      ranges: { red: { min: 0, max: 255 }, green: { min: 0, max: 255 }, blue: { min: 0, max: 255 } },
      colorCast: { type: 'neutral', strength: 0 },
      saturation: 0.5,
      temperature: 5500,
      recommendation: { type: 'maintain', priority: 'low', message: 'Color analysis unavailable' }
    };
  }

  // Additional helper methods for color analysis
  detectColorCast(averages) {
    const { red, green, blue } = averages;
    const max = Math.max(red, green, blue);
    const min = Math.min(red, green, blue);
    
    if (max - min < 10) {
      return { type: 'neutral', strength: 0 };
    }
    
    if (red > green && red > blue) {
      return { type: 'warm', strength: (red - Math.max(green, blue)) / 255 };
    } else if (blue > red && blue > green) {
      return { type: 'cool', strength: (blue - Math.max(red, green)) / 255 };
    } else if (green > red && green > blue) {
      return { type: 'green', strength: (green - Math.max(red, blue)) / 255 };
    }
    
    return { type: 'neutral', strength: 0 };
  }

  calculateSaturation(data, channels) {
    let totalSaturation = 0;
    const pixelCount = data.length / channels;
    
    for (let i = 0; i < data.length; i += channels) {
      const r = data[i] / 255;
      const g = data[i + 1] / 255;
      const b = data[i + 2] / 255;
      
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const saturation = max === 0 ? 0 : (max - min) / max;
      
      totalSaturation += saturation;
    }
    
    return totalSaturation / pixelCount;
  }

  estimateColorTemperature(averages) {
    // Simplified color temperature estimation
    const ratio = averages.blue / averages.red;
    
    if (ratio > 1.2) return 6500; // Cool/daylight
    if (ratio > 1.0) return 5500; // Neutral
    if (ratio > 0.8) return 4500; // Warm
    return 3500; // Very warm/tungsten
  }

  categorizeDistribution({ shadows, midtones, highlights }) {
    if (Math.abs(shadows - 0.33) < 0.1 && Math.abs(midtones - 0.34) < 0.1 && Math.abs(highlights - 0.33) < 0.1) {
      return 'balanced';
    } else if (shadows > 0.5) {
      return 'shadows_heavy';
    } else if (highlights > 0.5) {
      return 'highlights_heavy';
    } else if (midtones > 0.5) {
      return 'midtones_heavy';
    }
    return 'unbalanced';
  }

  analyzeFocusDistribution(focusRegions) {
    const sharpnessValues = focusRegions.map(r => r.sharpness);
    const avg = sharpnessValues.reduce((sum, val) => sum + val, 0) / sharpnessValues.length;
    const variance = sharpnessValues.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / sharpnessValues.length;
    
    return {
      average: avg,
      variance,
      uniformity: variance < 100 ? 'uniform' : 'varied'
    };
  }

  generateFocusRecommendation(overallSharpness, focusRegions) {
    if (overallSharpness < 30) {
      return { type: 'refocus', priority: 'high', message: 'Image appears out of focus' };
    } else if (overallSharpness < 50) {
      return { type: 'improve_focus', priority: 'medium', message: 'Focus could be improved' };
    }
    return { type: 'maintain', priority: 'low', message: 'Focus looks good' };
  }

  generateNoiseRecommendation(noiseLevel, category) {
    if (category === 'very_high' || category === 'high') {
      return { type: 'reduce_iso', priority: 'high', message: 'Significant noise detected, consider lower ISO' };
    } else if (category === 'medium') {
      return { type: 'monitor_iso', priority: 'medium', message: 'Moderate noise, watch ISO settings' };
    }
    return { type: 'maintain', priority: 'low', message: 'Noise levels acceptable' };
  }

  generateColorRecommendation(colorCast, saturation) {
    if (colorCast.strength > 0.3) {
      return { type: 'adjust_wb', priority: 'medium', message: `${colorCast.type} color cast detected` };
    } else if (saturation < 0.2) {
      return { type: 'increase_saturation', priority: 'low', message: 'Image appears undersaturated' };
    } else if (saturation > 0.8) {
      return { type: 'decrease_saturation', priority: 'low', message: 'Image appears oversaturated' };
    }
    return { type: 'maintain', priority: 'low', message: 'Color balance looks good' };
  }
}

module.exports = AdvancedImageAnalyzer;