import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'dart:io';

import 'i_camera.dart';
import 'camera_types.dart';
import 'implementations/builtin_mobile_camera.dart';
import 'implementations/builtin_macos_camera.dart';
import 'implementations/external_dslr_camera.dart';
import '../../models/external_camera.dart' as legacy;
import '../../models/builtin_camera.dart';
import '../../services/external_camera_service.dart';

/// Factory class for creating unified camera instances from different sources
/// This is the bridge between the old architecture and the new unified interface
class CameraFactory {
  static final CameraFactory _instance = CameraFactory._internal();
  factory CameraFactory() => _instance;
  CameraFactory._internal();
  
  final ExternalCameraService _externalCameraService = ExternalCameraService();
  
  /// Create ICamera from Flutter CameraDescription (built-in mobile cameras)
  ICamera createFromFlutterCamera(CameraDescription cameraDescription) {
    debugPrint('CameraFactory: Creating built-in mobile camera: ${cameraDescription.name}');
    return BuiltInMobileCamera(cameraDescription);
  }
  
  /// Create ICamera from legacy ExternalCamera
  ICamera createFromLegacyExternalCamera(legacy.ExternalCamera legacyCamera) {
    debugPrint('CameraFactory: Creating external DSLR camera: ${legacyCamera.name}');
    return ExternalDSLRCamera(legacyCamera, _externalCameraService);
  }
  
  /// Create ICamera from BuiltInCamera (macOS desktop cameras)
  ICamera createFromBuiltInCamera(BuiltInCamera builtInCamera) {
    debugPrint('CameraFactory: Creating built-in desktop camera: ${builtInCamera.name}');
    return BuiltInMacOSCamera(builtInCamera);
  }
  
  /// Auto-detect and create cameras from all available sources
  Future<List<ICamera>> discoverAllCameras() async {
    final cameras = <ICamera>[];
    
    try {
      // Discover built-in cameras (iOS/Android only)
      if (Platform.isIOS || Platform.isAndroid) {
        final flutterCameras = await availableCameras();
        for (final camera in flutterCameras) {
          cameras.add(createFromFlutterCamera(camera));
        }
        debugPrint('CameraFactory: Found ${flutterCameras.length} built-in mobile cameras');
      }
      
      // Discover external cameras
      await _externalCameraService.initializeFromStorage();
      await _externalCameraService.startDiscovery();
      
      // Wait a bit for discovery to complete
      await Future.delayed(Duration(seconds: 2));
      
      final externalCameras = _externalCameraService.discoveredCameras;
      for (final camera in externalCameras) {
        cameras.add(createFromLegacyExternalCamera(camera));
      }
      debugPrint('CameraFactory: Found ${externalCameras.length} external cameras');
      
      // TODO: Add macOS built-in camera discovery when implemented
      
    } catch (e) {
      debugPrint('CameraFactory: Error during camera discovery: $e');
    }
    
    debugPrint('CameraFactory: Total cameras discovered: ${cameras.length}');
    return cameras;
  }
  
  /// Get camera type name for display purposes
  String getCameraTypeName(ICamera camera) {
    switch (camera.type) {
      case CameraType.builtInMobile:
        return 'Built-in Mobile';
      case CameraType.builtInDesktop:
        return 'Built-in Desktop';
      case CameraType.dslr:
        return 'DSLR';
      case CameraType.mirrorless:
        return 'Mirrorless';
      case CameraType.compact:
        return 'Compact';
      case CameraType.webcam:
        return 'Webcam';
      default:
        return 'Unknown';
    }
  }
  
  /// Get capability summary for display
  String getCapabilitySummary(ICamera camera) {
    final caps = camera.capabilities;
    final features = <String>[];
    
    if (caps.supportsLiveView) features.add('Live View');
    if (caps.supportsRemoteCapture) features.add('Remote Capture');
    if (caps.supportsVideoRecording) features.add('Video');
    if (caps.canApplyManualSettings) features.add('Manual Controls');
    
    if (features.isEmpty) {
      return 'Basic controls only';
    }
    
    return features.join(', ');
  }
  
  /// Check if a camera is suitable for AI suggestions
  bool isSuitableForAISuggestions(ICamera camera) {
    // All cameras can get composition/lighting suggestions
    // Only cameras with manual controls can get technical suggestions
    return true;
  }
  
  /// Get recommended AI suggestion types for a camera
  List<String> getRecommendedAISuggestionTypes(ICamera camera) {
    final types = <String>['Composition', 'Lighting', 'Technique'];
    
    if (camera.capabilities.canApplyManualSettings) {
      types.addAll(['Exposure Settings', 'Focus Control', 'Creative Effects']);
    } else {
      types.add('Alternative Approaches');
    }
    
    return types;
  }
  
  /// Create a debug info map for a camera
  Map<String, dynamic> getCameraDebugInfo(ICamera camera) {
    return {
      'basic_info': {
        'id': camera.id,
        'name': camera.name,
        'model': camera.model,
        'type': camera.type.displayName,
        'brand': camera.brand.displayName,
        'platform': camera.platform.displayName,
      },
      'connection': {
        'is_connected': camera.isConnected,
        'is_live_view_active': camera.isLiveViewActive,
        'is_recording': camera.isRecording,
      },
      'capabilities': camera.capabilities.toJson(),
      'supported_settings': camera.supportedSettings.map((s) => s.displayName).toList(),
      'full_info': camera.getCameraInfo(),
    };
  }
}