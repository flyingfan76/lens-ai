import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'package:mockito/mockito.dart';
import 'package:lens_ai/models/ai_suggestion.dart';
import 'package:lens_ai/services/ai/i_ai_service.dart';
import 'package:lens_ai/services/ai/local_ai_service.dart';
import 'package:lens_ai/services/ai/cloud_ai_service.dart';
import 'package:lens_ai/core/providers/camera_provider.dart';
import 'package:lens_ai/core/providers/camera_state_provider.dart';
import 'package:lens_ai/core/providers/camera_settings_provider.dart';
import 'package:lens_ai/core/utils/lens_exceptions.dart';

/// Mock implementations for testing
/// 
/// These mocks provide predictable behavior for testing various scenarios
/// including success, failure, and edge cases.

// AI Service Mocks

class MockLocalAIService extends Mock implements LocalAIService {
  bool _isInitialized = false;
  AIServiceInfo? _serviceInfo;
  AIServiceCapabilities? _capabilities;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    await Future.delayed(Duration(milliseconds: 100)); // Simulate initialization delay
    _isInitialized = true;
  }

  @override
  AIServiceInfo get serviceInfo => _serviceInfo ?? AIServiceInfo(
    name: 'Mock Local AI Service',
    version: '1.0.0-test',
    description: 'Mock implementation for testing',
    type: AIServiceType.local,
    targetPlatform: defaultTargetPlatform,
  );

  @override
  AIServiceCapabilities get capabilities => _capabilities ?? AIServiceCapabilities(
    supportsImageAnalysis: true,
    supportsRealtimeAnalysis: true,
    requiresNetworkConnection: false,
    supportsCustomPrompts: false,
    supportsCameraSettings: true,
    supportsCompositionSuggestions: true,
    supportedCategories: [
      AISuggestionCategory.iso,
      AISuggestionCategory.aperture,
      AISuggestionCategory.shutterSpeed,
      AISuggestionCategory.whiteBalance,
      AISuggestionCategory.focus,
      AISuggestionCategory.ruleOfThirds,
    ],
  );

  @override
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw Exception('Empty image data');
    }
    
    await Future.delayed(Duration(milliseconds: 200)); // Simulate processing time
    
    return SceneAnalysis(
      sceneType: 'portrait',
      lightingCondition: 'normal',
      subjectDistance: 'medium',
      movementDetected: false,
      brightness: 0.6,
      contrast: 0.5,
      colorTemperature: 5500,
      dominantColors: ['blue', 'red'],
      faces: [],
      motion: 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }

  @override
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    await Future.delayed(Duration(milliseconds: 300)); // Simulate processing time
    
    final suggestions = <AISuggestion>[
      AISuggestion(
        id: 'mock_iso',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.iso,
        title: 'Adjust ISO',
        message: 'Increase ISO to 800 for better exposure',
        icon: 'iso',
        priority: 5.0,
        confidence: 0.85,
        actionable: true,
        action: () {},
        visual: null,
        explanation: 'Mock ISO suggestion for testing',
      ),
      AISuggestion(
        id: 'mock_composition',
        type: AISuggestionType.composition,
        category: AISuggestionCategory.ruleOfThirds,
        title: 'Rule of Thirds',
        message: 'Position subject along rule of thirds lines',
        icon: 'grid',
        priority: 4.0,
        confidence: 0.75,
        actionable: false,
        action: null,
        visual: null,
        explanation: 'Mock composition suggestion for testing',
      ),
    ];
    
    return AIAnalysisResult(
      success: true,
      suggestions: suggestions,
      analysisTimestamp: DateTime.now(),
      confidence: 0.8,
    );
  }

  @override
  Future<bool> testConnection() async {
    await Future.delayed(Duration(milliseconds: 50));
    return _isInitialized;
  }

  void setServiceInfo(AIServiceInfo info) => _serviceInfo = info;
  void setCapabilities(AIServiceCapabilities caps) => _capabilities = caps;
  void setInitialized(bool initialized) => _isInitialized = initialized;
}

class MockCloudAIService extends Mock implements CloudAIService {
  bool _isInitialized = false;
  bool _shouldFail = false;
  Duration _responseDelay = Duration(milliseconds: 500);

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_shouldFail) {
      throw Exception('Mock cloud service initialization failed');
    }
    
    await Future.delayed(_responseDelay);
    _isInitialized = true;
  }

  @override
  AIServiceInfo get serviceInfo => AIServiceInfo(
    name: 'Mock Cloud AI Service',
    version: '1.0.0-test',
    description: 'Mock cloud implementation for testing',
    type: AIServiceType.cloud,
    targetPlatform: defaultTargetPlatform,
  );

  @override
  AIServiceCapabilities get capabilities => AIServiceCapabilities(
    supportsImageAnalysis: true,
    supportsRealtimeAnalysis: false,
    requiresNetworkConnection: true,
    supportsCustomPrompts: true,
    supportsCameraSettings: true,
    supportsCompositionSuggestions: true,
    supportedCategories: [
      AISuggestionCategory.iso,
      AISuggestionCategory.aperture,
      AISuggestionCategory.shutterSpeed,
      AISuggestionCategory.whiteBalance,
      AISuggestionCategory.focus,
      AISuggestionCategory.ruleOfThirds,
      AISuggestionCategory.lighting,
    ],
  );

  @override
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    if (_shouldFail) {
      throw Exception('Mock cloud analysis failed');
    }
    
    await Future.delayed(_responseDelay);
    
    return SceneAnalysis(
      sceneType: 'landscape',
      lightingCondition: 'golden_hour',
      subjectDistance: 'far',
      movementDetected: false,
      brightness: 0.7,
      contrast: 0.6,
      colorTemperature: 3200,
      dominantColors: ['orange', 'yellow'],
      faces: [],
      motion: 0.0,
      focusDistance: 1.0,
      exposureBias: 0.3,
    );
  }

  @override
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    if (_shouldFail) {
      throw Exception('Mock cloud suggestion generation failed');
    }
    
    await Future.delayed(_responseDelay);
    
    final suggestions = <AISuggestion>[
      AISuggestion(
        id: 'mock_cloud_style',
        type: AISuggestionType.creative,
        category: AISuggestionCategory.lighting,
        title: 'Golden Hour Style',
        message: 'Apply warm color grading for golden hour effect',
        icon: 'style',
        priority: 6.0,
        confidence: 0.9,
        actionable: true,
        action: () {},
        visual: null,
        explanation: 'Mock cloud style suggestion for testing',
      ),
    ];
    
    return AIAnalysisResult(
      success: true,
      suggestions: suggestions,
      analysisTimestamp: DateTime.now(),
      confidence: 0.9,
    );
  }

  @override
  Future<bool> testConnection() async {
    await Future.delayed(_responseDelay);
    return !_shouldFail;
  }

  void setShouldFail(bool shouldFail) => _shouldFail = shouldFail;
  void setResponseDelay(Duration delay) => _responseDelay = delay;
}

// Camera Provider Mocks

class MockCameraProvider extends Mock implements CameraProvider {
  bool _isInitialized = false;
  bool _isConnected = false;
  String _connectionStatus = 'disconnected';
  List<camera.CameraDescription> _cameras = [];
  camera.CameraDescription? _currentCamera;
  LensException? _lastError;
  
  // Camera settings
  double _iso = 400;
  double _aperture = 2.8;
  double _shutterSpeed = 1/60;
  String _whiteBalance = 'auto';
  double _focusDistance = 0.5;
  bool _isFlashEnabled = false;
  double _zoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 10.0;

  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String get connectionStatus => _connectionStatus;
  
  @override
  List<camera.CameraDescription> get cameras => _cameras;
  
  @override
  List<Map<String, dynamic>> get availableCameras => _cameras.map((cam) => {
    'id': cam.name,
    'name': cam.name,
    'lensDirection': cam.lensDirection.toString(),
  }).toList();
  
  @override
  camera.CameraDescription? get currentCamera => _currentCamera;
  
  @override
  bool get hasError => _lastError != null;
  
  @override
  LensException? get lastError => _lastError;
  
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
  double get minZoomLevel => _minZoomLevel;
  
  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  Future<void> initializeCameras() async {
    await Future.delayed(Duration(milliseconds: 100));
    _cameras = [
      camera.CameraDescription(
        name: 'Mock Camera 1',
        lensDirection: camera.CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      camera.CameraDescription(
        name: 'Mock Camera 2', 
        lensDirection: camera.CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
    _isInitialized = true;
    _connectionStatus = 'initialized';
  }

  @override
  Future<List<Map<String, dynamic>>> discoverCameras({bool forceRefresh = false}) async {
    if (!_isInitialized || forceRefresh) {
      await initializeCameras();
    }
    return availableCameras;
  }

  @override
  Future<void> connectToCamera({required String cameraId}) async {
    await Future.delayed(Duration(milliseconds: 200));
    final camera = _cameras.where((cam) => cam.name == cameraId).firstOrNull;
    if (camera == null) {
      _lastError = LensException.now(
        message: 'Camera not found: $cameraId',
        category: 'Camera'
      );
      throw _lastError!;
    }
    _currentCamera = camera;
    _isConnected = true;
    _connectionStatus = 'connected to $cameraId';
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    await Future.delayed(Duration(milliseconds: 100));
    final currentIndex = _cameras.indexOf(_currentCamera!);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    _currentCamera = _cameras[nextIndex];
    _connectionStatus = 'connected to ${_currentCamera!.name}';
  }

  @override
  Future<void> disconnectCamera({String? cameraId}) async {
    await Future.delayed(Duration(milliseconds: 50));
    _currentCamera = null;
    _isConnected = false;
    _connectionStatus = 'disconnected';
  }

  @override
  Widget? getCameraPreview() {
    if (!_isConnected) return null;
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Mock Camera Preview\n${_currentCamera?.name}',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Setters for testing
  void setInitialized(bool initialized) => _isInitialized = initialized;
  void setConnected(bool connected) => _isConnected = connected;
  void setConnectionStatus(String status) => _connectionStatus = status;
  void setLastError(LensException? error) => _lastError = error;
  void setCameraSettings({
    double? iso,
    double? aperture,
    double? shutterSpeed,
    String? whiteBalance,
    double? focusDistance,
    bool? flashEnabled,
    double? zoomLevel,
  }) {
    if (iso != null) _iso = iso;
    if (aperture != null) _aperture = aperture;
    if (shutterSpeed != null) _shutterSpeed = shutterSpeed;
    if (whiteBalance != null) _whiteBalance = whiteBalance;
    if (focusDistance != null) _focusDistance = focusDistance;
    if (flashEnabled != null) _isFlashEnabled = flashEnabled;
    if (zoomLevel != null) _zoomLevel = zoomLevel;
  }
}

class MockCameraStateProvider extends Mock implements CameraStateProvider {
  bool _isCapturing = false;
  bool _isRecording = false;
  String _mode = 'photo';
  double _exposureOffset = 0.0;
  String _flashMode = 'auto';
  String _focusMode = 'auto';

  @override
  bool get isCapturing => _isCapturing;
  
  bool get isRecording => _isRecording;
  
  String get mode => _mode;
  
  double get exposureOffset => _exposureOffset;
  
  String get flashMode => _flashMode;
  
  String get focusMode => _focusMode;

  @override
  void setCapturing(bool capturing) {
    _isCapturing = capturing;
    notifyListeners();
  }
  
  void setRecording(bool recording) {
    _isRecording = recording;
    notifyListeners();
  }
  
  void setMode(String mode) {
    _mode = mode;
    notifyListeners();
  }
}

class MockCameraSettingsProvider extends Mock implements CameraSettingsProvider {
  Map<String, dynamic> _settings = {
    'iso': 400,
    'aperture': 2.8,
    'shutterSpeed': 1/60,
    'whiteBalance': 'auto',
    'focusDistance': 0.5,
    'zoomLevel': 1.0,
  };

  Map<String, dynamic> get currentSettings => Map.from(_settings);

  void updateSetting(String key, dynamic value) {
    _settings[key] = value;
    notifyListeners();
  }
  
  void updateSettings(Map<String, dynamic> newSettings) {
    _settings.addAll(newSettings);
    notifyListeners();
  }
}