import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for executing native system commands to detect USB devices
/// Provides platform-specific implementations for camera detection
class NativeSystemService {
  static const MethodChannel _channel = MethodChannel('lens_ai/system_commands');
  
  /// Execute a system command with timeout
  static Future<String?> executeCommand(String command, {int timeoutMs = 5000}) async {
    try {
      debugPrint('NativeSystemService: Executing command: $command');
      
      if (Platform.isAndroid || Platform.isIOS) {
        // Use method channel for mobile platforms
        final result = await _channel.invokeMethod<String>('executeCommand', {
          'command': command,
          'timeout': timeoutMs,
        });
        
        debugPrint('NativeSystemService: Command result: ${result?.substring(0, 100)}...');
        return result;
        
      } else {
        // Direct process execution for desktop platforms
        return await _executeDesktopCommand(command, timeoutMs);
      }
    } catch (e) {
      debugPrint('NativeSystemService: Command execution error: $e');
      return null;
    }
  }
  
  /// Execute command directly on desktop platforms
  static Future<String?> _executeDesktopCommand(String command, int timeoutMs) async {
    try {
      final parts = command.split(' ');
      final executable = parts.first;
      final arguments = parts.skip(1).toList();
      
      final process = await Process.start(
        executable,
        arguments,
        runInShell: true,
      );
      
      final timeout = Duration(milliseconds: timeoutMs);
      
      // Collect output with timeout
      final outputCompleter = Completer<String?>();
      final outputBuffer = StringBuffer();
      
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        outputBuffer.write(data);
      });
      
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        debugPrint('NativeSystemService: Command stderr: $data');
      });
      
      process.exitCode.then((exitCode) {
        if (!outputCompleter.isCompleted) {
          if (exitCode == 0) {
            outputCompleter.complete(outputBuffer.toString());
          } else {
            outputCompleter.complete(null);
          }
        }
      });
      
      // Apply timeout
      Timer(timeout, () {
        if (!outputCompleter.isCompleted) {
          process.kill();
          outputCompleter.complete(null);
        }
      });
      
      return await outputCompleter.future;
      
    } catch (e) {
      debugPrint('NativeSystemService: Desktop command error: $e');
      return null;
    }
  }
  
  /// Check if a specific command is available on the system
  static Future<bool> isCommandAvailable(String command) async {
    try {
      final result = await executeCommand('which $command', timeoutMs: 2000);
      return result != null && result.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get system information for debugging
  static Future<Map<String, String>> getSystemInfo() async {
    final info = <String, String>{};
    
    try {
      if (Platform.isLinux) {
        final unameResult = await executeCommand('uname -a');
        if (unameResult != null) {
          info['system'] = unameResult.trim();
        }
        
        final lsusbAvailable = await isCommandAvailable('lsusb');
        info['lsusb_available'] = lsusbAvailable.toString();
        
      } else if (Platform.isMacOS) {
        final systemProfilerAvailable = await isCommandAvailable('system_profiler');
        info['system_profiler_available'] = systemProfilerAvailable.toString();
        
      } else if (Platform.isAndroid) {
        info['platform'] = 'Android';
        info['usb_host_support'] = 'requires_native_check';
        
      } else if (Platform.isIOS) {
        info['platform'] = 'iOS';
        info['usb_support'] = 'mfi_limited';
      }
      
      info['dart_platform'] = Platform.operatingSystem;
      info['dart_version'] = Platform.version;
      
    } catch (e) {
      info['error'] = e.toString();
    }
    
    return info;
  }
}