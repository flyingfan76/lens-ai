import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../i_camera.dart';
import '../camera_types.dart';
import '../camera_capabilities.dart';
import '../camera_settings.dart';

/// Implementation of ICamera for built-in mobile cameras (iOS/Android)
/// This camera has LIMITED capabilities - only auto controls available
class BuiltInMobileCamera implements ICamera {
  final CameraDescription _cameraDescription;
  CameraController? _controller;
  
  late final StreamController<bool> _connectionStreamController;
  late final StreamController<CameraStatus> _statusStreamController;
  
  bool _isConnected = false;
  CameraStatus _currentStatus;
  
  BuiltInMobileCamera(this._cameraDescription) 
    : _currentStatus = CameraStatus(isConnected: false) {
    _connectionStreamController = StreamController<bool>.broadcast();
    _statusStreamController = StreamController<CameraStatus>.broadcast();
  }
  
  // ===== IDENTITY =====
  
  @override
  String get id => _cameraDescription.name;
  
  @override
  String get name => _cameraDescription.name;
  
  @override
  String get model {
    // Extract model from camera name if possible
    final name = _cameraDescription.name.toLowerCase();
    if (name.contains('front')) return 'Front Camera';
    if (name.contains('back')) return 'Back Camera';
    if (name.contains('wide')) return 'Wide Camera';
    if (name.contains('ultra')) return 'Ultra Wide Camera';
    if (name.contains('telephoto')) return 'Telephoto Camera';
    return 'Built-in Camera';
  }
  
  @override
  CameraType get type => CameraType.builtInMobile;
  
  @override
  CameraBrand get brand => CameraBrand.apple; // Could detect from platform
  
  @override
  CameraPlatform get platform {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CameraPlatform.ios;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return CameraPlatform.android;
    }
    return CameraPlatform.ios;
  }
  
  // ===== CAPABILITIES =====
  
  @override
  CameraCapabilities get capabilities {
    return CameraCapabilities.builtInMobile(model: model);
  }
  
  // ===== CONNECTION =====
  
  @override
  Future<bool> connect() async {
    try {
      debugPrint('BuiltInMobileCamera: Connecting to ${name}');
      
      _controller = CameraController(
        _cameraDescription,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      _isConnected = true;
      _updateStatus(CameraStatus(
        isConnected: true,
        currentOperation: 'Connected',
      ));
      
      debugPrint('BuiltInMobileCamera: Successfully connected to ${name}');
      return true;
      
    } catch (e) {
      debugPrint('BuiltInMobileCamera: Connection failed: $e');
      _updateStatus(CameraStatus(
        isConnected: false,
        error: 'Connection failed: $e',
      ));
      return false;
    }
  }
  
  @override
  Future<void> disconnect() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      
      _isConnected = false;
      _updateStatus(CameraStatus(isConnected: false));
      
      debugPrint('BuiltInMobileCamera: Disconnected from ${name}');
    } catch (e) {
      debugPrint('BuiltInMobileCamera: Disconnect error: $e');
    }
  }
  
  @override
  bool get isConnected => _isConnected && _controller != null;
  
  @override
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  
  // ===== LIVE VIEW =====
  
  @override
  Future<bool> startLiveView() async {
    if (!isConnected) {
      debugPrint('BuiltInMobileCamera: Cannot start live view - not connected');
      return false;
    }
    
    try {
      // For built-in cameras, live view is always available when connected
      _updateStatus(_currentStatus.copyWith(
        isLiveViewActive: true,
        currentOperation: 'Live view active',
      ));
      
      debugPrint('BuiltInMobileCamera: Live view started');
      return true;
    } catch (e) {
      debugPrint('BuiltInMobileCamera: Live view start failed: $e');
      return false;
    }
  }
  
  @override
  Future<void> stopLiveView() async {
    _updateStatus(_currentStatus.copyWith(
      isLiveViewActive: false,
      currentOperation: null,
    ));
    debugPrint('BuiltInMobileCamera: Live view stopped');
  }
  
  @override
  Stream<Uint8List>? get liveViewStream {
    // Built-in cameras use Flutter's CameraPreview widget, not a stream
    // This is a limitation of the camera plugin
    return null;
  }
  
  @override
  bool get isLiveViewActive => _currentStatus.isLiveViewActive;
  
  // ===== CAPTURE =====
  
  @override
  Future<CaptureResult> capturePhoto() async {
    if (!isConnected || _controller == null) {
      return CaptureResult.failure(error: 'Camera not connected');
    }
    
    try {
      debugPrint('BuiltInMobileCamera: Capturing photo');
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: true,
        currentOperation: 'Capturing photo',
      ));
      
      final image = await _controller!.takePicture();
      
      _updateStatus(_currentStatus.copyWith(
        isBusy: false,
        currentOperation: null,
      ));
      
      debugPrint('BuiltInMobileCamera: Photo captured: ${image.path}');
      
      return CaptureResult.success(
        filePath: image.path,
        fileName: image.name,
        metadata: {
          'camera': name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
    } catch (e) {
      _updateStatus(_currentStatus.copyWith(
        isBusy: false,
        error: 'Capture failed: $e',
      ));
      
      debugPrint('BuiltInMobileCamera: Capture failed: $e');
      return CaptureResult.failure(error: 'Capture failed: $e');
    }
  }
  
  @override
  Future<CaptureResult> startVideoRecording() async {
    if (!isConnected || _controller == null) {
      return CaptureResult.failure(error: 'Camera not connected');
    }
    
    try {
      await _controller!.startVideoRecording();
      
      _updateStatus(_currentStatus.copyWith(
        isRecording: true,
        currentOperation: 'Recording video',
      ));
      
      debugPrint('BuiltInMobileCamera: Video recording started');
      return CaptureResult.success(filePath: 'recording');
      
    } catch (e) {
      debugPrint('BuiltInMobileCamera: Video start failed: $e');
      return CaptureResult.failure(error: 'Video recording failed: $e');
    }
  }
  
  @override
  Future<CaptureResult> stopVideoRecording() async {
    if (!isConnected || _controller == null) {
      return CaptureResult.failure(error: 'Camera not connected');
    }
    
    try {
      final video = await _controller!.stopVideoRecording();
      
      _updateStatus(_currentStatus.copyWith(
        isRecording: false,
        currentOperation: null,
      ));
      
      debugPrint('BuiltInMobileCamera: Video recording stopped: ${video.path}');
      
      return CaptureResult.success(
        filePath: video.path,
        fileName: video.name,
        metadata: {
          'camera': name,
          'duration': 'unknown', // Camera plugin doesn't provide duration
        },
      );
      
    } catch (e) {
      debugPrint('BuiltInMobileCamera: Video stop failed: $e');
      return CaptureResult.failure(error: 'Stop recording failed: $e');
    }
  }
  
  @override
  bool get isRecording => _currentStatus.isRecording;
  
  // ===== SETTINGS =====
  
  @override
  Future<T?> getSetting<T>(CameraSetting setting) async {
    // Built-in mobile cameras don't expose manual settings
    debugPrint('BuiltInMobileCamera: getSetting(${setting.displayName}) - not supported');
    return null;
  }
  
  @override
  Future<bool> setSetting<T>(CameraSetting setting, T value) async {
    // Built-in mobile cameras don't support manual settings
    debugPrint('BuiltInMobileCamera: setSetting(${setting.displayName}, $value) - not supported');
    return false;
  }
  
  @override
  List<CameraSetting> get supportedSettings {
    // Built-in cameras don't support manual settings
    return [];
  }
  
  @override
  Future<List<T>> getSettingChoices<T>(CameraSetting setting) async {
    return [];
  }
  
  @override
  CameraSettingRange? getSettingRange(CameraSetting setting) {
    return null;
  }
  
  // ===== STATUS & MONITORING =====
  
  @override
  CameraStatus get status => _currentStatus;
  
  @override
  Stream<CameraStatus> get statusStream => _statusStreamController.stream;
  
  @override
  double? get batteryLevel => null; // Not available for built-in cameras
  
  @override
  CameraStorageInfo? get storageInfo => null; // Uses phone's storage
  
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
      'lensDirection': _cameraDescription.lensDirection.name,
      'sensorOrientation': _cameraDescription.sensorOrientation,
    };
  }
  
  @override
  bool isSameCamera(ICamera other) {
    return other is BuiltInMobileCamera && 
           other._cameraDescription.name == _cameraDescription.name;
  }
  
  // ===== PRIVATE METHODS =====
  
  void _updateStatus(CameraStatus newStatus) {
    _currentStatus = newStatus;
    _statusStreamController.add(_currentStatus);
    _connectionStreamController.add(_currentStatus.isConnected);
  }
  
  // ===== LIFECYCLE =====
  
  @override
  void dispose() {
    debugPrint('BuiltInMobileCamera: Disposing');
    _controller?.dispose();
    _connectionStreamController.close();
    _statusStreamController.close();
  }
}