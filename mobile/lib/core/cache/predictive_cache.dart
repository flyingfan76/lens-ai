import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'cache_manager.dart';
import 'cache_metrics.dart';

/// Intelligent predictive cache that learns user patterns and preloads likely-needed data
/// 
/// Features:
/// - Machine learning-based usage pattern recognition
/// - Context-aware preloading strategies
/// - Time-based and location-based prediction models
/// - Adaptive learning from user behavior
/// - Background preloading with resource management
/// - Performance optimization through smart prefetching
class PredictiveCache {
  final CacheManager _cacheManager;
  final CacheMetrics _metrics;
  
  // Pattern learning and prediction
  final Map<String, _UserPattern> _userPatterns = {};
  final Map<String, _ContextPattern> _contextPatterns = {};
  final Queue<_AccessEvent> _accessHistory = Queue();
  static const int _maxHistorySize = 10000;
  
  // Preloading management
  final Set<String> _preloadQueue = {};
  final Map<String, _PreloadTask> _activeTasks = {};
  final Set<String> _preloadedKeys = {};
  Timer? _preloadTimer;
  Timer? _patternAnalysisTimer;
  
  // Configuration
  final int _maxPreloadConcurrency;
  final Duration _patternAnalysisInterval;
  final double _predictionThreshold;
  final int _maxPreloadQueueSize;
  
  // Performance tracking
  int _predictionsGenerated = 0;
  int _preloadHits = 0;
  int _preloadMisses = 0;
  int _backgroundTasksCompleted = 0;
  
  // Context tracking
  String? _currentContext;
  DateTime? _lastContextChange;
  final Map<String, DateTime> _contextHistory = {};
  
  DateTime? get lastContextChange => _lastContextChange;
  
  PredictiveCache({
    CacheManager? cacheManager,
    int maxPreloadConcurrency = 3,
    Duration patternAnalysisInterval = const Duration(minutes: 5),
    double predictionThreshold = 0.7,
    int maxPreloadQueueSize = 100,
  })  : _cacheManager = cacheManager ?? CacheManager.named('predictive'),
        _metrics = CacheMetrics(),
        _maxPreloadConcurrency = maxPreloadConcurrency,
        _patternAnalysisInterval = patternAnalysisInterval,
        _predictionThreshold = predictionThreshold,
        _maxPreloadQueueSize = maxPreloadQueueSize;
  
  /// Initialize the predictive cache
  Future<void> initialize() async {
    await _cacheManager.initialize();
    _startBackgroundTasks();
    debugPrint('PredictiveCache: Initialized with ML-based prediction');
  }
  
  /// Record an access event for pattern learning
  void recordAccess(String key, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    final event = _AccessEvent(
      key: key,
      timestamp: DateTime.now(),
      context: context ?? _currentContext,
      metadata: metadata ?? {},
    );
    
    _accessHistory.add(event);
    
    // Limit history size
    if (_accessHistory.length > _maxHistorySize) {
      _accessHistory.removeFirst();
    }
    
    // Update patterns
    _updateUserPatterns(event);
    _updateContextPatterns(event);
    
    // Check if this was a predicted access
    if (_preloadedKeys.contains(key)) {
      _preloadHits++;
      _preloadedKeys.remove(key);
      debugPrint('PredictiveCache: Prediction hit for key: $key');
    }
  }
  
  /// Set current context for contextual predictions
  void setContext(String context, {Map<String, dynamic>? metadata}) {
    if (_currentContext != context) {
      _currentContext = context;
      _lastContextChange = DateTime.now();
      _contextHistory[context] = DateTime.now();
      
      // Generate predictions for new context
      _generateContextualPredictions(context, metadata ?? {});
    }
  }
  
  /// Generate predictions based on current patterns
  Future<List<PredictionResult>> generatePredictions({
    String? context,
    int maxPredictions = 10,
    double minConfidence = 0.5,
  }) async {
    final predictions = <PredictionResult>[];
    final targetContext = context ?? _currentContext;
    
    // Time-based predictions
    predictions.addAll(await _generateTimeBased(targetContext, maxPredictions ~/ 3));
    
    // Sequence-based predictions
    predictions.addAll(await _generateSequenceBased(targetContext, maxPredictions ~/ 3));
    
    // Context-based predictions
    predictions.addAll(await _generateContextBased(targetContext, maxPredictions ~/ 3));
    
    // Sort by confidence and filter
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    final filteredPredictions = predictions
        .where((p) => p.confidence >= minConfidence)
        .take(maxPredictions)
        .toList();
    
    _predictionsGenerated += filteredPredictions.length;
    
    debugPrint('PredictiveCache: Generated ${filteredPredictions.length} predictions');
    return filteredPredictions;
  }
  
  /// Trigger predictive preloading based on current context
  Future<void> triggerPreloading({
    String? context,
    Map<String, dynamic>? hints,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _analyzePatterns();
    }
    
    final predictions = await generatePredictions(
      context: context,
      maxPredictions: 20,
      minConfidence: _predictionThreshold,
    );
    
    // Add high-confidence predictions to preload queue
    for (final prediction in predictions) {
      if (prediction.confidence > _predictionThreshold) {
        _schedulePreload(prediction);
      }
    }
    
    debugPrint('PredictiveCache: Scheduled ${predictions.length} items for preloading');
  }
  
  /// Check if a key is likely to be accessed soon
  Future<double> getPredictionConfidence(String key, {String? context}) async {
    final targetContext = context ?? _currentContext;
    
    // Check user patterns
    final userPattern = _userPatterns[key];
    double userConfidence = 0.0;
    
    if (userPattern != null) {
      userConfidence = _calculateUserPatternConfidence(userPattern);
    }
    
    // Check context patterns
    double contextConfidence = 0.0;
    if (targetContext != null) {
      final contextPattern = _contextPatterns[targetContext];
      if (contextPattern != null && contextPattern.keyFrequencies.containsKey(key)) {
        contextConfidence = contextPattern.keyFrequencies[key]! / contextPattern.totalAccesses;
      }
    }
    
    // Combine confidences
    return math.max(userConfidence, contextConfidence);
  }
  
  /// Get preloading statistics
  PredictiveCacheStats getStats() {
    final managerStats = _cacheManager.getStats();
    
    return PredictiveCacheStats(
      userPatterns: _userPatterns.length,
      contextPatterns: _contextPatterns.length,
      accessHistorySize: _accessHistory.length,
      predictionsGenerated: _predictionsGenerated,
      preloadHits: _preloadHits,
      preloadMisses: _preloadMisses,
      preloadQueueSize: _preloadQueue.length,
      activePreloadTasks: _activeTasks.length,
      backgroundTasksCompleted: _backgroundTasksCompleted,
      predictionAccuracy: _preloadHits + _preloadMisses > 0 
          ? _preloadHits / (_preloadHits + _preloadMisses) 
          : 0.0,
      managerStats: managerStats,
    );
  }
  
  /// Clear learned patterns (for testing or reset)
  void clearPatterns() {
    _userPatterns.clear();
    _contextPatterns.clear();
    _accessHistory.clear();
    _preloadQueue.clear();
    _preloadedKeys.clear();
    _contextHistory.clear();
    
    _predictionsGenerated = 0;
    _preloadHits = 0;
    _preloadMisses = 0;
    _backgroundTasksCompleted = 0;
    
    debugPrint('PredictiveCache: Cleared all learned patterns');
  }
  
  // Private methods for pattern analysis and prediction
  
  void _startBackgroundTasks() {
    // Preloading task processor
    _preloadTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processPreloadQueue();
    });
    
    // Pattern analysis timer
    _patternAnalysisTimer = Timer.periodic(_patternAnalysisInterval, (_) {
      _analyzePatterns();
    });
  }
  
  void _updateUserPatterns(_AccessEvent event) {
    final pattern = _userPatterns.putIfAbsent(
      event.key,
      () => _UserPattern(key: event.key),
    );
    
    pattern.addAccess(event.timestamp);
    pattern.updateMetadata(event.metadata);
    
    // Update access frequency
    pattern.totalAccesses++;
    
    // Calculate time-based patterns
    _updateTimePatterns(pattern, event.timestamp);
  }
  
  void _updateContextPatterns(_AccessEvent event) {
    if (event.context == null) return;
    
    final pattern = _contextPatterns.putIfAbsent(
      event.context!,
      () => _ContextPattern(context: event.context!),
    );
    
    pattern.addAccess(event.key, event.timestamp);
    pattern.totalAccesses++;
    
    // Update key frequencies
    pattern.keyFrequencies[event.key] = 
        (pattern.keyFrequencies[event.key] ?? 0) + 1;
  }
  
  void _updateTimePatterns(_UserPattern pattern, DateTime timestamp) {
    final hour = timestamp.hour;
    final dayOfWeek = timestamp.weekday;
    
    // Hour-based patterns
    pattern.hourlyPatterns[hour] = (pattern.hourlyPatterns[hour] ?? 0) + 1;
    
    // Day-of-week patterns
    pattern.dailyPatterns[dayOfWeek] = (pattern.dailyPatterns[dayOfWeek] ?? 0) + 1;
    
    // Calculate intervals between accesses
    if (pattern.lastAccess != null) {
      final interval = timestamp.difference(pattern.lastAccess!);
      pattern.accessIntervals.add(interval.inMinutes);
      
      // Keep only recent intervals
      if (pattern.accessIntervals.length > 50) {
        pattern.accessIntervals.removeFirst();
      }
    }
    
    pattern.lastAccess = timestamp;
  }
  
  Future<void> _analyzePatterns() async {
    // Analyze user patterns for insights
    for (final pattern in _userPatterns.values) {
      _analyzeUserPattern(pattern);
    }
    
    // Analyze context patterns
    for (final pattern in _contextPatterns.values) {
      _analyzeContextPattern(pattern);
    }
    
    // Generate predictive insights
    await _generatePredictiveInsights();
    
    debugPrint('PredictiveCache: Pattern analysis completed');
  }
  
  void _analyzeUserPattern(_UserPattern pattern) {
    // Calculate average access interval
    if (pattern.accessIntervals.isNotEmpty) {
      final sum = pattern.accessIntervals.reduce((a, b) => a + b);
      pattern.averageInterval = sum / pattern.accessIntervals.length;
    }
    
    // Find peak usage hours
    if (pattern.hourlyPatterns.isNotEmpty) {
      final maxHour = pattern.hourlyPatterns.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      pattern.peakHour = maxHour.key;
    }
    
    // Calculate regularity score
    pattern.regularityScore = _calculateRegularityScore(pattern);
  }
  
  void _analyzeContextPattern(_ContextPattern pattern) {
    // Calculate key probabilities
    for (final entry in pattern.keyFrequencies.entries) {
      pattern.keyProbabilities[entry.key] = 
          entry.value / pattern.totalAccesses;
    }
  }
  
  double _calculateRegularityScore(_UserPattern pattern) {
    if (pattern.accessIntervals.length < 3) return 0.0;
    
    // Calculate coefficient of variation for intervals
    final mean = pattern.averageInterval ?? 0.0;
    if (mean == 0.0) return 0.0;
    
    final variance = pattern.accessIntervals
        .map((interval) => math.pow(interval - mean, 2))
        .reduce((a, b) => a + b) / pattern.accessIntervals.length;
    
    final stdDev = math.sqrt(variance);
    final cv = stdDev / mean;
    
    // Convert to regularity score (lower CV = higher regularity)
    return math.max(0.0, 1.0 - cv);
  }
  
  Future<void> _generatePredictiveInsights() async {
    // Look for sequential patterns
    _findSequentialPatterns();
    
    // Identify contextual relationships
    _findContextualRelationships();
    
    // Update prediction models
    _updatePredictionModels();
  }
  
  void _findSequentialPatterns() {
    // Analyze access sequences to find common patterns
    final recentEvents = _accessHistory
        .where((e) => DateTime.now().difference(e.timestamp).inHours < 24)
        .toList();
    
    // Simple sequential pattern detection
    for (int i = 0; i < recentEvents.length - 1; i++) {
      final current = recentEvents[i];
      final next = recentEvents[i + 1];
      
      final timeDiff = next.timestamp.difference(current.timestamp);
      
      if (timeDiff.inMinutes < 30) { // Within 30 minutes
        // Update sequential patterns
        final userPattern = _userPatterns[current.key];
        if (userPattern != null) {
          userPattern.sequentialPatterns[next.key] = 
              (userPattern.sequentialPatterns[next.key] ?? 0) + 1;
        }
      }
    }
  }
  
  void _findContextualRelationships() {
    // Analyze relationships between contexts and access patterns
    for (final contextPattern in _contextPatterns.values) {
      // Find keys that are frequently accessed together in this context
      final coOccurrences = <String, Map<String, int>>{};
      
      final contextEvents = _accessHistory
          .where((e) => e.context == contextPattern.context)
          .toList();
      
      // Simple co-occurrence analysis
      for (int i = 0; i < contextEvents.length - 1; i++) {
        final current = contextEvents[i].key;
        final next = contextEvents[i + 1].key;
        
        if (current != next) {
          coOccurrences.putIfAbsent(current, () => {});
          coOccurrences[current]![next] = 
              (coOccurrences[current]![next] ?? 0) + 1;
        }
      }
      
      contextPattern.coOccurrences = coOccurrences;
    }
  }
  
  void _updatePredictionModels() {
    // Update internal prediction models based on learned patterns
    // This could involve more sophisticated ML models in a production system
    
    for (final pattern in _userPatterns.values) {
      // Simple time-based prediction model
      if (pattern.peakHour != null && pattern.averageInterval != null) {
        final currentHour = DateTime.now().hour;
        final hourDiff = (pattern.peakHour! - currentHour).abs();
        
        // Higher confidence if we're near peak usage time
        pattern.timePredictionConfidence = math.max(0.0, 1.0 - (hourDiff / 12.0));
      }
    }
  }
  
  Future<List<PredictionResult>> _generateTimeBased(String? context, int maxResults) async {
    final predictions = <PredictionResult>[];
    final currentHour = DateTime.now().hour;
    
    for (final pattern in _userPatterns.values) {
      if (pattern.peakHour == currentHour && pattern.regularityScore > 0.5) {
        final confidence = pattern.timePredictionConfidence * pattern.regularityScore;
        
        if (confidence > 0.3) {
          predictions.add(PredictionResult(
            key: pattern.key,
            confidence: confidence,
            reason: 'Time-based pattern (peak hour: ${pattern.peakHour})',
            type: PredictionType.timeBased,
            estimatedAccessTime: DateTime.now().add(
              Duration(minutes: (pattern.averageInterval ?? 60).round()),
            ),
          ));
        }
      }
    }
    
    return predictions.take(maxResults).toList();
  }
  
  Future<List<PredictionResult>> _generateSequenceBased(String? context, int maxResults) async {
    final predictions = <PredictionResult>[];
    
    // Look at recent accesses to predict next items
    final recentAccesses = _accessHistory
        .where((e) => DateTime.now().difference(e.timestamp).inMinutes < 30)
        .map((e) => e.key)
        .toSet();
    
    for (final recentKey in recentAccesses) {
      final pattern = _userPatterns[recentKey];
      if (pattern != null) {
        for (final entry in pattern.sequentialPatterns.entries) {
          final nextKey = entry.key;
          final frequency = entry.value;
          
          final confidence = frequency / pattern.totalAccesses.toDouble();
          
          if (confidence > 0.2) {
            predictions.add(PredictionResult(
              key: nextKey,
              confidence: confidence,
              reason: 'Sequential pattern after $recentKey',
              type: PredictionType.sequenceBased,
              estimatedAccessTime: DateTime.now().add(const Duration(minutes: 10)),
            ));
          }
        }
      }
    }
    
    return predictions.take(maxResults).toList();
  }
  
  Future<List<PredictionResult>> _generateContextBased(String? context, int maxResults) async {
    final predictions = <PredictionResult>[];
    
    if (context != null) {
      final contextPattern = _contextPatterns[context];
      if (contextPattern != null) {
        for (final entry in contextPattern.keyProbabilities.entries) {
          final key = entry.key;
          final probability = entry.value;
          
          if (probability > 0.1) {
            predictions.add(PredictionResult(
              key: key,
              confidence: probability,
              reason: 'Context-based pattern in $context',
              type: PredictionType.contextBased,
              estimatedAccessTime: DateTime.now().add(const Duration(minutes: 15)),
            ));
          }
        }
      }
    }
    
    return predictions.take(maxResults).toList();
  }
  
  double _calculateUserPatternConfidence(_UserPattern pattern) {
    double confidence = 0.0;
    
    // Time-based confidence
    if (pattern.timePredictionConfidence > 0) {
      confidence += pattern.timePredictionConfidence * 0.4;
    }
    
    // Regularity-based confidence
    confidence += pattern.regularityScore * 0.3;
    
    // Frequency-based confidence
    if (pattern.totalAccesses > 5) {
      confidence += math.min(0.3, pattern.totalAccesses / 100.0);
    }
    
    return math.min(1.0, confidence);
  }
  
  void _generateContextualPredictions(String context, Map<String, dynamic> metadata) {
    Timer(const Duration(milliseconds: 500), () async {
      await triggerPreloading(context: context, hints: metadata);
    });
  }
  
  void _schedulePreload(PredictionResult prediction) {
    if (_preloadQueue.length >= _maxPreloadQueueSize) {
      return; // Queue is full
    }
    
    if (!_preloadQueue.contains(prediction.key) && 
        !_preloadedKeys.contains(prediction.key)) {
      _preloadQueue.add(prediction.key);
    }
  }
  
  Future<void> _processPreloadQueue() async {
    if (_preloadQueue.isEmpty || _activeTasks.length >= _maxPreloadConcurrency) {
      return;
    }
    
    final keysToProcess = _preloadQueue
        .take(_maxPreloadConcurrency - _activeTasks.length)
        .toList();
    
    for (final key in keysToProcess) {
      _preloadQueue.remove(key);
      
      final task = _PreloadTask(
        key: key,
        startTime: DateTime.now(),
      );
      
      _activeTasks[key] = task;
      
      // Execute preload task
      _executePreloadTask(key).then((_) {
        _activeTasks.remove(key);
        _backgroundTasksCompleted++;
      }).catchError((error) {
        _activeTasks.remove(key);
        debugPrint('PredictiveCache: Preload failed for $key: $error');
      });
    }
  }
  
  Future<void> _executePreloadTask(String key) async {
    // Check if key exists in cache
    final exists = await _cacheManager.contains(key);
    
    if (!exists) {
      // This would typically trigger loading from the original data source
      // For now, we just mark it as preloaded
      _preloadedKeys.add(key);
      debugPrint('PredictiveCache: Preloaded key: $key');
    }
  }
  
  /// Dispose predictive cache
  Future<void> dispose() async {
    _preloadTimer?.cancel();
    _patternAnalysisTimer?.cancel();
    
    await _cacheManager.dispose();
    _metrics.dispose();
    
    clearPatterns();
    
    debugPrint('PredictiveCache: Disposed');
  }
}

// Data classes for pattern tracking

class _AccessEvent {
  final String key;
  final DateTime timestamp;
  final String? context;
  final Map<String, dynamic> metadata;
  
  _AccessEvent({
    required this.key,
    required this.timestamp,
    this.context,
    required this.metadata,
  });
}

class _UserPattern {
  final String key;
  int totalAccesses = 0;
  DateTime? lastAccess;
  DateTime? firstAccess;
  
  // Time-based patterns
  final Map<int, int> hourlyPatterns = {}; // hour -> count
  final Map<int, int> dailyPatterns = {}; // day of week -> count
  final Queue<int> accessIntervals = Queue(); // minutes between accesses
  double? averageInterval;
  int? peakHour;
  
  // Sequential patterns
  final Map<String, int> sequentialPatterns = {}; // next key -> frequency
  
  // Prediction confidence
  double regularityScore = 0.0;
  double timePredictionConfidence = 0.0;
  
  _UserPattern({required this.key});
  
  void addAccess(DateTime timestamp) {
    firstAccess ??= timestamp;
    lastAccess = timestamp;
  }
  
  void updateMetadata(Map<String, dynamic> metadata) {
    // Update pattern based on metadata
  }
}

class _ContextPattern {
  final String context;
  int totalAccesses = 0;
  
  // Key usage patterns
  final Map<String, int> keyFrequencies = {}; // key -> count
  final Map<String, double> keyProbabilities = {}; // key -> probability
  
  // Co-occurrence patterns
  Map<String, Map<String, int>> coOccurrences = {}; // key -> {next_key -> count}
  
  _ContextPattern({required this.context});
  
  void addAccess(String key, DateTime timestamp) {
    // Record access for this context
  }
}

class _PreloadTask {
  final String key;
  final DateTime startTime;
  
  _PreloadTask({
    required this.key,
    required this.startTime,
  });
}

// Public API classes

class PredictionResult {
  final String key;
  final double confidence;
  final String reason;
  final PredictionType type;
  final DateTime? estimatedAccessTime;
  
  const PredictionResult({
    required this.key,
    required this.confidence,
    required this.reason,
    required this.type,
    this.estimatedAccessTime,
  });
  
  @override
  String toString() {
    return 'PredictionResult(key: $key, confidence: ${(confidence * 100).toStringAsFixed(1)}%, reason: $reason)';
  }
}

enum PredictionType {
  timeBased,
  sequenceBased,
  contextBased,
  frequencyBased,
}

class PredictiveCacheStats {
  final int userPatterns;
  final int contextPatterns;
  final int accessHistorySize;
  final int predictionsGenerated;
  final int preloadHits;
  final int preloadMisses;
  final int preloadQueueSize;
  final int activePreloadTasks;
  final int backgroundTasksCompleted;
  final double predictionAccuracy;
  final CacheStats managerStats;
  
  const PredictiveCacheStats({
    required this.userPatterns,
    required this.contextPatterns,
    required this.accessHistorySize,
    required this.predictionsGenerated,
    required this.preloadHits,
    required this.preloadMisses,
    required this.preloadQueueSize,
    required this.activePreloadTasks,
    required this.backgroundTasksCompleted,
    required this.predictionAccuracy,
    required this.managerStats,
  });
  
  @override
  String toString() {
    return 'PredictiveCacheStats('
           'patterns: $userPatterns/$contextPatterns, '
           'predictions: $predictionsGenerated, '
           'accuracy: ${(predictionAccuracy * 100).toStringAsFixed(1)}%, '
           'queue: $preloadQueueSize, '
           'active: $activePreloadTasks)';
  }
}