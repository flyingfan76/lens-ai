
import 'dart:math' show pow;

class CloudSyncStatus {
  final String syncStatus;
  final DateTime? lastSyncAt;
  final DateTime? nextSyncAt;
  final double syncProgress;
  final DataSyncStatus dataSyncStatus;
  final StorageUsage storageUsage;
  final List<SyncDevice> devices;
  final List<SyncConflict> conflicts;
  final SyncSettings syncSettings;

  CloudSyncStatus({
    required this.syncStatus,
    this.lastSyncAt,
    this.nextSyncAt,
    required this.syncProgress,
    required this.dataSyncStatus,
    required this.storageUsage,
    required this.devices,
    required this.conflicts,
    required this.syncSettings,
  });

  factory CloudSyncStatus.fromJson(Map<String, dynamic> json) {
    return CloudSyncStatus(
      syncStatus: json['syncStatus'] ?? 'idle',
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt']) : null,
      nextSyncAt: json['nextSyncAt'] != null ? DateTime.parse(json['nextSyncAt']) : null,
      syncProgress: (json['syncProgress'] ?? 0.0).toDouble(),
      dataSyncStatus: DataSyncStatus.fromJson(json['dataSyncStatus'] ?? {}),
      storageUsage: StorageUsage.fromJson(json['storageUsage'] ?? {}),
      devices: (json['devices'] as List? ?? [])
          .map((device) => SyncDevice.fromJson(device))
          .toList(),
      conflicts: (json['conflicts'] as List? ?? [])
          .map((conflict) => SyncConflict.fromJson(conflict))
          .toList(),
      syncSettings: SyncSettings.fromJson(json['syncSettings'] ?? {}),
    );
  }

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get isSyncing => syncStatus == 'syncing';
  bool get hasErrors => syncStatus == 'error';
}

class DataSyncStatus {
  final SyncItemStatus photos;
  final SyncItemStatus presets;
  final SyncItemStatus settings;

  DataSyncStatus({
    required this.photos,
    required this.presets,
    required this.settings,
  });

  factory DataSyncStatus.fromJson(Map<String, dynamic> json) {
    return DataSyncStatus(
      photos: SyncItemStatus.fromJson(json['photos'] ?? {}),
      presets: SyncItemStatus.fromJson(json['presets'] ?? {}),
      settings: SyncItemStatus.fromJson(json['settings'] ?? {}),
    );
  }

  int get totalSyncedItems => photos.syncedItems + presets.syncedItems + settings.syncedItems;
  int get totalPendingItems => photos.pendingItems + presets.pendingItems + settings.pendingItems;
  int get totalFailedItems => photos.failedItems + presets.failedItems + settings.failedItems;
}

class SyncItemStatus {
  final DateTime? lastSyncAt;
  final int totalItems;
  final int syncedItems;
  final int pendingItems;
  final int failedItems;

  SyncItemStatus({
    this.lastSyncAt,
    required this.totalItems,
    required this.syncedItems,
    required this.pendingItems,
    required this.failedItems,
  });

  factory SyncItemStatus.fromJson(Map<String, dynamic> json) {
    return SyncItemStatus(
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt']) : null,
      totalItems: json['totalItems'] ?? 0,
      syncedItems: json['syncedItems'] ?? 0,
      pendingItems: json['pendingItems'] ?? 0,
      failedItems: json['failedItems'] ?? 0,
    );
  }

  double get progress {
    if (totalItems == 0) return 1.0;
    return syncedItems / totalItems;
  }
}

class StorageUsage {
  final int totalBytes;
  final int photosBytes;
  final int thumbnailsBytes;
  final int quotaBytes;
  final DateTime? lastCalculatedAt;
  final int objectCount;
  final String formattedSize;

  StorageUsage({
    required this.totalBytes,
    required this.photosBytes,
    required this.thumbnailsBytes,
    required this.quotaBytes,
    this.lastCalculatedAt,
    required this.objectCount,
    required this.formattedSize,
  });

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    return StorageUsage(
      totalBytes: json['totalBytes'] ?? 0,
      photosBytes: json['photosBytes'] ?? 0,
      thumbnailsBytes: json['thumbnailsBytes'] ?? 0,
      quotaBytes: json['quotaBytes'] ?? 5368709120, // 5GB default
      lastCalculatedAt: json['lastCalculatedAt'] != null 
          ? DateTime.parse(json['lastCalculatedAt']) 
          : null,
      objectCount: json['objectCount'] ?? 0,
      formattedSize: json['formattedSize'] ?? '0 Bytes',
    );
  }

  double get usagePercent {
    if (quotaBytes == 0) return 0.0;
    return (totalBytes / quotaBytes).clamp(0.0, 1.0);
  }

  String get quotaFormatted => _formatBytes(quotaBytes);
  
  bool get isNearQuota => usagePercent > 0.8;
  bool get isOverQuota => usagePercent >= 1.0;

  static String _formatBytes(int bytes) {
    if (bytes == 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    
    return '${(bytes / pow(k, i)).toStringAsFixed(2)} ${sizes[i]}';
  }
}

class SyncDevice {
  final String deviceId;
  final String? deviceName;
  final String platform;
  final DateTime lastActiveAt;
  final bool syncEnabled;

  SyncDevice({
    required this.deviceId,
    this.deviceName,
    required this.platform,
    required this.lastActiveAt,
    required this.syncEnabled,
  });

  factory SyncDevice.fromJson(Map<String, dynamic> json) {
    return SyncDevice(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'],
      platform: json['platform'] ?? 'unknown',
      lastActiveAt: DateTime.parse(json['lastActiveAt'] ?? DateTime.now().toIso8601String()),
      syncEnabled: json['syncEnabled'] ?? true,
    );
  }

  String get displayName => deviceName ?? '${platform.capitalize()} Device';
  bool get isCurrentDevice => deviceId == getCurrentDeviceId();
  
  static String getCurrentDeviceId() {
    // Implementation would return actual device ID
    return 'current_device_id';
  }
}

class SyncConflict {
  final String id;
  final String type;
  final String? localId;
  final String? cloudId;
  final String conflictReason;
  final Map<String, dynamic>? localVersion;
  final Map<String, dynamic>? cloudVersion;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolution;

  SyncConflict({
    required this.id,
    required this.type,
    this.localId,
    this.cloudId,
    required this.conflictReason,
    this.localVersion,
    this.cloudVersion,
    required this.detectedAt,
    this.resolvedAt,
    this.resolution,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      localId: json['localId'],
      cloudId: json['cloudId'],
      conflictReason: json['conflictReason'] ?? '',
      localVersion: json['localVersion'],
      cloudVersion: json['cloudVersion'],
      detectedAt: DateTime.parse(json['detectedAt'] ?? DateTime.now().toIso8601String()),
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
      resolution: json['resolution'],
    );
  }

  bool get isResolved => resolvedAt != null;
  String get displayType => type.capitalize();
}

class SyncSettings {
  final bool autoSync;
  final bool syncOnWiFiOnly;
  final bool syncPhotos;
  final bool syncPresets;
  final bool syncSettings;
  final String compressionLevel;
  final String syncFrequency;

  SyncSettings({
    required this.autoSync,
    required this.syncOnWiFiOnly,
    required this.syncPhotos,
    required this.syncPresets,
    required this.syncSettings,
    required this.compressionLevel,
    required this.syncFrequency,
  });

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      autoSync: json['autoSync'] ?? true,
      syncOnWiFiOnly: json['syncOnWiFiOnly'] ?? true,
      syncPhotos: json['syncPhotos'] ?? true,
      syncPresets: json['syncPresets'] ?? true,
      syncSettings: json['syncSettings'] ?? true,
      compressionLevel: json['compressionLevel'] ?? 'medium',
      syncFrequency: json['syncFrequency'] ?? 'hourly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSync': autoSync,
      'syncOnWiFiOnly': syncOnWiFiOnly,
      'syncPhotos': syncPhotos,
      'syncPresets': syncPresets,
      'syncSettings': syncSettings,
      'compressionLevel': compressionLevel,
      'syncFrequency': syncFrequency,
    };
  }

  SyncSettings copyWith({
    bool? autoSync,
    bool? syncOnWiFiOnly,
    bool? syncPhotos,
    bool? syncPresets,
    bool? syncSettings,
    String? compressionLevel,
    String? syncFrequency,
  }) {
    return SyncSettings(
      autoSync: autoSync ?? this.autoSync,
      syncOnWiFiOnly: syncOnWiFiOnly ?? this.syncOnWiFiOnly,
      syncPhotos: syncPhotos ?? this.syncPhotos,
      syncPresets: syncPresets ?? this.syncPresets,
      syncSettings: syncSettings ?? this.syncSettings,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      syncFrequency: syncFrequency ?? this.syncFrequency,
    );
  }
}

class CloudPhoto {
  final String id;
  final String filename;
  final String? originalFilename;
  final String s3Key;
  final String cloudUrl;
  final String? thumbnailUrl;
  final PhotoMetadata metadata;
  final String syncStatus;
  final double uploadProgress;
  final DateTime? capturedAt;
  final DateTime? uploadedAt;

  CloudPhoto({
    required this.id,
    required this.filename,
    this.originalFilename,
    required this.s3Key,
    required this.cloudUrl,
    this.thumbnailUrl,
    required this.metadata,
    required this.syncStatus,
    required this.uploadProgress,
    this.capturedAt,
    this.uploadedAt,
  });

  factory CloudPhoto.fromJson(Map<String, dynamic> json) {
    return CloudPhoto(
      id: json['_id'] ?? json['id'] ?? '',
      filename: json['filename'] ?? '',
      originalFilename: json['originalFilename'],
      s3Key: json['s3Key'] ?? '',
      cloudUrl: json['cloudUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      metadata: PhotoMetadata.fromJson(json['metadata'] ?? {}),
      syncStatus: json['syncStatus'] ?? 'pending',
      uploadProgress: (json['uploadProgress'] ?? 0.0).toDouble(),
      capturedAt: json['capturedAt'] != null ? DateTime.parse(json['capturedAt']) : null,
      uploadedAt: json['uploadedAt'] != null ? DateTime.parse(json['uploadedAt']) : null,
    );
  }

  bool get isSynced => syncStatus == 'synced';
  bool get isPending => syncStatus == 'pending';
  bool get isUploading => syncStatus == 'uploading';
  bool get hasFailed => syncStatus == 'failed';
}

class PhotoMetadata {
  final int? fileSize;
  final PhotoDimensions? dimensions;
  final String? format;
  final ExifData? exifData;
  final ProcessingInfo? processingInfo;

  PhotoMetadata({
    this.fileSize,
    this.dimensions,
    this.format,
    this.exifData,
    this.processingInfo,
  });

  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      fileSize: json['fileSize'],
      dimensions: json['dimensions'] != null 
          ? PhotoDimensions.fromJson(json['dimensions'])
          : null,
      format: json['format'],
      exifData: json['exifData'] != null 
          ? ExifData.fromJson(json['exifData'])
          : null,
      processingInfo: json['processingInfo'] != null 
          ? ProcessingInfo.fromJson(json['processingInfo'])
          : null,
    );
  }
}

class PhotoDimensions {
  final int width;
  final int height;

  PhotoDimensions({required this.width, required this.height});

  factory PhotoDimensions.fromJson(Map<String, dynamic> json) {
    return PhotoDimensions(
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  double get aspectRatio => height != 0 ? width / height : 1.0;
  String get displaySize => '${width}x$height';
}

class ExifData {
  final String? camera;
  final String? lens;
  final int? iso;
  final String? aperture;
  final String? shutterSpeed;
  final double? focalLength;
  final DateTime? capturedAt;
  final GpsLocation? gpsLocation;

  ExifData({
    this.camera,
    this.lens,
    this.iso,
    this.aperture,
    this.shutterSpeed,
    this.focalLength,
    this.capturedAt,
    this.gpsLocation,
  });

  factory ExifData.fromJson(Map<String, dynamic> json) {
    return ExifData(
      camera: json['camera'],
      lens: json['lens'],
      iso: json['iso'],
      aperture: json['aperture'],
      shutterSpeed: json['shutterSpeed'],
      focalLength: json['focalLength']?.toDouble(),
      capturedAt: json['capturedAt'] != null ? DateTime.parse(json['capturedAt']) : null,
      gpsLocation: json['gpsLocation'] != null 
          ? GpsLocation.fromJson(json['gpsLocation'])
          : null,
    );
  }
}

class GpsLocation {
  final double latitude;
  final double longitude;

  GpsLocation({required this.latitude, required this.longitude});

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    return GpsLocation(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

class ProcessingInfo {
  final Map<String, dynamic>? aiAnalysis;
  final String? appliedPreset;
  final Map<String, dynamic>? adjustments;

  ProcessingInfo({
    this.aiAnalysis,
    this.appliedPreset,
    this.adjustments,
  });

  factory ProcessingInfo.fromJson(Map<String, dynamic> json) {
    return ProcessingInfo(
      aiAnalysis: json['aiAnalysis'],
      appliedPreset: json['appliedPreset'],
      adjustments: json['adjustments'],
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Helper for pow function