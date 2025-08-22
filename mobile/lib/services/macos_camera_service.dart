import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/builtin_camera.dart';

/// Service for accessing macOS built-in cameras via platform channel
/// This addresses the limitation where Flutter's camera plugin doesn't work on macOS
class MacOSCameraService {
  static const MethodChannel _channel = MethodChannel('lens_ai/macos_camera');
  static const EventChannel _eventChannel = EventChannel('lens_ai/macos_camera_events');
  
  static final MacOSCameraService _instance = MacOSCameraService._internal();
  factory MacOSCameraService() => _instance;
  MacOSCameraService._internal();
  
  StreamSubscription<Uint8List>? _imageStreamSubscription;
  StreamController<Uint8List>? _imageStreamController;
  
  List<BuiltInCamera> _availableCameras = [];
  BuiltInCamera? _activeCamera;
  bool _isInitialized = false;
  
  // Getters
  List<BuiltInCamera> get availableCameras => _availableCameras;
  BuiltInCamera? get activeCamera => _activeCamera;
  bool get isInitialized => _isInitialized;
  bool get isSupported => Platform.isMacOS;
  
  /// Initialize the service and discover available cameras
  Future<bool> initialize() async {
    if (!isSupported) {
      debugPrint('MacOSCameraService: Not supported on this platform');
      return false;
    }
    
    try {
      debugPrint('MacOSCameraService: Initializing...');
      
      final cameras = await _channel.invokeMethod('getAvailableCameras');
      _availableCameras = (cameras as List).map((camera) => 
        BuiltInCamera.fromMap(Map<String, dynamic>.from(camera))
      ).toList();
      
      debugPrint('MacOSCameraService: Found ${_availableCameras.length} cameras');
      for (final camera in _availableCameras) {
        debugPrint('  - ${camera.name} (${camera.lensDirection})');
      }
      
      return true;
    } catch (e) {
      debugPrint('MacOSCameraService: Initialization error: $e');
      return false;
    }
  }
  
  /// Initialize a specific camera for use
  Future<bool> initializeCamera(String cameraId) async {
    if (!isSupported) return false;
    
    try {
      debugPrint('MacOSCameraService: Initializing camera: $cameraId');
      
      final result = await _channel.invokeMethod('initializeCamera', {
        'cameraId': cameraId,
      });
      
      _activeCamera = _availableCameras.firstWhere((camera) => camera.id == cameraId);
      _isInitialized = true;
      
      debugPrint('MacOSCameraService: Camera initialized successfully');
      debugPrint('  - Preview size: ${result['previewWidth']}x${result['previewHeight']}');
      
      return true;
    } catch (e) {
      debugPrint('MacOSCameraService: Camera initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Start image stream for live preview
  Stream<Uint8List>? startImageStream() {
    if (!_isInitialized) {
      debugPrint('MacOSCameraService: Camera not initialized for image stream');
      return null;
    }
    
    try {
      debugPrint('MacOSCameraService: Starting image stream...');
      
      // Create stream controller if not exists
      _imageStreamController ??= StreamController<Uint8List>.broadcast();
      
      // Subscribe to native event channel first
      _imageStreamSubscription = _eventChannel.receiveBroadcastStream().cast<Uint8List>().listen(
        (data) {
          if (_imageStreamController != null && !_imageStreamController!.isClosed) {
            debugPrint('MacOSCameraService: Received frame data: ${data.length} bytes');
            _imageStreamController!.add(data);
          }
        },
        onError: (error) {
          debugPrint('MacOSCameraService: Image stream error: $error');
          // Try to recover from stream errors
          _handleStreamError(error);
        },
        onDone: () {
          debugPrint('MacOSCameraService: Image stream completed');
        },
      );
      
      // Start native image stream with timeout handling
      _channel.invokeMethod('startImageStream').timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugPrint('MacOSCameraService: Start image stream timed out');
          throw TimeoutException('Image stream start timed out', Duration(seconds: 10));
        },
      ).catchError((error) {
        debugPrint('MacOSCameraService: Start image stream method error: $error');
        _handleStreamError(error);
        throw error;
      });
      
      debugPrint('MacOSCameraService: Image stream setup completed');
      return _imageStreamController!.stream;
    } catch (e) {
      debugPrint('MacOSCameraService: Start image stream error: $e');
      _cleanupImageStream();
      return null;
    }
  }
  
  /// Handle stream errors and attempt recovery
  void _handleStreamError(dynamic error) {
    debugPrint('MacOSCameraService: Handling stream error: $error');
    
    // Close current stream
    _cleanupImageStream();
    
    // Optionally attempt reconnection after a delay
    Future.delayed(Duration(seconds: 1), () {
      if (_isInitialized) {
        debugPrint('MacOSCameraService: Attempting stream recovery...');
        // Could attempt to restart stream here if needed
      }
    });
  }
  
  /// Clean up image stream resources
  void _cleanupImageStream() {
    _imageStreamSubscription?.cancel();
    _imageStreamSubscription = null;
    
    if (_imageStreamController != null && !_imageStreamController!.isClosed) {
      _imageStreamController!.close();
    }
    _imageStreamController = null;
  }
  
  /// Stop image stream
  Future<void> stopImageStream() async {
    try {
      debugPrint('MacOSCameraService: Stopping image stream...');
      
      // Clean up stream resources
      _cleanupImageStream();
      
      // Stop native image stream
      await _channel.invokeMethod('stopImageStream').timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('MacOSCameraService: Stop image stream timed out');
        },
      );
      
      debugPrint('MacOSCameraService: Image stream stopped');
    } catch (e) {
      debugPrint('MacOSCameraService: Stop image stream error: $e');
    }
  }
  
  /// Take a picture and save to desktop
  Future<String?> takePicture() async {
    if (!_isInitialized) {
      debugPrint('MacOSCameraService: Camera not initialized for capture');
      return null;
    }
    
    try {
      debugPrint('MacOSCameraService: Taking picture...');
      
      final result = await _channel.invokeMethod('takePicture');
      final imagePath = result['path'] as String;
      
      debugPrint('MacOSCameraService: Picture saved to: $imagePath');
      return imagePath;
    } catch (e) {
      debugPrint('MacOSCameraService: Take picture error: $e');
      return null;
    }
  }
  
  /// Start video recording
  Future<bool> startVideoRecording() async {
    if (!_isInitialized) return false;
    
    try {
      debugPrint('MacOSCameraService: Starting video recording...');
      await _channel.invokeMethod('startVideoRecording');
      return true;
    } catch (e) {
      debugPrint('MacOSCameraService: Start video recording error: $e');
      return false;
    }
  }
  
  /// Stop video recording
  Future<String?> stopVideoRecording() async {
    try {
      debugPrint('MacOSCameraService: Stopping video recording...');
      final result = await _channel.invokeMethod('stopVideoRecording');
      return result['path'] as String?;
    } catch (e) {
      debugPrint('MacOSCameraService: Stop video recording error: $e');
      return null;
    }
  }
  
  /// Dispose camera and cleanup resources
  Future<void> dispose() async {
    try {
      debugPrint('MacOSCameraService: Disposing...');
      
      await stopImageStream();
      
      if (_isInitialized) {
        await _channel.invokeMethod('dispose');
      }
      
      _activeCamera = null;
      _isInitialized = false;
      
      debugPrint('MacOSCameraService: Disposed successfully');
    } catch (e) {
      debugPrint('MacOSCameraService: Dispose error: $e');
    }
  }
}