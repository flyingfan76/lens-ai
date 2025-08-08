import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lens_exceptions.dart';
import 'error_logger.dart';

/// Error dialog manager for consistent error handling across the app
class ErrorDialogManager {
  static ErrorDialogManager? _instance;
  static ErrorDialogManager get instance => _instance ??= ErrorDialogManager._();

  ErrorDialogManager._();

  /// Show error dialog based on exception type
  Future<void> showErrorDialog(
    BuildContext context,
    LensException exception, {
    String? title,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    // Log the error
    ErrorLogger.instance.logException(exception);

    // Show appropriate dialog based on exception type
    if (exception is CameraPermissionException) {
      await _showPermissionDialog(context, exception);
    } else if (exception.isCritical) {
      await _showCriticalErrorDialog(context, exception, title: title, actions: actions);
    } else if (exception.isRecoverable) {
      await _showRecoverableErrorDialog(context, exception, title: title, actions: actions);
    } else {
      await _showGenericErrorDialog(context, exception, title: title, actions: actions);
    }
  }

  /// Show error dialog for generic exceptions
  Future<void> showGenericErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? details,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    // Log the error
    ErrorLogger.instance.error('UI', title, details: details);

    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(
                      details,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: actions ?? [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar for minor errors
  void showErrorSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    // Log the error
    ErrorLogger.instance.warning('UI', 'Snackbar error: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show warning snackbar
  void showWarningSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show permission dialog
  Future<void> _showPermissionDialog(
    BuildContext context,
    CameraPermissionException exception,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Camera Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exception.userMessage),
            const SizedBox(height: 16),
            const Text(
              'This app needs camera access to:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Take photos and videos'),
            const Text('• Preview camera feed'),
            const Text('• Apply AI-powered suggestions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to app settings
              _openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show critical error dialog
  Future<void> _showCriticalErrorDialog(
    BuildContext context,
    LensException exception, {
    String? title,
    List<Widget>? actions,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Critical Error')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exception.userMessage),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.priority_high,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This error requires immediate attention. Please restart the app.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (exception.details != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(
                      exception.details!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: actions ?? [
          TextButton(
            onPressed: () => _copyErrorToClipboard(exception),
            child: const Text('Copy Error'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show recoverable error dialog
  Future<void> _showRecoverableErrorDialog(
    BuildContext context,
    LensException exception, {
    String? title,
    List<Widget>? actions,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Information')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exception.userMessage),
            if (exception.details != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('More Information'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(exception.details!),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: actions ?? [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show generic error dialog
  Future<void> _showGenericErrorDialog(
    BuildContext context,
    LensException exception, {
    String? title,
    List<Widget>? actions,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_outlined, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Error')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exception.userMessage),
            if (exception.details != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(
                      exception.details!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: actions ?? [
          if (exception.details != null)
            TextButton(
              onPressed: () => _copyErrorToClipboard(exception),
              child: const Text('Copy Error'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  /// Open app settings (platform-specific implementation would be needed)
  void _openAppSettings() {
    // This would need platform-specific implementation
    // For now, just log the action
    ErrorLogger.instance.info('UI', 'User requested to open app settings');
  }
}

/// Error boundary widget to catch rendering errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, LensException error)? errorBuilder;
  final Function(LensException error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  LensException? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ?? 
        _buildDefaultErrorWidget(context, _error!);
    }

    return widget.child;
  }

  /// Handle Flutter errors within this boundary
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Set up error handling for this widget tree
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = RenderException(
        message: 'Widget rendering failed',
        details: details.exception.toString(),
        suggestion: 'Try refreshing the screen or restart the app',
        originalError: details.exception,
        stackTrace: details.stack,
      );
      
      setState(() {
        _error = exception;
      });
      
      widget.onError?.call(exception);
      ErrorLogger.instance.logException(exception);
    };
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget(BuildContext context, LensException error) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.userMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

/// Extension to make error handling easier in widgets
extension ErrorHandlingExtension on BuildContext {
  /// Show error dialog using the error dialog manager
  Future<void> showErrorDialog(LensException exception, {
    String? title,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    await ErrorDialogManager.instance.showErrorDialog(
      this,
      exception,
      title: title,
      actions: actions,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show generic error dialog
  Future<void> showGenericErrorDialog(
    String title,
    String message, {
    String? details,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    await ErrorDialogManager.instance.showGenericErrorDialog(
      this,
      title,
      message,
      details: details,
      actions: actions,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show error snackbar
  void showErrorSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ErrorDialogManager.instance.showErrorSnackbar(
      this,
      message,
      duration: duration,
      action: action,
    );
  }

  /// Show success snackbar
  void showSuccessSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ErrorDialogManager.instance.showSuccessSnackbar(
      this,
      message,
      duration: duration,
      action: action,
    );
  }

  /// Show warning snackbar
  void showWarningSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ErrorDialogManager.instance.showWarningSnackbar(
      this,
      message,
      duration: duration,
      action: action,
    );
  }
}