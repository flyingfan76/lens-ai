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
          whiteBalance: 'daylight',
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
          whiteBalance: 'daylight',
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
          whiteBalance: 'shade',
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
}

module.exports = StylePresetService;