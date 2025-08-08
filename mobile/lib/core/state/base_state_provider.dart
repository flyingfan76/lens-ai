import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/disposal_mixin.dart';
import '../utils/error_handler.dart';
import '../utils/lens_exceptions.dart';

/// Base class for all state providers in the Lens AI app
/// 
/// Provides unified patterns for:
/// - Error state management
/// - Loading state management  
/// - Reactive state updates
/// - Resource disposal
/// - Performance optimization
abstract class BaseStateProvider with ChangeNotifier, ServiceDisposalMixin, ErrorHandlerMixin {
  // Loading state management
  bool _isLoading = false;
  String _loadingMessage = '';
  
  // Error state management
  LensException? _lastError;
  bool _hasError = false;
  String _errorMessage = '';
  
  // State tracking
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Performance optimization
  bool _notifyEnabled = true;
  Timer? _batchNotificationTimer;
  
  // Getters for common state
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  LensException? get lastError => _lastError;
  bool get isInitialized => _isInitialized;
  bool get isDisposed => _isDisposed;
  
  /// Initialize the provider state
  /// Subclasses should override this method to perform initialization
  @protected
  Future<void> initializeState() async {
    // Override in subclasses
  }
  
  /// Initialize the provider
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize disposed provider');
    }
    
    if (_isInitialized) {
      return; // Already initialized
    }
    
    await setLoadingState(true, 'Initializing...');
    
    try {
      await initializeState();
      _clearError();
      _isInitialized = true;
    } catch (e, stackTrace) {
      final error = e is LensException 
        ? e 
        : LensException.now(
            message: 'Initialization failed',
            category: 'Provider',
            details: e.toString(),
            originalError: e,
            stackTrace: stackTrace,
          );
      _setError(error);
    } finally {
      await setLoadingState(false);
    }
  }
  
  /// Set loading state with optional message
  Future<void> setLoadingState(bool loading, [String message = '']) async {
    if (_isDisposed) return;
    
    if (_isLoading != loading || _loadingMessage != message) {
      _isLoading = loading;
      _loadingMessage = message;
      _scheduleNotification();
    }
  }
  
  /// Set error state
  @protected
  void _setError(LensException error) {
    if (_isDisposed) return;
    
    _hasError = true;
    _lastError = error;
    _errorMessage = error.userMessage;
    _scheduleNotification();
    
    // Log error for debugging
    debugPrint('${runtimeType} Error: ${error.message}');
    if (error.details != null) {
      debugPrint('Details: ${error.details}');
    }
  }
  
  /// Clear error state
  @protected
  void _clearError() {
    if (_isDisposed) return;
    
    if (_hasError) {
      _hasError = false;
      _lastError = null;
      _errorMessage = '';
      _scheduleNotification();
    }
  }
  
  /// Execute operation with unified error handling
  Future<T?> executeWithErrorHandling<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? fallbackValue,
    bool clearErrorOnSuccess = true,
    bool showLoadingState = false,
    String loadingMessage = 'Processing...',
  }) async {
    if (_isDisposed) return fallbackValue;
    
    try {
      if (showLoadingState) {
        await setLoadingState(true, loadingMessage);
      }
      
      final result = await operation();
      
      if (clearErrorOnSuccess) {
        _clearError();
      }
      
      return result;
    } catch (e, stackTrace) {
      final error = e is LensException 
        ? e 
        : LensException.now(
            message: operationName != null 
              ? 'Failed to $operationName' 
              : 'Operation failed',
            category: 'Provider',
            details: e.toString(),
            originalError: e,
            stackTrace: stackTrace,
          );
      
      _setError(error);
      return fallbackValue;
    } finally {
      if (showLoadingState) {
        await setLoadingState(false);
      }
    }
  }
  
  /// Batch state updates for performance
  @protected
  void batchStateUpdates(VoidCallback updates) {
    if (_isDisposed) return;
    
    _notifyEnabled = false;
    try {
      updates();
    } finally {
      _notifyEnabled = true;
      _scheduleNotification();
    }
  }
  
  /// Schedule notification to batch updates
  void _scheduleNotification() {
    if (_isDisposed || !_notifyEnabled) {
      return;
    }
    
    if (_batchNotificationTimer?.isActive == true) {
      // Timer already active, notification will be sent
      return;
    }
    
    _batchNotificationTimer = Timer(const Duration(milliseconds: 16), () {
      if (!_isDisposed) {
        super.notifyListeners();
      }
    });
    
    addCleanupFunction(() => _batchNotificationTimer?.cancel());
  }
  
  /// Override notifyListeners to use batching
  @override
  void notifyListeners() {
    _scheduleNotification();
  }
  
  /// Validate state before operations
  @protected
  bool validateState({bool requireInitialized = true}) {
    if (_isDisposed) {
      _setError(LensException.now(
        message: 'Provider is disposed',
        category: 'Provider',
        details: 'Cannot perform operations on disposed provider',
      ));
      return false;
    }
    
    if (requireInitialized && !_isInitialized) {
      _setError(LensException.now(
        message: 'Provider not initialized',
        category: 'Provider',
        details: 'Call initialize() before using provider',
      ));
      return false;
    }
    
    return true;
  }
  
  /// Reset provider to initial state
  void resetState() {
    if (_isDisposed) return;
    
    batchStateUpdates(() {
      _isLoading = false;
      _loadingMessage = '';
      _clearError();
      // Don't reset _isInitialized as that requires re-calling initialize()
    });
  }
  
  /// Get current state summary for debugging
  @protected
  Map<String, dynamic> getStateSnapshot() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'loadingMessage': _loadingMessage,
      'hasError': _hasError,
      'errorMessage': _errorMessage,
      'isDisposed': _isDisposed,
      'runtimeType': runtimeType.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _batchNotificationTimer?.cancel();
    
    // ServiceDisposalMixin handles other cleanup
    super.dispose();
  }
}

/// Mixin for providers that need periodic state updates
mixin PeriodicStateMixin<T extends BaseStateProvider> on BaseStateProvider {
  Timer? _periodicTimer;
  Duration _updateInterval = const Duration(seconds: 5);
  bool _periodicUpdatesEnabled = false;
  
  /// Override to define what happens during periodic updates
  @protected
  Future<void> performPeriodicUpdate();
  
  /// Start periodic updates
  @protected
  void startPeriodicUpdates({Duration? interval}) {
    if (_isDisposed) return;
    
    _updateInterval = interval ?? _updateInterval;
    _periodicUpdatesEnabled = true;
    
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_updateInterval, (timer) async {
      if (_isDisposed || !_periodicUpdatesEnabled) {
        timer.cancel();
        return;
      }
      
      try {
        await performPeriodicUpdate();
      } catch (e) {
        debugPrint('Periodic update failed: $e');
      }
    });
    
    addCleanupFunction(() {
      _periodicTimer?.cancel();
      _periodicUpdatesEnabled = false;
    });
  }
  
  /// Stop periodic updates
  @protected
  void stopPeriodicUpdates() {
    _periodicUpdatesEnabled = false;
    _periodicTimer?.cancel();
  }
  
  @override
  void dispose() {
    stopPeriodicUpdates();
    super.dispose();
  }
}

/// Mixin for providers that need to persist state
mixin StatePersistenceMixin<T extends BaseStateProvider> on BaseStateProvider {
  /// Override to return state data that should be persisted
  Map<String, dynamic> getPersistedState();
  
  /// Override to restore state from persisted data
  Future<void> restorePersistedState(Map<String, dynamic> state);
  
  /// Override to return the storage key for this provider
  @protected
  String get persistenceKey;
  
  /// Save current state (implementation depends on storage mechanism)
  @protected
  Future<void> saveState() async {
    // To be implemented by concrete providers with specific storage mechanism
  }
  
  /// Load saved state (implementation depends on storage mechanism)  
  @protected
  Future<void> loadState() async {
    // To be implemented by concrete providers with specific storage mechanism
  }
}