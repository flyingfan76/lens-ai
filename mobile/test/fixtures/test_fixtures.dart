import 'dart:typed_data';
import 'package:lens_ai/models/ai_suggestion.dart';
import 'package:lens_ai/services/ai/ai_coordinator.dart';

/// Test fixtures providing consistent test data across test suites
class TestFixtures {
  
  // AI Service Test Data
  
  static const validImageBytes = [
    137, 80, 78, 71, 13, 10, 26, 10, // PNG header
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
    0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0, 3, 0, 1, 124, 181, 223, 203,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ];

  static Uint8List get validImage => Uint8List.fromList(validImageBytes);
  static Uint8List get emptyImage => Uint8List(0);
  static Uint8List get invalidImage => Uint8List.fromList([1, 2, 3, 4, 5]);

  // Scene Analysis Test Data

  static SceneAnalysis get portraitScene => SceneAnalysis(
    sceneType: 'portrait',
    lightingCondition: 'normal',
    subjectDistance: 'close',
    movementDetected: false,
    brightness: 0.6,
    contrast: 0.5,
    colorTemperature: 5500,
    dominantColors: ['skin_tone', 'blue'],
    faces: [FaceDetection(x: 0.3, y: 0.4, width: 0.2, height: 0.3, confidence: 0.9)],
    motion: 0.0,
    focusDistance: 0.3,
    exposureBias: 0.0,
  );

  static SceneAnalysis get landscapeScene => SceneAnalysis(
    sceneType: 'landscape',
    lightingCondition: 'golden_hour',
    subjectDistance: 'far',
    movementDetected: false,
    brightness: 0.7,
    contrast: 0.6,
    colorTemperature: 3200,
    dominantColors: ['orange', 'blue', 'green'],
    faces: [],
    motion: 0.0,
    focusDistance: 1.0,
    exposureBias: 0.3,
  );

  static SceneAnalysis get lowLightScene => SceneAnalysis(
    sceneType: 'night',
    lightingCondition: 'low',
    subjectDistance: 'medium',
    movementDetected: false,
    brightness: 0.2,
    contrast: 0.8,
    colorTemperature: 2800,
    dominantColors: ['black', 'yellow'],
    faces: [],
    motion: 0.0,
    focusDistance: 0.5,
    exposureBias: -0.5,
  );

  static SceneAnalysis get actionScene => SceneAnalysis(
    sceneType: 'sports',
    lightingCondition: 'bright',
    subjectDistance: 'medium',
    movementDetected: true,
    brightness: 0.8,
    contrast: 0.4,
    colorTemperature: 6000,
    dominantColors: ['green', 'white'],
    faces: [],
    motion: 0.8,
    focusDistance: 0.7,
    exposureBias: 0.0,
  );

  // AI Suggestion Test Data

  static AISuggestion get isoSuggestion => AISuggestion(
    id: 'test_iso_001',
    type: AISuggestionType.cameraSettings,
    category: AISuggestionCategory.iso,
    title: 'Increase ISO',
    message: 'Raise ISO to 800 for better low-light performance',
    icon: 'iso',
    priority: 8.0,
    confidence: 0.85,
    actionable: true,
    action: () {},
    visual: null,
    explanation: 'Low light conditions detected. Increasing ISO will brighten the image.',
  );

  static AISuggestion get apertureSuggestion => AISuggestion(
    id: 'test_aperture_001',
    type: AISuggestionType.cameraSettings,
    category: AISuggestionCategory.aperture,
    title: 'Open Aperture',
    message: 'Use f/2.8 for better depth of field',
    icon: 'aperture',
    priority: 7.0,
    confidence: 0.75,
    actionable: true,
    action: () {},
    visual: null,
    explanation: 'Portrait subject detected. Wider aperture creates pleasing background blur.',
  );

  static AISuggestion get compositionSuggestion => AISuggestion(
    id: 'test_composition_001',
    type: AISuggestionType.composition,
    category: AISuggestionCategory.ruleOfThirds,
    title: 'Rule of Thirds',
    message: 'Position subject along grid lines',
    icon: 'grid',
    priority: 5.0,
    confidence: 0.65,
    actionable: false,
    action: null,
    visual: null,
    explanation: 'Subject is centered. Try positioning along rule of thirds lines for better composition.',
  );

  static AISuggestion get styleSuggestion => AISuggestion(
    id: 'test_style_001',
    type: AISuggestionType.creative,
    category: AISuggestionCategory.lighting,
    title: 'Golden Hour Filter',
    message: 'Apply warm color grading',
    icon: 'filter',
    priority: 6.0,
    confidence: 0.8,
    actionable: true,
    action: null,
    visual: null,
    explanation: 'Golden hour lighting detected. Warm filter enhances the natural tones.',
  );

  static List<AISuggestion> get mixedSuggestions => [
    isoSuggestion,
    apertureSuggestion,
    compositionSuggestion,
    styleSuggestion,
  ];

  // AI Analysis Results

  static AIAnalysisResult get successfulAnalysis => AIAnalysisResult(
    success: true,
    suggestions: mixedSuggestions,
    analysisTimestamp: DateTime.now(),
    confidence: 0.78,
  );

  static AIAnalysisResult get failedAnalysis => AIAnalysisResult(
    success: false,
    suggestions: [],
    analysisTimestamp: DateTime.now(),
    confidence: 0.0,
  );

  static AIAnalysisResult get lowConfidenceAnalysis => AIAnalysisResult(
    success: true,
    suggestions: [compositionSuggestion],
    analysisTimestamp: DateTime.now(),
    confidence: 0.45,
  );

  // Camera Settings Test Data

  static Map<String, dynamic> get defaultSettings => {
    'iso': 400,
    'aperture': 4.0,
    'shutterSpeed': 1/60,
    'whiteBalance': 'auto',
    'focusDistance': 0.5,
    'flashEnabled': false,
    'zoomLevel': 1.0,
  };

  static Map<String, dynamic> get portraitSettings => {
    'iso': 200,
    'aperture': 2.8,
    'shutterSpeed': 1/125,
    'whiteBalance': 'daylight',
    'focusDistance': 0.3,
    'flashEnabled': false,
    'zoomLevel': 2.0,
  };

  static Map<String, dynamic> get landscapeSettings => {
    'iso': 100,
    'aperture': 8.0,
    'shutterSpeed': 1/250,
    'whiteBalance': 'daylight',
    'focusDistance': 1.0,
    'flashEnabled': false,
    'zoomLevel': 1.0,
  };

  static Map<String, dynamic> get nightSettings => {
    'iso': 1600,
    'aperture': 1.8,
    'shutterSpeed': 1/30,
    'whiteBalance': 'tungsten',
    'focusDistance': 0.5,
    'flashEnabled': true,
    'zoomLevel': 1.0,
  };

  static Map<String, dynamic> get sportsSettings => {
    'iso': 800,
    'aperture': 4.0,
    'shutterSpeed': 1/1000,
    'whiteBalance': 'auto',
    'focusDistance': 0.7,
    'flashEnabled': false,
    'zoomLevel': 3.0,
  };

  // Coordinator Configuration Test Data

  static AICoordinatorConfiguration get localFirstConfig => AICoordinatorConfiguration(
    selectionStrategy: ServiceSelectionStrategy.localFirst,
    enableCloudAI: true,
    allowFallbackToLocal: true,
    confidenceThreshold: 0.6,
    maxSuggestions: 8,
    cloudTimeout: Duration(seconds: 5),
  );

  static AICoordinatorConfiguration get cloudFirstConfig => AICoordinatorConfiguration(
    selectionStrategy: ServiceSelectionStrategy.cloudFirst,
    enableCloudAI: true,
    allowFallbackToLocal: true,
    confidenceThreshold: 0.7,
    maxSuggestions: 10,
    cloudTimeout: Duration(seconds: 8),
  );

  static AICoordinatorConfiguration get hybridConfig => AICoordinatorConfiguration(
    selectionStrategy: ServiceSelectionStrategy.hybrid,
    enableCloudAI: true,
    allowFallbackToLocal: true,
    confidenceThreshold: 0.5,
    maxSuggestions: 12,
    cloudTimeout: Duration(seconds: 6),
  );

  static AICoordinatorConfiguration get localOnlyConfig => AICoordinatorConfiguration(
    selectionStrategy: ServiceSelectionStrategy.localOnly,
    enableCloudAI: false,
    allowFallbackToLocal: false,
    confidenceThreshold: 0.6,
    maxSuggestions: 6,
    cloudTimeout: Duration(seconds: 1),
  );

  static AICoordinatorConfiguration get cloudOnlyConfig => AICoordinatorConfiguration(
    selectionStrategy: ServiceSelectionStrategy.cloudOnly,
    enableCloudAI: true,
    allowFallbackToLocal: false,
    confidenceThreshold: 0.8,
    maxSuggestions: 15,
    cloudTimeout: Duration(seconds: 10),
  );

  // User Request Test Data

  static List<String> get commonUserRequests => [
    'portrait photography',
    'landscape shot',
    'night photography',
    'macro close-up',
    'sports action',
    'street photography',
    'studio lighting',
    'golden hour',
    'black and white',
    'high contrast',
  ];

  static List<String> get complexUserRequests => [
    'cinematic portrait with shallow depth of field',
    'long exposure night cityscape',
    'high-speed sports photography with motion blur',
    'macro flower photography with natural lighting',
    'street photography with dramatic shadows',
  ];

  // Error Test Data

  static List<Exception> get commonExceptions => [
    Exception('Network connection failed'),
    Exception('Image processing error'),
    Exception('Camera not available'),
    Exception('Invalid parameters'),
    Exception('Service timeout'),
  ];

  // Performance Test Data

  static List<Uint8List> get performanceTestImages => [
    Uint8List.fromList(List.filled(1024, 128)), // 1KB
    Uint8List.fromList(List.filled(10240, 128)), // 10KB
    Uint8List.fromList(List.filled(102400, 128)), // 100KB
    Uint8List.fromList(List.filled(1048576, 128)), // 1MB
  ];

  static List<Map<String, dynamic>> get performanceTestScenarios => [
    {'name': 'Single suggestion', 'count': 1},
    {'name': 'Multiple suggestions', 'count': 5},
    {'name': 'Many suggestions', 'count': 10},
    {'name': 'Maximum suggestions', 'count': 20},
  ];

  // Validation Test Data

  static Map<String, dynamic> get validCameraSettings => {
    'iso': 800,
    'aperture': 2.8,
    'shutterSpeed': 1/125,
    'whiteBalance': 'daylight',
    'focusDistance': 0.3,
    'flashEnabled': true,
    'zoomLevel': 2.5,
  };

  static List<Map<String, dynamic>> get invalidCameraSettings => [
    {'iso': -100}, // Invalid ISO
    {'aperture': 0}, // Invalid aperture
    {'shutterSpeed': -1}, // Invalid shutter speed
    {'whiteBalance': 'invalid_mode'}, // Invalid white balance
    {'focusDistance': -0.5}, // Invalid focus distance
    {'zoomLevel': 0}, // Invalid zoom level
  ];

  // Edge Case Test Data

  static List<Uint8List> get edgeCaseImages => [
    Uint8List(0), // Empty image
    Uint8List.fromList([255]), // Single byte 
    Uint8List.fromList(List.filled(10000000, 0)), // Very large image
    Uint8List.fromList([137, 80, 78, 71]), // Incomplete PNG header
  ];

  static List<SceneAnalysis> get edgeCaseScenes => [
    SceneAnalysis(
      sceneType: '',
      lightingCondition: '',
      subjectDistance: '',
      movementDetected: false,
      brightness: 0.0,
      contrast: 0.0,
      colorTemperature: 0,
      dominantColors: [],
      faces: [],
      motion: 0.0,
      focusDistance: 0.0,
      exposureBias: 0.0,
    ),
    SceneAnalysis(
      sceneType: 'unknown',
      lightingCondition: 'extreme',
      subjectDistance: 'invalid',
      movementDetected: true,
      brightness: 2.0, // Out of range
      contrast: -1.0, // Out of range
      colorTemperature: -1000, // Invalid
      dominantColors: List.filled(100, 'color'), // Too many colors
      faces: List.filled(50, FaceDetection(x: 0, y: 0, width: 0, height: 0, confidence: 0)),
      motion: 5.0, // Out of range
      focusDistance: -1.0, // Invalid
      exposureBias: 10.0, // Extreme value
    ),
  ];
}

/// Face detection data for testing
class FaceDetection {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  const FaceDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });
}