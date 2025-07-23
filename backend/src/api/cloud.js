const express = require('express');
const multer = require('multer');
const CloudSyncService = require('../services/cloud_sync_service');
const logger = require('../utils/logger');

const router = express.Router();
const cloudSyncService = new CloudSyncService();

// Configure multer for photo uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = [
      'image/jpeg', 'image/jpg', 'image/png', 'image/tiff',
      'image/x-canon-cr3', 'image/x-nikon-nef', 'image/x-sony-arw'
    ];
    
    if (allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported file type: ${file.mimetype}`));
    }
  }
});

// Initialize user cloud sync
router.post('/init', async (req, res) => {
  try {
    const userId = req.user?.id; // Assumes authentication middleware
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { deviceInfo } = req.body;
    if (!deviceInfo || !deviceInfo.deviceId || !deviceInfo.platform) {
      return res.status(400).json({
        success: false,
        error: 'Device information required (deviceId, platform)'
      });
    }

    const syncRecord = await cloudSyncService.initializeUserSync(userId, deviceInfo);
    
    res.json({
      success: true,
      data: {
        syncId: syncRecord._id,
        syncStatus: syncRecord.syncStatus,
        lastSyncAt: syncRecord.lastSyncAt,
        syncSettings: syncRecord.syncSettings
      }
    });
  } catch (error) {
    logger.error('Cloud sync initialization failed:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to initialize cloud sync'
    });
  }
});

// Get sync status
router.get('/status', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const status = await cloudSyncService.getUserSyncStatus(userId);
    
    res.json({
      success: true,
      data: status
    });
  } catch (error) {
    logger.error('Failed to get sync status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve sync status'
    });
  }
});

// Trigger manual sync
router.post('/sync', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { syncPhotos, syncSettings, syncPresets, priority } = req.body;
    
    const result = await cloudSyncService.triggerSync(userId, {
      syncPhotos,
      syncSettings,
      syncPresets,
      priority: priority || 5
    });
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Manual sync failed:', error);
    res.status(500).json({
      success: false,
      error: 'Manual sync failed'
    });
  }
});

// Update sync settings
router.put('/settings', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const settings = req.body;
    
    // Validate settings
    const allowedSettings = [
      'autoSync', 'syncOnWiFiOnly', 'syncPhotos', 'syncPresets', 
      'syncSettings', 'compressionLevel', 'syncFrequency'
    ];
    
    const validSettings = {};
    for (const [key, value] of Object.entries(settings)) {
      if (allowedSettings.includes(key)) {
        validSettings[key] = value;
      }
    }

    await cloudSyncService.updateSyncSettings(userId, validSettings);
    
    res.json({
      success: true,
      message: 'Sync settings updated successfully'
    });
  } catch (error) {
    logger.error('Failed to update sync settings:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update sync settings'
    });
  }
});

// Upload photo
router.post('/photos/upload', upload.single('photo'), async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No photo file provided'
      });
    }

    // Parse metadata from request body
    let metadata = {};
    try {
      if (req.body.metadata) {
        metadata = JSON.parse(req.body.metadata);
      }
    } catch (parseError) {
      logger.warn('Failed to parse photo metadata:', parseError);
    }

    const result = await cloudSyncService.uploadPhoto(userId, req.file, metadata);
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Photo upload failed:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Photo upload failed'
    });
  }
});

// Delete photo
router.delete('/photos/:photoId', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { photoId } = req.params;
    
    await cloudSyncService.deletePhoto(userId, photoId);
    
    res.json({
      success: true,
      message: 'Photo deleted successfully'
    });
  } catch (error) {
    logger.error('Photo deletion failed:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Photo deletion failed'
    });
  }
});

// Get user's photos
router.get('/photos', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { CloudPhoto } = require('../models/CloudSync');
    
    const {
      page = 1,
      limit = 20,
      syncStatus,
      sortBy = 'capturedAt',
      sortOrder = 'desc'
    } = req.query;

    const query = { userId, syncStatus: { $ne: 'deleted' } };
    if (syncStatus) {
      query.syncStatus = syncStatus;
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const photos = await CloudPhoto.find(query)
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit))
      .select('-__v');

    const total = await CloudPhoto.countDocuments(query);

    res.json({
      success: true,
      data: {
        photos,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    logger.error('Failed to get photos:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve photos'
    });
  }
});

// Update cloud settings
router.put('/user-settings/:settingsType', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { settingsType } = req.params;
    const { settingsData, deviceId } = req.body;

    if (!settingsData || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Settings data and device ID required'
      });
    }

    const allowedTypes = ['camera_defaults', 'user_preferences', 'app_settings'];
    if (!allowedTypes.includes(settingsType)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid settings type'
      });
    }

    const result = await cloudSyncService.updateCloudSettings(
      userId, 
      settingsType, 
      settingsData, 
      deviceId
    );
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error('Failed to update cloud settings:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update settings'
    });
  }
});

// Get cloud settings
router.get('/user-settings/:settingsType', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { settingsType } = req.params;
    const { CloudSettings } = require('../models/CloudSync');
    
    const settings = await CloudSettings.findOne({ userId, settingsType });
    
    if (!settings) {
      return res.status(404).json({
        success: false,
        error: 'Settings not found'
      });
    }

    res.json({
      success: true,
      data: {
        settingsType: settings.settingsType,
        settingsData: settings.settingsData,
        version: settings.version,
        lastModifiedAt: settings.updatedAt,
        checksum: settings.checksum
      }
    });
  } catch (error) {
    logger.error('Failed to get cloud settings:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve settings'
    });
  }
});

// Resolve sync conflict
router.post('/conflicts/:conflictId/resolve', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { conflictId } = req.params;
    const { resolution, selectedVersion } = req.body;

    if (!['local_wins', 'cloud_wins', 'merge', 'manual'].includes(resolution)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid resolution type'
      });
    }

    const { CloudSync } = require('../models/CloudSync');
    const syncRecord = await CloudSync.findByUserId(userId);
    
    if (!syncRecord) {
      return res.status(404).json({
        success: false,
        error: 'Sync record not found'
      });
    }

    const conflict = syncRecord.conflicts.id(conflictId);
    if (!conflict) {
      return res.status(404).json({
        success: false,
        error: 'Conflict not found'
      });
    }

    // Resolve conflict
    conflict.resolution = resolution;
    conflict.resolvedAt = new Date();
    
    // Remove resolved conflict
    syncRecord.conflicts.pull(conflictId);
    
    // Update sync status if no more conflicts
    if (syncRecord.conflicts.length === 0) {
      syncRecord.syncStatus = 'idle';
    }
    
    await syncRecord.save();

    res.json({
      success: true,
      message: 'Conflict resolved successfully'
    });
  } catch (error) {
    logger.error('Failed to resolve conflict:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to resolve conflict'
    });
  }
});

// Get sync jobs (for debugging/admin)
router.get('/jobs', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { SyncJob } = require('../models/CloudSync');
    const { status, jobType, limit = 20 } = req.query;
    
    const query = { userId };
    if (status) query.status = status;
    if (jobType) query.jobType = jobType;

    const jobs = await SyncJob.find(query)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .select('-jobData.__v');

    res.json({
      success: true,
      data: jobs
    });
  } catch (error) {
    logger.error('Failed to get sync jobs:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve sync jobs'
    });
  }
});

// Health check for cloud services
router.get('/health', async (req, res) => {
  try {
    const awsHealth = await cloudSyncService.awsService.healthCheck();
    
    res.json({
      success: true,
      data: {
        cloudSync: {
          healthy: true,
          activeSyncs: cloudSyncService.activeSyncs,
          maxConcurrentSyncs: cloudSyncService.maxConcurrentSyncs
        },
        aws: awsHealth
      }
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(500).json({
      success: false,
      error: 'Health check failed'
    });
  }
});

module.exports = router;