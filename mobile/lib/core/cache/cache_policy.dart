import 'dart:io';

/// Cache policy that defines caching behavior and strategies
class CachePolicy {
  final bool useMemoryCache;
  final bool useDiskCache;
  final bool promoteOnDiskHit;
  final bool compressData;
  final bool encryptSensitiveData;
  final Duration defaultTtl;
  final EvictionPolicy evictionPolicy;
  final CachePriority priority;
  final int maxMemorySize;
  final int maxDiskSize;
  final double memoryPressureThreshold;
  final bool allowBackgroundRefresh;
  final bool prefetchSimilar;
  
  const CachePolicy({
    this.useMemoryCache = true,
    this.useDiskCache = true,
    this.promoteOnDiskHit = true,
    this.compressData = false,
    this.encryptSensitiveData = false,
    this.defaultTtl = const Duration(hours: 24),
    this.evictionPolicy = EvictionPolicy.lru,
    this.priority = CachePriority.normal,
    this.maxMemorySize = 100 * 1024 * 1024, // 100MB
    this.maxDiskSize = 500 * 1024 * 1024, // 500MB
    this.memoryPressureThreshold = 0.8,
    this.allowBackgroundRefresh = false,
    this.prefetchSimilar = false,
  });
  
  /// Balanced cache policy for general use
  factory CachePolicy.balanced() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: true,
      defaultTtl: Duration(hours: 12),
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.normal,
      allowBackgroundRefresh: false,
    );
  }
  
  /// Performance-focused cache policy
  factory CachePolicy.performance() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: false, // Skip compression for speed
      defaultTtl: Duration(hours: 6),
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.high,
      maxMemorySize: 200 * 1024 * 1024, // 200MB
      maxDiskSize: 1024 * 1024 * 1024, // 1GB
      allowBackgroundRefresh: true,
      prefetchSimilar: true,
    );
  }
  
  /// Memory-optimized cache policy for resource-constrained devices
  factory CachePolicy.memoryOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: false, // Reduce memory pressure
      compressData: true,
      defaultTtl: Duration(hours: 48), // Longer retention
      evictionPolicy: EvictionPolicy.lruMemoryAware,
      priority: CachePriority.low,
      maxMemorySize: 50 * 1024 * 1024, // 50MB
      maxDiskSize: 200 * 1024 * 1024, // 200MB
      memoryPressureThreshold: 0.6,
      allowBackgroundRefresh: false,
    );
  }
  
  /// Disk-only cache policy for large data
  factory CachePolicy.diskOnly() {
    return const CachePolicy(
      useMemoryCache: false,
      useDiskCache: true,
      promoteOnDiskHit: false,
      compressData: true,
      defaultTtl: Duration(days: 7),
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.normal,
      maxDiskSize: 2048 * 1024 * 1024, // 2GB
    );
  }
  
  /// Memory-only cache policy for temporary data
  factory CachePolicy.memoryOnly() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: false,
      promoteOnDiskHit: false,
      compressData: false,
      defaultTtl: Duration(minutes: 30),
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.high,
      maxMemorySize: 150 * 1024 * 1024, // 150MB
    );
  }
  
  /// Secure cache policy for sensitive data
  factory CachePolicy.secure() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: true,
      encryptSensitiveData: true,
      defaultTtl: Duration(hours: 1), // Short TTL for security
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.high,
      allowBackgroundRefresh: false,
    );
  }
  
  /// AI-specific cache policy optimized for ML workloads
  factory CachePolicy.aiOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: false, // Preserve data integrity
      defaultTtl: Duration(hours: 2), // Frequent model updates
      evictionPolicy: EvictionPolicy.lfu, // Frequently used models
      priority: CachePriority.high,
      maxMemorySize: 300 * 1024 * 1024, // 300MB
      maxDiskSize: 1536 * 1024 * 1024, // 1.5GB
      allowBackgroundRefresh: true,
      prefetchSimilar: true,
    );
  }
  
  /// Image-specific cache policy for photo processing
  factory CachePolicy.imageOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: false, // Images are large, limit memory
      compressData: true, // Compress to save space
      defaultTtl: Duration(days: 3),
      evictionPolicy: EvictionPolicy.lruSizeAware,
      priority: CachePriority.normal,
      maxMemorySize: 100 * 1024 * 1024, // 100MB
      maxDiskSize: 2048 * 1024 * 1024, // 2GB
      allowBackgroundRefresh: false,
    );
  }
  
  /// Create a copy with modified parameters
  CachePolicy copyWith({
    bool? useMemoryCache,
    bool? useDiskCache,
    bool? promoteOnDiskHit,
    bool? compressData,
    bool? encryptSensitiveData,
    Duration? defaultTtl,
    EvictionPolicy? evictionPolicy,
    CachePriority? priority,
    int? maxMemorySize,
    int? maxDiskSize,
    double? memoryPressureThreshold,
    bool? allowBackgroundRefresh,
    bool? prefetchSimilar,
  }) {
    return CachePolicy(
      useMemoryCache: useMemoryCache ?? this.useMemoryCache,
      useDiskCache: useDiskCache ?? this.useDiskCache,
      promoteOnDiskHit: promoteOnDiskHit ?? this.promoteOnDiskHit,
      compressData: compressData ?? this.compressData,
      encryptSensitiveData: encryptSensitiveData ?? this.encryptSensitiveData,
      defaultTtl: defaultTtl ?? this.defaultTtl,
      evictionPolicy: evictionPolicy ?? this.evictionPolicy,
      priority: priority ?? this.priority,
      maxMemorySize: maxMemorySize ?? this.maxMemorySize,
      maxDiskSize: maxDiskSize ?? this.maxDiskSize,
      memoryPressureThreshold: memoryPressureThreshold ?? this.memoryPressureThreshold,
      allowBackgroundRefresh: allowBackgroundRefresh ?? this.allowBackgroundRefresh,
      prefetchSimilar: prefetchSimilar ?? this.prefetchSimilar,
    );
  }
  
  @override
  String toString() {
    return 'CachePolicy('
           'mem: $useMemoryCache, '
           'disk: $useDiskCache, '
           'ttl: ${defaultTtl.inHours}h, '
           'eviction: $evictionPolicy, '
           'priority: $priority)';
  }
}

/// Cache eviction policies
enum EvictionPolicy {
  /// Least Recently Used - evict items that haven't been accessed recently
  lru,
  
  /// Least Frequently Used - evict items with lowest access count
  lfu,
  
  /// First In, First Out - evict oldest items first
  fifo,
  
  /// Size-aware LRU - prioritize evicting large items
  lruSizeAware,
  
  /// Memory-aware LRU - consider system memory pressure
  lruMemoryAware,
  
  /// Time-based - evict expired items first, then LRU
  ttlLru,
  
  /// Priority-based - evict low priority items first
  priorityBased,
  
  /// Adaptive - dynamically choose strategy based on conditions
  adaptive,
}

/// Cache priority levels
enum CachePriority {
  /// Low priority - first to be evicted under pressure
  low(1),
  
  /// Normal priority - standard caching behavior
  normal(2),
  
  /// High priority - protected from eviction longer
  high(3),
  
  /// Critical priority - last to be evicted
  critical(4);
  
  const CachePriority(this.value);
  final int value;
  
  bool operator >(CachePriority other) => value > other.value;
  bool operator <(CachePriority other) => value < other.value;
  bool operator >=(CachePriority other) => value >= other.value;
  bool operator <=(CachePriority other) => value <= other.value;
}

/// Cache invalidation strategies
enum InvalidationStrategy {
  /// Manual invalidation only
  manual,
  
  /// Time-based expiration
  ttl,
  
  /// Invalidate on data changes
  writeThrough,
  
  /// Invalidate on external events
  eventBased,
  
  /// Version-based invalidation
  versioned,
  
  /// Content-based invalidation using checksums
  contentHash,
}

/// Platform-specific cache policies
class PlatformCachePolicy {
  /// Get optimized policy for current platform
  static CachePolicy forCurrentPlatform() {
    if (Platform.isIOS) {
      return _iOSOptimized();
    } else if (Platform.isAndroid) {
      return _androidOptimized();
    } else if (Platform.isMacOS) {
      return _macOSOptimized();
    } else {
      return CachePolicy.balanced();
    }
  }
  
  static CachePolicy _iOSOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: true,
      defaultTtl: Duration(hours: 8),
      evictionPolicy: EvictionPolicy.lruMemoryAware,
      priority: CachePriority.normal,
      maxMemorySize: 150 * 1024 * 1024, // 150MB
      maxDiskSize: 800 * 1024 * 1024, // 800MB
      memoryPressureThreshold: 0.75,
      allowBackgroundRefresh: true,
    );
  }
  
  static CachePolicy _androidOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: false, // More conservative due to diverse hardware
      compressData: true,
      defaultTtl: Duration(hours: 12),
      evictionPolicy: EvictionPolicy.adaptive,
      priority: CachePriority.normal,
      maxMemorySize: 100 * 1024 * 1024, // 100MB
      maxDiskSize: 600 * 1024 * 1024, // 600MB
      memoryPressureThreshold: 0.7,
      allowBackgroundRefresh: false,
    );
  }
  
  static CachePolicy _macOSOptimized() {
    return const CachePolicy(
      useMemoryCache: true,
      useDiskCache: true,
      promoteOnDiskHit: true,
      compressData: false, // Desktop has more resources
      defaultTtl: Duration(hours: 4),
      evictionPolicy: EvictionPolicy.lru,
      priority: CachePriority.high,
      maxMemorySize: 500 * 1024 * 1024, // 500MB
      maxDiskSize: 2048 * 1024 * 1024, // 2GB
      memoryPressureThreshold: 0.85,
      allowBackgroundRefresh: true,
      prefetchSimilar: true,
    );
  }
}

/// Cache policy validator for configuration validation
class CachePolicyValidator {
  static List<String> validate(CachePolicy policy) {
    final issues = <String>[];
    
    // Check memory size limits
    if (policy.maxMemorySize < 10 * 1024 * 1024) { // 10MB minimum
      issues.add('Memory cache size too small: ${policy.maxMemorySize}B');
    }
    
    if (policy.maxMemorySize > 1024 * 1024 * 1024) { // 1GB maximum
      issues.add('Memory cache size too large: ${policy.maxMemorySize}B');
    }
    
    // Check disk size limits
    if (policy.useDiskCache && policy.maxDiskSize < 50 * 1024 * 1024) { // 50MB minimum
      issues.add('Disk cache size too small: ${policy.maxDiskSize}B');
    }
    
    // Check TTL
    if (policy.defaultTtl.inSeconds < 60) {
      issues.add('TTL too short: ${policy.defaultTtl.inSeconds}s');
    }
    
    if (policy.defaultTtl.inDays > 30) {
      issues.add('TTL too long: ${policy.defaultTtl.inDays} days');
    }
    
    // Check threshold
    if (policy.memoryPressureThreshold <= 0.0 || policy.memoryPressureThreshold >= 1.0) {
      issues.add('Invalid memory pressure threshold: ${policy.memoryPressureThreshold}');
    }
    
    // Platform-specific checks
    if (Platform.isIOS && policy.maxDiskSize > 2048 * 1024 * 1024) {
      issues.add('Disk cache too large for iOS: ${policy.maxDiskSize}B');
    }
    
    return issues;
  }
  
  static bool isValid(CachePolicy policy) {
    return validate(policy).isEmpty;
  }
}