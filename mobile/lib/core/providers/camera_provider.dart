import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:camera_companion/core/services/camera_service.dart';

class CameraProvider with ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  
  // Multi-brand camera integration
  final CameraService _cameraService = CameraService();
  List<Map<String, dynamic>> _availableCameras = [];
  Map<String, dynamic>? _connectedCameraInfo;
  String? _activeCameraId;
  String? _activeCameraBrand;
  
  // HTTP request batching
  final Map<String, dynamic> _pendingSettingsUpdates = {};
  Timer? _batchTimer;
  static const Duration _batchDelay = Duration(milliseconds: 300);
  
  // Camera settings
  double _iso = 400;
  String _aperture = 'f/4.0';
  String _shutterSpeed = '1/125';
  String _whiteBalance = 'auto';
  
  // Getters
  CameraController? get controller => _controller;
  List<CameraDescription> get cameras => _cameras;
  List<Map<String, dynamic>> get availableCameras => _availableCameras;
  Map<String, dynamic>? get connectedCameraInfo => _connectedCameraInfo;
  String? get activeCameraId => _activeCameraId;
  String? get activeCameraBrand => _activeCameraBrand;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  
  double get iso => _iso;
  String get aperture => _aperture;
  String get shutterSpeed => _shutterSpeed;
  String get whiteBalance => _whiteBalance;

  Future<void> initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initializeController(_cameras.first);
      }
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  Future<void> _initializeController(CameraDescription camera) async {
    try {
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
    }
  }

  Future<void> discoverExternalCameras() async {
    try {
      _availableCameras = await _cameraService.discoverCameras();
      notifyListeners();
    } catch (e) {
      debugPrint('Camera discovery failed: $e');
    }
  }

  Future<void> connectToExternalCamera({required String cameraId}) async {
    _connectionStatus = 'Connecting...';
    notifyListeners();
    
    try {
      final result = await _cameraService.connectToCamera(cameraId: cameraId);
      
      if (result['success'] == true) {
        _isConnected = true;
        _connectedCameraInfo = result['cameraInfo'];
        _activeCameraId = cameraId;
        _activeCameraBrand = result['cameraInfo']['brand'];
        
        final brand = _activeCameraBrand?.toUpperCase() ?? 'CAMERA';
        final model = _connectedCameraInfo?['model'] ?? 'Unknown';
        _connectionStatus = 'Connected to $brand $model';
        
        // Load current camera settings
        await _loadCameraSettings();
      } else {
        throw Exception('Connection failed');
      }
    } catch (e) {
      _isConnected = false;
      _connectionStatus = 'Connection failed: $e';
      debugPrint('Camera connection error: $e');
    }
    
    notifyListeners();
  }

  Future<void> setActiveCamera(String cameraId) async {
    try {
      final success = await _cameraService.setActiveCamera(cameraId);
      if (success) {
        _activeCameraId = cameraId;
        
        // Find camera info from available cameras
        final camera = _availableCameras.firstWhere(
          (cam) => cam['id'] == cameraId,
          orElse: () => {},
        );
        
        if (camera.isNotEmpty) {
          _activeCameraBrand = camera['brand'];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Set active camera error: $e');
    }
  }

  Future<void> _loadCameraSettings() async {
    try {
      final result = await _cameraService.getCameraSettings(cameraId: _activeCameraId);
      final settings = result['settings'] ?? {};
      
      _iso = (settings['iso'] ?? 400).toDouble();
      _aperture = settings['aperture'] ?? 'f/4.0';
      _shutterSpeed = settings['shutter_speed'] ?? '1/125';
      _whiteBalance = settings['white_balance'] ?? 'auto';
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load camera settings: $e');
    }
  }

  Future<void> disconnectCamera({String? cameraId}) async {
    try {
      await _cameraService.disconnectCamera(cameraId: cameraId ?? _activeCameraId);
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
    
    _isConnected = false;
    _connectedCameraInfo = null;
    _activeCameraId = null;
    _activeCameraBrand = null;
    _connectionStatus = 'Disconnected';
    notifyListeners();
  }

  void updateISO(double value) {
    _iso = value;
    _queueSettingUpdate('iso', value.toInt());
    notifyListeners();
  }

  void updateAperture(String value) {
    _aperture = value;
    _queueSettingUpdate('aperture', value);
    notifyListeners();
  }

  void updateShutterSpeed(String value) {
    _shutterSpeed = value;
    _queueSettingUpdate('shutter_speed', value);
    notifyListeners();
  }

  void updateWhiteBalance(String value) {
    _whiteBalance = value;
    _queueSettingUpdate('white_balance', value);
    notifyListeners();
  }
  
  void _queueSettingUpdate(String key, dynamic value) {
    _pendingSettingsUpdates[key] = value;
    
    // Cancel existing timer and start a new one
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchDelay, _flushPendingUpdates);
  }
  
  Future<void> _flushPendingUpdates() async {
    if (_pendingSettingsUpdates.isEmpty || _activeCameraId == null) {
      return;
    }
    
    final updates = Map<String, dynamic>.from(_pendingSettingsUpdates);
    _pendingSettingsUpdates.clear();
    
    try {
      await _cameraService.updateCameraSettings(
        updates,
        cameraId: _activeCameraId
      );
      debugPrint('Batched settings update: ${updates.keys.join(', ')}');
    } catch (e) {
      debugPrint('Failed to update camera settings: $e');
      // Optionally restore values on failure
    }
  }

  Future<void> captureImage() async {
    if (!_isConnected || _activeCameraId == null) {
      debugPrint('No camera connected for capture');
      return;
    }

    try {
      final result = await _cameraService.captureImage(
        settings: getCurrentSettings(),
        cameraId: _activeCameraId,
      );
      debugPrint('Image captured: ${result['filename']} (${result['brand']})');
      // TODO: Handle captured image result
    } catch (e) {
      debugPrint('Capture failed: $e');
    }
  }

  Future<Map<String, dynamic>> startLiveView() async {
    if (!_isConnected || _activeCameraId == null) {
      throw Exception('No camera connected');
    }

    try {
      return await _cameraService.startLiveView(cameraId: _activeCameraId);
    } catch (e) {
      debugPrint('Failed to start live view: $e');
      rethrow;
    }
  }

  Future<bool> stopLiveView() async {
    try {
      return await _cameraService.stopLiveView(cameraId: _activeCameraId);
    } catch (e) {
      debugPrint('Failed to stop live view: $e');
      return false;
    }
  }

  List<String> getAvailableBrands() {
    final brands = <String>{};
    for (final camera in _availableCameras) {
      if (camera['brand'] != null) {
        brands.add(camera['brand']);
      }
    }
    return brands.toList()..sort();
  }

  List<Map<String, dynamic>> getCamerasByBrand(String brand) {
    return _availableCameras.where((camera) => camera['brand'] == brand).toList();
  }

  String getBrandDisplayName(String brand) {
    switch (brand.toLowerCase()) {
      case 'canon':
        return 'Canon';
      case 'nikon':
        return 'Nikon';
      case 'sony':
        return 'Sony';
      default:
        return brand.toUpperCase();
    }
  }

  Map<String, dynamic> getCurrentSettings() {
    return {
      'iso': _iso,
      'aperture': _aperture,
      'shutterSpeed': _shutterSpeed,
      'whiteBalance': _whiteBalance,
    };
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}