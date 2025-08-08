import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import 'cache_manager.dart' hide CacheLevel;
import 'cache_policy.dart';
import 'cache_key_generator.dart';
import 'cache_metrics.dart';

/// Specialized cache for AI analysis results and suggestions
/// 
/// Features:
/// - Context-aware caching for similar scenarios
/// - Intelligent suggestion grouping and retrieval
/// - Progressive result caching for partial AI processing
/// - Confidence-based cache retention policies
/// - Smart invalidation on model updates
class AIResultsCache {
  final CacheManager _cacheManager;
  final AICacheKeyGenerator _keyGenerator;
  final CacheMetrics _metrics;
  
  // AI-specific cache policies
  static final CachePolicy _sceneAnalysisPolicy = CachePolicy.aiOptimized().copyWith(
    defaultTtl: const Duration(hours: 4), // Scene analysis can be cached longer
    useMemoryCache: true,
    useDiskCache: true,
  );
  
  static final CachePolicy _suggestionsPolicy = CachePolicy.aiOptimized().copyWith(
    defaultTtl: const Duration(hours: 1), // Suggestions may change more frequently
    useMemoryCache: true,
    useDiskCache: false, // Keep suggestions in memory for faster access
  );
  
  static final CachePolicy _modelResultsPolicy = CachePolicy.aiOptimized().copyWith(
    defaultTtl: const Duration(minutes: 30), // Model results are more volatile
    useMemoryCache: true,
    useDiskCache: true,
    compressData: false, // Preserve model output precision
  );
  
  // Performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _partialHits = 0;
  int _invalidations = 0;
  
  // Context tracking for similarity detection
  final Map<String, _AIContextMetadata> _contextMap = {};
  
  AIResultsCache({
    CacheManager? cacheManager,
  })  : _cacheManager = cacheManager ?? CacheManager.named('ai_results'),
        _keyGenerator = AICacheKeyGenerator(),
        _metrics = CacheMetrics();
  
  /// Initialize the AI results cache
  Future<void> initialize() async {
    await _cacheManager.initialize();
    debugPrint('AIResultsCache: Initialized successfully');
  }
  
  /// Cache scene analysis results with content-based key
  Future<void> cacheSceneAnalysis({
    required Uint8List imageData,
    required SceneAnalysis analysis,
    String? modelVersion,
  }) async {
    final key = _keyGenerator.sceneAnalysisKey(imageData, modelVersion ?? '1.0');
    
    // Store analysis with metadata
    final cacheData = {
      'analysis': _sceneAnalysisToJson(analysis),
      'confidence': analysis.confidence ?? 0.8,
      'modelVersion': modelVersion ?? '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'imageHash': _keyGenerator.generateContentKey(imageData, algorithm: ContentHashAlgorithm.sha256),
    };
    
    await _cacheManager.put(
      key,
      cacheData,
      policy: _sceneAnalysisPolicy,
      toJson: (data) => data as Map<String, dynamic>,
    );
    
    // Update context tracking
    _updateContextMap(key, analysis);
    
    debugPrint('AIResultsCache: Cached scene analysis for key: $key');
  }
  
  /// Retrieve cached scene analysis
  Future<SceneAnalysis?> getSceneAnalysis({
    required Uint8List imageData,
    String? modelVersion,
  }) async {
    final key = _keyGenerator.sceneAnalysisKey(imageData, modelVersion ?? '1.0');
    
    final cacheData = await _cacheManager.get<Map<String, dynamic>>(
      key,
      fromJson: (json) => json,
    );
    
    if (cacheData != null) {
      _cacheHits++;
      _metrics.recordHit(CacheLevel.memory, 0); // Assume memory hit for metrics
      
      final analysis = _sceneAnalysisFromJson(cacheData['analysis']);
      debugPrint('AIResultsCache: Retrieved scene analysis from cache');
      return analysis;
    }
    
    _cacheMisses++;
    _metrics.recordMiss(0);
    return null;
  }
  
  /// Cache AI suggestions with context awareness
  Future<void> cacheAISuggestions({
    required String sceneKey,
    required List<AISuggestion> suggestions,
    required Map<String, dynamic> context,
    double confidence = 0.8,
  }) async {
    final key = _keyGenerator.suggestionsKey(sceneKey, context);
    
    final cacheData = {
      'suggestions': suggestions.map(_suggestionToJson).toList(),
      'context': context,
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
      'sceneKey': sceneKey,
    };
    
    await _cacheManager.put(
      key,
      cacheData,
      policy: _suggestionsPolicy,
      toJson: (data) => data as Map<String, dynamic>,
    );
    
    // Also cache individual suggestions for partial matching
    await _cacheIndividualSuggestions(suggestions, context);
    
    debugPrint('AIResultsCache: Cached ${suggestions.length} AI suggestions');
  }
  
  /// Retrieve cached AI suggestions
  Future<List<AISuggestion>?> getAISuggestions({
    required String sceneKey,
    required Map<String, dynamic> context,
  }) async {
    final key = _keyGenerator.suggestionsKey(sceneKey, context);
    
    final cacheData = await _cacheManager.get<Map<String, dynamic>>(
      key,
      fromJson: (json) => json,
    );
    
    if (cacheData != null) {
      _cacheHits++;
      
      final suggestions = (cacheData['suggestions'] as List)
          .map((s) => _suggestionFromJson(s))
          .toList();
      
      debugPrint('AIResultsCache: Retrieved ${suggestions.length} suggestions from cache');
      return suggestions;
    }
    
    // Try partial matching for similar contexts
    final partialSuggestions = await _findSimilarSuggestions(sceneKey, context);
    if (partialSuggestions.isNotEmpty) {
      _partialHits++;
      debugPrint('AIResultsCache: Found ${partialSuggestions.length} similar suggestions');
      return partialSuggestions;
    }
    
    _cacheMisses++;
    return null;
  }
  
  /// Cache model inference results
  Future<void> cacheModelInference({
    required String modelId,
    required Uint8List inputData,
    required Map<String, dynamic> parameters,
    required Map<String, dynamic> results,
    double confidence = 0.8,
  }) async {
    final key = _keyGenerator.inferenceKey(modelId, inputData, parameters);
    
    final cacheData = {
      'results': results,
      'parameters': parameters,
      'confidence': confidence,
      'modelId': modelId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Use different TTL based on confidence
    final policy = confidence > 0.9 
        ? _modelResultsPolicy.copyWith(defaultTtl: const Duration(hours: 2))
        : _modelResultsPolicy;
    
    await _cacheManager.put(
      key,
      cacheData,
      policy: policy,
      toJson: (data) => data as Map<String, dynamic>,
    );
    
    debugPrint('AIResultsCache: Cached model inference for $modelId');
  }
  
  /// Retrieve cached model inference results
  Future<Map<String, dynamic>?> getModelInference({
    required String modelId,
    required Uint8List inputData,
    required Map<String, dynamic> parameters,
  }) async {
    final key = _keyGenerator.inferenceKey(modelId, inputData, parameters);
    
    final cacheData = await _cacheManager.get<Map<String, dynamic>>(
      key,
      fromJson: (json) => json,
    );
    
    if (cacheData != null) {
      _cacheHits++;
      debugPrint('AIResultsCache: Retrieved model inference from cache');
      return cacheData['results'] as Map<String, dynamic>;
    }
    
    _cacheMisses++;
    return null;
  }
  
  /// Cache progressive AI analysis results
  Future<void> cacheProgressiveAnalysis({
    required String baseKey,
    required String stage,
    required Map<String, dynamic> partialResults,
    bool isFinal = false,
  }) async {
    final key = '${baseKey}_stage_$stage';
    
    final cacheData = {
      'partialResults': partialResults,
      'stage': stage,
      'isFinal': isFinal,
      'baseKey': baseKey,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Shorter TTL for intermediate results
    final policy = isFinal 
        ? _modelResultsPolicy 
        : _modelResultsPolicy.copyWith(defaultTtl: const Duration(minutes: 10));
    
    await _cacheManager.put(
      key,
      cacheData,
      policy: policy,
      toJson: (data) => data as Map<String, dynamic>,
    );
  }
  
  /// Retrieve progressive analysis results
  Future<Map<String, dynamic>?> getProgressiveAnalysis({
    required String baseKey,
    required String stage,
  }) async {
    final key = '${baseKey}_stage_$stage';
    
    final cacheData = await _cacheManager.get<Map<String, dynamic>>(
      key,
      fromJson: (json) => json,
    );
    
    return cacheData?['partialResults'] as Map<String, dynamic>?;
  }
  
  /// Get all cached stages for progressive analysis
  Future<List<String>> getAvailableStages(String baseKey) async {
    final pattern = '${baseKey}_stage_.*';
    final allKeys = await _getAllCacheKeys();
    
    return allKeys
        .where((key) => RegExp(pattern).hasMatch(key))
        .map((key) => key.split('_stage_').last)
        .toList();
  }
  
  /// Invalidate cache entries based on model version changes
  Future<void> invalidateModelResults(String modelId, [String? version]) async {
    final pattern = version != null 
        ? 'ai_results:inference:.*_$modelId.*_v$version.*'
        : 'ai_results:inference:.*_$modelId.*';
    
    await _cacheManager.clear(pattern);
    _invalidations++;
    
    debugPrint('AIResultsCache: Invalidated cache for model $modelId');
  }
  
  /// Invalidate all AI suggestions for similar scenes
  Future<void> invalidateSimilarScenes(String sceneType) async {
    final pattern = 'ai_results:suggestions:.*scene.*$sceneType.*';
    await _cacheManager.clear(pattern);
    _invalidations++;
  }
  
  /// Get cache statistics specific to AI results
  AIResultsCacheStats getStats() {
    final managerStats = _cacheManager.getStats();
    
    return AIResultsCacheStats(
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      partialHits: _partialHits,
      invalidations: _invalidations,
      hitRate: (_cacheHits + _cacheMisses) > 0 
          ? _cacheHits / (_cacheHits + _cacheMisses) 
          : 0.0,
      partialHitRate: (_cacheHits + _cacheMisses) > 0 
          ? _partialHits / (_cacheHits + _cacheMisses) 
          : 0.0,
      contextMappings: _contextMap.length,
      managerStats: managerStats,
    );
  }
  
  /// Warm cache with common AI scenarios
  Future<void> warmCache(List<AIWarmupEntry> entries) async {
    final warmupEntries = entries
        .map((entry) => CacheWarmupEntry(
          key: entry.key,
          dataProvider: entry.dataProvider,
          policy: entry.policy ?? _sceneAnalysisPolicy,
        ))
        .toList();
    
    await _cacheManager.warmCache(warmupEntries);
    debugPrint('AIResultsCache: Warmed cache with ${entries.length} entries');
  }
  
  /// Preload AI results based on usage patterns
  Future<void> preloadPredictive({
    required List<String> likelySceneTypes,
    required Map<String, dynamic> userContext,
  }) async {
    final predictiveKeys = <String>[];
    
    // Generate keys for likely scenarios
    for (final sceneType in likelySceneTypes) {
      final contextVariations = _generateContextVariations(sceneType, userContext);
      for (final context in contextVariations) {
        final key = _keyGenerator.suggestionsKey(sceneType, context);
        predictiveKeys.add(key);
      }
    }
    
    await _cacheManager.preloadPredictive(predictiveKeys);
    debugPrint('AIResultsCache: Preloaded ${predictiveKeys.length} predictive keys');
  }
  
  // Private helper methods
  
  Future<void> _cacheIndividualSuggestions(
    List<AISuggestion> suggestions,
    Map<String, dynamic> context,
  ) async {
    for (final suggestion in suggestions) {
      final key = 'suggestion_${suggestion.id}';
      await _cacheManager.put(
        key,
        _suggestionToJson(suggestion),
        policy: _suggestionsPolicy.copyWith(defaultTtl: const Duration(minutes: 30)),
        toJson: (data) => data,
      );
    }
  }
  
  Future<List<AISuggestion>> _findSimilarSuggestions(
    String sceneKey,
    Map<String, dynamic> context,
  ) async {
    final similarSuggestions = <AISuggestion>[];
    
    // Find contexts with similar characteristics
    for (final entry in _contextMap.entries) {
      if (entry.value.sceneType == _extractSceneType(sceneKey)) {
        final similarity = _calculateContextSimilarity(context, entry.value.context);
        
        if (similarity > 0.7) { // 70% similarity threshold
          final suggestions = await getAISuggestions(
            sceneKey: entry.key,
            context: entry.value.context,
          );
          
          if (suggestions != null) {
            // Adjust confidence based on similarity
            final adjustedSuggestions = suggestions
                .map((s) => AISuggestion(
                  id: s.id,
                  type: s.type,
                  category: s.category,
                  title: s.title,
                  message: s.message,
                  icon: s.icon,
                  priority: s.priority * similarity, // Reduce priority by similarity
                  confidence: s.confidence * similarity, // Reduce confidence
                  actionable: s.actionable,
                  action: s.action,
                  visual: s.visual,
                  explanation: s.explanation,
                ))
                .toList();
            
            similarSuggestions.addAll(adjustedSuggestions);
          }
        }
      }
    }
    
    return similarSuggestions;
  }
  
  void _updateContextMap(String key, SceneAnalysis analysis) {
    _contextMap[key] = _AIContextMetadata(
      sceneType: analysis.sceneType,
      context: {
        'lightingCondition': analysis.lightingCondition,
        'brightness': analysis.brightness,
        'contrast': analysis.contrast,
        'colorTemperature': analysis.colorTemperature,
        'movementDetected': analysis.movementDetected,
      },
      timestamp: DateTime.now(),
    );
    
    // Limit context map size
    if (_contextMap.length > 1000) {
      final oldestKey = _contextMap.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _contextMap.remove(oldestKey);
    }
  }
  
  String _extractSceneType(String sceneKey) {
    // Extract scene type from scene key (implementation depends on key format)
    return sceneKey.split('_').first;
  }
  
  double _calculateContextSimilarity(
    Map<String, dynamic> context1,
    Map<String, dynamic> context2,
  ) {
    double similarity = 0.0;
    int comparisons = 0;
    
    for (final key in context1.keys) {
      if (context2.containsKey(key)) {
        final value1 = context1[key];
        final value2 = context2[key];
        
        if (value1.runtimeType == value2.runtimeType) {
          if (value1 is num && value2 is num) {
            final diff = (value1 - value2).abs() / math.max(value1.abs(), value2.abs());
            similarity += 1.0 - math.min(diff, 1.0);
          } else if (value1 == value2) {
            similarity += 1.0;
          }
          comparisons++;
        }
      }
    }
    
    return comparisons > 0 ? similarity / comparisons : 0.0;
  }
  
  List<Map<String, dynamic>> _generateContextVariations(
    String sceneType,
    Map<String, dynamic> userContext,
  ) {
    // Generate variations of context for predictive caching
    final variations = <Map<String, dynamic>>[];
    
    // Base context
    variations.add(Map.from(userContext));
    
    // Lighting variations
    if (userContext.containsKey('lightingCondition')) {
      for (final lighting in ['low', 'normal', 'bright']) {
        final variation = Map<String, dynamic>.from(userContext);
        variation['lightingCondition'] = lighting;
        variations.add(variation);
      }
    }
    
    // Time-based variations
    final timeVariations = ['morning', 'afternoon', 'evening', 'night'];
    for (final time in timeVariations) {
      final variation = Map<String, dynamic>.from(userContext);
      variation['timeOfDay'] = time;
      variations.add(variation);
    }
    
    return variations.take(10).toList(); // Limit variations
  }
  
  Future<List<String>> _getAllCacheKeys() async {
    // This would need to be implemented by the cache manager
    // For now, return empty list
    return [];
  }
  
  // JSON serialization helpers
  
  Map<String, dynamic> _sceneAnalysisToJson(SceneAnalysis analysis) {
    return {
      'sceneType': analysis.sceneType,
      'lightingCondition': analysis.lightingCondition,
      'subjectDistance': analysis.subjectDistance,
      'movementDetected': analysis.movementDetected,
      'brightness': analysis.brightness,
      'contrast': analysis.contrast,
      'colorTemperature': analysis.colorTemperature,
      'dominantColors': analysis.dominantColors,
      'faces': analysis.faces,
      'motion': analysis.motion,
      'focusDistance': analysis.focusDistance,
      'exposureBias': analysis.exposureBias,
      'confidence': analysis.confidence,
    };
  }
  
  SceneAnalysis _sceneAnalysisFromJson(Map<String, dynamic> json) {
    return SceneAnalysis(
      sceneType: json['sceneType'] as String,
      lightingCondition: json['lightingCondition'] as String,
      subjectDistance: json['subjectDistance'] as String,
      movementDetected: json['movementDetected'] as bool,
      brightness: json['brightness'] as double?,
      contrast: json['contrast'] as double?,
      colorTemperature: json['colorTemperature'] as int?,
      dominantColors: (json['dominantColors'] as List?)?.cast<int>() ?? [],
      faces: (json['faces'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      motion: json['motion'] as double?,
      focusDistance: json['focusDistance'] as double?,
      exposureBias: json['exposureBias'] as double?,
    );
  }
  
  Map<String, dynamic> _suggestionToJson(AISuggestion suggestion) {
    return {
      'id': suggestion.id,
      'type': suggestion.type.toString(),
      'category': suggestion.category.toString(),
      'title': suggestion.title,
      'message': suggestion.message,
      'icon': suggestion.icon,
      'priority': suggestion.priority,
      'confidence': suggestion.confidence,
      'actionable': suggestion.actionable,
      'action': suggestion.action?.toJson(),
      'visual': suggestion.visual?.toJson(),
      'explanation': suggestion.explanation,
    };
  }
  
  AISuggestion _suggestionFromJson(Map<String, dynamic> json) {
    return AISuggestion(
      id: json['id'] as String,
      type: AISuggestionType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => AISuggestionType.cameraSettings,
      ),
      category: AISuggestionCategory.values.firstWhere(
        (c) => c.toString() == json['category'],
        orElse: () => AISuggestionCategory.iso,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      icon: json['icon'] as String,
      priority: json['priority'] as double,
      confidence: json['confidence'] as double,
      actionable: json['actionable'] as bool,
      action: json['action'] != null 
          ? SuggestionAction.fromJson(json['action'])
          : null,
      visual: json['visual'] != null 
          ? SuggestionVisual.fromJson(json['visual'])
          : null,
      explanation: json['explanation'] as String?,
    );
  }
  
  /// Dispose AI results cache
  Future<void> dispose() async {
    await _cacheManager.dispose();
    _metrics.dispose();
    _contextMap.clear();
    debugPrint('AIResultsCache: Disposed');
  }
}

// Helper classes

class _AIContextMetadata {
  final String sceneType;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  
  _AIContextMetadata({
    required this.sceneType,
    required this.context,
    required this.timestamp,
  });
}

/// AI cache warmup entry
class AIWarmupEntry {
  final String key;
  final Future<dynamic> Function()? dataProvider;
  final CachePolicy? policy;
  
  const AIWarmupEntry({
    required this.key,
    this.dataProvider,
    this.policy,
  });
}

/// AI results cache statistics
class AIResultsCacheStats {
  final int cacheHits;
  final int cacheMisses;
  final int partialHits;
  final int invalidations;
  final double hitRate;
  final double partialHitRate;
  final int contextMappings;
  final CacheStats managerStats;
  
  const AIResultsCacheStats({
    required this.cacheHits,
    required this.cacheMisses,
    required this.partialHits,
    required this.invalidations,
    required this.hitRate,
    required this.partialHitRate,
    required this.contextMappings,
    required this.managerStats,
  });
  
  @override
  String toString() {
    return 'AIResultsCacheStats('
           'hits: $cacheHits, '
           'misses: $cacheMisses, '
           'partial: $partialHits, '
           'hit_rate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'context_mappings: $contextMappings)';
  }
}

// Math library imported at top for similarity calculations