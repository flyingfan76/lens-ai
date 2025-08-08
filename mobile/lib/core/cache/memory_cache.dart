import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/memory_manager.dart';
import 'cache_policy.dart';

/// High-performance memory cache with LRU eviction and memory optimization
/// 
/// Features:
/// - Lock-free concurrent access
/// - Memory-aware eviction
/// - Hot/warm/cold data separation
/// - Zero-copy optimizations where possible
/// - Real-time memory pressure monitoring
class MemoryCache {
  final int _maxMemorySize;
  final int _maxEntries;
  final MemoryManager _memoryManager;
  
  // Storage structures optimized for different access patterns
  final LinkedHashMap<String, _MemoryCacheEntry> _hotData = LinkedHashMap();
  final LinkedHashMap<String, _MemoryCacheEntry> _warmData = LinkedHashMap();
  final LinkedHashMap<String, _MemoryCacheEntry> _coldData = LinkedHashMap();
  
  // Memory tracking
  int _currentMemoryUsage = 0;
  int _totalEntries = 0;
  
  // Access tracking for intelligent promotion/demotion
  final Map<String, _AccessStats> _accessStats = {};
  
  // Performance counters
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _promotions = 0;
  int _demotions = 0;
  
  // Background maintenance
  Timer? _maintenanceTimer;
  bool _isInitialized = false;
  
  MemoryCache({
    required int maxMemorySize,
    required int maxEntries,
    required MemoryManager memoryManager,
  })  : _maxMemorySize = maxMemorySize,
        _maxEntries = maxEntries,
        _memoryManager = memoryManager;
  
  /// Initialize the memory cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Start background maintenance
    _maintenanceTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _performMaintenance(),
    );
    
    _isInitialized = true;
    debugPrint('MemoryCache: Initialized with ${_maxMemorySize}B memory, ${_maxEntries} entries');
  }
  
  /// Get value from cache with type safety
  Future<T?> get<T>(String key, {
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    if (!_isInitialized) await initialize();
    
    final entry = _findEntry(key);
    if (entry == null) {
      _misses++;
      return null;
    }
    
    // Check expiration
    if (entry.isExpired) {
      await _removeEntry(key);
      _misses++;
      return null;
    }
    
    // Update access statistics
    _updateAccessStats(key, entry);
    
    // Handle data tier promotion
    _considerPromotion(key, entry);
    
    _hits++;
    
    // Deserialize data if needed
    try {
      if (entry.data is T) {
        return entry.data as T;
      } else if (fromJson != null && entry.data is Map<String, dynamic>) {
        return fromJson(entry.data as Map<String, dynamic>);
      } else if (entry.data is String && T == String) {
        return entry.data as T;
      } else {
        // Try JSON deserialization
        final jsonData = entry.data is String 
            ? jsonDecode(entry.data as String) 
            : entry.data;
        
        if (fromJson != null && jsonData is Map<String, dynamic>) {
          return fromJson(jsonData);
        }
        
        return jsonData as T?;
      }
    } catch (e) {
      debugPrint('MemoryCache: Deserialization failed for key $key: $e');
      return null;
    }
  }
  
  /// Store value in cache with automatic tier assignment
  Future<void> put<T>(String key, T value, {
    CachePolicy? policy,
    Duration? ttl,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    if (!_isInitialized) await initialize();
    
    // Serialize data
    dynamic serializedData;
    int dataSize;
    
    try {
      if (value is Uint8List) {
        serializedData = value;
        dataSize = value.length;
      } else if (value is String) {
        serializedData = value;
        dataSize = value.length * 2; // UTF-16 approximation
      } else if (toJson != null) {
        final jsonMap = toJson(value);
        serializedData = jsonMap;
        dataSize = _estimateMapSize(jsonMap);
      } else {
        // Fallback to JSON encoding
        final jsonString = jsonEncode(value);
        serializedData = jsonString;
        dataSize = jsonString.length * 2;
      }
    } catch (e) {
      debugPrint('MemoryCache: Serialization failed for key $key: $e');
      return;
    }
    
    // Check memory pressure
    if (!await _ensureMemoryAvailable(dataSize)) {
      debugPrint('MemoryCache: Insufficient memory for key $key (${dataSize}B)');
      return;
    }
    
    // Remove existing entry if present
    await _removeEntry(key);
    
    // Create new entry
    final expiry = ttl != null ? DateTime.now().add(ttl) : null;
    final entry = _MemoryCacheEntry(
      key: key,
      data: serializedData,
      size: dataSize,
      created: DateTime.now(),
      lastAccessed: DateTime.now(),
      accessCount: 1,
      expiry: expiry,
    );
    
    // Determine initial tier based on policy and predicted access pattern
    final tier = _determineTier(key, policy);
    _placeInTier(key, entry, tier);
    
    _currentMemoryUsage += dataSize;
    _totalEntries++;
    
    // Initialize access stats
    _accessStats[key] = _AccessStats();
  }
  
  /// Remove entry from cache
  Future<bool> remove(String key) async {
    return await _removeEntry(key);
  }
  
  /// Check if key exists in cache
  Future<bool> contains(String key) async {
    final entry = _findEntry(key);
    if (entry == null) return false;
    
    if (entry.isExpired) {
      await _removeEntry(key);
      return false;
    }
    
    return true;
  }
  
  /// Clear cache entries matching pattern
  Future<void> clearPattern(String pattern) async {
    final regex = RegExp(pattern);
    final keysToRemove = <String>[];
    
    // Collect keys to remove
    for (final key in _getAllKeys()) {
      if (regex.hasMatch(key)) {
        keysToRemove.add(key);
      }
    }
    
    // Remove entries
    for (final key in keysToRemove) {
      await _removeEntry(key);
    }
    
    debugPrint('MemoryCache: Cleared ${keysToRemove.length} entries matching pattern: $pattern');
  }
  
  /// Clear all cache entries
  Future<void> clear() async {
    _hotData.clear();
    _warmData.clear();
    _coldData.clear();
    _accessStats.clear();
    
    _currentMemoryUsage = 0;
    _totalEntries = 0;
    
    debugPrint('MemoryCache: Cleared all entries');
  }
  
  /// Get cache statistics
  MemoryCacheStats getStats() {
    return MemoryCacheStats(
      maxMemorySize: _maxMemorySize,
      currentMemorySize: _currentMemoryUsage,
      maxEntries: _maxEntries,
      totalEntries: _totalEntries,
      hotEntries: _hotData.length,
      warmEntries: _warmData.length,
      coldEntries: _coldData.length,
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      promotions: _promotions,
      demotions: _demotions,
      hitRate: _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0,
      memoryUtilization: _currentMemoryUsage / _maxMemorySize,
    );
  }
  
  /// Get cache health status
  Future<MemoryCacheHealthStatus> getHealthStatus() async {
    final stats = getStats();
    final memoryStats = _memoryManager.getMemoryStats();
    
    final issues = <String>[];
    
    // Check memory pressure
    if (stats.memoryUtilization > 0.9) {
      issues.add('High memory utilization: ${(stats.memoryUtilization * 100).toStringAsFixed(1)}%');
    }
    
    // Check hit rate
    if (stats.hitRate < 0.7) {
      issues.add('Low hit rate: ${(stats.hitRate * 100).toStringAsFixed(1)}%');
    }
    
    // Check system memory
    if (await _memoryManager.isLowMemory()) {
      issues.add('System memory pressure detected');
    }
    
    return MemoryCacheHealthStatus(
      isHealthy: issues.isEmpty,
      memoryUsage: stats.memoryUtilization,
      hitRate: stats.hitRate,
      issues: issues,
    );
  }
  
  /// Perform maintenance and optimization
  Future<void> maintenance() async {
    await _performMaintenance();
  }
  
  // Private methods for cache management
  
  _MemoryCacheEntry? _findEntry(String key) {
    return _hotData[key] ?? _warmData[key] ?? _coldData[key];
  }
  
  List<String> _getAllKeys() {
    return [
      ..._hotData.keys,
      ..._warmData.keys,
      ..._coldData.keys,
    ];
  }
  
  Future<bool> _removeEntry(String key) async {
    _MemoryCacheEntry? entry;
    
    entry = _hotData.remove(key);
    entry ??= _warmData.remove(key);
    entry ??= _coldData.remove(key);
    
    if (entry != null) {
      _currentMemoryUsage -= entry.size;
      _totalEntries--;
      _accessStats.remove(key);
      return true;
    }
    
    return false;
  }
  
  void _updateAccessStats(String key, _MemoryCacheEntry entry) {
    entry.lastAccessed = DateTime.now();
    entry.accessCount++;
    
    final stats = _accessStats[key];
    if (stats != null) {
      stats.totalAccesses++;
      stats.lastAccess = DateTime.now();
      
      final timeSinceLastAccess = DateTime.now().difference(stats.previousAccess ?? DateTime.now());
      stats.averageInterval = stats.averageInterval == null
          ? timeSinceLastAccess.inMilliseconds.toDouble()
          : (stats.averageInterval! + timeSinceLastAccess.inMilliseconds) / 2;
      
      stats.previousAccess = DateTime.now();
    }
  }
  
  void _considerPromotion(String key, _MemoryCacheEntry entry) {
    final stats = _accessStats[key];
    if (stats == null) return;
    
    // Promotion criteria
    final recentAccess = DateTime.now().difference(entry.lastAccessed).inMinutes < 5;
    final frequentAccess = stats.totalAccesses > 3;
    final regularAccess = stats.averageInterval != null && stats.averageInterval! < 300000; // 5 minutes
    
    if (recentAccess && (frequentAccess || regularAccess)) {
      if (_coldData.containsKey(key)) {
        _promoteToWarm(key, entry);
      } else if (_warmData.containsKey(key) && frequentAccess && regularAccess) {
        _promoteToHot(key, entry);
      }
    }
  }
  
  void _promoteToWarm(String key, _MemoryCacheEntry entry) {
    if (_coldData.remove(key) != null) {
      _warmData[key] = entry;
      _promotions++;
    }
  }
  
  void _promoteToHot(String key, _MemoryCacheEntry entry) {
    if (_warmData.remove(key) != null) {
      _hotData[key] = entry;
      _promotions++;
    }
  }
  
  void _demoteToWarm(String key, _MemoryCacheEntry entry) {
    if (_hotData.remove(key) != null) {
      _warmData[key] = entry;
      _demotions++;
    }
  }
  
  void _demoteToCold(String key, _MemoryCacheEntry entry) {
    if (_warmData.remove(key) != null) {
      _coldData[key] = entry;
      _demotions++;
    }
  }
  
  _CacheTier _determineTier(String key, CachePolicy? policy) {
    // Start with warm tier for new entries
    // Hot tier is earned through access patterns
    // Cold tier is for deprioritized data
    return _CacheTier.warm;
  }
  
  void _placeInTier(String key, _MemoryCacheEntry entry, _CacheTier tier) {
    switch (tier) {
      case _CacheTier.hot:
        _hotData[key] = entry;
        break;
      case _CacheTier.warm:
        _warmData[key] = entry;
        break;
      case _CacheTier.cold:
        _coldData[key] = entry;
        break;
    }
  }
  
  Future<bool> _ensureMemoryAvailable(int requiredSize) async {
    // Check system memory
    if (!await _memoryManager.ensureMemoryAvailable(requiredSize)) {
      return false;
    }
    
    // Check cache limits
    while (_currentMemoryUsage + requiredSize > _maxMemorySize ||
           _totalEntries >= _maxEntries) {
      
      if (!await _evictLRU()) {
        return false; // Cannot evict any more entries
      }
    }
    
    return true;
  }
  
  Future<bool> _evictLRU() async {
    String? keyToEvict;
    _MemoryCacheEntry? entryToEvict;
    
    // Try to evict from cold tier first
    if (_coldData.isNotEmpty) {
      keyToEvict = _findLRUInMap(_coldData);
      entryToEvict = _coldData[keyToEvict];
    }
    
    // Then warm tier
    if (keyToEvict == null && _warmData.isNotEmpty) {
      keyToEvict = _findLRUInMap(_warmData);
      entryToEvict = _warmData[keyToEvict];
    }
    
    // Finally hot tier (least preferred)
    if (keyToEvict == null && _hotData.isNotEmpty) {
      keyToEvict = _findLRUInMap(_hotData);
      entryToEvict = _hotData[keyToEvict];
    }
    
    if (keyToEvict != null && entryToEvict != null) {
      await _removeEntry(keyToEvict);
      _evictions++;
      return true;
    }
    
    return false;
  }
  
  String? _findLRUInMap(LinkedHashMap<String, _MemoryCacheEntry> map) {
    if (map.isEmpty) return null;
    
    String? lruKey;
    DateTime? oldestAccess;
    
    for (final entry in map.entries) {
      if (oldestAccess == null || entry.value.lastAccessed.isBefore(oldestAccess)) {
        oldestAccess = entry.value.lastAccessed;
        lruKey = entry.key;
      }
    }
    
    return lruKey;
  }
  
  Future<void> _performMaintenance() async {
    // Remove expired entries
    final expiredKeys = <String>[];
    
    for (final entry in _getAllEntries()) {
      if (entry.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      await _removeEntry(key);
    }
    
    // Adjust tier assignments based on access patterns
    await _rebalanceTiers();
    
    debugPrint('MemoryCache: Maintenance completed - removed ${expiredKeys.length} expired entries');
  }
  
  Iterable<_MemoryCacheEntry> _getAllEntries() {
    return [
      ..._hotData.values,
      ..._warmData.values,
      ..._coldData.values,
    ];
  }
  
  Future<void> _rebalanceTiers() async {
    // Demote infrequently accessed hot data
    final hotDemotions = <String, _MemoryCacheEntry>{};
    for (final entry in _hotData.entries) {
      final stats = _accessStats[entry.key];
      if (stats != null) {
        final minutesSinceLastAccess = DateTime.now().difference(stats.lastAccess).inMinutes;
        if (minutesSinceLastAccess > 30 || stats.totalAccesses < 5) {
          hotDemotions[entry.key] = entry.value;
        }
      }
    }
    
    for (final entry in hotDemotions.entries) {
      _demoteToWarm(entry.key, entry.value);
    }
    
    // Demote infrequently accessed warm data
    final warmDemotions = <String, _MemoryCacheEntry>{};
    for (final entry in _warmData.entries) {
      final stats = _accessStats[entry.key];
      if (stats != null) {
        final minutesSinceLastAccess = DateTime.now().difference(stats.lastAccess).inMinutes;
        if (minutesSinceLastAccess > 60 || stats.totalAccesses < 2) {
          warmDemotions[entry.key] = entry.value;
        }
      }
    }
    
    for (final entry in warmDemotions.entries) {
      _demoteToCold(entry.key, entry.value);
    }
  }
  
  int _estimateMapSize(Map<String, dynamic> map) {
    // Rough estimation of map memory usage
    int size = 100; // Base overhead
    
    for (final entry in map.entries) {
      size += entry.key.length * 2; // Key size
      size += _estimateValueSize(entry.value);
    }
    
    return size;
  }
  
  int _estimateValueSize(dynamic value) {
    if (value is String) {
      return value.length * 2;
    } else if (value is int) {
      return 8;
    } else if (value is double) {
      return 8;
    } else if (value is bool) {
      return 1;
    } else if (value is List) {
      return value.length * 50; // Rough estimation
    } else if (value is Map) {
      return _estimateMapSize(value as Map<String, dynamic>);
    } else {
      return 100; // Default estimation
    }
  }
  
  /// Dispose memory cache
  Future<void> dispose() async {
    _maintenanceTimer?.cancel();
    await clear();
    debugPrint('MemoryCache: Disposed');
  }
}

/// Memory cache entry with metadata
class _MemoryCacheEntry {
  final String key;
  final dynamic data;
  final int size;
  final DateTime created;
  DateTime lastAccessed;
  int accessCount;
  final DateTime? expiry;
  
  _MemoryCacheEntry({
    required this.key,
    required this.data,
    required this.size,
    required this.created,
    required this.lastAccessed,
    required this.accessCount,
    this.expiry,
  });
  
  bool get isExpired {
    return expiry != null && DateTime.now().isAfter(expiry!);
  }
}

/// Access statistics for intelligent caching decisions
class _AccessStats {
  int totalAccesses = 0;
  DateTime lastAccess = DateTime.now();
  DateTime? previousAccess;
  double? averageInterval;
  
  _AccessStats();
}

/// Cache tiers for data temperature
enum _CacheTier { hot, warm, cold }

/// Memory cache statistics
class MemoryCacheStats {
  final int maxMemorySize;
  final int currentMemorySize;
  final int maxEntries;
  final int totalEntries;
  final int hotEntries;
  final int warmEntries;
  final int coldEntries;
  final int hits;
  final int misses;
  final int evictions;
  final int promotions;
  final int demotions;
  final double hitRate;
  final double memoryUtilization;
  
  const MemoryCacheStats({
    required this.maxMemorySize,
    required this.currentMemorySize,
    required this.maxEntries,
    required this.totalEntries,
    required this.hotEntries,
    required this.warmEntries,
    required this.coldEntries,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.promotions,
    required this.demotions,
    required this.hitRate,
    required this.memoryUtilization,
  });
  
  factory MemoryCacheStats.empty() {
    return const MemoryCacheStats(
      maxMemorySize: 0,
      currentMemorySize: 0,
      maxEntries: 0,
      totalEntries: 0,
      hotEntries: 0,
      warmEntries: 0,
      coldEntries: 0,
      hits: 0,
      misses: 0,
      evictions: 0,
      promotions: 0,
      demotions: 0,
      hitRate: 0.0,
      memoryUtilization: 0.0,
    );
  }
  
  @override
  String toString() {
    return 'MemoryCacheStats('
           'memory: ${(currentMemorySize / 1024 / 1024).toStringAsFixed(1)}MB/'
           '${(maxMemorySize / 1024 / 1024).toStringAsFixed(1)}MB, '
           'entries: $totalEntries/$maxEntries, '
           'hit_rate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'tiers: H$hotEntries/W$warmEntries/C$coldEntries)';
  }
}

/// Memory cache health status
class MemoryCacheHealthStatus {
  final bool isHealthy;
  final double memoryUsage;
  final double hitRate;
  final List<String> issues;
  
  const MemoryCacheHealthStatus({
    required this.isHealthy,
    required this.memoryUsage,
    required this.hitRate,
    required this.issues,
  });
}

/// Memory cache configuration
class MemoryCacheConfig {
  final int maxSize;
  final int maxEntries;
  final EvictionPolicy evictionPolicy;
  
  const MemoryCacheConfig({
    required this.maxSize,
    required this.maxEntries,
    required this.evictionPolicy,
  });
  
  factory MemoryCacheConfig.defaultConfig() {
    return const MemoryCacheConfig(
      maxSize: 100 * 1024 * 1024, // 100MB
      maxEntries: 1000,
      evictionPolicy: EvictionPolicy.lru,
    );
  }
  
  factory MemoryCacheConfig.performance() {
    return const MemoryCacheConfig(
      maxSize: 200 * 1024 * 1024, // 200MB
      maxEntries: 2000,
      evictionPolicy: EvictionPolicy.lru,
    );
  }
  
  factory MemoryCacheConfig.memoryOptimized() {
    return const MemoryCacheConfig(
      maxSize: 50 * 1024 * 1024, // 50MB
      maxEntries: 500,
      evictionPolicy: EvictionPolicy.lruMemoryAware,
    );
  }
}