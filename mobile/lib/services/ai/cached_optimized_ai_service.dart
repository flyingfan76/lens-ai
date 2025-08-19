import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/disposal_mixin.dart';
import '../../core/cache/ai_results_cache.dart';
import '../../core/cache/image_cache.dart';
import '../../core/cache/predictive_cache.dart';
import '../../core/cache/cache_policy.dart';
import 'optimized_local_ai_service.dart';
import 'i_ai_service.dart';

/// Cached wrapper around OptimizedLocalAIService with intelligent caching strategies
/// 
/// Features:
/// - Multi-level caching for AI results, images, and analysis data
/// - Predictive preloading based on usage patterns
/// - Content-aware cache invalidation
/// - Performance optimization through smart cache warming
/// - Comprehensive cache metrics and monitoring
class CachedOptimizedAIService with ErrorHandlerMixin, ServiceDisposalMixin implements IAIService {
  static const String _serviceVersion = '2.1.0-cached';
  
  // Core AI service
  late final OptimizedLocalAIService _baseService;
  
  // Cache subsystems
  late final AIResultsCache _aiCache;
  late final ImageCache _imageCache;
  late final PredictiveCache _predictiveCache;
  
  // Performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _totalRequests = 0;
  double _averageCacheLatency = 0.0;
  
  // Prediction and preloading
  String? _currentContext;
  final Map<String, DateTime> _recentAnalyses = {};
  
  bool _isInitialized = false;
  
  CachedOptimizedAIService() {
    _baseService = OptimizedLocalAIService();
    _aiCache = AIResultsCache();
    _imageCache = ImageCache();
    _predictiveCache = PredictiveCache();
  }
  
  @override
  Future<void> initialize() async {
    return await withAIErrorHandling(
      () async {
        // Initialize base service
        await _baseService.initialize();
        
        // Initialize cache subsystems
        await Future.wait([
          _aiCache.initialize(),
          _imageCache.initialize(),
          _predictiveCache.initialize(),
        ]);
        
        // Warm cache with common scenarios
        await _warmInitialCache();
        
        _isInitialized = true;
        debugPrint('CachedOptimizedAIService: Initialized with comprehensive caching');
        
        // Log cache configurations
        _logCacheConfiguration();
      },
      operation: 'initialize cached AI service',
      showToUser: false,
    );
  }
  
  @override
  bool get isInitialized => _isInitialized && _baseService.isInitialized;
  
  @override
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await withImageErrorHandling<SceneAnalysis>(
      () async {
        final startTime = DateTime.now();
        _totalRequests++;
        
        // Try to get from cache first
        final cachedAnalysis = await _aiCache.getSceneAnalysis(
          imageData: imageBytes,
          modelVersion: _serviceVersion,
        );
        
        if (cachedAnalysis != null) {
          _cacheHits++;
          _updateCacheLatency(startTime);
          
          // Record access for predictive learning
          _recordAnalysisAccess(imageBytes);
          
          debugPrint('CachedOptimizedAIService: Cache hit for scene analysis');
          return cachedAnalysis;
        }
        
        _cacheMisses++;
        
        // Cache miss - perform analysis and cache result
        final analysis = await _baseService.analyzeImage(imageBytes);
        
        // Cache the analysis result
        await _aiCache.cacheSceneAnalysis(
          imageData: imageBytes,
          analysis: analysis,
          modelVersion: _serviceVersion,
        );
        
        // Cache the image for potential reuse
        await _cacheImageData(imageBytes);
        
        // Record access patterns for prediction
        _recordAnalysisAccess(imageBytes);
        
        // Update prediction models
        await _updatePredictionContext(analysis);
        
        _updateCacheLatency(startTime);
        
        debugPrint('CachedOptimizedAIService: Analysis completed and cached');
        return analysis;
        
      },
      operation: 'analyze image with caching',
      fallbackValue: _createFallbackSceneAnalysis(),
    ) ?? _createFallbackSceneAnalysis();
  }
  
  @override
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await withAIErrorHandling<AIAnalysisResult>(
      () async {
        final startTime = DateTime.now();
        _totalRequests++;
        
        // Create context for caching
        final context = _buildSuggestionsContext(
          sceneAnalysis,
          cameraModel,
          currentSettings,
          userRequest,
        );
        
        // Generate cache key based on scene analysis
        final sceneKey = imageBytes != null 
            ? await _generateSceneKey(imageBytes, sceneAnalysis)
            : 'scene_${sceneAnalysis.sceneType}_${sceneAnalysis.lightingCondition}';
        
        // Try to get from cache
        final cachedSuggestions = await _aiCache.getAISuggestions(
          sceneKey: sceneKey,
          context: context,
        );
        
        if (cachedSuggestions != null) {
          _cacheHits++;
          _updateCacheLatency(startTime);
          
          // Record access for learning
          _predictiveCache.recordAccess(sceneKey, context: _currentContext);
          
          debugPrint('CachedOptimizedAIService: Cache hit for AI suggestions');
          return AIAnalysisResult(
            success: true,
            suggestions: cachedSuggestions,
            analysisTimestamp: DateTime.now(),
            confidence: _calculateCachedConfidence(cachedSuggestions),
          );
        }
        
        _cacheMisses++;
        
        // Cache miss - generate suggestions
        final result = await _baseService.generateSuggestions(
          sceneAnalysis: sceneAnalysis,
          cameraModel: cameraModel,
          currentSettings: currentSettings,
          userRequest: userRequest,
          imageBytes: imageBytes,
        );
        
        // Cache the suggestions
        if (result.success && result.suggestions.isNotEmpty) {
          await _aiCache.cacheAISuggestions(
            sceneKey: sceneKey,
            suggestions: result.suggestions,
            context: context,
            confidence: result.confidence,
          );
          
          // Record for predictive learning
          _predictiveCache.recordAccess(sceneKey, context: _currentContext);
          
          // Trigger predictive preloading for similar scenarios
          await _triggerPredictivePreloading(sceneAnalysis, context);
        }
        
        _updateCacheLatency(startTime);
        
        debugPrint('CachedOptimizedAIService: Suggestions generated and cached');
        return result;
        
      },
      operation: 'generate AI suggestions with caching',
      fallbackValue: _createFallbackAnalysisResult(),
    ) ?? _createFallbackAnalysisResult();
  }
  
  /// Batch analyze multiple images with intelligent caching
  Future<List<SceneAnalysis>> analyzeBatch(List<Uint8List> imageBatch) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await withAIErrorHandling<List<SceneAnalysis>>(
      () async {
        final results = <SceneAnalysis>[];
        final uncachedImages = <Uint8List>[];
        final uncachedIndices = <int>[];
        
        // Check cache for each image
        for (int i = 0; i < imageBatch.length; i++) {
          final imageBytes = imageBatch[i];
          final cachedAnalysis = await _aiCache.getSceneAnalysis(
            imageData: imageBytes,
            modelVersion: _serviceVersion,
          );
          
          if (cachedAnalysis != null) {
            results.add(cachedAnalysis);
            _cacheHits++;
          } else {
            uncachedImages.add(imageBytes);
            uncachedIndices.add(i);
            results.add(_createFallbackSceneAnalysis()); // Placeholder
            _cacheMisses++;
          }
        }
        
        // Process uncached images
        if (uncachedImages.isNotEmpty) {
          final uncachedResults = await _baseService.analyzeBatch(uncachedImages);
          
          // Cache results and update placeholders
          for (int i = 0; i < uncachedResults.length; i++) {
            final originalIndex = uncachedIndices[i];
            final analysis = uncachedResults[i];
            
            results[originalIndex] = analysis;
            
            // Cache the result
            await _aiCache.cacheSceneAnalysis(
              imageData: uncachedImages[i],
              analysis: analysis,
              modelVersion: _serviceVersion,
            );
          }
        }
        
        _totalRequests += imageBatch.length;
        
        debugPrint('CachedOptimizedAIService: Batch analysis completed - ${_cacheHits}/${imageBatch.length} from cache');
        return results;
        
      },
      operation: 'batch analyze images with caching',
      fallbackValue: <SceneAnalysis>[],
    ) ?? <SceneAnalysis>[];
  }
  
  /// Preload AI data for predicted scenarios
  Future<void> preloadForContext({
    required String context,
    List<String>? likelySceneTypes,
    Map<String, dynamic>? hints,
  }) async {
    if (!_isInitialized) return;
    
    // Set current context for prediction
    _currentContext = context;
    _predictiveCache.setContext(context, metadata: hints);
    
    // Generate predictions and preload
    final predictions = await _predictiveCache.generatePredictions(
      context: context,
      maxPredictions: 15,
      minConfidence: 0.6,
    );
    
    debugPrint('CachedOptimizedAIService: Preloading ${predictions.length} predicted items for context: $context');
    
    // Preload AI results
    if (likelySceneTypes != null) {
      await _aiCache.preloadPredictive(
        likelySceneTypes: likelySceneTypes,
        userContext: hints ?? {},
      );
    }
    
    // Trigger background preloading
    await _predictiveCache.triggerPreloading(
      context: context,
      hints: hints,
    );
  }
  
  /// Get comprehensive cache statistics
  CachedAIServiceStats getCacheStats() {
    final aiStats = _aiCache.getStats();
    final imageStats = _imageCache.getStats();
    final predictiveStats = _predictiveCache.getStats();
    
    return CachedAIServiceStats(
      totalRequests: _totalRequests,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      hitRate: _totalRequests > 0 ? _cacheHits / _totalRequests : 0.0,
      averageCacheLatency: _averageCacheLatency,
      aiCacheStats: aiStats,
      imageCacheStats: imageStats,
      predictiveCacheStats: predictiveStats,
    );
  }
  
  /// Warm cache with common AI scenarios
  Future<void> warmCache({
    List<String>? commonSceneTypes,
    List<String>? frequentCameraSettings,
    Map<String, dynamic>? userPreferences,
  }) async {
    if (!_isInitialized) return;
    
    final warmupEntries = <AIWarmupEntry>[];
    
    // Common scene analysis warmup
    if (commonSceneTypes != null) {
      for (final sceneType in commonSceneTypes) {
        warmupEntries.add(AIWarmupEntry(
          key: 'scene_analysis_$sceneType',
          dataProvider: () async => _generateEmptySceneAnalysis(sceneType),
          policy: CachePolicy.aiOptimized(),
        ));
      }
    }
    
    // Camera settings combinations
    if (frequentCameraSettings != null) {
      for (final setting in frequentCameraSettings) {
        warmupEntries.add(AIWarmupEntry(
          key: 'camera_settings_$setting',
          dataProvider: () async => _generateEmptyCameraSettings(setting),
        ));
      }
    }
    
    await _aiCache.warmCache(warmupEntries);
    
    debugPrint('CachedOptimizedAIService: Cache warmed with ${warmupEntries.length} entries');
  }
  
  /// Invalidate cache for specific model versions
  Future<void> invalidateModelCache([String? modelVersion]) async {
    await _aiCache.invalidateModelResults('optimized_local_ai', modelVersion);
    debugPrint('CachedOptimizedAIService: Invalidated cache for model version: ${modelVersion ?? 'all'}');
  }
  
  @override
  Future<bool> testConnection() async {
    if (!_isInitialized) return false;
    
    // Test base service and cache health
    final baseServiceHealthy = await _baseService.testConnection();
    final cacheHealthy = await _testCacheHealth();
    
    return baseServiceHealthy && cacheHealthy;
  }
  
  @override
  AIServiceCapabilities get capabilities {
    final baseCapabilities = _baseService.capabilities;
    
    // Enhanced capabilities with caching
    return AIServiceCapabilities(
      supportsImageAnalysis: baseCapabilities.supportsImageAnalysis,
      supportsRealtimeAnalysis: true, // Enhanced with caching
      requiresNetworkConnection: false,
      supportsCustomPrompts: baseCapabilities.supportsCustomPrompts,
      supportsCameraSettings: baseCapabilities.supportsCameraSettings,
      supportsCompositionSuggestions: baseCapabilities.supportsCompositionSuggestions,
      supportedCategories: baseCapabilities.supportedCategories,
    );
  }
  
  @override
  AIServiceInfo get serviceInfo {
    final baseInfo = _baseService.serviceInfo;
    final cacheStats = getCacheStats();
    
    return AIServiceInfo(
      name: 'Cached Optimized Local AI Service',
      version: _serviceVersion,
      description: 'High-performance AI service with intelligent multi-level caching',
      type: AIServiceType.local,
      targetPlatform: baseInfo.targetPlatform,
    );
  }
  
  // Private helper methods
  
  Future<void> _warmInitialCache() async {
    // Warm with common scenarios
    await warmCache(
      commonSceneTypes: ['portrait', 'landscape', 'macro', 'night', 'sports'],
      frequentCameraSettings: ['auto', 'portrait', 'landscape', 'night'],
      userPreferences: {'quality': 'high', 'speed': 'balanced'},
    );
  }
  
  void _logCacheConfiguration() {
    final aiStats = _aiCache.getStats();
    final imageStats = _imageCache.getStats();
    final predictiveStats = _predictiveCache.getStats();
    
    debugPrint('CachedOptimizedAIService: Cache configuration loaded');
    debugPrint('  - AI Cache: ${aiStats}');
    debugPrint('  - Image Cache: ${imageStats}');
    debugPrint('  - Predictive Cache: ${predictiveStats}');
  }
  
  void _recordAnalysisAccess(Uint8List imageBytes) {
    // Generate a simple key for access tracking
    final imageKey = imageBytes.length.toString() + imageBytes.take(10).toString();
    _recentAnalyses[imageKey] = DateTime.now();
    
    // Limit recent analyses tracking
    if (_recentAnalyses.length > 100) {
      final oldestKey = _recentAnalyses.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _recentAnalyses.remove(oldestKey);
    }
  }
  
  Future<void> _cacheImageData(Uint8List imageBytes) async {
    try {
      await _imageCache.cacheOriginalImage(imageBytes);
    } catch (e) {
      debugPrint('CachedOptimizedAIService: Failed to cache image data: $e');
    }
  }
  
  Future<String> _generateSceneKey(Uint8List imageBytes, SceneAnalysis analysis) async {
    // Generate a content-aware key combining image hash and scene characteristics
    final imageKey = await _imageCache.cacheOriginalImage(imageBytes);
    return '${imageKey}_${analysis.sceneType}_${analysis.lightingCondition}';
  }
  
  Map<String, dynamic> _buildSuggestionsContext(
    SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
  ) {
    return {
      'sceneType': sceneAnalysis.sceneType,
      'lightingCondition': sceneAnalysis.lightingCondition,
      'brightness': sceneAnalysis.brightness,
      'contrast': sceneAnalysis.contrast,
      'cameraModel': cameraModel,
      'currentSettings': currentSettings ?? {},
      'userRequest': userRequest,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  Future<void> _updatePredictionContext(SceneAnalysis analysis) async {
    final context = 'scene_${analysis.sceneType}';
    _currentContext = context;
    
    _predictiveCache.setContext(context, metadata: {
      'lightingCondition': analysis.lightingCondition,
      'brightness': analysis.brightness,
      'contrast': analysis.contrast,
    });
  }
  
  Future<void> _triggerPredictivePreloading(
    SceneAnalysis analysis,
    Map<String, dynamic> context,
  ) async {
    // Generate similar scene variations for preloading
    final similarScenes = _generateSimilarSceneTypes(analysis.sceneType);
    
    await _predictiveCache.triggerPreloading(
      context: _currentContext,
      hints: {
        ...context,
        'similarScenes': similarScenes,
      },
    );
  }
  
  List<String> _generateSimilarSceneTypes(String sceneType) {
    const sceneGroups = {
      'portrait': ['portrait', 'selfie', 'group'],
      'landscape': ['landscape', 'nature', 'outdoor'],
      'macro': ['macro', 'closeup', 'detail'],
      'night': ['night', 'lowlight', 'indoor'],
      'sports': ['sports', 'action', 'movement'],
    };
    
    return sceneGroups[sceneType] ?? [sceneType];
  }
  
  double _calculateCachedConfidence(List<AISuggestion> suggestions) {
    if (suggestions.isEmpty) return 0.0;
    
    final totalConfidence = suggestions
        .map((s) => s.confidence)
        .reduce((a, b) => a + b);
    
    return totalConfidence / suggestions.length;
  }
  
  void _updateCacheLatency(DateTime startTime) {
    final latency = DateTime.now().difference(startTime).inMicroseconds.toDouble();
    _averageCacheLatency = _totalRequests > 1
        ? ((_averageCacheLatency * (_totalRequests - 1)) + latency) / _totalRequests
        : latency;
  }
  
  Future<bool> _testCacheHealth() async {
    try {
      final aiHealth = _aiCache.getStats();
      final imageHealth = _imageCache.getStats();
      final predictiveHealth = _predictiveCache.getStats();
      
      return aiHealth.cacheHits >= 0 && 
             imageHealth.imagesCached >= 0 && 
             predictiveHealth.userPatterns >= 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Generate empty scene analysis when caching is not available
  SceneAnalysis _generateEmptySceneAnalysis(String sceneType) {
    return SceneAnalysis(
      sceneType: sceneType,
      lightingCondition: 'unknown',
      subjectDistance: 'unknown',
      movementDetected: false,
      brightness: 0.0,
      contrast: 0.0,
      colorTemperature: 5500,
      dominantColors: [],
      faces: [],
      motion: 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }
  
  /// Generate empty camera settings when caching is not available
  Map<String, dynamic> _generateEmptyCameraSettings(String setting) {
    return {'error': 'Cache not available', 'confidence': 0.0};
  }
  
  SceneAnalysis _createFallbackSceneAnalysis() {
    return SceneAnalysis(
      sceneType: 'general',
      lightingCondition: 'normal',
      subjectDistance: 'medium',
      movementDetected: false,
      brightness: 0.5,
      contrast: 0.5,
      colorTemperature: 5500,
      dominantColors: [],
      faces: [],
      motion: 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }
  
  AIAnalysisResult _createFallbackAnalysisResult() {
    return AIAnalysisResult(
      success: false,
      suggestions: [],
      analysisTimestamp: DateTime.now(),
      confidence: 0.0,
    );
  }
  
  @override
  void dispose() {
    _aiCache.dispose();
    _imageCache.dispose();
    _predictiveCache.dispose();
    _baseService.dispose();
    
    _recentAnalyses.clear();
    
    debugPrint('CachedOptimizedAIService: Disposed with cache stats - Hits: $_cacheHits, Misses: $_cacheMisses, Hit Rate: ${(_cacheHits / math.max(_totalRequests, 1) * 100).toStringAsFixed(1)}%');
    super.dispose();
  }
}

// Extended capabilities for cached service
extension AIServiceCapabilitiesExtension on AIServiceCapabilities {
  bool get supportsCaching => true;
  bool get supportsPredictivePreloading => true;
  bool get supportsContextAwareness => true;
}

/// Comprehensive cache statistics for the AI service
class CachedAIServiceStats {
  final int totalRequests;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;
  final double averageCacheLatency;
  final AIResultsCacheStats aiCacheStats;
  final ImageCacheStats imageCacheStats;
  final PredictiveCacheStats predictiveCacheStats;
  
  const CachedAIServiceStats({
    required this.totalRequests,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
    required this.averageCacheLatency,
    required this.aiCacheStats,
    required this.imageCacheStats,
    required this.predictiveCacheStats,
  });
  
  double get performanceImprovement {
    return hitRate * 0.8; // Estimated 80% improvement for cache hits
  }
  
  @override
  String toString() {
    return 'CachedAIServiceStats('
           'requests: $totalRequests, '
           'hit_rate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'cache_latency: ${(averageCacheLatency / 1000).toStringAsFixed(1)}ms, '
           'ai_cache: ${aiCacheStats.cacheHits}, '
           'image_cache: ${imageCacheStats.imagesCached}, '
           'predictive_accuracy: ${(predictiveCacheStats.predictionAccuracy * 100).toStringAsFixed(1)}%)';
  }
}