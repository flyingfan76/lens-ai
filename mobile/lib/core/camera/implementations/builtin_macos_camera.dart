import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../i_camera.dart';
import '../camera_types.dart';
import '../camera_capabilities.dart';
import '../camera_settings.dart';
import '../../../models/builtin_camera.dart';

/// Minimal implementation of ICamera for macOS built-in cameras
/// This provides just enough functionality for AI capability detection
class BuiltInMacOSCamera implements ICamera {
  final BuiltInCamera _legacyCamera;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<CameraStatus> _statusController = StreamController<CameraStatus>.broadcast();
  
  BuiltInMacOSCamera(this._legacyCamera) {
    // Emit initial connection status
    _connectionController.add(true);
    _statusController.add(CameraStatus(isConnected: true));
  }
  
  @override
  String get id => _legacyCamera.id;
  
  @override
  String get name => _legacyCamera.name;
  
  @override
  String get model => _legacyCamera.name;
  
  @override
  CameraBrand get brand => CameraBrand.apple;
  
  @override
  CameraType get type => CameraType.builtInDesktop;
  
  @override
  CameraPlatform get platform => CameraPlatform.macOS;
  
  @override
  bool get isConnected => true;
  
  @override
  Stream<bool> get connectionStream => _connectionController.stream;
  
  @override
  CameraCapabilities get capabilities {
    return const CameraCapabilities(
      // Basic capabilities
      supportsLiveView: true,
      supportsRemoteCapture: true,
      supportsVideoRecording: true,
      
      // NO manual controls - this is key for AI filtering!
      supportsManualISO: false,
      supportsManualAperture: false,
      supportsManualShutter: false,
      supportsManualFocus: false,
      supportsManualWhiteBalance: false,
      supportsExposureCompensation: false,
      
      // Limited features
      supportsFocusControl: false,
      supportsZoomControl: false,
      supportsSettingsRead: false,
      supportsSettingsWrite: false,
      
      // Platform limitations for built-in cameras
      isBuiltInCamera: true,
      platformLimitations: PlatformLimitations(
        canOnlyUseAutoMode: true,
        limitedToBasicCapture: true,
        reason: 'Built-in cameras use automatic controls',
        explanation: 'macOS built-in cameras automatically optimize settings. Focus on composition, lighting, and positioning instead.',
      ),
    );
  }
  
  // === MINIMAL REQUIRED IMPLEMENTATIONS ===
  
  @override
  Future<bool> connect() async => true;
  
  @override
  Future<void> disconnect() async {}
  
  @override
  Future<bool> startLiveView() async => true;
  
  @override
  Future<void> stopLiveView() async {}
  
  @override
  Stream<Uint8List>? get liveViewStream => null;
  
  @override  
  bool get isLiveViewActive => false;
  
  @override
  Future<CaptureResult> capturePhoto() async {
    return CaptureResult.failure(error: 'Photo capture handled by macOS camera service');
  }
  
  @override
  Future<CaptureResult> startVideoRecording() async {
    return CaptureResult.failure(error: 'Video recording not implemented');
  }
  
  @override
  Future<CaptureResult> stopVideoRecording() async {
    return CaptureResult.failure(error: 'Video recording not implemented');
  }
  
  @override
  bool get isRecording => false;
  
  @override
  Future<T?> getSetting<T>(CameraSetting setting) async => null;
  
  @override
  Future<bool> setSetting<T>(CameraSetting setting, T value) async => false;
  
  @override
  List<CameraSetting> get supportedSettings => [];
  
  @override
  Future<List<T>> getSettingChoices<T>(CameraSetting setting) async => [];
  
  @override
  CameraSettingRange? getSettingRange(CameraSetting setting) => null;
  
  @override
  CameraStatus get status => CameraStatus(isConnected: true);
  
  @override
  Stream<CameraStatus> get statusStream => _statusController.stream;
  
  @override
  double? get batteryLevel => null;
  
  @override
  CameraStorageInfo? get storageInfo => null;
  
  @override
  Map<String, dynamic> getCameraInfo() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'brand': brand.displayName,
      'type': type.displayName,
      'platform': platform.displayName,
      'isConnected': isConnected,
      'supportsManualControls': capabilities.canApplyManualSettings,
    };
  }
  
  @override
  bool isSameCamera(ICamera other) {
    return other.id == id && other.type == type;
  }
  
  @override
  void dispose() {
    _connectionController.close();
    _statusController.close();
  }
  
  @override
  String toString() {
    return 'BuiltInMacOSCamera(id: $id, name: $name, type: ${type.displayName})';
  }
}