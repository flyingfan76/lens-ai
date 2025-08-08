import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_state_provider.dart';

/// Global application state provider
/// 
/// Manages app-wide state including:
/// - Theme mode and preferences
/// - User preferences and settings
/// - App configuration
/// - Navigation state
/// - Performance settings
class AppStateProvider extends BaseStateProvider with StatePersistenceMixin {
  static const String _storageKey = 'lens_ai_app_state';
  
  // Theme state
  ThemeMode _themeMode = ThemeMode.system;
  bool _useSystemTheme = true;
  double _textScaleFactor = 1.0;
  bool _useHighContrast = false;
  bool _reducedAnimations = false;
  
  // User preferences
  String _preferredLanguage = 'en';
  bool _enableNotifications = true;
  bool _enableAnalytics = false;
  bool _enableCrashReporting = true;
  bool _enablePerformanceMonitoring = false;
  
  // App configuration
  bool _isFirstLaunch = true;
  String _appVersion = '1.0.0';
  DateTime? _lastLaunchTime;
  int _launchCount = 0;
  bool _onboardingCompleted = false;
  
  // Performance settings
  bool _enableDebugMode = false;
  bool _showPerformanceOverlay = false;
  bool _enableMemoryOptimizations = true;
  bool _enableBatteryOptimizations = true;
  
  // Navigation state
  String _currentRoute = '/';
  Map<String, dynamic> _navigationHistory = {};
  
  // Feature flags
  Map<String, bool> _featureFlags = {
    'advanced_ai_features': true,
    'cloud_sync': false,
    'professional_mode': false,
    'beta_features': false,
    'experimental_ui': false,
  };
  
  SharedPreferences? _prefs;
  
  // Getters - Theme
  ThemeMode get themeMode => _themeMode;
  bool get useSystemTheme => _useSystemTheme;
  double get textScaleFactor => _textScaleFactor;
  bool get useHighContrast => _useHighContrast;
  bool get reducedAnimations => _reducedAnimations;
  
  // Getters - User preferences  
  String get preferredLanguage => _preferredLanguage;
  bool get enableNotifications => _enableNotifications;
  bool get enableAnalytics => _enableAnalytics;
  bool get enableCrashReporting => _enableCrashReporting;
  bool get enablePerformanceMonitoring => _enablePerformanceMonitoring;
  
  // Getters - App configuration
  bool get isFirstLaunch => _isFirstLaunch;
  String get appVersion => _appVersion;
  DateTime? get lastLaunchTime => _lastLaunchTime;
  int get launchCount => _launchCount;
  bool get onboardingCompleted => _onboardingCompleted;
  
  // Getters - Performance
  bool get enableDebugMode => _enableDebugMode;
  bool get showPerformanceOverlay => _showPerformanceOverlay;
  bool get enableMemoryOptimizations => _enableMemoryOptimizations;
  bool get enableBatteryOptimizations => _enableBatteryOptimizations;
  
  // Getters - Navigation
  String get currentRoute => _currentRoute;
  Map<String, dynamic> get navigationHistory => Map.from(_navigationHistory);
  
  // Getters - Feature flags
  Map<String, bool> get featureFlags => Map.from(_featureFlags);
  
  @override
  String get persistenceKey => _storageKey;
  
  @override
  Future<void> initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    await loadState();
    
    // Update app launch tracking
    await _updateLaunchTracking();
  }
  
  /// Update launch tracking information
  Future<void> _updateLaunchTracking() async {
    await executeWithErrorHandling(() async {
      _lastLaunchTime = DateTime.now();
      _launchCount++;
      _isFirstLaunch = _launchCount == 1;
      
      await saveState();
    }, operationName: 'update launch tracking');
  }
  
  // Theme management methods
  
  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      await executeWithErrorHandling(() async {
        _themeMode = mode;
        _useSystemTheme = mode == ThemeMode.system;
        await saveState();
        notifyListeners();
      }, operationName: 'set theme mode');
    }
  }
  
  /// Set text scale factor
  Future<void> setTextScaleFactor(double factor) async {
    final clampedFactor = factor.clamp(0.8, 2.0);
    if (_textScaleFactor != clampedFactor) {
      await executeWithErrorHandling(() async {
        _textScaleFactor = clampedFactor;
        await saveState();
        notifyListeners();
      }, operationName: 'set text scale factor');
    }
  }
  
  /// Set high contrast mode
  Future<void> setHighContrast(bool enabled) async {
    if (_useHighContrast != enabled) {
      await executeWithErrorHandling(() async {
        _useHighContrast = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set high contrast');
    }
  }
  
  /// Set reduced animations
  Future<void> setReducedAnimations(bool enabled) async {
    if (_reducedAnimations != enabled) {
      await executeWithErrorHandling(() async {
        _reducedAnimations = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set reduced animations');
    }
  }
  
  // User preferences methods
  
  /// Set preferred language
  Future<void> setPreferredLanguage(String language) async {
    if (_preferredLanguage != language) {
      await executeWithErrorHandling(() async {
        _preferredLanguage = language;
        await saveState();
        notifyListeners();
      }, operationName: 'set preferred language');
    }
  }
  
  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_enableNotifications != enabled) {
      await executeWithErrorHandling(() async {
        _enableNotifications = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set notifications enabled');
    }
  }
  
  /// Set analytics enabled
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_enableAnalytics != enabled) {
      await executeWithErrorHandling(() async {
        _enableAnalytics = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set analytics enabled');
    }
  }
  
  /// Set crash reporting enabled
  Future<void> setCrashReportingEnabled(bool enabled) async {
    if (_enableCrashReporting != enabled) {
      await executeWithErrorHandling(() async {
        _enableCrashReporting = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set crash reporting enabled');
    }
  }
  
  /// Set performance monitoring enabled
  Future<void> setPerformanceMonitoringEnabled(bool enabled) async {
    if (_enablePerformanceMonitoring != enabled) {
      await executeWithErrorHandling(() async {
        _enablePerformanceMonitoring = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set performance monitoring enabled');
    }
  }
  
  // App configuration methods
  
  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    if (!_onboardingCompleted) {
      await executeWithErrorHandling(() async {
        _onboardingCompleted = true;
        await saveState();
        notifyListeners();
      }, operationName: 'complete onboarding');
    }
  }
  
  /// Reset onboarding state
  Future<void> resetOnboarding() async {
    if (_onboardingCompleted) {
      await executeWithErrorHandling(() async {
        _onboardingCompleted = false;
        await saveState();
        notifyListeners();
      }, operationName: 'reset onboarding');
    }
  }
  
  // Performance settings methods
  
  /// Set debug mode
  Future<void> setDebugMode(bool enabled) async {
    if (_enableDebugMode != enabled) {
      await executeWithErrorHandling(() async {
        _enableDebugMode = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set debug mode');
    }
  }
  
  /// Set performance overlay
  Future<void> setPerformanceOverlay(bool enabled) async {
    if (_showPerformanceOverlay != enabled) {
      await executeWithErrorHandling(() async {
        _showPerformanceOverlay = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set performance overlay');
    }
  }
  
  /// Set memory optimizations
  Future<void> setMemoryOptimizations(bool enabled) async {
    if (_enableMemoryOptimizations != enabled) {
      await executeWithErrorHandling(() async {
        _enableMemoryOptimizations = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set memory optimizations');
    }
  }
  
  /// Set battery optimizations
  Future<void> setBatteryOptimizations(bool enabled) async {
    if (_enableBatteryOptimizations != enabled) {
      await executeWithErrorHandling(() async {
        _enableBatteryOptimizations = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set battery optimizations');
    }
  }
  
  // Navigation methods
  
  /// Update current route
  void updateCurrentRoute(String route, {Map<String, dynamic>? arguments}) {
    if (_currentRoute != route) {
      batchStateUpdates(() {
        // Add to history
        _navigationHistory[DateTime.now().toIso8601String()] = {
          'route': _currentRoute,
          'newRoute': route,
          'arguments': arguments,
        };
        
        // Keep only last 10 navigation entries for memory efficiency
        if (_navigationHistory.length > 10) {
          final keys = _navigationHistory.keys.toList()..sort();
          final oldestKey = keys.first;
          _navigationHistory.remove(oldestKey);
        }
        
        _currentRoute = route;
      });
      
      // Save navigation state (fire and forget)
      saveState().catchError((e) {
        debugPrint('Failed to save navigation state: $e');
      });
    }
  }
  
  // Feature flag methods
  
  /// Check if feature is enabled
  bool isFeatureEnabled(String feature) {
    return _featureFlags[feature] ?? false;
  }
  
  /// Set feature flag
  Future<void> setFeatureFlag(String feature, bool enabled) async {
    if (_featureFlags[feature] != enabled) {
      await executeWithErrorHandling(() async {
        _featureFlags[feature] = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set feature flag $feature');
    }
  }
  
  /// Enable multiple features
  Future<void> enableFeatures(List<String> features) async {
    await executeWithErrorHandling(() async {
      bool hasChanges = false;
      
      batchStateUpdates(() {
        for (final feature in features) {
          if (_featureFlags[feature] != true) {
            _featureFlags[feature] = true;
            hasChanges = true;
          }
        }
      });
      
      if (hasChanges) {
        await saveState();
      }
    }, operationName: 'enable features');
  }
  
  // State persistence implementation
  
  @override
  Map<String, dynamic> getPersistedState() {
    return {
      'theme': {
        'themeMode': _themeMode.index,
        'useSystemTheme': _useSystemTheme,
        'textScaleFactor': _textScaleFactor,
        'useHighContrast': _useHighContrast,
        'reducedAnimations': _reducedAnimations,
      },
      'userPreferences': {
        'preferredLanguage': _preferredLanguage,
        'enableNotifications': _enableNotifications,
        'enableAnalytics': _enableAnalytics,
        'enableCrashReporting': _enableCrashReporting,
        'enablePerformanceMonitoring': _enablePerformanceMonitoring,
      },
      'appConfiguration': {
        'isFirstLaunch': _isFirstLaunch,
        'appVersion': _appVersion,
        'lastLaunchTime': _lastLaunchTime?.toIso8601String(),
        'launchCount': _launchCount,
        'onboardingCompleted': _onboardingCompleted,
      },
      'performance': {
        'enableDebugMode': _enableDebugMode,
        'showPerformanceOverlay': _showPerformanceOverlay,
        'enableMemoryOptimizations': _enableMemoryOptimizations,
        'enableBatteryOptimizations': _enableBatteryOptimizations,
      },
      'navigation': {
        'currentRoute': _currentRoute,
        'navigationHistory': _navigationHistory,
      },
      'featureFlags': _featureFlags,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  Future<void> restorePersistedState(Map<String, dynamic> state) async {
    batchStateUpdates(() {
      // Restore theme settings
      final theme = state['theme'] as Map<String, dynamic>? ?? {};
      _themeMode = ThemeMode.values[theme['themeMode'] ?? ThemeMode.system.index];
      _useSystemTheme = theme['useSystemTheme'] ?? true;
      _textScaleFactor = theme['textScaleFactor'] ?? 1.0;
      _useHighContrast = theme['useHighContrast'] ?? false;
      _reducedAnimations = theme['reducedAnimations'] ?? false;
      
      // Restore user preferences
      final userPrefs = state['userPreferences'] as Map<String, dynamic>? ?? {};
      _preferredLanguage = userPrefs['preferredLanguage'] ?? 'en';
      _enableNotifications = userPrefs['enableNotifications'] ?? true;
      _enableAnalytics = userPrefs['enableAnalytics'] ?? false;
      _enableCrashReporting = userPrefs['enableCrashReporting'] ?? true;
      _enablePerformanceMonitoring = userPrefs['enablePerformanceMonitoring'] ?? false;
      
      // Restore app configuration
      final appConfig = state['appConfiguration'] as Map<String, dynamic>? ?? {};
      _isFirstLaunch = appConfig['isFirstLaunch'] ?? true;
      _appVersion = appConfig['appVersion'] ?? '1.0.0';
      _launchCount = appConfig['launchCount'] ?? 0;
      _onboardingCompleted = appConfig['onboardingCompleted'] ?? false;
      
      final lastLaunchStr = appConfig['lastLaunchTime'] as String?;
      if (lastLaunchStr != null) {
        _lastLaunchTime = DateTime.tryParse(lastLaunchStr);
      }
      
      // Restore performance settings
      final performance = state['performance'] as Map<String, dynamic>? ?? {};
      _enableDebugMode = performance['enableDebugMode'] ?? false;
      _showPerformanceOverlay = performance['showPerformanceOverlay'] ?? false;
      _enableMemoryOptimizations = performance['enableMemoryOptimizations'] ?? true;
      _enableBatteryOptimizations = performance['enableBatteryOptimizations'] ?? true;
      
      // Restore navigation state
      final navigation = state['navigation'] as Map<String, dynamic>? ?? {};
      _currentRoute = navigation['currentRoute'] ?? '/';
      _navigationHistory = Map<String, dynamic>.from(navigation['navigationHistory'] ?? {});
      
      // Restore feature flags
      final flags = state['featureFlags'] as Map<String, dynamic>? ?? {};
      for (final entry in flags.entries) {
        _featureFlags[entry.key] = entry.value ?? false;
      }
    });
  }
  
  @override
  Future<void> saveState() async {
    if (_prefs == null) return;
    
    try {
      final state = getPersistedState();
      await _prefs!.setString(_storageKey, jsonEncode(state));
    } catch (e) {
      debugPrint('Failed to save app state: $e');
    }
  }
  
  @override
  Future<void> loadState() async {
    if (_prefs == null) return;
    
    try {
      final stateJson = _prefs!.getString(_storageKey);
      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        await restorePersistedState(state);
      }
    } catch (e) {
      debugPrint('Failed to load app state: $e');
    }
  }
  
  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await executeWithErrorHandling(() async {
      if (_prefs != null) {
        await _prefs!.remove(_storageKey);
      }
      
      batchStateUpdates(() {
        _themeMode = ThemeMode.system;
        _useSystemTheme = true;
        _textScaleFactor = 1.0;
        _useHighContrast = false;
        _reducedAnimations = false;
        
        _preferredLanguage = 'en';
        _enableNotifications = true;
        _enableAnalytics = false;
        _enableCrashReporting = true;
        _enablePerformanceMonitoring = false;
        
        _enableDebugMode = false;
        _showPerformanceOverlay = false;
        _enableMemoryOptimizations = true;
        _enableBatteryOptimizations = true;
        
        _navigationHistory.clear();
        _currentRoute = '/';
        
        // Reset feature flags to defaults
        _featureFlags = {
          'advanced_ai_features': true,
          'cloud_sync': false,
          'professional_mode': false,
          'beta_features': false,
          'experimental_ui': false,
        };
        
        // Don't reset app configuration like launch count, onboarding, etc.
      });
      
      await saveState();
    }, operationName: 'reset to defaults');
  }
  
  /// Export app settings
  Map<String, dynamic> exportSettings() {
    return {
      'appState': getPersistedState(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }
  
  /// Import app settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    await executeWithErrorHandling(() async {
      final appState = settings['appState'] as Map<String, dynamic>?;
      if (appState != null) {
        await restorePersistedState(appState);
        await saveState();
        notifyListeners();
      }
    }, operationName: 'import settings');
  }
}