import 'dart:async';
import 'package:flutter/material.dart';
import 'base_state_provider.dart';

/// UI state provider for transient UI state management
/// 
/// Manages ephemeral UI state including:
/// - Loading states and progress indicators
/// - Dialog and modal states
/// - Animation states and transitions
/// - Toast and snackbar messages
/// - Navigation and overlay states
class UIStateProvider extends BaseStateProvider {
  // Loading states
  Map<String, bool> _loadingStates = {};
  Map<String, String> _loadingMessages = {};
  Map<String, double?> _loadingProgress = {};
  
  // Dialog states
  Map<String, bool> _dialogStates = {};
  Map<String, Map<String, dynamic>> _dialogData = {};
  
  // Animation states
  Map<String, bool> _animationStates = {};
  Map<String, AnimationController?> _animationControllers = {};
  
  // Toast and snackbar states
  List<Map<String, dynamic>> _toastQueue = [];
  List<Map<String, dynamic>> _snackbarQueue = [];
  bool _toastVisible = false;
  bool _snackbarVisible = false;
  
  // Navigation states
  String _currentBottomNavTab = 'camera';
  Map<String, dynamic> _navigationParams = {};
  List<String> _navigationStack = [];
  bool _canPop = false;
  
  // Overlay states
  Map<String, bool> _overlayStates = {};
  Map<String, Widget?> _overlayWidgets = {};
  
  // Keyboard and input states
  bool _keyboardVisible = false;
  double _keyboardHeight = 0.0;
  String _focusedInput = '';
  
  // Screen states
  Orientation _screenOrientation = Orientation.portrait;
  Size _screenSize = Size.zero;
  EdgeInsets _screenPadding = EdgeInsets.zero;
  bool _isTablet = false;
  
  // Theme and visual states
  Brightness _systemBrightness = Brightness.light;
  double _devicePixelRatio = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  
  // Timers for auto-dismiss functionality
  Map<String, Timer> _autoCloseTimers = {};
  
  // Getters - Loading states
  Map<String, bool> get loadingStates => Map.from(_loadingStates);
  Map<String, String> get loadingMessages => Map.from(_loadingMessages);
  Map<String, double?> get loadingProgress => Map.from(_loadingProgress);
  
  // Getters - Dialog states
  Map<String, bool> get dialogStates => Map.from(_dialogStates);
  Map<String, Map<String, dynamic>> get dialogData => Map.from(_dialogData);
  
  // Getters - Animation states
  Map<String, bool> get animationStates => Map.from(_animationStates);
  
  // Getters - Toast and snackbar
  List<Map<String, dynamic>> get toastQueue => List.from(_toastQueue);
  List<Map<String, dynamic>> get snackbarQueue => List.from(_snackbarQueue);
  bool get toastVisible => _toastVisible;
  bool get snackbarVisible => _snackbarVisible;
  
  // Getters - Navigation
  String get currentBottomNavTab => _currentBottomNavTab;
  Map<String, dynamic> get navigationParams => Map.from(_navigationParams);
  List<String> get navigationStack => List.from(_navigationStack);
  bool get canPop => _canPop;
  
  // Getters - Overlays
  Map<String, bool> get overlayStates => Map.from(_overlayStates);
  Map<String, Widget?> get overlayWidgets => Map.from(_overlayWidgets);
  
  // Getters - Keyboard and input
  bool get keyboardVisible => _keyboardVisible;
  double get keyboardHeight => _keyboardHeight;
  String get focusedInput => _focusedInput;
  
  // Getters - Screen
  Orientation get screenOrientation => _screenOrientation;
  Size get screenSize => _screenSize;
  EdgeInsets get screenPadding => _screenPadding;
  bool get isTablet => _isTablet;
  
  // Getters - Theme and visual
  Brightness get systemBrightness => _systemBrightness;
  double get devicePixelRatio => _devicePixelRatio;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  
  @override
  Future<void> initializeState() async {
    // Initialize with default states
    _currentBottomNavTab = 'camera';
    _navigationStack = ['/'];
  }
  
  // Loading state management
  
  /// Set loading state for a specific component
  void setComponentLoadingState(
    String key, 
    bool loading, {
    String? message,
    double? progress,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    batchStateUpdates(() {
      _loadingStates[key] = loading;
      
      if (message != null) {
        _loadingMessages[key] = message;
      } else if (!loading) {
        _loadingMessages.remove(key);
      }
      
      if (progress != null) {
        _loadingProgress[key] = progress;
      } else if (!loading) {
        _loadingProgress.remove(key);
      }
      
      // Clean up if not loading
      if (!loading) {
        _loadingStates.remove(key);
        _loadingMessages.remove(key);
        _loadingProgress.remove(key);
      }
    });
  }
  
  /// Check if specific component is loading
  bool isComponentLoading(String key) {
    return _loadingStates[key] ?? false;
  }
  
  /// Check if any component is loading
  bool get isAnyLoading => _loadingStates.values.any((loading) => loading);
  
  /// Get loading message for component
  String? getLoadingMessage(String key) {
    return _loadingMessages[key];
  }
  
  /// Get loading progress for component
  double? getLoadingProgress(String key) {
    return _loadingProgress[key];
  }
  
  /// Clear all loading states
  void clearAllLoading() {
    if (_loadingStates.isNotEmpty || 
        _loadingMessages.isNotEmpty || 
        _loadingProgress.isNotEmpty) {
      batchStateUpdates(() {
        _loadingStates.clear();
        _loadingMessages.clear();
        _loadingProgress.clear();
      });
    }
  }
  
  // Dialog state management
  
  /// Show dialog with optional data
  void showDialog(
    String dialogId, {
    Map<String, dynamic>? data,
    Duration? autoCloseAfter,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    batchStateUpdates(() {
      _dialogStates[dialogId] = true;
      if (data != null) {
        _dialogData[dialogId] = data;
      }
    });
    
    // Set auto-close timer if specified
    if (autoCloseAfter != null) {
      _setAutoCloseTimer(dialogId, autoCloseAfter, () => hideDialog(dialogId));
    }
  }
  
  /// Hide dialog
  void hideDialog(String dialogId) {
    if (!validateState(requireInitialized: false)) return;
    
    if (_dialogStates[dialogId] == true) {
      batchStateUpdates(() {
        _dialogStates.remove(dialogId);
        _dialogData.remove(dialogId);
      });
      
      _cancelAutoCloseTimer(dialogId);
    }
  }
  
  /// Check if dialog is visible
  bool isDialogVisible(String dialogId) {
    return _dialogStates[dialogId] ?? false;
  }
  
  /// Get dialog data
  Map<String, dynamic>? getDialogData(String dialogId) {
    return _dialogData[dialogId];
  }
  
  /// Hide all dialogs
  void hideAllDialogs() {
    if (_dialogStates.isNotEmpty) {
      final dialogIds = _dialogStates.keys.toList();
      batchStateUpdates(() {
        _dialogStates.clear();
        _dialogData.clear();
      });
      
      // Cancel all auto-close timers
      for (final id in dialogIds) {
        _cancelAutoCloseTimer(id);
      }
    }
  }
  
  // Animation state management
  
  /// Start animation
  void startAnimation(
    String animationId, {
    AnimationController? controller,
    Duration? duration,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    batchStateUpdates(() {
      _animationStates[animationId] = true;
      if (controller != null) {
        _animationControllers[animationId] = controller;
      }
    });
    
    // Auto-stop animation after duration
    if (duration != null) {
      _setAutoCloseTimer(
        'animation_$animationId', 
        duration, 
        () => stopAnimation(animationId),
      );
    }
  }
  
  /// Stop animation
  void stopAnimation(String animationId) {
    if (!validateState(requireInitialized: false)) return;
    
    if (_animationStates[animationId] == true) {
      batchStateUpdates(() {
        _animationStates.remove(animationId);
        
        // Dispose controller if we own it
        final controller = _animationControllers[animationId];
        if (controller != null) {
          controller.dispose();
          _animationControllers.remove(animationId);
        }
      });
      
      _cancelAutoCloseTimer('animation_$animationId');
    }
  }
  
  /// Check if animation is running
  bool isAnimationRunning(String animationId) {
    return _animationStates[animationId] ?? false;
  }
  
  /// Get animation controller
  AnimationController? getAnimationController(String animationId) {
    return _animationControllers[animationId];
  }
  
  // Toast and snackbar management
  
  /// Show toast message
  void showToast(
    String message, {
    Duration duration = const Duration(seconds: 3),
    ToastType type = ToastType.info,
    Map<String, dynamic>? data,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    final toast = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'message': message,
      'type': type.name,
      'duration': duration,
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _toastQueue.add(toast);
    notifyListeners();
    
    // Process toast queue
    _processToastQueue();
  }
  
  /// Show snackbar message
  void showSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackbarType type = SnackbarType.info,
    String? actionLabel,
    VoidCallback? actionCallback,
    Map<String, dynamic>? data,
  }) {
    if (!validateState(requireInitialized: false)) return;
    
    final snackbar = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'message': message,
      'type': type.name,
      'duration': duration,
      'actionLabel': actionLabel,
      'actionCallback': actionCallback,
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _snackbarQueue.add(snackbar);
    notifyListeners();
    
    // Process snackbar queue
    _processSnackbarQueue();
  }
  
  /// Process toast queue
  void _processToastQueue() {
    if (_toastVisible || _toastQueue.isEmpty) return;
    
    final toast = _toastQueue.removeAt(0);
    _toastVisible = true;
    notifyListeners();
    
    // Auto-hide toast
    final duration = toast['duration'] as Duration;
    _setAutoCloseTimer(
      'toast_${toast['id']}',
      duration,
      () {
        _toastVisible = false;
        notifyListeners();
        
        // Process next toast in queue
        if (_toastQueue.isNotEmpty) {
          Timer(const Duration(milliseconds: 300), _processToastQueue);
        }
      },
    );
  }
  
  /// Process snackbar queue
  void _processSnackbarQueue() {
    if (_snackbarVisible || _snackbarQueue.isEmpty) return;
    
    final snackbar = _snackbarQueue.removeAt(0);
    _snackbarVisible = true;
    notifyListeners();
    
    // Auto-hide snackbar
    final duration = snackbar['duration'] as Duration;
    _setAutoCloseTimer(
      'snackbar_${snackbar['id']}',
      duration,
      () {
        _snackbarVisible = false;
        notifyListeners();
        
        // Process next snackbar in queue
        if (_snackbarQueue.isNotEmpty) {
          Timer(const Duration(milliseconds: 300), _processSnackbarQueue);
        }
      },
    );
  }
  
  /// Hide current toast
  void hideCurrentToast() {
    if (_toastVisible) {
      _toastVisible = false;
      notifyListeners();
    }
  }
  
  /// Hide current snackbar
  void hideCurrentSnackbar() {
    if (_snackbarVisible) {
      _snackbarVisible = false;
      notifyListeners();
    }
  }
  
  /// Clear all toasts
  void clearAllToasts() {
    _toastQueue.clear();
    _toastVisible = false;
    notifyListeners();
  }
  
  /// Clear all snackbars
  void clearAllSnackbars() {
    _snackbarQueue.clear();
    _snackbarVisible = false;
    notifyListeners();
  }
  
  // Navigation state management
  
  /// Set current bottom navigation tab
  void setCurrentBottomNavTab(String tab) {
    if (_currentBottomNavTab != tab) {
      _currentBottomNavTab = tab;
      notifyListeners();
    }
  }
  
  /// Set navigation parameters
  void setNavigationParams(Map<String, dynamic> params) {
    _navigationParams = Map.from(params);
    notifyListeners();
  }
  
  /// Add to navigation stack
  void pushToNavigationStack(String route) {
    _navigationStack.add(route);
    _canPop = _navigationStack.length > 1;
    notifyListeners();
  }
  
  /// Remove from navigation stack
  String? popFromNavigationStack() {
    if (_navigationStack.length > 1) {
      final popped = _navigationStack.removeLast();
      _canPop = _navigationStack.length > 1;
      notifyListeners();
      return popped;
    }
    return null;
  }
  
  /// Clear navigation stack
  void clearNavigationStack() {
    _navigationStack.clear();
    _navigationStack.add('/');
    _canPop = false;
    notifyListeners();
  }
  
  // Overlay management
  
  /// Show overlay
  void showOverlay(String overlayId, {Widget? widget}) {
    if (!validateState(requireInitialized: false)) return;
    
    batchStateUpdates(() {
      _overlayStates[overlayId] = true;
      if (widget != null) {
        _overlayWidgets[overlayId] = widget;
      }
    });
  }
  
  /// Hide overlay
  void hideOverlay(String overlayId) {
    if (_overlayStates[overlayId] == true) {
      batchStateUpdates(() {
        _overlayStates.remove(overlayId);
        _overlayWidgets.remove(overlayId);
      });
    }
  }
  
  /// Check if overlay is visible
  bool isOverlayVisible(String overlayId) {
    return _overlayStates[overlayId] ?? false;
  }
  
  /// Get overlay widget
  Widget? getOverlayWidget(String overlayId) {
    return _overlayWidgets[overlayId];
  }
  
  // Keyboard and input management
  
  /// Set keyboard visibility
  void setKeyboardVisible(bool visible, {double height = 0.0}) {
    if (_keyboardVisible != visible || _keyboardHeight != height) {
      batchStateUpdates(() {
        _keyboardVisible = visible;
        _keyboardHeight = height;
      });
    }
  }
  
  /// Set focused input
  void setFocusedInput(String inputId) {
    if (_focusedInput != inputId) {
      _focusedInput = inputId;
      notifyListeners();
    }
  }
  
  /// Clear focused input
  void clearFocusedInput() {
    if (_focusedInput.isNotEmpty) {
      _focusedInput = '';
      notifyListeners();
    }
  }
  
  // Screen state management
  
  /// Update screen information
  void updateScreenInfo({
    Orientation? orientation,
    Size? size,
    EdgeInsets? padding,
    bool? isTablet,
  }) {
    batchStateUpdates(() {
      if (orientation != null && _screenOrientation != orientation) {
        _screenOrientation = orientation;
      }
      if (size != null && _screenSize != size) {
        _screenSize = size;
      }
      if (padding != null && _screenPadding != padding) {
        _screenPadding = padding;
      }
      if (isTablet != null && _isTablet != isTablet) {
        _isTablet = isTablet;
      }
    });
  }
  
  // Theme and visual state management
  
  /// Update system theme information
  void updateSystemTheme({
    Brightness? brightness,
    double? pixelRatio,
    bool? highContrast,
    bool? reduceMotion,
  }) {
    batchStateUpdates(() {
      if (brightness != null && _systemBrightness != brightness) {
        _systemBrightness = brightness;
      }
      if (pixelRatio != null && _devicePixelRatio != pixelRatio) {
        _devicePixelRatio = pixelRatio;
      }
      if (highContrast != null && _highContrast != highContrast) {
        _highContrast = highContrast;
      }
      if (reduceMotion != null && _reduceMotion != reduceMotion) {
        _reduceMotion = reduceMotion;
      }
    });
  }
  
  // Utility methods
  
  /// Set auto-close timer
  void _setAutoCloseTimer(String key, Duration duration, VoidCallback callback) {
    _cancelAutoCloseTimer(key);
    
    _autoCloseTimers[key] = Timer(duration, () {
      callback();
      _autoCloseTimers.remove(key);
    });
    
    addCleanupFunction(() => _cancelAutoCloseTimer(key));
  }
  
  /// Cancel auto-close timer
  void _cancelAutoCloseTimer(String key) {
    _autoCloseTimers[key]?.cancel();
    _autoCloseTimers.remove(key);
  }
  
  /// Reset all UI state
  void resetAllUIState() {
    batchStateUpdates(() {
      clearAllLoading();
      hideAllDialogs();
      clearAllToasts();
      clearAllSnackbars();
      
      _animationStates.clear();
      _overlayStates.clear();
      _overlayWidgets.clear();
      
      _currentBottomNavTab = 'camera';
      _navigationParams.clear();
      clearNavigationStack();
      
      _keyboardVisible = false;
      _keyboardHeight = 0.0;
      _focusedInput = '';
    });
    
    // Cancel all timers
    for (final timer in _autoCloseTimers.values) {
      timer.cancel();
    }
    _autoCloseTimers.clear();
    
    // Dispose animation controllers
    for (final controller in _animationControllers.values) {
      controller?.dispose();
    }
    _animationControllers.clear();
  }
  
  @override
  void dispose() {
    resetAllUIState();
    super.dispose();
  }
}

/// Toast types
enum ToastType {
  info,
  success,
  warning,
  error,
}

/// Snackbar types  
enum SnackbarType {
  info,
  success,
  warning,
  error,
  action,
}