const mongoose = require('mongoose');

// Main cloud sync record for tracking user data synchronization
const CloudSyncSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  // Sync metadata
  lastSyncAt: {
    type: Date,
    default: Date.now
  },
  nextSyncAt: {
    type: Date,
    default: () => new Date(Date.now() + 3600000) // 1 hour from now
  },
  syncStatus: {
    type: String,
    enum: ['idle', 'syncing', 'error', 'conflict', 'paused'],
    default: 'idle'
  },
  syncVersion: {
    type: Number,
    default: 1
  },
  
  // Device tracking
  devices: [{
    deviceId: {
      type: String,
      required: true
    },
    deviceName: String,
    platform: {
      type: String,
      enum: ['ios', 'android', 'web'],
      required: true
    },
    lastActiveAt: {
      type: Date,
      default: Date.now
    },
    syncEnabled: {
      type: Boolean,
      default: true
    }
  }],
  
  // Data sync status for different types
  dataSyncStatus: {
    photos: {
      lastSyncAt: Date,
      totalItems: { type: Number, default: 0 },
      syncedItems: { type: Number, default: 0 },
      pendingItems: { type: Number, default: 0 },
      failedItems: { type: Number, default: 0 }
    },
    presets: {
      lastSyncAt: Date,
      totalItems: { type: Number, default: 0 },
      syncedItems: { type: Number, default: 0 },
      pendingItems: { type: Number, default: 0 },
      failedItems: { type: Number, default: 0 }
    },
    settings: {
      lastSyncAt: Date,
      totalItems: { type: Number, default: 0 },
      syncedItems: { type: Number, default: 0 },
      pendingItems: { type: Number, default: 0 },
      failedItems: { type: Number, default: 0 }
    }
  },
  
  // Storage usage
  storageUsage: {
    totalBytes: { type: Number, default: 0 },
    photosBytes: { type: Number, default: 0 },
    thumbnailsBytes: { type: Number, default: 0 },
    quotaBytes: { type: Number, default: 5368709120 }, // 5GB default
    lastCalculatedAt: Date
  },
  
  // Sync settings
  syncSettings: {
    autoSync: { type: Boolean, default: true },
    syncOnWiFiOnly: { type: Boolean, default: true },
    syncPhotos: { type: Boolean, default: true },
    syncPresets: { type: Boolean, default: true },
    syncSettings: { type: Boolean, default: true },
    compressionLevel: {
      type: String,
      enum: ['none', 'low', 'medium', 'high'],
      default: 'medium'
    },
    syncFrequency: {
      type: String,
      enum: ['realtime', 'hourly', 'daily', 'manual'],
      default: 'hourly'
    }
  },
  
  // Error tracking
  lastError: {
    message: String,
    code: String,
    timestamp: Date,
    retryCount: { type: Number, default: 0 }
  },
  
  // Conflict resolution
  conflicts: [{
    type: {
      type: String,
      enum: ['photo', 'preset', 'setting'],
      required: true
    },
    localId: String,
    cloudId: String,
    conflictReason: String,
    localVersion: mongoose.Schema.Types.Mixed,
    cloudVersion: mongoose.Schema.Types.Mixed,
    detectedAt: { type: Date, default: Date.now },
    resolvedAt: Date,
    resolution: {
      type: String,
      enum: ['local_wins', 'cloud_wins', 'merge', 'manual']
    }
  }]
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Photo cloud storage record
const CloudPhotoSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  // Photo identification
  localId: String, // ID from mobile device
  filename: {
    type: String,
    required: true
  },
  originalFilename: String,
  
  // S3 storage info
  s3Key: {
    type: String,
    required: true,
    unique: true
  },
  s3Bucket: String,
  s3Region: String,
  cloudUrl: String,
  thumbnailS3Key: String,
  thumbnailUrl: String,
  
  // Photo metadata
  metadata: {
    fileSize: Number,
    dimensions: {
      width: Number,
      height: Number
    },
    format: String,
    exifData: {
      camera: String,
      lens: String,
      iso: Number,
      aperture: String,
      shutterSpeed: String,
      focalLength: Number,
      capturedAt: Date,
      gpsLocation: {
        latitude: Number,
        longitude: Number
      }
    },
    processingInfo: {
      aiAnalysis: mongoose.Schema.Types.Mixed,
      appliedPreset: String,
      adjustments: mongoose.Schema.Types.Mixed
    }
  },
  
  // Sync status
  syncStatus: {
    type: String,
    enum: ['pending', 'uploading', 'synced', 'failed', 'deleted'],
    default: 'pending'
  },
  uploadProgress: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  },
  
  // Sharing and access
  isPublic: { type: Boolean, default: false },
  sharedWith: [String], // User IDs
  tags: [String],
  
  // Timestamps
  capturedAt: Date,
  uploadedAt: Date,
  lastModifiedAt: Date
}, {
  timestamps: true,
  index: { userId: 1, syncStatus: 1 }
});

// Cloud settings sync record
const CloudSettingsSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  // Settings data
  settingsType: {
    type: String,
    enum: ['camera_defaults', 'user_preferences', 'app_settings'],
    required: true
  },
  settingsData: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  
  // Versioning
  version: {
    type: Number,
    default: 1
  },
  checksum: String, // For integrity verification
  
  // Device sync tracking
  deviceSyncStatus: [{
    deviceId: String,
    lastSyncedVersion: Number,
    syncStatus: {
      type: String,
      enum: ['synced', 'pending', 'conflict', 'error'],
      default: 'pending'
    },
    lastSyncAt: Date
  }],
  
  // Sync metadata
  lastModifiedBy: String, // Device ID
  syncPriority: {
    type: String,
    enum: ['low', 'normal', 'high'],
    default: 'normal'
  }
}, {
  timestamps: true,
  index: { userId: 1, settingsType: 1 }
});

// Sync job queue for background processing
const SyncJobSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  jobType: {
    type: String,
    enum: ['photo_upload', 'photo_download', 'settings_sync', 'preset_sync', 'full_sync'],
    required: true
  },
  
  // Job data
  jobData: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  
  // Job status
  status: {
    type: String,
    enum: ['pending', 'processing', 'completed', 'failed', 'cancelled'],
    default: 'pending'
  },
  priority: {
    type: Number,
    default: 5,
    min: 1,
    max: 10
  },
  
  // Execution info
  attempts: { type: Number, default: 0 },
  maxAttempts: { type: Number, default: 3 },
  processingStartedAt: Date,
  completedAt: Date,
  
  // Progress tracking
  progress: {
    current: { type: Number, default: 0 },
    total: { type: Number, default: 100 },
    message: String
  },
  
  // Error handling
  error: {
    message: String,
    stack: String,
    code: String
  },
  
  // Scheduling
  scheduledFor: {
    type: Date,
    default: Date.now
  },
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
  }
}, {
  timestamps: true,
  index: { status: 1, scheduledFor: 1, priority: -1 }
});

// Add virtual properties and methods
CloudSyncSchema.virtual('totalSyncedItems').get(function() {
  const { photos, presets, settings } = this.dataSyncStatus;
  return (photos.syncedItems || 0) + (presets.syncedItems || 0) + (settings.syncedItems || 0);
});

CloudSyncSchema.virtual('totalPendingItems').get(function() {
  const { photos, presets, settings } = this.dataSyncStatus;
  return (photos.pendingItems || 0) + (presets.pendingItems || 0) + (settings.pendingItems || 0);
});

CloudSyncSchema.virtual('syncProgress').get(function() {
  const total = this.totalSyncedItems + this.totalPendingItems;
  return total > 0 ? (this.totalSyncedItems / total) * 100 : 100;
});

CloudSyncSchema.virtual('storageUsagePercent').get(function() {
  const { totalBytes, quotaBytes } = this.storageUsage;
  return quotaBytes > 0 ? (totalBytes / quotaBytes) * 100 : 0;
});

// Methods
CloudSyncSchema.methods.addDevice = function(deviceInfo) {
  const existingDevice = this.devices.find(d => d.deviceId === deviceInfo.deviceId);
  if (existingDevice) {
    Object.assign(existingDevice, deviceInfo, { lastActiveAt: new Date() });
  } else {
    this.devices.push({ ...deviceInfo, lastActiveAt: new Date() });
  }
  return this.save();
};

CloudSyncSchema.methods.updateSyncStatus = function(dataType, status) {
  if (!this.dataSyncStatus[dataType]) {
    this.dataSyncStatus[dataType] = {};
  }
  Object.assign(this.dataSyncStatus[dataType], status, { lastSyncAt: new Date() });
  return this.save();
};

CloudSyncSchema.methods.addConflict = function(conflictData) {
  this.conflicts.push(conflictData);
  this.syncStatus = 'conflict';
  return this.save();
};

CloudPhotoSchema.methods.updateUploadProgress = function(progress) {
  this.uploadProgress = Math.min(100, Math.max(0, progress));
  if (progress >= 100) {
    this.syncStatus = 'synced';
    this.uploadedAt = new Date();
  }
  return this.save();
};

// Static methods
CloudSyncSchema.statics.findByUserId = function(userId) {
  return this.findOne({ userId }).populate('userId', 'name email');
};

CloudPhotoSchema.statics.findPendingUploads = function(userId, limit = 10) {
  return this.find({ 
    userId, 
    syncStatus: { $in: ['pending', 'uploading'] }
  }).limit(limit);
};

SyncJobSchema.statics.getNextJob = function() {
  return this.findOneAndUpdate(
    { 
      status: 'pending',
      scheduledFor: { $lte: new Date() },
      attempts: { $lt: this.$where('this.maxAttempts') }
    },
    { 
      status: 'processing',
      processingStartedAt: new Date(),
      $inc: { attempts: 1 }
    },
    { 
      new: true,
      sort: { priority: -1, scheduledFor: 1 }
    }
  );
};

// Indexes for performance
CloudSyncSchema.index({ userId: 1 }, { unique: true });
CloudSyncSchema.index({ 'devices.deviceId': 1 });
CloudSyncSchema.index({ syncStatus: 1, nextSyncAt: 1 });

CloudPhotoSchema.index({ userId: 1, syncStatus: 1 });
CloudPhotoSchema.index({ s3Key: 1 }, { unique: true });
CloudPhotoSchema.index({ capturedAt: -1 });

CloudSettingsSchema.index({ userId: 1, settingsType: 1 }, { unique: true });
CloudSettingsSchema.index({ version: -1 });

SyncJobSchema.index({ userId: 1, status: 1 });
SyncJobSchema.index({ status: 1, scheduledFor: 1, priority: -1 });
SyncJobSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = {
  CloudSync: mongoose.model('CloudSync', CloudSyncSchema),
  CloudPhoto: mongoose.model('CloudPhoto', CloudPhotoSchema),
  CloudSettings: mongoose.model('CloudSettings', CloudSettingsSchema),
  SyncJob: mongoose.model('SyncJob', SyncJobSchema)
};