const mongoose = require('mongoose');

const StylePresetSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true,
    trim: true
  },
  category: {
    type: String,
    enum: ['portrait', 'landscape', 'street', 'macro', 'creative', 'low_light'],
    default: 'portrait'
  },
  type: {
    type: String,
    enum: ['built_in', 'user_created', 'community'],
    default: 'built_in'
  },
  visibility: {
    type: String,
    enum: ['public', 'private', 'friends_only'],
    default: 'public'
  },
  isUserGenerated: {
    type: Boolean,
    default: false
  },
  settings: {
    iso: {
      type: mongoose.Schema.Types.Mixed,
      required: true
    },
    aperture: {
      type: String,
      required: true,
      match: /^f\/\d+(\.\d+)?$/
    },
    shutterSpeed: {
      type: String,
      required: true
    },
    whiteBalance: {
      mode: {
        type: String,
        enum: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade', 'custom'],
        default: 'auto'
      },
      kelvin: {
        type: Number,
        min: 2000,
        max: 10000,
        default: 5500
      },
      shift: {
        magentaGreen: {
          type: Number,
          min: -9,
          max: 9,
          default: 0
        },
        blueAmber: {
          type: Number,
          min: -9,
          max: 9,
          default: 0
        }
      },
      autoWBBias: {
        enabled: {
          type: Boolean,
          default: false
        },
        amber: {
          type: Number,
          min: -3,
          max: 3,
          default: 0
        },
        magenta: {
          type: Number,
          min: -3,
          max: 3,
          default: 0
        }
      },
      priority: {
        type: String,
        enum: ['standard', 'white_priority', 'atmosphere_priority'],
        default: 'standard'
      }
    },
    exposureCompensation: {
      type: String,
      default: '0.0'
    },
    focusMode: {
      type: String,
      enum: ['single', 'continuous', 'manual', 'hyperfocal'],
      default: 'single'
    },
    meteringMode: {
      type: String,
      enum: ['matrix', 'center', 'spot'],
      default: 'matrix'
    },
    colorProfile: {
      type: String,
      default: 'standard'
    }
  },
  thumbnail: {
    type: String,
    default: ''
  },
  tags: [{
    type: String,
    trim: true
  }],
  sceneTypes: [{
    type: String,
    enum: ['portrait', 'landscape', 'macro', 'street', 'architecture', 'nature', 'sports', 'low_light', 'backlight', 'sunset']
  }],
  lightingConditions: [{
    type: String,
    enum: ['bright', 'normal', 'dim', 'very_dark', 'golden_hour', 'blue_hour']
  }],
  compatibility: {
    cameras: [{
      brand: {
        type: String,
        enum: ['canon', 'nikon', 'sony'],
        required: true
      },
      models: [String]
    }]
  },
  metadata: {
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: function() { return this.isUserGenerated; }
    },
    createdByUsername: {
      type: String,
      required: function() { return this.isUserGenerated && this.visibility === 'public'; }
    },
    originalSettings: {
      type: Object,
      default: null
    },
    shareCode: {
      type: String,
      unique: true,
      sparse: true
    },
    usageCount: {
      type: Number,
      default: 0
    },
    rating: {
      average: {
        type: Number,
        default: 0,
        min: 0,
        max: 5
      },
      count: {
        type: Number,
        default: 0
      }
    },
    featured: {
      type: Boolean,
      default: false
    },
    difficulty: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced'],
      default: 'beginner'
    }
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

StylePresetSchema.virtual('averageRating').get(function() {
  return this.metadata.rating.average;
});

StylePresetSchema.virtual('totalRatings').get(function() {
  return this.metadata.rating.count;
});

StylePresetSchema.index({ category: 1, type: 1 });
StylePresetSchema.index({ 'metadata.featured': 1, 'metadata.usageCount': -1 });
StylePresetSchema.index({ tags: 1 });
StylePresetSchema.index({ sceneTypes: 1 });

StylePresetSchema.methods.incrementUsage = function() {
  this.metadata.usageCount += 1;
  return this.save();
};

StylePresetSchema.methods.addRating = function(rating) {
  const currentTotal = this.metadata.rating.average * this.metadata.rating.count;
  this.metadata.rating.count += 1;
  this.metadata.rating.average = (currentTotal + rating) / this.metadata.rating.count;
  return this.save();
};

StylePresetSchema.statics.findByScene = function(sceneType) {
  return this.find({
    sceneTypes: sceneType,
    isActive: true
  }).sort({ 'metadata.usageCount': -1 });
};

StylePresetSchema.statics.findByLighting = function(lightingCondition) {
  return this.find({
    lightingConditions: lightingCondition,
    isActive: true
  }).sort({ 'metadata.usageCount': -1 });
};

StylePresetSchema.statics.getFeatured = function() {
  return this.find({
    'metadata.featured': true,
    isActive: true
  }).sort({ 'metadata.usageCount': -1 });
};

StylePresetSchema.statics.getUserPresets = function(userId, includePrivate = false) {
  const query = {
    'metadata.createdBy': userId,
    isActive: true
  };
  
  if (!includePrivate) {
    query.visibility = { $ne: 'private' };
  }
  
  return this.find(query).sort({ createdAt: -1 });
};

StylePresetSchema.statics.getPublicPresets = function() {
  return this.find({
    visibility: 'public',
    isUserGenerated: true,
    isActive: true
  }).sort({ 'metadata.usageCount': -1 });
};

StylePresetSchema.statics.findByShareCode = function(shareCode) {
  return this.findOne({
    'metadata.shareCode': shareCode,
    isActive: true
  });
};

StylePresetSchema.methods.generateShareCode = function() {
  if (!this.metadata.shareCode) {
    this.metadata.shareCode = Math.random().toString(36).substring(2, 12).toUpperCase();
  }
  return this.metadata.shareCode;
};

StylePresetSchema.methods.canUserAccess = function(userId) {
  // Public presets are accessible to everyone
  if (this.visibility === 'public') return true;
  
  // Private presets only accessible to owner
  if (this.visibility === 'private') {
    return this.metadata.createdBy && this.metadata.createdBy.toString() === userId.toString();
  }
  
  // TODO: Implement friends_only logic when friend system is added
  if (this.visibility === 'friends_only') {
    return this.metadata.createdBy && this.metadata.createdBy.toString() === userId.toString();
  }
  
  return false;
};

// White Balance helper methods
StylePresetSchema.methods.getEffectiveWBKelvin = function() {
  const modeKelvinMap = {
    'tungsten': 3200,
    'fluorescent': 4000,
    'daylight': 5500,
    'flash': 5500,
    'cloudy': 6500,
    'shade': 7500
  };

  if (this.settings.whiteBalance.mode === 'custom') {
    return this.settings.whiteBalance.kelvin;
  }
  
  return modeKelvinMap[this.settings.whiteBalance.mode] || 5500;
};

StylePresetSchema.methods.getWBShiftDescription = function() {
  const { magentaGreen, blueAmber } = this.settings.whiteBalance.shift;
  
  if (magentaGreen === 0 && blueAmber === 0) {
    return 'No shift';
  }
  
  const mgDesc = magentaGreen > 0 ? `M${magentaGreen}` : magentaGreen < 0 ? `G${Math.abs(magentaGreen)}` : '';
  const baDesc = blueAmber > 0 ? `A${blueAmber}` : blueAmber < 0 ? `B${Math.abs(blueAmber)}` : '';
  
  return [mgDesc, baDesc].filter(Boolean).join(', ') || 'No shift';
};

StylePresetSchema.methods.isWBCompatibleWith = function(cameraModel) {
  // Different cameras have different WB shift ranges and precision
  const cameraSpecs = {
    'canon': { mgRange: [-9, 9], baRange: [-9, 9], precision: 1 },
    'nikon': { mgRange: [-6, 6], baRange: [-6, 6], precision: 1 },
    'sony': { mgRange: [-9, 9], baRange: [-9, 9], precision: 1 },
    'fujifilm': { mgRange: [-9, 9], baRange: [-9, 9], precision: 1 }
  };
  
  const brand = cameraModel.toLowerCase().includes('canon') ? 'canon' :
               cameraModel.toLowerCase().includes('nikon') ? 'nikon' :
               cameraModel.toLowerCase().includes('sony') ? 'sony' :
               cameraModel.toLowerCase().includes('fuji') ? 'fujifilm' : 'canon';
  
  const spec = cameraSpecs[brand];
  const wb = this.settings.whiteBalance;
  
  return wb.shift.magentaGreen >= spec.mgRange[0] && 
         wb.shift.magentaGreen <= spec.mgRange[1] &&
         wb.shift.blueAmber >= spec.baRange[0] && 
         wb.shift.blueAmber <= spec.baRange[1];
};

module.exports = mongoose.model('StylePreset', StylePresetSchema);