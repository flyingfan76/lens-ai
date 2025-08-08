import 'dart:async';
import 'package:flutter/material.dart';
import 'disposal_mixin.dart';

/// Utilities for testing disposal patterns and memory leak detection
class DisposalTestUtils {
  static int _widgetCreationCount = 0;
  static int _widgetDisposalCount = 0;
  static final Map<String, DisposalTrackingData> _trackingData = {};

  /// Track widget creation for disposal testing
  static void trackWidgetCreation(String widgetName) {
    _widgetCreationCount++;
    final data = _trackingData.putIfAbsent(
      widgetName, 
      () => DisposalTrackingData(widgetName),
    );
    data.creationCount++;
    DisposalTracker.trackCreation('widget_$widgetName');
  }

  /// Track widget disposal for disposal testing
  static void trackWidgetDisposal(String widgetName) {
    _widgetDisposalCount++;
    final data = _trackingData[widgetName];
    if (data != null) {
      data.disposalCount++;
      DisposalTracker.trackDisposal('widget_$widgetName');
    }
  }

  /// Reset all tracking counters
  static void resetTracking() {
    _widgetCreationCount = 0;
    _widgetDisposalCount = 0;
    _trackingData.clear();
    DisposalTracker.reset();
  }

  /// Get current disposal statistics
  static DisposalStats getDisposalStats() {
    return DisposalStats(
      totalWidgetsCreated: _widgetCreationCount,
      totalWidgetsDisposed: _widgetDisposalCount,
      potentialLeaks: _calculatePotentialLeaks(),
      trackingData: Map.from(_trackingData),
    );
  }

  /// Calculate potential memory leaks
  static Map<String, int> _calculatePotentialLeaks() {
    final leaks = <String, int>{};
    for (final data in _trackingData.values) {
      if (data.creationCount > data.disposalCount) {
        leaks[data.widgetName] = data.creationCount - data.disposalCount;
      }
    }
    return leaks;
  }

  /// Assert that all widgets have been properly disposed
  static void assertAllWidgetsDisposed() {
    final stats = getDisposalStats();
    if (stats.potentialLeaks.isNotEmpty) {
      throw AssertionError(
        'Memory leaks detected: ${stats.potentialLeaks}\n'
        'Total created: ${stats.totalWidgetsCreated}, '
        'Total disposed: ${stats.totalWidgetsDisposed}',
      );
    }
  }

  /// Assert that a specific widget type has been properly disposed
  static void assertWidgetTypeDisposed(String widgetName) {
    final data = _trackingData[widgetName];
    if (data == null) {
      throw AssertionError('Widget $widgetName was never tracked');
    }
    if (data.creationCount > data.disposalCount) {
      throw AssertionError(
        'Widget $widgetName has potential leaks: '
        '${data.creationCount} created, ${data.disposalCount} disposed',
      );
    }
  }

  /// Print detailed disposal report
  static void printDisposalReport() {
    final stats = getDisposalStats();
    debugPrint('=== Disposal Test Report ===');
    debugPrint('Total widgets created: ${stats.totalWidgetsCreated}');
    debugPrint('Total widgets disposed: ${stats.totalWidgetsDisposed}');
    
    if (stats.potentialLeaks.isNotEmpty) {
      debugPrint('⚠️ Potential memory leaks detected:');
      for (final entry in stats.potentialLeaks.entries) {
        debugPrint('  - ${entry.key}: ${entry.value} undisposed instances');
      }
    } else {
      debugPrint('✅ No memory leaks detected');
    }
    
    debugPrint('\nPer-widget breakdown:');
    for (final data in stats.trackingData.values) {
      debugPrint('  ${data.widgetName}: ${data.creationCount} created, ${data.disposalCount} disposed');
    }
    
    debugPrint('============================');
  }
}

/// Mixin for testing widgets with disposal tracking
mixin DisposalTestingMixin<T extends StatefulWidget> on State<T> {
  late String _widgetTestName;

  @override
  void initState() {
    super.initState();
    _widgetTestName = widget.runtimeType.toString();
    DisposalTestUtils.trackWidgetCreation(_widgetTestName);
  }

  @override
  void dispose() {
    DisposalTestUtils.trackWidgetDisposal(_widgetTestName);
    super.dispose();
  }
}

/// Data class for tracking disposal information
class DisposalTrackingData {
  final String widgetName;
  int creationCount = 0;
  int disposalCount = 0;

  DisposalTrackingData(this.widgetName);

  bool get hasLeaks => creationCount > disposalCount;
  int get leakCount => creationCount - disposalCount;
}

/// Statistics about disposal behavior
class DisposalStats {
  final int totalWidgetsCreated;
  final int totalWidgetsDisposed;
  final Map<String, int> potentialLeaks;
  final Map<String, DisposalTrackingData> trackingData;

  const DisposalStats({
    required this.totalWidgetsCreated,
    required this.totalWidgetsDisposed,
    required this.potentialLeaks,
    required this.trackingData,
  });

  bool get hasLeaks => potentialLeaks.isNotEmpty;
  int get totalLeaks => potentialLeaks.values.fold(0, (sum, count) => sum + count);
}

/// Custom test widget for disposal testing
class DisposalTestWidget extends StatefulWidget {
  final String testName;
  final Widget child;
  final VoidCallback? onDispose;

  const DisposalTestWidget({
    super.key,
    required this.testName,
    required this.child,
    this.onDispose,
  });

  @override
  State<DisposalTestWidget> createState() => _DisposalTestWidgetState();
}

class _DisposalTestWidgetState extends State<DisposalTestWidget>
    with DisposalTestingMixin {
  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Test helper for async operations with disposal
class AsyncDisposalTester {
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];
  final List<StreamController> _controllers = [];
  bool _disposed = false;

  /// Create a timer for testing
  Timer createTimer(Duration duration, VoidCallback callback) {
    if (_disposed) throw StateError('Tester is disposed');
    
    final timer = Timer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Create a periodic timer for testing
  Timer createPeriodicTimer(Duration period, void Function(Timer) callback) {
    if (_disposed) throw StateError('Tester is disposed');
    
    final timer = Timer.periodic(period, callback);
    _timers.add(timer);
    return timer;
  }

  /// Create a stream subscription for testing
  StreamSubscription<T> createSubscription<T>(
    Stream<T> stream,
    void Function(T) onData,
  ) {
    if (_disposed) throw StateError('Tester is disposed');
    
    final subscription = stream.listen(onData);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Create a stream controller for testing
  StreamController<T> createStreamController<T>() {
    if (_disposed) throw StateError('Tester is disposed');
    
    final controller = StreamController<T>();
    _controllers.add(controller);
    return controller;
  }

  /// Check if all resources are properly disposed
  bool get areResourcesDisposed {
    return _timers.every((timer) => !timer.isActive) &&
           _subscriptions.every((sub) => sub.isPaused) &&
           _controllers.every((controller) => controller.isClosed);
  }

  /// Get count of active resources
  int get activeResourceCount {
    return _timers.where((timer) => timer.isActive).length +
           _subscriptions.where((sub) => !sub.isPaused).length +
           _controllers.where((controller) => !controller.isClosed).length;
  }

  /// Dispose all resources
  void dispose() {
    if (_disposed) return;
    
    for (final timer in _timers) {
      if (timer.isActive) timer.cancel();
    }
    _timers.clear();
    
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    for (final controller in _controllers) {
      if (!controller.isClosed) controller.close();
    }
    _controllers.clear();
    
    _disposed = true;
  }
}

/// Debug utilities for monitoring disposal in development
class DisposalDebugger {
  /// Enable disposal debugging
  static bool _debugEnabled = false;
  
  /// Enable or disable disposal debugging
  static void setDebugEnabled(bool enabled) {
    _debugEnabled = enabled;
    debugPrint('Disposal debugging ${enabled ? 'enabled' : 'disabled'}');
  }
  
  /// Log disposal event
  static void logDisposal(String resourceType, String resourceId) {
    if (_debugEnabled) {
      debugPrint('🗑️ Disposed $resourceType: $resourceId');
    }
  }
  
  /// Log resource creation event  
  static void logCreation(String resourceType, String resourceId) {
    if (_debugEnabled) {
      debugPrint('✨ Created $resourceType: $resourceId');
    }
  }
  
  /// Log potential memory leak
  static void logPotentialLeak(String resourceType, String resourceId) {
    if (_debugEnabled) {
      debugPrint('⚠️ Potential leak in $resourceType: $resourceId');
    }
  }
}