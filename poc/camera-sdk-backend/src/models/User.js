const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  profileImage: {
    type: String,
    default: null
  },
  preferences: {
    defaultCameraSettings: {
      iso: { type: Number, default: 400 },
      aperture: { type: String, default: 'f/4.0' },
      shutterSpeed: { type: String, default: '1/125' },
      whiteBalance: { type: String, default: 'auto' }
    },
    favoritePresets: [{ type: String }],
    aiAssistanceLevel: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced'],
      default: 'beginner'
    }
  },
  stats: {
    photosProcessed: { type: Number, default: 0 },
    aiSuggestionsAccepted: { type: Number, default: 0 },
    totalSessionTime: { type: Number, default: 0 }
  }
}, {
  timestamps: true
});

userSchema.index({ email: 1 });

module.exports = mongoose.model('User', userSchema);