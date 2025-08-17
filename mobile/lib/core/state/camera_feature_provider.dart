import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'base_state_provider.dart';
import '../providers/camera_provider.dart';
import '../utils/lens_exceptions.dart';

/// Unified camera feature state provider
/// 
/// Consolidates camera hardware control, UI state, and settings persistence
/// into a single, well-structured provider with consistent patterns.
class CameraFeatureProvider extends BaseStateProvider 
    with StatePersistenceMixin, PeriodicStateMixin {
  static const String _storageKey = 'lens_ai_camera_feature_state';
  
  // Hardware provider dependency
  CameraProvider? _cameraProvider;
  
  // Hardware state
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  List<camera.CameraDescription> _availableCameras = [];
  camera.CameraDescription? _currentCamera;
  Map<String, dynamic> _cameraCapabilities = {};
  
  // Camera settings state
  double _iso = 400;
  double _aperture = 2.8;
  double _shutterSpeed = 60; // 1/60
  String _whiteBalance = 'auto';
  double _focusDistance = 0.0;
  bool _isFlashEnabled = false;
  double _zoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  
  // UI control state
  bool _showAdvancedControls = false;
  bool _showAISuggestions = false;
  bool _showCameraControls = false;
  bool _isLiveViewActive = false;
  bool _isCapturing = false;
  bool _isDiscovering = false;
  
  // UI settings (user preferences for display)
  String _selectedCameraName = 'Mobile Camera';
  String _advancedMode = 'Basic';
  bool _showCompositionGrid = false;
  bool _showHistogram = false;
  double _previewBrightness = 1.0;
  String _captureMode = 'photo'; // photo, video, burst
  int _captureCount = 0;
  
  Map<String, dynamic> _lastUsedSettings = {};
  bool _autoSaveSettings = true;
  bool _useLastSettings = true;
  
  SharedPreferences? _prefs;
  Timer? _settingsAutoSaveTimer;
  
  // Getters - Hardware state
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  List<camera.CameraDescription> get availableCameras => List.unmodifiable(_availableCameras);
  camera.CameraDescription? get currentCamera => _currentCamera;
  Map<String, dynamic> get cameraCapabilities => Map.from(_cameraCapabilities);
  
  // Getters - Camera settings
  double get iso => _iso;
  double get aperture => _aperture;
  double get shutterSpeed => _shutterSpeed;
  String get whiteBalance => _whiteBalance;
  double get focusDistance => _focusDistance;
  bool get isFlashEnabled => _isFlashEnabled;
  double get zoomLevel => _zoomLevel;
  double get maxZoomLevel => _maxZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  
  // Getters - UI control state
  bool get showAdvancedControls => _showAdvancedControls;
  bool get showAISuggestions => _showAISuggestions;
  bool get showCameraControls => _showCameraControls;
  bool get isLiveViewActive => _isLiveViewActive;
  bool get isCapturing => _isCapturing;
  bool get isDiscovering => _isDiscovering;
  
  // Getters - UI settings
  String get selectedCameraName => _selectedCameraName;
  String get advancedMode => _advancedMode;
  bool get showCompositionGrid => _showCompositionGrid;
  bool get showHistogram => _showHistogram;
  double get previewBrightness => _previewBrightness;
  String get captureMode => _captureMode;
  int get captureCount => _captureCount;
  
  Map<String, dynamic> get lastUsedSettings => Map.from(_lastUsedSettings);
  bool get autoSaveSettings => _autoSaveSettings;
  bool get useLastSettings => _useLastSettings;
  
  @override
  String get persistenceKey => _storageKey;
  
  /// Set camera provider dependency
  void setCameraProvider(CameraProvider provider) {
    if (_cameraProvider != provider) {
      _cameraProvider = provider;
      
      // Sync initial state if provider is connected
      if (provider.isConnected) {
        _syncWithHardwareProvider();
      }
    }
  }
  
  @override
  Future<void> initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    await loadState();
    
    
    // Restore last used settings if enabled
    if (_useLastSettings && _lastUsedSettings.isNotEmpty) {
      await _restoreLastUsedSettings();
    }
    
    // Start periodic hardware sync
    startPeriodicUpdates(interval: const Duration(seconds: 2));
    
    // Set up auto-save timer
    _setupAutoSaveTimer();
  }
  
  /// Sync state with hardware camera provider
  void _syncWithHardwareProvider() {
    if (_cameraProvider == null) return;
    
    batchStateUpdates(() {
      _isConnected = _cameraProvider!.isConnected;
      _connectionStatus = _cameraProvider!.connectionStatus;
      _availableCameras = _cameraProvider!.cameras;
      _currentCamera = _cameraProvider!.currentCamera;
      
      // Sync camera settings from hardware
      _iso = _cameraProvider!.iso;
      _aperture = _cameraProvider!.aperture;
      _shutterSpeed = _cameraProvider!.shutterSpeed;
      _whiteBalance = _cameraProvider!.whiteBalance;
      _focusDistance = _cameraProvider!.focusDistance;
      _isFlashEnabled = _cameraProvider!.isFlashEnabled;
      _zoomLevel = _cameraProvider!.zoomLevel;
      _maxZoomLevel = _cameraProvider!.maxZoomLevel;
      _minZoomLevel = _cameraProvider!.minZoomLevel;
      
      if (_currentCamera != null) {
        _selectedCameraName = _getCameraDisplayName(_currentCamera!);
      }
    });
  }
  
  @override
  Future<void> performPeriodicUpdate() async {
    if (_cameraProvider != null) {
      _syncWithHardwareProvider();
    }
  }
  
  /// Get display name for camera
  String _getCameraDisplayName(camera.CameraDescription camera) {
    if (camera.lensDirection == CameraLensDirection.back) {
      return 'Back Camera';
    } else if (camera.lensDirection == CameraLensDirection.front) {
      return 'Front Camera';
    } else if (camera.lensDirection == CameraLensDirection.external) {
      return 'External Camera';
    } else {
      return 'Unknown Camera';
    }
  }
  
  
  /// Restore last used settings
  Future<void> _restoreLastUsedSettings() async {
    await executeWithErrorHandling(() async {
      if (_lastUsedSettings.isNotEmpty) {
        await updateCameraSettings(_lastUsedSettings);
      }
    }, operationName: 'restore last used settings');
  }
  
  /// Set up auto-save timer for settings
  void _setupAutoSaveTimer() {
    _settingsAutoSaveTimer?.cancel();
    
    if (_autoSaveSettings) {
      _settingsAutoSaveTimer = Timer.periodic(
        const Duration(seconds: 10),
        (timer) => _autoSaveCurrentSettings(),
      );
      
      addCleanupFunction(() => _settingsAutoSaveTimer?.cancel());
    }
  }
  
  /// Auto-save current settings
  void _autoSaveCurrentSettings() {
    if (!_autoSaveSettings) return;
    
    _lastUsedSettings = {
      'iso': _iso,
      'aperture': _aperture,
      'shutterSpeed': _shutterSpeed,
      'whiteBalance': _whiteBalance,
      'zoomLevel': _zoomLevel,
      'flashMode': _isFlashEnabled,
      'savedAt': DateTime.now().toIso8601String(),
    };
    
    // Save asynchronously without blocking UI
    saveState().catchError((e) {
      debugPrint('Auto-save failed: $e');
    });
  }
  
  // Camera hardware control methods
  
  /// Initialize camera system
  Future<void> initializeCameras() async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      setDiscovering(true);
      
      if (_cameraProvider != null) {
        await _cameraProvider!.initializeCameras();
        _syncWithHardwareProvider();
      } else {
        throw CameraConnectionException(
          message: 'No camera provider available',
          suggestion: 'Initialize camera provider first',
        );
      }
    }, 
    operationName: 'initialize cameras',
    showLoadingState: true,
    loadingMessage: 'Initializing cameras...',
    );
    
    setDiscovering(false);
  }
  
  /// Connect to specific camera
  Future<void> connectToCamera(String cameraId) async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      if (_cameraProvider != null) {
        await _cameraProvider!.connectToCamera(cameraId: cameraId);
        _syncWithHardwareProvider();
        
        // Auto-save current camera selection
        if (_autoSaveSettings) {
          _lastUsedSettings['lastUsedCamera'] = cameraId;
          await saveState();
        }
      }
    }, 
    operationName: 'connect to camera',
    showLoadingState: true,
    loadingMessage: 'Connecting to camera...',
    );
  }
  
  /// Switch to next available camera
  Future<void> switchCamera() async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      if (_cameraProvider != null) {
        await _cameraProvider!.switchCamera();
        _syncWithHardwareProvider();
      }
    }, 
    operationName: 'switch camera',
    showLoadingState: true,
    loadingMessage: 'Switching camera...',
    );
  }
  
  /// Capture image
  Future<camera.XFile?> captureImage() async {
    if (!validateState()) return null;
    
    setCapturing(true);
    
    final result = await executeWithErrorHandling<camera.XFile>(() async {
      if (_cameraProvider != null) {
        final image = await _cameraProvider!.captureImage();
        incrementCaptureCount();
        return image;
      } else {
        throw CameraCaptureException(
          message: 'No camera provider available',
        );
      }
    }, 
    operationName: 'capture image',
    showLoadingState: true,
    loadingMessage: 'Capturing image...',
    );
    
    setCapturing(false);
    return result;
  }
  
  /// Update camera settings
  Future<void> updateCameraSettings(Map<String, dynamic> settings) async {
    if (!validateState()) return;
    
    await executeWithErrorHandling(() async {
      batchStateUpdates(() {
        if (settings.containsKey('iso')) {
          _iso = settings['iso'].toDouble();
          _cameraProvider?.updateISO(_iso);
        }
        if (settings.containsKey('aperture')) {
          _aperture = settings['aperture'].toDouble();
          _cameraProvider?.updateAperture(_aperture);
        }
        if (settings.containsKey('shutterSpeed')) {
          _shutterSpeed = settings['shutterSpeed'].toDouble();
          _cameraProvider?.updateShutterSpeed(_shutterSpeed);
        }
        if (settings.containsKey('whiteBalance')) {
          _whiteBalance = settings['whiteBalance'];
          _cameraProvider?.updateWhiteBalance(_whiteBalance);
        }
        if (settings.containsKey('zoomLevel')) {
          _zoomLevel = settings['zoomLevel'].toDouble();
          _cameraProvider?.setZoomLevel(_zoomLevel);
        }
        if (settings.containsKey('flashMode')) {
          _isFlashEnabled = settings['flashMode'];
          _cameraProvider?.setFlashMode(_isFlashEnabled);
        }
      });
      
      // Auto-save if enabled
      if (_autoSaveSettings) {
        _autoSaveCurrentSettings();
      }
    }, operationName: 'update camera settings');
  }
  
  
  // UI state management methods
  
  /// Toggle advanced controls visibility
  void toggleAdvancedControls() {
    _showAdvancedControls = !_showAdvancedControls;
    notifyListeners();
  }
  
  /// Set advanced controls visibility
  void setAdvancedControlsVisible(bool visible) {
    if (_showAdvancedControls != visible) {
      _showAdvancedControls = visible;
      notifyListeners();
    }
  }
  
  /// Toggle AI suggestions visibility
  void toggleAISuggestions() {
    _showAISuggestions = !_showAISuggestions;
    notifyListeners();
  }
  
  /// Set AI suggestions visibility
  void setAISuggestionsVisible(bool visible) {
    if (_showAISuggestions != visible) {
      _showAISuggestions = visible;
      notifyListeners();
    }
  }
  
  /// Toggle camera controls visibility
  void toggleCameraControls() {
    _showCameraControls = !_showCameraControls;
    notifyListeners();
  }
  
  /// Set camera controls visibility
  void setCameraControlsVisible(bool visible) {
    if (_showCameraControls != visible) {
      _showCameraControls = visible;
      notifyListeners();
    }
  }
  
  /// Set live view state
  void setLiveViewActive(bool active) {
    if (_isLiveViewActive != active) {
      _isLiveViewActive = active;
      notifyListeners();
    }
  }
  
  /// Set capturing state
  void setCapturing(bool capturing) {
    if (_isCapturing != capturing) {
      _isCapturing = capturing;
      notifyListeners();
    }
  }
  
  /// Set discovering state
  void setDiscovering(bool discovering) {
    if (_isDiscovering != discovering) {
      _isDiscovering = discovering;
      notifyListeners();
    }
  }
  
  /// Set advanced mode
  void setAdvancedMode(String mode) {
    if (_advancedMode != mode) {
      _advancedMode = mode;
      notifyListeners();
    }
  }
  
  /// Toggle composition grid
  void toggleCompositionGrid() {
    _showCompositionGrid = !_showCompositionGrid;
    notifyListeners();
  }
  
  /// Set composition grid visibility
  void setCompositionGridVisible(bool visible) {
    if (_showCompositionGrid != visible) {
      _showCompositionGrid = visible;
      notifyListeners();
    }
  }
  
  /// Toggle histogram
  void toggleHistogram() {
    _showHistogram = !_showHistogram;
    notifyListeners();
  }
  
  /// Set histogram visibility
  void setHistogramVisible(bool visible) {
    if (_showHistogram != visible) {
      _showHistogram = visible;
      notifyListeners();
    }
  }
  
  /// Set preview brightness
  void setPreviewBrightness(double brightness) {
    brightness = brightness.clamp(0.0, 2.0);
    if (_previewBrightness != brightness) {
      _previewBrightness = brightness;
      notifyListeners();
    }
  }
  
  /// Set capture mode
  void setCaptureMode(String mode) {
    if (_captureMode != mode) {
      _captureMode = mode;
      notifyListeners();
    }
  }
  
  /// Increment capture count
  void incrementCaptureCount() {
    _captureCount++;
    notifyListeners();
  }
  
  /// Reset capture count
  void resetCaptureCount() {
    _captureCount = 0;
    notifyListeners();
  }
  
  // Settings management methods
  
  /// Set auto-save settings
  Future<void> setAutoSaveSettings(bool enabled) async {
    if (_autoSaveSettings != enabled) {
      _autoSaveSettings = enabled;
      _setupAutoSaveTimer();
      await saveState();
      notifyListeners();
    }
  }
  
  /// Set use last settings
  Future<void> setUseLastSettings(bool enabled) async {
    if (_useLastSettings != enabled) {
      _useLastSettings = enabled;
      await saveState();
      notifyListeners();
    }
  }
  
  
  // State persistence implementation
  
  @override
  Map<String, dynamic> getPersistedState() {
    return {
      'cameraSettings': {
        'iso': _iso,
        'aperture': _aperture,
        'shutterSpeed': _shutterSpeed,
        'whiteBalance': _whiteBalance,
        'focusDistance': _focusDistance,
        'isFlashEnabled': _isFlashEnabled,
        'zoomLevel': _zoomLevel,
      },
      'uiSettings': {
        'showAdvancedControls': _showAdvancedControls,
        'showAISuggestions': _showAISuggestions,
        'showCameraControls': _showCameraControls,
        'selectedCameraName': _selectedCameraName,
        'advancedMode': _advancedMode,
        'showCompositionGrid': _showCompositionGrid,
        'showHistogram': _showHistogram,
        'previewBrightness': _previewBrightness,
        'captureMode': _captureMode,
        'captureCount': _captureCount,
      },
      'settings': {
        'autoSaveSettings': _autoSaveSettings,
        'useLastSettings': _useLastSettings,
        'lastUsedSettings': _lastUsedSettings,
      },
      'savedAt': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  Future<void> restorePersistedState(Map<String, dynamic> state) async {
    batchStateUpdates(() {
      // Restore camera settings
      final cameraSettings = state['cameraSettings'] as Map<String, dynamic>? ?? {};
      _iso = cameraSettings['iso']?.toDouble() ?? 400;
      _aperture = cameraSettings['aperture']?.toDouble() ?? 2.8;
      _shutterSpeed = cameraSettings['shutterSpeed']?.toDouble() ?? 60;
      _whiteBalance = cameraSettings['whiteBalance'] ?? 'auto';
      _focusDistance = cameraSettings['focusDistance']?.toDouble() ?? 0.0;
      _isFlashEnabled = cameraSettings['isFlashEnabled'] ?? false;
      _zoomLevel = cameraSettings['zoomLevel']?.toDouble() ?? 1.0;
      
      // Restore UI settings
      final uiSettings = state['uiSettings'] as Map<String, dynamic>? ?? {};
      _showAdvancedControls = uiSettings['showAdvancedControls'] ?? false;
      _showAISuggestions = uiSettings['showAISuggestions'] ?? false;
      _showCameraControls = uiSettings['showCameraControls'] ?? false;
      _selectedCameraName = uiSettings['selectedCameraName'] ?? 'Mobile Camera';
      _advancedMode = uiSettings['advancedMode'] ?? 'Basic';
      _showCompositionGrid = uiSettings['showCompositionGrid'] ?? false;
      _showHistogram = uiSettings['showHistogram'] ?? false;
      _previewBrightness = uiSettings['previewBrightness']?.toDouble() ?? 1.0;
      _captureMode = uiSettings['captureMode'] ?? 'photo';
      _captureCount = uiSettings['captureCount'] ?? 0;
      
      
      // Restore settings
      final settings = state['settings'] as Map<String, dynamic>? ?? {};
      _autoSaveSettings = settings['autoSaveSettings'] ?? true;
      _useLastSettings = settings['useLastSettings'] ?? true;
      _lastUsedSettings = Map<String, dynamic>.from(settings['lastUsedSettings'] ?? {});
    });
  }
  
  @override
  Future<void> saveState() async {
    if (_prefs == null) return;
    
    try {
      final state = getPersistedState();
      await _prefs!.setString(_storageKey, jsonEncode(state));
    } catch (e) {
      debugPrint('Failed to save camera feature state: $e');
    }
  }
  
  @override
  Future<void> loadState() async {
    if (_prefs == null) return;
    
    try {
      final stateJson = _prefs!.getString(_storageKey);
      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        await restorePersistedState(state);
      }
    } catch (e) {
      debugPrint('Failed to load camera feature state: $e');
    }
  }
  
  @override
  void dispose() {
    _settingsAutoSaveTimer?.cancel();
    stopPeriodicUpdates();
    super.dispose();
  }
}