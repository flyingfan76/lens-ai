/// Base exception class for all Lens AI specific errors
abstract class LensException implements Exception {
  final String message;
  final String? details;
  final String? suggestion;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String category;
  final int severity; // 1=info, 2=warning, 3=error, 4=critical

  LensException({
    required this.message,
    required this.category,
    this.details,
    this.suggestion,
    this.originalError,
    this.stackTrace,
    this.severity = 3,
  }) : timestamp = DateTime.now();

  LensException._withTimestamp({
    required this.message,
    required this.category,
    this.details,
    this.suggestion,
    this.originalError,
    this.stackTrace,
    this.severity = 3,
  }) : timestamp = DateTime.now();

  /// Create exception with current timestamp
  factory LensException.now({
    required String message,
    required String category,
    String? details,
    String? suggestion,
    dynamic originalError,
    StackTrace? stackTrace,
    int severity = 3,
  }) {
    return _LensExceptionImpl._withTimestamp(
      message: message,
      category: category,
      details: details,
      suggestion: suggestion,
      originalError: originalError,
      stackTrace: stackTrace,
      severity: severity,
    );
  }

  /// User-friendly error message for display
  String get userMessage => suggestion ?? message;

  /// Detailed error message for logging
  String get detailedMessage {
    var msg = '$category: $message';
    if (details != null) msg += '\nDetails: $details';
    if (suggestion != null) msg += '\nSuggestion: $suggestion';
    if (originalError != null) msg += '\nOriginal: $originalError';
    return msg;
  }

  /// Check if this is a recoverable error
  bool get isRecoverable => severity <= 2;

  /// Check if this is a critical error that requires immediate attention
  bool get isCritical => severity >= 4;

  /// Convert to Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'category': category,
      'details': details,
      'suggestion': suggestion,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'originalError': originalError?.toString(),
    };
  }

  @override
  String toString() => detailedMessage;
}

/// Concrete implementation of LensException
class _LensExceptionImpl extends LensException {
  _LensExceptionImpl({
    required super.message,
    required super.category,
    super.details, // ignore: unused_element_parameter
    super.suggestion, // ignore: unused_element_parameter
    super.originalError, // ignore: unused_element_parameter
    super.stackTrace, // ignore: unused_element_parameter
    super.severity, // ignore: unused_element_parameter
  });

  _LensExceptionImpl._withTimestamp({
    required super.message,
    required super.category,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity,
  }) : super._withTimestamp();
}

// =============================================================================
// CAMERA EXCEPTIONS
// =============================================================================

/// Base class for all camera-related errors
abstract class CameraException extends LensException {
  CameraException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 3,
  }) : super(category: 'Camera');
}

/// Camera permission denied
class CameraPermissionException extends CameraException {
  CameraPermissionException({
    String message = 'Camera permission required',
    String? details,
    String suggestion = 'Please grant camera permission in device settings to use camera features',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 4,
        );
}

/// Camera initialization failed
class CameraInitializationException extends CameraException {
  CameraInitializationException({
    String message = 'Failed to initialize camera',
    String? details,
    String suggestion = 'Try restarting the app or check if another app is using the camera',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 3,
        );
}

/// Camera connection failed
class CameraConnectionException extends CameraException {
  CameraConnectionException({
    String message = 'Failed to connect to camera',
    String? details,
    String suggestion = 'Check camera connection and try again',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 3,
        );
}

/// Camera not available
class CameraNotAvailableException extends CameraException {
  CameraNotAvailableException({
    String message = 'Camera not available',
    String? details,
    String suggestion = 'Make sure the camera is not being used by another app',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 2,
        );
}

/// Camera capture failed
class CameraCaptureException extends CameraException {
  CameraCaptureException({
    String message = 'Failed to capture image',
    String? details,
    String suggestion = 'Try again or check camera settings',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

/// Camera settings error
class CameraSettingsException extends CameraException {
  CameraSettingsException({
    String message = 'Failed to apply camera settings',
    String? details,
    String suggestion = 'Some settings may not be supported by your device',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 1,
        );
}

// =============================================================================
// AI PROCESSING EXCEPTIONS
// =============================================================================

/// Base class for AI processing errors
abstract class AIException extends LensException {
  AIException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 3,
  }) : super(category: 'AI Processing');
}

/// AI model initialization failed
class AIModelInitializationException extends AIException {
  AIModelInitializationException({
    String message = 'Failed to initialize AI model',
    String? details,
    String suggestion = 'AI features will be limited. Try restarting the app',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

/// AI processing failed
class AIProcessingException extends AIException {
  AIProcessingException({
    String message = 'AI processing failed',
    String? details,
    String suggestion = 'Try again or use manual camera controls',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

/// AI analysis timeout
class AITimeoutException extends AIException {
  AITimeoutException({
    String message = 'AI analysis timed out',
    String? details,
    String suggestion = 'Processing is taking longer than expected. Try with a different image',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 1,
        );
}

/// Invalid AI response
class AIResponseException extends AIException {
  AIResponseException({
    String message = 'Invalid AI response',
    String? details,
    String suggestion = 'AI analysis could not be completed. Try again',
    dynamic originalError,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          severity: 2,
        );
}

// =============================================================================
// FILE OPERATION EXCEPTIONS
// =============================================================================

/// Base class for file operation errors
abstract class FileException extends LensException {
  FileException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 3,
  }) : super(category: 'File Operation');
}

/// Storage permission denied
class StoragePermissionException extends FileException {
  StoragePermissionException({
    String message = 'Storage permission required',
    String? details,
    String suggestion = 'Please grant storage permission to save photos',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 4,
        );
}

/// Insufficient storage space
class InsufficientStorageException extends FileException {
  InsufficientStorageException({
    String message = 'Not enough storage space',
    String? details,
    String suggestion = 'Free up some space on your device and try again',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 3,
        );
}

/// File read/write error
class FileIOException extends FileException {
  FileIOException({
    String message = 'File operation failed',
    String? details,
    String suggestion = 'Check if the file exists and you have permission to access it',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 3,
        );
}

/// File not found
class FileNotFoundException extends FileException {
  FileNotFoundException({
    String message = 'File not found',
    String? details,
    String suggestion = 'The file may have been moved or deleted',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 2,
        );
}

// =============================================================================
// IMAGE PROCESSING EXCEPTIONS
// =============================================================================

/// Base class for image processing errors
abstract class ImageException extends LensException {
  ImageException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 3,
  }) : super(category: 'Image Processing');
}

/// Invalid image format
class InvalidImageFormatException extends ImageException {
  InvalidImageFormatException({
    String message = 'Invalid or unsupported image format',
    String? details,
    String suggestion = 'Please use JPEG, PNG, or other supported image formats',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 2,
        );
}

/// Image too large
class ImageTooLargeException extends ImageException {
  ImageTooLargeException({
    String message = 'Image is too large to process',
    String? details,
    String suggestion = 'Try using a smaller image or reduce the camera resolution',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 2,
        );
}

/// Image processing failed
class ImageProcessingException extends ImageException {
  ImageProcessingException({
    String message = 'Failed to process image',
    String? details,
    String suggestion = 'Try again with a different image',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

/// Out of memory during image processing
class ImageMemoryException extends ImageException {
  ImageMemoryException({
    String message = 'Not enough memory to process image',
    String? details,
    String suggestion = 'Close other apps and try again, or use a smaller image',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 3,
        );
}

// =============================================================================
// STATE MANAGEMENT EXCEPTIONS
// =============================================================================

/// Base class for state management errors
abstract class StateException extends LensException {
  StateException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 3,
  }) : super(category: 'State Management');
}

/// Provider initialization failed
class ProviderInitializationException extends StateException {
  ProviderInitializationException({
    String message = 'Failed to initialize provider',
    String? details,
    String suggestion = 'Restart the app to reset the application state',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 4,
        );
}

/// State synchronization error
class StateSyncException extends StateException {
  StateSyncException({
    String message = 'State synchronization failed',
    String? details,
    String suggestion = 'Some features may not work properly. Try refreshing',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

// =============================================================================
// UI EXCEPTIONS
// =============================================================================

/// Base class for UI-related errors
abstract class UIException extends LensException {
  UIException({
    required super.message,
    super.details,
    super.suggestion,
    super.originalError,
    super.stackTrace,
    super.severity = 2,
  }) : super(category: 'User Interface');
}

/// Form validation error
class ValidationException extends UIException {
  ValidationException({
    String message = 'Input validation failed',
    String? details,
    String suggestion = 'Please check your input and try again',
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          severity: 1,
        );
}

/// Navigation error
class NavigationException extends UIException {
  NavigationException({
    String message = 'Navigation failed',
    String? details,
    String suggestion = 'Try using the back button or restart the app',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 2,
        );
}

/// Widget rendering error
class RenderException extends UIException {
  RenderException({
    String message = 'Failed to render UI component',
    String? details,
    String suggestion = 'Try refreshing the screen or restart the app',
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          details: details,
          suggestion: suggestion,
          originalError: originalError,
          stackTrace: stackTrace,
          severity: 3,
        );
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/// Exception factory for creating appropriate exceptions based on error type
class ExceptionFactory {
  /// Create camera exception from generic error
  static CameraException createCameraException(dynamic error, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    final String errorMsg = error.toString().toLowerCase();
    
    if (errorMsg.contains('permission')) {
      return CameraPermissionException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('initialize') || errorMsg.contains('init')) {
      return CameraInitializationException(
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (errorMsg.contains('connect') || errorMsg.contains('connection')) {
      return CameraConnectionException(
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (errorMsg.contains('capture') || errorMsg.contains('picture')) {
      return CameraCaptureException(
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (errorMsg.contains('available') || errorMsg.contains('not found')) {
      return CameraNotAvailableException(
        details: error.toString(),
      );
    } else {
      return CameraSettingsException(
        message: operation != null ? 'Failed to $operation' : 'Camera operation failed',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create AI exception from generic error
  static AIException createAIException(dynamic error, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    final String errorMsg = error.toString().toLowerCase();
    
    if (errorMsg.contains('timeout') || errorMsg.contains('time out')) {
      return AITimeoutException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('initialize') || errorMsg.contains('model')) {
      return AIModelInitializationException(
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (errorMsg.contains('response') || errorMsg.contains('format') || errorMsg.contains('parse')) {
      return AIResponseException(
        details: error.toString(),
        originalError: error,
      );
    } else {
      return AIProcessingException(
        message: operation != null ? 'Failed to $operation' : 'AI processing failed',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create file exception from generic error
  static FileException createFileException(dynamic error, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    final String errorMsg = error.toString().toLowerCase();
    
    if (errorMsg.contains('permission')) {
      return StoragePermissionException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('space') || errorMsg.contains('storage') || errorMsg.contains('disk full')) {
      return InsufficientStorageException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('not found') || errorMsg.contains('does not exist')) {
      return FileNotFoundException(
        details: error.toString(),
      );
    } else {
      return FileIOException(
        message: operation != null ? 'Failed to $operation' : 'File operation failed',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create image exception from generic error
  static ImageException createImageException(dynamic error, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    final String errorMsg = error.toString().toLowerCase();
    
    if (errorMsg.contains('format') || errorMsg.contains('decode') || errorMsg.contains('invalid')) {
      return InvalidImageFormatException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('memory') || errorMsg.contains('out of memory')) {
      return ImageMemoryException(
        details: error.toString(),
      );
    } else if (errorMsg.contains('large') || errorMsg.contains('size')) {
      return ImageTooLargeException(
        details: error.toString(),
      );
    } else {
      return ImageProcessingException(
        message: operation != null ? 'Failed to $operation' : 'Image processing failed',
        details: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }
}