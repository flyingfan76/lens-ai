import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'camera_types.dart';
import 'camera_capabilities.dart';
import 'camera_settings.dart';

/// Universal camera interface that all camera types must implement
/// This provides a unified API for built-in, external, and desktop cameras
abstract class ICamera {
  // ===== IDENTITY =====
  
  /// Unique identifier for this camera
  String get id;
  
  /// Human-readable name (e.g., "Nikon D90", "Built-in FaceTime HD Camera")
  String get name;
  
  /// Camera model (e.g., "D90", "FaceTime HD Camera")
  String get model;
  
  /// Camera type (DSLR, mirrorless, built-in, compact)
  CameraType get type;
  
  /// Camera brand (Nikon, Canon, Apple, etc.)
  CameraBrand get brand;
  
  /// Platform this camera runs on
  CameraPlatform get platform;
  
  // ===== CAPABILITIES =====
  
  /// Comprehensive capability information - CRITICAL for AI integration
  /// This tells the system exactly what this camera can and cannot do
  CameraCapabilities get capabilities;
  
  // ===== CONNECTION =====
  
  /// Connect to the camera
  Future<bool> connect();
  
  /// Disconnect from the camera
  Future<void> disconnect();
  
  /// Current connection state
  bool get isConnected;
  
  /// Connection status stream for real-time updates
  Stream<bool> get connectionStream;
  
  // ===== LIVE VIEW =====
  
  /// Start live view if supported
  Future<bool> startLiveView();
  
  /// Stop live view
  Future<void> stopLiveView();
  
  /// Live view image stream (null if not supported or not active)
  Stream<Uint8List>? get liveViewStream;
  
  /// Whether live view is currently active
  bool get isLiveViewActive;
  
  // ===== CAPTURE =====
  
  /// Capture a photo
  Future<CaptureResult> capturePhoto();
  
  /// Start video recording (if supported)
  Future<CaptureResult> startVideoRecording();
  
  /// Stop video recording
  Future<CaptureResult> stopVideoRecording();
  
  /// Whether video is currently recording
  bool get isRecording;
  
  // ===== SETTINGS =====
  
  /// Get current value of a camera setting
  /// Returns null if setting is not supported or cannot be read
  Future<T?> getSetting<T>(CameraSetting setting);
  
  /// Set a camera setting to a specific value
  /// Returns false if setting is not supported or value is invalid
  Future<bool> setSetting<T>(CameraSetting setting, T value);
  
  /// Get list of all settings this camera supports
  List<CameraSetting> get supportedSettings;
  
  /// Get available choices for a specific setting
  /// Returns empty list if setting doesn't have discrete choices
  Future<List<T>> getSettingChoices<T>(CameraSetting setting);
  
  /// Get valid range for a numeric setting
  /// Returns null if setting is not numeric or not supported
  CameraSettingRange? getSettingRange(CameraSetting setting);
  
  // ===== STATUS & MONITORING =====
  
  /// Current camera status
  CameraStatus get status;
  
  /// Status change stream for real-time monitoring
  Stream<CameraStatus> get statusStream;
  
  /// Battery level (0.0 - 1.0, null if not available)
  double? get batteryLevel;
  
  /// Storage information (null if not available)
  CameraStorageInfo? get storageInfo;
  
  // ===== METADATA =====
  
  /// Get camera information as a map (for debugging/logging)
  Map<String, dynamic> getCameraInfo();
  
  /// Check if this camera is the same as another camera
  bool isSameCamera(ICamera other);
  
  // ===== LIFECYCLE =====
  
  /// Dispose of resources
  void dispose();
}

/// Result of a capture operation
class CaptureResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final String? error;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  
  CaptureResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.error,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  CaptureResult.success({
    required String filePath,
    String? fileName,
    Map<String, dynamic>? metadata,
  }) : this(
    success: true,
    filePath: filePath,
    fileName: fileName,
    metadata: metadata,
  );
  
  CaptureResult.failure({
    required String error,
  }) : this(
    success: false,
    error: error,
  );
}

/// Camera status information
class CameraStatus {
  final bool isConnected;
  final bool isLiveViewActive;
  final bool isRecording;
  final bool isBusy;
  final String? currentOperation;
  final String? error;
  final DateTime timestamp;
  
  CameraStatus({
    required this.isConnected,
    this.isLiveViewActive = false,
    this.isRecording = false,
    this.isBusy = false,
    this.currentOperation,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  CameraStatus copyWith({
    bool? isConnected,
    bool? isLiveViewActive,
    bool? isRecording,
    bool? isBusy,
    String? currentOperation,
    String? error,
  }) {
    return CameraStatus(
      isConnected: isConnected ?? this.isConnected,
      isLiveViewActive: isLiveViewActive ?? this.isLiveViewActive,
      isRecording: isRecording ?? this.isRecording,
      isBusy: isBusy ?? this.isBusy,
      currentOperation: currentOperation ?? this.currentOperation,
      error: error ?? this.error,
      timestamp: DateTime.now(),
    );
  }
}

/// Camera storage information
class CameraStorageInfo {
  final int totalSpaceBytes;
  final int freeSpaceBytes;
  final int usedSpaceBytes;
  final String storageType; // "SD Card", "Internal", "CF Card", etc.
  
  const CameraStorageInfo({
    required this.totalSpaceBytes,
    required this.freeSpaceBytes,
    required this.usedSpaceBytes,
    required this.storageType,
  });
  
  double get usagePercentage => usedSpaceBytes / totalSpaceBytes;
  double get freePercentage => freeSpaceBytes / totalSpaceBytes;
}