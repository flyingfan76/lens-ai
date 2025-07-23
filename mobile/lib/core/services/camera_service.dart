import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  
  CacheEntry(this.data, this.timestamp);
  
  bool isExpired(Duration expiry) {
    return DateTime.now().difference(timestamp) > expiry;
  }
}

class CameraService {
  static const String baseUrl = 'http://localhost:3000/api/camera';
  
  // Caching
  final Map<String, CacheEntry> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // HTTP client with connection pooling
  late final http.Client _httpClient;
  
  CameraService() {
    _httpClient = http.Client();
  }
  
  T? _getCachedData<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired(_cacheExpiry)) {
      return entry.data as T;
    }
    _cache.remove(key); // Remove expired entry
    return null;
  }
  
  void _setCachedData(String key, dynamic data) {
    _cache[key] = CacheEntry(data, DateTime.now());
  }
  
  void clearCache() {
    _cache.clear();
  }
  
  Future<List<Map<String, dynamic>>> discoverCameras({bool forceRefresh = false}) async {
    const cacheKey = 'discovered_cameras';
    
    // Return cached data if available and not forcing refresh
    if (!forceRefresh) {
      final cached = _getCachedData<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/discover'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cameras = List<Map<String, dynamic>>.from(data['cameras'] ?? []);
        _setCachedData(cacheKey, cameras);
        return cameras;
      } else {
        throw Exception('Failed to discover cameras');
      }
    } catch (e) {
      debugPrint('Camera discovery error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getCameraStatus({bool useCache = true}) async {
    const cacheKey = 'camera_status';
    
    if (useCache) {
      final cached = _getCachedData<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/status'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] ?? {};
        _setCachedData(cacheKey, status);
        return status;
      } else {
        throw Exception('Failed to get camera status');
      }
    } catch (e) {
      debugPrint('Get camera status error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> connectToCamera({
    required String cameraId,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cameraId': cameraId,
        }),
      );
      
      if (response.statusCode == 200) {
        // Clear status cache since connection state changed
        _cache.remove('camera_status');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to connect to camera');
      }
    } catch (e) {
      debugPrint('Camera connection error: $e');
      rethrow;
    }
  }
  
  Future<bool> setActiveCamera(String cameraId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set-active'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cameraId': cameraId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Set active camera error: $e');
      return false;
    }
  }
  
  Future<bool> disconnectCamera({String? cameraId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (cameraId != null) 'cameraId': cameraId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Camera disconnection error: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getCameraSettings({String? cameraId}) async {
    try {
      final uri = Uri.parse('$baseUrl/settings');
      final response = await http.get(
        cameraId != null ? uri.replace(queryParameters: {'cameraId': cameraId}) : uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'settings': data['settings'] ?? {},
          'cameraId': data['cameraId'],
          'brand': data['brand'],
        };
      } else {
        throw Exception('Failed to get camera settings');
      }
    } catch (e) {
      debugPrint('Get settings error: $e');
      rethrow;
    }
  }
  
  Future<bool> updateCameraSettings(Map<String, dynamic> settings, {String? cameraId}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'settings': settings,
          if (cameraId != null) 'cameraId': cameraId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update settings error: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> startLiveView({String? cameraId}) async {
    try {
      final uri = Uri.parse('$baseUrl/liveview/start');
      final response = await http.get(
        cameraId != null ? uri.replace(queryParameters: {'cameraId': cameraId}) : uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to start live view');
      }
    } catch (e) {
      debugPrint('Live view error: $e');
      rethrow;
    }
  }
  
  Future<bool> stopLiveView({String? cameraId}) async {
    try {
      final uri = Uri.parse('$baseUrl/liveview/stop');
      final response = await http.get(
        cameraId != null ? uri.replace(queryParameters: {'cameraId': cameraId}) : uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Stop live view error: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> captureImage({
    Map<String, dynamic>? settings,
    String? cameraId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/capture'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'settings': settings ?? {},
          if (cameraId != null) 'cameraId': cameraId,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to capture image');
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      rethrow;
    }
  }
  
  void dispose() {
    _httpClient.close();
    clearCache();
  }
}