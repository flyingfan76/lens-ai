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
      type: String,
      enum: ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash', 'shade'],
      default: 'auto'
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
      ref: 'User'
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

module.exports = mongoose.model('StylePreset', StylePresetSchema);