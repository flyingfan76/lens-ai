import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:lens_ai/core/image/optimized_image_processor.dart';
import 'package:lens_ai/core/image/image_processing_pipeline.dart';
import 'package:lens_ai/core/utils/memory_manager.dart';
import 'package:lens_ai/core/utils/performance_monitor.dart';

void main() {
  group('OptimizedImageProcessor Tests', () {
    late OptimizedImageProcessor processor;
    late MemoryManager memoryManager;
    late PerformanceMonitor performanceMonitor;
    
    setUp(() {
      memoryManager = MemoryManager();
      performanceMonitor = PerformanceMonitor();
      processor = OptimizedImageProcessor(
        memoryManager: memoryManager,
        performanceMonitor: performanceMonitor,
      );
    });
    
    tearDown(() {
      processor.dispose();
    });
    
    test('should process small image efficiently', () async {
      final testImage = _generateTestImage(256, 256);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      final stopwatch = Stopwatch()..start();
      final result = await processor.analyzeImageOptimized(imageBytes);
      stopwatch.stop();
      
      expect(result, isNotNull);
      expect(result.brightness, isA<double>());
      expect(result.contrast, isA<double>());
      expect(result.colorTemperature, isA<double>());
      expect(result.processingTime, lessThan(2000)); // Should be under 2 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      
      debugPrint('Small image processing time: ${stopwatch.elapsedMilliseconds}ms');
    });
    
    test('should handle large images with progressive processing', () async {
      final testImage = _generateTestImage(2048, 2048);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      final stopwatch = Stopwatch()..start();
      final result = await processor.analyzeImageOptimized(
        imageBytes,
        useProgressiveProcessing: true,
      );
      stopwatch.stop();
      
      expect(result, isNotNull);
      expect(result.processingTime, lessThan(5000)); // Should be under 5 seconds
      expect(result.samplingRate, greaterThan(5)); // Should use higher sampling for large images
      
      debugPrint('Large image processing time: ${stopwatch.elapsedMilliseconds}ms');
    });
    
    test('should use caching effectively', () async {
      final testImage = _generateTestImage(512, 512);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      // First processing
      final stopwatch1 = Stopwatch()..start();
      final result1 = await processor.analyzeImageOptimized(imageBytes);
      stopwatch1.stop();
      
      // Second processing (should use cache)
      final stopwatch2 = Stopwatch()..start();
      final result2 = await processor.analyzeImageOptimized(imageBytes);
      stopwatch2.stop();
      
      expect(result1.brightness, closeTo(result2.brightness, 0.01));
      expect(stopwatch2.elapsedMilliseconds, lessThan(stopwatch1.elapsedMilliseconds));
      
      debugPrint('First processing: ${stopwatch1.elapsedMilliseconds}ms');
      debugPrint('Cached processing: ${stopwatch2.elapsedMilliseconds}ms');
      debugPrint('Cache speedup: ${(stopwatch1.elapsedMilliseconds / stopwatch2.elapsedMilliseconds).toStringAsFixed(2)}x');
    });
    
    test('should optimize memory usage', () async {
      final testImages = List.generate(5, (i) => _generateTestImage(1024, 1024));
      final imageBytesList = testImages.map((image) => Uint8List.fromList(img.encodePng(image))).toList();
      
      final initialMemory = memoryManager.getMemoryStats().currentUsage;
      
      for (final imageBytes in imageBytesList) {
        await processor.analyzeImageOptimized(imageBytes);
      }
      
      final finalMemory = memoryManager.getMemoryStats().currentUsage;
      final memoryIncrease = finalMemory - initialMemory;
      
      // Memory increase should be reasonable (less than 50MB)
      expect(memoryIncrease, lessThan(50 * 1024 * 1024));
      
      debugPrint('Memory increase: ${(memoryIncrease / 1024 / 1024).toStringAsFixed(1)}MB');
      debugPrint('Memory stats: ${memoryManager.getMemoryStats()}');
    });
    
    test('should produce consistent results', () async {
      final testImage = _generateTestImage(512, 512);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      final results = <SceneAnalysisOptimized>[];
      for (int i = 0; i < 3; i++) {
        results.add(await processor.analyzeImageOptimized(imageBytes, useCache: false));
      }
      
      // Results should be consistent across runs
      for (int i = 1; i < results.length; i++) {
        expect(results[i].brightness, closeTo(results[0].brightness, 0.05));
        expect(results[i].contrast, closeTo(results[0].contrast, 0.05));
        expect(results[i].colorTemperature, closeTo(results[0].colorTemperature, 100));
      }
    });
  });
  
  group('ImageProcessingPipeline Tests', () {
    late ImageProcessingPipeline pipeline;
    
    setUp(() async {
      pipeline = ImageProcessingPipeline();
      await pipeline.initialize();
    });
    
    tearDown(() {
      pipeline.dispose();
    });
    
    test('should process batch efficiently', () async {
      final testImages = List.generate(8, (i) => _generateTestImage(256, 256));
      final imageBytesList = testImages.map((image) => Uint8List.fromList(img.encodePng(image))).toList();
      
      final stopwatch = Stopwatch()..start();
      final results = await pipeline.processBatch(imageBytesList);
      stopwatch.stop();
      
      expect(results.length, equals(8));
      expect(stopwatch.elapsedMilliseconds, lessThan(8000)); // Should be faster than sequential
      
      final avgTimePerImage = stopwatch.elapsedMilliseconds / 8;
      debugPrint('Batch processing - Total: ${stopwatch.elapsedMilliseconds}ms, Avg per image: ${avgTimePerImage.toStringAsFixed(1)}ms');
    });
    
    test('should handle concurrent processing', () async {
      final testImage = _generateTestImage(512, 512);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      final stopwatch = Stopwatch()..start();
      final futures = List.generate(4, (i) => pipeline.processImage(imageBytes));
      final results = await Future.wait(futures);
      stopwatch.stop();
      
      expect(results.length, equals(4));
      expect(results.every((r) => r != null), isTrue);
      
      debugPrint('Concurrent processing time: ${stopwatch.elapsedMilliseconds}ms');
    });
    
    test('should provide pipeline metrics', () {
      final metrics = pipeline.getMetrics();
      
      expect(metrics.totalWorkers, greaterThan(0));
      expect(metrics.activeTasks, greaterThanOrEqualTo(0));
      expect(metrics.queuedTasks, greaterThanOrEqualTo(0));
      expect(metrics.memoryStats, isNotNull);
      
      debugPrint('Pipeline metrics: $metrics');
    });
  });
  
  group('Performance Benchmarks', () {
    test('should demonstrate performance improvements', () async {
      final processor = OptimizedImageProcessor();
      final testImage = _generateTestImage(1024, 1024);
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      // Warmup
      await processor.analyzeImageOptimized(imageBytes);
      
      // Benchmark multiple runs
      final times = <int>[];
      for (int i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await processor.analyzeImageOptimized(imageBytes, useCache: false);
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
      }
      
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final minTime = times.reduce(math.min);
      final maxTime = times.reduce(math.max);
      
      debugPrint('Performance benchmark (1024x1024 image):');
      debugPrint('  Average time: ${avgTime.toStringAsFixed(1)}ms');
      debugPrint('  Min time: ${minTime}ms');
      debugPrint('  Max time: ${maxTime}ms');
      debugPrint('  Standard deviation: ${_calculateStdDev(times, avgTime).toStringAsFixed(1)}ms');
      
      // Performance target: should be under 3 seconds on average
      expect(avgTime, lessThan(3000));
      
      processor.dispose();
    });
    
    test('should show memory efficiency', () async {
      final memoryManager = MemoryManager();
      final processor = OptimizedImageProcessor(memoryManager: memoryManager);
      
      final testImages = List.generate(10, (i) => _generateTestImage(512, 512));
      final imageBytesList = testImages.map((image) => Uint8List.fromList(img.encodePng(image))).toList();
      
      final initialStats = memoryManager.getMemoryStats();
      
      for (final imageBytes in imageBytesList) {
        await processor.analyzeImageOptimized(imageBytes);
      }
      
      final finalStats = memoryManager.getMemoryStats();
      
      debugPrint('Memory efficiency test:');
      debugPrint('  Initial usage: ${(initialStats.currentUsage / 1024 / 1024).toStringAsFixed(1)}MB');
      debugPrint('  Final usage: ${(finalStats.currentUsage / 1024 / 1024).toStringAsFixed(1)}MB');
      debugPrint('  Buffer reuse ratio: ${(finalStats.reuseRatio * 100).toStringAsFixed(1)}%');
      debugPrint('  Memory efficiency: ${(finalStats.memoryEfficiency * 100).toStringAsFixed(1)}%');
      
      // Memory should be well-managed
      expect(finalStats.reuseRatio, greaterThan(0.3)); // At least 30% reuse
      expect(finalStats.currentUsage, lessThan(100 * 1024 * 1024)); // Under 100MB
      
      processor.dispose();
    });
  });
}

// Helper functions

img.Image _generateTestImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Create a test pattern with various colors and gradients
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final r = ((x / width) * 255).toInt();
      final g = ((y / height) * 255).toInt();
      final b = (((x + y) / (width + height)) * 255).toInt();
      
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }
  
  return image;
}

double _calculateStdDev(List<int> values, double mean) {
  final variance = values
      .map((v) => math.pow(v - mean, 2))
      .reduce((a, b) => a + b) / values.length;
  return math.sqrt(variance);
}