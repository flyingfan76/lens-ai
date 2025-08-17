import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app_state_provider.dart';
import 'camera_feature_provider.dart';
import 'ai_feature_provider.dart';
import 'ui_state_provider.dart';
import 'persistent_state_provider.dart';
import 'error_state_provider.dart';

// Legacy providers for backward compatibility
import '../providers/mobile_camera_provider.dart';
import '../providers/camera_state_provider.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/unified_camera_provider.dart';
import '../../services/ai/ai_coordinator.dart';

/// Central state management coordinator
/// 
/// Manages the initialization and coordination of all state providers
/// in the Lens AI application, ensuring proper dependencies and
/// initialization order.
class StateManager {
  // Unified state providers
  late final AppStateProvider appStateProvider;
  late final CameraFeatureProvider cameraFeatureProvider;  
  late final AIFeatureProvider aiFeatureProvider;
  late final UIStateProvider uiStateProvider;
  late final PersistentStateProvider persistentStateProvider;
  late final ErrorStateProvider errorStateProvider;
  
  // Unified camera provider
  late final UnifiedCameraProvider unifiedCameraProvider;
  
  // Legacy providers (for backward compatibility during migration)
  late final MobileCameraProvider mobileCameraProvider;
  late final CameraStateProvider cameraStateProvider;
  late final CameraSettingsProvider cameraSettingsProvider;
  late final AICoordinator aiCoordinator;
  
  bool _initialized = false;
  
  StateManager._();
  
  /// Initialize the complete state management system
  static Future<StateManager> initialize() async {
    final manager = StateManager._();
    await manager._initializeProviders();
    return manager;
  }
  
  /// Initialize all state providers in correct dependency order
  Future<void> _initializeProviders() async {
    if (_initialized) return;
    
    debugPrint('Initializing unified state management system...');
    
    try {
      // Step 1: Initialize core infrastructure providers
      debugPrint('Step 1: Initializing infrastructure providers...');
      
      // Error state provider (must be first for error handling)
      errorStateProvider = ErrorStateProvider();
      await errorStateProvider.initialize();
      
      // UI state provider (no dependencies)
      uiStateProvider = UIStateProvider();
      await uiStateProvider.initialize();
      
      // App state provider (no dependencies)
      appStateProvider = AppStateProvider();
      await appStateProvider.initialize();
      
      // Persistent state provider (no dependencies)
      persistentStateProvider = PersistentStateProvider();
      await persistentStateProvider.initialize();
      
      // Step 2: Initialize legacy providers for backward compatibility
      debugPrint('Step 2: Initializing legacy providers...');
      
      // AI Coordinator
      aiCoordinator = AICoordinator();
      await aiCoordinator.initialize();
      
      // Camera Settings Provider
      cameraSettingsProvider = CameraSettingsProvider();
      await cameraSettingsProvider.initialize();
      
      // Unified Camera Provider (new external camera support)
      unifiedCameraProvider = UnifiedCameraProvider();
      
      // Mobile Camera Provider
      mobileCameraProvider = MobileCameraProvider();
      
      // Camera State Provider
      cameraStateProvider = CameraStateProvider();
      
      // Step 3: Initialize feature providers with dependencies
      debugPrint('Step 3: Initializing feature providers...');
      
      // Camera feature provider (depends on hardware providers)
      cameraFeatureProvider = CameraFeatureProvider();
      cameraFeatureProvider.setCameraProvider(mobileCameraProvider);
      await cameraFeatureProvider.initialize();
      
      // AI feature provider (depends on AI coordinator)
      aiFeatureProvider = AIFeatureProvider();
      aiFeatureProvider.setAICoordinator(aiCoordinator);
      await aiFeatureProvider.initialize();
      
      // Step 4: Register providers for persistence
      debugPrint('Step 4: Setting up persistence...');
      
      await persistentStateProvider.registerProvider('app_state', appStateProvider);
      await persistentStateProvider.registerProvider('camera_feature', cameraFeatureProvider);
      await persistentStateProvider.registerProvider('ai_feature', aiFeatureProvider);
      await persistentStateProvider.registerProvider('camera_settings', cameraSettingsProvider);
      
      // Step 5: Register providers for error monitoring
      debugPrint('Step 5: Setting up error monitoring...');
      
      errorStateProvider.registerProviderForMonitoring('app_state', appStateProvider);
      errorStateProvider.registerProviderForMonitoring('camera_feature', cameraFeatureProvider);
      errorStateProvider.registerProviderForMonitoring('ai_feature', aiFeatureProvider);
      errorStateProvider.registerProviderForMonitoring('ui_state', uiStateProvider);
      errorStateProvider.registerProviderForMonitoring('mobile_camera', mobileCameraProvider);
      errorStateProvider.registerProviderForMonitoring('camera_state', cameraStateProvider);
      errorStateProvider.registerProviderForMonitoring('camera_settings', cameraSettingsProvider);
      
      _initialized = true;
      debugPrint('State management system initialized successfully!');
      
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize state management system: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Get list of providers for MultiProvider
  List<SingleChildWidget> getProviders() {
    if (!_initialized) {
      throw StateError('StateManager not initialized. Call StateManager.initialize() first.');
    }
    
    return [
      // Core unified state providers
      ChangeNotifierProvider<AppStateProvider>.value(value: appStateProvider),
      ChangeNotifierProvider<CameraFeatureProvider>.value(value: cameraFeatureProvider),
      ChangeNotifierProvider<AIFeatureProvider>.value(value: aiFeatureProvider),
      ChangeNotifierProvider<UIStateProvider>.value(value: uiStateProvider),
      ChangeNotifierProvider<PersistentStateProvider>.value(value: persistentStateProvider),
      ChangeNotifierProvider<ErrorStateProvider>.value(value: errorStateProvider),
      
      // Unified camera provider
      ChangeNotifierProvider<UnifiedCameraProvider>.value(value: unifiedCameraProvider),
      
      // Legacy providers (for backward compatibility)
      ChangeNotifierProvider<MobileCameraProvider>.value(value: mobileCameraProvider),
      ChangeNotifierProvider<CameraStateProvider>.value(value: cameraStateProvider),
      ChangeNotifierProvider<CameraSettingsProvider>.value(value: cameraSettingsProvider),
      Provider<AICoordinator>.value(value: aiCoordinator),
    ];
  }
  
  /// Save all state providers
  Future<void> saveAllStates() async {
    if (!_initialized) return;
    
    try {
      await persistentStateProvider.saveAllProviderStates();
      debugPrint('All states saved successfully');
    } catch (e) {
      debugPrint('Failed to save states: $e');
      errorStateProvider.reportError(
        Exception('Failed to save application states: $e'),
        source: 'state_manager',
      );
    }
  }
  
  /// Get state statistics for debugging
  Map<String, dynamic> getStateStatistics() {
    if (!_initialized) return {'initialized': false};
    
    return {
      'initialized': _initialized,
      'providers': {
        'app_state': {
          'initialized': appStateProvider.isInitialized,
          'error': appStateProvider.hasError,
        },
        'camera_feature': {
          'initialized': cameraFeatureProvider.isInitialized,
          'error': cameraFeatureProvider.hasError,
          'connected': cameraFeatureProvider.isConnected,
        },
        'ai_feature': {
          'initialized': aiFeatureProvider.isInitialized,
          'error': aiFeatureProvider.hasError,
          'service_available': aiFeatureProvider.aiServiceAvailable,
        },
        'ui_state': {
          'initialized': uiStateProvider.isInitialized,
          'error': uiStateProvider.hasError,
          'loading_states': uiStateProvider.loadingStates.length,
        },
        'persistent_state': {
          'initialized': persistentStateProvider.isInitialized,
          'error': persistentStateProvider.hasError,
          'registered_providers': persistentStateProvider.registeredProviders.length,
        },
        'error_state': {
          'initialized': errorStateProvider.isInitialized,
          'active_errors': errorStateProvider.activeErrorCount,
          'critical_errors': errorStateProvider.hasCriticalErrors,
        },
      },
      'error_statistics': errorStateProvider.getErrorStatistics(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Reset all providers to initial state
  Future<void> resetAllStates() async {
    if (!_initialized) return;
    
    try {
      debugPrint('Resetting all state providers...');
      
      // Reset unified providers
      appStateProvider.resetToDefaults();
      cameraFeatureProvider.resetState();
      aiFeatureProvider.resetState();
      uiStateProvider.resetAllUIState();
      errorStateProvider.resolveAllErrors(resolution: 'System reset');
      
      // Reset legacy providers
      cameraStateProvider.resetToDefaults();
      await cameraSettingsProvider.resetToDefaults();
      
      debugPrint('All states reset successfully');
    } catch (e) {
      debugPrint('Failed to reset states: $e');
      errorStateProvider.reportError(
        Exception('Failed to reset application states: $e'),
        source: 'state_manager',
      );
    }
  }
  
  /// Dispose all providers
  Future<void> dispose() async {
    if (!_initialized) return;
    
    debugPrint('Disposing state management system...');
    
    try {
      // Save states before disposing
      await saveAllStates();
      
      // Dispose unified providers
      errorStateProvider.dispose();
      persistentStateProvider.dispose();
      uiStateProvider.dispose();
      aiFeatureProvider.dispose();
      cameraFeatureProvider.dispose();
      appStateProvider.dispose();
      
      // Dispose legacy providers
      cameraStateProvider.dispose();
      cameraSettingsProvider.dispose();
      mobileCameraProvider.dispose();
      // Note: AICoordinator disposal handled by its own lifecycle
      
      _initialized = false;
      debugPrint('State management system disposed successfully');
    } catch (e) {
      debugPrint('Error during state manager disposal: $e');
    }
  }
  
  /// Check if system is healthy
  bool get isHealthy {
    if (!_initialized) return false;
    
    return !appStateProvider.hasError &&
           !cameraFeatureProvider.hasError &&
           !aiFeatureProvider.hasError &&
           !uiStateProvider.hasError &&
           !persistentStateProvider.hasError &&
           !errorStateProvider.hasCriticalErrors;
  }
  
  /// Get system health report
  Map<String, dynamic> getHealthReport() {
    return {
      'healthy': isHealthy,
      'initialized': _initialized,
      'critical_errors': _initialized ? errorStateProvider.hasCriticalErrors : false,
      'active_error_count': _initialized ? errorStateProvider.activeErrorCount : 0,
      'provider_errors': _initialized ? {
        'app_state': appStateProvider.hasError,
        'camera_feature': cameraFeatureProvider.hasError,
        'ai_feature': aiFeatureProvider.hasError,
        'ui_state': uiStateProvider.hasError,
        'persistent_state': persistentStateProvider.hasError,
        'error_state': errorStateProvider.hasError,
      } : {},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}