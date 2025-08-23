import 'package:flutter/foundation.dart';

/// Simplified Performance Monitor for Lens AI
/// 
/// Only tracks essential metrics without the overhead of complex monitoring
class SimplePerformanceMonitor {
  static final SimplePerformanceMonitor _instance = SimplePerformanceMonitor._internal();
  factory SimplePerformanceMonitor() => _instance;
  SimplePerformanceMonitor._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  bool _isEnabled = false;

  /// Enable/disable performance monitoring
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _operationStartTimes.clear();
      _operationDurations.clear();
    }
  }

  /// Start timing an operation
  void startOperation(String operationName) {
    if (!_isEnabled) return;
    _operationStartTimes[operationName] = DateTime.now();
  }

  /// End timing an operation and record the duration
  Duration? endOperation(String operationName) {
    if (!_isEnabled) return null;
    
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    
    _operationDurations.putIfAbsent(operationName, () => []).add(duration);
    
    // Keep only the last 100 measurements to avoid memory issues
    if (_operationDurations[operationName]!.length > 100) {
      _operationDurations[operationName]!.removeAt(0);
    }

    debugPrint('Performance: $operationName took ${duration.inMilliseconds}ms');
    return duration;
  }

  /// Get average duration for an operation
  Duration? getAverageDuration(String operationName) {
    if (!_isEnabled) return null;
    
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// Get performance summary
  Map<String, Map<String, dynamic>> getSummary() {
    if (!_isEnabled) return {};
    
    final summary = <String, Map<String, dynamic>>{};
    
    for (final entry in _operationDurations.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;

      final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
      final avgMs = totalMs / durations.length;
      final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
      final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);

      summary[entry.key] = {
        'count': durations.length,
        'average_ms': avgMs.round(),
        'min_ms': minMs,
        'max_ms': maxMs,
      };
    }

    return summary;
  }

  /// Clear all recorded metrics
  void clear() {
    _operationStartTimes.clear();
    _operationDurations.clear();
  }

  /// Record a metric value (for simple counters or values)
  void recordMetric(String metricName, double value) {
    if (!_isEnabled) return;
    debugPrint('Metric: $metricName = $value');
  }
}