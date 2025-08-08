import 'package:flutter/foundation.dart';
import 'local_photo_storage.dart';
import 'sync_configuration.dart';

/// Sync status for individual photos
enum PhotoSyncStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped,
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final int totalPhotos;
  final int syncedPhotos;
  final int failedPhotos;
  final int skippedPhotos;
  final Duration duration;

  const SyncResult({
    required this.success,
    this.error,
    required this.totalPhotos,
    required this.syncedPhotos,
    required this.failedPhotos,
    required this.skippedPhotos,
    required this.duration,
  });
}

/// Individual photo sync status
class PhotoSyncInfo {
  final String photoId;
  final PhotoSyncStatus status;
  final String? error;
  final DateTime? syncedAt;
  final List<String> syncedTargets;

  const PhotoSyncInfo({
    required this.photoId,
    required this.status,
    this.error,
    this.syncedAt,
    this.syncedTargets = const [],
  });
}

/// Service to handle photo synchronization
class PhotoSyncService {
  static const String _logTag = 'PhotoSyncService';
  
  static PhotoSyncService? _instance;
  static PhotoSyncService get instance => _instance ??= PhotoSyncService._();
  
  PhotoSyncService._();

  final LocalPhotoStorage _photoStorage = LocalPhotoStorage.instance;
  final SyncConfigurationService _syncConfig = SyncConfigurationService.instance;
  
  bool _isSyncing = false;
  final List<PhotoSyncInfo> _syncStatus = [];
  
  // Stream controller for sync progress (would use actual streams in production)
  void Function(double progress)? onSyncProgress;
  void Function(PhotoSyncInfo info)? onPhotoSyncUpdate;
  void Function(SyncResult result)? onSyncComplete;

  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Get sync status for all photos
  List<PhotoSyncInfo> get syncStatus => List.from(_syncStatus);

  /// Initialize the sync service
  Future<void> initialize() async {
    await _photoStorage.initialize();
    await _syncConfig.initialize();
    debugPrint('$_logTag: Initialized');
  }

  /// Perform manual sync of all unsorted photos
  Future<SyncResult> syncAllPhotos({bool forceSync = false}) async {
    if (_isSyncing) {
      throw Exception('Sync already in progress');
    }

    try {
      _isSyncing = true;
      final startTime = DateTime.now();
      
      debugPrint('$_logTag: Starting sync (force: $forceSync)');
      
      // Get enabled sync targets
      final enabledTargets = _syncConfig.enabledSyncTargets;
      if (enabledTargets.isEmpty) {
        throw Exception('No enabled sync targets configured');
      }

      // Get photos to sync
      final allPhotos = _photoStorage.getAllPhotos();
      final photosToSync = forceSync 
        ? allPhotos
        : allPhotos.where((photo) => !photo.isSynced).toList();

      if (photosToSync.isEmpty) {
        debugPrint('$_logTag: No photos to sync');
        return SyncResult(
          success: true,
          totalPhotos: 0,
          syncedPhotos: 0,
          failedPhotos: 0,
          skippedPhotos: 0,
          duration: DateTime.now().difference(startTime),
        );
      }

      debugPrint('$_logTag: Syncing ${photosToSync.length} photos to ${enabledTargets.length} targets');

      int syncedCount = 0;
      int failedCount = 0;
      int skippedCount = 0;

      // Sync each photo
      for (int i = 0; i < photosToSync.length; i++) {
        final photo = photosToSync[i];
        
        // Update progress
        final progress = (i + 1) / photosToSync.length;
        onSyncProgress?.call(progress);
        
        // Check if photo meets sync criteria
        if (!_shouldSyncPhoto(photo)) {
          skippedCount++;
          _updatePhotoSyncStatus(photo.id, PhotoSyncStatus.skipped, 
            'Photo does not meet sync criteria');
          continue;
        }

        // Update status to in progress
        _updatePhotoSyncStatus(photo.id, PhotoSyncStatus.inProgress, null);

        try {
          // Sync to all enabled targets
          final syncedTargets = <String>[];
          bool photoSyncSuccess = true;
          String? lastError;

          for (final target in enabledTargets) {
            try {
              final success = await _syncPhotoToTarget(photo, target);
              if (success) {
                syncedTargets.add(target.id);
              } else {
                photoSyncSuccess = false;
                lastError = 'Failed to sync to ${target.name}';
              }
            } catch (e) {
              photoSyncSuccess = false;
              lastError = 'Error syncing to ${target.name}: $e';
              debugPrint('$_logTag: Failed to sync ${photo.id} to ${target.name}: $e');
            }
          }

          if (photoSyncSuccess && syncedTargets.isNotEmpty) {
            // Update photo as synced
            await _photoStorage.updatePhotoMetadata(
              photoId: photo.id,
              isSynced: true,
              syncTargets: syncedTargets,
            );
            
            syncedCount++;
            _updatePhotoSyncStatus(photo.id, PhotoSyncStatus.completed, null,
              syncedTargets: syncedTargets);
          } else {
            failedCount++;
            _updatePhotoSyncStatus(photo.id, PhotoSyncStatus.failed, lastError);
          }

        } catch (e) {
          failedCount++;
          _updatePhotoSyncStatus(photo.id, PhotoSyncStatus.failed, e.toString());
          debugPrint('$_logTag: Failed to sync photo ${photo.id}: $e');
        }
      }

      final duration = DateTime.now().difference(startTime);
      final result = SyncResult(
        success: failedCount == 0,
        totalPhotos: photosToSync.length,
        syncedPhotos: syncedCount,
        failedPhotos: failedCount,
        skippedPhotos: skippedCount,
        duration: duration,
      );

      debugPrint('$_logTag: Sync complete - ${result.syncedPhotos}/${result.totalPhotos} synced in ${duration.inSeconds}s');
      
      onSyncComplete?.call(result);
      return result;

    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single photo immediately
  Future<bool> syncPhoto(String photoId) async {
    final photo = _photoStorage.getPhotoById(photoId);
    if (photo == null) {
      throw Exception('Photo not found: $photoId');
    }

    final enabledTargets = _syncConfig.enabledSyncTargets;
    if (enabledTargets.isEmpty) {
      throw Exception('No enabled sync targets configured');
    }

    try {
      _updatePhotoSyncStatus(photoId, PhotoSyncStatus.inProgress, null);
      
      final syncedTargets = <String>[];
      bool success = true;

      for (final target in enabledTargets) {
        try {
          final targetSuccess = await _syncPhotoToTarget(photo, target);
          if (targetSuccess) {
            syncedTargets.add(target.id);
          } else {
            success = false;
          }
        } catch (e) {
          success = false;
          debugPrint('$_logTag: Failed to sync ${photoId} to ${target.name}: $e');
        }
      }

      if (success && syncedTargets.isNotEmpty) {
        await _photoStorage.updatePhotoMetadata(
          photoId: photoId,
          isSynced: true,
          syncTargets: syncedTargets,
        );
        
        _updatePhotoSyncStatus(photoId, PhotoSyncStatus.completed, null,
          syncedTargets: syncedTargets);
        return true;
      } else {
        _updatePhotoSyncStatus(photoId, PhotoSyncStatus.failed,
          'Failed to sync to targets');
        return false;
      }

    } catch (e) {
      _updatePhotoSyncStatus(photoId, PhotoSyncStatus.failed, e.toString());
      return false;
    }
  }

  /// Check if a photo should be synced based on configuration
  bool _shouldSyncPhoto(StoredPhoto photo) {
    final config = _syncConfig.configuration;
    
    // Check file size limit
    if (photo.fileSize > config.maxFileSize * 1024 * 1024) {
      return false;
    }
    
    // Check if already synced (unless force sync)
    if (photo.isSynced && photo.syncTargets.isNotEmpty) {
      return false;
    }
    
    // TODO: Check WiFi condition when connectivity package is available
    // if (config.syncOnWiFiOnly && !isOnWiFi) return false;
    
    return true;
  }

  /// Sync a photo to a specific target (mock implementation)
  Future<bool> _syncPhotoToTarget(StoredPhoto photo, SyncTarget target) async {
    try {
      debugPrint('$_logTag: Syncing ${photo.id} to ${target.name}');
      
      // Mock implementation - in production, this would:
      // 1. Read the photo file
      // 2. Upload to the specific target using its credentials
      // 3. Handle target-specific protocols (REST API, WebDAV, etc.)
      
      // Simulate network delay
      await Future.delayed(Duration(milliseconds: 100 + (photo.fileSize ~/ 1000)));
      
      // Mock success based on target configuration
      final hasCredentials = target.credentials.isNotEmpty;
      final hasSettings = target.settings.isNotEmpty;
      
      switch (target.type) {
        case SyncTargetType.none:
          return false;
        case SyncTargetType.googleDrive:
        case SyncTargetType.dropbox:
        case SyncTargetType.onedrive:
        case SyncTargetType.icloud:
          return hasCredentials;
        case SyncTargetType.customWebDAV:
        case SyncTargetType.localNetwork:
        case SyncTargetType.customAPI:
          return hasCredentials && hasSettings;
      }
      
    } catch (e) {
      debugPrint('$_logTag: Error syncing to ${target.name}: $e');
      return false;
    }
  }

  /// Update sync status for a photo
  void _updatePhotoSyncStatus(
    String photoId, 
    PhotoSyncStatus status, 
    String? error, {
    List<String> syncedTargets = const [],
  }) {
    final existingIndex = _syncStatus.indexWhere((info) => info.photoId == photoId);
    final info = PhotoSyncInfo(
      photoId: photoId,
      status: status,
      error: error,
      syncedAt: status == PhotoSyncStatus.completed ? DateTime.now() : null,
      syncedTargets: syncedTargets,
    );
    
    if (existingIndex >= 0) {
      _syncStatus[existingIndex] = info;
    } else {
      _syncStatus.add(info);
    }
    
    onPhotoSyncUpdate?.call(info);
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    final allPhotos = _photoStorage.getAllPhotos();
    final syncedPhotos = allPhotos.where((p) => p.isSynced).length;
    final pendingPhotos = allPhotos.length - syncedPhotos;
    
    return {
      'totalPhotos': allPhotos.length,
      'syncedPhotos': syncedPhotos,
      'pendingPhotos': pendingPhotos,
      'syncPercentage': allPhotos.isNotEmpty 
        ? (syncedPhotos / allPhotos.length * 100).round()
        : 0,
      'lastSyncAt': _getLastSyncTime(),
      'enabledTargets': _syncConfig.enabledSyncTargets.length,
    };
  }

  /// Get the last sync time from any target
  DateTime? _getLastSyncTime() {
    final targets = _syncConfig.syncTargets;
    DateTime? latest;
    
    for (final target in targets) {
      if (target.lastSyncAt != null) {
        if (latest == null || target.lastSyncAt!.isAfter(latest)) {
          latest = target.lastSyncAt;
        }
      }
    }
    
    return latest;
  }

  /// Cancel current sync operation
  void cancelSync() {
    if (_isSyncing) {
      _isSyncing = false;
      debugPrint('$_logTag: Sync cancelled');
    }
  }

  /// Clear sync status history
  void clearSyncStatus() {
    _syncStatus.clear();
    debugPrint('$_logTag: Sync status cleared');
  }
}