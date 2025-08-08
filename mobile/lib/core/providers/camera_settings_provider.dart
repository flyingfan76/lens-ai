import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/base_state_provider.dart';

/// Camera settings persistence provider
/// 
/// Handles saving and loading user camera preferences, presets, and settings.
/// Focused solely on settings persistence and user preferences.
class CameraSettingsProvider extends BaseStateProvider {
  static const String _keyPrefix = 'lens_ai_camera_';
  static const String _userPreferencesKey = '${_keyPrefix}user_preferences';
  static const String _cameraPresetsKey = '${_keyPrefix}camera_presets';
  static const String _lastUsedSettingsKey = '${_keyPrefix}last_used_settings';
  static const String _uiPreferencesKey = '${_keyPrefix}ui_preferences';
  
  SharedPreferences? _prefs;
  
  // User preferences
  Map<String, dynamic> _userPreferences = {
    'autoSaveSettings': true,
    'useLastSettings': true,
    'enableAdvancedMode': false,
    'defaultCameraMode': 'auto',
    'saveLocationData': false,
    'autoApplyAISettings': true,
    'showCompositionGrid': false,
    'showHistogram': false,
    'enableSoundFeedback': true,
    'previewBrightness': 1.0,
  };
  
  // Camera presets (user-defined and built-in)
  Map<String, Map<String, dynamic>> _cameraPresets = {
    'portrait': {
      'name': 'Portrait',
      'description': 'Optimized for portrait photography',
      'iso': 200.0,
      'aperture': 2.8,
      'shutterSpeed': 125.0,
      'whiteBalance': 'auto',
      'focusMode': 'single',
      'flashMode': false,
      'isBuiltIn': true,
    },
    'landscape': {
      'name': 'Landscape',
      'description': 'Wide aperture for landscapes',
      'iso': 100.0,
      'aperture': 8.0,
      'shutterSpeed': 60.0,
      'whiteBalance': 'daylight',
      'focusMode': 'single',
      'flashMode': false,
      'isBuiltIn': true,
    },
    'lowLight': {
      'name': 'Low Light',
      'description': 'High ISO for low light conditions',
      'iso': 1600.0,
      'aperture': 1.8,
      'shutterSpeed': 30.0,
      'whiteBalance': 'auto',
      'focusMode': 'continuous',
      'flashMode': false,
      'isBuiltIn': true,
    },
    'sports': {
      'name': 'Sports',
      'description': 'Fast shutter for action shots',
      'iso': 800.0,
      'aperture': 4.0,
      'shutterSpeed': 500.0,
      'whiteBalance': 'auto',
      'focusMode': 'continuous',
      'flashMode': false,
      'isBuiltIn': true,
    },
  };
  
  // Last used camera settings
  Map<String, dynamic> _lastUsedSettings = {
    'iso': 400.0,
    'aperture': 2.8,
    'shutterSpeed': 60.0,
    'whiteBalance': 'auto',
    'zoomLevel': 1.0,
    'flashMode': false,
    'lastUsedCamera': null,
    'lastUsedPreset': null,
  };
  
  // UI preferences
  Map<String, dynamic> _uiPreferences = {
    'showAdvancedControls': false,
    'showAISuggestions': false,
    'showCameraControls': false,
    'advancedMode': 'Basic',
    'captureMode': 'photo',
    'gridType': 'thirds', // thirds, golden, none
    'histogramPosition': 'topRight', // topLeft, topRight, bottomLeft, bottomRight
  };
  
  // Getters
  // isInitialized is inherited from BaseStateProvider
  Map<String, dynamic> get userPreferences => Map.from(_userPreferences);
  Map<String, Map<String, dynamic>> get cameraPresets => Map.from(_cameraPresets);
  Map<String, dynamic> get lastUsedSettings => Map.from(_lastUsedSettings);
  Map<String, dynamic> get uiPreferences => Map.from(_uiPreferences);
  
  // Convenience getters for common preferences
  bool get autoSaveSettings => _userPreferences['autoSaveSettings'] ?? true;
  bool get useLastSettings => _userPreferences['useLastSettings'] ?? true;
  bool get enableAdvancedMode => _userPreferences['enableAdvancedMode'] ?? false;
  String get defaultCameraMode => _userPreferences['defaultCameraMode'] ?? 'auto';
  bool get autoApplyAISettings => _userPreferences['autoApplyAISettings'] ?? true;
  bool get showCompositionGrid => _userPreferences['showCompositionGrid'] ?? false;
  bool get showHistogram => _userPreferences['showHistogram'] ?? false;
  double get previewBrightness => _userPreferences['previewBrightness'] ?? 1.0;
  
  /// Override BaseStateProvider's initializeState
  @override
  Future<void> initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAllSettings();
    notifyListeners();
  }
  
  /// Load all settings from storage
  Future<void> _loadAllSettings() async {
    if (_prefs == null) return;
    
    try {
      // Load user preferences
      final userPrefsJson = _prefs!.getString(_userPreferencesKey);
      if (userPrefsJson != null) {
        _userPreferences = {
          ..._userPreferences,
          ...jsonDecode(userPrefsJson),
        };
      }
      
      // Load camera presets (user-defined only, built-ins are hardcoded)
      final presetsJson = _prefs!.getString(_cameraPresetsKey);
      if (presetsJson != null) {
        final savedPresets = jsonDecode(presetsJson) as Map<String, dynamic>;
        // Only add non-built-in presets
        for (final entry in savedPresets.entries) {
          final preset = entry.value as Map<String, dynamic>;
          if (preset['isBuiltIn'] != true) {
            _cameraPresets[entry.key] = Map<String, dynamic>.from(preset);
          }
        }
      }
      
      // Load last used settings
      final lastSettingsJson = _prefs!.getString(_lastUsedSettingsKey);
      if (lastSettingsJson != null) {
        _lastUsedSettings = {
          ..._lastUsedSettings,
          ...jsonDecode(lastSettingsJson),
        };
      }
      
      // Load UI preferences
      final uiPrefsJson = _prefs!.getString(_uiPreferencesKey);
      if (uiPrefsJson != null) {
        _uiPreferences = {
          ..._uiPreferences,
          ...jsonDecode(uiPrefsJson),
        };
      }
      
      debugPrint('Loaded camera settings successfully');
    } catch (e) {
      debugPrint('Error loading camera settings: $e');
    }
  }
  
  /// Save user preferences
  Future<void> saveUserPreferences() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.setString(_userPreferencesKey, jsonEncode(_userPreferences));
      debugPrint('Saved user preferences');
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
    }
  }
  
  /// Save camera presets
  Future<void> saveCameraPresets() async {
    if (_prefs == null) return;
    
    try {
      // Only save user-defined presets (not built-in ones)
      final userPresets = <String, Map<String, dynamic>>{};
      for (final entry in _cameraPresets.entries) {
        final preset = entry.value;
        if (preset['isBuiltIn'] != true) {
          userPresets[entry.key] = preset;
        }
      }
      
      await _prefs!.setString(_cameraPresetsKey, jsonEncode(userPresets));
      debugPrint('Saved camera presets');
    } catch (e) {
      debugPrint('Error saving camera presets: $e');
    }
  }
  
  /// Save last used settings
  Future<void> saveLastUsedSettings() async {
    if (_prefs == null || !autoSaveSettings) return;
    
    try {
      await _prefs!.setString(_lastUsedSettingsKey, jsonEncode(_lastUsedSettings));
      debugPrint('Saved last used settings');
    } catch (e) {
      debugPrint('Error saving last used settings: $e');
    }
  }
  
  /// Save UI preferences
  Future<void> saveUIPreferences() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.setString(_uiPreferencesKey, jsonEncode(_uiPreferences));
      debugPrint('Saved UI preferences');
    } catch (e) {
      debugPrint('Error saving UI preferences: $e');
    }
  }
  
  /// Update user preference
  Future<void> updateUserPreference(String key, dynamic value) async {
    if (_userPreferences[key] != value) {
      _userPreferences[key] = value;
      await saveUserPreferences();
      notifyListeners();
    }
  }
  
  /// Update last used camera settings
  Future<void> updateLastUsedSettings(Map<String, dynamic> settings) async {
    bool changed = false;
    
    for (final entry in settings.entries) {
      if (_lastUsedSettings[entry.key] != entry.value) {
        _lastUsedSettings[entry.key] = entry.value;
        changed = true;
      }
    }
    
    if (changed) {
      await saveLastUsedSettings();
      notifyListeners();
    }
  }
  
  /// Update UI preference
  Future<void> updateUIPreference(String key, dynamic value) async {
    if (_uiPreferences[key] != value) {
      _uiPreferences[key] = value;
      await saveUIPreferences();
      notifyListeners();
    }
  }
  
  /// Create new camera preset
  Future<void> createPreset(String presetId, Map<String, dynamic> settings) async {
    settings['isBuiltIn'] = false;
    settings['createdAt'] = DateTime.now().toIso8601String();
    
    _cameraPresets[presetId] = Map<String, dynamic>.from(settings);
    await saveCameraPresets();
    notifyListeners();
  }
  
  /// Update existing preset
  Future<void> updatePreset(String presetId, Map<String, dynamic> settings) async {
    if (_cameraPresets.containsKey(presetId)) {
      final preset = _cameraPresets[presetId]!;
      
      // Don't allow updating built-in presets
      if (preset['isBuiltIn'] == true) {
        throw Exception('Cannot modify built-in preset');
      }
      
      preset.addAll(settings);
      preset['modifiedAt'] = DateTime.now().toIso8601String();
      
      await saveCameraPresets();
      notifyListeners();
    }
  }
  
  /// Delete preset
  Future<void> deletePreset(String presetId) async {
    if (_cameraPresets.containsKey(presetId)) {
      final preset = _cameraPresets[presetId]!;
      
      // Don't allow deleting built-in presets
      if (preset['isBuiltIn'] == true) {
        throw Exception('Cannot delete built-in preset');
      }
      
      _cameraPresets.remove(presetId);
      await saveCameraPresets();
      notifyListeners();
    }
  }
  
  /// Get preset by ID
  Map<String, dynamic>? getPreset(String presetId) {
    return _cameraPresets[presetId];
  }
  
  /// Get all user-defined presets
  Map<String, Map<String, dynamic>> getUserPresets() {
    return Map.fromEntries(
      _cameraPresets.entries.where((entry) => entry.value['isBuiltIn'] != true),
    );
  }
  
  /// Get all built-in presets
  Map<String, Map<String, dynamic>> getBuiltInPresets() {
    return Map.fromEntries(
      _cameraPresets.entries.where((entry) => entry.value['isBuiltIn'] == true),
    );
  }
  
  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.remove(_userPreferencesKey);
      await _prefs!.remove(_cameraPresetsKey);
      await _prefs!.remove(_lastUsedSettingsKey);
      await _prefs!.remove(_uiPreferencesKey);
      
      // Reset to default values
      _userPreferences = {
        'autoSaveSettings': true,
        'useLastSettings': true,
        'enableAdvancedMode': false,
        'defaultCameraMode': 'auto',
        'saveLocationData': false,
        'autoApplyAISettings': true,
        'showCompositionGrid': false,
        'showHistogram': false,
        'enableSoundFeedback': true,
        'previewBrightness': 1.0,
      };
      
      // Keep only built-in presets
      _cameraPresets.removeWhere((key, value) => value['isBuiltIn'] != true);
      
      _lastUsedSettings = {
        'iso': 400.0,
        'aperture': 2.8,
        'shutterSpeed': 60.0,
        'whiteBalance': 'auto',
        'zoomLevel': 1.0,
        'flashMode': false,
        'lastUsedCamera': null,
        'lastUsedPreset': null,
      };
      
      _uiPreferences = {
        'showAdvancedControls': false,
        'showAISuggestions': false,
        'showCameraControls': false,
        'advancedMode': 'Basic',
        'captureMode': 'photo',
        'gridType': 'thirds',
        'histogramPosition': 'topRight',
      };
      
      notifyListeners();
      debugPrint('Reset camera settings to defaults');
    } catch (e) {
      debugPrint('Error resetting camera settings: $e');
    }
  }
  
  /// Export settings as JSON
  Map<String, dynamic> exportSettings() {
    return {
      'userPreferences': _userPreferences,
      'cameraPresets': getUserPresets(), // Only user presets
      'lastUsedSettings': _lastUsedSettings,
      'uiPreferences': _uiPreferences,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }
  
  /// Import settings from JSON
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      if (settings['userPreferences'] != null) {
        _userPreferences = {
          ..._userPreferences,
          ...settings['userPreferences'],
        };
      }
      
      if (settings['cameraPresets'] != null) {
        final importedPresets = settings['cameraPresets'] as Map<String, dynamic>;
        for (final entry in importedPresets.entries) {
          final preset = entry.value as Map<String, dynamic>;
          preset['isBuiltIn'] = false; // Ensure imported presets are user presets
          _cameraPresets[entry.key] = preset;
        }
      }
      
      if (settings['lastUsedSettings'] != null) {
        _lastUsedSettings = {
          ..._lastUsedSettings,
          ...settings['lastUsedSettings'],
        };
      }
      
      if (settings['uiPreferences'] != null) {
        _uiPreferences = {
          ..._uiPreferences,
          ...settings['uiPreferences'],
        };
      }
      
      // Save all imported settings
      await saveUserPreferences();
      await saveCameraPresets();
      await saveLastUsedSettings();
      await saveUIPreferences();
      
      notifyListeners();
      debugPrint('Imported camera settings successfully');
    } catch (e) {
      debugPrint('Error importing camera settings: $e');
      throw Exception('Failed to import settings: $e');
    }
  }
  
  @override
  void dispose() {
    // ServiceDisposalMixin handles cleanup
    super.dispose();
  }
}