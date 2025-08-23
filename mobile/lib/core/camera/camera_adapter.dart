import 'package:flutter/foundation.dart';
import 'dart:async';

import 'i_camera.dart';
import 'camera_factory.dart';
import '../providers/unified_camera_provider.dart';
import '../../models/external_camera.dart';
import '../../models/builtin_camera.dart';
import 'package:camera/camera.dart';

/// Backward-compatible adapter that bridges the old UnifiedCameraProvider
/// with the new ICamera interface WITHOUT breaking existing functionality
/// 
/// This allows gradual migration while maintaining all existing behavior
class CameraAdapter {
  static final CameraAdapter _instance = CameraAdapter._internal();
  factory CameraAdapter() => _instance;
  CameraAdapter._internal();
  
  final CameraFactory _cameraFactory = CameraFactory();
  final Map<String, ICamera> _cameraCache = {};
  
  // Track the current active camera from the new system
  ICamera? _currentActiveCamera;
  StreamSubscription? _statusSubscription;
  
  // Callback to notify when active camera changes
  Function(ICamera?)? onActiveCameraChanged;
  
  /// Get ICamera representation of the currently active camera from UnifiedCameraProvider
  /// This maintains backward compatibility while providing new interface access
  ICamera? getCurrentActiveCamera(UnifiedCameraProvider provider) {
    try {
      if (provider.activeCameraType == null) {
        _setActiveCamera(null);
        return null;
      }
      
      ICamera? camera;
      String cameraId;
      
      switch (provider.activeCameraType!) {
        case CameraSourceType.builtin:
          if (provider.builtinController?.description != null) {
            cameraId = provider.builtinController!.description.name;
            camera = _getOrCreateBuiltinMobileCamera(provider.builtinController!.description);
          }
          break;
          
        case CameraSourceType.external:
          if (provider.activeExternalCamera != null) {
            cameraId = provider.activeExternalCamera!.id;
            camera = _getOrCreateExternalCamera(provider.activeExternalCamera!);
          }
          break;
          
        case CameraSourceType.builtinMacOS:
          if (provider.activeMacOSCamera != null) {
            cameraId = provider.activeMacOSCamera!.id;
            camera = _getOrCreateMacOSCamera(provider.activeMacOSCamera!);
          }
          break;
      }
      
      if (camera != null && camera != _currentActiveCamera) {
        _setActiveCamera(camera);
      }
      
      return camera;
      
    } catch (e) {
      debugPrint('CameraAdapter: Error getting current active camera: $e');
      return null;
    }
  }
  
  /// Get or create a built-in mobile camera ICamera instance
  ICamera _getOrCreateBuiltinMobileCamera(CameraDescription description) {
    final cacheKey = 'builtin_${description.name}';
    
    if (!_cameraCache.containsKey(cacheKey)) {
      _cameraCache[cacheKey] = _cameraFactory.createFromFlutterCamera(description);
      debugPrint('CameraAdapter: Created new built-in mobile camera: ${description.name}');
    }
    
    return _cameraCache[cacheKey]!;
  }
  
  /// Get or create an external camera ICamera instance
  ICamera _getOrCreateExternalCamera(ExternalCamera externalCamera) {
    final cacheKey = 'external_${externalCamera.id}';
    
    if (!_cameraCache.containsKey(cacheKey)) {
      _cameraCache[cacheKey] = _cameraFactory.createFromLegacyExternalCamera(externalCamera);
      debugPrint('CameraAdapter: Created new external camera: ${externalCamera.name}');
    }
    
    return _cameraCache[cacheKey]!;
  }
  
  /// Get or create a macOS built-in camera ICamera instance
  ICamera _getOrCreateMacOSCamera(BuiltInCamera builtInCamera) {
    final cacheKey = 'macos_${builtInCamera.id}';
    
    if (!_cameraCache.containsKey(cacheKey)) {
      _cameraCache[cacheKey] = _cameraFactory.createFromBuiltInCamera(builtInCamera);
      debugPrint('CameraAdapter: Created new macOS camera: ${builtInCamera.name}');
    }
    
    return _cameraCache[cacheKey]!;
  }
  
  /// Set the current active camera and manage subscriptions
  void _setActiveCamera(ICamera? camera) {
    if (_currentActiveCamera == camera) return;
    
    // Clean up previous camera subscription
    _statusSubscription?.cancel();
    
    _currentActiveCamera = camera;
    
    // Set up new camera monitoring
    if (camera != null) {
      _statusSubscription = camera.statusStream.listen((status) {
        debugPrint('CameraAdapter: Camera ${camera.name} status: ${status.isConnected ? "connected" : "disconnected"}');
      });
    }
    
    // Notify listeners
    onActiveCameraChanged?.call(camera);
    
    debugPrint('CameraAdapter: Active camera changed to: ${camera?.name ?? "none"}');
  }
  
  /// Check if the current camera supports manual controls (for AI suggestions)
  bool currentCameraSupportsManualControls(UnifiedCameraProvider provider) {
    final camera = getCurrentActiveCamera(provider);
    if (camera == null) return false;
    
    return camera.capabilities.canApplyManualSettings;
  }
  
  /// Get capability summary for the current camera
  String getCurrentCameraCapabilitySummary(UnifiedCameraProvider provider) {
    final camera = getCurrentActiveCamera(provider);
    if (camera == null) return 'No camera active';
    
    return _cameraFactory.getCapabilitySummary(camera);
  }
  
  /// Check if specific AI suggestion types are applicable to current camera
  bool canApplyAISuggestionType(UnifiedCameraProvider provider, String suggestionType) {
    final camera = getCurrentActiveCamera(provider);
    if (camera == null) return false;
    
    final caps = camera.capabilities;
    
    switch (suggestionType.toLowerCase()) {
      case 'iso':
        return caps.supportsManualISO;
      case 'aperture':
        return caps.supportsManualAperture;
      case 'shutter':
      case 'shutterspeed':
        return caps.supportsManualShutter;
      case 'focus':
        return caps.supportsManualFocus;
      case 'whitebalance':
        return caps.supportsManualWhiteBalance;
      case 'exposure':
      case 'exposurecompensation':
        return caps.supportsExposureCompensation;
      case 'composition':
      case 'lighting':
      case 'technique':
        return true; // Always applicable
      default:
        return true; // Unknown types are allowed by default
    }
  }
  
  /// Get explanation for why a suggestion type isn't applicable
  String getUnsupportedSuggestionExplanation(UnifiedCameraProvider provider, String suggestionType) {
    final camera = getCurrentActiveCamera(provider);
    if (camera == null) return 'No camera active';
    
    if (camera.capabilities.isBuiltInCamera) {
      switch (suggestionType.toLowerCase()) {
        case 'iso':
          return 'Built-in cameras don\'t support manual ISO control. Try improving lighting instead.';
        case 'aperture':
          return 'Built-in cameras don\'t support manual aperture control. Try adjusting your distance from the subject.';
        case 'shutter':
        case 'shutterspeed':
          return 'Built-in cameras don\'t support manual shutter control. The camera automatically adjusts shutter speed.';
        default:
          return 'This manual control is not available on built-in cameras.';
      }
    }
    
    return 'This camera doesn\'t support this type of manual control.';
  }
  
  /// Get debug information about current camera state
  Map<String, dynamic> getDebugInfo(UnifiedCameraProvider provider) {
    final camera = getCurrentActiveCamera(provider);
    
    return {
      'adapter_info': {
        'active_camera_from_new_system': camera?.name,
        'active_camera_type_from_old_system': provider.activeCameraType?.name,
        'cache_size': _cameraCache.length,
        'cached_cameras': _cameraCache.keys.toList(),
      },
      'camera_info': camera?.getCameraInfo(),
      'compatibility_status': {
        'can_use_new_ai_system': camera != null,
        'supports_manual_controls': camera?.capabilities.canApplyManualSettings ?? false,
        'capability_summary': camera != null ? _cameraFactory.getCapabilitySummary(camera) : 'No camera',
      },
    };
  }
  
  /// Clear camera cache (useful for testing)
  void clearCache() {
    _cameraCache.clear();
    _setActiveCamera(null);
    debugPrint('CameraAdapter: Cache cleared');
  }
  
  /// Dispose of adapter resources
  void dispose() {
    _statusSubscription?.cancel();
    _cameraCache.clear();
    _currentActiveCamera = null;
    debugPrint('CameraAdapter: Disposed');
  }
}