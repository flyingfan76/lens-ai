import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Comprehensive cache metrics system for performance monitoring and optimization
/// 
/// Features:
/// - Real-time performance tracking
/// - Historical metrics with time-series data
/// - Hit rate analysis and trending
/// - Memory and disk usage monitoring
/// - Error tracking and alerting
/// - Performance regression detection
class CacheMetrics {
  // Real-time counters
  int _totalRequests = 0;
  int _hits = 0;
  int _misses = 0;
  int _writes = 0;
  int _evictions = 0;
  int _errors = 0;
  
  // Performance tracking
  final List<int> _hitLatencies = [];
  final List<int> _missLatencies = [];
  final List<int> _writeLatencies = [];
  
  // Time-series data
  final Queue<_MetricsSnapshot> _snapshots = Queue();
  static const int _maxSnapshots = 1440; // 24 hours of minute-level data
  
  // Memory and size tracking
  int _totalMemoryUsage = 0;
  int _totalDiskUsage = 0;
  int _totalEntries = 0;
  
  // Error tracking
  final Map<String, int> _errorCounts = {};
  final Queue<_ErrorEvent> _recentErrors = Queue();
  static const int _maxRecentErrors = 100;
  
  // Performance thresholds and alerts
  final List<PerformanceAlert> _activeAlerts = [];
  final StreamController<PerformanceAlert> _alertController = StreamController.broadcast();
  
  // Maintenance tracking
  DateTime? _lastMaintenanceTime;
  int _maintenanceCount = 0;
  
  // Configuration
  final Duration _snapshotInterval;
  Timer? _snapshotTimer;
  
  CacheMetrics({
    Duration snapshotInterval = const Duration(minutes: 1),
  }) : _snapshotInterval = snapshotInterval {
    _startSnapshotTimer();
  }
  
  /// Record a cache hit with latency
  void recordHit(CacheLevel level, int latencyMicros) {
    _totalRequests++;
    _hits++;
    _hitLatencies.add(latencyMicros);
    
    // Keep latency list size manageable
    if (_hitLatencies.length > 1000) {
      _hitLatencies.removeRange(0, 500);
    }
    
    _checkPerformanceThresholds(latencyMicros, 'hit', level);
  }
  
  /// Record a cache miss with latency
  void recordMiss(int latencyMicros) {
    _totalRequests++;
    _misses++;
    _missLatencies.add(latencyMicros);
    
    if (_missLatencies.length > 1000) {
      _missLatencies.removeRange(0, 500);
    }
    
    _checkHitRateThreshold();
  }
  
  /// Record a cache write with latency
  void recordWrite(int latencyMicros) {
    _writes++;
    _writeLatencies.add(latencyMicros);
    
    if (_writeLatencies.length > 1000) {
      _writeLatencies.removeRange(0, 500);
    }
    
    _checkPerformanceThresholds(latencyMicros, 'write');
  }
  
  /// Record a cache eviction
  void recordEviction(String reason) {
    _evictions++;
    
    // Check if eviction rate is too high
    if (_getRecentEvictionRate() > 10.0) { // More than 10 evictions per minute
      _triggerAlert(PerformanceAlert(
        type: AlertType.highEvictionRate,
        message: 'High eviction rate detected: ${_getRecentEvictionRate().toStringAsFixed(1)}/min',
        severity: AlertSeverity.warning,
        data: {'reason': reason, 'rate': _getRecentEvictionRate()},
      ));
    }
  }
  
  /// Record an error
  void recordError(String operation, String error) {
    _errors++;
    
    // Track error types
    _errorCounts[operation] = (_errorCounts[operation] ?? 0) + 1;
    
    // Keep recent errors for analysis
    _recentErrors.add(_ErrorEvent(
      operation: operation,
      error: error,
      timestamp: DateTime.now(),
    ));
    
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeFirst();
    }
    
    // Check error rate threshold
    final errorRate = _calculateErrorRate();
    if (errorRate > 0.05) { // More than 5% error rate
      _triggerAlert(PerformanceAlert(
        type: AlertType.highErrorRate,
        message: 'High error rate detected: ${(errorRate * 100).toStringAsFixed(1)}%',
        severity: AlertSeverity.error,
        data: {'operation': operation, 'error': error, 'rate': errorRate},
      ));
    }
  }
  
  /// Record a cache maintenance operation
  void recordMaintenance() {
    _lastMaintenanceTime = DateTime.now();
    _maintenanceCount++;
  }
  
  /// Record a cache clear operation
  void recordClear() {
    // Reset relevant counters
    _totalEntries = 0;
    _totalMemoryUsage = 0;
    // Keep historical data for analysis
  }
  
  /// Update usage statistics
  void updateUsageStats({
    int? memoryUsage,
    int? diskUsage,
    int? totalEntries,
  }) {
    if (memoryUsage != null) _totalMemoryUsage = memoryUsage;
    if (diskUsage != null) _totalDiskUsage = diskUsage;
    if (totalEntries != null) _totalEntries = totalEntries;
  }
  
  /// Get current metrics snapshot
  CacheMetricsStats getStats() {
    final hitRate = _totalRequests > 0 ? _hits / _totalRequests : 0.0;
    final errorRate = _calculateErrorRate();
    
    return CacheMetricsStats(
      totalRequests: _totalRequests,
      hits: _hits,
      misses: _misses,
      writes: _writes,
      evictions: _evictions,
      errors: _errors,
      hitRate: hitRate,
      errorRate: errorRate,
      averageHitLatency: _calculateAverageLatency(_hitLatencies),
      averageMissLatency: _calculateAverageLatency(_missLatencies),
      averageWriteLatency: _calculateAverageLatency(_writeLatencies),
      memoryUsage: _totalMemoryUsage,
      diskUsage: _totalDiskUsage,
      totalEntries: _totalEntries,
      lastMaintenanceTime: _lastMaintenanceTime,
      maintenanceCount: _maintenanceCount,
      activeAlerts: _activeAlerts.length,
      snapshotCount: _snapshots.length,
    );
  }
  
  /// Get detailed performance analysis
  PerformanceAnalysis getPerformanceAnalysis() {
    final stats = getStats();
    final trends = _calculateTrends();
    
    return PerformanceAnalysis(
      current: stats,
      trends: trends,
      recommendations: _generateRecommendations(stats, trends),
      alerts: List.from(_activeAlerts),
      errorBreakdown: Map.from(_errorCounts),
      latencyPercentiles: _calculateLatencyPercentiles(),
    );
  }
  
  /// Get historical metrics data
  List<MetricsSnapshot> getHistoricalData([Duration? period]) {
    final cutoff = period != null 
        ? DateTime.now().subtract(period)
        : null;
    
    return _snapshots
        .where((s) => cutoff == null || s.timestamp.isAfter(cutoff))
        .map((s) => MetricsSnapshot(
          timestamp: s.timestamp,
          hitRate: s.hitRate,
          requestRate: s.requestRate,
          errorRate: s.errorRate,
          memoryUsage: s.memoryUsage,
          diskUsage: s.diskUsage,
          averageLatency: s.averageLatency,
        ))
        .toList();
  }
  
  /// Get performance alerts stream
  Stream<PerformanceAlert> get alerts => _alertController.stream;
  
  /// Take a manual snapshot of current metrics
  void snapshot() {
    final stats = getStats();
    final snapshot = _MetricsSnapshot(
      timestamp: DateTime.now(),
      totalRequests: _totalRequests,
      hits: _hits,
      misses: _misses,
      writes: _writes,
      evictions: _evictions,
      errors: _errors,
      hitRate: stats.hitRate,
      requestRate: _calculateRequestRate(),
      errorRate: stats.errorRate,
      memoryUsage: _totalMemoryUsage,
      diskUsage: _totalDiskUsage,
      averageLatency: stats.averageHitLatency,
    );
    
    _snapshots.add(snapshot);
    
    // Keep only recent snapshots
    if (_snapshots.length > _maxSnapshots) {
      _snapshots.removeFirst();
    }
  }
  
  /// Reset all metrics (for testing or fresh start)
  void reset() {
    _totalRequests = 0;
    _hits = 0;
    _misses = 0;
    _writes = 0;
    _evictions = 0;
    _errors = 0;
    
    _hitLatencies.clear();
    _missLatencies.clear();
    _writeLatencies.clear();
    
    _snapshots.clear();
    _errorCounts.clear();
    _recentErrors.clear();
    _activeAlerts.clear();
    
    _totalMemoryUsage = 0;
    _totalDiskUsage = 0;
    _totalEntries = 0;
    
    _lastMaintenanceTime = null;
    _maintenanceCount = 0;
  }
  
  // Private methods for analysis and alerting
  
  void _startSnapshotTimer() {
    _snapshotTimer = Timer.periodic(_snapshotInterval, (_) => snapshot());
  }
  
  double _calculateAverageLatency(List<int> latencies) {
    if (latencies.isEmpty) return 0.0;
    final sum = latencies.reduce((a, b) => a + b);
    return sum / latencies.length;
  }
  
  double _calculateErrorRate() {
    return _totalRequests > 0 ? _errors / _totalRequests : 0.0;
  }
  
  double _calculateRequestRate() {
    if (_snapshots.length < 2) return 0.0;
    
    final recent = _snapshots.last;
    final previous = _snapshots.elementAt(_snapshots.length - 2);
    
    final requestDiff = recent.totalRequests - previous.totalRequests;
    final timeDiff = recent.timestamp.difference(previous.timestamp).inSeconds;
    
    return timeDiff > 0 ? requestDiff / timeDiff : 0.0;
  }
  
  double _getRecentEvictionRate() {
    if (_snapshots.length < 2) return 0.0;
    
    final recent = _snapshots.last;
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    
    final recentSnapshots = _snapshots
        .where((s) => s.timestamp.isAfter(oneMinuteAgo))
        .toList();
    
    if (recentSnapshots.length < 2) return 0.0;
    
    final evictionDiff = recentSnapshots.last.evictions - recentSnapshots.first.evictions;
    return evictionDiff.toDouble();
  }
  
  void _checkPerformanceThresholds(int latencyMicros, String operation, [CacheLevel? level]) {
    // Check for slow operations
    final latencyMs = latencyMicros / 1000;
    
    if (latencyMs > 100) { // More than 100ms
      _triggerAlert(PerformanceAlert(
        type: AlertType.slowOperation,
        message: 'Slow $operation detected: ${latencyMs.toStringAsFixed(1)}ms',
        severity: latencyMs > 500 ? AlertSeverity.error : AlertSeverity.warning,
        data: {
          'operation': operation,
          'latency_ms': latencyMs,
          'level': level?.name,
        },
      ));
    }
  }
  
  void _checkHitRateThreshold() {
    final hitRate = _totalRequests > 100 ? _hits / _totalRequests : 1.0;
    
    if (hitRate < 0.7) { // Less than 70% hit rate
      _triggerAlert(PerformanceAlert(
        type: AlertType.lowHitRate,
        message: 'Low hit rate detected: ${(hitRate * 100).toStringAsFixed(1)}%',
        severity: hitRate < 0.5 ? AlertSeverity.error : AlertSeverity.warning,
        data: {'hit_rate': hitRate, 'total_requests': _totalRequests},
      ));
    }
  }
  
  void _triggerAlert(PerformanceAlert alert) {
    // Avoid duplicate alerts
    final existingAlert = _activeAlerts.where(
      (a) => a.type == alert.type && a.message == alert.message,
    ).firstOrNull;
    
    if (existingAlert == null) {
      _activeAlerts.add(alert);
      
      if (!_alertController.isClosed) {
        _alertController.add(alert);
      }
      
      debugPrint('CacheMetrics: Alert triggered - ${alert.message}');
    }
  }
  
  MetricsTrends _calculateTrends() {
    if (_snapshots.length < 10) {
      return MetricsTrends.empty();
    }
    
    final recent = _snapshots.skip(_snapshots.length - 10).toList();
    
    return MetricsTrends(
      hitRateTrend: _calculateTrend(recent.map((s) => s.hitRate).toList()),
      requestRateTrend: _calculateTrend(recent.map((s) => s.requestRate).toList()),
      errorRateTrend: _calculateTrend(recent.map((s) => s.errorRate).toList()),
      latencyTrend: _calculateTrend(recent.map((s) => s.averageLatency).toList()),
      memoryUsageTrend: _calculateTrend(recent.map((s) => s.memoryUsage.toDouble()).toList()),
    );
  }
  
  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;
    
    // Simple linear regression slope
    final n = values.length;
    final sumX = (n * (n - 1)) / 2; // 0 + 1 + 2 + ... + (n-1)
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries
        .map((e) => e.key * e.value)
        .reduce((a, b) => a + b);
    final sumX2 = (n * (n - 1) * (2 * n - 1)) / 6; // Sum of squares
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    return slope;
  }
  
  List<String> _generateRecommendations(CacheMetricsStats stats, MetricsTrends trends) {
    final recommendations = <String>[];
    
    // Hit rate recommendations
    if (stats.hitRate < 0.7) {
      recommendations.add('Consider increasing cache size or adjusting eviction policy');
    }
    
    if (trends.hitRateTrend < -0.01) {
      recommendations.add('Hit rate is declining - review cache configuration');
    }
    
    // Latency recommendations
    if (stats.averageHitLatency > 50) {
      recommendations.add('High hit latency detected - consider memory optimization');
    }
    
    // Error rate recommendations
    if (stats.errorRate > 0.02) {
      recommendations.add('High error rate - investigate cache reliability issues');
    }
    
    // Eviction recommendations
    if (stats.evictions > stats.writes * 0.1) {
      recommendations.add('High eviction rate - consider increasing cache capacity');
    }
    
    return recommendations;
  }
  
  Map<String, double> _calculateLatencyPercentiles() {
    final allLatencies = [..._hitLatencies, ..._missLatencies, ..._writeLatencies];
    if (allLatencies.isEmpty) return {};
    
    allLatencies.sort();
    
    return {
      'p50': _percentile(allLatencies, 0.5),
      'p90': _percentile(allLatencies, 0.9),
      'p95': _percentile(allLatencies, 0.95),
      'p99': _percentile(allLatencies, 0.99),
    };
  }
  
  double _percentile(List<int> sortedList, double percentile) {
    final index = (sortedList.length * percentile).floor();
    return sortedList[math.min(index, sortedList.length - 1)].toDouble();
  }
  
  /// Dispose metrics system
  void dispose() {
    _snapshotTimer?.cancel();
    _alertController.close();
    debugPrint('CacheMetrics: Disposed');
  }
}

// Internal classes for metrics tracking

class _MetricsSnapshot {
  final DateTime timestamp;
  final int totalRequests;
  final int hits;
  final int misses;
  final int writes;
  final int evictions;
  final int errors;
  final double hitRate;
  final double requestRate;
  final double errorRate;
  final int memoryUsage;
  final int diskUsage;
  final double averageLatency;
  
  _MetricsSnapshot({
    required this.timestamp,
    required this.totalRequests,
    required this.hits,
    required this.misses,
    required this.writes,
    required this.evictions,
    required this.errors,
    required this.hitRate,
    required this.requestRate,
    required this.errorRate,
    required this.memoryUsage,
    required this.diskUsage,
    required this.averageLatency,
  });
}

class _ErrorEvent {
  final String operation;
  final String error;
  final DateTime timestamp;
  
  _ErrorEvent({
    required this.operation,
    required this.error,
    required this.timestamp,
  });
}

class PerformanceAlert {
  final AlertType type;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  
  PerformanceAlert({
    required this.type,
    required this.message,
    required this.severity,
    required this.data,
  }) : timestamp = DateTime.now();
  
}

// Public classes for metrics API

/// Cache metrics statistics
class CacheMetricsStats {
  final int totalRequests;
  final int hits;
  final int misses;
  final int writes;
  final int evictions;
  final int errors;
  final double hitRate;
  final double errorRate;
  final double averageHitLatency;
  final double averageMissLatency;
  final double averageWriteLatency;
  final int memoryUsage;
  final int diskUsage;
  final int totalEntries;
  final DateTime? lastMaintenanceTime;
  final int maintenanceCount;
  final int activeAlerts;
  final int snapshotCount;
  
  const CacheMetricsStats({
    required this.totalRequests,
    required this.hits,
    required this.misses,
    required this.writes,
    required this.evictions,
    required this.errors,
    required this.hitRate,
    required this.errorRate,
    required this.averageHitLatency,
    required this.averageMissLatency,
    required this.averageWriteLatency,
    required this.memoryUsage,
    required this.diskUsage,
    required this.totalEntries,
    this.lastMaintenanceTime,
    required this.maintenanceCount,
    required this.activeAlerts,
    required this.snapshotCount,
  });
  
  factory CacheMetricsStats.empty() {
    return CacheMetricsStats(
      totalRequests: 0,
      hits: 0,
      misses: 0,
      writes: 0,
      evictions: 0,
      errors: 0,
      hitRate: 0.0,
      errorRate: 0.0,
      averageHitLatency: 0.0,
      averageMissLatency: 0.0,
      averageWriteLatency: 0.0,
      memoryUsage: 0,
      diskUsage: 0,
      totalEntries: 0,
      maintenanceCount: 0,
      activeAlerts: 0,
      snapshotCount: 0,
    );
  }
  
  @override
  String toString() {
    return 'CacheMetricsStats('
           'requests: $totalRequests, '
           'hit_rate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'avg_latency: ${averageHitLatency.toStringAsFixed(1)}μs, '
           'memory: ${(memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB, '
           'alerts: $activeAlerts)';
  }
}

/// Performance analysis with trends and recommendations
class PerformanceAnalysis {
  final CacheMetricsStats current;
  final MetricsTrends trends;
  final List<String> recommendations;
  final List<PerformanceAlert> alerts;
  final Map<String, int> errorBreakdown;
  final Map<String, double> latencyPercentiles;
  
  const PerformanceAnalysis({
    required this.current,
    required this.trends,
    required this.recommendations,
    required this.alerts,
    required this.errorBreakdown,
    required this.latencyPercentiles,
  });
}

/// Metrics trends analysis
class MetricsTrends {
  final double hitRateTrend;
  final double requestRateTrend;
  final double errorRateTrend;
  final double latencyTrend;
  final double memoryUsageTrend;
  
  const MetricsTrends({
    required this.hitRateTrend,
    required this.requestRateTrend,
    required this.errorRateTrend,
    required this.latencyTrend,
    required this.memoryUsageTrend,
  });
  
  factory MetricsTrends.empty() {
    return const MetricsTrends(
      hitRateTrend: 0.0,
      requestRateTrend: 0.0,
      errorRateTrend: 0.0,
      latencyTrend: 0.0,
      memoryUsageTrend: 0.0,
    );
  }
}

/// Historical metrics snapshot
class MetricsSnapshot {
  final DateTime timestamp;
  final double hitRate;
  final double requestRate;
  final double errorRate;
  final int memoryUsage;
  final int diskUsage;
  final double averageLatency;
  
  const MetricsSnapshot({
    required this.timestamp,
    required this.hitRate,
    required this.requestRate,
    required this.errorRate,
    required this.memoryUsage,
    required this.diskUsage,
    required this.averageLatency,
  });
}


/// Alert types for different performance issues
enum AlertType {
  slowOperation,
  lowHitRate,
  highErrorRate,
  highEvictionRate,
  memoryPressure,
  diskSpaceLow,
}

/// Alert severity levels
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// Cache levels for hit tracking
enum CacheLevel {
  memory,
  disk,
}