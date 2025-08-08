import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/memory_manager.dart';
import '../utils/performance_monitor.dart';
import 'memory_cache.dart';
import 'disk_cache.dart';
import 'cache_metrics.dart';
import 'cache_key_generator.dart';
import 'cache_policy.dart';

/// Central cache coordinator that manages multi-level caching architecture
/// 
/// Features:
/// - Multi-tier caching (Memory L1, Disk L2)
/// - Content-aware cache keys
/// - Intelligent eviction policies
/// - Performance monitoring
/// - Background maintenance
/// - Cache warming strategies
class CacheManager {
  static const String _defaultNamespace = 'lens_ai';
  
  // Cache components
  late final MemoryCache _memoryCache;
  late final DiskCache _diskCache;
  late final CacheMetrics _metrics;
  late final CacheKeyGenerator _keyGenerator;
  late final MemoryManager _memoryManager;
  late final PerformanceMonitor _performanceMonitor;
  
  // Configuration
  final CacheManagerConfig _config;
  final String _namespace;
  
  // State management
  bool _isInitialized = false;
  Timer? _maintenanceTimer;
  Timer? _metricsTimer;
  final Map<String, Timer> _warmupTimers = {};
  
  // Performance tracking
  int _totalRequests = 0;
  int _memoryHits = 0;
  int _diskHits = 0;
  int _misses = 0;
  
  // Background operations
  final Set<String> _backgroundTasks = {};
  final StreamController<CacheEvent> _eventController = StreamController.broadcast();
  
  /// Singleton instance for global cache management
  static CacheManager? _instance;
  static CacheManager get instance => _instance ??= CacheManager._internal();
  
  CacheManager._internal([CacheManagerConfig? config, String? namespace])
      : _config = config ?? CacheManagerConfig.defaultConfig(),
        _namespace = namespace ?? _defaultNamespace;
  
  /// Create a named cache manager instance
  factory CacheManager.named(String namespace, [CacheManagerConfig? config]) {
    return CacheManager._internal(config, namespace);
  }
  
  /// Initialize the cache manager and all subsystems
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize dependencies
      _memoryManager = MemoryManager.instance;
      _performanceMonitor = PerformanceMonitor();
      _keyGenerator = CacheKeyGenerator();
      
      // Initialize cache layers
      _memoryCache = MemoryCache(
        maxMemorySize: _config.memoryCache.maxSize,
        maxEntries: _config.memoryCache.maxEntries,
        memoryManager: _memoryManager,
      );
      
      _diskCache = DiskCache(
        cacheDirectory: await _getCacheDirectory(),
        maxDiskSize: _config.diskCache.maxSize,
        maxEntries: _config.diskCache.maxEntries,
        compressionEnabled: _config.diskCache.compressionEnabled,
        encryptionEnabled: _config.diskCache.encryptionEnabled,
      );
      
      // Initialize metrics
      _metrics = CacheMetrics();
      
      // Initialize cache layers
      await _memoryCache.initialize();
      await _diskCache.initialize();
      
      // Start background maintenance
      _startMaintenanceTasks();
      
      _isInitialized = true;
      _emitEvent(CacheEvent.initialized(_namespace));
      
      debugPrint('CacheManager[$_namespace]: Initialized successfully');
      
    } catch (e, stackTrace) {
      throw CacheException(
        'Failed to initialize cache manager', 
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Get cached data with multi-level lookup
  Future<T?> get<T>(String key, {
    CachePolicy? policy,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    if (!_isInitialized) await initialize();
    
    final effectivePolicy = policy ?? _config.defaultPolicy;
    final fullKey = _keyGenerator.generate(key, namespace: _namespace);
    _totalRequests++;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // L1: Memory cache lookup
      if (effectivePolicy.useMemoryCache) {
        final memoryResult = await _memoryCache.get<T>(fullKey, fromJson: fromJson);
        if (memoryResult != null) {
          _memoryHits++;
          _metrics.recordHit(CacheLevel.memory, stopwatch.elapsedMicroseconds);
          _emitEvent(CacheEvent.hit(fullKey, CacheLevel.memory));
          return memoryResult;
        }
      }
      
      // L2: Disk cache lookup
      if (effectivePolicy.useDiskCache) {
        final diskResult = await _diskCache.get<T>(fullKey, fromJson: fromJson);
        if (diskResult != null) {
          _diskHits++;
          _metrics.recordHit(CacheLevel.disk, stopwatch.elapsedMicroseconds);
          _emitEvent(CacheEvent.hit(fullKey, CacheLevel.disk));
          
          // Promote to memory cache if policy allows
          if (effectivePolicy.promoteOnDiskHit && effectivePolicy.useMemoryCache) {
            await _memoryCache.put(fullKey, diskResult, policy: effectivePolicy);
          }
          
          return diskResult;
        }
      }
      
      // Cache miss
      _misses++;
      _metrics.recordMiss(stopwatch.elapsedMicroseconds);
      _emitEvent(CacheEvent.miss(fullKey));
      return null;
      
    } catch (e) {
      _metrics.recordError('get', e.toString());
      _emitEvent(CacheEvent.error(fullKey, 'get', e.toString()));
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Store data in appropriate cache levels
  Future<void> put<T>(String key, T value, {
    CachePolicy? policy,
    Duration? ttl,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    if (!_isInitialized) await initialize();
    
    final effectivePolicy = policy ?? _config.defaultPolicy;
    final fullKey = _keyGenerator.generate(key, namespace: _namespace);
    final effectiveTtl = ttl ?? effectivePolicy.defaultTtl;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Store in memory cache
      if (effectivePolicy.useMemoryCache) {
        await _memoryCache.put(fullKey, value, 
          policy: effectivePolicy, 
          ttl: effectiveTtl,
          toJson: toJson,
        );
      }
      
      // Store in disk cache
      if (effectivePolicy.useDiskCache) {
        await _diskCache.put(fullKey, value, 
          policy: effectivePolicy, 
          ttl: effectiveTtl,
          toJson: toJson,
        );
      }
      
      _metrics.recordWrite(stopwatch.elapsedMicroseconds);
      _emitEvent(CacheEvent.write(fullKey));
      
    } catch (e) {
      _metrics.recordError('put', e.toString());
      _emitEvent(CacheEvent.error(fullKey, 'put', e.toString()));
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Remove item from all cache levels
  Future<bool> remove(String key) async {
    if (!_isInitialized) await initialize();
    
    final fullKey = _keyGenerator.generate(key, namespace: _namespace);
    bool removed = false;
    
    try {
      final memoryRemoved = await _memoryCache.remove(fullKey);
      final diskRemoved = await _diskCache.remove(fullKey);
      
      removed = memoryRemoved || diskRemoved;
      
      if (removed) {
        _metrics.recordEviction('manual');
        _emitEvent(CacheEvent.eviction(fullKey, 'manual'));
      }
      
    } catch (e) {
      _metrics.recordError('remove', e.toString());
      _emitEvent(CacheEvent.error(fullKey, 'remove', e.toString()));
    }
    
    return removed;
  }
  
  /// Clear cache with optional pattern matching
  Future<void> clear([String? pattern]) async {
    if (!_isInitialized) await initialize();
    
    try {
      if (pattern != null) {
        await _memoryCache.clearPattern(pattern);
        await _diskCache.clearPattern(pattern);
      } else {
        await _memoryCache.clear();
        await _diskCache.clear();
      }
      
      _metrics.recordClear();
      _emitEvent(CacheEvent.clear(_namespace, pattern));
      
    } catch (e) {
      _metrics.recordError('clear', e.toString());
    }
  }
  
  /// Check if key exists in any cache level
  Future<bool> contains(String key) async {
    if (!_isInitialized) await initialize();
    
    final fullKey = _keyGenerator.generate(key, namespace: _namespace);
    
    return await _memoryCache.contains(fullKey) || 
           await _diskCache.contains(fullKey);
  }
  
  /// Get cache statistics and metrics
  CacheStats getStats() {
    if (!_isInitialized) {
      return CacheStats.empty();
    }
    
    final memoryStats = _memoryCache.getStats();
    final diskStats = _diskCache.getStats();
    final metricsStats = _metrics.getStats();
    
    return CacheStats(
      namespace: _namespace,
      totalRequests: _totalRequests,
      memoryHits: _memoryHits,
      diskHits: _diskHits,
      misses: _misses,
      hitRate: _totalRequests > 0 ? (_memoryHits + _diskHits) / _totalRequests : 0.0,
      memoryHitRate: _totalRequests > 0 ? _memoryHits / _totalRequests : 0.0,
      diskHitRate: _totalRequests > 0 ? _diskHits / _totalRequests : 0.0,
      memoryStats: memoryStats,
      diskStats: diskStats,
      metricsStats: metricsStats,
      backgroundTasks: _backgroundTasks.length,
    );
  }
  
  /// Warm cache with commonly used data
  Future<void> warmCache(List<CacheWarmupEntry> entries) async {
    if (!_isInitialized) await initialize();
    
    final taskId = 'warmup_${DateTime.now().millisecondsSinceEpoch}';
    _backgroundTasks.add(taskId);
    
    try {
      for (final entry in entries) {
        if (entry.delay != null) {
          _warmupTimers[entry.key] = Timer(entry.delay!, () async {
            await _warmupEntry(entry);
            _warmupTimers.remove(entry.key);
          });
        } else {
          await _warmupEntry(entry);
        }
      }
      
      _emitEvent(CacheEvent.warmupStarted(_namespace, entries.length));
      
    } finally {
      _backgroundTasks.remove(taskId);
    }
  }
  
  /// Preload data based on usage patterns
  Future<void> preloadPredictive(List<String> likelyKeys) async {
    if (!_isInitialized) await initialize();
    
    final taskId = 'predictive_${DateTime.now().millisecondsSinceEpoch}';
    _backgroundTasks.add(taskId);
    
    try {
      // Implement predictive preloading logic
      for (final key in likelyKeys) {
        if (await contains(key)) continue; // Already cached
        
        // Schedule background loading
        Timer(Duration(milliseconds: 100), () async {
          // This would be implemented by specific cache implementations
          _emitEvent(CacheEvent.predictiveLoad(key));
        });
      }
      
    } finally {
      _backgroundTasks.remove(taskId);
    }
  }
  
  /// Force cache maintenance and optimization
  Future<void> maintenance() async {
    if (!_isInitialized) await initialize();
    
    final taskId = 'maintenance_${DateTime.now().millisecondsSinceEpoch}';
    _backgroundTasks.add(taskId);
    
    try {
      // Run maintenance on both cache levels
      await Future.wait([
        _memoryCache.maintenance(),
        _diskCache.maintenance(),
      ]);
      
      // Update metrics
      _metrics.recordMaintenance();
      _emitEvent(CacheEvent.maintenance(_namespace));
      
    } finally {
      _backgroundTasks.remove(taskId);
    }
  }
  
  /// Get cache events stream for monitoring
  Stream<CacheEvent> get events => _eventController.stream;
  PerformanceMonitor get performanceMonitor => _performanceMonitor;
  
  /// Check cache health status
  Future<CacheHealthStatus> getHealthStatus() async {
    if (!_isInitialized) {
      return CacheHealthStatus.uninitialized();
    }
    
    final stats = getStats();
    final memoryHealth = await _memoryCache.getHealthStatus();
    final diskHealth = await _diskCache.getHealthStatus();
    
    return CacheHealthStatus(
      isHealthy: memoryHealth.isHealthy && diskHealth.isHealthy,
      hitRate: stats.hitRate,
      memoryUsage: memoryHealth.memoryUsage,
      diskUsage: diskHealth.diskUsage,
      errorRate: stats.metricsStats.errorRate,
      lastMaintenanceTime: _metrics.lastMaintenanceTime,
      issues: [
        ...memoryHealth.issues,
        ...diskHealth.issues,
      ],
    );
  }
  
  // Private methods
  
  Future<Directory> _getCacheDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Disk cache not supported on web platform');
    }
    
    final baseDir = Platform.isAndroid 
        ? Directory('/data/data/com.lensai.mobile/cache')
        : Directory('${Platform.environment['HOME']}/Library/Caches/com.lensai.mobile');
    
    final cacheDir = Directory('${baseDir.path}/lens_ai_cache/$_namespace');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  void _startMaintenanceTasks() {
    // Regular maintenance timer
    _maintenanceTimer = Timer.periodic(
      _config.maintenanceInterval,
      (_) async {
        if (_backgroundTasks.length < _config.maxBackgroundTasks) {
          await maintenance();
        }
      },
    );
    
    // Metrics collection timer
    _metricsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _metrics.snapshot(),
    );
  }
  
  Future<void> _warmupEntry(CacheWarmupEntry entry) async {
    try {
      if (entry.dataProvider != null) {
        final data = await entry.dataProvider!();
        await put(entry.key, data, policy: entry.policy);
      }
    } catch (e) {
      debugPrint('CacheManager: Warmup failed for ${entry.key}: $e');
    }
  }
  
  void _emitEvent(CacheEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
  
  /// Dispose cache manager and cleanup resources
  Future<void> dispose() async {
    _maintenanceTimer?.cancel();
    _metricsTimer?.cancel();
    
    for (final timer in _warmupTimers.values) {
      timer.cancel();
    }
    _warmupTimers.clear();
    
    if (_isInitialized) {
      await _memoryCache.dispose();
      await _diskCache.dispose();
      _metrics.dispose();
    }
    
    await _eventController.close();
    
    _isInitialized = false;
    debugPrint('CacheManager[$_namespace]: Disposed');
  }
}

/// Configuration for cache manager
class CacheManagerConfig {
  final MemoryCacheConfig memoryCache;
  final DiskCacheConfig diskCache;
  final CachePolicy defaultPolicy;
  final Duration maintenanceInterval;
  final int maxBackgroundTasks;
  
  const CacheManagerConfig({
    required this.memoryCache,
    required this.diskCache,
    required this.defaultPolicy,
    this.maintenanceInterval = const Duration(minutes: 30),
    this.maxBackgroundTasks = 3,
  });
  
  factory CacheManagerConfig.defaultConfig() {
    return CacheManagerConfig(
      memoryCache: MemoryCacheConfig.defaultConfig(),
      diskCache: DiskCacheConfig.defaultConfig(),
      defaultPolicy: CachePolicy.balanced(),
    );
  }
  
  factory CacheManagerConfig.performance() {
    return CacheManagerConfig(
      memoryCache: MemoryCacheConfig.performance(),
      diskCache: DiskCacheConfig.performance(),
      defaultPolicy: CachePolicy.performance(),
      maintenanceInterval: const Duration(minutes: 15),
      maxBackgroundTasks: 5,
    );
  }
  
  factory CacheManagerConfig.memoryOptimized() {
    return CacheManagerConfig(
      memoryCache: MemoryCacheConfig.memoryOptimized(),
      diskCache: DiskCacheConfig.memoryOptimized(),
      defaultPolicy: CachePolicy.memoryOptimized(),
      maintenanceInterval: const Duration(minutes: 45),
      maxBackgroundTasks: 2,
    );
  }
}

/// Cache warmup entry for preloading
class CacheWarmupEntry {
  final String key;
  final Future<dynamic> Function()? dataProvider;
  final CachePolicy? policy;
  final Duration? delay;
  
  const CacheWarmupEntry({
    required this.key,
    this.dataProvider,
    this.policy,
    this.delay,
  });
}

/// Cache statistics
class CacheStats {
  final String namespace;
  final int totalRequests;
  final int memoryHits;
  final int diskHits;
  final int misses;
  final double hitRate;
  final double memoryHitRate;
  final double diskHitRate;
  final MemoryCacheStats memoryStats;
  final DiskCacheStats diskStats;
  final CacheMetricsStats metricsStats;
  final int backgroundTasks;
  
  const CacheStats({
    required this.namespace,
    required this.totalRequests,
    required this.memoryHits,
    required this.diskHits,
    required this.misses,
    required this.hitRate,
    required this.memoryHitRate,
    required this.diskHitRate,
    required this.memoryStats,
    required this.diskStats,
    required this.metricsStats,
    required this.backgroundTasks,
  });
  
  factory CacheStats.empty() {
    return CacheStats(
      namespace: 'empty',
      totalRequests: 0,
      memoryHits: 0,
      diskHits: 0,
      misses: 0,
      hitRate: 0.0,
      memoryHitRate: 0.0,
      diskHitRate: 0.0,
      memoryStats: MemoryCacheStats.empty(),
      diskStats: DiskCacheStats.empty(),
      metricsStats: CacheMetricsStats.empty(),
      backgroundTasks: 0,
    );
  }
  
  @override
  String toString() {
    return 'CacheStats($namespace: '
           'requests=$totalRequests, '
           'hit_rate=${(hitRate * 100).toStringAsFixed(1)}%, '
           'memory_hits=$memoryHits, '
           'disk_hits=$diskHits, '
           'misses=$misses, '
           'bg_tasks=$backgroundTasks)';
  }
}

/// Cache health status
class CacheHealthStatus {
  final bool isHealthy;
  final double hitRate;
  final double memoryUsage;
  final double diskUsage;
  final double errorRate;
  final DateTime? lastMaintenanceTime;
  final List<String> issues;
  
  const CacheHealthStatus({
    required this.isHealthy,
    required this.hitRate,
    required this.memoryUsage,
    required this.diskUsage,
    required this.errorRate,
    this.lastMaintenanceTime,
    this.issues = const [],
  });
  
  factory CacheHealthStatus.uninitialized() {
    return CacheHealthStatus(
      isHealthy: false,
      hitRate: 0.0,
      memoryUsage: 0.0,
      diskUsage: 0.0,
      errorRate: 0.0,
      issues: ['Cache manager not initialized'],
    );
  }
}

/// Cache events for monitoring
class CacheEvent {
  final String type;
  final String key;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  
  CacheEvent._(this.type, this.key, this.data) : timestamp = DateTime.now();
  
  factory CacheEvent.initialized(String namespace) => 
      CacheEvent._('initialized', namespace, {});
  
  factory CacheEvent.hit(String key, CacheLevel level) => 
      CacheEvent._('hit', key, {'level': level.name});
  
  factory CacheEvent.miss(String key) => 
      CacheEvent._('miss', key, {});
  
  factory CacheEvent.write(String key) => 
      CacheEvent._('write', key, {});
  
  factory CacheEvent.eviction(String key, String reason) => 
      CacheEvent._('eviction', key, {'reason': reason});
  
  factory CacheEvent.error(String key, String operation, String error) => 
      CacheEvent._('error', key, {'operation': operation, 'error': error});
  
  factory CacheEvent.clear(String namespace, String? pattern) => 
      CacheEvent._('clear', namespace, {'pattern': pattern});
  
  factory CacheEvent.maintenance(String namespace) => 
      CacheEvent._('maintenance', namespace, {});
  
  factory CacheEvent.warmupStarted(String namespace, int entries) => 
      CacheEvent._('warmup_started', namespace, {'entries': entries});
  
  factory CacheEvent.predictiveLoad(String key) => 
      CacheEvent._('predictive_load', key, {});
}

/// Cache levels enumeration
enum CacheLevel { memory, disk }

extension CacheLevelExtension on CacheLevel {
  String get name {
    switch (this) {
      case CacheLevel.memory:
        return 'memory';
      case CacheLevel.disk:
        return 'disk';
    }
  }
}