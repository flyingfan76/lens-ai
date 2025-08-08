import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../utils/memory_manager.dart';
import '../utils/performance_monitor.dart';
import '../image/platform_optimizations.dart';

/// High-performance AI preprocessing system optimized for mobile inference
class OptimizedAIPreprocessor {
  static const int _defaultModelInputSize = 224;
  // Normalization constants available for future model-specific preprocessing
  
  final MemoryManager _memoryManager;
  final PerformanceMonitor _performanceMonitor;
  final PlatformOptimizer _platformOptimizer;
  
  // Preprocessing cache
  final Map<String, PreprocessedData> _preprocessCache = {};
  final int _maxCacheSize = 20;
  
  // Tensor pools for reuse
  final Map<String, List<Float32List>> _tensorPools = {};
  
  // Batch processing optimization
  final List<PreprocessingTask> _batchQueue = [];
  Timer? _batchProcessor;
  
  OptimizedAIPreprocessor({
    MemoryManager? memoryManager,
    PerformanceMonitor? performanceMonitor,
    PlatformOptimizer? platformOptimizer,
  }) : _memoryManager = memoryManager ?? MemoryManager(),
        _performanceMonitor = performanceMonitor ?? PerformanceMonitor(),
        _platformOptimizer = platformOptimizer ?? PlatformOptimizer() {
    _initializeBatchProcessor();
  }
  
  /// Initialize the preprocessor
  Future<void> initialize() async {
    await _platformOptimizer.initialize();
    _warmupTensorPools();
    debugPrint('OptimizedAIPreprocessor: Initialized');
  }
  
  /// Preprocess image for AI model inference with optimal performance
  Future<ModelInput> preprocessForInference(
    Uint8List imageBytes, {
    int? modelInputSize,
    ModelFormat format = ModelFormat.rgb,
    bool normalize = true,
    bool useCache = true,
    String? cacheKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    final inputSize = modelInputSize ?? _defaultModelInputSize;
    
    try {
      // Check cache first
      final key = cacheKey ?? _generateCacheKey(imageBytes, inputSize, format);
      if (useCache && _preprocessCache.containsKey(key)) {
        final cached = _preprocessCache[key]!;
        if (DateTime.now().difference(cached.timestamp).inMinutes < 10) {
          _performanceMonitor.recordCacheHit('ai_preprocessing');
          return cached.modelInput;
        }
      }
      
      // Memory check
      await _memoryManager.ensureMemoryAvailable(imageBytes.length * 2);
      
      // Optimized preprocessing pipeline
      final modelInput = await _executePreprocessingPipeline(
        imageBytes,
        inputSize,
        format,
        normalize,
      );
      
      // Cache result
      if (useCache) {
        _cachePreprocessedData(key, modelInput);
      }
      
      // Record performance
      _performanceMonitor.recordImageProcessing(
        processingTime: stopwatch.elapsedMilliseconds,
        imageSize: imageBytes.length,
        resultQuality: 1.0,
        algorithm: 'ai_preprocessing',
        additionalData: {
          'inputSize': inputSize,
          'format': format.name,
          'normalized': normalize,
        },
      );
      
      return modelInput;
      
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Preprocess batch of images with optimized memory usage
  Future<List<ModelInput>> preprocessBatch(
    List<Uint8List> imageBatch, {
    int? modelInputSize,
    ModelFormat format = ModelFormat.rgb,
    bool normalize = true,
    bool useCache = true,
  }) async {
    final benchmark = _performanceMonitor.startBenchmark('batch_preprocessing');
    benchmark.addMetadata('batch_size', imageBatch.length);
    
    try {
      final inputSize = modelInputSize ?? _defaultModelInputSize;
      final results = <ModelInput>[];
      
      // Process in optimized batches to manage memory
      const batchSize = 4;
      for (int i = 0; i < imageBatch.length; i += batchSize) {
        final end = math.min(i + batchSize, imageBatch.length);
        final batch = imageBatch.sublist(i, end);
        
        final batchResults = await _processBatchParallel(
          batch,
          inputSize,
          format,
          normalize,
          useCache,
        );
        
        results.addAll(batchResults);
        
        // Memory cleanup between batches
        await _memoryManager.releaseTempMemory();
      }
      
      benchmark.addMetadata('total_processed', results.length);
      return results;
      
    } finally {
      benchmark.finish();
    }
  }
  
  /// Create optimized tensor from preprocessed data
  Float32List createOptimizedTensor(
    ModelInput modelInput, {
    String? tensorKey,
  }) {
    final key = tensorKey ?? 'default_${modelInput.width}x${modelInput.height}x${modelInput.channels}';
    final tensorSize = modelInput.width * modelInput.height * modelInput.channels;
    
    // Try to reuse tensor from pool
    final pool = _tensorPools[key];
    Float32List tensor;
    
    if (pool != null && pool.isNotEmpty) {
      tensor = pool.removeLast();
      _performanceMonitor.recordCacheHit('tensor_pool');
    } else {
      tensor = Float32List(tensorSize);
    }
    
    // Copy data with optimal memory access pattern
    _copyDataOptimized(modelInput.data, tensor, modelInput.format);
    
    return tensor;
  }
  
  /// Release tensor back to pool for reuse
  void releaseTensor(Float32List tensor, {String? tensorKey}) {
    final key = tensorKey ?? 'default_${tensor.length}';
    final pool = _tensorPools.putIfAbsent(key, () => <Float32List>[]);
    
    // Clear tensor and add to pool if not full
    if (pool.length < 5) {
      tensor.fillRange(0, tensor.length, 0.0);
      pool.add(tensor);
    }
  }
  
  /// Prepare image data for specific AI model requirements
  Future<ModelInput> prepareForModel(
    Uint8List imageBytes,
    AIModelSpec modelSpec,
  ) async {
    return await preprocessForInference(
      imageBytes,
      modelInputSize: modelSpec.inputSize,
      format: modelSpec.inputFormat,
      normalize: modelSpec.requiresNormalization,
      useCache: modelSpec.allowCaching,
    );
  }
  
  /// Get preprocessing statistics
  PreprocessingStats getStats() {
    return PreprocessingStats(
      cacheSize: _preprocessCache.length,
      cacheHitRate: _calculateCacheHitRate(),
      tensorPoolSizes: _tensorPools.map((key, pool) => MapEntry(key, pool.length)),
      memoryStats: _memoryManager.getMemoryStats(),
    );
  }
  
  // Private methods
  
  Future<ModelInput> _executePreprocessingPipeline(
    Uint8List imageBytes,
    int inputSize,
    ModelFormat format,
    bool normalize,
  ) async {
    // Step 1: Optimized image decoding
    final image = await _platformOptimizer.decodeImageOptimized(imageBytes);
    if (image == null) {
      throw PreprocessingException('Failed to decode image');
    }
    
    // Step 2: Efficient resizing
    final resizedImage = await _platformOptimizer.resizeImageOptimized(
      image,
      inputSize,
      inputSize,
    );
    
    // Step 3: Format conversion and normalization
    final processedData = await _convertAndNormalize(
      resizedImage,
      format,
      normalize,
    );
    
    return ModelInput(
      data: processedData,
      width: inputSize,
      height: inputSize,
      channels: format.channelCount,
      format: format,
      isNormalized: normalize,
    );
  }
  
  Future<List<ModelInput>> _processBatchParallel(
    List<Uint8List> batch,
    int inputSize,
    ModelFormat format,
    bool normalize,
    bool useCache,
  ) async {
    final futures = batch.map((imageBytes) => preprocessForInference(
      imageBytes,
      modelInputSize: inputSize,
      format: format,
      normalize: normalize,
      useCache: useCache,
    )).toList();
    
    return await Future.wait(futures);
  }
  
  Future<Uint8List> _convertAndNormalize(
    img.Image image,
    ModelFormat format,
    bool normalize,
  ) async {
    final width = image.width;
    final height = image.height;
    final channels = format.channelCount;
    final data = Uint8List(width * height * channels);
    
    // Optimized pixel conversion with SIMD-like operations where possible
    await compute(_convertPixelsIsolate, ConversionTask(
      image: image,
      format: format,
      normalize: normalize,
      outputBuffer: data,
    ));
    
    return data;
  }
  
  void _copyDataOptimized(Uint8List source, Float32List dest, ModelFormat format) {
    // Vectorized copy with format-specific optimizations
    switch (format) {
      case ModelFormat.rgb:
        _copyRGBOptimized(source, dest);
        break;
      case ModelFormat.bgr:
        _copyBGROptimized(source, dest);
        break;
      case ModelFormat.grayscale:
        _copyGrayscaleOptimized(source, dest);
        break;
      case ModelFormat.rgba:
        _copyRGBAOptimized(source, dest);
        break;
    }
  }
  
  void _copyRGBOptimized(Uint8List source, Float32List dest) {
    // Unrolled loop for better performance
    for (int i = 0; i < source.length; i += 4) {
      final baseIndex = (i ~/ 4) * 3;
      dest[baseIndex] = source[i] / 255.0;       // R
      dest[baseIndex + 1] = source[i + 1] / 255.0; // G
      dest[baseIndex + 2] = source[i + 2] / 255.0; // B
    }
  }
  
  void _copyBGROptimized(Uint8List source, Float32List dest) {
    for (int i = 0; i < source.length; i += 4) {
      final baseIndex = (i ~/ 4) * 3;
      dest[baseIndex] = source[i + 2] / 255.0;     // B
      dest[baseIndex + 1] = source[i + 1] / 255.0; // G
      dest[baseIndex + 2] = source[i] / 255.0;     // R
    }
  }
  
  void _copyGrayscaleOptimized(Uint8List source, Float32List dest) {
    for (int i = 0; i < source.length; i += 4) {
      final r = source[i];
      final g = source[i + 1];
      final b = source[i + 2];
      final gray = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      dest[i ~/ 4] = gray;
    }
  }
  
  void _copyRGBAOptimized(Uint8List source, Float32List dest) {
    for (int i = 0; i < source.length; i += 4) {
      final baseIndex = i;
      dest[baseIndex] = source[i] / 255.0;       // R
      dest[baseIndex + 1] = source[i + 1] / 255.0; // G
      dest[baseIndex + 2] = source[i + 2] / 255.0; // B
      dest[baseIndex + 3] = source[i + 3] / 255.0; // A
    }
  }
  
  String _generateCacheKey(Uint8List imageBytes, int inputSize, ModelFormat format) {
    final hash = imageBytes.fold<int>(0, (prev, byte) => prev ^ byte);
    return '${hash}_${inputSize}_${format.name}';
  }
  
  void _cachePreprocessedData(String key, ModelInput modelInput) {
    if (_preprocessCache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestKey = _preprocessCache.keys.first;
      _preprocessCache.remove(oldestKey);
    }
    
    _preprocessCache[key] = PreprocessedData(
      modelInput: modelInput,
      timestamp: DateTime.now(),
    );
  }
  
  void _warmupTensorPools() {
    // Pre-allocate common tensor sizes
    final commonSizes = [224, 256, 299, 512];
    
    for (final size in commonSizes) {
      for (final channels in [1, 3, 4]) {
        final key = 'default_${size}x${size}x$channels';
        final pool = _tensorPools.putIfAbsent(key, () => <Float32List>[]);
        
        // Pre-allocate 2 tensors per common size
        for (int i = 0; i < 2; i++) {
          pool.add(Float32List(size * size * channels));
        }
      }
    }
  }
  
  void _initializeBatchProcessor() {
    _batchProcessor = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_batchQueue.isNotEmpty) {
        _processBatchQueue();
      }
    });
  }
  
  void _processBatchQueue() {
    // Process queued batch operations
    // This could be used for background preprocessing
  }
  
  double _calculateCacheHitRate() {
    // This would track actual hit/miss ratios
    return 0.8; // Placeholder
  }
  
  void dispose() {
    _batchProcessor?.cancel();
    _preprocessCache.clear();
    _tensorPools.clear();
    _platformOptimizer.dispose();
    debugPrint('OptimizedAIPreprocessor: Disposed');
  }
}

// Isolate function for pixel conversion
ConversionResult _convertPixelsIsolate(ConversionTask task) {
  final image = task.image;
  final format = task.format;
  final normalize = task.normalize;
  final output = task.outputBuffer;
  
  int outputIndex = 0;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = pixel.a.toInt();
      
      switch (format) {
        case ModelFormat.rgb:
          output[outputIndex++] = normalize ? (r / 255.0 * 255).toInt() : r;
          output[outputIndex++] = normalize ? (g / 255.0 * 255).toInt() : g;
          output[outputIndex++] = normalize ? (b / 255.0 * 255).toInt() : b;
          break;
        case ModelFormat.bgr:
          output[outputIndex++] = normalize ? (b / 255.0 * 255).toInt() : b;
          output[outputIndex++] = normalize ? (g / 255.0 * 255).toInt() : g;
          output[outputIndex++] = normalize ? (r / 255.0 * 255).toInt() : r;
          break;
        case ModelFormat.rgba:
          output[outputIndex++] = normalize ? (r / 255.0 * 255).toInt() : r;
          output[outputIndex++] = normalize ? (g / 255.0 * 255).toInt() : g;
          output[outputIndex++] = normalize ? (b / 255.0 * 255).toInt() : b;
          output[outputIndex++] = normalize ? (a / 255.0 * 255).toInt() : a;
          break;
        case ModelFormat.grayscale:
          final gray = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
          output[outputIndex++] = normalize ? (gray / 255.0 * 255).toInt() : gray;
          break;
      }
    }
  }
  
  return ConversionResult(success: true, processedBytes: outputIndex);
}

// Data classes

class ModelInput {
  final Uint8List data;
  final int width;
  final int height;
  final int channels;
  final ModelFormat format;
  final bool isNormalized;
  
  ModelInput({
    required this.data,
    required this.width,
    required this.height,
    required this.channels,
    required this.format,
    required this.isNormalized,
  });
  
  int get totalSize => width * height * channels;
}

enum ModelFormat {
  rgb(3),
  bgr(3),
  rgba(4),
  grayscale(1);
  
  const ModelFormat(this.channelCount);
  final int channelCount;
}

class AIModelSpec {
  final int inputSize;
  final ModelFormat inputFormat;
  final bool requiresNormalization;
  final bool allowCaching;
  
  AIModelSpec({
    required this.inputSize,
    required this.inputFormat,
    this.requiresNormalization = true,
    this.allowCaching = true,
  });
}

class PreprocessedData {
  final ModelInput modelInput;
  final DateTime timestamp;
  
  PreprocessedData({
    required this.modelInput,
    required this.timestamp,
  });
}

class PreprocessingTask {
  final String id;
  final Uint8List imageBytes;
  final int inputSize;
  final ModelFormat format;
  final Completer<ModelInput> completer;
  
  PreprocessingTask({
    required this.id,
    required this.imageBytes,
    required this.inputSize,
    required this.format,
    required this.completer,
  });
}

class PreprocessingStats {
  final int cacheSize;
  final double cacheHitRate;
  final Map<String, int> tensorPoolSizes;
  final MemoryStats memoryStats;
  
  PreprocessingStats({
    required this.cacheSize,
    required this.cacheHitRate,
    required this.tensorPoolSizes,
    required this.memoryStats,
  });
  
  @override
  String toString() {
    return 'PreprocessingStats(cache: $cacheSize, hitRate: ${(cacheHitRate * 100).toStringAsFixed(1)}%, pools: $tensorPoolSizes)';
  }
}

class ConversionTask {
  final img.Image image;
  final ModelFormat format;
  final bool normalize;
  final Uint8List outputBuffer;
  
  ConversionTask({
    required this.image,
    required this.format,
    required this.normalize,
    required this.outputBuffer,
  });
}

class ConversionResult {
  final bool success;
  final int processedBytes;
  
  ConversionResult({
    required this.success,
    required this.processedBytes,
  });
}

class PreprocessingException implements Exception {
  final String message;
  
  PreprocessingException(this.message);
  
  @override
  String toString() => 'PreprocessingException: $message';
}