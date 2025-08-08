import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lens_exceptions.dart';
import 'error_logger.dart';
import 'error_dialog_manager.dart';

/// Centralized error handler for the Lens AI application
class ErrorHandler {
  static ErrorHandler? _instance;
  static ErrorHandler get instance => _instance ??= ErrorHandler._();

  ErrorHandler._();

  bool _isInitialized = false;

  /// Initialize the error handler
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize logger
      await ErrorLogger.instance.initialize();

      // Set up global error handlers
      _setupGlobalErrorHandlers();

      _isInitialized = true;
      ErrorLogger.instance.info('ErrorHandler', 'Error handler initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize ErrorHandler: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Handle any error with appropriate logging and user feedback
  Future<void> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    BuildContext? uiContext,
    bool showToUser = true,
    String? operation,
  }) async {
    try {
      // Convert to LensException if not already
      final lensException = _convertToLensException(error, stackTrace, context, operation);

      // Log the error
      ErrorLogger.instance.logException(lensException, context: {
        if (context != null) 'context': context,
        if (operation != null) 'operation': operation,
      });

      // Show to user if context is provided and requested
      if (showToUser && uiContext != null) {
        await _showErrorToUser(uiContext, lensException);
      }

      // Additional handling for critical errors
      if (lensException.isCritical) {
        await _handleCriticalError(lensException, uiContext);
      }

    } catch (handlerError, handlerStackTrace) {
      // If our error handler fails, fall back to basic logging
      debugPrint('Error handler failed: $handlerError');
      debugPrint('Original error: $error');
      debugPrint('Handler stack trace: $handlerStackTrace');
    }
  }

  /// Handle camera errors specifically
  Future<void> handleCameraError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    final cameraException = ExceptionFactory.createCameraException(
      error,
      operation: operation,
      stackTrace: stackTrace,
    );

    await handleError(
      cameraException,
      context: 'Camera Operation',
      uiContext: context,
      showToUser: showToUser,
      operation: operation,
    );
  }

  /// Handle AI processing errors
  Future<void> handleAIError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    final aiException = ExceptionFactory.createAIException(
      error,
      operation: operation,
      stackTrace: stackTrace,
    );

    await handleError(
      aiException,
      context: 'AI Processing',
      uiContext: context,
      showToUser: showToUser,
      operation: operation,
    );
  }

  /// Handle file operation errors
  Future<void> handleFileError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    final fileException = ExceptionFactory.createFileException(
      error,
      operation: operation,
      stackTrace: stackTrace,
    );

    await handleError(
      fileException,
      context: 'File Operation',
      uiContext: context,
      showToUser: showToUser,
      operation: operation,
    );
  }

  /// Handle image processing errors
  Future<void> handleImageError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    final imageException = ExceptionFactory.createImageException(
      error,
      operation: operation,
      stackTrace: stackTrace,
    );

    await handleError(
      imageException,
      context: 'Image Processing',
      uiContext: context,
      showToUser: showToUser,
      operation: operation,
    );
  }

  /// Execute function with error handling
  Future<T?> withErrorHandling<T>(
    Future<T> Function() function, {
    String? context,
    String? operation,
    BuildContext? uiContext,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      await handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        uiContext: uiContext,
        showToUser: showToUser,
        operation: operation,
      );
      return fallbackValue;
    }
  }

  /// Execute function with camera error handling
  Future<T?> withCameraErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      await handleCameraError(
        error,
        stackTrace: stackTrace,
        operation: operation,
        context: context,
        showToUser: showToUser,
      );
      return fallbackValue;
    }
  }

  /// Execute function with AI error handling
  Future<T?> withAIErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      await handleAIError(
        error,
        stackTrace: stackTrace,
        operation: operation,
        context: context,
        showToUser: showToUser,
      );
      return fallbackValue;
    }
  }

  /// Execute function with file error handling
  Future<T?> withFileErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      await handleFileError(
        error,
        stackTrace: stackTrace,
        operation: operation,
        context: context,
        showToUser: showToUser,
      );
      return fallbackValue;
    }
  }

  /// Execute function with image error handling
  Future<T?> withImageErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      await handleImageError(
        error,
        stackTrace: stackTrace,
        operation: operation,
        context: context,
        showToUser: showToUser,
      );
      return fallbackValue;
    }
  }

  /// Setup global error handlers
  void _setupGlobalErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = RenderException(
        message: 'Flutter framework error',
        details: details.exception.toString(),
        originalError: details.exception,
        stackTrace: details.stack,
      );

      ErrorLogger.instance.logException(exception, context: {
        'library': details.library ?? 'unknown',
        'context': details.context?.toString() ?? 'unknown',
        'informationCollected': details.informationCollector?.call() ?? 'none',
      });

      // In debug mode, also print to console
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle errors outside of Flutter framework (async errors, etc.)
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      final exception = LensException.now(
        message: 'Unhandled async error',
        category: 'System',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
        severity: 4,
      );

      ErrorLogger.instance.logException(exception);

      if (kDebugMode) {
        debugPrint('Unhandled error: $error');
        debugPrint('Stack trace: $stackTrace');
      }

      return true; // Indicates error was handled
    };
  }

  /// Convert any error to LensException
  LensException _convertToLensException(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    String? operation,
  ) {
    if (error is LensException) {
      return error;
    }

    // Try to categorize based on error type and message
    final errorMsg = error.toString().toLowerCase();
    
    if (errorMsg.contains('camera') || errorMsg.contains('permission')) {
      return ExceptionFactory.createCameraException(error, operation: operation, stackTrace: stackTrace);
    } else if (errorMsg.contains('file') || errorMsg.contains('storage')) {
      return ExceptionFactory.createFileException(error, operation: operation, stackTrace: stackTrace);
    } else if (errorMsg.contains('image') || errorMsg.contains('decode')) {
      return ExceptionFactory.createImageException(error, operation: operation, stackTrace: stackTrace);
    } else if (errorMsg.contains('ai') || errorMsg.contains('model')) {
      return ExceptionFactory.createAIException(error, operation: operation, stackTrace: stackTrace);
    } else {
      // Generic error
      return LensException.now(
        message: operation != null ? 'Failed to $operation' : 'An error occurred',
        category: context ?? 'General',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
        severity: 3,
      );
    }
  }

  /// Show error to user based on severity and type
  Future<void> _showErrorToUser(BuildContext context, LensException exception) async {
    // Don't show debug-level errors to users in release mode
    if (!kDebugMode && exception.severity <= 1) {
      return;
    }

    // For recoverable errors, use snackbar
    if (exception.isRecoverable && exception.severity <= 2) {
      ErrorDialogManager.instance.showWarningSnackbar(
        context,
        exception.userMessage,
      );
    } else {
      // For more serious errors, use dialog
      await ErrorDialogManager.instance.showErrorDialog(context, exception);
    }
  }

  /// Handle critical errors that might require app restart
  Future<void> _handleCriticalError(LensException exception, BuildContext? context) async {
    ErrorLogger.instance.critical(
      'CriticalError',
      'Critical error detected: ${exception.message}',
      details: exception.detailedMessage,
    );

    if (context != null) {
      // Show critical error dialog with restart option
      await ErrorDialogManager.instance.showErrorDialog(
        context,
        exception,
        title: 'Critical Error',
        actions: [
          TextButton(
            onPressed: () {
              // Copy error to clipboard
              _copyErrorToClipboard(exception);
            },
            child: const Text('Copy Error'),
          ),
          ElevatedButton(
            onPressed: () {
              // Exit the app
              if (Platform.isAndroid) {
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              } else if (Platform.isIOS) {
                exit(0);
              }
            },
            child: const Text('Restart App'),
          ),
        ],
      );
    }
  }

  /// Copy error details to clipboard
  void _copyErrorToClipboard(LensException exception) {
    final errorText = '''
Error: ${exception.message}
Category: ${exception.category}
${exception.details != null ? 'Details: ${exception.details}\n' : ''}
${exception.suggestion != null ? 'Suggestion: ${exception.suggestion}\n' : ''}
Timestamp: ${exception.timestamp}
Severity: ${exception.severity}
''';

    Clipboard.setData(ClipboardData(text: errorText));
  }

  /// Check if error handler is ready
  bool get isInitialized => _isInitialized;

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    return ErrorLogger.instance.getLogStats();
  }

  /// Export error logs
  Future<String> exportErrorLogs({
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await ErrorLogger.instance.exportLogs(
      category: category,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}

/// Extension to make error handling easier throughout the app
extension ErrorHandlerExtension on Object {
  /// Handle error with context
  Future<void> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    await ErrorHandler.instance.handleError(
      error,
      stackTrace: stackTrace,
      context: runtimeType.toString(),
      uiContext: context,
      showToUser: showToUser,
      operation: operation,
    );
  }

  /// Execute with error handling
  Future<T?> withErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    return await ErrorHandler.instance.withErrorHandling(
      function,
      context: runtimeType.toString(),
      operation: operation,
      uiContext: context,
      showToUser: showToUser,
      fallbackValue: fallbackValue,
    );
  }
}

/// Mixin for classes that need error handling capabilities
mixin ErrorHandlerMixin {
  /// Handle camera errors
  Future<void> handleCameraError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    await ErrorHandler.instance.handleCameraError(
      error,
      stackTrace: stackTrace,
      operation: operation,
      context: context,
      showToUser: showToUser,
    );
  }

  /// Handle AI errors
  Future<void> handleAIError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    await ErrorHandler.instance.handleAIError(
      error,
      stackTrace: stackTrace,
      operation: operation,
      context: context,
      showToUser: showToUser,
    );
  }

  /// Handle file errors
  Future<void> handleFileError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    await ErrorHandler.instance.handleFileError(
      error,
      stackTrace: stackTrace,
      operation: operation,
      context: context,
      showToUser: showToUser,
    );
  }

  /// Handle image errors
  Future<void> handleImageError(
    dynamic error, {
    StackTrace? stackTrace,
    String? operation,
    BuildContext? context,
    bool showToUser = true,
  }) async {
    await ErrorHandler.instance.handleImageError(
      error,
      stackTrace: stackTrace,
      operation: operation,
      context: context,
      showToUser: showToUser,
    );
  }

  /// Execute with camera error handling
  Future<T?> withCameraErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    return await ErrorHandler.instance.withCameraErrorHandling(
      function,
      operation: operation,
      context: context,
      showToUser: showToUser,
      fallbackValue: fallbackValue,
    );
  }

  /// Execute with AI error handling
  Future<T?> withAIErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    return await ErrorHandler.instance.withAIErrorHandling(
      function,
      operation: operation,
      context: context,
      showToUser: showToUser,
      fallbackValue: fallbackValue,
    );
  }

  /// Execute with file error handling
  Future<T?> withFileErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    return await ErrorHandler.instance.withFileErrorHandling(
      function,
      operation: operation,
      context: context,
      showToUser: showToUser,
      fallbackValue: fallbackValue,
    );
  }

  /// Execute with image error handling
  Future<T?> withImageErrorHandling<T>(
    Future<T> Function() function, {
    String? operation,
    BuildContext? context,
    bool showToUser = true,
    T? fallbackValue,
  }) async {
    return await ErrorHandler.instance.withImageErrorHandling(
      function,
      operation: operation,
      context: context,
      showToUser: showToUser,
      fallbackValue: fallbackValue,
    );
  }
}