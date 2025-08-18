import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Complete Flutter service for libgphoto2 camera control
class LibGPhoto2Service {
  static const MethodChannel _channel = MethodChannel('libgphoto2_bridge');
  static const EventChannel _eventChannel = EventChannel('libgphoto2_events');
  
  static LibGPhoto2Service? _instance;
  factory LibGPhoto2Service() => _instance ??= LibGPhoto2Service._internal();
  LibGPhoto2Service._internal();
  
  StreamController<Uint8List>? _liveViewStreamController;
  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isLiveViewActive = false;
  
  /// Public getters
  Stream<Uint8List>? get liveViewStream => _liveViewStreamController?.stream;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isLiveViewActive => _isLiveViewActive;
  
  /// Initialize the libgphoto2 service
  Future<bool> initialize() async {
    try {
      debugPrint('LibGPhoto2Service: Initializing libgphoto2 backend');
      
      // Listen for events from native side
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          _handleNativeEvent(event);
        },
        onError: (error) {
          debugPrint('LibGPhoto2Service: Event stream error: $error');
        },
      );
      
      // Initialize native library
      final result = await _channel.invokeMethod('initialize');
      _isInitialized = result == true;
      
      if (_isInitialized) {
        debugPrint('LibGPhoto2Service: libgphoto2 initialized successfully');
      } else {
        debugPrint('LibGPhoto2Service: libgphoto2 initialization failed');
      }
      
      return _isInitialized;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Initialization error: $e');
      return false;
    }
  }
  
  /// Detect available cameras
  Future<List<Map<String, dynamic>>> detectCameras() async {
    try {
      debugPrint('LibGPhoto2Service: Detecting cameras');
      
      if (!_isInitialized) {
        debugPrint('LibGPhoto2Service: Not initialized, cannot detect cameras');
        return [];
      }
      
      final result = await _channel.invokeMethod('detectCameras');
      
      if (result is List) {
        final cameras = <Map<String, dynamic>>[];
        for (final item in result) {
          if (item is Map) {
            cameras.add(Map<String, dynamic>.from(item));
          }
        }
        debugPrint('LibGPhoto2Service: Found ${cameras.length} cameras');
        
        for (final camera in cameras) {
          debugPrint('  - ${camera['name']} on ${camera['port']}');
        }
        
        return cameras;
      }
      
      return [];
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Camera detection error: $e');
      return [];
    }
  }
  
  /// Connect to the first available camera
  Future<bool> connect() async {
    try {
      debugPrint('LibGPhoto2Service: Connecting to camera');
      
      if (!_isInitialized) {
        debugPrint('LibGPhoto2Service: Not initialized, cannot connect');
        return false;
      }
      
      if (_isConnected) {
        debugPrint('LibGPhoto2Service: Already connected');
        return true;
      }
      
      final result = await _channel.invokeMethod('connect');
      _isConnected = result == true;
      
      if (_isConnected) {
        debugPrint('LibGPhoto2Service: Camera connected successfully');
      } else {
        debugPrint('LibGPhoto2Service: Camera connection failed');
      }
      
      return _isConnected;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Connection error: $e');
      return false;
    }
  }
  
  /// Disconnect from camera
  Future<bool> disconnect() async {
    try {
      debugPrint('LibGPhoto2Service: Disconnecting from camera');
      
      // Stop live view if active
      if (_isLiveViewActive) {
        await stopLiveView();
      }
      
      final result = await _channel.invokeMethod('disconnect');
      _isConnected = false;
      
      debugPrint('LibGPhoto2Service: Camera disconnected');
      return result == true;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Disconnect error: $e');
      return false;
    }
  }
  
  /// Check connection status
  Future<bool> checkConnection() async {
    try {
      final result = await _channel.invokeMethod('isConnected');
      _isConnected = result == true;
      return _isConnected;
    } catch (e) {
      debugPrint('LibGPhoto2Service: Connection check error: $e');
      return false;
    }
  }
  
  /// Start live view streaming
  Future<bool> startLiveView() async {
    try {
      debugPrint('LibGPhoto2Service: Starting live view');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot start live view');
        return false;
      }
      
      if (_isLiveViewActive) {
        debugPrint('LibGPhoto2Service: Live view already active');
        return true;
      }
      
      // Create stream controller for live view frames
      _liveViewStreamController = StreamController<Uint8List>.broadcast();
      
      final result = await _channel.invokeMethod('startLiveView');
      _isLiveViewActive = result == true;
      
      if (_isLiveViewActive) {
        debugPrint('LibGPhoto2Service: Live view started successfully');
      } else {
        debugPrint('LibGPhoto2Service: Live view start failed');
        await _liveViewStreamController?.close();
        _liveViewStreamController = null;
      }
      
      return _isLiveViewActive;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Live view start error: $e');
      await _liveViewStreamController?.close();
      _liveViewStreamController = null;
      return false;
    }
  }
  
  /// Stop live view streaming
  Future<bool> stopLiveView() async {
    try {
      debugPrint('LibGPhoto2Service: Stopping live view');
      
      _isLiveViewActive = false;
      
      // Close stream controller
      await _liveViewStreamController?.close();
      _liveViewStreamController = null;
      
      final result = await _channel.invokeMethod('stopLiveView');
      
      debugPrint('LibGPhoto2Service: Live view stopped');
      return result == true;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Live view stop error: $e');
      return false;
    }
  }
  
  /// Capture a photo
  Future<Map<String, String>?> capturePhoto() async {
    try {
      debugPrint('LibGPhoto2Service: Capturing photo');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot capture photo');
        return null;
      }
      
      final result = await _channel.invokeMethod('capturePhoto');
      
      if (result is Map<String, dynamic>) {
        final photoInfo = Map<String, String>.from(result);
        debugPrint('LibGPhoto2Service: Photo captured: ${photoInfo['filename']}');
        return photoInfo;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Photo capture error: $e');
      return null;
    }
  }
  
  /// Download a file from camera
  Future<Uint8List?> downloadFile(String folder, String filename) async {
    try {
      debugPrint('LibGPhoto2Service: Downloading file $folder/$filename');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot download file');
        return null;
      }
      
      final result = await _channel.invokeMethod('downloadFile', {
        'folder': folder,
        'filename': filename,
      });
      
      if (result is Uint8List) {
        debugPrint('LibGPhoto2Service: File downloaded: ${result.length} bytes');
        return result;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: File download error: $e');
      return null;
    }
  }
  
  /// Set camera setting (ISO, aperture, etc.)
  Future<bool> setSetting(String settingName, String value) async {
    try {
      debugPrint('LibGPhoto2Service: Setting $settingName = $value');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot set setting');
        return false;
      }
      
      final result = await _channel.invokeMethod('setSetting', {
        'settingName': settingName,
        'value': value,
      });
      
      final success = result == true;
      if (success) {
        debugPrint('LibGPhoto2Service: Setting $settingName applied successfully');
      } else {
        debugPrint('LibGPhoto2Service: Failed to set $settingName');
      }
      
      return success;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Set setting error: $e');
      return false;
    }
  }
  
  /// Get camera setting value
  Future<String?> getSetting(String settingName) async {
    try {
      debugPrint('LibGPhoto2Service: Getting setting $settingName');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot get setting');
        return null;
      }
      
      final result = await _channel.invokeMethod('getSetting', {
        'settingName': settingName,
      });
      
      if (result is String) {
        debugPrint('LibGPhoto2Service: Setting $settingName = $result');
        return result;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Get setting error: $e');
      return null;
    }
  }
  
  /// Get available choices for a setting
  Future<List<String>> getSettingChoices(String settingName) async {
    try {
      debugPrint('LibGPhoto2Service: Getting setting choices for $settingName');
      
      if (!_isConnected) {
        debugPrint('LibGPhoto2Service: Not connected, cannot get setting choices');
        return [];
      }
      
      final result = await _channel.invokeMethod('getSettingChoices', {
        'settingName': settingName,
      });
      
      if (result is List) {
        final choices = result.cast<String>();
        debugPrint('LibGPhoto2Service: Setting $settingName has ${choices.length} choices');
        return choices;
      }
      
      return [];
      
    } catch (e) {
      debugPrint('LibGPhoto2Service: Get setting choices error: $e');
      return [];
    }
  }
  
  /// Convenience methods for common camera settings
  
  /// Set ISO value
  Future<bool> setISO(String iso) async {
    return await setSetting('iso', iso);
  }
  
  /// Set aperture value (f-stop)
  Future<bool> setAperture(String aperture) async {
    return await setSetting('aperture', aperture);
  }
  
  /// Set shutter speed
  Future<bool> setShutterSpeed(String shutterSpeed) async {
    return await setSetting('shutterspeed', shutterSpeed);
  }
  
  /// Set white balance
  Future<bool> setWhiteBalance(String whiteBalance) async {
    return await setSetting('whitebalance', whiteBalance);
  }
  
  /// Set focus mode
  Future<bool> setFocusMode(String focusMode) async {
    return await setSetting('focusmode', focusMode);
  }
  
  /// Set image quality
  Future<bool> setImageQuality(String quality) async {
    return await setSetting('imagequality', quality);
  }
  
  /// Get available ISO values
  Future<List<String>> getISOChoices() async {
    return await getSettingChoices('iso');
  }
  
  /// Get available aperture values
  Future<List<String>> getApertureChoices() async {
    return await getSettingChoices('aperture');
  }
  
  /// Get available shutter speed values
  Future<List<String>> getShutterSpeedChoices() async {
    return await getSettingChoices('shutterspeed');
  }
  
  /// Get available white balance options
  Future<List<String>> getWhiteBalanceChoices() async {
    return await getSettingChoices('whitebalance');
  }
  
  /// Handle events from native side
  void _handleNativeEvent(dynamic event) {
    debugPrint('LibGPhoto2Service: Raw native event received: $event');
    
    // Handle both Map<String, dynamic> and Map<Object?, Object?> from platform channels
    Map<String, dynamic>? eventMap;
    if (event is Map<String, dynamic>) {
      eventMap = event;
    } else if (event is Map) {
      // Convert Map<Object?, Object?> to Map<String, dynamic>
      try {
        eventMap = Map<String, dynamic>.from(event);
        debugPrint('LibGPhoto2Service: ✅ Converted Map<Object?, Object?> to Map<String, dynamic>');
      } catch (e) {
        debugPrint('LibGPhoto2Service: ❌ Failed to convert event map: $e');
        return;
      }
    } else {
      debugPrint('LibGPhoto2Service: ❌ Event is not a Map: ${event.runtimeType}');
      return;
    }
    
    if (eventMap != null) {
      final type = eventMap['type'] as String?;
      final message = eventMap['message'] as String?;
      final method = eventMap['method'] as String?;
      final source = eventMap['source'] as String?;
      
      debugPrint('LibGPhoto2Service: Native event - source: $source, type: $type, method: $method, message: $message');
      debugPrint('LibGPhoto2Service: Event keys: ${eventMap.keys.toList()}');
      
      // Handle connection status events (with 'type' field)
      switch (type) {
        case 'connected':
          _isConnected = true;
          break;
        case 'disconnected':
          _isConnected = false;
          _isLiveViewActive = false;
          break;
        case 'live_view_started':
          _isLiveViewActive = true;
          break;
        case 'live_view_stopped':
          _isLiveViewActive = false;
          break;
        default:
          break;
      }
      
      // Handle live view frames (method-based events from libgphoto2)
      final eventMethod = eventMap['method'];
      final eventData = eventMap['data'];
      final hasJpegData = eventData is List && eventData.isNotEmpty && 
                         eventData.length > 1 && eventData[0] == 255 && eventData[1] == 216;
      
      debugPrint('LibGPhoto2Service: 🔍 Event analysis: method="$eventMethod", hasData=${eventData != null}, dataLength=${eventData is List ? eventData.length : 0}, hasJpegData=$hasJpegData');
      
      // Process live view image frames
      if (eventMethod == 'onLiveViewImage') {
        debugPrint('LibGPhoto2Service: ✅ Processing live view frame event');
        final data = eventMap['data'];
        debugPrint('LibGPhoto2Service: Data type: ${data.runtimeType}, data length: ${data is List ? data.length : 'N/A'}');
        debugPrint('LibGPhoto2Service: Stream controller status: ${_liveViewStreamController != null ? 'AVAILABLE' : 'NULL'}');
        
        if (!hasJpegData) {
          debugPrint('LibGPhoto2Service: ⚠️ Event data does not have valid JPEG header');
        }
        
        // Initialize stream controller if not already done and we have valid data
        if (_liveViewStreamController == null && hasJpegData) {
          debugPrint('LibGPhoto2Service: 🔧 Auto-initializing stream controller for incoming live view data');
          _liveViewStreamController = StreamController<Uint8List>.broadcast();
          _isLiveViewActive = true;
        }
        
        if (_liveViewStreamController != null && data != null && hasJpegData) {
          Uint8List? imageData;
          
          if (data is Uint8List) {
            imageData = data;
            debugPrint('LibGPhoto2Service: Direct Uint8List: ${imageData.length} bytes');
          } else if (data is List<int>) {
            // Convert efficiently without intermediate List
            imageData = Uint8List.fromList(data);
            debugPrint('LibGPhoto2Service: Converted List<int> to Uint8List: ${imageData.length} bytes');
          } else if (data is List<dynamic>) {
            // Handle dynamic list from Flutter platform channel
            try {
              final intList = data.cast<int>();
              imageData = Uint8List.fromList(intList);
              debugPrint('LibGPhoto2Service: Converted List<dynamic> to Uint8List: ${imageData.length} bytes');
            } catch (e) {
              debugPrint('LibGPhoto2Service: Failed to convert List<dynamic>: $e');
              return;
            }
          } else {
            debugPrint('LibGPhoto2Service: Unexpected data type: ${data.runtimeType}');
            return;
          }
          
          if (imageData != null && imageData.isNotEmpty) {
            // Validate JPEG header before sending to stream
            if (imageData.length > 10 && imageData[0] == 0xFF && imageData[1] == 0xD8) {
              debugPrint('LibGPhoto2Service: ✅ Adding valid JPEG frame to stream (${imageData.length} bytes)');
              _liveViewStreamController!.add(imageData);
            } else {
              debugPrint('LibGPhoto2Service: ❌ Invalid JPEG frame - header: [${imageData.take(4).join(', ')}]');
            }
          } else {
            debugPrint('LibGPhoto2Service: ❌ No valid image data to add to stream');
          }
        } else {
          debugPrint('LibGPhoto2Service: ❌ Stream controller not available or no data - controller: ${_liveViewStreamController != null}, data: ${data != null}');
        }
      } else if (hasJpegData) {
        // Handle JPEG data even without specific method (for direct data events)
        debugPrint('LibGPhoto2Service: ✅ Processing JPEG data without specific method');
        final data = eventMap['data'];
        debugPrint('LibGPhoto2Service: Data type: ${data.runtimeType}, data length: ${data is List ? data.length : 'N/A'}');
        
        // Initialize stream controller if not already done
        if (_liveViewStreamController == null) {
          debugPrint('LibGPhoto2Service: 🔧 Auto-initializing stream controller for JPEG data');
          _liveViewStreamController = StreamController<Uint8List>.broadcast();
          _isLiveViewActive = true;
        }
        
        if (_liveViewStreamController != null && data != null) {
          Uint8List? imageData;
          
          if (data is Uint8List) {
            imageData = data;
            debugPrint('LibGPhoto2Service: Direct Uint8List: ${imageData.length} bytes');
          } else if (data is List<int>) {
            imageData = Uint8List.fromList(data);
            debugPrint('LibGPhoto2Service: Converted List<int> to Uint8List: ${imageData.length} bytes');
          } else if (data is List<dynamic>) {
            try {
              final intList = data.cast<int>();
              imageData = Uint8List.fromList(intList);
              debugPrint('LibGPhoto2Service: Converted List<dynamic> to Uint8List: ${imageData.length} bytes');
            } catch (e) {
              debugPrint('LibGPhoto2Service: Failed to convert List<dynamic>: $e');
              return;
            }
          }
          
          if (imageData != null && imageData.isNotEmpty) {
            if (imageData.length > 10 && imageData[0] == 0xFF && imageData[1] == 0xD8) {
              debugPrint('LibGPhoto2Service: ✅ Adding valid JPEG frame to stream (${imageData.length} bytes)');
              _liveViewStreamController!.add(imageData);
            } else {
              debugPrint('LibGPhoto2Service: ❌ Invalid JPEG frame - header: [${imageData.take(4).join(', ')}]');
            }
          }
        }
      } else {
        debugPrint('LibGPhoto2Service: ⚠️ Event has no recognizable JPEG data or method');
      }
    }
  }
  
  /// Cleanup resources
  void dispose() {
    debugPrint('LibGPhoto2Service: Disposing');
    
    _eventSubscription?.cancel();
    _liveViewStreamController?.close();
    _liveViewStreamController = null;
    
    _isInitialized = false;
    _isConnected = false;
    _isLiveViewActive = false;
  }
}

/// Camera setting names for convenience
class CameraSettings {
  static const String iso = 'iso';
  static const String aperture = 'aperture'; 
  static const String shutterSpeed = 'shutterspeed';
  static const String whiteBalance = 'whitebalance';
  static const String focusMode = 'focusmode';
  static const String imageQuality = 'imagequality';
  static const String liveView = 'liveview';
  static const String captureMode = 'capturemode';
  static const String meteringMode = 'meteringmode';
  static const String exposureMode = 'exposuremode';
}

/// Common camera setting values
class CameraValues {
  // ISO values
  static const List<String> commonISO = [
    '100', '200', '400', '800', '1600', '3200', '6400'
  ];
  
  // Aperture values (f-stops)
  static const List<String> commonAperture = [
    'f/1.4', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16'
  ];
  
  // Shutter speeds
  static const List<String> commonShutterSpeed = [
    '1/1000', '1/500', '1/250', '1/125', '1/60', '1/30', '1/15', '1/8', '1/4', '1/2', '1', '2'
  ];
  
  // White balance presets
  static const List<String> commonWhiteBalance = [
    'Auto', 'Daylight', 'Cloudy', 'Shade', 'Tungsten', 'Fluorescent', 'Flash'
  ];
  
  // Focus modes
  static const List<String> commonFocusMode = [
    'Manual', 'Single', 'Continuous', 'Auto'
  ];
}// Hot reload trigger
