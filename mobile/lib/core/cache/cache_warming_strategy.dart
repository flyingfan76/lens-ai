import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'cache_manager.dart';
import 'cache_policy.dart';
import 'cache_metrics.dart';

/// Intelligent cache warming strategies for optimal app startup performance
/// 
/// Features:
/// - Progressive warming to avoid blocking app startup
/// - Priority-based warming for critical data first
/// - Background warming with resource management
/// - Adaptive warming based on usage patterns
/// - Platform-specific optimization strategies
/// - Performance monitoring and optimization
class CacheWarmingStrategy {
  final CacheManager _cacheManager;
  final CacheMetrics _metrics;
  
  // Warming configuration
  final Duration _maxWarmupTime;
  final int _maxConcurrentWarmups;
  
  // Warming state
  final Map<String, _WarmingTask> _activeTasks = {};
  final Queue<WarmingEntry> _warmingQueue = Queue();
  bool _isWarming = false;
  Timer? _warmingTimer;
  
  // Performance tracking
  int _itemsWarmed = 0;
  int _warmingFailures = 0;
  Duration _totalWarmingTime = Duration.zero;
  final Map<WarmingPriority, int> _priorityStats = {};
  
  // Resource monitoring
  Timer? _resourceMonitorTimer;
  bool _resourcesAvailable = true;
  
  CacheWarmingStrategy({
    required CacheManager cacheManager,
    Duration maxWarmupTime = const Duration(seconds: 30),
    int maxConcurrentWarmups = 3,
  })  : _cacheManager = cacheManager,
        _metrics = CacheMetrics(),
        _maxWarmupTime = maxWarmupTime,
        _maxConcurrentWarmups = maxConcurrentWarmups;
  
  /// Initialize cache warming system
  Future<void> initialize() async {
    await _cacheManager.initialize();
    _startResourceMonitoring();
    debugPrint('CacheWarmingStrategy: Initialized with intelligent warming');
  }
  
  /// Execute app startup cache warming
  Future<void> warmAppStartup({
    required AppStartupContext context,
    Duration? timeout,
  }) async {
    final startTime = DateTime.now();
    final effectiveTimeout = timeout ?? _maxWarmupTime;
    
    debugPrint('CacheWarmingStrategy: Starting app startup warming');
    
    try {
      // Phase 1: Critical data (blocking)
      await _warmCriticalData(context);
      
      // Phase 2: High priority data (background)
      _warmHighPriorityData(context);
      
      // Phase 3: Normal priority data (background, resource-aware)
      _warmNormalPriorityData(context);
      
      // Phase 4: Low priority data (background, idle-time only)
      _warmLowPriorityData(context);
      
    } catch (e) {
      debugPrint('CacheWarmingStrategy: Startup warming failed: $e');
    }
    
    final duration = DateTime.now().difference(startTime);
    _totalWarmingTime = _totalWarmingTime + duration;
    
    debugPrint('CacheWarmingStrategy: Startup warming completed in ${duration.inMilliseconds}ms');
  }
  
  /// Warm cache for specific user context
  Future<void> warmForContext({
    required String context,
    required ContextWarmingProfile profile,
    bool background = true,
  }) async {
    final entries = _generateContextEntries(context, profile);
    
    if (background) {
      _scheduleBackgroundWarming(entries);
    } else {
      await _executeWarmingBatch(entries);
    }
    
    debugPrint('CacheWarmingStrategy: Warming ${entries.length} items for context: $context');
  }
  
  /// Warm cache based on usage patterns
  Future<void> warmFromPatterns({
    required List<UsagePattern> patterns,
    int maxItems = 50,
  }) async {
    final entries = _generatePatternBasedEntries(patterns, maxItems);
    _scheduleBackgroundWarming(entries);
    
    debugPrint('CacheWarmingStrategy: Warming ${entries.length} items from usage patterns');
  }
  
  /// Warm cache with predictive preloading
  Future<void> warmPredictive({
    required PredictiveWarmingContext context,
    double confidenceThreshold = 0.6,
  }) async {
    final predictions = await _generatePredictions(context);
    final highConfidencePredictions = predictions
        .where((p) => p.confidence >= confidenceThreshold)
        .toList();
    
    final entries = highConfidencePredictions
        .map((p) => WarmingEntry(
          key: p.key,
          priority: _confidenceToPriority(p.confidence),
          dataProvider: p.dataProvider,
          estimatedSize: p.estimatedSize,
          policy: p.policy,
        ))
        .toList();
    
    _scheduleBackgroundWarming(entries);
    
    debugPrint('CacheWarmingStrategy: Warming ${entries.length} predictive items');
  }
  
  /// Warm frequently accessed items
  Future<void> warmFrequentItems({
    required Map<String, int> accessCounts,
    int topN = 20,
  }) async {
    final sortedItems = accessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topItems = sortedItems.take(topN);
    final entries = topItems
        .map((item) => WarmingEntry(
          key: item.key,
          priority: WarmingPriority.high,
          estimatedSize: 1024, // Default size
        ))
        .toList();
    
    await _executeWarmingBatch(entries);
    
    debugPrint('CacheWarmingStrategy: Warmed ${entries.length} frequent items');
  }
  
  /// Progressive warming with user feedback
  Future<void> progressiveWarm({
    required List<ProgressiveWarmingStage> stages,
    Function(ProgressiveWarmingProgress)? onProgress,
  }) async {
    final totalItems = stages.fold<int>(0, (sum, stage) => sum + stage.entries.length);
    int completedItems = 0;
    
    for (int i = 0; i < stages.length; i++) {
      final stage = stages[i];
      
      onProgress?.call(ProgressiveWarmingProgress(
        currentStage: i,
        totalStages: stages.length,
        stageProgress: 0.0,
        overallProgress: completedItems / totalItems,
        stageName: stage.name,
      ));
      
      // Execute stage with resource monitoring
      await _executeStage(stage, (stageProgress) {
        onProgress?.call(ProgressiveWarmingProgress(
          currentStage: i,
          totalStages: stages.length,
          stageProgress: stageProgress,
          overallProgress: (completedItems + (stage.entries.length * stageProgress)) / totalItems,
          stageName: stage.name,
        ));
      });
      
      completedItems += stage.entries.length;
      
      // Wait between stages if needed
      if (stage.waitBetweenStages && i < stages.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    onProgress?.call(ProgressiveWarmingProgress(
      currentStage: stages.length,
      totalStages: stages.length,
      stageProgress: 1.0,
      overallProgress: 1.0,
      stageName: 'Complete',
    ));
  }
  
  /// Get warming statistics
  CacheWarmingStats getStats() {
    return CacheWarmingStats(
      itemsWarmed: _itemsWarmed,
      warmingFailures: _warmingFailures,
      totalWarmingTime: _totalWarmingTime,
      activeWarmingTasks: _activeTasks.length,
      queuedWarmingTasks: _warmingQueue.length,
      priorityStats: Map.from(_priorityStats),
      averageWarmingTime: _itemsWarmed > 0 
          ? _totalWarmingTime.inMilliseconds / _itemsWarmed 
          : 0.0,
      successRate: _itemsWarmed + _warmingFailures > 0 
          ? _itemsWarmed / (_itemsWarmed + _warmingFailures) 
          : 0.0,
    );
  }
  
  /// Cancel ongoing warming operations
  Future<void> cancelWarming() async {
    _isWarming = false;
    _warmingTimer?.cancel();
    
    // Cancel active tasks
    for (final task in _activeTasks.values) {
      task.cancel();
    }
    _activeTasks.clear();
    _warmingQueue.clear();
    
    debugPrint('CacheWarmingStrategy: Warming operations cancelled');
  }
  
  // Private implementation methods
  
  Future<void> _warmCriticalData(AppStartupContext context) async {
    final criticalEntries = [
      // User preferences
      WarmingEntry(
        key: 'user_preferences_${context.userId}',
        priority: WarmingPriority.critical,
        dataProvider: () => _loadUserPreferences(context.userId),
      ),
      
      // App configuration
      WarmingEntry(
        key: 'app_config_${context.appVersion}',
        priority: WarmingPriority.critical,
        dataProvider: () => _loadAppConfiguration(context.appVersion),
      ),
      
      // Essential AI models
      WarmingEntry(
        key: 'ai_model_essential',
        priority: WarmingPriority.critical,
        dataProvider: () => _loadEssentialAIModel(),
        estimatedSize: 10 * 1024 * 1024, // 10MB
      ),
    ];
    
    await _executeWarmingBatch(criticalEntries);
  }
  
  void _warmHighPriorityData(AppStartupContext context) {
    final entries = [
      // Recent photos thumbnails
      WarmingEntry(
        key: 'recent_thumbnails',
        priority: WarmingPriority.high,
        dataProvider: () => _loadRecentThumbnails(context.userId),
        estimatedSize: 5 * 1024 * 1024, // 5MB
      ),
      
      // Frequent camera settings
      WarmingEntry(
        key: 'frequent_camera_settings',
        priority: WarmingPriority.high,
        dataProvider: () => _loadFrequentCameraSettings(context.userId),
      ),
      
      // Common AI suggestions
      WarmingEntry(
        key: 'common_ai_suggestions',
        priority: WarmingPriority.high,
        dataProvider: () => _loadCommonAISuggestions(),
        estimatedSize: 2 * 1024 * 1024, // 2MB
      ),
    ];
    
    _scheduleBackgroundWarming(entries);
  }
  
  void _warmNormalPriorityData(AppStartupContext context) {
    final entries = [
      // Scene analysis cache
      WarmingEntry(
        key: 'scene_analysis_cache',
        priority: WarmingPriority.normal,
        dataProvider: () => _loadSceneAnalysisCache(),
        estimatedSize: 15 * 1024 * 1024, // 15MB
      ),
      
      // Style presets
      WarmingEntry(
        key: 'style_presets',
        priority: WarmingPriority.normal,
        dataProvider: () => _loadStylePresets(),
      ),
    ];
    
    _scheduleBackgroundWarming(entries);
  }
  
  void _warmLowPriorityData(AppStartupContext context) {
    final entries = [
      // Full image processing cache
      WarmingEntry(
        key: 'image_processing_cache',
        priority: WarmingPriority.low,
        dataProvider: () => _loadImageProcessingCache(),
        estimatedSize: 50 * 1024 * 1024, // 50MB
      ),
      
      // Historical analytics
      WarmingEntry(
        key: 'historical_analytics',
        priority: WarmingPriority.low,
        dataProvider: () => _loadHistoricalAnalytics(context.userId),
      ),
    ];
    
    _scheduleBackgroundWarming(entries);
  }
  
  List<WarmingEntry> _generateContextEntries(String context, ContextWarmingProfile profile) {
    final entries = <WarmingEntry>[];
    
    // Context-specific data
    entries.add(WarmingEntry(
      key: 'context_data_$context',
      priority: profile.priority,
      dataProvider: () => _loadContextData(context),
      estimatedSize: profile.estimatedDataSize,
    ));
    
    // Related contexts
    for (final relatedContext in profile.relatedContexts) {
      entries.add(WarmingEntry(
        key: 'related_context_$relatedContext',
        priority: WarmingPriority.normal,
        dataProvider: () => _loadContextData(relatedContext),
      ));
    }
    
    return entries;
  }
  
  List<WarmingEntry> _generatePatternBasedEntries(List<UsagePattern> patterns, int maxItems) {
    final entries = <WarmingEntry>[];
    
    for (final pattern in patterns.take(maxItems)) {
      entries.add(WarmingEntry(
        key: pattern.key,
        priority: _frequencyToPriority(pattern.frequency),
        dataProvider: pattern.dataProvider,
        estimatedSize: pattern.estimatedSize,
      ));
    }
    
    return entries;
  }
  
  void _scheduleBackgroundWarming(List<WarmingEntry> entries) {
    for (final entry in entries) {
      _warmingQueue.add(entry);
    }
    
    _startBackgroundWarming();
  }
  
  void _startBackgroundWarming() {
    if (_isWarming) return;
    
    _isWarming = true;
    _warmingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _processWarmingQueue();
    });
  }
  
  Future<void> _processWarmingQueue() async {
    if (!_resourcesAvailable || _activeTasks.length >= _maxConcurrentWarmups) {
      return;
    }
    
    // Get next highest priority entry
    final entry = _getNextWarmingEntry();
    if (entry == null) {
      _stopBackgroundWarming();
      return;
    }
    
    // Execute warming task
    final task = _WarmingTask(
      entry: entry,
      startTime: DateTime.now(),
    );
    
    _activeTasks[entry.key] = task;
    
    _executeWarmingEntry(entry).then((_) {
      _activeTasks.remove(entry.key);
      _itemsWarmed++;
      _priorityStats[entry.priority] = (_priorityStats[entry.priority] ?? 0) + 1;
    }).catchError((error) {
      _activeTasks.remove(entry.key);
      _warmingFailures++;
      debugPrint('CacheWarmingStrategy: Warming failed for ${entry.key}: $error');
    });
  }
  
  WarmingEntry? _getNextWarmingEntry() {
    if (_warmingQueue.isEmpty) return null;
    
    // Sort by priority
    final sortedQueue = _warmingQueue.toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    final entry = sortedQueue.first;
    _warmingQueue.remove(entry);
    
    return entry;
  }
  
  Future<void> _executeWarmingEntry(WarmingEntry entry) async {
    if (entry.dataProvider != null) {
      final data = await entry.dataProvider!();
      
      await _cacheManager.put(
        entry.key,
        data,
        policy: entry.policy ?? CachePolicy.balanced(),
      );
    }
  }
  
  Future<void> _executeWarmingBatch(List<WarmingEntry> entries) async {
    final futures = entries.map((entry) => _executeWarmingEntry(entry));
    await Future.wait(futures, eagerError: false);
  }
  
  Future<void> _executeStage(
    ProgressiveWarmingStage stage,
    Function(double) onProgress,
  ) async {
    for (int i = 0; i < stage.entries.length; i++) {
      if (!_resourcesAvailable && stage.respectResourceLimits) {
        await _waitForResources();
      }
      
      await _executeWarmingEntry(stage.entries[i]);
      
      final progress = (i + 1) / stage.entries.length;
      onProgress(progress);
      
      // Small delay between items to avoid overwhelming the system
      if (i < stage.entries.length - 1) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }
  
  void _startResourceMonitoring() {
    _resourceMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkResourceAvailability();
    });
  }
  
  void _checkResourceAvailability() {
    // Simplified resource check - in production, use platform-specific APIs
    _resourcesAvailable = true; // Assume resources are available for now
  }
  
  Future<void> _waitForResources() async {
    while (!_resourcesAvailable) {
      await Future.delayed(const Duration(seconds: 1));
      _checkResourceAvailability();
    }
  }
  
  void _stopBackgroundWarming() {
    _isWarming = false;
    _warmingTimer?.cancel();
  }
  
  WarmingPriority _frequencyToPriority(int frequency) {
    if (frequency > 100) return WarmingPriority.high;
    if (frequency > 50) return WarmingPriority.normal;
    return WarmingPriority.low;
  }
  
  WarmingPriority _confidenceToPriority(double confidence) {
    if (confidence > 0.9) return WarmingPriority.high;
    if (confidence > 0.7) return WarmingPriority.normal;
    return WarmingPriority.low;
  }
  
  Future<List<PredictiveWarmingItem>> _generatePredictions(PredictiveWarmingContext context) async {
    // Simplified prediction generation - would use ML models in production
    return [
      PredictiveWarmingItem(
        key: 'predicted_scene_portrait',
        confidence: 0.8,
        dataProvider: () => _loadSceneData('portrait'),
        estimatedSize: 1024 * 1024,
        policy: CachePolicy.aiOptimized(),
      ),
      PredictiveWarmingItem(
        key: 'predicted_scene_landscape',
        confidence: 0.7,
        dataProvider: () => _loadSceneData('landscape'),
        estimatedSize: 1024 * 1024,
        policy: CachePolicy.aiOptimized(),
      ),
    ];
  }
  
  // Mock data loading methods (replace with actual implementations)
  
  Future<Map<String, dynamic>> _loadUserPreferences(String userId) async {
    return {'theme': 'dark', 'quality': 'high'};
  }
  
  Future<Map<String, dynamic>> _loadAppConfiguration(String version) async {
    return {'version': version, 'features': ['ai', 'cache']};
  }
  
  Future<Map<String, dynamic>> _loadEssentialAIModel() async {
    return {'model': 'essential', 'version': '1.0'};
  }
  
  Future<List<Map<String, dynamic>>> _loadRecentThumbnails(String userId) async {
    return [{'id': '1', 'thumbnail': 'data'}];
  }
  
  Future<Map<String, dynamic>> _loadFrequentCameraSettings(String userId) async {
    return {'iso': 400, 'aperture': 5.6};
  }
  
  Future<List<Map<String, dynamic>>> _loadCommonAISuggestions() async {
    return [{'type': 'iso', 'value': 800}];
  }
  
  Future<Map<String, dynamic>> _loadSceneAnalysisCache() async {
    return {'scenes': ['portrait', 'landscape']};
  }
  
  Future<List<Map<String, dynamic>>> _loadStylePresets() async {
    return [{'name': 'vivid', 'settings': {}}];
  }
  
  Future<Map<String, dynamic>> _loadImageProcessingCache() async {
    return {'cache': 'processed_images'};
  }
  
  Future<Map<String, dynamic>> _loadHistoricalAnalytics(String userId) async {
    return {'analytics': 'historical_data'};
  }
  
  Future<Map<String, dynamic>> _loadContextData(String context) async {
    return {'context': context, 'data': 'contextual_information'};
  }
  
  Future<Map<String, dynamic>> _loadSceneData(String sceneType) async {
    return {'scene': sceneType, 'analysis': 'scene_data'};
  }
  
  /// Dispose warming strategy
  Future<void> dispose() async {
    await cancelWarming();
    _resourceMonitorTimer?.cancel();
    _metrics.dispose();
    debugPrint('CacheWarmingStrategy: Disposed');
  }
}

// Data classes and enums

enum WarmingPriority { 
  critical, // Must complete before app becomes interactive
  high,     // Should complete early for best UX
  normal,   // Can be done in background
  low       // Only when system is idle
}

class WarmingEntry {
  final String key;
  final WarmingPriority priority;
  final Future<dynamic> Function()? dataProvider;
  final int estimatedSize;
  final CachePolicy? policy;
  
  WarmingEntry({
    required this.key,
    required this.priority,
    this.dataProvider,
    this.estimatedSize = 1024,
    this.policy,
  });
}

class _WarmingTask {
  final WarmingEntry entry;
  final DateTime startTime;
  bool _cancelled = false;
  
  _WarmingTask({
    required this.entry,
    required this.startTime,
  });
  
  void cancel() {
    _cancelled = true;
  }
  
  bool get isCancelled => _cancelled;
}

class AppStartupContext {
  final String userId;
  final String appVersion;
  final Map<String, dynamic> userPreferences;
  final List<String> recentContexts;
  
  const AppStartupContext({
    required this.userId,
    required this.appVersion,
    this.userPreferences = const {},
    this.recentContexts = const [],
  });
}

class ContextWarmingProfile {
  final WarmingPriority priority;
  final int estimatedDataSize;
  final List<String> relatedContexts;
  final CachePolicy? policy;
  
  const ContextWarmingProfile({
    this.priority = WarmingPriority.normal,
    this.estimatedDataSize = 1024,
    this.relatedContexts = const [],
    this.policy,
  });
}

class UsagePattern {
  final String key;
  final int frequency;
  final Future<dynamic> Function()? dataProvider;
  final int estimatedSize;
  
  const UsagePattern({
    required this.key,
    required this.frequency,
    this.dataProvider,
    this.estimatedSize = 1024,
  });
}

class PredictiveWarmingContext {
  final String currentContext;
  final Map<String, dynamic> userBehavior;
  final List<String> recentAccesses;
  final DateTime timeOfDay;
  
  const PredictiveWarmingContext({
    required this.currentContext,
    this.userBehavior = const {},
    this.recentAccesses = const [],
    required this.timeOfDay,
  });
}

class PredictiveWarmingItem {
  final String key;
  final double confidence;
  final Future<dynamic> Function() dataProvider;
  final int estimatedSize;
  final CachePolicy policy;
  
  const PredictiveWarmingItem({
    required this.key,
    required this.confidence,
    required this.dataProvider,
    this.estimatedSize = 1024,
    required this.policy,
  });
}

class ProgressiveWarmingStage {
  final String name;
  final List<WarmingEntry> entries;
  final bool respectResourceLimits;
  final bool waitBetweenStages;
  
  const ProgressiveWarmingStage({
    required this.name,
    required this.entries,
    this.respectResourceLimits = true,
    this.waitBetweenStages = false,
  });
}

class ProgressiveWarmingProgress {
  final int currentStage;
  final int totalStages;
  final double stageProgress;
  final double overallProgress;
  final String stageName;
  
  const ProgressiveWarmingProgress({
    required this.currentStage,
    required this.totalStages,
    required this.stageProgress,
    required this.overallProgress,
    required this.stageName,
  });
}

class CacheWarmingStats {
  final int itemsWarmed;
  final int warmingFailures;
  final Duration totalWarmingTime;
  final int activeWarmingTasks;
  final int queuedWarmingTasks;
  final Map<WarmingPriority, int> priorityStats;
  final double averageWarmingTime;
  final double successRate;
  
  const CacheWarmingStats({
    required this.itemsWarmed,
    required this.warmingFailures,
    required this.totalWarmingTime,
    required this.activeWarmingTasks,
    required this.queuedWarmingTasks,
    required this.priorityStats,
    required this.averageWarmingTime,
    required this.successRate,
  });
  
  @override
  String toString() {
    return 'CacheWarmingStats('
           'warmed: $itemsWarmed, '
           'failures: $warmingFailures, '
           'success_rate: ${(successRate * 100).toStringAsFixed(1)}%, '
           'avg_time: ${averageWarmingTime.toStringAsFixed(1)}ms, '
           'active: $activeWarmingTasks, '
           'queued: $queuedWarmingTasks)';
  }
}

// Collection utilities imported at top