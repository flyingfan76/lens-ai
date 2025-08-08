import 'package:flutter/foundation.dart';

/// Supported sync target types
enum SyncTargetType {
  none,
  googleDrive,
  icloud,
  dropbox,
  onedrive,
  customWebDAV,
  localNetwork,
  customAPI,
}

/// Configuration for a sync target
class SyncTarget {
  final String id;
  final SyncTargetType type;
  final String name;
  final Map<String, dynamic> credentials;
  final Map<String, dynamic> settings;
  final bool isEnabled;
  final DateTime? lastSyncAt;
  final String? lastSyncError;

  const SyncTarget({
    required this.id,
    required this.type,
    required this.name,
    this.credentials = const {},
    this.settings = const {},
    this.isEnabled = false,
    this.lastSyncAt,
    this.lastSyncError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'credentials': credentials,
      'settings': settings,
      'isEnabled': isEnabled,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'lastSyncError': lastSyncError,
    };
  }

  factory SyncTarget.fromJson(Map<String, dynamic> json) {
    return SyncTarget(
      id: json['id'],
      type: SyncTargetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncTargetType.none,
      ),
      name: json['name'],
      credentials: Map<String, dynamic>.from(json['credentials'] ?? {}),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      isEnabled: json['isEnabled'] ?? false,
      lastSyncAt: json['lastSyncAt'] != null 
        ? DateTime.parse(json['lastSyncAt'])
        : null,
      lastSyncError: json['lastSyncError'],
    );
  }

  SyncTarget copyWith({
    String? id,
    SyncTargetType? type,
    String? name,
    Map<String, dynamic>? credentials,
    Map<String, dynamic>? settings,
    bool? isEnabled,
    DateTime? lastSyncAt,
    String? lastSyncError,
  }) {
    return SyncTarget(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      credentials: credentials ?? this.credentials,
      settings: settings ?? this.settings,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }
}

/// Sync configuration and preferences
class SyncConfiguration {
  final bool autoSyncEnabled;
  final bool syncOnWiFiOnly;
  final bool syncOriginalPhotos;
  final bool syncThumbnails;
  final bool syncMetadata;
  final bool syncAIAnalysis;
  final int maxFileSize; // in MB
  final List<String> excludedFolders;
  final int syncIntervalMinutes;
  final bool deleteAfterSync;
  final SyncTargetType defaultSyncTarget;

  const SyncConfiguration({
    this.autoSyncEnabled = false,
    this.syncOnWiFiOnly = true,
    this.syncOriginalPhotos = true,
    this.syncThumbnails = false,
    this.syncMetadata = true,
    this.syncAIAnalysis = true,
    this.maxFileSize = 50, // 50MB default
    this.excludedFolders = const [],
    this.syncIntervalMinutes = 60, // 1 hour
    this.deleteAfterSync = false,
    this.defaultSyncTarget = SyncTargetType.none,
  });

  Map<String, dynamic> toJson() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'syncOnWiFiOnly': syncOnWiFiOnly,
      'syncOriginalPhotos': syncOriginalPhotos,
      'syncThumbnails': syncThumbnails,
      'syncMetadata': syncMetadata,
      'syncAIAnalysis': syncAIAnalysis,
      'maxFileSize': maxFileSize,
      'excludedFolders': excludedFolders,
      'syncIntervalMinutes': syncIntervalMinutes,
      'deleteAfterSync': deleteAfterSync,
      'defaultSyncTarget': defaultSyncTarget.name,
    };
  }

  factory SyncConfiguration.fromJson(Map<String, dynamic> json) {
    return SyncConfiguration(
      autoSyncEnabled: json['autoSyncEnabled'] ?? false,
      syncOnWiFiOnly: json['syncOnWiFiOnly'] ?? true,
      syncOriginalPhotos: json['syncOriginalPhotos'] ?? true,
      syncThumbnails: json['syncThumbnails'] ?? false,
      syncMetadata: json['syncMetadata'] ?? true,
      syncAIAnalysis: json['syncAIAnalysis'] ?? true,
      maxFileSize: json['maxFileSize'] ?? 50,
      excludedFolders: List<String>.from(json['excludedFolders'] ?? []),
      syncIntervalMinutes: json['syncIntervalMinutes'] ?? 60,
      deleteAfterSync: json['deleteAfterSync'] ?? false,
      defaultSyncTarget: SyncTargetType.values.firstWhere(
        (e) => e.name == json['defaultSyncTarget'],
        orElse: () => SyncTargetType.none,
      ),
    );
  }

  SyncConfiguration copyWith({
    bool? autoSyncEnabled,
    bool? syncOnWiFiOnly,
    bool? syncOriginalPhotos,
    bool? syncThumbnails,
    bool? syncMetadata,
    bool? syncAIAnalysis,
    int? maxFileSize,
    List<String>? excludedFolders,
    int? syncIntervalMinutes,
    bool? deleteAfterSync,
    SyncTargetType? defaultSyncTarget,
  }) {
    return SyncConfiguration(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncOnWiFiOnly: syncOnWiFiOnly ?? this.syncOnWiFiOnly,
      syncOriginalPhotos: syncOriginalPhotos ?? this.syncOriginalPhotos,
      syncThumbnails: syncThumbnails ?? this.syncThumbnails,
      syncMetadata: syncMetadata ?? this.syncMetadata,
      syncAIAnalysis: syncAIAnalysis ?? this.syncAIAnalysis,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      deleteAfterSync: deleteAfterSync ?? this.deleteAfterSync,
      defaultSyncTarget: defaultSyncTarget ?? this.defaultSyncTarget,
    );
  }
}

/// Sync configuration service
class SyncConfigurationService {
  static const String _logTag = 'SyncConfiguration';
  
  static SyncConfigurationService? _instance;
  static SyncConfigurationService get instance => _instance ??= SyncConfigurationService._();
  
  SyncConfigurationService._();

  SyncConfiguration _config = const SyncConfiguration();
  List<SyncTarget> _syncTargets = [];
  bool _isInitialized = false;

  /// Initialize the sync configuration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // TODO: Load from persistent storage when available
      await _loadConfiguration();
      await _loadSyncTargets();
      
      _isInitialized = true;
      debugPrint('$_logTag: Initialized with ${_syncTargets.length} sync targets');
      
    } catch (e) {
      debugPrint('$_logTag: Failed to initialize: $e');
      // Continue with default configuration
      _isInitialized = true;
    }
  }

  /// Get current sync configuration
  SyncConfiguration get configuration => _config;

  /// Update sync configuration
  Future<void> updateConfiguration(SyncConfiguration newConfig) async {
    _config = newConfig;
    await _saveConfiguration();
    debugPrint('$_logTag: Configuration updated');
  }

  /// Get all configured sync targets
  List<SyncTarget> get syncTargets => List.from(_syncTargets);

  /// Get enabled sync targets only
  List<SyncTarget> get enabledSyncTargets => 
      _syncTargets.where((target) => target.isEnabled).toList();

  /// Add or update a sync target
  Future<void> addOrUpdateSyncTarget(SyncTarget target) async {
    final existingIndex = _syncTargets.indexWhere((t) => t.id == target.id);
    
    if (existingIndex >= 0) {
      _syncTargets[existingIndex] = target;
    } else {
      _syncTargets.add(target);
    }
    
    await _saveSyncTargets();
    debugPrint('$_logTag: ${existingIndex >= 0 ? 'Updated' : 'Added'} sync target: ${target.name}');
  }

  /// Remove a sync target
  Future<bool> removeSyncTarget(String targetId) async {
    final originalLength = _syncTargets.length;
    _syncTargets.removeWhere((target) => target.id == targetId);
    final removed = originalLength != _syncTargets.length;
    
    if (removed) {
      await _saveSyncTargets();
      debugPrint('$_logTag: Removed sync target: $targetId');
      return true;
    }
    
    return false;
  }

  /// Get sync target by ID
  SyncTarget? getSyncTarget(String targetId) {
    try {
      return _syncTargets.firstWhere((target) => target.id == targetId);
    } catch (e) {
      return null;
    }
  }

  /// Test connection to a sync target
  Future<bool> testSyncTarget(SyncTarget target) async {
    try {
      debugPrint('$_logTag: Testing connection to ${target.name}');
      
      // Mock implementation - in production, this would test actual connectivity
      switch (target.type) {
        case SyncTargetType.none:
          return false;
        case SyncTargetType.googleDrive:
        case SyncTargetType.icloud:
        case SyncTargetType.dropbox:
        case SyncTargetType.onedrive:
          return target.credentials.isNotEmpty;
        case SyncTargetType.customWebDAV:
        case SyncTargetType.localNetwork:
        case SyncTargetType.customAPI:
          return target.settings['url'] != null;
      }
    } catch (e) {
      debugPrint('$_logTag: Test failed for ${target.name}: $e');
      return false;
    }
  }

  /// Check if any sync targets are configured
  bool get hasSyncTargets => _syncTargets.any((target) => target.isEnabled);

  /// Check if auto-sync is enabled and conditions are met
  bool get shouldAutoSync {
    if (!_config.autoSyncEnabled) return false;
    if (!hasSyncTargets) return false;
    
    // TODO: Check WiFi condition when connectivity package is available
    // if (_config.syncOnWiFiOnly && !isOnWiFi) return false;
    
    return true;
  }

  /// Get sync target display information
  String getSyncTargetDisplayName(SyncTargetType type) {
    switch (type) {
      case SyncTargetType.none:
        return 'No Sync';
      case SyncTargetType.googleDrive:
        return 'Google Drive';
      case SyncTargetType.icloud:
        return 'iCloud';
      case SyncTargetType.dropbox:
        return 'Dropbox';
      case SyncTargetType.onedrive:
        return 'OneDrive';
      case SyncTargetType.customWebDAV:
        return 'WebDAV Server';
      case SyncTargetType.localNetwork:
        return 'Local Network';
      case SyncTargetType.customAPI:
        return 'Custom API';
    }
  }

  /// Get sync target configuration requirements
  Map<String, dynamic> getSyncTargetRequirements(SyncTargetType type) {
    switch (type) {
      case SyncTargetType.none:
        return {};
      case SyncTargetType.googleDrive:
        return {
          'credentials': ['oauth_token', 'refresh_token'],
          'settings': ['folder_path'],
        };
      case SyncTargetType.icloud:
        return {
          'credentials': ['apple_id', 'app_password'],
          'settings': ['folder_path'],
        };
      case SyncTargetType.dropbox:
        return {
          'credentials': ['access_token'],
          'settings': ['folder_path'],
        };
      case SyncTargetType.onedrive:
        return {
          'credentials': ['access_token', 'refresh_token'],
          'settings': ['folder_path'],
        };
      case SyncTargetType.customWebDAV:
        return {
          'credentials': ['username', 'password'],
          'settings': ['url', 'folder_path'],
        };
      case SyncTargetType.localNetwork:
        return {
          'credentials': ['username', 'password'],
          'settings': ['host', 'port', 'protocol', 'folder_path'],
        };
      case SyncTargetType.customAPI:
        return {
          'credentials': ['api_key', 'api_secret'],
          'settings': ['endpoint_url', 'upload_method'],
        };
    }
  }

  /// Create a default sync target configuration
  SyncTarget createDefaultSyncTarget(SyncTargetType type) {
    final id = 'sync_${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    final name = getSyncTargetDisplayName(type);
    
    return SyncTarget(
      id: id,
      type: type,
      name: name,
      isEnabled: false,
    );
  }

  /// Mock storage methods (replace with actual persistent storage)
  Future<void> _loadConfiguration() async {
    // TODO: Load from shared preferences or secure storage
    // For now, use default configuration
    debugPrint('$_logTag: Using default configuration');
  }

  Future<void> _saveConfiguration() async {
    // TODO: Save to shared preferences or secure storage
    debugPrint('$_logTag: Configuration saved (mock)');
  }

  Future<void> _loadSyncTargets() async {
    // TODO: Load from persistent storage
    // For now, use empty list
    debugPrint('$_logTag: No sync targets loaded (mock)');
  }

  Future<void> _saveSyncTargets() async {
    // TODO: Save to persistent storage
    debugPrint('$_logTag: Sync targets saved (mock)');
  }

  /// Reset all sync configuration to defaults
  Future<void> resetToDefaults() async {
    _config = const SyncConfiguration();
    _syncTargets.clear();
    await _saveConfiguration();
    await _saveSyncTargets();
    debugPrint('$_logTag: Reset to default configuration');
  }
}