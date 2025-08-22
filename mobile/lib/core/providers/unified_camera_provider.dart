import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/external_camera.dart';
import '../../models/builtin_camera.dart';
import '../../services/external_camera_service.dart';
import '../../services/photo_capture_service.dart';
import '../../services/macos_camera_service.dart';
import 'dart:async';
import 'dart:io';

enum CameraSourceType {
  builtin,
  builtinMacOS, // macOS built-in cameras via platform channel
  external,
}

class UnifiedCameraProvider extends ChangeNotifier {
  static final UnifiedCameraProvider _instance = UnifiedCameraProvider._internal();
  factory UnifiedCameraProvider() => _instance;
  UnifiedCameraProvider._internal() {
    _initialize();
  }

  final ExternalCameraService _externalCameraService = ExternalCameraService();
  final MacOSCameraService _macOSCameraService = MacOSCameraService();
  
  // Built-in cameras (iOS/Android via camera plugin)
  List<CameraDescription> _builtinCameras = [];
  CameraController? _builtinController;
  
  // macOS built-in cameras (via platform channel)
  List<BuiltInCamera> _macOSCameras = [];
  BuiltInCamera? _activeMacOSCamera;
  Stream<Uint8List>? _macOSCameraStream;
  
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
  List<BuiltInCamera> get macOSCameras => _macOSCameras;
  List<ExternalCamera> get externalCameras => _externalCameras;
  CameraController? get builtinController => _builtinController;
  BuiltInCamera? get activeMacOSCamera => _activeMacOSCamera;
  ExternalCamera? get activeExternalCamera => _activeExternalCamera;
  CameraSourceType? get activeCameraType => _activeCameraType;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get hasBuiltinCameras => _builtinCameras.isNotEmpty;
  bool get hasMacOSCameras => _macOSCameras.isNotEmpty;
  bool get hasExternalCameras => _externalCameras.isNotEmpty;
  bool get hasAnyCameras => hasBuiltinCameras || hasMacOSCameras || hasExternalCameras;
  
  int get totalCameraCount => _builtinCameras.length + _macOSCameras.length + _externalCameras.length;

  Future<void> _initialize() async {
    try {
      debugPrint('UnifiedCameraProvider: Initializing...');
      
      // Initialize built-in cameras based on platform
      if (Platform.isMacOS) {
        await _initializeMacOSCameras();
      } else {
        await _initializeBuiltinCameras();
      }
      
      // Initialize external camera discovery
      await _initializeExternalCameras();
      
      _isLoading = false;
      _error = null;
      notifyListeners();
      
      debugPrint('UnifiedCameraProvider: Initialization complete');
      debugPrint('  - Built-in cameras: ${_builtinCameras.length}');
      debugPrint('  - macOS cameras: ${_macOSCameras.length}');
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

  Future<void> _initializeMacOSCameras() async {
    try {
      debugPrint('UnifiedCameraProvider: Initializing macOS cameras...');
      
      final success = await _macOSCameraService.initialize();
      if (success) {
        _macOSCameras = _macOSCameraService.availableCameras;
        debugPrint('UnifiedCameraProvider: Found ${_macOSCameras.length} macOS cameras');
        
        for (final camera in _macOSCameras) {
          debugPrint('  - ${camera.name} (${camera.lensDirection})');
        }
      } else {
        debugPrint('UnifiedCameraProvider: macOS camera initialization failed');
        
        debugPrint('UnifiedCameraProvider: macOS camera initialization complete');
      }
    } catch (e) {
      debugPrint('UnifiedCameraProvider: macOS camera error: $e');
      
      debugPrint('UnifiedCameraProvider: macOS camera error: $e');
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
      
      // Disconnect from other cameras if active
      await _disconnectFromAllCameras();
      
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

  Future<bool> switchToMacOSCamera(BuiltInCamera camera) async {
    try {
      debugPrint('UnifiedCameraProvider: Switching to macOS camera: ${camera.name}');
      
      // Disconnect from other cameras if active
      await _disconnectFromAllCameras();
      
      // Initialize macOS camera
      final success = await _macOSCameraService.initializeCamera(camera.id);
      
      if (success) {
        _activeMacOSCamera = camera;
        _activeCameraType = CameraSourceType.builtinMacOS;
        _isInitialized = true;
        _error = null;
        
        notifyListeners();
        
        debugPrint('UnifiedCameraProvider: Successfully switched to macOS camera');
        return true;
      } else {
        _error = 'Failed to initialize macOS camera: ${camera.name}';
        debugPrint('UnifiedCameraProvider: macOS camera initialization failed');
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      _error = 'Failed to switch to macOS camera: $e';
      _isInitialized = false;
      debugPrint('UnifiedCameraProvider: macOS camera switch error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> switchToExternalCamera(ExternalCamera camera) async {
    try {
      debugPrint('UnifiedCameraProvider: Switching to external camera: ${camera.name}');
      
      // Disconnect from other cameras if active (but preserve external camera connections)
      await _disconnectFromAllCameras();
      
      // CRITICAL FIX: Only disconnect from external camera if it's ACTUALLY a different camera
      // Previously this was breaking D90 reconnection by disconnecting the same camera
      if (_activeExternalCamera != null && _activeExternalCamera!.id != camera.id) {
        debugPrint('UnifiedCameraProvider: Switching to different external camera, disconnecting previous: ${_activeExternalCamera!.name}');
        await disconnectFromExternalCamera();
      } else if (_activeExternalCamera != null && _activeExternalCamera!.id == camera.id) {
        debugPrint('UnifiedCameraProvider: Same external camera selected (${camera.name}), preserving connection and reusing');
        // Don't disconnect - we're switching back to the same camera!
        _activeExternalCamera = camera; // Update reference
        _activeCameraType = CameraSourceType.external;
        _isInitialized = true;
        _error = null;
        notifyListeners();
        debugPrint('UnifiedCameraProvider: Successfully reactivated same external camera: ${camera.name}');
        return true;
      }
      
      // Check if camera is already connected (preserved from previous session)
      final currentCamera = _externalCameraService.discoveredCameras
          .firstWhere((c) => c.id == camera.id, orElse: () => camera);
      
      bool connected = currentCamera.isConnected;
      
      // Only attempt connection if not already connected
      if (!connected) {
        debugPrint('UnifiedCameraProvider: Camera not connected, attempting connection...');
        connected = await _externalCameraService.connectToCamera(camera.id);
      } else {
        debugPrint('UnifiedCameraProvider: Camera already connected, reusing connection');
      }
      
      if (connected) {
        // Get the updated camera object from the service to ensure we have the latest connection state
        final updatedCamera = _externalCameraService.discoveredCameras
            .firstWhere((c) => c.id == camera.id, orElse: () => camera);
        _activeExternalCamera = updatedCamera;
        _activeCameraType = CameraSourceType.external;
        _isInitialized = true;
        _error = null;
        
        notifyListeners();
        
        debugPrint('UnifiedCameraProvider: Successfully switched to external camera (connection preserved)');
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

  /// Helper method to disconnect from all active cameras
  Future<void> _disconnectFromAllCameras() async {
    // Dispose built-in controller
    if (_builtinController != null) {
      await _builtinController!.dispose();
      _builtinController = null;
    }
    
    // Dispose macOS camera
    if (_activeMacOSCamera != null) {
      await _macOSCameraService.dispose();
      _activeMacOSCamera = null;
      _macOSCameraStream = null;
    }
    
    // CRITICAL FIX: Stop live view without disconnecting external camera 
    // This preserves the camera connection state for faster switching
    if (_activeExternalCamera != null && _externalCameraService.isLiveViewActive) {
      debugPrint('UnifiedCameraProvider: Stopping external camera live view without disconnecting');
      await _externalCameraService.stopLiveView();
    }
    
    // Don't disconnect external camera - this was causing the switching issue!
    // External cameras should remain connected for faster switching
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

  /// Refresh all cameras (external and macOS)
  Future<void> refreshCameras() async {
    debugPrint('UnifiedCameraProvider: Refreshing all cameras...');
    
    // Refresh external cameras
    await refreshExternalCameras();
    
    // Refresh macOS cameras if on macOS platform
    if (Platform.isMacOS) {
      await _initializeMacOSCameras();
      notifyListeners();
      debugPrint('UnifiedCameraProvider: macOS cameras refreshed - Found ${_macOSCameras.length} cameras');
    }
  }

  // Live view functionality
  Stream<Uint8List>? get liveViewStream {
    if (_activeCameraType == CameraSourceType.builtinMacOS) {
      return _macOSCameraStream;
    }
    return _externalCameraService.liveViewStream;
  }
  
  bool get isLiveViewActive {
    if (_activeCameraType == CameraSourceType.builtinMacOS) {
      return _macOSCameraStream != null;
    }
    return _externalCameraService.isLiveViewActive;
  }

  /// Start live view for the active camera
  Future<bool> startLiveView() async {
    debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    debugPrint('🚀 LIVE VIEW START ATTEMPT - UnifiedCameraProvider.startLiveView() CALLED');
    debugPrint('UnifiedCameraProvider: _activeCameraType = $_activeCameraType');
    debugPrint('UnifiedCameraProvider: _activeExternalCamera = $_activeExternalCamera');
    debugPrint('UnifiedCameraProvider: _activeMacOSCamera = $_activeMacOSCamera');
    debugPrint('UnifiedCameraProvider: Current error state = $_error');
    debugPrint('UnifiedCameraProvider: isLiveViewActive = $isLiveViewActive');
    debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    
    // CRITICAL FIX: Prevent infinite loop by checking if live view is already active
    if (isLiveViewActive) {
      debugPrint('UnifiedCameraProvider: ⚠️ Live view already active - skipping start attempt');
      return true; // Already active, return success
    }
    
    if (_activeCameraType == CameraSourceType.builtinMacOS) {
      return await _startMacOSLiveView();
    } else if (_activeCameraType == CameraSourceType.external) {
      return await _startExternalLiveView();
    } else {
      debugPrint('UnifiedCameraProvider: ERROR - No compatible camera is active for live view');
      _error = 'No compatible camera is active for live view';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _startMacOSLiveView() async {
    if (_activeMacOSCamera == null) {
      debugPrint('UnifiedCameraProvider: ERROR - No macOS camera is active');
      _error = 'No macOS camera is active';
      notifyListeners();
      return false;
    }

    // Retry logic for macOS live view
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('UnifiedCameraProvider: Starting macOS live view attempt $attempt/3 for ${_activeMacOSCamera!.name}');
        
        // Clear any previous error
        _error = null;
        notifyListeners();
        
        // Initialize the camera if not already done
        if (!_macOSCameraService.isInitialized) {
          debugPrint('UnifiedCameraProvider: Initializing macOS camera service...');
          final initSuccess = await _macOSCameraService.initialize();
          if (!initSuccess) {
            throw Exception('Failed to initialize macOS camera service');
          }
          
          // Initialize the specific camera
          final cameraInitSuccess = await _macOSCameraService.initializeCamera(_activeMacOSCamera!.id);
          if (!cameraInitSuccess) {
            throw Exception('Failed to initialize camera ${_activeMacOSCamera!.id}');
          }
        }
        
        // Start the image stream with timeout
        _macOSCameraStream = _macOSCameraService.startImageStream();
        
        if (_macOSCameraStream != null) {
          debugPrint('UnifiedCameraProvider: macOS live view started successfully for ${_activeMacOSCamera!.name}');
          _error = null;
          notifyListeners();
          return true;
        } else {
          throw Exception('Image stream returned null');
        }
        
      } catch (e) {
        debugPrint('UnifiedCameraProvider: macOS live view attempt $attempt failed: $e');
        
        if (attempt < 3) {
          // Wait before retry
          await Future.delayed(Duration(seconds: 2));
          
          // Clean up before retry
          try {
            await _macOSCameraService.stopImageStream();
          } catch (cleanupError) {
            debugPrint('UnifiedCameraProvider: Cleanup error during retry: $cleanupError');
          }
        } else {
          // Final attempt failed
          _error = 'Failed to start macOS live view after 3 attempts: $e';
          debugPrint('UnifiedCameraProvider: ${_error}');
          notifyListeners();
          return false;
        }
      }
    }
    
    return false;
  }

  Future<bool> _startExternalLiveView() async {
    if (_activeExternalCamera == null) {
      debugPrint('UnifiedCameraProvider: ERROR - No external camera is active');
      _error = 'No external camera is active';
      notifyListeners();
      return false;
    }

    try {
      debugPrint('UnifiedCameraProvider: Starting external live view for ${_activeExternalCamera!.name} (id: ${_activeExternalCamera!.id})');
      final success = await _externalCameraService.startLiveView(_activeExternalCamera!.id);
      if (success) {
        debugPrint('UnifiedCameraProvider: External live view started successfully for ${_activeExternalCamera!.name}');
        _error = null;
        notifyListeners(); // CRITICAL FIX: Notify UI that live view state changed
      } else {
        debugPrint('UnifiedCameraProvider: External live view failed to start for ${_activeExternalCamera!.name}');
        _error = 'Failed to start external live view';
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'External live view error: $e';
      debugPrint('UnifiedCameraProvider: External live view error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Stop live view
  Future<void> stopLiveView() async {
    try {
      if (_activeCameraType == CameraSourceType.builtinMacOS) {
        await _macOSCameraService.stopImageStream();
        _macOSCameraStream = null;
        debugPrint('UnifiedCameraProvider: macOS live view stopped');
      } else {
        await _externalCameraService.stopLiveView();
        debugPrint('UnifiedCameraProvider: External live view stopped');
      }
      notifyListeners();
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
        
      } else if (_activeCameraType == CameraSourceType.builtinMacOS && _activeMacOSCamera != null) {
        final imagePath = await _macOSCameraService.takePicture();
        if (imagePath != null) {
          debugPrint('UnifiedCameraProvider: macOS photo captured: $imagePath');
          return true;
        } else {
          debugPrint('UnifiedCameraProvider: macOS photo capture failed');
          _error = 'macOS photo capture failed';
          notifyListeners();
          return false;
        }
        
      } else if (_activeCameraType == CameraSourceType.external && _activeExternalCamera != null) {
        debugPrint('UnifiedCameraProvider: External camera capture requested');
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
    } else if (_activeCameraType == CameraSourceType.builtinMacOS && _activeMacOSCamera != null) {
      return _activeMacOSCamera!.name;
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
    } else if (_activeCameraType == CameraSourceType.builtinMacOS && _activeMacOSCamera != null) {
      return {
        'type': 'builtinMacOS',
        'name': _activeMacOSCamera!.name,
        'lensDirection': _activeMacOSCamera!.lensDirection,
        'sensorOrientation': _activeMacOSCamera!.sensorOrientation,
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
    _macOSCameraService.dispose();
    _externalCameraService.dispose();
    super.dispose();
  }
}