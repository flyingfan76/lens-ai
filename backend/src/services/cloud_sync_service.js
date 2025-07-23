const EventEmitter = require('events');
const cron = require('node-cron');
const { CloudSync, CloudPhoto, CloudSettings, SyncJob } = require('../models/CloudSync');
const AWSService = require('./aws_service');
const logger = require('../utils/logger');

class CloudSyncService extends EventEmitter {
  constructor() {
    super();
    this.awsService = new AWSService();
    this.isProcessing = new Map(); // Track active sync processes per user
    this.syncQueue = [];
    this.maxConcurrentSyncs = 5;
    this.activeSyncs = 0;
    
    // Sync intervals (in milliseconds)
    this.syncIntervals = {
      realtime: 5 * 60 * 1000,      // 5 minutes
      hourly: 60 * 60 * 1000,       // 1 hour
      daily: 24 * 60 * 60 * 1000,   // 24 hours
      manual: null                   // No automatic sync
    };

    this.initialize();
  }

  initialize() {
    try {
      // Start background job processor
      this.startJobProcessor();
      
      // Schedule periodic sync checks
      this.schedulePeriodicSync();
      
      logger.info('Cloud sync service initialized successfully');
      this.emit('initialized');
    } catch (error) {
      logger.error('Failed to initialize cloud sync service:', error);
      throw error;
    }
  }

  // User sync management
  async initializeUserSync(userId, deviceInfo) {
    try {
      let syncRecord = await CloudSync.findByUserId(userId);
      
      if (!syncRecord) {
        syncRecord = new CloudSync({
          userId,
          devices: [],
          dataSyncStatus: {
            photos: { totalItems: 0, syncedItems: 0, pendingItems: 0, failedItems: 0 },
            presets: { totalItems: 0, syncedItems: 0, pendingItems: 0, failedItems: 0 },
            settings: { totalItems: 0, syncedItems: 0, pendingItems: 0, failedItems: 0 }
          }
        });
      }

      // Add or update device
      await syncRecord.addDevice(deviceInfo);
      
      logger.info(`User sync initialized for user ${userId}, device ${deviceInfo.deviceId}`);
      return syncRecord;
    } catch (error) {
      logger.error(`Failed to initialize user sync for ${userId}:`, error);
      throw error;
    }
  }

  async syncUserData(userId, options = {}) {
    try {
      if (this.isProcessing.get(userId)) {
        logger.warn(`Sync already in progress for user ${userId}`);
        return { success: false, message: 'Sync already in progress' };
      }

      this.isProcessing.set(userId, true);
      
      const syncRecord = await CloudSync.findByUserId(userId);
      if (!syncRecord) {
        throw new Error('User sync not initialized');
      }

      // Update sync status
      syncRecord.syncStatus = 'syncing';
      await syncRecord.save();

      logger.info(`Starting sync for user ${userId}`);

      const results = {
        photos: { success: false, synced: 0, failed: 0 },
        settings: { success: false, synced: 0, failed: 0 },
        presets: { success: false, synced: 0, failed: 0 }
      };

      // Sync photos
      if (syncRecord.syncSettings.syncPhotos && (options.syncPhotos !== false)) {
        results.photos = await this.syncPhotos(userId, options);
      }

      // Sync settings
      if (syncRecord.syncSettings.syncSettings && (options.syncSettings !== false)) {
        results.settings = await this.syncSettings(userId, options);
      }

      // Sync presets
      if (syncRecord.syncSettings.syncPresets && (options.syncPresets !== false)) {
        results.presets = await this.syncPresets(userId, options);
      }

      // Update sync record
      syncRecord.syncStatus = 'idle';
      syncRecord.lastSyncAt = new Date();
      syncRecord.nextSyncAt = new Date(Date.now() + this.getSyncInterval(syncRecord.syncSettings.syncFrequency));
      await syncRecord.save();

      logger.info(`Sync completed for user ${userId}:`, results);
      this.emit('syncCompleted', { userId, results });

      return { success: true, results };

    } catch (error) {
      logger.error(`Sync failed for user ${userId}:`, error);
      
      // Update sync record with error
      const syncRecord = await CloudSync.findByUserId(userId);
      if (syncRecord) {
        syncRecord.syncStatus = 'error';
        syncRecord.lastError = {
          message: error.message,
          code: error.code || 'SYNC_ERROR',
          timestamp: new Date(),
          retryCount: (syncRecord.lastError?.retryCount || 0) + 1
        };
        await syncRecord.save();
      }

      this.emit('syncError', { userId, error });
      throw error;
    } finally {
      this.isProcessing.delete(userId);
    }
  }

  async syncPhotos(userId, options = {}) {
    try {
      const limit = options.limit || 50;
      const pendingPhotos = await CloudPhoto.findPendingUploads(userId, limit);
      
      let synced = 0;
      let failed = 0;

      for (const photo of pendingPhotos) {
        try {
          if (photo.syncStatus === 'pending') {
            // Create sync job for photo upload
            await this.createSyncJob(userId, 'photo_upload', {
              photoId: photo._id,
              s3Key: photo.s3Key,
              priority: options.priority || 5
            });
            synced++;
          }
        } catch (error) {
          logger.error(`Failed to sync photo ${photo._id}:`, error);
          photo.syncStatus = 'failed';
          await photo.save();
          failed++;
        }
      }

      // Update sync status
      const syncRecord = await CloudSync.findByUserId(userId);
      if (syncRecord) {
        await syncRecord.updateSyncStatus('photos', {
          syncedItems: syncRecord.dataSyncStatus.photos.syncedItems + synced,
          failedItems: syncRecord.dataSyncStatus.photos.failedItems + failed,
          pendingItems: Math.max(0, syncRecord.dataSyncStatus.photos.pendingItems - synced - failed)
        });
      }

      return { success: true, synced, failed };
    } catch (error) {
      logger.error(`Photo sync failed for user ${userId}:`, error);
      return { success: false, error: error.message };
    }
  }

  async syncSettings(userId, options = {}) {
    try {
      const settingsTypes = ['camera_defaults', 'user_preferences', 'app_settings'];
      let synced = 0;
      let failed = 0;

      for (const settingsType of settingsTypes) {
        try {
          const cloudSettings = await CloudSettings.findOne({ userId, settingsType });
          
          if (cloudSettings) {
            // Check if settings need to be synced to other devices
            const deviceSyncNeeded = cloudSettings.deviceSyncStatus.some(
              device => device.syncStatus === 'pending'
            );

            if (deviceSyncNeeded) {
              await this.createSyncJob(userId, 'settings_sync', {
                settingsId: cloudSettings._id,
                settingsType,
                priority: options.priority || 3
              });
              synced++;
            }
          }
        } catch (error) {
          logger.error(`Failed to sync ${settingsType} for user ${userId}:`, error);
          failed++;
        }
      }

      return { success: true, synced, failed };
    } catch (error) {
      logger.error(`Settings sync failed for user ${userId}:`, error);
      return { success: false, error: error.message };
    }
  }

  async syncPresets(userId, options = {}) {
    try {
      // Import style preset service
      const StylePresetService = require('./style_preset_service');
      const presetService = new StylePresetService();
      
      // Get user's custom presets that need syncing
      const userPresets = await presetService.getAllPresets({
        type: 'user_created',
        // Add logic to identify presets that need syncing
      });

      let synced = 0;
      let failed = 0;

      for (const preset of userPresets) {
        try {
          await this.createSyncJob(userId, 'preset_sync', {
            presetId: preset._id,
            presetData: preset.toObject(),
            priority: options.priority || 4
          });
          synced++;
        } catch (error) {
          logger.error(`Failed to sync preset ${preset._id}:`, error);
          failed++;
        }
      }

      return { success: true, synced, failed };
    } catch (error) {
      logger.error(`Preset sync failed for user ${userId}:`, error);
      return { success: false, error: error.message };
    }
  }

  // Photo management
  async uploadPhoto(userId, file, metadata = {}) {
    try {
      // Upload to S3
      const uploadResult = await this.awsService.uploadPhoto(file, userId, {
        quality: 85,
        maxWidth: 4000 // Reasonable max for most cameras
      });

      if (!uploadResult.success) {
        throw new Error('S3 upload failed');
      }

      // Create cloud photo record
      const cloudPhoto = new CloudPhoto({
        userId,
        filename: file.originalname || file.filename,
        originalFilename: file.originalname,
        s3Key: uploadResult.s3Key,
        s3Bucket: this.awsService.bucketName,
        s3Region: this.awsService.region,
        cloudUrl: uploadResult.url,
        thumbnailS3Key: uploadResult.thumbnails.medium?.key,
        thumbnailUrl: uploadResult.thumbnails.medium?.url,
        metadata: {
          fileSize: uploadResult.size,
          dimensions: {
            width: uploadResult.metadata?.width,
            height: uploadResult.metadata?.height
          },
          format: uploadResult.metadata?.format,
          exifData: metadata.exifData || {},
          processingInfo: metadata.processingInfo || {}
        },
        syncStatus: 'synced',
        uploadProgress: 100,
        capturedAt: metadata.capturedAt || new Date(),
        uploadedAt: new Date()
      });

      await cloudPhoto.save();

      // Update user's sync statistics
      const syncRecord = await CloudSync.findByUserId(userId);
      if (syncRecord) {
        await syncRecord.updateSyncStatus('photos', {
          syncedItems: syncRecord.dataSyncStatus.photos.syncedItems + 1,
          totalItems: syncRecord.dataSyncStatus.photos.totalItems + 1
        });

        // Update storage usage
        syncRecord.storageUsage.photosBytes += uploadResult.size;
        syncRecord.storageUsage.totalBytes += uploadResult.size;
        syncRecord.storageUsage.lastCalculatedAt = new Date();
        await syncRecord.save();
      }

      logger.info(`Photo uploaded successfully for user ${userId}: ${uploadResult.s3Key}`);
      this.emit('photoUploaded', { userId, photo: cloudPhoto, uploadResult });

      return {
        success: true,
        photoId: cloudPhoto._id,
        cloudUrl: cloudPhoto.cloudUrl,
        thumbnailUrl: cloudPhoto.thumbnailUrl,
        s3Key: cloudPhoto.s3Key
      };

    } catch (error) {
      logger.error(`Photo upload failed for user ${userId}:`, error);
      throw error;
    }
  }

  async deletePhoto(userId, photoId) {
    try {
      const cloudPhoto = await CloudPhoto.findOne({ _id: photoId, userId });
      
      if (!cloudPhoto) {
        throw new Error('Photo not found or access denied');
      }

      // Delete from S3
      await this.awsService.deletePhoto(cloudPhoto.s3Key, userId);

      // Update photo record
      cloudPhoto.syncStatus = 'deleted';
      await cloudPhoto.save();

      // Update storage usage
      const syncRecord = await CloudSync.findByUserId(userId);
      if (syncRecord) {
        syncRecord.storageUsage.photosBytes = Math.max(0, 
          syncRecord.storageUsage.photosBytes - cloudPhoto.metadata.fileSize
        );
        syncRecord.storageUsage.totalBytes = Math.max(0,
          syncRecord.storageUsage.totalBytes - cloudPhoto.metadata.fileSize
        );
        syncRecord.storageUsage.lastCalculatedAt = new Date();
        await syncRecord.save();
      }

      logger.info(`Photo deleted successfully for user ${userId}: ${photoId}`);
      this.emit('photoDeleted', { userId, photoId });

      return { success: true };

    } catch (error) {
      logger.error(`Photo deletion failed for user ${userId}:`, error);
      throw error;
    }
  }

  // Settings management
  async updateCloudSettings(userId, settingsType, settingsData, deviceId) {
    try {
      let cloudSettings = await CloudSettings.findOne({ userId, settingsType });
      
      if (!cloudSettings) {
        cloudSettings = new CloudSettings({
          userId,
          settingsType,
          settingsData,
          version: 1,
          deviceSyncStatus: [],
          lastModifiedBy: deviceId
        });
      } else {
        // Check for conflicts
        if (cloudSettings.lastModifiedBy !== deviceId && 
            cloudSettings.version > 1) {
          // Potential conflict - create conflict record
          const syncRecord = await CloudSync.findByUserId(userId);
          if (syncRecord) {
            await syncRecord.addConflict({
              type: 'setting',
              localId: `${settingsType}_${deviceId}`,
              cloudId: cloudSettings._id.toString(),
              conflictReason: 'Concurrent modification',
              localVersion: settingsData,
              cloudVersion: cloudSettings.settingsData
            });
          }
        }

        cloudSettings.settingsData = settingsData;
        cloudSettings.version += 1;
        cloudSettings.lastModifiedBy = deviceId;
      }

      // Generate checksum for integrity
      cloudSettings.checksum = this.generateChecksum(settingsData);

      // Mark all other devices as pending sync
      cloudSettings.deviceSyncStatus = cloudSettings.deviceSyncStatus.map(device => ({
        ...device,
        syncStatus: device.deviceId === deviceId ? 'synced' : 'pending',
        lastSyncAt: device.deviceId === deviceId ? new Date() : device.lastSyncAt
      }));

      // Add current device if not exists
      if (!cloudSettings.deviceSyncStatus.find(d => d.deviceId === deviceId)) {
        cloudSettings.deviceSyncStatus.push({
          deviceId,
          lastSyncedVersion: cloudSettings.version,
          syncStatus: 'synced',
          lastSyncAt: new Date()
        });
      }

      await cloudSettings.save();

      logger.info(`Settings updated for user ${userId}, type ${settingsType}`);
      this.emit('settingsUpdated', { userId, settingsType, deviceId });

      return { success: true, version: cloudSettings.version };

    } catch (error) {
      logger.error(`Settings update failed for user ${userId}:`, error);
      throw error;
    }
  }

  // Job management
  async createSyncJob(userId, jobType, jobData, options = {}) {
    try {
      const syncJob = new SyncJob({
        userId,
        jobType,
        jobData,
        priority: options.priority || 5,
        scheduledFor: options.scheduledFor || new Date(),
        maxAttempts: options.maxAttempts || 3
      });

      await syncJob.save();
      
      logger.debug(`Sync job created: ${jobType} for user ${userId}`);
      return syncJob;
    } catch (error) {
      logger.error('Failed to create sync job:', error);
      throw error;
    }
  }

  async processNextJob() {
    if (this.activeSyncs >= this.maxConcurrentSyncs) {
      return null;
    }

    try {
      const job = await SyncJob.getNextJob();
      
      if (!job) {
        return null;
      }

      this.activeSyncs++;
      logger.debug(`Processing sync job: ${job.jobType} for user ${job.userId}`);

      try {
        await this.executeJob(job);
        
        job.status = 'completed';
        job.completedAt = new Date();
        await job.save();
        
        logger.debug(`Job completed: ${job._id}`);
      } catch (error) {
        job.status = 'failed';
        job.error = {
          message: error.message,
          stack: error.stack,
          code: error.code
        };
        await job.save();
        
        logger.error(`Job failed: ${job._id}`, error);
      }

      this.activeSyncs--;
      return job;

    } catch (error) {
      this.activeSyncs--;
      logger.error('Job processing error:', error);
      return null;
    }
  }

  async executeJob(job) {
    switch (job.jobType) {
      case 'photo_upload':
        return await this.executePhotoUploadJob(job);
      case 'photo_download':
        return await this.executePhotoDownloadJob(job);
      case 'settings_sync':
        return await this.executeSettingsSyncJob(job);
      case 'preset_sync':
        return await this.executePresetSyncJob(job);
      case 'full_sync':
        return await this.syncUserData(job.userId, job.jobData);
      default:
        throw new Error(`Unknown job type: ${job.jobType}`);
    }
  }

  async executePhotoUploadJob(job) {
    const { photoId } = job.jobData;
    const cloudPhoto = await CloudPhoto.findById(photoId);
    
    if (!cloudPhoto) {
      throw new Error('Photo not found');
    }

    // Implementation would handle actual file upload to S3
    // This is a placeholder for the actual upload logic
    cloudPhoto.syncStatus = 'synced';
    cloudPhoto.uploadProgress = 100;
    cloudPhoto.uploadedAt = new Date();
    await cloudPhoto.save();

    return { success: true };
  }

  async executeSettingsSyncJob(job) {
    const { settingsId } = job.jobData;
    const cloudSettings = await CloudSettings.findById(settingsId);
    
    if (!cloudSettings) {
      throw new Error('Settings not found');
    }

    // Mark all devices as synced (in real implementation, this would 
    // involve pushing to device-specific queues or notification systems)
    cloudSettings.deviceSyncStatus.forEach(device => {
      if (device.syncStatus === 'pending') {
        device.syncStatus = 'synced';
        device.lastSyncAt = new Date();
        device.lastSyncedVersion = cloudSettings.version;
      }
    });

    await cloudSettings.save();
    return { success: true };
  }

  async executePresetSyncJob(job) {
    // Placeholder for preset sync logic
    return { success: true };
  }

  // Utility methods
  startJobProcessor() {
    // Process jobs every 30 seconds
    setInterval(async () => {
      try {
        while (this.activeSyncs < this.maxConcurrentSyncs) {
          const job = await this.processNextJob();
          if (!job) break;
        }
      } catch (error) {
        logger.error('Job processor error:', error);
      }
    }, 30000);
  }

  schedulePeriodicSync() {
    // Run every hour to check for users who need syncing
    cron.schedule('0 * * * *', async () => {
      try {
        const usersToSync = await CloudSync.find({
          syncStatus: 'idle',
          nextSyncAt: { $lte: new Date() },
          'syncSettings.autoSync': true
        });

        for (const syncRecord of usersToSync) {
          if (syncRecord.syncSettings.syncFrequency !== 'manual') {
            await this.createSyncJob(syncRecord.userId, 'full_sync', {
              autoSync: true
            });
          }
        }

        logger.debug(`Scheduled sync for ${usersToSync.length} users`);
      } catch (error) {
        logger.error('Periodic sync scheduling error:', error);
      }
    });
  }

  getSyncInterval(frequency) {
    return this.syncIntervals[frequency] || this.syncIntervals.daily;
  }

  generateChecksum(data) {
    const crypto = require('crypto');
    return crypto.createHash('sha256')
      .update(JSON.stringify(data))
      .digest('hex');
  }

  // Public API methods
  async getUserSyncStatus(userId) {
    const syncRecord = await CloudSync.findByUserId(userId);
    if (!syncRecord) {
      throw new Error('User sync not initialized');
    }

    const storageUsage = await this.awsService.getUserStorageUsage(userId);
    
    return {
      syncStatus: syncRecord.syncStatus,
      lastSyncAt: syncRecord.lastSyncAt,
      nextSyncAt: syncRecord.nextSyncAt,
      syncProgress: syncRecord.syncProgress,
      dataSyncStatus: syncRecord.dataSyncStatus,
      storageUsage: {
        ...syncRecord.storageUsage.toObject(),
        ...storageUsage
      },
      devices: syncRecord.devices,
      conflicts: syncRecord.conflicts,
      syncSettings: syncRecord.syncSettings
    };
  }

  async updateSyncSettings(userId, settings) {
    const syncRecord = await CloudSync.findByUserId(userId);
    if (!syncRecord) {
      throw new Error('User sync not initialized');
    }

    Object.assign(syncRecord.syncSettings, settings);
    
    // Update next sync time based on new frequency
    if (settings.syncFrequency) {
      syncRecord.nextSyncAt = new Date(Date.now() + this.getSyncInterval(settings.syncFrequency));
    }

    await syncRecord.save();
    
    logger.info(`Sync settings updated for user ${userId}`);
    return { success: true };
  }

  async triggerSync(userId, options = {}) {
    return await this.syncUserData(userId, { ...options, manual: true });
  }
}

module.exports = CloudSyncService;