import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/external_camera.dart';
import '../../services/external_camera_service.dart';
import '../../services/photo_capture_service.dart';
import 'dart:async';

enum CameraSourceType {
  builtin,
  external,
}

class UnifiedCameraProvider extends ChangeNotifier {
  static final UnifiedCameraProvider _instance = UnifiedCameraProvider._internal();
  factory UnifiedCameraProvider() => _instance;
  UnifiedCameraProvider._internal() {
    _initialize();
  }

  final ExternalCameraService _externalCameraService = ExternalCameraService();
  
  // Built-in cameras
  List<CameraDescription> _builtinCameras = [];
  CameraController? _builtinController;
  
  // External cameras
  List<ExternalCamera> _externalCameras = [];
  ExternalCamera? _activeExternalCamera;
  
  // Current active camera
  CameraSourceType? _activeCameraType;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  
  StreamSubscription<List<ExternalCamera>>? _externalCameraSubscription;

  // Getters
  List<CameraDescription> get builtinCameras => _builtinCameras;
  List<ExternalCamera> get externalCameras => _externalCameras;
  CameraController? get builtinController => _builtinController;
  ExternalCamera? get activeExternalCamera => _activeExternalCamera;
  CameraSourceType? get activeCameraType => _activeCameraType;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get hasBuiltinCameras => _builtinCameras.isNotEmpty;
  bool get hasExternalCameras => _externalCameras.isNotEmpty;
  bool get hasAnyCameras => hasBuiltinCameras || hasExternalCameras;
  
  int get totalCameraCount => _builtinCameras.length + _externalCameras.length;

  Future<void> _initialize() async {
    try {
      debugPrint('UnifiedCameraProvider: Initializing...');
      
      // Initialize built-in cameras
      await _initializeBuiltinCameras();
      
      // Initialize external camera discovery
      await _initializeExternalCameras();
      
      _isLoading = false;
      _error = null;
      notifyListeners();
      
      debugPrint('UnifiedCameraProvider: Initialization complete');
      debugPrint('  - Built-in cameras: ${_builtinCameras.length}');
      debugPrint('  - External cameras: ${_externalCameras.length}');
      
    } catch (e) {
      _error = 'Camera initialization failed: $e';
      _isLoading = false;
      debugPrint('UnifiedCameraProvider: Initialization error: $e');
      notifyListeners();
    }
  }

  Future<void> _initializeBuiltinCameras() async {
    try {
      _builtinCameras = await availableCameras();
      debugPrint('UnifiedCameraProvider: Found ${_builtinCameras.length} built-in cameras');
      
      for (final camera in _builtinCameras) {
        debugPrint('  - ${camera.name} (${camera.lensDirection.name})');
      }
    } catch (e) {
      debugPrint('UnifiedCameraProvider: Built-in camera error: $e');
      // Don't throw - external cameras might still work
    }
  }

  Future<void> _initializeExternalCameras() async {
    try {
      // Initialize from stored state first
      await _externalCameraService.initializeFromStorage();
      
      // Subscribe to external camera discoveries
      _externalCameraSubscription = _externalCameraService.cameraStream.listen(
        (cameras) {
          _externalCameras = cameras;
          debugPrint('UnifiedCameraProvider: External cameras updated: ${cameras.length}');
          
          // Auto-select connected camera if no camera is currently active
          if (_activeExternalCamera == null && cameras.isNotEmpty) {
            final connectedCamera = cameras.firstWhere(
              (camera) => camera.isConnected,
              orElse: () => cameras.first,
            );
            if (connectedCamera.isConnected) {
              debugPrint('UnifiedCameraProvider: Auto-selecting connected camera: ${connectedCamera.name}');
              _activeExternalCamera = connectedCamera;
              _activeCameraType = CameraSourceType.external;
              _isInitialized = true;
              _error = null;  // CRITICAL: Clear any previous errors
              debugPrint('UnifiedCameraProvider: Camera auto-selected successfully, error cleared');
            }
          }
          
          notifyListeners();
        },
      );
      
      // Start discovery
      await _externalCameraService.startDiscovery();
    } catch (e) {
      debugPrint('UnifiedCameraProvider: External camera initialization error: $e');
    }
  }

  Future<bool> switchToBuiltinCamera(CameraDescription camera) async {
    try {
      debugPrint('UnifiedCameraProvider: Switching to built-in camera: ${camera.name}');
      
      // Disconnect from external camera if active
      if (_activeExternalCamera != null) {
        await disconnectFromExternalCamera();
      }
      
      // Dispose current built-in controller
      await _builtinController?.dispose();
      
      // Initialize new built-in camera controller
      _builtinController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _builtinController!.initialize();
      
      _activeCameraType = CameraSourceType.builtin;
      _isInitialized = true;
      _error = null;
      
      notifyListeners();
      
      debugPrint('UnifiedCameraProvider: Successfully switched to built-in camera');
      return true;
      
    } catch (e) {
      _error = 'Failed to switch to built-in camera: $e';
      _isInitialized = false;
      debugPrint('UnifiedCameraProvider: Built-in camera switch error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> switchToExternalCamera(ExternalCamera camera) async {
    try {
      debugPrint('UnifiedCameraProvider: Switching to external camera: ${camera.name}');
      
      // Dispose built-in controller if active
      if (_builtinController != null) {
        await _builtinController!.dispose();
        _builtinController = null;
      }
      
      // Disconnect from current external camera if different
      if (_activeExternalCamera != null && _activeExternalCamera!.id != camera.id) {
        await disconnectFromExternalCamera();
      }
      
      // Connect to external camera
      final connected = await _externalCameraService.connectToCamera(camera.id);
      
      if (connected) {
        // Get the updated camera object from the service to ensure we have the latest connection state
        final updatedCamera = _externalCameraService.discoveredCameras
            .firstWhere((c) => c.id == camera.id, orElse: () => camera);
        _activeExternalCamera = updatedCamera;
        _activeCameraType = CameraSourceType.external;
        _isInitialized = true;
        _error = null;
        
        notifyListeners();
        
        debugPrint('UnifiedCameraProvider: Successfully switched to external camera');
        return true;
      } else {
        // Provide more specific error message based on camera type
        String errorDetails = '';
        if (camera.model == 'Unknown Model') {
          errorDetails = ' (Camera model not recognized. Please ensure drivers are installed.)';
        } else if (camera.connectionType == CameraConnectionType.usb) {
          errorDetails = ' (USB connection failed. Check cable and permissions.)';
        } else if (camera.connectionType == CameraConnectionType.wifi) {
          errorDetails = ' (WiFi connection failed. Check network and camera settings.)';
        }
        
        _error = 'Failed to connect to external camera: ${camera.name}$errorDetails';
        debugPrint('UnifiedCameraProvider: External camera connection failed - ${camera.name}');
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      _error = 'Failed to switch to external camera: $e';
      _isInitialized = false;
      debugPrint('UnifiedCameraProvider: External camera switch error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectFromExternalCamera() async {
    if (_activeExternalCamera != null) {
      try {
        await _externalCameraService.disconnectFromCamera(_activeExternalCamera!.id);
        _activeExternalCamera = null;
        
        if (_activeCameraType == CameraSourceType.external) {
          _activeCameraType = null;
          _isInitialized = false;
        }
        
        notifyListeners();
      } catch (e) {
        debugPrint('UnifiedCameraProvider: Disconnect error: $e');
      }
    }
  }

  Future<void> refreshExternalCameras() async {
    try {
      debugPrint('UnifiedCameraProvider: Refreshing external camera discovery...');
      await _externalCameraService.stopDiscovery();
      await _externalCameraService.startDiscovery();
    } catch (e) {
      debugPrint('UnifiedCameraProvider: Refresh error: $e');
    }
  }

  /// Clear any error state and attempt to recover
  void clearError() {
    _error = null;
    debugPrint('UnifiedCameraProvider: Error state cleared');
    // Also clear any cached cameras that might be causing issues
    _externalCameraService.clearDiscoveredCameras();
    notifyListeners();
  }

  /// Refresh cameras (alias for refreshExternalCameras for compatibility)
  Future<void> refreshCameras() async {
    await refreshExternalCameras();
  }

  // Live view functionality
  Stream<Uint8List>? get liveViewStream => _externalCameraService.liveViewStream;
  bool get isLiveViewActive => _externalCameraService.isLiveViewActive;

  /// Start live view for the active external camera
  Future<bool> startLiveView() async {
    debugPrint('======================================');
    debugPrint('UnifiedCameraProvider: startLiveView called');
    debugPrint('UnifiedCameraProvider: _activeExternalCamera = $_activeExternalCamera');
    debugPrint('UnifiedCameraProvider: _activeCameraType = $_activeCameraType');
    debugPrint('UnifiedCameraProvider: Current error state = $_error');
    debugPrint('======================================');
    
    if (_activeExternalCamera == null) {
      debugPrint('UnifiedCameraProvider: ERROR - No external camera is active - cannot start live view');
      _error = 'No external camera is active';
      notifyListeners();
      return false;
    }

    try {
      debugPrint('UnifiedCameraProvider: Starting live view for ${_activeExternalCamera!.name} (id: ${_activeExternalCamera!.id})');
      final success = await _externalCameraService.startLiveView(_activeExternalCamera!.id);
      if (success) {
        debugPrint('UnifiedCameraProvider: Live view started successfully for ${_activeExternalCamera!.name}');
      } else {
        debugPrint('UnifiedCameraProvider: Live view failed to start for ${_activeExternalCamera!.name}');
        _error = 'Failed to start live view';
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Live view error: $e';
      debugPrint('UnifiedCameraProvider: Live view error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Stop live view
  Future<void> stopLiveView() async {
    try {
      await _externalCameraService.stopLiveView();
      debugPrint('UnifiedCameraProvider: Live view stopped');
    } catch (e) {
      debugPrint('UnifiedCameraProvider: Stop live view error: $e');
    }
  }
  
  /// Stop macOS PTP services that block camera access
  Future<bool> stopPTPService() async {
    try {
      debugPrint('UnifiedCameraProvider: Stopping PTP service');
      final success = await _externalCameraService.stopPTPService();
      debugPrint('UnifiedCameraProvider: Stop PTP service result: $success');
      return success;
    } catch (e) {
      debugPrint('UnifiedCameraProvider: Stop PTP service error: $e');
      return false;
    }
  }

  Future<bool> capturePhoto() async {
    if (!_isInitialized) {
      _error = 'No camera is active';
      notifyListeners();
      return false;
    }
    
    try {
      if (_activeCameraType == CameraSourceType.builtin && _builtinController != null) {
        final image = await _builtinController!.takePicture();
        debugPrint('UnifiedCameraProvider: Built-in photo captured: ${image.path}');
        return true;
        
      } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
        // Implement external camera capture
        debugPrint('UnifiedCameraProvider: External camera capture requested');
        // TODO: Call external camera service capture method
        return await _captureExternalPhoto();
      }
      
      return false;
    } catch (e) {
      _error = 'Photo capture failed: $e';
      debugPrint('UnifiedCameraProvider: Capture error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Capture photo from external camera
  Future<bool> _captureExternalPhoto() async {
    if (_activeExternalCamera == null) return false;
    
    try {
      debugPrint('UnifiedCameraProvider: Capturing photo from ${_activeExternalCamera!.name}');
      
      // Use PhotoCaptureService for comprehensive capture handling
      final PhotoCaptureService photoCaptureService = PhotoCaptureService();
      
      // Read save to phone setting
      final shouldSaveToPhone = await _getShouldSaveToPhone();
      
      final result = await photoCaptureService.capturePhoto(
        camera: _activeExternalCamera!,
        saveToPhone: shouldSaveToPhone,
      );
      
      if (result.success) {
        debugPrint('UnifiedCameraProvider: Photo captured successfully');
        debugPrint('  - Camera file: ${result.cameraFilePath}');
        debugPrint('  - Phone file: ${result.phoneFilePath}');
        debugPrint('  - Formats: ${result.originalFormat} -> ${result.phoneFormat}');
        return true;
      } else {
        debugPrint('UnifiedCameraProvider: Photo capture failed: ${result.error}');
        _error = result.error;
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      debugPrint('UnifiedCameraProvider: External capture error: $e');
      _error = 'Photo capture failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> startVideoRecording() async {
    if (!_isInitialized) {
      _error = 'No camera is active';
      notifyListeners();
      return;
    }
    
    try {
      if (_activeCameraType == CameraSourceType.builtin && _builtinController != null) {
        await _builtinController!.startVideoRecording();
        debugPrint('UnifiedCameraProvider: Built-in video recording started');
        
      } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
        // Implement external camera video recording
        debugPrint('UnifiedCameraProvider: External camera video recording requested');
        // Video recording not supported for external cameras - focusing on picture capture only
      }
    } catch (e) {
      _error = 'Video recording failed: $e';
      debugPrint('UnifiedCameraProvider: Video recording error: $e');
      notifyListeners();
    }
  }

  Future<void> stopVideoRecording() async {
    try {
      if (_activeCameraType == CameraSourceType.builtin && _builtinController != null) {
        final video = await _builtinController!.stopVideoRecording();
        debugPrint('UnifiedCameraProvider: Built-in video recording stopped: ${video.path}');
        
      } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
        // Implement external camera video stop
        debugPrint('UnifiedCameraProvider: External camera video recording stop requested');
        // Video recording not supported for external cameras - focusing on picture capture only
      }
    } catch (e) {
      _error = 'Stop video recording failed: $e';
      debugPrint('UnifiedCameraProvider: Stop video recording error: $e');
      notifyListeners();
    }
  }

  String getActiveCameraName() {
    if (_activeCameraType == CameraSourceType.builtin && _builtinController != null) {
      return _builtinController!.description.name;
    } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
      return _activeExternalCamera!.name;
    }
    return 'No camera active';
  }

  Map<String, dynamic> getActiveCameraInfo() {
    if (_activeCameraType == CameraSourceType.builtin && _builtinController != null) {
      final desc = _builtinController!.description;
      return {
        'type': 'builtin',
        'name': desc.name,
        'lensDirection': desc.lensDirection.name,
        'sensorOrientation': desc.sensorOrientation,
      };
    } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
      return {
        'type': 'external',
        'name': _activeExternalCamera!.name,
        'model': _activeExternalCamera!.model,
        'brand': _activeExternalCamera!.brand.name,
        'connectionType': _activeExternalCamera!.connectionType.name,
        'capabilities': _activeExternalCamera!.capabilities,
      };
    }
    return {'type': 'none'};
  }

  /// Read the save to phone setting from SharedPreferences
  Future<bool> _getShouldSaveToPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('save_pictures_to_phone') ?? true;
    } catch (e) {
      debugPrint('UnifiedCameraProvider: Error reading save to phone setting: $e');
      return true; // Default to saving
    }
  }

  @override
  void dispose() {
    _externalCameraSubscription?.cancel();
    _builtinController?.dispose();
    _externalCameraService.dispose();
    super.dispose();
  }
}