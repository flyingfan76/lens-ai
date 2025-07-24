const StylePreset = require('../models/StylePreset');
const logger = require('../utils/logger');

class StylePresetService {
  constructor() {
    this.builtInPresets = [
      {
        id: 'creamy_portrait',
        name: 'Creamy Portrait',
        description: 'Soft, dreamy look perfect for portraits with beautiful bokeh',
        category: 'portrait',
        type: 'built_in',
        settings: {
          iso: 200,
          aperture: 'f/2.8',
          shutterSpeed: '1/160',
          whiteBalance: {
            mode: 'daylight',
            kelvin: 5500,
            shift: {
              magentaGreen: 1,
              blueAmber: 0
            },
            autoWBBias: {
              enabled: false,
              amber: 0,
              magenta: 0
            },
            priority: 'standard'
          },
          exposureCompensation: '+0.3',
          focusMode: 'single',
          meteringMode: 'spot',
          colorProfile: 'portrait'
        },
        thumbnail: '/assets/presets/creamy_portrait.jpg',
        tags: ['portrait', 'bokeh', 'soft', 'dreamy'],
        sceneTypes: ['portrait'],
        lightingConditions: ['normal', 'bright'],
        compatibility: {
          cameras: [
            { brand: 'canon', models: ['EOS R5', 'EOS R6', '5D Mark IV'] },
            { brand: 'sony', models: ['A7R V', 'A7 IV', 'A6600'] },
            { brand: 'nikon', models: ['Z9', 'Z7II', 'D850'] }
          ]
        },
        metadata: {
          featured: true,
          difficulty: 'beginner'
        }
      },
      {
        id: 'vivid_landscape',
        name: 'Vivid Landscape',
        description: 'Enhanced colors and contrast perfect for dramatic landscapes',
        category: 'landscape',
        type: 'built_in',
        settings: {
          iso: 100,
          aperture: 'f/8.0',
          shutterSpeed: '1/60',
          whiteBalance: {
            mode: 'daylight',
            kelvin: 5500,
            shift: {
              magentaGreen: 0,
              blueAmber: 1
            },
            autoWBBias: {
              enabled: false,
              amber: 0,
              magenta: 0
            },
            priority: 'atmosphere_priority'
          },
          exposureCompensation: '0.0',
          focusMode: 'hyperfocal',
          meteringMode: 'matrix',
          colorProfile: 'vivid'
        },
        thumbnail: '/assets/presets/vivid_landscape.jpg',
        tags: ['landscape', 'vivid', 'contrast', 'nature'],
        sceneTypes: ['landscape', 'nature'],
        lightingConditions: ['bright', 'normal'],
        compatibility: {
          cameras: [
            { brand: 'canon', models: [] },
            { brand: 'sony', models: [] },
            { brand: 'nikon', models: [] }
          ]
        },
        metadata: {
          featured: true,
          difficulty: 'beginner'
        }
      },
      {
        id: 'golden_hour',
        name: 'Golden Hour',
        description: 'Warm, soft lighting perfect for magic hour photography',
        category: 'creative',
        type: 'built_in',
        settings: {
          iso: 400,
          aperture: 'f/4.0',
          shutterSpeed: '1/125',
          whiteBalance: {
            mode: 'shade',
            kelvin: 7500,
            shift: {
              magentaGreen: -1,
              blueAmber: 3
            },
            autoWBBias: {
              enabled: true,
              amber: 2,
              magenta: 0
            },
            priority: 'atmosphere_priority'
          },
          exposureCompensation: '-0.3',
          focusMode: 'single',
          meteringMode: 'center',
          colorProfile: 'warm'
        },
        thumbnail: '/assets/presets/golden_hour.jpg',
        tags: ['golden_hour', 'warm', 'sunset', 'romantic'],
        sceneTypes: ['portrait', 'landscape', 'sunset'],
        lightingConditions: ['golden_hour', 'dim'],
        compatibility: {
          cameras: [
            { brand: 'canon', models: [] },
            { brand: 'sony', models: [] },
            { brand: 'nikon', models: [] }
          ]
        },
        metadata: {
          featured: true,
          difficulty: 'intermediate'
        }
      },
      {
        id: 'street_sharp',
        name: 'Street Sharp',
        description: 'High contrast, sharp details perfect for street photography',
        category: 'street',
        type: 'built_in',
        settings: {
          iso: 800,
          aperture: 'f/5.6',
          shutterSpeed: '1/250',
          whiteBalance: 'auto',
          exposureCompensation: '0.0',
          focusMode: 'continuous',
          meteringMode: 'matrix',
          colorProfile: 'monochrome'
        },
        thumbnail: '/assets/presets/street_sharp.jpg',
        tags: ['street', 'sharp', 'contrast', 'urban'],
        sceneTypes: ['street', 'architecture'],
        lightingConditions: ['normal', 'dim'],
        compatibility: {
          cameras: [
            { brand: 'canon', models: [] },
            { brand: 'sony', models: [] },
            { brand: 'nikon', models: [] }
          ]
        },
        metadata: {
          featured: true,
          difficulty: 'intermediate'
        }
      },
      {
        id: 'low_light_magic',
        name: 'Low Light Magic',
        description: 'Optimized settings for challenging low light conditions',
        category: 'low_light',
        type: 'built_in',
        settings: {
          iso: 1600,
          aperture: 'f/2.0',
          shutterSpeed: '1/80',
          whiteBalance: 'auto',
          exposureCompensation: '+0.7',
          focusMode: 'single',
          meteringMode: 'spot',
          colorProfile: 'standard'
        },
        thumbnail: '/assets/presets/low_light_magic.jpg',
        tags: ['low_light', 'night', 'available_light'],
        sceneTypes: ['low_light', 'portrait'],
        lightingConditions: ['very_dark', 'dim'],
        compatibility: {
          cameras: [
            { brand: 'canon', models: [] },
            { brand: 'sony', models: [] },
            { brand: 'nikon', models: [] }
          ]
        },
        metadata: {
          featured: true,
          difficulty: 'advanced'
        }
      }
    ];
  }

  async initializeBuiltInPresets() {
    try {
      logger.info('Initializing built-in style presets...');
      
      for (const preset of this.builtInPresets) {
        const existing = await StylePreset.findOne({ id: preset.id });
        
        if (!existing) {
          await StylePreset.create(preset);
          logger.info(`Created built-in preset: ${preset.name}`);
        } else {
          logger.debug(`Built-in preset already exists: ${preset.name}`);
        }
      }
      
      logger.info('Built-in presets initialization completed');
    } catch (error) {
      logger.error('Failed to initialize built-in presets:', error);
      throw error;
    }
  }

  async getAllPresets(filters = {}) {
    try {
      const query = { isActive: true };
      
      if (filters.category) {
        query.category = filters.category;
      }
      
      if (filters.type) {
        query.type = filters.type;
      }
      
      if (filters.sceneType) {
        query.sceneTypes = filters.sceneType;
      }
      
      if (filters.lightingCondition) {
        query.lightingConditions = filters.lightingCondition;
      }
      
      if (filters.difficulty) {
        query['metadata.difficulty'] = filters.difficulty;
      }
      
      if (filters.featured !== undefined) {
        query['metadata.featured'] = filters.featured;
      }
      
      const sortOptions = {};
      if (filters.sortBy === 'popularity') {
        sortOptions['metadata.usageCount'] = -1;
      } else if (filters.sortBy === 'rating') {
        sortOptions['metadata.rating.average'] = -1;
      } else {
        sortOptions.createdAt = -1;
      }
      
      const presets = await StylePreset.find(query)
        .sort(sortOptions)
        .limit(filters.limit || 50);
      
      return presets;
    } catch (error) {
      logger.error('Failed to get presets:', error);
      throw error;
    }
  }

  async getPresetById(presetId) {
    try {
      const preset = await StylePreset.findOne({ 
        id: presetId, 
        isActive: true 
      });
      
      if (!preset) {
        throw new Error(`Preset not found: ${presetId}`);
      }
      
      return preset;
    } catch (error) {
      logger.error(`Failed to get preset ${presetId}:`, error);
      throw error;
    }
  }

  async getRecommendedPresets(analysis, userPreferences = {}) {
    try {
      const recommendations = [];
      
      // Find presets matching scene type
      if (analysis.scene_type) {
        const scenePresets = await StylePreset.findByScene(analysis.scene_type);
        recommendations.push(...scenePresets.slice(0, 3));
      }
      
      // Find presets matching lighting condition
      if (analysis.lighting_condition) {
        const lightingPresets = await StylePreset.findByLighting(analysis.lighting_condition);
        recommendations.push(...lightingPresets.slice(0, 2));
      }
      
      // Add featured presets if not enough recommendations
      if (recommendations.length < 3) {
        const featuredPresets = await StylePreset.getFeatured();
        recommendations.push(...featuredPresets.slice(0, 3 - recommendations.length));
      }
      
      // Remove duplicates and sort by relevance
      const uniquePresets = this.removeDuplicatePresets(recommendations);
      const scoredPresets = this.scorePresetRelevance(uniquePresets, analysis, userPreferences);
      
      return scoredPresets.slice(0, 5);
    } catch (error) {
      logger.error('Failed to get recommended presets:', error);
      throw error;
    }
  }

  async createUserPreset(userId, presetData) {
    try {
      const preset = new StylePreset({
        ...presetData,
        type: 'user_created',
        metadata: {
          ...presetData.metadata,
          createdBy: userId
        }
      });
      
      await preset.save();
      logger.info(`User preset created: ${preset.name} by user ${userId}`);
      
      return preset;
    } catch (error) {
      logger.error('Failed to create user preset:', error);
      throw error;
    }
  }

  async updatePreset(presetId, updateData) {
    try {
      const preset = await StylePreset.findOneAndUpdate(
        { id: presetId },
        updateData,
        { new: true, runValidators: true }
      );
      
      if (!preset) {
        throw new Error(`Preset not found: ${presetId}`);
      }
      
      logger.info(`Preset updated: ${presetId}`);
      return preset;
    } catch (error) {
      logger.error(`Failed to update preset ${presetId}:`, error);
      throw error;
    }
  }

  async deletePreset(presetId) {
    try {
      const preset = await StylePreset.findOneAndUpdate(
        { id: presetId },
        { isActive: false },
        { new: true }
      );
      
      if (!preset) {
        throw new Error(`Preset not found: ${presetId}`);
      }
      
      logger.info(`Preset deleted: ${presetId}`);
      return preset;
    } catch (error) {
      logger.error(`Failed to delete preset ${presetId}:`, error);
      throw error;
    }
  }

  async incrementPresetUsage(presetId) {
    try {
      const preset = await this.getPresetById(presetId);
      await preset.incrementUsage();
      logger.debug(`Usage incremented for preset: ${presetId}`);
      return preset;
    } catch (error) {
      logger.error(`Failed to increment usage for preset ${presetId}:`, error);
      throw error;
    }
  }

  async ratePreset(presetId, rating) {
    try {
      if (rating < 1 || rating > 5) {
        throw new Error('Rating must be between 1 and 5');
      }
      
      const preset = await this.getPresetById(presetId);
      await preset.addRating(rating);
      logger.info(`Rating added for preset ${presetId}: ${rating}`);
      return preset;
    } catch (error) {
      logger.error(`Failed to rate preset ${presetId}:`, error);
      throw error;
    }
  }

  async searchPresets(searchTerm, filters = {}) {
    try {
      const query = {
        isActive: true,
        $or: [
          { name: { $regex: searchTerm, $options: 'i' } },
          { description: { $regex: searchTerm, $options: 'i' } },
          { tags: { $in: [new RegExp(searchTerm, 'i')] } }
        ]
      };

      if (filters.category) {
        query.category = filters.category;
      }

      const presets = await StylePreset.find(query)
        .sort({ 'metadata.usageCount': -1 })
        .limit(filters.limit || 20);

      return presets;
    } catch (error) {
      logger.error('Failed to search presets:', error);
      throw error;
    }
  }

  removeDuplicatePresets(presets) {
    const seen = new Set();
    return presets.filter(preset => {
      if (seen.has(preset.id)) {
        return false;
      }
      seen.add(preset.id);
      return true;
    });
  }

  scorePresetRelevance(presets, analysis, userPreferences) {
    return presets.map(preset => {
      let score = 0;
      
      // Score based on scene type match
      if (preset.sceneTypes.includes(analysis.scene_type)) {
        score += 3;
      }
      
      // Score based on lighting condition match
      if (preset.lightingConditions.includes(analysis.lighting_condition)) {
        score += 2;
      }
      
      // Score based on popularity
      score += Math.min(preset.metadata.usageCount / 100, 2);
      
      // Score based on rating
      score += preset.metadata.rating.average;
      
      // Score based on user preferences
      if (userPreferences.favoriteCategories && 
          userPreferences.favoriteCategories.includes(preset.category)) {
        score += 1;
      }
      
      return {
        ...preset.toObject(),
        relevanceScore: score
      };
    }).sort((a, b) => b.relevanceScore - a.relevanceScore);
  }

  async getPresetStatistics() {
    try {
      const stats = await StylePreset.aggregate([
        { $match: { isActive: true } },
        {
          $group: {
            _id: null,
            totalPresets: { $sum: 1 },
            totalUsage: { $sum: '$metadata.usageCount' },
            averageRating: { $avg: '$metadata.rating.average' },
            categoryDistribution: {
              $push: '$category'
            }
          }
        }
      ]);

      const categoryStats = await StylePreset.aggregate([
        { $match: { isActive: true } },
        {
          $group: {
            _id: '$category',
            count: { $sum: 1 },
            avgUsage: { $avg: '$metadata.usageCount' }
          }
        }
      ]);

      return {
        overview: stats[0] || {
          totalPresets: 0,
          totalUsage: 0,
          averageRating: 0
        },
        byCategory: categoryStats
      };
    } catch (error) {
      logger.error('Failed to get preset statistics:', error);
      throw error;
    }
  }

  // New methods for user-generated presets

  async createUserPreset(userId, presetData) {
    try {
      const preset = new StylePreset({
        ...presetData,
        id: this.generatePresetId(presetData.name),
        type: 'user_created',
        isUserGenerated: true,
        visibility: presetData.visibility || 'private',
        metadata: {
          ...presetData.metadata,
          createdBy: userId,
          createdByUsername: presetData.createdByUsername,
          originalSettings: presetData.settings
        }
      });

      await preset.save();
      logger.info(`User preset created: ${preset.id} by user ${userId}`);
      return preset;
    } catch (error) {
      logger.error('Failed to create user preset:', error);
      throw error;
    }
  }

  async getUserPresets(userId, includePrivate = false) {
    try {
      return await StylePreset.getUserPresets(userId, includePrivate);
    } catch (error) {
      logger.error('Failed to get user presets:', error);
      throw error;
    }
  }

  async getCommunityPresets(filters = {}) {
    try {
      let query = StylePreset.getPublicPresets();

      if (filters.category) {
        query = query.where('category', filters.category);
      }

      if (filters.limit) {
        query = query.limit(filters.limit);
      }

      // Apply sorting
      if (filters.sortBy === 'newest') {
        query = query.sort({ createdAt: -1 });
      } else if (filters.sortBy === 'rating') {
        query = query.sort({ 'metadata.rating.average': -1 });
      }
      // Default is by popularity (usageCount)

      return await query.exec();
    } catch (error) {
      logger.error('Failed to get community presets:', error);
      throw error;
    }
  }

  async getPresetByShareCode(shareCode) {
    try {
      return await StylePreset.findByShareCode(shareCode);
    } catch (error) {
      logger.error('Failed to get preset by share code:', error);
      throw error;
    }
  }

  async updatePresetVisibility(presetId, visibility) {
    try {
      const preset = await StylePreset.findOneAndUpdate(
        { id: presetId },
        { 
          visibility: visibility,
          // Update username based on visibility
          'metadata.createdByUsername': visibility === 'public' ? 
            await this.getUsernameFromPreset(presetId) : undefined
        },
        { new: true }
      );

      if (!preset) {
        throw new Error('Preset not found');
      }

      logger.info(`Updated preset ${presetId} visibility to ${visibility}`);
      return preset;
    } catch (error) {
      logger.error('Failed to update preset visibility:', error);
      throw error;
    }
  }

  async generateShareCode(presetId) {
    try {
      const preset = await StylePreset.findOne({ id: presetId });
      if (!preset) {
        throw new Error('Preset not found');
      }

      const shareCode = preset.generateShareCode();
      await preset.save();

      logger.info(`Generated share code ${shareCode} for preset ${presetId}`);
      return shareCode;
    } catch (error) {
      logger.error('Failed to generate share code:', error);
      throw error;
    }
  }

  async forkPreset(userId, presetId, customization = {}) {
    try {
      const originalPreset = await this.getPresetById(presetId);
      if (!originalPreset) {
        throw new Error('Original preset not found');
      }

      // Check if user can access the preset
      if (!originalPreset.canUserAccess(userId)) {
        throw new Error('Access denied to preset');
      }

      const forkedPresetData = {
        name: customization.name || `${originalPreset.name} (Copy)`,
        description: customization.description || `Forked from ${originalPreset.name}`,
        category: customization.category || originalPreset.category,
        settings: { ...originalPreset.settings, ...customization.settings },
        tags: [...(originalPreset.tags || []), 'forked'],
        sceneTypes: originalPreset.sceneTypes,
        lightingConditions: originalPreset.lightingConditions,
        visibility: 'private', // Always start as private
        metadata: {
          originalPresetId: originalPreset.id,
          originalSettings: originalPreset.settings
        }
      };

      const forkedPreset = await this.createUserPreset(userId, forkedPresetData);
      
      // Increment usage count of original preset
      await this.incrementPresetUsage(presetId);

      logger.info(`User ${userId} forked preset ${presetId} as ${forkedPreset.id}`);
      return forkedPreset;
    } catch (error) {
      logger.error('Failed to fork preset:', error);
      throw error;
    }
  }

  generatePresetId(name) {
    const timestamp = Date.now();
    const cleanName = name.toLowerCase()
      .replace(/[^a-z0-9]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '');
    return `user_${cleanName}_${timestamp}`;
  }

  async getUsernameFromPreset(presetId) {
    try {
      const preset = await StylePreset.findOne({ id: presetId }).populate('metadata.createdBy', 'username');
      return preset?.metadata?.createdBy?.username || 'Anonymous';
    } catch (error) {
      logger.error('Failed to get username from preset:', error);
      return 'Anonymous';
    }
  }

  // White Balance Analysis and Recommendations
  
  analyzeWBForScene(sceneAnalysis) {
    const { lighting_condition, color_temperature, scene_type } = sceneAnalysis;
    
    const recommendations = {
      mode: 'auto',
      kelvin: 5500,
      shift: { magentaGreen: 0, blueAmber: 0 },
      autoWBBias: { enabled: false, amber: 0, magenta: 0 },
      priority: 'standard',
      confidence: 0.5
    };

    // Analyze lighting conditions
    if (lighting_condition === 'tungsten' || color_temperature < 3500) {
      recommendations.mode = 'tungsten';
      recommendations.kelvin = Math.max(2800, color_temperature || 3200);
      recommendations.shift.magentaGreen = 1; // Counter green cast
      recommendations.confidence = 0.8;
    } else if (lighting_condition === 'fluorescent') {
      recommendations.mode = 'fluorescent';
      recommendations.kelvin = 4000;
      recommendations.shift.magentaGreen = 2; // Strong magenta for green fluorescent
      recommendations.confidence = 0.9;
    } else if (lighting_condition === 'mixed') {
      recommendations.mode = 'auto';
      recommendations.autoWBBias.enabled = true;
      recommendations.autoWBBias.amber = 1;
      recommendations.confidence = 0.6;
    } else if (lighting_condition === 'golden_hour') {
      recommendations.mode = 'shade';
      recommendations.kelvin = 7000;
      recommendations.shift.blueAmber = 2; // Enhance warmth
      recommendations.priority = 'atmosphere_priority';
      recommendations.confidence = 0.85;
    } else if (lighting_condition === 'overcast') {
      recommendations.mode = 'cloudy';
      recommendations.kelvin = 6500;
      recommendations.shift.blueAmber = 1; // Slight warmth
      recommendations.confidence = 0.7;
    }

    // Scene-specific adjustments
    if (scene_type === 'portrait') {
      recommendations.shift.magentaGreen += 1; // Warmer skin tones
      recommendations.priority = 'white_priority';
    } else if (scene_type === 'landscape') {
      recommendations.priority = 'atmosphere_priority';
    }

    return recommendations;
  }

  optimizeWBForCamera(wbSettings, cameraModel) {
    const brand = this.getCameraBrand(cameraModel);
    const optimized = { ...wbSettings };

    // Brand-specific optimizations
    switch (brand) {
      case 'canon':
        // Canon tends to run warm, adjust accordingly
        if (optimized.mode === 'daylight') {
          optimized.shift.blueAmber = Math.max(-2, optimized.shift.blueAmber - 1);
        }
        break;
      
      case 'nikon':
        // Nikon has limited shift range (-6 to +6)
        optimized.shift.magentaGreen = Math.max(-6, Math.min(6, optimized.shift.magentaGreen));
        optimized.shift.blueAmber = Math.max(-6, Math.min(6, optimized.shift.blueAmber));
        break;
      
      case 'sony':
        // Sony benefits from slight magenta bias in auto WB
        if (optimized.mode === 'auto') {
          optimized.autoWBBias.enabled = true;
          optimized.autoWBBias.magenta = Math.max(0, optimized.autoWBBias.magenta);
        }
        break;
    }

    return optimized;
  }

  getCameraBrand(cameraModel) {
    const model = cameraModel.toLowerCase();
    if (model.includes('canon')) return 'canon';
    if (model.includes('nikon')) return 'nikon';
    if (model.includes('sony')) return 'sony';
    if (model.includes('fuji')) return 'fujifilm';
    return 'generic';
  }

  generateWBShiftPresets(basePreset, variations = 3) {
    const presets = [];
    const base = basePreset.settings.whiteBalance;
    
    // Create variations with different WB shifts
    for (let i = 0; i < variations; i++) {
      const variant = {
        ...basePreset,
        name: `${basePreset.name} (WB Variant ${i + 1})`,
        settings: {
          ...basePreset.settings,
          whiteBalance: {
            ...base,
            shift: {
              magentaGreen: base.shift.magentaGreen + (i - 1),
              blueAmber: base.shift.blueAmber + (i - 1) * 0.5
            }
          }
        }
      };
      presets.push(variant);
    }
    
    return presets;
  }

  validateWBSettings(wbSettings) {
    const errors = [];
    
    if (wbSettings.kelvin < 2000 || wbSettings.kelvin > 10000) {
      errors.push('Kelvin value must be between 2000K and 10000K');
    }
    
    if (wbSettings.shift.magentaGreen < -9 || wbSettings.shift.magentaGreen > 9) {
      errors.push('Magenta-Green shift must be between -9 and +9');
    }
    
    if (wbSettings.shift.blueAmber < -9 || wbSettings.shift.blueAmber > 9) {
      errors.push('Blue-Amber shift must be between -9 and +9');
    }
    
    return errors;
  }
}

module.exports = StylePresetService;