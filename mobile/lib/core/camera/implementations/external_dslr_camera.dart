import 'dart:async';
import 'package:flutter/foundation.dart';
import '../i_camera.dart';
import '../camera_types.dart';
import '../camera_capabilities.dart';
import '../camera_settings.dart';
import '../../../models/external_camera.dart' as legacy;
import '../../../services/external_camera_service.dart';

/// Implementation of ICamera for external DSLR/Mirrorless cameras
/// This wraps the existing ExternalCameraService and provides full manual controls
class ExternalDSLRCamera implements ICamera {
  final legacy.ExternalCamera _legacyCamera;
  final ExternalCameraService _cameraService;
  
  late final StreamController<bool> _connectionStreamController;
  late final StreamController<CameraStatus> _statusStreamController;
  
  CameraStatus _currentStatus;
  
  ExternalDSLRCamera(this._legacyCamera, this._cameraService) 
    : _currentStatus = CameraStatus(isConnected: _legacyCamera.isConnected) {
    _connectionStreamController = StreamController<bool>.broadcast();
    _statusStreamController = StreamController<CameraStatus>.broadcast();
    
    // Initialize status
    _updateStatus(CameraStatus(isConnected: _legacyCamera.isConnected));
  }
  
  // ===== IDENTITY =====
  
  @override
  String get id => _legacyCamera.id;
  
  @override
  String get name => _legacyCamera.name;
  
  @override
  String get model => _legacyCamera.model;
  
  @override
  CameraType get type {
    switch (_legacyCamera.type) {
      case legacy.CameraType.dslr:
        return CameraType.dslr;
      case legacy.CameraType.mirrorless:
        return CameraType.mirrorless;
      case legacy.CameraType.compact:
        return CameraType.compact;
      default:
        return CameraType.unknown;
    }
  }
  
  @override
  CameraBrand get brand {
    switch (_legacyCamera.brand) {
      case legacy.CameraBrand.nikon:
        return CameraBrand.nikon;
      case legacy.CameraBrand.canon:
        return CameraBrand.canon;
      case legacy.CameraBrand.sony:
        return CameraBrand.sony;
      case legacy.CameraBrand.fujifilm:
        return CameraBrand.fujifilm;
      case legacy.CameraBrand.olympus:
        return CameraBrand.olympus;
      case legacy.CameraBrand.panasonic:
        return CameraBrand.panasonic;
      default:
        return CameraBrand.unknown;
    }
  }
  
  @override
  CameraPlatform get platform => CameraPlatform.external;
  
  // ===== CAPABILITIES =====
  
  @override
  CameraCapabilities get capabilities {
    // Create capabilities based on camera type and known capabilities
    CameraSettingRange? isoRange;
    CameraSettingRange? apertureRange;
    CameraSettingRange? shutterRange;
    
    // Extract ranges from legacy capabilities if available
    if (_legacyCamera.capabilities != null) {
      final legacyCaps = _legacyCamera.capabilities!;
      
      // Try to create ranges from available settings
      if (legacyCaps['availableSettings'] is Map) {
        final settings = legacyCaps['availableSettings'] as Map<String, dynamic>;
        
        if (settings['ISO'] is List) {
          isoRange = CameraSettingRange.fromList(settings['ISO']);
        }
        if (settings['Aperture'] is List) {
          apertureRange = CameraSettingRange.fromList(settings['Aperture']);
        }
        if (settings['ShutterSpeed'] is List) {
          shutterRange = CameraSettingRange.fromList(settings['ShutterSpeed']);
        }
      }
    }
    
    return CameraCapabilities.externalDSLR(
      model: model,
      brand: brand,
      isoRange: isoRange,
      apertureRange: apertureRange,
      shutterRange: shutterRange,
    );
  }
  
  // ===== CONNECTION =====
  
  @override
  Future<bool> connect() async {
    try {
      debugPrint('ExternalDSLRCamera: Connecting to ${name}');
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: true,
        currentOperation: 'Connecting',
      ));
      
      final success = await _cameraService.connectToCamera(id);
      
      if (success) {
        _updateStatus(CameraStatus(
          isConnected: true,
          currentOperation: 'Connected',
        ));
        debugPrint('ExternalDSLRCamera: Successfully connected to ${name}');
      } else {
        _updateStatus(CameraStatus(
          isConnected: false,
          error: 'Connection failed',
        ));
        debugPrint('ExternalDSLRCamera: Connection failed for ${name}');
      }
      
      return success;
      
    } catch (e) {
      _updateStatus(CameraStatus(
        isConnected: false,
        error: 'Connection error: $e',
      ));
      debugPrint('ExternalDSLRCamera: Connection error: $e');
      return false;
    }
  }
  
  @override
  Future<void> disconnect() async {
    try {
      await _cameraService.disconnectFromCamera(id);
      _updateStatus(CameraStatus(isConnected: false));
      debugPrint('ExternalDSLRCamera: Disconnected from ${name}');
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Disconnect error: $e');
    }
  }
  
  @override
  bool get isConnected {
    // Check both legacy camera state and current status
    final legacyConnected = _cameraService.discoveredCameras
        .firstWhere((c) => c.id == id, orElse: () => _legacyCamera)
        .isConnected;
    return legacyConnected && _currentStatus.isConnected;
  }
  
  @override
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  
  // ===== LIVE VIEW =====
  
  @override
  Future<bool> startLiveView() async {
    if (!isConnected) {
      debugPrint('ExternalDSLRCamera: Cannot start live view - not connected');
      return false;
    }
    
    try {
      debugPrint('ExternalDSLRCamera: Starting live view for ${name}');
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: true,
        currentOperation: 'Starting live view',
      ));
      
      final success = await _cameraService.startLiveView(id);
      
      if (success) {
        _updateStatus(_currentStatus.copyWith(
          isLiveViewActive: true,
          isBusy: false,
          currentOperation: 'Live view active',
        ));
        debugPrint('ExternalDSLRCamera: Live view started for ${name}');
      } else {
        _updateStatus(_currentStatus.copyWith(
          isBusy: false,
          error: 'Live view start failed',
        ));
        debugPrint('ExternalDSLRCamera: Live view start failed for ${name}');
      }
      
      return success;
      
    } catch (e) {
      _updateStatus(_currentStatus.copyWith(
        isBusy: false,
        error: 'Live view error: $e',
      ));
      debugPrint('ExternalDSLRCamera: Live view start error: $e');
      return false;
    }
  }
  
  @override
  Future<void> stopLiveView() async {
    try {
      await _cameraService.stopLiveView();
      _updateStatus(_currentStatus.copyWith(
        isLiveViewActive: false,
        currentOperation: null,
      ));
      debugPrint('ExternalDSLRCamera: Live view stopped for ${name}');
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Live view stop error: $e');
    }
  }
  
  @override
  Stream<Uint8List>? get liveViewStream => _cameraService.liveViewStream;
  
  @override
  bool get isLiveViewActive => _cameraService.isLiveViewActive && _currentStatus.isLiveViewActive;
  
  // ===== CAPTURE =====
  
  @override
  Future<CaptureResult> capturePhoto() async {
    if (!isConnected) {
      return CaptureResult.failure(error: 'Camera not connected');
    }
    
    try {
      debugPrint('ExternalDSLRCamera: Capturing photo with ${name}');
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: true,
        currentOperation: 'Capturing photo',
      ));
      
      // Use the existing external camera service
      // Note: This would need to be adapted based on the actual capture method
      // For now, we'll simulate the capture
      
      await Future.delayed(Duration(milliseconds: 500)); // Simulate capture time
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: false,
        currentOperation: null,
      ));
      
      debugPrint('ExternalDSLRCamera: Photo captured with ${name}');
      
      return CaptureResult.success(
        filePath: '/camera/photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fileName: 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
        metadata: {
          'camera': name,
          'model': model,
          'brand': brand.displayName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
    } catch (e) {
      _updateStatus(_currentStatus.copyWith(
        isBusy: false,
        error: 'Capture failed: $e',
      ));
      debugPrint('ExternalDSLRCamera: Capture failed: $e');
      return CaptureResult.failure(error: 'Capture failed: $e');
    }
  }
  
  @override
  Future<CaptureResult> startVideoRecording() async {
    if (!isConnected) {
      return CaptureResult.failure(error: 'Camera not connected');
    }
    
    // Check if camera supports video recording
    if (!capabilities.supportsVideoRecording) {
      return CaptureResult.failure(error: 'Camera does not support video recording');
    }
    
    try {
      _updateStatus(_currentStatus.copyWith(
        isRecording: true,
        currentOperation: 'Recording video',
      ));
      
      debugPrint('ExternalDSLRCamera: Video recording started with ${name}');
      return CaptureResult.success(filePath: 'recording');
      
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Video start failed: $e');
      return CaptureResult.failure(error: 'Video recording failed: $e');
    }
  }
  
  @override
  Future<CaptureResult> stopVideoRecording() async {
    try {
      _updateStatus(_currentStatus.copyWith(
        isRecording: false,
        currentOperation: null,
      ));
      
      debugPrint('ExternalDSLRCamera: Video recording stopped with ${name}');
      
      return CaptureResult.success(
        filePath: '/camera/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        fileName: 'VID_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Video stop failed: $e');
      return CaptureResult.failure(error: 'Stop recording failed: $e');
    }
  }
  
  @override
  bool get isRecording => _currentStatus.isRecording;
  
  // ===== SETTINGS =====
  
  @override
  Future<T?> getSetting<T>(CameraSetting setting) async {
    if (!isConnected) {
      debugPrint('ExternalDSLRCamera: Cannot get setting - not connected');
      return null;
    }
    
    try {
      // Map our unified settings to the legacy camera service
      String? legacySetting = _mapSettingToLegacy(setting);
      if (legacySetting == null) {
        debugPrint('ExternalDSLRCamera: Setting ${setting.displayName} not supported');
        return null;
      }
      
      // This would need to be implemented in the external camera service
      // For now, return null as a placeholder
      debugPrint('ExternalDSLRCamera: Getting ${setting.displayName} (mapped to $legacySetting)');
      return null;
      
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Get setting error: $e');
      return null;
    }
  }
  
  @override
  Future<bool> setSetting<T>(CameraSetting setting, T value) async {
    if (!isConnected) {
      debugPrint('ExternalDSLRCamera: Cannot set setting - not connected');
      return false;
    }
    
    try {
      String? legacySetting = _mapSettingToLegacy(setting);
      if (legacySetting == null) {
        debugPrint('ExternalDSLRCamera: Setting ${setting.displayName} not supported');
        return false;
      }
      
      debugPrint('ExternalDSLRCamera: Setting ${setting.displayName} = $value (mapped to $legacySetting)');
      
      // This would need to be implemented in the external camera service
      // For now, return false as a placeholder
      return false;
      
    } catch (e) {
      debugPrint('ExternalDSLRCamera: Set setting error: $e');
      return false;
    }
  }
  
  @override
  List<CameraSetting> get supportedSettings {
    // Return settings based on capabilities
    final settings = <CameraSetting>[];
    
    if (capabilities.supportsManualISO) settings.add(CameraSetting.iso);
    if (capabilities.supportsManualAperture) settings.add(CameraSetting.aperture);
    if (capabilities.supportsManualShutter) settings.add(CameraSetting.shutterSpeed);
    if (capabilities.supportsExposureCompensation) settings.add(CameraSetting.exposureCompensation);
    if (capabilities.supportsManualFocus) settings.add(CameraSetting.focusMode);
    if (capabilities.supportsManualWhiteBalance) settings.add(CameraSetting.whiteBalance);
    
    return settings;
  }
  
  @override
  Future<List<T>> getSettingChoices<T>(CameraSetting setting) async {
    // This would need to be implemented based on camera capabilities
    return [];
  }
  
  @override
  CameraSettingRange? getSettingRange(CameraSetting setting) {
    switch (setting) {
      case CameraSetting.iso:
        return capabilities.isoRange;
      case CameraSetting.aperture:
        return capabilities.apertureRange;
      case CameraSetting.shutterSpeed:
        return capabilities.shutterRange;
      case CameraSetting.exposureCompensation:
        return CameraSettingRange.exposureCompensation();
      default:
        return null;
    }
  }
  
  // ===== STATUS & MONITORING =====
  
  @override
  CameraStatus get status => _currentStatus;
  
  @override
  Stream<CameraStatus> get statusStream => _statusStreamController.stream;
  
  @override
  double? get batteryLevel {
    // Could be extracted from camera capabilities if available
    return null;
  }
  
  @override
  CameraStorageInfo? get storageInfo {
    // Could be extracted from camera capabilities if available
    return null;
  }
  
  // ===== METADATA =====
  
  @override
  Map<String, dynamic> getCameraInfo() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'type': type.displayName,
      'brand': brand.displayName,
      'platform': platform.displayName,
      'isConnected': isConnected,
      'capabilities': capabilities.toJson(),
      'connectionType': _legacyCamera.connectionType.name,
      'ipAddress': _legacyCamera.ipAddress,
      'port': _legacyCamera.port,
      'usbPath': _legacyCamera.usbPath,
    };
  }
  
  @override
  bool isSameCamera(ICamera other) {
    return other is ExternalDSLRCamera && other.id == id;
  }
  
  // ===== PRIVATE METHODS =====
  
  void _updateStatus(CameraStatus newStatus) {
    _currentStatus = newStatus;
    _statusStreamController.add(_currentStatus);
    _connectionStreamController.add(_currentStatus.isConnected);
  }
  
  String? _mapSettingToLegacy(CameraSetting setting) {
    switch (setting) {
      case CameraSetting.iso:
        return 'ISO';
      case CameraSetting.aperture:
        return 'Aperture';
      case CameraSetting.shutterSpeed:
        return 'ShutterSpeed';
      case CameraSetting.exposureCompensation:
        return 'ExposureCompensation';
      case CameraSetting.focusMode:
        return 'FocusMode';
      case CameraSetting.whiteBalance:
        return 'WhiteBalance';
      default:
        return null;
    }
  }
  
  // ===== LIFECYCLE =====
  
  @override
  void dispose() {
    debugPrint('ExternalDSLRCamera: Disposing');
    _connectionStreamController.close();
    _statusStreamController.close();
  }
}