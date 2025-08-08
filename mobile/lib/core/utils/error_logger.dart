import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'lens_exceptions.dart';

/// Error logging levels
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARN'),
  error(3, 'ERROR'),
  critical(4, 'CRITICAL');

  const LogLevel(this.value, this.label);
  final int value;
  final String label;
}

/// Error log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final String? details;
  final Map<String, dynamic>? context;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details,
    this.context,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.label,
      'category': category,
      'message': message,
      'details': details,
      'context': context,
      'stackTrace': stackTrace,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere(
        (l) => l.label == json['level'],
        orElse: () => LogLevel.info,
      ),
      category: json['category'],
      message: json['message'],
      details: json['details'],
      context: json['context'] != null
          ? Map<String, dynamic>.from(json['context'])
          : null,
      stackTrace: json['stackTrace'],
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('${level.label} ');
    buffer.write('[$category] ');
    buffer.write(message);
    
    if (details != null) {
      buffer.write('\n  Details: $details');
    }
    
    if (context != null && context!.isNotEmpty) {
      buffer.write('\n  Context: ${jsonEncode(context)}');
    }
    
    if (stackTrace != null) {
      buffer.write('\n  Stack: $stackTrace');
    }
    
    return buffer.toString();
  }
}

/// Error logger for Lens AI application
class ErrorLogger {
  static const String _logFileName = 'lens_error_log.json';
  static const int _maxLogEntries = 1000;
  static const int _maxLogFileSizeMB = 5;

  static ErrorLogger? _instance;
  static ErrorLogger get instance => _instance ??= ErrorLogger._();

  ErrorLogger._();

  File? _logFile;
  final List<LogEntry> _logEntries = [];
  bool _isInitialized = false;
  LogLevel _minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Initialize the logger
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logFile = File(path.join(appDir.path, _logFileName));
      
      // Load existing logs
      await _loadLogs();
      
      _isInitialized = true;
      
      // Log initialization
      info('ErrorLogger', 'Error logger initialized with ${_logEntries.length} existing entries');
      
    } catch (e) {
      debugPrint('Failed to initialize ErrorLogger: $e');
    }
  }

  /// Set minimum log level
  void setLogLevel(LogLevel level) {
    _minimumLevel = level;
    info('ErrorLogger', 'Log level set to ${level.label}');
  }

  /// Log debug message
  void debug(String category, String message, {
    String? details,
    Map<String, dynamic>? context,
  }) {
    _log(LogLevel.debug, category, message, details: details, context: context);
  }

  /// Log info message
  void info(String category, String message, {
    String? details,
    Map<String, dynamic>? context,
  }) {
    _log(LogLevel.info, category, message, details: details, context: context);
  }

  /// Log warning message
  void warning(String category, String message, {
    String? details,
    Map<String, dynamic>? context,
  }) {
    _log(LogLevel.warning, category, message, details: details, context: context);
  }

  /// Log error message
  void error(String category, String message, {
    String? details,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error, 
      category, 
      message, 
      details: details, 
      context: context,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log critical error message
  void critical(String category, String message, {
    String? details,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.critical, 
      category, 
      message, 
      details: details, 
      context: context,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log exception
  void logException(LensException exception, {
    Map<String, dynamic>? context,
  }) {
    final level = _getLogLevelFromSeverity(exception.severity);
    _log(
      level,
      exception.category,
      exception.message,
      details: exception.details,
      context: {
        ...?context,
        'suggestion': exception.suggestion,
        'originalError': exception.originalError?.toString(),
        'severity': exception.severity,
        'recoverable': exception.isRecoverable,
        'critical': exception.isCritical,
      },
      stackTrace: exception.stackTrace?.toString(),
    );
  }

  /// Log generic exception
  void logGenericException(
    String category,
    dynamic exception, {
    String? operation,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    final message = operation != null 
        ? 'Failed to $operation: $exception'
        : 'Exception occurred: $exception';
    
    error(
      category,
      message,
      details: exception.toString(),
      context: context,
      stackTrace: stackTrace,
    );
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs({
    int limit = 50,
    LogLevel? minLevel,
    String? category,
  }) {
    var filtered = _logEntries.where((entry) {
      if (minLevel != null && entry.level.value < minLevel.value) {
        return false;
      }
      if (category != null && entry.category != category) {
        return false;
      }
      return true;
    }).toList();

    // Sort by timestamp (newest first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return filtered.take(limit).toList();
  }

  /// Get log statistics
  Map<String, dynamic> getLogStats() {
    if (_logEntries.isEmpty) {
      return {
        'totalEntries': 0,
        'byLevel': {},
        'byCategory': {},
        'oldestEntry': null,
        'newestEntry': null,
      };
    }

    final byLevel = <String, int>{};
    final byCategory = <String, int>{};
    
    for (final entry in _logEntries) {
      byLevel[entry.level.label] = (byLevel[entry.level.label] ?? 0) + 1;
      byCategory[entry.category] = (byCategory[entry.category] ?? 0) + 1;
    }

    final sortedEntries = [..._logEntries];
    sortedEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return {
      'totalEntries': _logEntries.length,
      'byLevel': byLevel,
      'byCategory': byCategory,
      'oldestEntry': sortedEntries.first.timestamp.toIso8601String(),
      'newestEntry': sortedEntries.last.timestamp.toIso8601String(),
      'fileSizeKB': _logFile != null && _logFile!.existsSync() 
          ? (_logFile!.lengthSync() / 1024).round()
          : 0,
    };
  }

  /// Export logs as JSON string
  Future<String> exportLogs({
    LogLevel? minLevel,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var filtered = _logEntries.where((entry) {
      if (minLevel != null && entry.level.value < minLevel.value) {
        return false;
      }
      if (category != null && entry.category != category) {
        return false;
      }
      if (fromDate != null && entry.timestamp.isBefore(fromDate)) {
        return false;
      }
      if (toDate != null && entry.timestamp.isAfter(toDate)) {
        return false;
      }
      return true;
    }).toList();

    // Sort by timestamp
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalEntries': filtered.length,
      'filters': {
        'minLevel': minLevel?.label,
        'category': category,
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
      },
      'entries': filtered.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _logEntries.clear();
    await _saveLogs();
    info('ErrorLogger', 'All logs cleared');
  }

  /// Clear old logs (older than specified days)
  Future<void> clearOldLogs(int olderThanDays) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final initialCount = _logEntries.length;
    
    _logEntries.removeWhere((entry) => entry.timestamp.isBefore(cutoffDate));
    
    await _saveLogs();
    
    final removedCount = initialCount - _logEntries.length;
    if (removedCount > 0) {
      info('ErrorLogger', 'Cleared $removedCount old log entries');
    }
  }

  /// Internal logging method
  void _log(
    LogLevel level,
    String category,
    String message, {
    String? details,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    // Check minimum level
    if (level.value < _minimumLevel.value) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      details: details,
      context: context,
      stackTrace: stackTrace,
    );

    // Add to memory
    _logEntries.add(entry);

    // Print to console in debug mode
    if (kDebugMode) {
      debugPrint(entry.toString());
    }

    // Maintain size limits
    _maintainLogSize();

    // Save to file (async, don't wait)
    if (_isInitialized) {
      _saveLogs().catchError((e) {
        debugPrint('Failed to save log: $e');
      });
    }
  }

  /// Convert severity to log level
  LogLevel _getLogLevelFromSeverity(int severity) {
    switch (severity) {
      case 1:
        return LogLevel.info;
      case 2:
        return LogLevel.warning;
      case 3:
        return LogLevel.error;
      case 4:
        return LogLevel.critical;
      default:
        return LogLevel.info;
    }
  }

  /// Maintain log size limits
  void _maintainLogSize() {
    // Limit number of entries
    if (_logEntries.length > _maxLogEntries) {
      final excess = _logEntries.length - _maxLogEntries;
      _logEntries.removeRange(0, excess);
    }
  }

  /// Load logs from file
  Future<void> _loadLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    try {
      final content = await _logFile!.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(content);
      _logEntries.clear();
      _logEntries.addAll(
        jsonList.map((json) => LogEntry.fromJson(json)).toList(),
      );

      // Check file size and truncate if necessary
      await _checkAndTruncateLogFile();
      
    } catch (e) {
      debugPrint('Failed to load error logs: $e');
      _logEntries.clear();
    }
  }

  /// Save logs to file
  Future<void> _saveLogs() async {
    if (_logFile == null) return;

    try {
      final jsonList = _logEntries.map((e) => e.toJson()).toList();
      final content = jsonEncode(jsonList);
      await _logFile!.writeAsString(content);
    } catch (e) {
      debugPrint('Failed to save error logs: $e');
    }
  }

  /// Check and truncate log file if too large
  Future<void> _checkAndTruncateLogFile() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    try {
      final fileSizeBytes = await _logFile!.length();
      const maxSizeBytes = _maxLogFileSizeMB * 1024 * 1024;

      if (fileSizeBytes > maxSizeBytes) {
        // Keep only the most recent half of the logs
        final keepCount = _logEntries.length ~/ 2;
        _logEntries.removeRange(0, _logEntries.length - keepCount);
        await _saveLogs();
        
        info('ErrorLogger', 'Log file truncated, kept $keepCount most recent entries');
      }
    } catch (e) {
      debugPrint('Failed to check log file size: $e');
    }
  }

  /// Static convenience methods for common logging operations
  static void logError(
    LensException error, {
    String? source,
    Map<String, dynamic>? context,
    int? severity,
  }) {
    instance.logException(error, context: {
      ...?context,
      if (source != null) 'source': source,
      if (severity != null) 'severity': severity,
    });
  }

  static void logGenericError(
    String category,
    dynamic error, {
    String? operation,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    instance.logGenericException(
      category,
      error,
      operation: operation,
      context: context,
      stackTrace: stackTrace,
    );
  }
}

/// Extension to make logging easier
extension LoggerExtension on Object {
  void logDebug(String message, {String? details, Map<String, dynamic>? context}) {
    ErrorLogger.instance.debug(runtimeType.toString(), message, details: details, context: context);
  }

  void logInfo(String message, {String? details, Map<String, dynamic>? context}) {
    ErrorLogger.instance.info(runtimeType.toString(), message, details: details, context: context);
  }

  void logWarning(String message, {String? details, Map<String, dynamic>? context}) {
    ErrorLogger.instance.warning(runtimeType.toString(), message, details: details, context: context);
  }

  void logError(String message, {String? details, Map<String, dynamic>? context, StackTrace? stackTrace}) {
    ErrorLogger.instance.error(runtimeType.toString(), message, details: details, context: context, stackTrace: stackTrace);
  }

  void logCritical(String message, {String? details, Map<String, dynamic>? context, StackTrace? stackTrace}) {
    ErrorLogger.instance.critical(runtimeType.toString(), message, details: details, context: context, stackTrace: stackTrace);
  }

  void logException(LensException exception, {Map<String, dynamic>? context}) {
    ErrorLogger.instance.logException(exception, context: context);
  }

  void logGenericException(dynamic exception, {String? operation, Map<String, dynamic>? context, StackTrace? stackTrace}) {
    ErrorLogger.instance.logGenericException(runtimeType.toString(), exception, operation: operation, context: context, stackTrace: stackTrace);
  }
}