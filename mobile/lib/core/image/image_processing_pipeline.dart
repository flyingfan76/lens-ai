import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/memory_manager.dart';
import '../utils/performance_monitor.dart';
import 'optimized_image_processor.dart';

/// High-performance image processing pipeline with parallel processing and optimization
class ImageProcessingPipeline {
  static const Duration _taskTimeout = Duration(seconds: 30);
  
  final OptimizedImageProcessor _processor;
  final MemoryManager _memoryManager;
  final PerformanceMonitor _performanceMonitor;
  
  // Task management
  final Map<String, ProcessingTask> _activeTasks = {};
  final Queue<ProcessingTask> _taskQueue = Queue<ProcessingTask>();
  int _runningTasks = 0;
  
  // Worker isolates for parallel processing
  final List<IsolateWorker> _workers = [];
  bool _isInitialized = false;
  
  // Pipeline configuration
  PipelineConfiguration _config = const PipelineConfiguration();
  
  ImageProcessingPipeline({
    OptimizedImageProcessor? processor,
    MemoryManager? memoryManager,
    PerformanceMonitor? performanceMonitor,
  }) : _processor = processor ?? OptimizedImageProcessor(),
        _memoryManager = memoryManager ?? MemoryManager(),
        _performanceMonitor = performanceMonitor ?? PerformanceMonitor();
  
  /// Initialize the pipeline with worker isolates
  Future<void> initialize({PipelineConfiguration? config}) async {
    if (_isInitialized) return;
    
    _config = config ?? _config;
    
    final benchmark = _performanceMonitor.startBenchmark('pipeline_initialization');
    
    try {
      // Initialize worker isolates
      for (int i = 0; i < _config.maxWorkers; i++) {
        final worker = await _createWorkerIsolate('worker_$i');
        _workers.add(worker);
      }
      
      _isInitialized = true;
      benchmark.addMetadata('workers_created', _workers.length);
      debugPrint('ImageProcessingPipeline: Initialized with ${_workers.length} workers');
      
    } catch (e) {
      debugPrint('ImageProcessingPipeline: Failed to initialize: $e');
      rethrow;
    } finally {
      benchmark.finish();
    }
  }
  
  /// Process single image with optimized pipeline
  Future<SceneAnalysisOptimized> processImage(
    Uint8List imageBytes, {
    ProcessingOptions? options,
  }) async {
    if (!_isInitialized) await initialize();
    
    final taskId = 'single_${DateTime.now().millisecondsSinceEpoch}';
    final task = ProcessingTask(
      id: taskId,
      type: ProcessingTaskType.singleImage,
      imageBytes: imageBytes,
      options: options ?? ProcessingOptions(),
    );
    
    return await _executeTask(task);
  }
  
  /// Process multiple images in parallel batches
  Future<List<SceneAnalysisOptimized>> processBatch(
    List<Uint8List> imageBatch, {
    ProcessingOptions? options,
  }) async {
    if (!_isInitialized) await initialize();
    
    final benchmark = _performanceMonitor.startBenchmark('batch_processing');
    benchmark.addMetadata('batch_size', imageBatch.length);
    
    try {
      final results = <SceneAnalysisOptimized>[];
      final batches = _splitIntoBatches(imageBatch, _config.batchSize);
      
      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];
        final batchResults = await _processBatchParallel(batch, options, batchIndex);
        results.addAll(batchResults);
      }
      
      benchmark.addMetadata('total_processed', results.length);
      return results;
      
    } finally {
      benchmark.finish();
    }
  }
  
  /// Process images with streaming results
  Stream<ProcessingResult> processStream(
    Stream<Uint8List> imageStream, {
    ProcessingOptions? options,
  }) async* {
    if (!_isInitialized) await initialize();
    
    final buffer = <Uint8List>[];
    
    await for (final imageBytes in imageStream) {
      buffer.add(imageBytes);
      
      // Process in batches
      if (buffer.length >= _config.streamBatchSize) {
        final batchResults = await processBatch(buffer, options: options);
        
        for (int i = 0; i < batchResults.length; i++) {
          yield ProcessingResult(
            analysis: batchResults[i],
            originalImage: buffer[i],
            processingIndex: i,
          );
        }
        
        buffer.clear();
      }
    }
    
    // Process remaining images
    if (buffer.isNotEmpty) {
      final batchResults = await processBatch(buffer, options: options);
      for (int i = 0; i < batchResults.length; i++) {
        yield ProcessingResult(
          analysis: batchResults[i],
          originalImage: buffer[i],
          processingIndex: i,
        );
      }
    }
  }
  
  /// Process large image progressively
  Future<SceneAnalysisOptimized> processLargeImage(
    Uint8List imageBytes, {
    ProcessingOptions? options,
  }) async {
    if (!_isInitialized) await initialize();
    
    final benchmark = _performanceMonitor.startBenchmark('large_image_processing');
    
    try {
      // Check if progressive processing is needed
      if (imageBytes.length > _config.largeImageThreshold) {
        return await _processProgressively(imageBytes, options);
      } else {
        return await processImage(imageBytes, options: options);
      }
    } finally {
      benchmark.finish();
    }
  }
  
  /// Get pipeline performance metrics
  PipelineMetrics getMetrics() {
    return PipelineMetrics(
      activeTasks: _activeTasks.length,
      queuedTasks: _taskQueue.length,
      runningTasks: _runningTasks,
      totalWorkers: _workers.length,
      memoryStats: _memoryManager.getMemoryStats(),
      performanceSummary: _performanceMonitor.getSummary(),
    );
  }
  
  /// Configure pipeline settings
  void configure(PipelineConfiguration config) {
    _config = config;
  }
  
  /// Cancel all pending tasks
  Future<void> cancelAllTasks() async {
    for (final task in _activeTasks.values) {
      task.completer.completeError(ProcessingCancelledException('Task cancelled'));
    }
    _activeTasks.clear();
    _taskQueue.clear();
  }
  
  // Private methods
  
  Future<SceneAnalysisOptimized> _executeTask(ProcessingTask task) async {
    final completer = Completer<SceneAnalysisOptimized>();
    task.completer = completer;
    
    _activeTasks[task.id] = task;
    
    try {
      if (_runningTasks < _config.maxConcurrentTasks) {
        unawaited(_processTaskImmediate(task));
      } else {
        _taskQueue.add(task);
      }
      
      return await completer.future.timeout(_taskTimeout);
      
    } catch (e) {
      _performanceMonitor.recordError('task_execution', e.toString());
      rethrow;
    } finally {
      _activeTasks.remove(task.id);
    }
  }
  
  Future<void> _processTaskImmediate(ProcessingTask task) async {
    _runningTasks++;
    
    try {
      final result = await _processImageWithWorker(task);
      task.completer.complete(result);
      
    } catch (e) {
      task.completer.completeError(e);
    } finally {
      _runningTasks--;
      _processNextTask();
    }
  }
  
  void _processNextTask() {
    if (_taskQueue.isNotEmpty && _runningTasks < _config.maxConcurrentTasks) {
      final nextTask = _taskQueue.removeFirst();
      unawaited(_processTaskImmediate(nextTask));
    }
  }
  
  Future<SceneAnalysisOptimized> _processImageWithWorker(ProcessingTask task) async {
    // Select best available worker
    final worker = _selectOptimalWorker();
    
    if (worker != null) {
      return await _processWithIsolate(worker, task);
    } else {
      // Fallback to main thread processing
      return await _processor.analyzeImageOptimized(
        task.imageBytes,
        useCache: task.options.useCache,
        useProgressiveProcessing: task.options.useProgressiveProcessing,
        targetSize: task.options.targetSize,
      );
    }
  }
  
  Future<List<SceneAnalysisOptimized>> _processBatchParallel(
    List<Uint8List> batch,
    ProcessingOptions? options,
    int batchIndex,
  ) async {
    final futures = <Future<SceneAnalysisOptimized>>[];
    
    for (int i = 0; i < batch.length; i++) {
      final taskId = 'batch_${batchIndex}_$i';
      final task = ProcessingTask(
        id: taskId,
        type: ProcessingTaskType.batchImage,
        imageBytes: batch[i],
        options: options ?? ProcessingOptions(),
      );
      
      futures.add(_executeTask(task));
    }
    
    return await Future.wait(futures);
  }
  
  Future<SceneAnalysisOptimized> _processProgressively(
    Uint8List imageBytes,
    ProcessingOptions? options,
  ) async {
    final benchmark = _performanceMonitor.startBenchmark('progressive_processing');
    
    try {
      // Step 1: Quick low-resolution analysis
      final quickOptions = ProcessingOptions(
        targetSize: 256,
        useCache: false,
        useProgressiveProcessing: false,
      );
      
      final quickResult = await _processor.analyzeImageOptimized(
        imageBytes,
        targetSize: quickOptions.targetSize,
        useCache: quickOptions.useCache,
        useProgressiveProcessing: quickOptions.useProgressiveProcessing,
      );
      
      // Step 2: Detailed analysis if needed
      if ((options?.requireHighAccuracy ?? false) || quickResult.confidence < 0.7) {
        final detailedOptions = options ?? ProcessingOptions();
        return await _processor.analyzeImageOptimized(
          imageBytes,
          targetSize: detailedOptions.targetSize,
          useCache: detailedOptions.useCache,
          useProgressiveProcessing: true,
        );
      }
      
      return quickResult;
      
    } finally {
      benchmark.finish();
    }
  }
  
  IsolateWorker? _selectOptimalWorker() {
    if (_workers.isEmpty) return null;
    
    // Find worker with least load
    IsolateWorker? bestWorker;
    int minLoad = double.maxFinite.toInt();
    
    for (final worker in _workers) {
      if (worker.isAvailable && worker.currentLoad < minLoad) {
        bestWorker = worker;
        minLoad = worker.currentLoad;
      }
    }
    
    return bestWorker;
  }
  
  Future<SceneAnalysisOptimized> _processWithIsolate(IsolateWorker worker, ProcessingTask task) async {
    final request = IsolateRequest(
      id: task.id,
      imageBytes: task.imageBytes,
      options: task.options,
    );
    
    worker.currentLoad++;
    
    try {
      final response = await worker.sendRequest(request);
      if (response.result != null) {
        return response.result!;
      } else {
        throw Exception('Processing failed: null result');
      }
    } finally {
      worker.currentLoad--;
    }
  }
  
  Future<IsolateWorker> _createWorkerIsolate(String name) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_isolateEntryPoint, receivePort.sendPort);
    
    final worker = IsolateWorker(
      name: name,
      isolate: isolate,
      receivePort: receivePort,
    );
    
    await worker.initialize();
    return worker;
  }
  
  static void _isolateEntryPoint(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    final processor = OptimizedImageProcessor();
    
    receivePort.listen((message) async {
      if (message is IsolateRequest) {
        try {
          final result = await processor.analyzeImageOptimized(
            message.imageBytes,
            useCache: message.options.useCache,
            useProgressiveProcessing: message.options.useProgressiveProcessing,
            targetSize: message.options.targetSize,
          );
          
          final response = IsolateResponse(
            id: message.id,
            result: result,
            success: true,
          );
          
          sendPort.send(response);
        } catch (e) {
          final response = IsolateResponse(
            id: message.id,
            result: null,
            success: false,
            error: e.toString(),
          );
          
          sendPort.send(response);
        }
      }
    });
  }
  
  List<List<T>> _splitIntoBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = math.min(i + batchSize, items.length);
      batches.add(items.sublist(i, end));
    }
    return batches;
  }
  
  void dispose() {
    // Cancel all tasks
    unawaited(cancelAllTasks());
    
    // Dispose workers
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    
    // Dispose components
    _processor.dispose();
    _memoryManager.dispose();
    _performanceMonitor.dispose();
    
    _isInitialized = false;
    debugPrint('ImageProcessingPipeline: Disposed');
  }
}

/// Worker isolate for parallel processing
class IsolateWorker {
  final String name;
  final Isolate isolate;
  final ReceivePort receivePort;
  
  SendPort? _sendPort;
  final Map<String, Completer<IsolateResponse>> _pendingRequests = {};
  bool _isInitialized = false;
  int currentLoad = 0;
  
  IsolateWorker({
    required this.name,
    required this.isolate,
    required this.receivePort,
  });
  
  bool get isAvailable => _isInitialized && currentLoad < 2;
  
  Future<void> initialize() async {
    final completer = Completer<void>();
    
    late StreamSubscription subscription;
    subscription = receivePort.listen((message) {
      if (message is SendPort && !_isInitialized) {
        _sendPort = message;
        _isInitialized = true;
        completer.complete();
      } else if (message is IsolateResponse) {
        final completer = _pendingRequests.remove(message.id);
        if (completer != null) {
          if (message.success) {
            completer.complete(message);
          } else {
            completer.completeError(ProcessingException(message.error ?? 'Unknown error'));
          }
        }
      }
    });
    
    await completer.future;
    debugPrint('IsolateWorker: $name initialized');
  }
  
  Future<IsolateResponse> sendRequest(IsolateRequest request) async {
    if (!_isInitialized || _sendPort == null) {
      throw StateError('Worker not initialized');
    }
    
    final completer = Completer<IsolateResponse>();
    _pendingRequests[request.id] = completer;
    
    _sendPort!.send(request);
    
    return await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(request.id);
        throw TimeoutException('Processing timeout', const Duration(seconds: 30));
      },
    );
  }
  
  void dispose() {
    receivePort.close();
    isolate.kill();
    
    // Complete pending requests with error
    for (final completer in _pendingRequests.values) {
      completer.completeError(ProcessingCancelledException('Worker disposed'));
    }
    _pendingRequests.clear();
    
    debugPrint('IsolateWorker: $name disposed');
  }
}

// Data classes and configuration

class PipelineConfiguration {
  final int maxWorkers;
  final int maxConcurrentTasks;
  final int batchSize;
  final int streamBatchSize;
  final int largeImageThreshold;
  
  const PipelineConfiguration({
    this.maxWorkers = 2,
    this.maxConcurrentTasks = 4,
    this.batchSize = 8,
    this.streamBatchSize = 4,
    this.largeImageThreshold = 20 * 1024 * 1024, // 20MB
  });
}

class ProcessingOptions {
  final bool useCache;
  final bool useProgressiveProcessing;
  final int? targetSize;
  final bool requireHighAccuracy;
  
  ProcessingOptions({
    this.useCache = true,
    this.useProgressiveProcessing = true,
    this.targetSize,
    this.requireHighAccuracy = false,
  });
}

class ProcessingTask {
  final String id;
  final ProcessingTaskType type;
  final Uint8List imageBytes;
  final ProcessingOptions options;
  late final Completer<SceneAnalysisOptimized> completer;
  
  ProcessingTask({
    required this.id,
    required this.type,
    required this.imageBytes,
    required this.options,
  });
}

enum ProcessingTaskType {
  singleImage,
  batchImage,
  streamImage,
  largeImage,
}

class ProcessingResult {
  final SceneAnalysisOptimized analysis;
  final Uint8List originalImage;
  final int processingIndex;
  
  ProcessingResult({
    required this.analysis,
    required this.originalImage,
    required this.processingIndex,
  });
}

class PipelineMetrics {
  final int activeTasks;
  final int queuedTasks;
  final int runningTasks;
  final int totalWorkers;
  final MemoryStats memoryStats;
  final PerformanceSummary performanceSummary;
  
  PipelineMetrics({
    required this.activeTasks,
    required this.queuedTasks,
    required this.runningTasks,
    required this.totalWorkers,
    required this.memoryStats,
    required this.performanceSummary,
  });
  
  double get efficiency => runningTasks / math.max(1, totalWorkers);
  double get utilization => (activeTasks + runningTasks) / math.max(1, totalWorkers * 2);
}

class IsolateRequest {
  final String id;
  final Uint8List imageBytes;
  final ProcessingOptions options;
  
  IsolateRequest({
    required this.id,
    required this.imageBytes,
    required this.options,
  });
}

class IsolateResponse {
  final String id;
  final SceneAnalysisOptimized? result;
  final bool success;
  final String? error;
  
  IsolateResponse({
    required this.id,
    required this.result,
    required this.success,
    this.error,
  });
}

// Custom exceptions

class ProcessingException implements Exception {
  final String message;
  
  ProcessingException(this.message);
  
  @override
  String toString() => 'ProcessingException: $message';
}

class ProcessingCancelledException extends ProcessingException {
  ProcessingCancelledException(super.message);
}

class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}

// Utilities