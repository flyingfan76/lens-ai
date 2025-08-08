import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../models/ai_suggestion.dart';
import '../utils/memory_manager.dart';
import '../utils/performance_monitor.dart';

/// High-performance image processor with optimized algorithms and memory management
class OptimizedImageProcessor {
  static const int _maxImageSize = 50 * 1024 * 1024; // 50MB
  static const int _optimalProcessingSize = 1024; // 1024px for processing
  static const int _minSampleRate = 2;
  static const int _maxSampleRate = 20;
  
  final MemoryManager _memoryManager;
  final PerformanceMonitor _performanceMonitor;
  
  // Cache for processed data
  final Map<String, CachedImageAnalysis> _analysisCache = {};
  final int _maxCacheSize = 10;
  
  OptimizedImageProcessor({
    MemoryManager? memoryManager,
    PerformanceMonitor? performanceMonitor,
  }) : _memoryManager = memoryManager ?? MemoryManager(),
        _performanceMonitor = performanceMonitor ?? PerformanceMonitor();

  /// Optimized image analysis with parallel processing and memory management
  Future<SceneAnalysisOptimized> analyzeImageOptimized(
    Uint8List imageBytes, {
    bool useCache = true,
    bool useProgressiveProcessing = true,
    int? targetSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Input validation
      if (imageBytes.isEmpty) {
        throw ArgumentError('Empty image data');
      }
      
      if (imageBytes.length > _maxImageSize) {
        throw ArgumentError('Image too large: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB');
      }
      
      // Check cache first
      final cacheKey = _generateCacheKey(imageBytes);
      if (useCache && _analysisCache.containsKey(cacheKey)) {
        final cached = _analysisCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp).inMinutes < 5) {
          _performanceMonitor.recordCacheHit('image_analysis');
          return cached.analysis;
        }
      }
      
      // Memory check before processing
      await _memoryManager.ensureMemoryAvailable(imageBytes.length * 2);
      
      // Decode and prepare image
      final image = await _decodeImageOptimized(imageBytes);
      if (image == null) {
        throw ArgumentError('Failed to decode image');
      }
      
      // Optimize image size for processing
      final processedImage = await _prepareImageForProcessing(
        image, 
        targetSize ?? _optimalProcessingSize,
        useProgressiveProcessing,
      );
      
      // Parallel analysis
      final analysisResults = await _runParallelAnalysis(processedImage);
      
      // Create optimized scene analysis
      final sceneAnalysis = SceneAnalysisOptimized(
        sceneType: analysisResults['sceneType'] as String,
        lightingCondition: analysisResults['lightingCondition'] as String,
        subjectDistance: analysisResults['subjectDistance'] as String,
        movementDetected: analysisResults['movementDetected'] as bool,
        brightness: analysisResults['brightness'] as double,
        contrast: analysisResults['contrast'] as double,
        colorTemperature: analysisResults['colorTemperature'] as double,
        dominantColors: analysisResults['dominantColors'] as List<String>,
        faces: analysisResults['faces'] as List<Map<String, dynamic>>,
        motion: analysisResults['motion'] as double,
        focusDistance: analysisResults['focusDistance'] as double,
        exposureBias: analysisResults['exposureBias'] as double,
        // Optimization metrics
        processingTime: stopwatch.elapsedMilliseconds,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        samplingRate: analysisResults['samplingRate'] as int,
        memoryUsed: analysisResults['memoryUsed'] as int,
      );
      
      // Cache the result
      if (useCache) {
        _cacheAnalysis(cacheKey, sceneAnalysis);
      }
      
      // Record performance metrics
      _performanceMonitor.recordImageProcessing(
        processingTime: stopwatch.elapsedMilliseconds,
        imageSize: imageBytes.length,
        resultQuality: sceneAnalysis.confidence,
      );
      
      // Cleanup
      await _memoryManager.releaseTempMemory();
      
      return sceneAnalysis;
      
    } catch (e) {
      _performanceMonitor.recordError('image_analysis', e.toString());
      debugPrint('OptimizedImageProcessor: Error analyzing image: $e');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Decode image with optimization for different formats
  Future<img.Image?> _decodeImageOptimized(Uint8List imageBytes) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Try to determine format first to optimize decoding
      final format = _detectImageFormat(imageBytes);
      
      img.Image? image;
      switch (format) {
        case ImageFormat.jpeg:
          image = img.decodeJpg(imageBytes);
          break;
        case ImageFormat.png:
          image = img.decodePng(imageBytes);
          break;
        case ImageFormat.webp:
          image = img.decodeWebP(imageBytes);
          break;
        default:
          // Fallback to generic decoder
          image = img.decodeImage(imageBytes);
      }
      
      _performanceMonitor.recordImageDecoding(
        format: format.name,
        time: stopwatch.elapsedMilliseconds,
        size: imageBytes.length,
      );
      
      return image;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Prepare image for processing with size optimization
  Future<img.Image> _prepareImageForProcessing(
    img.Image image, 
    int targetSize,
    bool useProgressiveProcessing,
  ) async {
    final originalSize = math.max(image.width, image.height);
    
    // Skip resizing if image is already optimal size
    if (originalSize <= targetSize) {
      return image;
    }
    
    if (useProgressiveProcessing && originalSize > targetSize * 2) {
      // Progressive downsampling for large images
      return await _progressiveResize(image, targetSize);
    } else {
      // Direct resize
      final scale = targetSize / originalSize;
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();
      
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear, // Faster than cubic
      );
    }
  }
  
  /// Progressive resize for large images to prevent memory spikes
  Future<img.Image> _progressiveResize(img.Image image, int targetSize) async {
    img.Image current = image;
    final originalSize = math.max(image.width, image.height);
    
    // Resize in steps, halving each time until we reach target
    while (math.max(current.width, current.height) > targetSize * 1.5) {
      final newWidth = (current.width * 0.7).round();
      final newHeight = (current.height * 0.7).round();
      
      current = img.copyResize(
        current,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // Allow other operations to run
      await Future.delayed(const Duration(microseconds: 100));
    }
    
    // Final resize to exact target
    final scale = targetSize / math.max(current.width, current.height);
    final finalWidth = (current.width * scale).round();
    final finalHeight = (current.height * scale).round();
    
    return img.copyResize(
      current,
      width: finalWidth,
      height: finalHeight,
      interpolation: img.Interpolation.linear,
    );
  }
  
  /// Run parallel analysis using isolates for CPU-intensive operations
  Future<Map<String, dynamic>> _runParallelAnalysis(img.Image image) async {
    // Determine optimal sampling rate based on image size
    final imagePixels = image.width * image.height;
    final samplingRate = _calculateOptimalSamplingRate(imagePixels);
    
    // Create optimized pixel data for parallel processing
    final pixelData = _extractOptimizedPixelData(image, samplingRate);
    
    // Run parallel computations
    final futures = <Future<Map<String, dynamic>>>[
      _computeBrightnessAndContrast(pixelData),
      _computeColorAnalysis(pixelData),
      _computeSceneDetection(pixelData, image.width, image.height),
      _computeAdvancedFeatures(image, samplingRate),
    ];
    
    final results = await Future.wait(futures);
    
    // Combine results
    final combinedResults = <String, dynamic>{
      'samplingRate': samplingRate,
      'memoryUsed': pixelData.length * 4, // Approximate memory usage
    };
    
    for (final result in results) {
      combinedResults.addAll(result);
    }
    
    return combinedResults;
  }
  
  /// Extract optimized pixel data with intelligent sampling
  OptimizedPixelData _extractOptimizedPixelData(img.Image image, int samplingRate) {
    final width = image.width;
    final height = image.height;
    final pixelCount = (width * height / (samplingRate * samplingRate)).ceil();
    
    final redValues = Uint8List(pixelCount);
    final greenValues = Uint8List(pixelCount);
    final blueValues = Uint8List(pixelCount);
    final positions = <Point<int>>[];
    
    int index = 0;
    for (int y = 0; y < height; y += samplingRate) {
      for (int x = 0; x < width; x += samplingRate) {
        if (index < pixelCount) {
          final pixel = image.getPixel(x, y);
          redValues[index] = pixel.r.toInt();
          greenValues[index] = pixel.g.toInt();
          blueValues[index] = pixel.b.toInt();
          positions.add(Point(x, y));
          index++;
        }
      }
    }
    
    return OptimizedPixelData(
      red: redValues,
      green: greenValues,
      blue: blueValues,
      positions: positions,
      width: width,
      height: height,
      samplingRate: samplingRate,
    );
  }
  
  /// Compute brightness and contrast in parallel
  Future<Map<String, dynamic>> _computeBrightnessAndContrast(OptimizedPixelData pixelData) async {
    return await compute(_computeBrightnessContrastIsolate, pixelData);
  }
  
  /// Compute color analysis in parallel
  Future<Map<String, dynamic>> _computeColorAnalysis(OptimizedPixelData pixelData) async {
    return await compute(_computeColorAnalysisIsolate, pixelData);
  }
  
  /// Compute scene detection in parallel
  Future<Map<String, dynamic>> _computeSceneDetection(
    OptimizedPixelData pixelData, 
    int imageWidth, 
    int imageHeight,
  ) async {
    final sceneData = SceneDetectionData(
      pixelData: pixelData,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    return await compute(_computeSceneDetectionIsolate, sceneData);
  }
  
  /// Compute advanced features (faces, motion, etc.)
  Future<Map<String, dynamic>> _computeAdvancedFeatures(img.Image image, int samplingRate) async {
    // These could be implemented with more sophisticated algorithms
    // For now, return basic implementations
    return {
      'faces': <Map<String, dynamic>>[],
      'motion': 0.0,
      'focusDistance': 0.5,
      'movementDetected': false,
    };
  }
  
  /// Calculate optimal sampling rate based on image size and device capabilities
  int _calculateOptimalSamplingRate(int pixelCount) {
    // Adaptive sampling based on image size and available memory
    if (pixelCount > 8000000) return _maxSampleRate; // 8MP+
    if (pixelCount > 2000000) return 15; // 2-8MP
    if (pixelCount > 500000) return 10; // 0.5-2MP
    if (pixelCount > 100000) return 5; // 0.1-0.5MP
    return _minSampleRate; // < 0.1MP
  }
  
  /// Generate cache key for image
  String _generateCacheKey(Uint8List imageBytes) {
    // Use a simple hash of first and last bytes plus length
    final start = imageBytes.take(16).toList();
    final end = imageBytes.skip(math.max(0, imageBytes.length - 16)).toList();
    return '${start.join()}_${end.join()}_${imageBytes.length}';
  }
  
  /// Cache analysis result
  void _cacheAnalysis(String key, SceneAnalysisOptimized analysis) {
    if (_analysisCache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestKey = _analysisCache.keys.first;
      _analysisCache.remove(oldestKey);
    }
    
    _analysisCache[key] = CachedImageAnalysis(
      analysis: analysis,
      timestamp: DateTime.now(),
    );
  }
  
  /// Detect image format for optimized decoding
  ImageFormat _detectImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return ImageFormat.unknown;
    
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return ImageFormat.jpeg;
    }
    
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return ImageFormat.png;
    }
    
    // WebP: "RIFF" ... "WEBP"
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return ImageFormat.webp;
    }
    
    return ImageFormat.unknown;
  }
  
  /// Dispose and cleanup
  void dispose() {
    _analysisCache.clear();
    _memoryManager.dispose();
    _performanceMonitor.dispose();
  }
}

// Isolate functions for parallel processing

/// Compute brightness and contrast in isolate
Map<String, dynamic> _computeBrightnessContrastIsolate(OptimizedPixelData pixelData) {
  double totalBrightness = 0;
  final pixelCount = pixelData.red.length;
  
  // Calculate brightness using vectorized operations
  for (int i = 0; i < pixelCount; i++) {
    final brightness = 0.299 * pixelData.red[i] + 0.587 * pixelData.green[i] + 0.114 * pixelData.blue[i];
    totalBrightness += brightness;
  }
  
  final avgBrightness = totalBrightness / pixelCount / 255.0;
  
  // Calculate contrast (variance)
  double variance = 0.0;
  for (int i = 0; i < pixelCount; i++) {
    final pixelBrightness = (0.299 * pixelData.red[i] + 0.587 * pixelData.green[i] + 0.114 * pixelData.blue[i]) / 255.0;
    final diff = pixelBrightness - avgBrightness;
    variance += diff * diff;
  }
  
  final contrast = variance / pixelCount;
  final exposureBias = _calculateExposureBias(avgBrightness, contrast);
  
  return {
    'brightness': avgBrightness,
    'contrast': contrast,
    'exposureBias': exposureBias,
  };
}

/// Compute color analysis in isolate
Map<String, dynamic> _computeColorAnalysisIsolate(OptimizedPixelData pixelData) {
  double redSum = 0, greenSum = 0, blueSum = 0;
  final colorCounts = <String, int>{};
  final pixelCount = pixelData.red.length;
  
  // Vectorized color analysis
  for (int i = 0; i < pixelCount; i++) {
    final r = pixelData.red[i];
    final g = pixelData.green[i];
    final b = pixelData.blue[i];
    
    redSum += r;
    greenSum += g;
    blueSum += b;
    
    // Color family classification
    final colorFamily = _getColorFamily(r, g, b);
    colorCounts[colorFamily] = (colorCounts[colorFamily] ?? 0) + 1;
  }
  
  // Color temperature estimation
  final redAvg = redSum / pixelCount;
  final blueAvg = blueSum / pixelCount;
  final ratio = redAvg / blueAvg;
  
  double colorTemperature;
  if (ratio > 1.3) {
    colorTemperature = 2800;
  } else if (ratio > 1.2) {
    colorTemperature = 3200;
  } else if (ratio > 1.0) {
    colorTemperature = 4000;
  } else if (ratio > 0.9) {
    colorTemperature = 5500;
  } else if (ratio > 0.8) {
    colorTemperature = 6500;
  } else {
    colorTemperature = 7500;
  }
  
  // Dominant colors
  final sortedColors = colorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominantColors = sortedColors.take(3).map((e) => e.key).toList();
  
  return {
    'colorTemperature': colorTemperature,
    'dominantColors': dominantColors,
  };
}

/// Compute scene detection in isolate
Map<String, dynamic> _computeSceneDetectionIsolate(SceneDetectionData sceneData) {
  final pixelData = sceneData.pixelData;
  final width = sceneData.imageWidth;
  final height = sceneData.imageHeight;
  
  // Scene type detection based on color distribution and spatial analysis
  final colorCounts = <String, int>{};
  double centerBrightness = 0;
  double edgeBrightness = 0;
  int centerCount = 0;
  int edgeCount = 0;
  
  final centerX = width ~/ 2;
  final centerY = height ~/ 2;
  final centerThreshold = math.min(width, height) ~/ 4;
  
  for (int i = 0; i < pixelData.positions.length; i++) {
    final pos = pixelData.positions[i];
    final r = pixelData.red[i];
    final g = pixelData.green[i];
    final b = pixelData.blue[i];
    
    final brightness = (r + g + b) / 3.0;
    final colorFamily = _getColorFamily(r, g, b);
    colorCounts[colorFamily] = (colorCounts[colorFamily] ?? 0) + 1;
    
    // Center vs edge analysis for subject distance
    final distanceFromCenter = math.sqrt(
      math.pow(pos.x - centerX, 2) + math.pow(pos.y - centerY, 2)
    );
    
    if (distanceFromCenter < centerThreshold) {
      centerBrightness += brightness;
      centerCount++;
    } else {
      edgeBrightness += brightness;
      edgeCount++;
    }
  }
  
  // Scene type classification
  String sceneType = 'general';
  if (colorCounts.containsKey('green') && colorCounts.containsKey('blue')) {
    if ((colorCounts['green'] ?? 0) > pixelData.red.length * 0.3) {
      sceneType = 'landscape';
    }
  } else if (colorCounts.containsKey('white') || colorCounts.containsKey('neutral')) {
    sceneType = 'portrait';
  }
  
  // Subject distance estimation
  final centerAvg = centerCount > 0 ? centerBrightness / centerCount : 128;
  final edgeAvg = edgeCount > 0 ? edgeBrightness / edgeCount : 128;
  final brightnessDiff = (centerAvg - edgeAvg).abs();
  
  String subjectDistance;
  if (brightnessDiff > 75) {
    subjectDistance = 'close';
  } else if (brightnessDiff > 25) {
    subjectDistance = 'medium';
  } else {
    subjectDistance = 'far';
  }
  
  // Lighting condition
  final avgBrightness = (centerBrightness + edgeBrightness) / (centerCount + edgeCount) / 255.0;
  String lightingCondition;
  if (avgBrightness < 0.2) {
    lightingCondition = 'very_low';
  } else if (avgBrightness < 0.4) {
    lightingCondition = 'low';
  } else if (avgBrightness < 0.6) {
    lightingCondition = 'normal';
  } else if (avgBrightness < 0.8) {
    lightingCondition = 'bright';
  } else {
    lightingCondition = 'very_bright';
  }
  
  return {
    'sceneType': sceneType,
    'subjectDistance': subjectDistance,
    'lightingCondition': lightingCondition,
  };
}

/// Helper function for color family classification
String _getColorFamily(int r, int g, int b) {
  if (r > 220 && g > 220 && b > 220) return 'white';
  if (r < 30 && g < 30 && b < 30) return 'black';
  if (r > g + 20 && r > b + 20) return 'red';
  if (g > r + 20 && g > b + 20) return 'green';
  if (b > r + 20 && b > g + 20) return 'blue';
  if (r > 180 && g > 180 && b < 100) return 'yellow';
  if (r > 180 && b > 180 && g < 100) return 'magenta';
  if (g > 180 && b > 180 && r < 100) return 'cyan';
  if ((r + g + b) / 3 < 80) return 'dark';
  return 'neutral';
}

/// Helper function for exposure bias calculation
double _calculateExposureBias(double brightness, double contrast) {
  if (brightness < 0.3) return 0.7;
  if (brightness > 0.8) return -0.3;
  if (contrast > 0.4) return -0.3;
  return 0.0;
}

// Data classes for optimized processing

class OptimizedPixelData {
  final Uint8List red;
  final Uint8List green;
  final Uint8List blue;
  final List<Point<int>> positions;
  final int width;
  final int height;
  final int samplingRate;
  
  OptimizedPixelData({
    required this.red,
    required this.green,
    required this.blue,
    required this.positions,
    required this.width,
    required this.height,
    required this.samplingRate,
  });
}

class SceneDetectionData {
  final OptimizedPixelData pixelData;
  final int imageWidth;
  final int imageHeight;
  
  SceneDetectionData({
    required this.pixelData,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class CachedImageAnalysis {
  final SceneAnalysisOptimized analysis;
  final DateTime timestamp;
  
  CachedImageAnalysis({
    required this.analysis,
    required this.timestamp,
  });
}

class SceneAnalysisOptimized extends SceneAnalysis {
  final int processingTime;
  final Size imageSize;
  final int samplingRate;
  final int memoryUsed;
  
  SceneAnalysisOptimized({
    required super.sceneType,
    required super.lightingCondition,
    required super.subjectDistance,
    required super.movementDetected,
    required super.brightness,
    required super.contrast,
    required super.colorTemperature,
    required super.dominantColors,
    required super.faces,
    required super.motion,
    required super.focusDistance,
    required super.exposureBias,
    required this.processingTime,
    required this.imageSize,
    required this.samplingRate,
    required this.memoryUsed,
  });
  
  double get confidence {
    // Calculate confidence based on processing quality
    final sizeScore = math.min(1.0, imageSize.width * imageSize.height / 1000000); // Up to 1MP
    final timeScore = math.max(0.3, 1.0 - (processingTime / 5000)); // Penalty after 5s
    final samplingScore = math.min(1.0, samplingRate / 10.0); // Better with more samples
    
    return (sizeScore + timeScore + samplingScore) / 3.0;
  }
}

enum ImageFormat {
  jpeg,
  png,
  webp,
  unknown,
}

class Point<T extends num> {
  final T x;
  final T y;
  
  Point(this.x, this.y);
}

class Size {
  final double width;
  final double height;
  
  Size(this.width, this.height);
}

extension OptimizedImageProcessorMethods on OptimizedImageProcessor {
  /// Initialize the image processor
  Future<void> initialize() async {
    // Initialize performance monitoring and memory management
    // Implementation can be empty for now as the constructor handles initialization
  }

  /// Resize image to specified dimensions
  Future<Uint8List> resizeImage(Uint8List imageBytes, int width, int height) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Failed to decode image');
    }

    final resized = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Compress image with specified quality
  Future<Uint8List> compressImage(Uint8List imageBytes, {int quality = 85}) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Failed to decode image');
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}