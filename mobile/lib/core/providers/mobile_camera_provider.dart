import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:permission_handler/permission_handler.dart';
import '../utils/lens_exceptions.dart';
import '../state/base_state_provider.dart';
import 'camera_provider.dart';

class MobileCameraProvider extends BaseStateProvider implements CameraProvider {
  camera.CameraController? _controller;
  List<camera.CameraDescription> _cameras = [];
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  int _selectedCameraIndex = 0;
  
  // Camera settings - simulated professional camera controls
  double _iso = 400;
  double _aperture = 2.8;
  double _shutterSpeed = 60; // 1/60
  String _whiteBalance = 'auto';
  double _focusDistance = 0.0;
  bool _isFlashEnabled = false;
  
  // Zoom and other mobile-specific settings
  double _zoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  
  // Capture settings
  camera.ResolutionPreset _resolutionPreset = camera.ResolutionPreset.high;
  bool _enableAudio = false;
  
  // Getters
  camera.CameraController? get controller => _controller;
  @override
  List<camera.CameraDescription> get cameras => _cameras;
  @override
  List<Map<String, dynamic>> get availableCameras => _getAvailableCamerasAsMap();
  @override
  bool get isConnected => _isConnected;
  @override
  String get connectionStatus => _connectionStatus;
  
  // Camera settings getters
  @override
  double get iso => _iso;
  @override
  double get aperture => _aperture;
  @override
  double get shutterSpeed => _shutterSpeed;
  @override
  String get whiteBalance => _whiteBalance;
  @override
  double get focusDistance => _focusDistance;
  @override
  bool get isFlashEnabled => _isFlashEnabled;
  @override
  double get zoomLevel => _zoomLevel;
  @override
  double get maxZoomLevel => _maxZoomLevel;
  @override
  double get minZoomLevel => _minZoomLevel;
  
  // Current camera info
  @override
  camera.CameraDescription? get currentCamera => 
    _cameras.isNotEmpty ? _cameras[_selectedCameraIndex] : null;
  

  /// Override BaseStateProvider's initializeState
  @override
  Future<void> initializeState() async {
    await initializeCameras();
  }
  
  /// Initialize mobile cameras
  @override
  Future<void> initializeCameras() async {
    return await executeWithErrorHandling(
      () async {
        _connectionStatus = 'Initializing cameras...';
        notifyListeners();

        // Request camera permissions (mobile only)
        if (!kIsWeb && !Platform.isMacOS) {
          final permissionStatus = await Permission.camera.request();
          if (permissionStatus != PermissionStatus.granted) {
            throw CameraPermissionException(
              details: 'Permission status: $permissionStatus',
            );
          }
        } else if (!kIsWeb) {
          // macOS permissions handled via entitlements
          debugPrint('macOS camera permissions handled via entitlements');
        }

        // Get available cameras
        try {
          if (kIsWeb) {
            // Web platform - use mock cameras
            _cameras = _getMockCameras();
            debugPrint('Using mock cameras for web platform');
          } else {
            // Mobile/Desktop platform - get actual cameras  
            final availableCamerasList = await camera.availableCameras();
            _cameras = availableCamerasList;
            debugPrint('Found ${_cameras.length} cameras on ${Platform.operatingSystem}');

            // Log camera details for debugging
            for (int i = 0; i < _cameras.length; i++) {
              final cam = _cameras[i];
              debugPrint('Camera $i: ${cam.name} (${cam.lensDirection.name})');
            }
          }
        } catch (e, stackTrace) {
          if (kIsWeb) {
            _cameras = _getMockCameras();
            debugPrint('Using fallback mock cameras for web due to error: $e');
          } else {
            throw CameraInitializationException(
              message: 'Failed to enumerate cameras',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }

        if (_cameras.isEmpty) {
          throw CameraNotAvailableException(
            message: 'No cameras found on this device',
            details: 'Platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}',
          );
        }

        debugPrint('Found ${_cameras.length} cameras');
        for (int i = 0; i < _cameras.length; i++) {
          final camera = _cameras[i];
          debugPrint('Camera $i: ${camera.name} (${camera.lensDirection.name})');
        }

        // Initialize with the first camera (usually back camera)
        await _initializeCamera(_selectedCameraIndex);
      },
      operationName: 'initialize cameras',
      clearErrorOnSuccess: true,
    );
  }
  
  /// Discover and return camera information in the expected format
  @override
  Future<List<Map<String, dynamic>>> discoverCameras({bool forceRefresh = false}) async {
    final result = await executeWithErrorHandling<List<Map<String, dynamic>>>(
      () async {
        if (forceRefresh || _cameras.isEmpty) {
          await initializeCameras();
        }
        return _getAvailableCamerasAsMap();
      },
      operationName: 'discover cameras',
      fallbackValue: <Map<String, dynamic>>[],
    );
    return result ?? <Map<String, dynamic>>[];
  }
  
  List<Map<String, dynamic>> _getAvailableCamerasAsMap() {
    return _cameras.asMap().entries.map((entry) {
      final index = entry.key;
      final camera = entry.value;
      return {
        'id': 'mobile_camera_$index',
        'brand': 'mobile',
        'model': _getCameraDisplayName(camera),
        'serialNumber': camera.name,
        'isConnected': index == _selectedCameraIndex && _isConnected,
        'connectionType': 'built-in',
        'modelInfo': {
          'series': _getCameraType(camera),
          'type': 'mobile',
          'level': 'consumer',
          'matched': camera.name,
          'fullModel': _getCameraDisplayName(camera),
        },
        'detectionMethod': 'system',
        'capabilities': {
          'liveView': true,
          'remoteCapture': true,
          'settingsControl': true,
          'zoom': true,
          'flash': _hasFlash(camera),
          'autofocus': true,
        },
        'connectionQuality': 1.0,
        'compatibilityScore': 1.0,
      };
    }).toList();
  }
  
  String _getCameraDisplayName(camera.CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.back:
        return 'Back Camera';
      case CameraLensDirection.front:
        return 'Front Camera';
      case CameraLensDirection.external:
        return 'External Camera';
    }
  }
  
  String _getCameraType(camera.CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.back:
        return 'Primary';
      case CameraLensDirection.front:
        return 'Selfie';
      case CameraLensDirection.external:
        return 'External';
    }
  }
  
  bool _hasFlash(camera.CameraDescription camera) {
    // Most back cameras have flash, front cameras typically don't
    return camera.lensDirection == CameraLensDirection.back;
  }
  
  /// Initialize a specific camera
  Future<void> _initializeCamera(int cameraIndex) async {
    try {
      if (cameraIndex >= _cameras.length) {
        throw CameraInitializationException(
          message: 'Invalid camera index',
          details: 'Index $cameraIndex out of range (${_cameras.length} cameras available)',
        );
      }

      // Dispose existing controller safely
      try {
        await _controller?.dispose();
      } catch (disposeError) {
        debugPrint('Warning: Error disposing previous controller: $disposeError');
      }
      _controller = null;

      _connectionStatus = 'Connecting to ${_getCameraDisplayName(_cameras[cameraIndex])}...';
      notifyListeners();

      if (kIsWeb) {
        // Web platform - simulate camera connection
        debugPrint('Simulating camera connection for web platform');
        _maxZoomLevel = 3.0;
        _minZoomLevel = 1.0;
        _zoomLevel = _minZoomLevel;
      } else {
        // Create new controller for mobile
        try {
          _controller = camera.CameraController(
            _cameras[cameraIndex],
            _resolutionPreset,
            enableAudio: _enableAudio,
            imageFormatGroup: !kIsWeb && Platform.isAndroid 
              ? camera.ImageFormatGroup.nv21 
              : camera.ImageFormatGroup.bgra8888,
          );

          // Initialize controller with timeout
          await _controller!.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw CameraInitializationException(
                message: 'Camera initialization timed out',
                details: 'Failed to initialize ${_cameras[cameraIndex].name} within 30 seconds',
                suggestion: 'Try restarting the app or switch to a different camera',
              );
            },
          );

          // Set zoom limits with error handling
          try {
            _maxZoomLevel = await _controller!.getMaxZoomLevel();
            _minZoomLevel = await _controller!.getMinZoomLevel();
            _zoomLevel = _minZoomLevel;
          } catch (zoomError) {
            // Use defaults if zoom info is not available
            debugPrint('Warning: Could not get zoom levels: $zoomError');
            _maxZoomLevel = 1.0;
            _minZoomLevel = 1.0;
            _zoomLevel = 1.0;
          }
        } catch (e, stackTrace) {
          // Clean up controller on failure
          try {
            await _controller?.dispose();
          } catch (_) {}
          _controller = null;

          if (e.toString().contains('permission')) {
            throw CameraPermissionException(
              details: e.toString(),
            );
          } else if (e.toString().contains('busy') || e.toString().contains('use')) {
            throw CameraConnectionException(
              message: 'Camera is busy or in use by another app',
              details: e.toString(),
              suggestion: 'Close other camera apps and try again',
              originalError: e,
              stackTrace: stackTrace,
            );
          } else {
            throw CameraInitializationException(
              message: 'Failed to initialize camera controller',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }
      }

      _selectedCameraIndex = cameraIndex;
      _isConnected = true;
      _connectionStatus = 'Connected to ${_getCameraDisplayName(_cameras[cameraIndex])}';

      debugPrint('Camera initialized: ${_cameras[cameraIndex].name}');
      debugPrint('Zoom range: ${_minZoomLevel}x - ${_maxZoomLevel}x');

      notifyListeners();

    } catch (e) {
      _isConnected = false;
      
      if (e is LensException) {
        _connectionStatus = e.userMessage;
      } else {
        _connectionStatus = 'Connection failed: ${e.toString()}';
      }
      
      notifyListeners();
      rethrow;
    }
  }
  
  /// Connect to a specific camera (implements CameraProvider interface)
  @override
  Future<void> connectToCamera({required String cameraId}) async {
    return await connectToExternalCamera(cameraId: cameraId);
  }
  
  /// Connect to a specific camera (mobile camera selection)
  Future<void> connectToExternalCamera({required String cameraId}) async {
    return await executeWithErrorHandling(
      () async {
        // Parse camera index from ID
        final cameraIndex = int.tryParse(cameraId.replaceAll('mobile_camera_', ''));
        if (cameraIndex == null || cameraIndex >= _cameras.length) {
          throw CameraConnectionException(
            message: 'Invalid camera ID',
            details: 'Camera ID "$cameraId" is not valid',
            suggestion: 'Please select a valid camera from the available list',
          );
        }

        await _initializeCamera(cameraIndex);
      },
      operationName: 'connect to camera $cameraId',
    );
  }
  
  /// Switch between front/back cameras
  @override
  Future<void> switchCamera() async {
    return await executeWithErrorHandling(
      () async {
        if (_cameras.length <= 1) {
          throw CameraNotAvailableException(
            message: 'Cannot switch camera',
            details: 'Only ${_cameras.length} camera(s) available',
            suggestion: 'Camera switching requires multiple cameras',
          );
        }

        final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
        await connectToCamera(cameraId: 'mobile_camera_$newIndex');
      },
      operationName: 'switch camera',
    );
  }
  
  /// Start live view (camera preview)
  @override
  Future<Map<String, dynamic>> startLiveView() async {
    return await executeWithErrorHandling<Map<String, dynamic>>(
      () async {
        if (!_isConnected || _controller == null) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera connection first',
          );
        }

        // For mobile cameras, live view is the camera preview itself
        // Return success with a mock stream URL for compatibility
        return {
          'success': true,
          'streamUrl': 'mobile://camera_preview',
          'message': 'Live view active'
        };
      },
      operationName: 'start live view',
      fallbackValue: {
        'success': false,
        'message': 'Failed to start live view'
      },
    ) ?? {
      'success': false,
      'message': 'Failed to start live view'
    };
  }
  
  /// Stop live view
  @override
  Future<bool> stopLiveView() async {
    try {
      // For mobile cameras, stopping live view means pausing preview
      return true;
    } catch (e) {
      debugPrint('Failed to stop live view: $e');
      return false;
    }
  }
  
  /// Capture image
  @override
  Future<camera.XFile> captureImage() async {
    return await executeWithErrorHandling<camera.XFile>(
      () async {
        if (!_isConnected) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera connection first',
          );
        }

        debugPrint('Capturing image with settings - ISO: $_iso, Aperture: f/$_aperture, Shutter: 1/$_shutterSpeed');

        if (kIsWeb) {
          // Web platform - not supported
          throw CameraCaptureException(
            message: 'Image capture not supported on web platform',
            details: 'This is a mobile-first feature',
            suggestion: 'Use a mobile device for camera capture',
          );
        }

        // Mobile platform - actual capture
        if (_controller == null) {
          throw CameraConnectionException(
            message: 'Camera controller not initialized',
            suggestion: 'Restart the camera to reinitialize',
          );
        }

        if (!_controller!.value.isInitialized) {
          throw CameraConnectionException(
            message: 'Camera not ready',
            suggestion: 'Wait for camera to initialize completely',
          );
        }

        try {
          final image = await _controller!.takePicture().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw CameraCaptureException(
                message: 'Image capture timed out',
                details: 'Camera took too long to capture image',
                suggestion: 'Try again or restart the camera',
              );
            },
          );
          
          debugPrint('Image captured: ${image.path}');
          return image;
        } catch (e, stackTrace) {
          if (e.toString().contains('permission')) {
            throw CameraPermissionException(
              details: e.toString(),
            );
          } else if (e.toString().contains('busy') || e.toString().contains('locked')) {
            throw CameraCaptureException(
              message: 'Camera is busy',
              details: e.toString(),
              suggestion: 'Wait a moment and try again',
              originalError: e,
              stackTrace: stackTrace,
            );
          } else {
            throw CameraCaptureException(
              message: 'Failed to capture image',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }
      },
      operationName: 'capture image',
    ) ?? (throw CameraCaptureException(message: 'Image capture failed completely'));
  }
  
  /// Get camera preview widget
  @override
  Widget? getCameraPreview() {
    if (_controller != null && _controller!.value.isInitialized) {
      return camera.CameraPreview(_controller!);
    }
    return null;
  }
  
  // Camera Settings Controls (These simulate professional camera controls)
  
  /// Update ISO (simulated - mobile cameras have limited ISO control)
  @override
  void updateISO(double value) {
    _iso = value;
    debugPrint('ISO updated to: $_iso');
    notifyListeners();
  }
  
  /// Update Aperture (simulated for mobile cameras)
  @override
  void updateAperture(double value) {
    _aperture = value;
    debugPrint('Aperture updated to: f/$_aperture');
    notifyListeners();
  }
  
  /// Update Shutter Speed (simulated)
  @override
  void updateShutterSpeed(double value) {
    _shutterSpeed = value;
    debugPrint('Shutter speed updated to: 1/$_shutterSpeed');
    notifyListeners();
  }
  
  /// Update White Balance
  @override
  void updateWhiteBalance(String value) {
    _whiteBalance = value;
    debugPrint('White balance updated to: $_whiteBalance');
    notifyListeners();
  }
  
  /// Set zoom level
  @override
  Future<void> setZoomLevel(double zoom) async {
    return await executeWithErrorHandling(
      () async {
        if (_controller == null) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera first',
          );
        }

        final clampedZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel);
        if (clampedZoom != zoom) {
          debugPrint('Zoom level clamped from $zoom to $clampedZoom (range: $_minZoomLevel-$_maxZoomLevel)');
        }

        await _controller!.setZoomLevel(clampedZoom);
        _zoomLevel = clampedZoom;
        notifyListeners();
      },
      operationName: 'set zoom level to $zoom',
    );
  }
  
  /// Set flash mode
  @override
  Future<void> setFlashMode(bool enabled) async {
    return await executeWithErrorHandling(
      () async {
        if (_controller == null) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera first',
          );
        }

        await _controller!.setFlashMode(
          enabled ? camera.FlashMode.auto : camera.FlashMode.off
        );
        _isFlashEnabled = enabled;
        notifyListeners();
      },
      operationName: 'set flash mode',
    );
  }
  
  /// Set focus point
  @override
  Future<void> setFocusPoint(Offset point) async {
    return await executeWithErrorHandling(
      () async {
        if (_controller == null) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera first',
          );
        }

        await _controller!.setFocusPoint(point);
        debugPrint('Focus point set to: $point');
      },
      operationName: 'set focus point',
    );
  }
  
  /// Set exposure point
  @override
  Future<void> setExposurePoint(Offset point) async {
    return await executeWithErrorHandling(
      () async {
        if (_controller == null) {
          throw CameraConnectionException(
            message: 'Camera not connected',
            suggestion: 'Initialize camera first',
          );
        }

        await _controller!.setExposurePoint(point);
        debugPrint('Exposure point set to: $point');
      },
      operationName: 'set exposure point',
    );
  }
  
  /// Apply AI-recommended settings
  @override
  Future<bool> applyAISettings(Map<String, dynamic> settings) async {
    try {
      // Basic camera settings
      if (settings.containsKey('iso')) {
        updateISO(settings['iso'].toDouble());
      }
      if (settings.containsKey('aperture')) {
        updateAperture(settings['aperture'].toDouble());
      }
      if (settings.containsKey('shutterSpeed')) {
        updateShutterSpeed(settings['shutterSpeed'].toDouble());
      }
      if (settings.containsKey('whiteBalance')) {
        updateWhiteBalance(settings['whiteBalance']);
      }
      
      // Advanced camera settings
      if (settings.containsKey('flashMode')) {
        await setFlashMode(settings['flashMode']);
      }
      if (settings.containsKey('zoomLevel')) {
        await setZoomLevel(settings['zoomLevel'].toDouble());
      }
      if (settings.containsKey('focusMode')) {
        await _setFocusMode(settings['focusMode']);
      }
      if (settings.containsKey('exposureCompensation')) {
        await _setExposureCompensation(settings['exposureCompensation'].toDouble());
      }
      if (settings.containsKey('hdr')) {
        await _setHDRMode(settings['hdr']);
      }
      if (settings.containsKey('stabilization')) {
        await _setImageStabilization(settings['stabilization']);
      }
      
      debugPrint('Applied AI settings: $settings');
      return true;
    } catch (e) {
      debugPrint('Error applying AI settings: $e');
      return false;
    }
  }

  /// Set focus mode (single, continuous, etc.)
  Future<void> _setFocusMode(String mode) async {
    if (_controller == null) return;
    
    try {
      camera.FocusMode focusMode;
      switch (mode) {
        case 'continuous':
          focusMode = camera.FocusMode.auto;
          break;
        case 'single':
          focusMode = camera.FocusMode.auto;
          break;
        case 'manual':
          focusMode = camera.FocusMode.locked;
          break;
        default:
          focusMode = camera.FocusMode.auto;
      }
      
      await _controller!.setFocusMode(focusMode);
      debugPrint('Focus mode set to: $mode');
    } catch (e) {
      debugPrint('Failed to set focus mode: $e');
    }
  }

  /// Set exposure compensation
  Future<void> _setExposureCompensation(double compensation) async {
    if (_controller == null) return;
    
    try {
      // Clamp compensation to typical range
      compensation = compensation.clamp(-2.0, 2.0);
      await _controller!.setExposureOffset(compensation);
      debugPrint('Exposure compensation set to: $compensation');
    } catch (e) {
      debugPrint('Failed to set exposure compensation: $e');
    }
  }

  /// Enable/disable HDR mode (simulated for mobile)
  Future<void> _setHDRMode(bool enabled) async {
    try {
      // Note: True HDR requires platform-specific implementation
      // This is a placeholder for HDR functionality
      debugPrint('HDR mode ${enabled ? 'enabled' : 'disabled'} (simulated)');
    } catch (e) {
      debugPrint('Failed to set HDR mode: $e');
    }
  }

  /// Enable/disable image stabilization
  Future<void> _setImageStabilization(bool enabled) async {
    try {
      // Note: Image stabilization is typically handled at hardware level
      // This is a placeholder for stabilization control
      debugPrint('Image stabilization ${enabled ? 'enabled' : 'disabled'} (simulated)');
    } catch (e) {
      debugPrint('Failed to set image stabilization: $e');
    }
  }

  /// Get current settings as a map
  @override
  Map<String, dynamic> getCurrentSettings() {
    return {
      'iso': _iso,
      'aperture': 'f/${_aperture.toStringAsFixed(1)}',
      'shutterSpeed': '1/${_shutterSpeed.toInt()}',
      'whiteBalance': _whiteBalance,
      'zoom': _zoomLevel,
      'flash': _isFlashEnabled,
      'focusDistance': _focusDistance,
    };
  }
  
  /// Disconnect camera
  @override
  Future<void> disconnectCamera({String? cameraId}) async {
    try {
      await _controller?.dispose();
      _controller = null;
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      debugPrint('Camera disconnected');
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting camera: $e');
    }
  }
  
  /// Get mock cameras for web platform testing
  List<camera.CameraDescription> _getMockCameras() {
    return [
      const camera.CameraDescription(
        name: 'Mock Back Camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      const camera.CameraDescription(
        name: 'Mock Front Camera', 
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
  }
  
  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }
    // ServiceDisposalMixin handles other resources
    super.dispose();
  }
}