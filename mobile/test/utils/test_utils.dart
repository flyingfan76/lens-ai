import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lens_ai/models/ai_suggestion.dart';
import 'package:lens_ai/core/providers/camera_state_provider.dart';
import 'package:lens_ai/core/providers/camera_settings_provider.dart';
import 'package:lens_ai/core/state/app_state_provider.dart';
import 'package:lens_ai/services/ai/ai_coordinator.dart';

/// Comprehensive test utilities for Lens AI testing
class TestUtils {
  
  // Test data generators
  
  /// Generate a simple test image (1x1 PNG)
  static Uint8List generateTestImage() {
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, // PNG header
      0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
      0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0, 3, 0, 1, 124, 181, 223, 203,
      0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);
  }

  /// Generate a larger test image for performance tests
  static Uint8List generateLargeTestImage(int width, int height) {
    final random = Random();
    final pixels = width * height * 4; // RGBA
    final data = Uint8List(pixels);
    
    for (int i = 0; i < pixels; i++) {
      data[i] = random.nextInt(256);
    }
    
    return data;
  }

  /// Create test scene analysis with configurable parameters
  static SceneAnalysis createTestSceneAnalysis({
    String sceneType = 'portrait',
    String lightingCondition = 'normal',
    double brightness = 0.5,
    double contrast = 0.5,
    double colorTemperature = 5500,
    bool movementDetected = false,
  }) {
    return SceneAnalysis(
      sceneType: sceneType,
      lightingCondition: lightingCondition,
      subjectDistance: 'medium',
      movementDetected: movementDetected,
      brightness: brightness,
      contrast: contrast,
      colorTemperature: colorTemperature,
      dominantColors: ['blue', 'red'],
      faces: [],
      motion: movementDetected ? 0.5 : 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }

  /// Create test AI suggestions
  static List<AISuggestion> createTestSuggestions({int count = 3}) {
    return List.generate(count, (index) => AISuggestion(
      id: 'test_suggestion_$index',
      type: AISuggestionType.cameraSettings,
      category: AISuggestionCategory.iso,
      title: 'Test Suggestion $index',
      message: 'This is test suggestion number $index',
      icon: 'settings',
      priority: (count - index).toDouble(),
      confidence: 0.8 + (index * 0.05),
      actionable: true,
      action: () {},
      visual: null,
      explanation: 'Test explanation for suggestion $index',
    ));
  }

  /// Create test AI analysis result
  static AIAnalysisResult createTestAnalysisResult({
    bool success = true,
    int suggestionCount = 3,
    double confidence = 0.85,
  }) {
    return AIAnalysisResult(
      success: success,
      suggestions: success ? createTestSuggestions(count: suggestionCount) : [],
      analysisTimestamp: DateTime.now(),
      confidence: confidence,
    );
  }

  // Widget testing utilities

  /// Create a test app with providers for widget testing
  static Widget createTestApp({
    required Widget child,
    ChangeNotifier? cameraProvider,
    CameraStateProvider? cameraStateProvider,
    CameraSettingsProvider? cameraSettingsProvider,
    AppStateProvider? appStateProvider,
  }) {
    return MultiProvider(
      providers: [
        if (cameraProvider != null) 
          ChangeNotifierProvider.value(value: cameraProvider),
        if (cameraStateProvider != null)
          ChangeNotifierProvider<CameraStateProvider>.value(value: cameraStateProvider),
        if (cameraSettingsProvider != null)
          ChangeNotifierProvider<CameraSettingsProvider>.value(value: cameraSettingsProvider),
        if (appStateProvider != null)
          ChangeNotifierProvider<AppStateProvider>.value(value: appStateProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  /// Pump widget and settle for consistent test timing
  static Future<void> pumpAndSettle(
    WidgetTester tester, 
    Widget widget, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle(timeout);
  }

  /// Find widgets by type with error handling
  static Finder findSafelyByType<T extends Widget>() {
    return find.byType(T);
  }

  /// Find widgets by key with error handling
  static Finder findSafelyByKey(Key key) {
    return find.byKey(key);
  }

  /// Wait for a condition with timeout
  static Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      if (condition()) return;
      await tester.pump(interval);
    }
    
    throw TimeoutException('Condition not met within timeout', timeout);
  }

  // Performance testing utilities

  /// Measure execution time of an async operation
  static Future<Duration> measureExecutionTime(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Measure memory usage (simplified)
  static int measureMemoryUsage() {
    // This is a simplified implementation
    // In real testing, you might use more sophisticated memory profiling
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }

  /// Run performance benchmark
  static Future<PerformanceResult> runPerformanceBenchmark(
    String name,
    Future<void> Function() operation, {
    int iterations = 10,
  }) async {
    final durations = <Duration>[];
    
    for (int i = 0; i < iterations; i++) {
      final duration = await measureExecutionTime(operation);
      durations.add(duration);
    }
    
    final totalMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    final averageMs = totalMs / iterations;
    final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
    final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
    
    return PerformanceResult(
      name: name,
      iterations: iterations,
      averageMs: averageMs,
      minMs: minMs,
      maxMs: maxMs,
      durations: durations,
    );
  }

  // Error testing utilities

  /// Create test exceptions
  static Exception createTestException(String message) {
    return Exception('Test Exception: $message');
  }

  /// Verify error handling
  static Future<void> verifyErrorHandling(
    Future<void> Function() operation,
    Type expectedException,
  ) async {
    try {
      await operation();
      fail('Expected $expectedException to be thrown');
    } catch (e) {
      expect(e, isA<Type>());
      expect(e.runtimeType, equals(expectedException));
    }
  }

  // Mock data generators

  /// Generate random camera settings
  static Map<String, dynamic> generateRandomCameraSettings() {
    final random = Random();
    return {
      'iso': 100 + random.nextInt(3100),
      'aperture': 1.4 + random.nextDouble() * 10,
      'shutterSpeed': 1.0 / (1 + random.nextInt(4000)),
      'whiteBalance': ['auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent'][random.nextInt(5)],
      'focusDistance': random.nextDouble(),
      'flashEnabled': random.nextBool(),
      'zoomLevel': 1.0 + random.nextDouble() * 9,
    };
  }

  /// Generate test user requests
  static List<String> generateTestUserRequests() {
    return [
      'portrait photography',
      'landscape shot',
      'night photography',
      'macro photography',
      'sports action',
      'street photography',
      'studio lighting',
      'golden hour',
      'black and white',
      'high contrast',
    ];
  }

  // Cleanup utilities

  /// Clean up after tests
  static Future<void> cleanup() async {
    // Reset singletons
    AICoordinator.resetSingleton();
    
    // Clear any cached data
    // Add other cleanup as needed
  }

  /// Dispose of providers safely
  static void disposeProviders(List<ChangeNotifier> providers) {
    for (final provider in providers) {
      try {
        provider.dispose();
      } catch (e) {
        debugPrint('Error disposing provider: $e');
      }
    }
  }
}

/// Performance test result
class PerformanceResult {
  final String name;
  final int iterations;
  final double averageMs;
  final int minMs;
  final int maxMs;
  final List<Duration> durations;

  const PerformanceResult({
    required this.name,
    required this.iterations,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.durations,
  });

  @override
  String toString() {
    return 'PerformanceResult($name): avg=${averageMs.toStringAsFixed(2)}ms, '
           'min=${minMs}ms, max=${maxMs}ms, iterations=$iterations';
  }
}

/// Custom timeout exception
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}