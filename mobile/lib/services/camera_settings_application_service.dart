import 'package:flutter/foundation.dart';
import '../models/ai_suggestion.dart';
import '../models/external_camera.dart';
import 'libgphoto2_service.dart';
import '../core/providers/unified_camera_provider.dart';
import '../core/state/camera_feature_provider.dart';

/// Service responsible for applying AI suggestions to external cameras
class CameraSettingsApplicationService {
  static final CameraSettingsApplicationService _instance = 
      CameraSettingsApplicationService._internal();
  factory CameraSettingsApplicationService() => _instance;
  CameraSettingsApplicationService._internal();

  final LibGPhoto2Service _libGPhoto2Service = LibGPhoto2Service();

  /// Apply a single AI suggestion to the active external camera
  Future<bool> applySuggestion({
    required AISuggestion suggestion,
    required UnifiedCameraProvider cameraProvider,
    required CameraFeatureProvider featureProvider,
  }) async {
    if (!suggestion.actionable || suggestion.action == null) {
      debugPrint('CameraSettingsApplicationService: Suggestion ${suggestion.id} is not actionable');
      return false;
    }

    final settings = suggestion.action!.settings;
    debugPrint('CameraSettingsApplicationService: Applying suggestion "${suggestion.title}" with settings: $settings');

    return await _applySettingsToCamera(
      settings: settings,
      cameraProvider: cameraProvider,
      featureProvider: featureProvider,
    );
  }

  /// Apply multiple AI suggestions in bulk
  Future<List<String>> applyMultipleSuggestions({
    required List<AISuggestion> suggestions,
    required UnifiedCameraProvider cameraProvider,
    required CameraFeatureProvider featureProvider,
  }) async {
    final List<String> appliedSuggestions = [];
    final Map<String, dynamic> combinedSettings = {};

    // Combine all actionable suggestions
    for (final suggestion in suggestions) {
      if (suggestion.actionable && suggestion.action != null) {
        combinedSettings.addAll(suggestion.action!.settings);
        appliedSuggestions.add(suggestion.title);
      }
    }

    if (combinedSettings.isEmpty) {
      debugPrint('CameraSettingsApplicationService: No actionable suggestions to apply');
      return [];
    }

    debugPrint('CameraSettingsApplicationService: Applying ${suggestions.length} suggestions with combined settings: $combinedSettings');

    final success = await _applySettingsToCamera(
      settings: combinedSettings,
      cameraProvider: cameraProvider,
      featureProvider: featureProvider,
    );

    return success ? appliedSuggestions : [];
  }

  /// Apply camera settings to the active camera
  Future<bool> _applySettingsToCamera({
    required Map<String, dynamic> settings,
    required UnifiedCameraProvider cameraProvider,
    required CameraFeatureProvider featureProvider,
  }) async {
    final activeCamera = cameraProvider.activeExternalCamera;
    
    if (activeCamera == null) {
      debugPrint('CameraSettingsApplicationService: No active external camera');
      return false;
    }

    if (!activeCamera.isConnected) {
      debugPrint('CameraSettingsApplicationService: Camera ${activeCamera.name} is not connected');
      return false;
    }

    bool overallSuccess = true;
    final List<String> successfulSettings = [];
    final List<String> failedSettings = [];

    for (final entry in settings.entries) {
      final settingName = entry.key;
      final value = entry.value;

      try {
        bool success = false;

        // Apply setting based on camera type and connection
        if (activeCamera.connectionType == CameraConnectionType.usb) {
          success = await _applyUSBCameraSetting(settingName, value);
        } else if (activeCamera.connectionType == CameraConnectionType.wifi) {
          success = await _applyWiFiCameraSetting(settingName, value, activeCamera);
        }

        if (success) {
          successfulSettings.add(settingName);
          // Update the feature provider state
          _updateFeatureProviderState(settingName, value, featureProvider);
        } else {
          failedSettings.add(settingName);
          overallSuccess = false;
        }

      } catch (e) {
        debugPrint('CameraSettingsApplicationService: Error applying $settingName = $value: $e');
        failedSettings.add(settingName);
        overallSuccess = false;
      }
    }

    debugPrint('CameraSettingsApplicationService: Applied ${successfulSettings.length} settings successfully');
    if (failedSettings.isNotEmpty) {
      debugPrint('CameraSettingsApplicationService: Failed to apply ${failedSettings.length} settings: $failedSettings');
    }

    return overallSuccess;
  }

  /// Apply setting to USB-connected camera using libgphoto2
  Future<bool> _applyUSBCameraSetting(String settingName, dynamic value) async {
    debugPrint('CameraSettingsApplicationService: Applying USB setting $settingName = $value');

    // Ensure libgphoto2 service is connected
    if (!_libGPhoto2Service.isConnected) {
      debugPrint('CameraSettingsApplicationService: libgphoto2 not connected, attempting to connect');
      final connected = await _libGPhoto2Service.connect();
      if (!connected) {
        debugPrint('CameraSettingsApplicationService: Failed to connect to camera via libgphoto2');
        return false;
      }
    }

    final stringValue = value.toString();

    switch (settingName.toLowerCase()) {
      case 'iso':
        return await _libGPhoto2Service.setISO(stringValue);
      
      case 'aperture':
      case 'f-stop':
        // Convert f/2.8 format to 2.8 if needed
        final apertureValue = stringValue.startsWith('f/') 
            ? stringValue.substring(2) 
            : stringValue;
        return await _libGPhoto2Service.setAperture(apertureValue);
      
      case 'shutterspeed':
      case 'shutter_speed':
      case 'shutter':
        // Convert 1/100 format if needed
        return await _libGPhoto2Service.setShutterSpeed(stringValue);
      
      case 'whitebalance':
      case 'white_balance':
        return await _libGPhoto2Service.setWhiteBalance(stringValue);
      
      case 'focusmode':
      case 'focus_mode':
        return await _libGPhoto2Service.setFocusMode(stringValue);
      
      case 'imagequality':
      case 'image_quality':
        return await _libGPhoto2Service.setImageQuality(stringValue);
      
      default:
        // Try generic setting application
        debugPrint('CameraSettingsApplicationService: Applying generic setting $settingName');
        return await _libGPhoto2Service.setSetting(settingName, stringValue);
    }
  }

  /// Apply setting to WiFi-connected camera
  Future<bool> _applyWiFiCameraSetting(String settingName, dynamic value, ExternalCamera camera) async {
    debugPrint('CameraSettingsApplicationService: Applying WiFi setting $settingName = $value to ${camera.name}');
    
    // TODO: Implement WiFi camera setting application
    // This would depend on the specific camera's WiFi API
    
    // For now, simulate success for demonstration
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('CameraSettingsApplicationService: WiFi setting $settingName applied (simulated)');
    return true;
  }

  /// Update the CameraFeatureProvider state to reflect applied settings
  void _updateFeatureProviderState(String settingName, dynamic value, CameraFeatureProvider featureProvider) {
    switch (settingName.toLowerCase()) {
      case 'iso':
        if (value is num) {
          featureProvider.updateCameraSettings({'iso': value.toDouble()});
        } else if (value is String) {
          final isoValue = double.tryParse(value);
          if (isoValue != null) {
            featureProvider.updateCameraSettings({'iso': isoValue});
          }
        }
        break;
      
      case 'aperture':
      case 'f-stop':
        if (value is num) {
          featureProvider.updateCameraSettings({'aperture': value.toDouble()});
        } else if (value is String) {
          final cleanValue = value.startsWith('f/') ? value.substring(2) : value;
          final apertureValue = double.tryParse(cleanValue);
          if (apertureValue != null) {
            featureProvider.updateCameraSettings({'aperture': apertureValue});
          }
        }
        break;
      
      case 'shutterspeed':
      case 'shutter_speed':
      case 'shutter':
        if (value is num) {
          featureProvider.updateCameraSettings({'shutterSpeed': value.toDouble()});
        } else if (value is String) {
          // Handle formats like "1/100" or "100"
          double? shutterValue;
          if (value.contains('/')) {
            final parts = value.split('/');
            if (parts.length == 2) {
              final numerator = double.tryParse(parts[0]);
              final denominator = double.tryParse(parts[1]);
              if (numerator != null && denominator != null && denominator != 0) {
                shutterValue = denominator; // Store as 1/x format denominator
              }
            }
          } else {
            shutterValue = double.tryParse(value);
          }
          
          if (shutterValue != null) {
            featureProvider.updateCameraSettings({'shutterSpeed': shutterValue});
          }
        }
        break;
      
      case 'flashmode':
      case 'flash_mode':
        final flashEnabled = value.toString().toLowerCase() == 'on' || 
                            value.toString().toLowerCase() == 'true' || 
                            value == true;
        featureProvider.updateCameraSettings({'flashMode': flashEnabled});
        break;
      
      case 'zoomlevel':
      case 'zoom_level':
      case 'zoom':
        if (value is num) {
          featureProvider.updateCameraSettings({'zoomLevel': value.toDouble()});
        } else if (value is String) {
          final zoomValue = double.tryParse(value);
          if (zoomValue != null) {
            featureProvider.updateCameraSettings({'zoomLevel': zoomValue});
          }
        }
        break;
    }
    
    debugPrint('CameraSettingsApplicationService: Updated feature provider with $settingName = $value');
  }

  /// Get available setting choices for a specific camera setting
  Future<List<String>> getSettingChoices(String settingName) async {
    if (!_libGPhoto2Service.isConnected) {
      return [];
    }

    switch (settingName.toLowerCase()) {
      case 'iso':
        return await _libGPhoto2Service.getISOChoices();
      case 'aperture':
        return await _libGPhoto2Service.getApertureChoices();
      case 'shutterspeed':
        return await _libGPhoto2Service.getShutterSpeedChoices();
      case 'whitebalance':
        return await _libGPhoto2Service.getWhiteBalanceChoices();
      default:
        return await _libGPhoto2Service.getSettingChoices(settingName);
    }
  }

  /// Check if a camera setting is supported by the connected camera
  Future<bool> isSettingSupported(String settingName) async {
    final choices = await getSettingChoices(settingName);
    return choices.isNotEmpty;
  }

  /// Get current camera setting value
  Future<String?> getCurrentSettingValue(String settingName) async {
    if (!_libGPhoto2Service.isConnected) {
      return null;
    }

    try {
      return await _libGPhoto2Service.getSetting(settingName);
    } catch (e) {
      debugPrint('CameraSettingsApplicationService: Error getting $settingName: $e');
      return null;
    }
  }
}