import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'base_state_provider.dart';
import '../utils/lens_exceptions.dart';

/// Persistent state provider for automatic settings persistence
/// 
/// Provides unified persistence capabilities for all app state including:
/// - Automatic state serialization and deserialization
/// - Multiple storage backends (SharedPreferences, File, Database)
/// - State versioning and migration
/// - Backup and restore functionality
/// - Encryption for sensitive data
class PersistentStateProvider extends BaseStateProvider {
  static const String _globalStateKey = 'lens_ai_global_persistent_state';
  
  // Storage backends
  SharedPreferences? _prefs;
  Directory? _documentsDir;
  
  // Registered state providers
  final Map<String, BaseStateProvider> _registeredProviders = {};
  final Map<String, String> _providerStorageKeys = {};
  
  // Persistence configuration
  bool _autoSaveEnabled = true;
  Duration _autoSaveInterval = const Duration(seconds: 30);
  bool _useFileStorage = false;
  bool _useEncryption = false;
  String _encryptionKey = '';
  
  // State versioning
  int _currentVersion = 1;
  Map<int, Function(Map<String, dynamic>)> _migrationHandlers = {};
  
  // Backup configuration
  bool _autoBackupEnabled = false;
  Duration _backupInterval = const Duration(hours: 24);
  int _maxBackups = 5;
  
  // Performance optimization
  Timer? _autoSaveTimer;
  Timer? _backupTimer;
  final Map<String, DateTime> _lastSaveTime = {};
  final Map<String, dynamic> _pendingChanges = {};
  bool _isSaving = false;
  
  // State tracking
  Map<String, dynamic> _globalState = {};
  
  // Getters
  bool get autoSaveEnabled => _autoSaveEnabled;
  Duration get autoSaveInterval => _autoSaveInterval;
  bool get useFileStorage => _useFileStorage;
  bool get useEncryption => _useEncryption;
  bool get autoBackupEnabled => _autoBackupEnabled;
  int get currentVersion => _currentVersion;
  Map<String, BaseStateProvider> get registeredProviders => Map.from(_registeredProviders);
  
  @override
  Future<void> initializeState() async {
    // Initialize storage backends
    _prefs = await SharedPreferences.getInstance();
    
    if (!kIsWeb) {
      try {
        _documentsDir = await getApplicationDocumentsDirectory();
      } catch (e) {
        debugPrint('Failed to get documents directory: $e');
      }
    }
    
    // Load global persistent state
    await _loadGlobalState();
    
    // Set up auto-save if enabled
    if (_autoSaveEnabled) {
      _setupAutoSave();
    }
    
    // Set up auto-backup if enabled
    if (_autoBackupEnabled) {
      _setupAutoBackup();
    }
  }
  
  /// Register a state provider for automatic persistence
  Future<void> registerProvider(
    String providerId,
    BaseStateProvider provider, {
    String? customStorageKey,
    bool autoSave = true,
  }) async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      _registeredProviders[providerId] = provider;
      _providerStorageKeys[providerId] = customStorageKey ?? '${_globalStateKey}_$providerId';
      
      // Load existing state for this provider if it supports persistence
      if (provider is StatePersistenceMixin) {
        await _loadProviderState(providerId, provider);
      }
      
      debugPrint('Registered state provider: $providerId');
    }, operationName: 'register provider $providerId');
  }
  
  /// Unregister a state provider
  Future<void> unregisterProvider(String providerId) async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      // Save final state before unregistering
      if (_registeredProviders.containsKey(providerId)) {
        await _saveProviderState(providerId);
      }
      
      _registeredProviders.remove(providerId);
      _providerStorageKeys.remove(providerId);
      _lastSaveTime.remove(providerId);
      _pendingChanges.remove(providerId);
      
      debugPrint('Unregistered state provider: $providerId');
    }, operationName: 'unregister provider $providerId');
  }
  
  /// Load state for a specific provider
  Future<void> _loadProviderState(String providerId, BaseStateProvider provider) async {
    if (provider is! StatePersistenceMixin) return;
    
    try {
      final storageKey = _providerStorageKeys[providerId];
      if (storageKey == null) return;
      
      Map<String, dynamic>? state;
      
      if (_useFileStorage && _documentsDir != null) {
        state = await _loadFromFile(storageKey);
      } else if (_prefs != null) {
        state = await _loadFromPreferences(storageKey);
      }
      
      if (state != null) {
        // Check version and migrate if necessary
        final version = state['version'] ?? 1;
        if (version < _currentVersion) {
          state = await _migrateState(state, version, _currentVersion);
        }
        
        // Restore provider state
        await provider.restorePersistedState(state);
        
        debugPrint('Loaded state for provider: $providerId');
      }
    } catch (e) {
      debugPrint('Failed to load state for provider $providerId: $e');
    }
  }
  
  /// Save state for a specific provider
  Future<void> _saveProviderState(String providerId) async {
    final provider = _registeredProviders[providerId];
    if (provider == null || provider is! StatePersistenceMixin) return;
    
    try {
      final state = provider.getPersistedState();
      
      // Add metadata
      state['version'] = _currentVersion;
      state['savedAt'] = DateTime.now().toIso8601String();
      state['providerId'] = providerId;
      
      final storageKey = _providerStorageKeys[providerId];
      if (storageKey == null) return;
      
      if (_useFileStorage && _documentsDir != null) {
        await _saveToFile(storageKey, state);
      } else if (_prefs != null) {
        await _saveToPreferences(storageKey, state);
      }
      
      _lastSaveTime[providerId] = DateTime.now();
      _pendingChanges.remove(providerId);
      
      debugPrint('Saved state for provider: $providerId');
    } catch (e) {
      debugPrint('Failed to save state for provider $providerId: $e');
    }
  }
  
  /// Save state for all registered providers
  Future<void> saveAllProviderStates() async {
    if (!validateState() || _isSaving) return;
    
    await executeWithErrorHandling(() async {
      _isSaving = true;
      
      final futures = <Future>[];
      for (final providerId in _registeredProviders.keys) {
        futures.add(_saveProviderState(providerId));
      }
      
      await Future.wait(futures);
      await _saveGlobalState();
      
      _isSaving = false;
    }, 
    operationName: 'save all provider states',
    showLoadingState: true,
    loadingMessage: 'Saving settings...',
    );
  }
  
  /// Load global persistent state
  Future<void> _loadGlobalState() async {
    try {
      Map<String, dynamic>? state;
      
      if (_useFileStorage && _documentsDir != null) {
        state = await _loadFromFile(_globalStateKey);
      } else if (_prefs != null) {
        state = await _loadFromPreferences(_globalStateKey);
      }
      
      if (state != null) {
        _globalState = state;
        
        // Load configuration from global state
        _autoSaveEnabled = state['autoSaveEnabled'] ?? _autoSaveEnabled;
        _autoSaveInterval = Duration(
          seconds: state['autoSaveIntervalSeconds'] ?? _autoSaveInterval.inSeconds
        );
        _useFileStorage = state['useFileStorage'] ?? _useFileStorage;
        _useEncryption = state['useEncryption'] ?? _useEncryption;
        _autoBackupEnabled = state['autoBackupEnabled'] ?? _autoBackupEnabled;
        _backupInterval = Duration(
          hours: state['backupIntervalHours'] ?? _backupInterval.inHours
        );
        _maxBackups = state['maxBackups'] ?? _maxBackups;
        _currentVersion = state['currentVersion'] ?? _currentVersion;
        
        debugPrint('Loaded global persistent state');
      }
    } catch (e) {
      debugPrint('Failed to load global state: $e');
    }
  }
  
  /// Save global persistent state
  Future<void> _saveGlobalState() async {
    try {
      _globalState = {
        'autoSaveEnabled': _autoSaveEnabled,
        'autoSaveIntervalSeconds': _autoSaveInterval.inSeconds,
        'useFileStorage': _useFileStorage,
        'useEncryption': _useEncryption,
        'autoBackupEnabled': _autoBackupEnabled,
        'backupIntervalHours': _backupInterval.inHours,
        'maxBackups': _maxBackups,
        'currentVersion': _currentVersion,
        'registeredProviders': _registeredProviders.keys.toList(),
        'lastSaveTime': _lastSaveTime.map((k, v) => MapEntry(k, v.toIso8601String())),
        'savedAt': DateTime.now().toIso8601String(),
        'version': _currentVersion,
      };
      
      if (_useFileStorage && _documentsDir != null) {
        await _saveToFile(_globalStateKey, _globalState);
      } else if (_prefs != null) {
        await _saveToPreferences(_globalStateKey, _globalState);
      }
      
      // Global state saved at ${DateTime.now()}
    } catch (e) {
      debugPrint('Failed to save global state: $e');
    }
  }
  
  /// Load state from SharedPreferences
  Future<Map<String, dynamic>?> _loadFromPreferences(String key) async {
    if (_prefs == null) return null;
    
    try {
      final stateJson = _prefs!.getString(key);
      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        return _useEncryption ? _decryptState(state) : state;
      }
    } catch (e) {
      debugPrint('Failed to load from preferences [$key]: $e');
    }
    
    return null;
  }
  
  /// Save state to SharedPreferences
  Future<void> _saveToPreferences(String key, Map<String, dynamic> state) async {
    if (_prefs == null) return;
    
    try {
      final finalState = _useEncryption ? _encryptState(state) : state;
      await _prefs!.setString(key, jsonEncode(finalState));
    } catch (e) {
      debugPrint('Failed to save to preferences [$key]: $e');
      rethrow;
    }
  }
  
  /// Load state from file
  Future<Map<String, dynamic>?> _loadFromFile(String key) async {
    if (_documentsDir == null) return null;
    
    try {
      final file = File('${_documentsDir!.path}/$key.json');
      if (await file.exists()) {
        final stateJson = await file.readAsString();
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        return _useEncryption ? _decryptState(state) : state;
      }
    } catch (e) {
      debugPrint('Failed to load from file [$key]: $e');
    }
    
    return null;
  }
  
  /// Save state to file
  Future<void> _saveToFile(String key, Map<String, dynamic> state) async {
    if (_documentsDir == null) return;
    
    try {
      final file = File('${_documentsDir!.path}/$key.json');
      final finalState = _useEncryption ? _encryptState(state) : state;
      await file.writeAsString(jsonEncode(finalState));
    } catch (e) {
      debugPrint('Failed to save to file [$key]: $e');
      rethrow;
    }
  }
  
  /// Encrypt state (placeholder - implement with actual encryption)
  Map<String, dynamic> _encryptState(Map<String, dynamic> state) {
    // Placeholder for encryption implementation
    // In a real app, you would use proper encryption libraries
    return {
      'encrypted': true,
      'data': base64Encode(utf8.encode(jsonEncode(state))),
      'key': _encryptionKey.isNotEmpty ? _encryptionKey.hashCode : 0,
    };
  }
  
  /// Decrypt state (placeholder - implement with actual decryption)
  Map<String, dynamic> _decryptState(Map<String, dynamic> encryptedState) {
    // Placeholder for decryption implementation
    if (encryptedState['encrypted'] == true) {
      try {
        final data = encryptedState['data'] as String;
        final decrypted = utf8.decode(base64Decode(data));
        return jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to decrypt state: $e');
        return {};
      }
    }
    return encryptedState;
  }
  
  /// Migrate state from old version to new version
  Future<Map<String, dynamic>> _migrateState(
    Map<String, dynamic> state,
    int fromVersion,
    int toVersion,
  ) async {
    var migratedState = Map<String, dynamic>.from(state);
    
    for (int version = fromVersion; version < toVersion; version++) {
      final migrationHandler = _migrationHandlers[version + 1];
      if (migrationHandler != null) {
        try {
          migrationHandler(migratedState);
          migratedState['version'] = version + 1;
          debugPrint('Migrated state from version $version to ${version + 1}');
        } catch (e) {
          debugPrint('Failed to migrate state from version $version: $e');
          break;
        }
      }
    }
    
    return migratedState;
  }
  
  /// Set up auto-save timer
  void _setupAutoSave() {
    _autoSaveTimer?.cancel();
    
    if (_autoSaveEnabled) {
      _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
        if (!_isSaving) {
          _performAutoSave();
        }
      });
      
      addCleanupFunction(() => _autoSaveTimer?.cancel());
    }
  }
  
  /// Perform automatic save
  Future<void> _performAutoSave() async {
    try {
      // Only save providers that have changes
      final providersToSave = <String>[];
      
      for (final providerId in _registeredProviders.keys) {
        final lastSave = _lastSaveTime[providerId];
        if (lastSave == null || 
            DateTime.now().difference(lastSave) >= _autoSaveInterval) {
          providersToSave.add(providerId);
        }
      }
      
      if (providersToSave.isNotEmpty) {
        _isSaving = true;
        
        final futures = <Future>[];
        for (final providerId in providersToSave) {
          futures.add(_saveProviderState(providerId));
        }
        
        await Future.wait(futures);
        await _saveGlobalState();
        
        _isSaving = false;
        
        debugPrint('Auto-saved ${providersToSave.length} providers');
      }
    } catch (e) {
      _isSaving = false;
      debugPrint('Auto-save failed: $e');
    }
  }
  
  /// Set up auto-backup timer
  void _setupAutoBackup() {
    _backupTimer?.cancel();
    
    if (_autoBackupEnabled && _documentsDir != null) {
      _backupTimer = Timer.periodic(_backupInterval, (timer) {
        _performBackup();
      });
      
      addCleanupFunction(() => _backupTimer?.cancel());
    }
  }
  
  /// Perform backup
  Future<void> _performBackup() async {
    if (_documentsDir == null) return;
    
    try {
      final backupDir = Directory('${_documentsDir!.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile = File('${backupDir.path}/backup_$timestamp.json');
      
      // Create backup with all provider states
      final backup = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'version': _currentVersion,
        'globalState': _globalState,
        'providerStates': <String, dynamic>{},
      };
      
      // Add all provider states to backup
      for (final entry in _registeredProviders.entries) {
        final providerId = entry.key;
        final provider = entry.value;
        
        if (provider is StatePersistenceMixin) {
          backup['providerStates'][providerId] = provider.getPersistedState();
        }
      }
      
      await backupFile.writeAsString(jsonEncode(backup));
      
      // Clean up old backups
      await _cleanupOldBackups(backupDir);
      
      debugPrint('Created backup: ${backupFile.path}');
    } catch (e) {
      debugPrint('Backup failed: $e');
    }
  }
  
  /// Clean up old backups
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final backupFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      if (backupFiles.length > _maxBackups) {
        // Sort by modification time (oldest first)
        backupFiles.sort((a, b) => 
          a.statSync().modified.compareTo(b.statSync().modified));
        
        // Delete oldest backups
        for (int i = 0; i < backupFiles.length - _maxBackups; i++) {
          await backupFiles[i].delete();
          debugPrint('Deleted old backup: ${backupFiles[i].path}');
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old backups: $e');
    }
  }
  
  /// Restore from backup
  Future<bool> restoreFromBackup(String backupPath) async {
    return await executeWithErrorHandling<bool>(() async {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw LensException.now(
          message: 'Backup file not found',
          category: 'Backup',
          details: 'File: $backupPath',
        );
      }
      
      final backupJson = await backupFile.readAsString();
      final backup = jsonDecode(backupJson) as Map<String, dynamic>;
      
      // Restore global state
      final globalState = backup['globalState'] as Map<String, dynamic>?;
      if (globalState != null) {
        _globalState = globalState;
        await _saveGlobalState();
      }
      
      // Restore provider states
      final providerStates = backup['providerStates'] as Map<String, dynamic>?;
      if (providerStates != null) {
        for (final entry in providerStates.entries) {
          final providerId = entry.key;
          final state = entry.value as Map<String, dynamic>;
          
          final provider = _registeredProviders[providerId];
          if (provider != null && provider is StatePersistenceMixin) {
            await provider.restorePersistedState(state);
            await _saveProviderState(providerId);
          }
        }
      }
      
      debugPrint('Restored from backup: $backupPath');
      return true;
    }, 
    operationName: 'restore from backup',
    showLoadingState: true,
    loadingMessage: 'Restoring backup...',
    fallbackValue: false,
    ) ?? false;
  }
  
  /// Get list of available backups
  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    if (_documentsDir == null) return [];
    
    try {
      final backupDir = Directory('${_documentsDir!.path}/backups');
      if (!await backupDir.exists()) return [];
      
      final backupFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      final backups = <Map<String, dynamic>>[];
      
      for (final file in backupFiles) {
        try {
          final stat = file.statSync();
          final name = file.path.split('/').last.replaceAll('.json', '');
          
          backups.add({
            'name': name,
            'path': file.path,
            'size': stat.size,
            'created': stat.modified.toIso8601String(),
          });
        } catch (e) {
          debugPrint('Failed to read backup file info: ${file.path}');
        }
      }
      
      // Sort by creation time (newest first)
      backups.sort((a, b) => 
        DateTime.parse(b['created']).compareTo(DateTime.parse(a['created'])));
      
      return backups;
    } catch (e) {
      debugPrint('Failed to get available backups: $e');
      return [];
    }
  }
  
  // Configuration methods
  
  /// Set auto-save enabled
  void setAutoSaveEnabled(bool enabled) {
    if (_autoSaveEnabled != enabled) {
      _autoSaveEnabled = enabled;
      _setupAutoSave();
      notifyListeners();
    }
  }
  
  /// Set auto-save interval
  void setAutoSaveInterval(Duration interval) {
    if (_autoSaveInterval != interval) {
      _autoSaveInterval = interval;
      _setupAutoSave();
      notifyListeners();
    }
  }
  
  /// Set file storage enabled
  void setFileStorageEnabled(bool enabled) {
    if (_useFileStorage != enabled) {
      _useFileStorage = enabled;
      notifyListeners();
    }
  }
  
  /// Set encryption enabled
  void setEncryptionEnabled(bool enabled, {String? encryptionKey}) {
    if (_useEncryption != enabled) {
      _useEncryption = enabled;
      if (enabled && encryptionKey != null) {
        _encryptionKey = encryptionKey;
      }
      notifyListeners();
    }
  }
  
  /// Set auto-backup enabled
  void setAutoBackupEnabled(bool enabled) {
    if (_autoBackupEnabled != enabled) {
      _autoBackupEnabled = enabled;
      _setupAutoBackup();
      notifyListeners();
    }
  }
  
  /// Add migration handler
  void addMigrationHandler(int version, Function(Map<String, dynamic>) handler) {
    _migrationHandlers[version] = handler;
  }
  
  /// Clear all persisted data
  Future<void> clearAllPersistedData() async {
    await executeWithErrorHandling(() async {
      // Clear SharedPreferences
      if (_prefs != null) {
        final keys = _prefs!.getKeys().where((key) => 
          key.startsWith(_globalStateKey)).toList();
        for (final key in keys) {
          await _prefs!.remove(key);
        }
      }
      
      // Clear files
      if (_documentsDir != null) {
        final files = _documentsDir!
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains(_globalStateKey))
            .toList();
        
        for (final file in files) {
          await file.delete();
        }
      }
      
      // Reset internal state
      _globalState.clear();
      _lastSaveTime.clear();
      _pendingChanges.clear();
      
      debugPrint('Cleared all persisted data');
      notifyListeners();
    }, 
    operationName: 'clear all persisted data',
    showLoadingState: true,
    loadingMessage: 'Clearing data...',
    );
  }
  
  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _backupTimer?.cancel();
    super.dispose();
  }
}