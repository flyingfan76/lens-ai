const EventEmitter = require('events');
const logger = require('../utils/logger');

class BrandSpecificOptimizer extends EventEmitter {
  constructor() {
    super();
    
    // Brand-specific optimization profiles
    this.brandOptimizers = {
      canon: new CanonOptimizer(),
      nikon: new NikonOptimizer(),
      sony: new SonyOptimizer(),
      fujifilm: new FujifilmOptimizer(),
      olympus: new OlympusOptimizer(),
      panasonic: new PanasonicOptimizer()
    };
    
    // Cross-brand optimization strategies
    this.optimizationStrategies = {
      portrait: {
        priority: ['subject_isolation', 'skin_tones', 'eye_focus'],
        fallback_settings: {
          aperture: 'f/2.8',
          focus_mode: 'Single',
          metering_mode: 'Spot'
        }
      },
      landscape: {
        priority: ['overall_sharpness', 'dynamic_range', 'color_accuracy'],
        fallback_settings: {
          aperture: 'f/8.0',
          focus_mode: 'Hyperfocal',
          metering_mode: 'Matrix'
        }
      },
      sports: {
        priority: ['tracking_speed', 'burst_rate', 'low_light_performance'],
        fallback_settings: {
          shutter_speed: '1/500',
          focus_mode: 'Continuous',
          drive_mode: 'Continuous High'
        }
      },
      macro: {
        priority: ['detail_resolution', 'focus_precision', 'stability'],
        fallback_settings: {
          aperture: 'f/5.6',
          focus_mode: 'Manual',
          image_stabilization: 'On'
        }
      },
      low_light: {
        priority: ['noise_performance', 'stabilization', 'focus_accuracy'],
        fallback_settings: {
          iso: '1600',
          aperture: 'f/2.8',
          image_stabilization: 'On'
        }
      }
    };
    
    // Brand performance characteristics database
    this.brandCharacteristics = {
      canon: {
        strengths: ['color_science', 'dual_pixel_af', 'ergonomics', 'lens_ecosystem'],
        iso_performance: { sweet_spot: [100, 800], usable_max: 6400, native: 100 },
        af_performance: { speed: 'excellent', tracking: 'excellent', low_light: 'very_good' },
        color_profiles: ['Standard', 'Portrait', 'Landscape', 'Neutral', 'Faithful', 'Monochrome'],
        special_features: ['dual_pixel_raw', 'focus_guide', 'highlight_tone_priority']
      },
      nikon: {
        strengths: ['dynamic_range', 'build_quality', 'ergonomics', 'matrix_metering'],
        iso_performance: { sweet_spot: [64, 800], usable_max: 3200, native: 64 },
        af_performance: { speed: 'very_good', tracking: 'excellent', low_light: 'excellent' },
        color_profiles: ['Standard', 'Neutral', 'Vivid', 'Monochrome', 'Portrait', 'Landscape'],
        special_features: ['active_d_lighting', 'picture_control', 'matrix_metering_3d']
      },
      sony: {
        strengths: ['eye_af', 'video_features', 'ibis', 'silent_shooting'],
        iso_performance: { sweet_spot: [100, 1600], usable_max: 12800, native: 100 },
        af_performance: { speed: 'excellent', tracking: 'outstanding', low_light: 'excellent' },
        color_profiles: ['Standard', 'Vivid', 'Neutral', 'Clear', 'Deep', 'Light', 'Portrait'],
        special_features: ['real_time_eye_af', 'animal_eye_af', 'real_time_tracking', 'silent_shooting']
      },
      fujifilm: {
        strengths: ['film_simulation', 'color_science', 'build_quality', 'creative_controls'],
        iso_performance: { sweet_spot: [160, 1600], usable_max: 6400, native: 160 },
        af_performance: { speed: 'good', tracking: 'good', low_light: 'good' },
        color_profiles: ['Provia', 'Velvia', 'Astia', 'Classic Chrome', 'Pro Neg.', 'Acros', 'Eterna'],
        special_features: ['film_simulation', 'grain_effect', 'color_chrome_effect', 'highlight_shadow']
      },
      olympus: {
        strengths: ['ibis', 'weather_sealing', 'computational_photography', 'handheld_high_res'],
        iso_performance: { sweet_spot: [200, 800], usable_max: 3200, native: 200 },
        af_performance: { speed: 'very_good', tracking: 'good', low_light: 'good' },
        color_profiles: ['Natural', 'Vivid', 'Muted', 'Portrait', 'Monotone', 'Custom'],
        special_features: ['handheld_high_res', 'live_composite', 'focus_stacking', 'pro_capture']
      },
      panasonic: {
        strengths: ['video_features', 'ibis', 'weather_sealing', '6k_photo'],
        iso_performance: { sweet_spot: [200, 1600], usable_max: 6400, native: 200 },
        af_performance: { speed: 'good', tracking: 'very_good', low_light: 'good' },
        color_profiles: ['Standard', 'Vivid', 'Natural', 'Monochrome', 'Scenery', 'Portrait'],
        special_features: ['6k_photo', 'focus_stacking', 'light_composition', 'dual_native_iso']
      }
    };
  }

  async optimizeForBrand(brand, scene_analysis, current_settings, user_preferences = {}) {
    try {
      logger.info(`Optimizing camera settings for ${brand} based on scene analysis`);
      
      const brandOptimizer = this.brandOptimizers[brand.toLowerCase()];
      if (!brandOptimizer) {
        logger.warn(`No specific optimizer for brand: ${brand}, using generic optimization`);
        return this.genericOptimization(scene_analysis, current_settings, user_preferences);
      }
      
      // Get brand characteristics
      const characteristics = this.brandCharacteristics[brand.toLowerCase()];
      
      // Determine scene type and strategy
      const scene_type = this.determineSceneType(scene_analysis);
      const strategy = this.optimizationStrategies[scene_type];
      
      // Perform brand-specific optimization
      const optimized_settings = await brandOptimizer.optimize({
        scene_analysis,
        current_settings,
        strategy,
        characteristics,
        user_preferences
      });
      
      // Apply cross-brand validation
      const validated_settings = this.validateSettings(optimized_settings, characteristics);
      
      // Generate explanation
      const explanation = this.generateOptimizationExplanation(
        brand, scene_type, optimized_settings, current_settings
      );
      
      return {
        success: true,
        brand,
        scene_type,
        optimized_settings: validated_settings,
        current_settings,
        changes_made: this.calculateChanges(current_settings, validated_settings),
        explanation,
        confidence: this.calculateConfidence(scene_analysis, brand),
        brand_specific_features: this.getBrandSpecificRecommendations(brand, scene_type)
      };
      
    } catch (error) {
      logger.error(`Brand-specific optimization failed for ${brand}:`, error);
      throw error;
    }
  }

  determineSceneType(scene_analysis) {
    // Determine scene type from analysis
    if (scene_analysis.has_faces && scene_analysis.face_count > 0) {
      return 'portrait';
    }
    
    if (scene_analysis.scene_type === 'landscape') {
      return 'landscape';
    }
    
    if (scene_analysis.motion_detected || 
        scene_analysis.scene_type === 'sports' || 
        scene_analysis.focusAnalysis?.tracking_required) {
      return 'sports';
    }
    
    if (scene_analysis.scene_type === 'macro' || 
        scene_analysis.focusAnalysis?.close_subject) {
      return 'macro';
    }
    
    if (scene_analysis.lighting_condition === 'dim' || 
        scene_analysis.lighting_condition === 'very_dark' ||
        scene_analysis.brightness_level < 0.3) {
      return 'low_light';
    }
    
    return 'general';
  }

  validateSettings(settings, characteristics) {
    const validated = { ...settings };
    
    // Validate ISO against brand characteristics
    if (validated.iso && validated.iso !== 'AUTO') {
      const iso_num = parseInt(validated.iso);
      const max_usable = characteristics.iso_performance.usable_max;
      
      if (iso_num > max_usable) {
        validated.iso = max_usable.toString();
        logger.info(`ISO clamped to brand maximum: ${max_usable}`);
      }
    }
    
    return validated;
  }

  calculateChanges(current, optimized) {
    const changes = {};
    
    for (const [key, value] of Object.entries(optimized)) {
      if (current[key] !== value) {
        changes[key] = {
          from: current[key],
          to: value,
          reason: this.getChangeReason(key, current[key], value)
        };
      }
    }
    
    return changes;
  }

  getChangeReason(setting, from, to) {
    const reasons = {
      iso: `Optimized ISO from ${from} to ${to} for better noise performance`,
      aperture: `Adjusted aperture from ${from} to ${to} for optimal depth of field`,
      shutter_speed: `Changed shutter speed from ${from} to ${to} for motion control`,
      focus_mode: `Switched focus mode from ${from} to ${to} for better subject tracking`,
      metering_mode: `Updated metering from ${from} to ${to} for accurate exposure`
    };
    
    return reasons[setting] || `Changed ${setting} from ${from} to ${to}`;
  }

  calculateConfidence(scene_analysis, brand) {
    let confidence = 0.7; // Base confidence
    
    // Increase confidence based on scene analysis quality
    if (scene_analysis.confidence && scene_analysis.confidence > 0.8) {
      confidence += 0.15;
    }
    
    // Brand-specific confidence adjustments
    const brandCharacteristics = this.brandCharacteristics[brand.toLowerCase()];
    if (brandCharacteristics) {
      confidence += 0.1;
    }
    
    return Math.min(0.95, confidence);
  }

  getBrandSpecificRecommendations(brand, scene_type) {
    const characteristics = this.brandCharacteristics[brand.toLowerCase()];
    if (!characteristics) return [];
    
    const recommendations = [];
    
    // Add brand-specific feature recommendations
    for (const feature of characteristics.special_features) {
      const recommendation = this.getFeatureRecommendation(feature, scene_type, brand);
      if (recommendation) {
        recommendations.push(recommendation);
      }
    }
    
    return recommendations;
  }

  getFeatureRecommendation(feature, scene_type, brand) {
    const recommendations = {
      canon: {
        dual_pixel_raw: {
          portrait: 'Enable Dual Pixel RAW for advanced post-processing control',
          macro: 'Use Dual Pixel RAW for micro-adjustment capabilities'
        },
        highlight_tone_priority: {
          landscape: 'Enable Highlight Tone Priority to preserve highlight detail',
          general: 'Consider Highlight Tone Priority for high contrast scenes'
        }
      },
      nikon: {
        active_d_lighting: {
          landscape: 'Enable Active D-Lighting for better shadow/highlight balance',
          portrait: 'Use Active D-Lighting to preserve facial details in harsh light'
        },
        matrix_metering_3d: {
          general: 'Use 3D Matrix Metering for accurate exposure in complex lighting'
        }
      },
      sony: {
        real_time_eye_af: {
          portrait: 'Enable Real-time Eye AF for perfect portrait focus',
          sports: 'Use Real-time Eye AF for athlete portraits'
        },
        animal_eye_af: {
          sports: 'Enable Animal Eye AF when photographing pets or wildlife'
        },
        silent_shooting: {
          portrait: 'Consider Silent Shooting for candid portraits',
          macro: 'Use Silent Shooting to avoid camera shake in macro work'
        }
      },
      fujifilm: {
        film_simulation: {
          portrait: 'Try Classic Chrome or Portrait film simulation',
          landscape: 'Consider Velvia for vibrant landscape colors',
          general: 'Experiment with film simulations for creative looks'
        },
        grain_effect: {
          portrait: 'Add subtle grain for film-like portrait aesthetic',
          general: 'Use grain effect sparingly for artistic appeal'
        }
      },
      olympus: {
        handheld_high_res: {
          landscape: 'Use Handheld High Res mode for maximum detail',
          macro: 'Enable High Res mode for ultra-detailed macro shots'
        },
        live_composite: {
          low_light: 'Try Live Composite for creative long exposure effects'
        }
      },
      panasonic: {
        '6k_photo': {
          sports: 'Use 6K Photo mode to capture decisive moments',
          macro: 'Try 6K Photo for perfect timing in macro photography'
        },
        focus_stacking: {
          macro: 'Enable Focus Stacking for extended depth of field'
        }
      }
    };
    
    const brandRecs = recommendations[brand];
    if (!brandRecs || !brandRecs[feature]) return null;
    
    const sceneRecs = brandRecs[feature];
    return sceneRecs[scene_type] || sceneRecs.general || null;
  }

  generateOptimizationExplanation(brand, scene_type, optimized, current) {
    const brandName = brand.charAt(0).toUpperCase() + brand.slice(1);
    const characteristics = this.brandCharacteristics[brand.toLowerCase()];
    
    let explanation = `Optimized settings for ${brandName} camera based on ${scene_type} scene detection. `;
    
    if (characteristics) {
      explanation += `This optimization leverages ${brandName}'s strengths in ${characteristics.strengths.join(', ')}. `;
    }
    
    const changes = this.calculateChanges(current, optimized);
    const changeCount = Object.keys(changes).length;
    
    if (changeCount > 0) {
      explanation += `Made ${changeCount} setting adjustments for optimal image quality.`;
    } else {
      explanation += `Current settings are already well-optimized for this scene.`;
    }
    
    return explanation;
  }

  genericOptimization(scene_analysis, current_settings, user_preferences) {
    // Generic optimization for unsupported brands
    const scene_type = this.determineSceneType(scene_analysis);
    const strategy = this.optimizationStrategies[scene_type];
    
    return {
      success: true,
      brand: 'generic',
      scene_type,
      optimized_settings: {
        ...current_settings,
        ...strategy.fallback_settings
      },
      explanation: `Applied generic optimization for ${scene_type} scene`,
      confidence: 0.6
    };
  }
}

// Brand-specific optimizer classes
class CanonOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Canon-specific ISO optimization
    if (scene_analysis.lighting_condition === 'dim') {
      // Canon performs well up to ISO 1600-3200
      optimized.iso = this.optimizeCanonISO(scene_analysis, characteristics);
    }
    
    // Leverage Dual Pixel AF
    if (scene_analysis.has_faces || scene_analysis.scene_type === 'portrait') {
      optimized.focus_mode = 'Single';
      optimized.af_area_mode = 'Zone AF'; // Canon's strength
    }
    
    // Canon color science optimization
    if (scene_analysis.scene_type === 'portrait') {
      optimized.picture_style = 'Portrait';
      optimized.highlight_tone_priority = 'Enable';
    } else if (scene_analysis.scene_type === 'landscape') {
      optimized.picture_style = 'Landscape';
    }
    
    // Metering optimization for Canon's excellent metering system
    optimized.metering_mode = 'Evaluative'; // Canon's matrix metering
    
    return optimized;
  }
  
  optimizeCanonISO(scene_analysis, characteristics) {
    const brightness = scene_analysis.brightness_level || 0.5;
    
    if (brightness < 0.2) return '1600'; // Canon's sweet spot for low light
    if (brightness < 0.4) return '800';
    if (brightness < 0.6) return '400';
    return '200';
  }
}

class NikonOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Nikon's excellent dynamic range optimization
    optimized.active_d_lighting = 'Auto';
    
    // Leverage Nikon's superior low-light AF
    if (scene_analysis.lighting_condition === 'dim') {
      optimized.iso = this.optimizeNikonISO(scene_analysis);
      optimized.focus_mode = 'AF-S'; // Single-servo AF
      optimized.af_area_mode = 'Single-point AF';
    }
    
    // Nikon's 3D Matrix Metering advantage
    optimized.metering_mode = '3D Matrix';
    
    // Picture Control optimization
    if (scene_analysis.scene_type === 'portrait') {
      optimized.picture_control = 'Portrait';
    } else if (scene_analysis.scene_type === 'landscape') {
      optimized.picture_control = 'Landscape';
      optimized.active_d_lighting = 'Strong'; // Better shadow recovery
    }
    
    return optimized;
  }
  
  optimizeNikonISO(scene_analysis) {
    // Nikon's base ISO is typically 64, with excellent performance up to 800-1600
    const brightness = scene_analysis.brightness_level || 0.5;
    
    if (brightness < 0.2) return '1250'; // Nikon's strength in low light
    if (brightness < 0.4) return '640';
    if (brightness < 0.6) return '320';
    return '200';
  }
}

class SonyOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Sony's Eye AF advantage
    if (scene_analysis.has_faces) {
      optimized.focus_mode = 'AF-S';
      optimized.focus_area = 'Wide';
      optimized.eye_af = 'On';
      optimized.eye_af_priority = 'On';
    }
    
    // Sony's excellent high ISO performance
    if (scene_analysis.lighting_condition === 'dim') {
      optimized.iso = this.optimizeSonyISO(scene_analysis);
      optimized.noise_reduction = 'Normal'; // Sony's good NR
    }
    
    // Silent shooting advantage
    if (scene_analysis.scene_type === 'portrait' && user_preferences.silent_preferred) {
      optimized.shutter_type = 'Electronic';
      optimized.silent_shooting = 'On';
    }
    
    // Sony's Real-time Tracking
    if (scene_analysis.motion_detected) {
      optimized.focus_mode = 'AF-C';
      optimized.focus_area = 'Tracking Wide';
      optimized.real_time_tracking = 'On';
    }
    
    return optimized;
  }
  
  optimizeSonyISO(scene_analysis) {
    // Sony's excellent high ISO performance
    const brightness = scene_analysis.brightness_level || 0.5;
    
    if (brightness < 0.15) return '3200'; // Sony can handle higher ISOs well
    if (brightness < 0.3) return '1600';
    if (brightness < 0.5) return '800';
    return '400';
  }
}

class FujifilmOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Fujifilm's Film Simulation strength
    optimized.film_simulation = this.selectFilmSimulation(scene_analysis);
    
    // Fujifilm's color science optimization
    if (scene_analysis.scene_type === 'portrait') {
      optimized.color_chrome_effect = 'Weak';
      optimized.highlight_tone = '+1';
      optimized.shadow_tone = '+1';
    }
    
    // ISO optimization for Fujifilm's sensor characteristics
    if (scene_analysis.lighting_condition === 'dim') {
      optimized.iso = this.optimizeFujifilmISO(scene_analysis);
      optimized.noise_reduction = 'Standard';
    }
    
    // Fujifilm's unique grain effect
    if (user_preferences.artistic_preference === 'film_like') {
      optimized.grain_effect = 'Weak';
    }
    
    return optimized;
  }
  
  selectFilmSimulation(scene_analysis) {
    if (scene_analysis.scene_type === 'portrait') {
      return 'Classic Chrome'; // Excellent for skin tones
    } else if (scene_analysis.scene_type === 'landscape') {
      return 'Velvia'; // Vibrant colors for landscapes
    } else if (scene_analysis.lighting_condition === 'dim') {
      return 'Pro Neg. Hi'; // Better for low light
    }
    return 'Provia'; // Standard, versatile choice
  }
  
  optimizeFujifilmISO(scene_analysis) {
    // Fujifilm's ISO performance characteristics
    const brightness = scene_analysis.brightness_level || 0.5;
    
    if (brightness < 0.2) return '1250';
    if (brightness < 0.4) return '640';
    if (brightness < 0.6) return '400';
    return '200';
  }
}

class OlympusOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Olympus IBIS advantage
    optimized.image_stabilization = 'On';
    optimized.is_mode = 'Auto'; // Let Olympus decide the best IS mode
    
    // Computational photography features
    if (scene_analysis.scene_type === 'landscape' && user_preferences.max_quality) {
      optimized.handheld_high_res = 'On'; // 50MP mode
    }
    
    // Olympus Live Composite for long exposures
    if (scene_analysis.lighting_condition === 'very_dark' && 
        user_preferences.creative_mode) {
      optimized.shooting_mode = 'Live Composite';
    }
    
    // Focus stacking for macro
    if (scene_analysis.scene_type === 'macro') {
      optimized.focus_stacking = 'On';
      optimized.focus_stacking_steps = '8'; // Good balance
    }
    
    return optimized;
  }
}

class PanasonicOptimizer {
  async optimize({ scene_analysis, current_settings, strategy, characteristics, user_preferences }) {
    const optimized = { ...current_settings };
    
    // Panasonic's dual native ISO advantage
    if (scene_analysis.lighting_condition === 'dim') {
      optimized.iso = this.optimizePanasonicISO(scene_analysis);
      optimized.dual_native_iso = 'On';
    }
    
    // 6K Photo mode for decisive moments
    if (scene_analysis.motion_detected || scene_analysis.scene_type === 'sports') {
      optimized.burst_mode = '6K Photo';
      optimized.burst_rate = '30fps';
    }
    
    // IBIS optimization
    optimized.image_stabilization = 'On';
    if (scene_analysis.scene_type === 'video' || user_preferences.video_priority) {
      optimized.is_mode = 'Operation'; // Video-optimized IS
    }
    
    return optimized;
  }
  
  optimizePanasonicISO(scene_analysis) {
    // Panasonic dual native ISO: typically 200 and 800/1000
    const brightness = scene_analysis.brightness_level || 0.5;
    
    if (brightness < 0.3) return '800'; // Second native ISO
    return '200'; // First native ISO
  }
}

module.exports = BrandSpecificOptimizer;