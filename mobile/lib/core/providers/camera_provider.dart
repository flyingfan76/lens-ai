import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import '../utils/lens_exceptions.dart';

/// Abstract interface for camera providers
/// 
/// This defines the core camera operations that all camera providers must implement.
/// Focused on hardware control and core camera functionality only.
abstract class CameraProvider {
  // Connection state
  bool get isInitialized;
  bool get isConnected;
  String get connectionStatus;
  
  // Available cameras
  List<camera.CameraDescription> get cameras;
  List<Map<String, dynamic>> get availableCameras;
  camera.CameraDescription? get currentCamera;
  
  // Core hardware settings (read-only, actual values)
  double get iso;
  double get aperture;
  double get shutterSpeed;
  String get whiteBalance;
  double get focusDistance;
  bool get isFlashEnabled;
  double get zoomLevel;
  double get maxZoomLevel;
  double get minZoomLevel;
  
  // Error handling
  bool get hasError;
  LensException? get lastError;
  
  /// Initialize camera system
  Future<void> initializeCameras();
  
  /// Discover available cameras
  Future<List<Map<String, dynamic>>> discoverCameras({bool forceRefresh = false});
  
  /// Connect to a specific camera
  Future<void> connectToCamera({required String cameraId});
  
  /// Switch between available cameras
  Future<void> switchCamera();
  
  /// Disconnect from current camera
  Future<void> disconnectCamera({String? cameraId});
  
  /// Camera preview widget
  Widget? getCameraPreview();
  
  /// Start live view/preview
  Future<Map<String, dynamic>> startLiveView();
  
  /// Stop live view/preview
  Future<bool> stopLiveView();
  
  /// Capture image
  Future<camera.XFile> captureImage();
  
  // Hardware control methods
  
  /// Update ISO setting
  void updateISO(double value);
  
  /// Update aperture setting
  void updateAperture(double value);
  
  /// Update shutter speed setting
  void updateShutterSpeed(double value);
  
  /// Update white balance setting
  void updateWhiteBalance(String value);
  
  /// Set zoom level
  Future<void> setZoomLevel(double zoom);
  
  /// Set flash mode
  Future<void> setFlashMode(bool enabled);
  
  /// Set focus point
  Future<void> setFocusPoint(Offset point);
  
  /// Set exposure point
  Future<void> setExposurePoint(Offset point);
  
  /// Apply AI-recommended settings
  Future<bool> applyAISettings(Map<String, dynamic> settings);
  
  /// Get current camera settings
  Map<String, dynamic> getCurrentSettings();
  
  /// Dispose resources
  void dispose();
}