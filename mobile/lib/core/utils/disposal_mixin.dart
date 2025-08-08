import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin that provides common disposal patterns for StatefulWidgets
/// 
/// This mixin helps ensure proper resource cleanup by managing:
/// - StreamSubscriptions
/// - Timers
/// - TextEditingControllers
/// - AnimationControllers
/// - Focus nodes
/// - Custom cleanup functions
mixin DisposalMixin<T extends StatefulWidget> on State<T> {
  // Collections to track resources for automatic disposal
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final List<TextEditingController> _textControllers = [];
  final List<AnimationController> _animationControllers = [];
  final List<FocusNode> _focusNodes = [];
  final List<VoidCallback> _customCleanupFunctions = [];
  
  /// Add a stream subscription to be disposed automatically
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
  
  /// Add a timer to be cancelled automatically
  void addTimer(Timer timer) {
    _timers.add(timer);
  }
  
  /// Add a text controller to be disposed automatically
  void addTextController(TextEditingController controller) {
    _textControllers.add(controller);
  }
  
  /// Add an animation controller to be disposed automatically
  void addAnimationController(AnimationController controller) {
    _animationControllers.add(controller);
  }
  
  /// Add a focus node to be disposed automatically
  void addFocusNode(FocusNode focusNode) {
    _focusNodes.add(focusNode);
  }
  
  /// Add a custom cleanup function to be called during disposal
  void addCleanupFunction(VoidCallback cleanupFunction) {
    _customCleanupFunctions.add(cleanupFunction);
  }
  
  /// Create and register a stream subscription
  StreamSubscription<U> createSubscription<U>(
    Stream<U> stream,
    void Function(U) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    addSubscription(subscription);
    return subscription;
  }
  
  /// Create and register a periodic timer
  Timer createPeriodicTimer(Duration period, void Function(Timer) callback) {
    final timer = Timer.periodic(period, callback);
    addTimer(timer);
    return timer;
  }
  
  /// Create and register a one-time timer
  Timer createTimer(Duration duration, void Function() callback) {
    final timer = Timer(duration, callback);
    addTimer(timer);
    return timer;
  }
  
  /// Create and register a text editing controller
  TextEditingController createTextController({String? text}) {
    final controller = TextEditingController(text: text);
    addTextController(controller);
    return controller;
  }
  
  /// Create and register an animation controller
  AnimationController createAnimationController({
    required Duration duration,
    Duration? reverseDuration,
    String? debugLabel,
    double? value,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
  }) {
    final controller = AnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      value: value,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
      vsync: this as TickerProvider,
    );
    addAnimationController(controller);
    return controller;
  }
  
  /// Create and register a focus node
  FocusNode createFocusNode({
    String? debugLabel,
    FocusOnKeyCallback? onKey,
    bool skipTraversal = false,
    bool canRequestFocus = true,
  }) {
    final focusNode = FocusNode(
      debugLabel: debugLabel,
      onKey: onKey,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
    );
    addFocusNode(focusNode);
    return focusNode;
  }
  
  /// Remove a subscription from tracking (if manually disposed)
  void removeSubscription(StreamSubscription subscription) {
    _subscriptions.remove(subscription);
  }
  
  /// Remove a timer from tracking (if manually cancelled)
  void removeTimer(Timer timer) {
    _timers.remove(timer);
  }
  
  /// Remove a controller from tracking (if manually disposed)
  void removeTextController(TextEditingController controller) {
    _textControllers.remove(controller);
  }
  
  /// Remove an animation controller from tracking (if manually disposed)
  void removeAnimationController(AnimationController controller) {
    _animationControllers.remove(controller);
  }
  
  /// Remove a focus node from tracking (if manually disposed)
  void removeFocusNode(FocusNode focusNode) {
    _focusNodes.remove(focusNode);
  }
  
  /// Dispose all tracked resources
  /// Call this from your widget's dispose() method
  void disposeAll() {
    final widgetName = (this as State).widget.runtimeType.toString();
    
    // Cancel all stream subscriptions
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
        debugPrint('✅ Disposed subscription in $widgetName');
      } catch (e) {
        debugPrint('❌ Error cancelling subscription in $widgetName: $e');
      }
    }
    _subscriptions.clear();
    
    // Cancel all timers
    for (final timer in _timers) {
      try {
        timer.cancel();
        debugPrint('✅ Disposed timer in $widgetName');
      } catch (e) {
        debugPrint('❌ Error cancelling timer in $widgetName: $e');
      }
    }
    _timers.clear();
    
    // Dispose all text controllers
    for (final controller in _textControllers) {
      try {
        controller.dispose();
        debugPrint('✅ Disposed text controller in $widgetName');
      } catch (e) {
        debugPrint('❌ Error disposing text controller in $widgetName: $e');
      }
    }
    _textControllers.clear();
    
    // Dispose all animation controllers
    for (final controller in _animationControllers) {
      try {
        controller.dispose();
        debugPrint('✅ Disposed animation controller in $widgetName');
      } catch (e) {
        debugPrint('❌ Error disposing animation controller in $widgetName: $e');
      }
    }
    _animationControllers.clear();
    
    // Dispose all focus nodes
    for (final focusNode in _focusNodes) {
      try {
        focusNode.dispose();
        debugPrint('✅ Disposed focus node in $widgetName');
      } catch (e) {
        debugPrint('❌ Error disposing focus node in $widgetName: $e');
      }
    }
    _focusNodes.clear();
    
    // Execute all custom cleanup functions
    for (final cleanupFunction in _customCleanupFunctions) {
      try {
        cleanupFunction();
        debugPrint('✅ Executed cleanup function in $widgetName');
      } catch (e) {
        debugPrint('❌ Error executing custom cleanup function in $widgetName: $e');
      }
    }
    _customCleanupFunctions.clear();
    
    debugPrint('🧹 Completed disposal for $widgetName');
  }
  
  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }
}

/// Mixin for providers and services that need disposal
/// 
/// This mixin provides disposal patterns for non-widget classes like:
/// - Services
/// - Providers
/// - Controllers
/// - Repositories
mixin ServiceDisposalMixin {
  // Collections to track resources for automatic disposal
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final List<StreamController> _streamControllers = [];
  final List<VoidCallback> _customCleanupFunctions = [];
  
  /// Add a stream subscription to be disposed automatically
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
  
  /// Add a timer to be cancelled automatically
  void addTimer(Timer timer) {
    _timers.add(timer);
  }
  
  /// Add a stream controller to be disposed automatically
  void addStreamController(StreamController controller) {
    _streamControllers.add(controller);
  }
  
  /// Add a custom cleanup function to be called during disposal
  void addCleanupFunction(VoidCallback cleanupFunction) {
    _customCleanupFunctions.add(cleanupFunction);
  }
  
  /// Create and register a stream subscription
  StreamSubscription<U> createSubscription<U>(
    Stream<U> stream,
    void Function(U) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    addSubscription(subscription);
    return subscription;
  }
  
  /// Create and register a periodic timer
  Timer createPeriodicTimer(Duration period, void Function(Timer) callback) {
    final timer = Timer.periodic(period, callback);
    addTimer(timer);
    return timer;
  }
  
  /// Create and register a one-time timer
  Timer createTimer(Duration duration, void Function() callback) {
    final timer = Timer(duration, callback);
    addTimer(timer);
    return timer;
  }
  
  /// Create and register a stream controller
  StreamController<U> createStreamController<U>({
    bool sync = false,
    void Function()? onListen,
    void Function()? onCancel,
  }) {
    final controller = StreamController<U>(
      sync: sync,
      onListen: onListen,
      onCancel: onCancel,
    );
    addStreamController(controller);
    return controller;
  }
  
  /// Create and register a broadcast stream controller
  StreamController<U> createBroadcastStreamController<U>({
    bool sync = false,
    void Function()? onListen,
    void Function()? onCancel,
  }) {
    final controller = StreamController<U>.broadcast(
      sync: sync,
      onListen: onListen,
      onCancel: onCancel,
    );
    addStreamController(controller);
    return controller;
  }
  
  /// Remove a subscription from tracking (if manually disposed)
  void removeSubscription(StreamSubscription subscription) {
    _subscriptions.remove(subscription);
  }
  
  /// Remove a timer from tracking (if manually cancelled)
  void removeTimer(Timer timer) {
    _timers.remove(timer);
  }
  
  /// Remove a stream controller from tracking (if manually disposed)
  void removeStreamController(StreamController controller) {
    _streamControllers.remove(controller);
  }
  
  /// Dispose all tracked resources
  /// Call this from your service's dispose() method
  void disposeAll() {
    // Cancel all stream subscriptions
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        debugPrint('Error cancelling subscription: $e');
      }
    }
    _subscriptions.clear();
    
    // Cancel all timers
    for (final timer in _timers) {
      try {
        timer.cancel();
      } catch (e) {
        debugPrint('Error cancelling timer: $e');
      }
    }
    _timers.clear();
    
    // Close all stream controllers
    for (final controller in _streamControllers) {
      try {
        if (!controller.isClosed) {
          controller.close();
        }
      } catch (e) {
        debugPrint('Error closing stream controller: $e');
      }
    }
    _streamControllers.clear();
    
    // Execute all custom cleanup functions
    for (final cleanupFunction in _customCleanupFunctions) {
      try {
        cleanupFunction();
      } catch (e) {
        debugPrint('Error executing custom cleanup function: $e');
      }
    }
    _customCleanupFunctions.clear();
  }
  
  /// Dispose method to be called when the service is no longer needed
  void dispose() {
    disposeAll();
  }
}

/// Utility class for disposal testing and debugging
class DisposalTracker {
  static final Map<String, int> _createdResources = {};
  static final Map<String, int> _disposedResources = {};
  
  /// Track resource creation
  static void trackCreation(String resourceType) {
    _createdResources[resourceType] = (_createdResources[resourceType] ?? 0) + 1;
  }
  
  /// Track resource disposal
  static void trackDisposal(String resourceType) {
    _disposedResources[resourceType] = (_disposedResources[resourceType] ?? 0) + 1;
  }
  
  /// Get current resource counts
  static Map<String, Map<String, int>> getResourceCounts() {
    return {
      'created': Map.from(_createdResources),
      'disposed': Map.from(_disposedResources),
    };
  }
  
  /// Get potential memory leaks (created but not disposed resources)
  static Map<String, int> getPotentialLeaks() {
    final leaks = <String, int>{};
    for (final type in _createdResources.keys) {
      final created = _createdResources[type] ?? 0;
      final disposed = _disposedResources[type] ?? 0;
      if (created > disposed) {
        leaks[type] = created - disposed;
      }
    }
    return leaks;
  }
  
  /// Reset tracking counters
  static void reset() {
    _createdResources.clear();
    _disposedResources.clear();
  }
  
  /// Print disposal summary
  static void printSummary() {
    debugPrint('=== Disposal Tracker Summary ===');
    debugPrint('Created resources: $_createdResources');
    debugPrint('Disposed resources: $_disposedResources');
    
    final leaks = getPotentialLeaks();
    if (leaks.isNotEmpty) {
      debugPrint('⚠️ Potential memory leaks: $leaks');
    } else {
      debugPrint('✅ No potential memory leaks detected');
    }
    debugPrint('===============================');
  }
}