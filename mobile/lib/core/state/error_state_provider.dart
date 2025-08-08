import 'dart:async';
import 'package:flutter/foundation.dart';
import 'base_state_provider.dart';
import '../utils/lens_exceptions.dart';
import '../utils/error_logger.dart';

/// Global error state provider for unified error handling
/// 
/// Provides centralized error management including:
/// - Error collection and aggregation from all providers
/// - Error categorization and prioritization
/// - Error recovery strategies
/// - Error reporting and analytics
/// - User-friendly error display
class ErrorStateProvider extends BaseStateProvider {
  // Error collection
  final Map<String, LensException> _currentErrors = {};
  final List<ErrorEntry> _errorHistory = [];
  final Map<String, int> _errorCounts = {};
  
  // Error categorization
  final Map<ErrorSeverity, List<String>> _errorsBySeverity = {
    ErrorSeverity.low: [],
    ErrorSeverity.medium: [],
    ErrorSeverity.high: [],
    ErrorSeverity.critical: [],
  };
  
  // Error recovery
  final Map<String, Function()> _recoveryActions = {};
  bool _autoRecoveryEnabled = true;
  int _maxRecoveryAttempts = 3;
  final Map<String, int> _recoveryAttempts = {};
  
  // Error display
  bool _showErrorBanner = false;
  String _currentErrorMessage = '';
  ErrorSeverity _currentErrorSeverity = ErrorSeverity.low;
  bool _userDismissedBanner = false;
  
  // Error reporting
  bool _errorReportingEnabled = true;
  bool _autoReportCriticalErrors = true;
  
  // Error filtering
  Set<String> _suppressedErrorTypes = {};
  Set<String> _temporarilyIgnoredErrors = {};
  Timer? _errorSuppressionTimer;
  
  // Analytics and metrics
  Map<String, dynamic> _errorMetrics = {
    'totalErrors': 0,
    'criticalErrors': 0,
    'resolvedErrors': 0,
    'suppressedErrors': 0,
    'averageResolutionTime': 0.0,
  };
  
  // Registered providers for error monitoring
  final Map<String, BaseStateProvider> _monitoredProviders = {};
  final Map<String, StreamSubscription?> _providerSubscriptions = {};
  
  // Getters
  Map<String, LensException> get currentErrors => Map.from(_currentErrors);
  List<ErrorEntry> get errorHistory => List.from(_errorHistory);
  Map<String, int> get errorCounts => Map.from(_errorCounts);
  Map<ErrorSeverity, List<String>> get errorsBySeverity => Map.from(_errorsBySeverity);
  
  bool get showErrorBanner => _showErrorBanner;
  String get currentErrorMessage => _currentErrorMessage;
  ErrorSeverity get currentErrorSeverity => _currentErrorSeverity;
  bool get userDismissedBanner => _userDismissedBanner;
  
  bool get errorReportingEnabled => _errorReportingEnabled;
  bool get autoRecoveryEnabled => _autoRecoveryEnabled;
  int get maxRecoveryAttempts => _maxRecoveryAttempts;
  
  Map<String, dynamic> get errorMetrics => Map.from(_errorMetrics);
  Set<String> get suppressedErrorTypes => Set.from(_suppressedErrorTypes);
  
  bool get hasActiveErrors => _currentErrors.isNotEmpty;
  bool get hasCriticalErrors => _errorsBySeverity[ErrorSeverity.critical]?.isNotEmpty ?? false;
  int get activeErrorCount => _currentErrors.length;
  
  @override
  Future<void> initializeState() async {
    // Initialize error logger
    await ErrorLogger.instance.initialize();
    
    // Load suppressed error types from persistence
    _loadSuppressionSettings();
  }
  
  /// Register a provider for error monitoring
  void registerProviderForMonitoring(String providerId, BaseStateProvider provider) {
    if (_monitoredProviders.containsKey(providerId)) {
      unregisterProviderFromMonitoring(providerId);
    }
    
    _monitoredProviders[providerId] = provider;
    
    // Listen for errors from this provider
    provider.addListener(() {
      if (provider.hasError && provider.lastError != null) {
        reportError(
          provider.lastError!,
          source: providerId,
        );
      }
    });
    
    addCleanupFunction(() => unregisterProviderFromMonitoring(providerId));
  }
  
  /// Unregister a provider from error monitoring
  void unregisterProviderFromMonitoring(String providerId) {
    _providerSubscriptions[providerId]?.cancel();
    _providerSubscriptions.remove(providerId);
    _monitoredProviders.remove(providerId);
  }
  
  /// Report an error to the global error handler
  void reportError(
    Exception error, {
    String? source,
    Map<String, dynamic>? context,
    bool shouldDisplay = true,
    bool canRecover = false,
    Function()? recoveryAction,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    final lensError = error is LensException 
        ? error 
        : LensException.now(
            message: 'Unexpected error occurred',
            category: 'Error',
            details: error.toString(),
            originalError: error,
          );
    
    final errorId = _generateErrorId(lensError, source);
    
    // Check if this error should be suppressed
    if (_shouldSuppressError(errorId, lensError)) {
      _errorMetrics['suppressedErrors'] = 
          (_errorMetrics['suppressedErrors'] ?? 0) + 1;
      return;
    }
    
    // Create error entry
    final errorEntry = ErrorEntry(
      id: errorId,
      error: lensError,
      source: source ?? 'unknown',
      context: context ?? {},
      timestamp: DateTime.now(),
      severity: _determineSeverity(lensError),
      canRecover: canRecover,
    );
    
    // Add to current errors if not already present
    if (!_currentErrors.containsKey(errorId)) {
      _currentErrors[errorId] = lensError;
      
      // Add to history
      _errorHistory.add(errorEntry);
      
      // Update error counts
      _errorCounts[errorId] = (_errorCounts[errorId] ?? 0) + 1;
      
      // Categorize by severity
      _errorsBySeverity[errorEntry.severity]?.add(errorId);
      
      // Store recovery action
      if (recoveryAction != null) {
        _recoveryActions[errorId] = recoveryAction;
      }
      
      // Update metrics
      _updateErrorMetrics(errorEntry);
      
      // Log error
      _logError(errorEntry);
      
      // Display error if needed
      if (shouldDisplay) {
        _displayError(errorEntry);
      }
      
      // Attempt auto-recovery
      if (_autoRecoveryEnabled && canRecover) {
        _attemptRecovery(errorId);
      }
      
      // Report to analytics
      if (_errorReportingEnabled) {
        _reportToAnalytics(errorEntry);
      }
      
      notifyListeners();
    }
  }
  
  /// Resolve an error
  void resolveError(String errorId, {String? resolution}) {
    if (!_currentErrors.containsKey(errorId)) return;
    
    final error = _currentErrors[errorId];
    if (error == null) return;
    
    batchStateUpdates(() {
      // Remove from current errors
      _currentErrors.remove(errorId);
      
      // Remove from severity categorization
      for (final severityErrors in _errorsBySeverity.values) {
        severityErrors.remove(errorId);
      }
      
      // Clean up recovery action
      _recoveryActions.remove(errorId);
      _recoveryAttempts.remove(errorId);
      
      // Update history with resolution
      final historyEntry = _errorHistory
          .where((e) => e.id == errorId)
          .lastOrNull;
      
      if (historyEntry != null) {
        historyEntry.resolvedAt = DateTime.now();
        historyEntry.resolution = resolution;
        historyEntry.resolutionTime = historyEntry.resolvedAt!
            .difference(historyEntry.timestamp)
            .inMilliseconds;
      }
      
      // Update metrics
      _errorMetrics['resolvedErrors'] = 
          (_errorMetrics['resolvedErrors'] ?? 0) + 1;
      
      // Update banner if this was the displayed error
      if (_showErrorBanner && _currentErrorMessage.contains(error.userMessage)) {
        _hideErrorBanner();
      }
    });
    
    debugPrint('Resolved error: $errorId ${resolution ?? ''}');
    notifyListeners();
  }
  
  /// Resolve all current errors
  void resolveAllErrors({String? resolution}) {
    final errorIds = _currentErrors.keys.toList();
    for (final errorId in errorIds) {
      resolveError(errorId, resolution: resolution);
    }
  }
  
  /// Suppress error type temporarily
  void suppressErrorType(
    String errorType, {
    Duration? duration = const Duration(minutes: 30),
  }) {
    _suppressedErrorTypes.add(errorType);
    
    if (duration != null) {
      _errorSuppressionTimer?.cancel();
      _errorSuppressionTimer = Timer(duration, () {
        _suppressedErrorTypes.remove(errorType);
        notifyListeners();
      });
      
      addCleanupFunction(() => _errorSuppressionTimer?.cancel());
    }
    
    debugPrint('Suppressed error type: $errorType for ${duration?.inMinutes} minutes');
    notifyListeners();
  }
  
  /// Ignore specific error temporarily
  void ignoreErrorTemporarily(String errorId, Duration duration) {
    _temporarilyIgnoredErrors.add(errorId);
    
    Timer(duration, () {
      _temporarilyIgnoredErrors.remove(errorId);
    });
    
    // Hide from current errors temporarily
    if (_currentErrors.containsKey(errorId)) {
      _currentErrors.remove(errorId);
      notifyListeners();
    }
  }
  
  /// Attempt error recovery
  Future<bool> _attemptRecovery(String errorId) async {
    final attempts = _recoveryAttempts[errorId] ?? 0;
    if (attempts >= _maxRecoveryAttempts) {
      debugPrint('Max recovery attempts reached for error: $errorId');
      return false;
    }
    
    final recoveryAction = _recoveryActions[errorId];
    if (recoveryAction == null) {
      debugPrint('No recovery action available for error: $errorId');
      return false;
    }
    
    try {
      _recoveryAttempts[errorId] = attempts + 1;
      
      debugPrint('Attempting recovery for error: $errorId (attempt ${attempts + 1})');
      recoveryAction();
      
      // Check if recovery was successful (error should be resolved)
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_currentErrors.containsKey(errorId)) {
        debugPrint('Recovery successful for error: $errorId');
        return true;
      } else {
        debugPrint('Recovery failed for error: $errorId');
        return false;
      }
    } catch (e) {
      debugPrint('Recovery action failed for error $errorId: $e');
      return false;
    }
  }
  
  /// Retry recovery for an error
  Future<bool> retryRecovery(String errorId) async {
    _recoveryAttempts[errorId] = 0; // Reset attempts
    return await _attemptRecovery(errorId);
  }
  
  /// Display error to user
  void _displayError(ErrorEntry errorEntry) {
    // Only show banner for medium+ severity errors
    if (errorEntry.severity.index >= ErrorSeverity.medium.index) {
      _showErrorBanner = true;
      _currentErrorMessage = errorEntry.error.userMessage;
      _currentErrorSeverity = errorEntry.severity;
      _userDismissedBanner = false;
      
      // Auto-hide banner for non-critical errors
      if (errorEntry.severity != ErrorSeverity.critical) {
        Timer(const Duration(seconds: 10), () {
          if (!_userDismissedBanner) {
            _hideErrorBanner();
          }
        });
      }
    }
  }
  
  /// Hide error banner
  void _hideErrorBanner() {
    _showErrorBanner = false;
    _currentErrorMessage = '';
    _currentErrorSeverity = ErrorSeverity.low;
    notifyListeners();
  }
  
  /// Dismiss error banner (user action)
  void dismissErrorBanner() {
    _userDismissedBanner = true;
    _hideErrorBanner();
  }
  
  /// Determine error severity
  ErrorSeverity _determineSeverity(LensException error) {
    // Determine severity based on error type and characteristics
    if (error is CameraConnectionException || 
        error is CameraInitializationException) {
      return ErrorSeverity.high;
    }
    
    if (error is CameraCaptureException) {
      return ErrorSeverity.medium;
    }
    
    if (error is CameraPermissionException) {
      return ErrorSeverity.critical;
    }
    
    // Default based on error message content
    final message = error.message.toLowerCase();
    if (message.contains('critical') || 
        message.contains('fatal') ||
        message.contains('permission')) {
      return ErrorSeverity.critical;
    } else if (message.contains('failed') || 
               message.contains('error') ||
               message.contains('timeout')) {
      return ErrorSeverity.high;
    } else if (message.contains('warning') || 
               message.contains('retry')) {
      return ErrorSeverity.medium;
    }
    
    return ErrorSeverity.low;
  }
  
  /// Generate unique error ID
  String _generateErrorId(LensException error, String? source) {
    final components = [
      source ?? 'unknown',
      error.runtimeType.toString(),
      error.message,
    ];
    
    return components.join('_').hashCode.abs().toString();
  }
  
  /// Check if error should be suppressed
  bool _shouldSuppressError(String errorId, LensException error) {
    // Check if error type is suppressed
    if (_suppressedErrorTypes.contains(error.runtimeType.toString())) {
      return true;
    }
    
    // Check if specific error is temporarily ignored
    if (_temporarilyIgnoredErrors.contains(errorId)) {
      return true;
    }
    
    // Check if error count exceeds threshold (avoid spam)
    final count = _errorCounts[errorId] ?? 0;
    if (count > 10) {
      return true;
    }
    
    return false;
  }
  
  /// Log error
  void _logError(ErrorEntry errorEntry) {
    ErrorLogger.logError(
      errorEntry.error,
      source: errorEntry.source,
      context: errorEntry.context,
      severity: errorEntry.severity.index,
    );
  }
  
  /// Report error to analytics
  void _reportToAnalytics(ErrorEntry errorEntry) {
    // This would integrate with actual analytics service
    if (_errorReportingEnabled && 
        (errorEntry.severity == ErrorSeverity.critical || _autoReportCriticalErrors)) {
      
      debugPrint('Reporting error to analytics: ${errorEntry.id}');
      
      // Analytics reporting would happen here
      // For now, just log
      if (kDebugMode) {
        debugPrint('Analytics Report: ${errorEntry.toMap()}');
      }
    }
  }
  
  /// Update error metrics
  void _updateErrorMetrics(ErrorEntry errorEntry) {
    _errorMetrics['totalErrors'] = (_errorMetrics['totalErrors'] ?? 0) + 1;
    
    if (errorEntry.severity == ErrorSeverity.critical) {
      _errorMetrics['criticalErrors'] = (_errorMetrics['criticalErrors'] ?? 0) + 1;
    }
    
    // Update average resolution time
    final resolvedEntries = _errorHistory
        .where((e) => e.resolvedAt != null && e.resolutionTime != null);
    
    if (resolvedEntries.isNotEmpty) {
      final totalTime = resolvedEntries
          .fold<int>(0, (sum, e) => sum + (e.resolutionTime ?? 0));
      _errorMetrics['averageResolutionTime'] = totalTime / resolvedEntries.length;
    }
  }
  
  /// Load suppression settings
  void _loadSuppressionSettings() {
    // This would load from persistent storage
    // For now, use defaults
  }
  
  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final last7d = now.subtract(const Duration(days: 7));
    
    final recent24h = _errorHistory.where((e) => e.timestamp.isAfter(last24h));
    final recent7d = _errorHistory.where((e) => e.timestamp.isAfter(last7d));
    
    return {
      'totalErrors': _errorHistory.length,
      'activeErrors': _currentErrors.length,
      'resolvedErrors': _errorHistory.where((e) => e.resolvedAt != null).length,
      'criticalErrors': _errorHistory
          .where((e) => e.severity == ErrorSeverity.critical).length,
      'last24hours': recent24h.length,
      'last7days': recent7d.length,
      'errorsBySource': _groupErrorsBySource(),
      'errorsBySeverity': _errorsBySeverity.map((k, v) => MapEntry(k.name, v.length)),
      'averageResolutionTime': _errorMetrics['averageResolutionTime'] ?? 0.0,
      'suppressedTypes': _suppressedErrorTypes.toList(),
    };
  }
  
  /// Group errors by source
  Map<String, int> _groupErrorsBySource() {
    final bySource = <String, int>{};
    
    for (final entry in _errorHistory) {
      bySource[entry.source] = (bySource[entry.source] ?? 0) + 1;
    }
    
    return bySource;
  }
  
  /// Clear error history
  void clearErrorHistory({bool keepActive = true}) {
    if (keepActive) {
      _errorHistory.removeWhere((e) => e.resolvedAt != null);
    } else {
      _errorHistory.clear();
      if (!keepActive) {
        _currentErrors.clear();
        for (final severityErrors in _errorsBySeverity.values) {
          severityErrors.clear();
        }
      }
    }
    
    _errorCounts.clear();
    notifyListeners();
  }
  
  /// Export error report
  Map<String, dynamic> exportErrorReport() {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'statistics': getErrorStatistics(),
      'currentErrors': _currentErrors.map((k, v) => MapEntry(k, v.toMap())),
      'errorHistory': _errorHistory.map((e) => e.toMap()).toList(),
      'metrics': _errorMetrics,
      'configuration': {
        'autoRecoveryEnabled': _autoRecoveryEnabled,
        'maxRecoveryAttempts': _maxRecoveryAttempts,
        'errorReportingEnabled': _errorReportingEnabled,
        'autoReportCriticalErrors': _autoReportCriticalErrors,
      },
    };
  }
  
  // Configuration methods
  
  void setAutoRecoveryEnabled(bool enabled) {
    _autoRecoveryEnabled = enabled;
    notifyListeners();
  }
  
  void setMaxRecoveryAttempts(int attempts) {
    _maxRecoveryAttempts = attempts.clamp(1, 10);
    notifyListeners();
  }
  
  void setErrorReportingEnabled(bool enabled) {
    _errorReportingEnabled = enabled;
    notifyListeners();
  }
  
  void setAutoReportCriticalErrors(bool enabled) {
    _autoReportCriticalErrors = enabled;
    notifyListeners();
  }
  
  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _providerSubscriptions.values) {
      subscription?.cancel();
    }
    
    _errorSuppressionTimer?.cancel();
    super.dispose();
  }
}

/// Error severity levels
enum ErrorSeverity {
  low,      // Minor issues, info messages
  medium,   // Warnings, recoverable errors
  high,     // Significant errors affecting functionality
  critical, // System-breaking errors requiring immediate attention
}

/// Error entry for tracking
class ErrorEntry {
  final String id;
  final LensException error;
  final String source;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final bool canRecover;
  
  DateTime? resolvedAt;
  String? resolution;
  int? resolutionTime;
  
  ErrorEntry({
    required this.id,
    required this.error,
    required this.source,
    required this.context,
    required this.timestamp,
    required this.severity,
    required this.canRecover,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'error': error.toMap(),
      'source': source,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'canRecover': canRecover,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolution': resolution,
      'resolutionTime': resolutionTime,
    };
  }
}