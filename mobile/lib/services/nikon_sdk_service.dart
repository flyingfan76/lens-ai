import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to interface with native Nikon SDK for real live view functionality
class NikonSDKService {
  static const MethodChannel _channel = MethodChannel('nikon_sdk_bridge');
  static const EventChannel _eventChannel = EventChannel('nikon_sdk_events');
  
  static NikonSDKService? _instance;
  factory NikonSDKService() => _instance ??= NikonSDKService._internal();
  NikonSDKService._internal();
  
  StreamController<Uint8List>? _liveViewStreamController;
  StreamSubscription? _eventSubscription;
  bool _isLiveViewActive = false;
  
  Stream<Uint8List>? get liveViewStream => _liveViewStreamController?.stream;
  bool get isLiveViewActive => _isLiveViewActive;
  
  /// Initialize the SDK service
  Future<void> initialize() async {
    try {
      debugPrint('NikonSDKService: Initializing native SDK bridge');
      debugPrint('NikonSDKService: Method channel: ${_channel.name}');
      debugPrint('NikonSDKService: Event channel: ${_eventChannel.name}');
      
      // Listen for live view events from native side
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          debugPrint('NikonSDKService: Received event: $event');
          if (event is Map && event['method'] == 'onLiveViewImage') {
            final imageData = event['data'] as Uint8List?;
            if (imageData != null && _liveViewStreamController != null) {
              debugPrint('NikonSDKService: Received live view image: ${imageData.length} bytes');
              _liveViewStreamController!.add(imageData);
            }
          }
        },
        onError: (error) {
          debugPrint('NikonSDKService: Event stream error: $error');
        },
      );
      
      debugPrint('NikonSDKService: SDK bridge initialized successfully');
      
    } catch (e) {
      debugPrint('NikonSDKService: Initialization error: $e');
    }
  }
  
  /// Start live view streaming from connected Nikon camera
  Future<bool> startLiveView() async {
    try {
      debugPrint('NikonSDKService: Starting live view via method channel');
      
      if (_isLiveViewActive) {
        await stopLiveView();
      }
      
      _liveViewStreamController = StreamController<Uint8List>.broadcast();
      
      debugPrint('NikonSDKService: Invoking startLiveView method on channel: ${_channel.name}');
      final result = await _channel.invokeMethod('startLiveView');
      debugPrint('NikonSDKService: Method channel returned: $result');
      
      if (result == true) {
        _isLiveViewActive = true;
        debugPrint('NikonSDKService: Live view started successfully');
        return true;
      } else {
        await _liveViewStreamController?.close();
        _liveViewStreamController = null;
        debugPrint('NikonSDKService: Method returned false - failed to start live view');
        return false;
      }
      
    } catch (e) {
      debugPrint('NikonSDKService: Start live view method channel error: $e');
      await _liveViewStreamController?.close();
      _liveViewStreamController = null;
      return false;
    }
  }
  
  /// Stop live view streaming
  Future<void> stopLiveView() async {
    try {
      debugPrint('NikonSDKService: Stopping live view');
      
      _isLiveViewActive = false;
      
      await _channel.invokeMethod('stopLiveView');
      await _liveViewStreamController?.close();
      _liveViewStreamController = null;
      
      debugPrint('NikonSDKService: Live view stopped');
      
    } catch (e) {
      debugPrint('NikonSDKService: Stop live view error: $e');
    }
  }
  
  /// Get a single live view image
  Future<Uint8List?> getLiveViewImage() async {
    try {
      final result = await _channel.invokeMethod('getLiveViewImage');
      return result as Uint8List?;
    } catch (e) {
      debugPrint('NikonSDKService: Get live view image error: $e');
      return null;
    }
  }
  
  /// Check if Nikon camera is connected
  Future<bool> isCameraConnected() async {
    try {
      debugPrint('NikonSDKService: Testing camera connection via method channel');
      final result = await _channel.invokeMethod('isCameraConnected');
      debugPrint('NikonSDKService: Camera connection check returned: $result');
      return result == true;
    } catch (e) {
      debugPrint('NikonSDKService: Camera connection check error: $e');
      return false;
    }
  }
  
  /// Test method to verify method channel is working
  Future<bool> testConnection() async {
    try {
      debugPrint('NikonSDKService: Testing method channel connectivity');
      final result = await _channel.invokeMethod('test');
      debugPrint('NikonSDKService: Test method returned: $result');
      return result == true;
    } catch (e) {
      debugPrint('NikonSDKService: Test method error: $e');
      return false;
    }
  }
  
  /// Advanced PTP management with multiple strategies
  Future<bool> managePTP(String action) async {
    try {
      debugPrint('NikonSDKService: Managing PTP - action: $action');
      final result = await _channel.invokeMethod('managePTP', {'action': action});
      debugPrint('NikonSDKService: Manage PTP returned: $result');
      return result == true;
    } catch (e) {
      debugPrint('NikonSDKService: Manage PTP error: $e');
      return false;
    }
  }
  
  /// Stop macOS PTP services that block camera access
  Future<bool> stopPTPService() async {
    return await managePTP('disable');
  }
  
  /// Re-enable PTP services
  Future<bool> enablePTPService() async {
    return await managePTP('enable');
  }
  
  /// Check PTP daemon status
  Future<bool> isPTPRunning() async {
    return await managePTP('status');
  }
  
  /// Request exclusive USB access for camera
  Future<bool> requestExclusiveAccess() async {
    try {
      debugPrint('NikonSDKService: Requesting exclusive USB access');
      final result = await _channel.invokeMethod('requestExclusiveAccess');
      debugPrint('NikonSDKService: Exclusive access returned: $result');
      return result == true;
    } catch (e) {
      debugPrint('NikonSDKService: Exclusive access error: $e');
      return false;
    }
  }
  
  /// Capture a photo using the connected camera
  Future<bool> capturePhoto() async {
    try {
      debugPrint('NikonSDKService: Capturing photo');
      final result = await _channel.invokeMethod('capturePhoto');
      debugPrint('NikonSDKService: Capture photo returned: $result');
      return result == true;
    } catch (e) {
      debugPrint('NikonSDKService: Capture photo error: $e');
      return false;
    }
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _liveViewStreamController?.close();
    _liveViewStreamController = null;
    _isLiveViewActive = false;
  }
}