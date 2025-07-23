import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/cloud_sync.dart';

class CloudSyncService {
  static const String baseUrl = 'http://localhost:3000/api/cloud';
  final http.Client _client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();

  CloudSyncService({http.Client? client}) : _client = client ?? http.Client();

  // Initialize cloud sync for the user
  Future<void> initializeSync() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      final response = await _client.post(
        Uri.parse('$baseUrl/init'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode({
          'deviceInfo': deviceInfo,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to initialize sync: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error initializing sync: $e');
    }
  }

  // Get current sync status
  Future<CloudSyncStatus> getSyncStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CloudSyncStatus.fromJson(data['data']);
      } else {
        throw Exception('Failed to get sync status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting sync status: $e');
    }
  }

  // Trigger manual sync
  Future<Map<String, dynamic>> triggerSync({
    bool? syncPhotos,
    bool? syncSettings,
    bool? syncPresets,
    int priority = 5,
  }) async {
    try {
      // Check network connectivity if sync is set to WiFi only
      final syncStatus = await getSyncStatus();
      if (syncStatus.syncSettings.syncOnWiFiOnly) {
        final isWiFi = await _isConnectedToWiFi();
        if (!isWiFi) {
          throw Exception('Sync requires WiFi connection');
        }
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode({
          'syncPhotos': syncPhotos,
          'syncSettings': syncSettings,
          'syncPresets': syncPresets,
          'priority': priority,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to trigger sync: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error triggering sync: $e');
    }
  }

  // Update sync settings
  Future<void> updateSyncSettings(SyncSettings settings) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode(settings.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update sync settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error updating sync settings: $e');
    }
  }

  // Upload photo to cloud
  Future<Map<String, dynamic>> uploadPhoto(
    File photoFile, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/photos/upload'));
      
      request.headers['Authorization'] = 'Bearer ${await _getAuthToken()}';
      
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoFile.path),
      );

      if (metadata != null) {
        request.fields['metadata'] = json.encode(metadata);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to upload photo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error uploading photo: $e');
    }
  }

  // Delete photo from cloud
  Future<void> deletePhoto(String photoId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/photos/$photoId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete photo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error deleting photo: $e');
    }
  }

  // Get user's cloud photos
  Future<List<CloudPhoto>> getCloudPhotos({
    int page = 1,
    int limit = 20,
    String? syncStatus,
    String sortBy = 'capturedAt',
    String sortOrder = 'desc',
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

      if (syncStatus != null) {
        queryParams['syncStatus'] = syncStatus;
      }

      final uri = Uri.parse('$baseUrl/photos').replace(queryParameters: queryParams);
      
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final photosList = data['data']['photos'] as List;
        return photosList.map((photo) => CloudPhoto.fromJson(photo)).toList();
      } else {
        throw Exception('Failed to get cloud photos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting cloud photos: $e');
    }
  }

  // Update cloud settings (camera defaults, user preferences, app settings)
  Future<void> updateCloudSettings(
    String settingsType,
    Map<String, dynamic> settingsData,
  ) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      final response = await _client.put(
        Uri.parse('$baseUrl/user-settings/$settingsType'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode({
          'settingsData': settingsData,
          'deviceId': deviceInfo['deviceId'],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update cloud settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error updating cloud settings: $e');
    }
  }

  // Get cloud settings
  Future<Map<String, dynamic>> getCloudSettings(String settingsType) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/user-settings/$settingsType'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else if (response.statusCode == 404) {
        // Settings not found, return empty
        return {};
      } else {
        throw Exception('Failed to get cloud settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting cloud settings: $e');
    }
  }

  // Resolve sync conflict
  Future<void> resolveConflict(
    String conflictId,
    String resolution, {
    Map<String, dynamic>? selectedVersion,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/conflicts/$conflictId/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode({
          'resolution': resolution,
          'selectedVersion': selectedVersion,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to resolve conflict: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error resolving conflict: $e');
    }
  }

  // Check if auto-sync should run
  Future<bool> shouldAutoSync() async {
    try {
      final syncStatus = await getSyncStatus();
      
      // Don't sync if already syncing or has errors
      if (syncStatus.isSyncing || syncStatus.hasErrors) {
        return false;
      }

      // Don't sync if auto-sync is disabled
      if (!syncStatus.syncSettings.autoSync) {
        return false;
      }

      // Check WiFi requirement
      if (syncStatus.syncSettings.syncOnWiFiOnly) {
        final isWiFi = await _isConnectedToWiFi();
        if (!isWiFi) {
          return false;
        }
      }

      // Check if sync is due based on frequency
      if (syncStatus.nextSyncAt != null) {
        final now = DateTime.now();
        return now.isAfter(syncStatus.nextSyncAt!);
      }

      return true;
    } catch (e) {
      print('Error checking auto-sync: $e');
      return false;
    }
  }

  // Get sync health status
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error checking health: $e');
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    String deviceId;
    String deviceName;
    String platform;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      platform = 'android';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
      deviceName = '${iosInfo.name} (${iosInfo.model})';
      platform = 'ios';
    } else {
      deviceId = 'unknown';
      deviceName = 'Unknown Device';
      platform = 'unknown';
    }

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
    };
  }

  Future<bool> _isConnectedToWiFi() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<String> _getAuthToken() async {
    // Implementation would get actual auth token from secure storage
    // For now, return placeholder
    return 'placeholder_auth_token';
  }

  // Background sync management
  Future<void> scheduleBackgroundSync() async {
    // Implementation would use platform-specific background task scheduling
    // This is a placeholder for the actual background sync setup
    print('Background sync scheduled');
  }

  Future<void> cancelBackgroundSync() async {
    // Implementation would cancel platform-specific background tasks
    print('Background sync cancelled');
  }

  // Batch operations for efficiency
  Future<List<Map<String, dynamic>>> batchUploadPhotos(
    List<File> photos, {
    Map<String, dynamic>? commonMetadata,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    // Upload in batches of 5 to avoid overwhelming the server
    const batchSize = 5;
    for (int i = 0; i < photos.length; i += batchSize) {
      final batch = photos.skip(i).take(batchSize);
      final batchResults = await Future.wait(
        batch.map((photo) => uploadPhoto(photo, metadata: commonMetadata)),
      );
      results.addAll(batchResults);
    }
    
    return results;
  }

  // Sync progress monitoring
  Stream<CloudSyncStatus> watchSyncStatus() async* {
    while (true) {
      try {
        final status = await getSyncStatus();
        yield status;
        
        // Poll every 5 seconds during sync, every 30 seconds otherwise
        final pollInterval = status.isSyncing ? 5 : 30;
        await Future.delayed(Duration(seconds: pollInterval));
      } catch (e) {
        print('Error watching sync status: $e');
        await Future.delayed(const Duration(seconds: 30));
      }
    }
  }

  // Conflict resolution helpers
  List<SyncConflict> getUnresolvedConflicts(CloudSyncStatus status) {
    return status.conflicts.where((conflict) => !conflict.isResolved).toList();
  }

  bool hasUnresolvedConflicts(CloudSyncStatus status) {
    return getUnresolvedConflicts(status).isNotEmpty;
  }

  // Storage management
  Future<bool> isStorageNearQuota() async {
    try {
      final status = await getSyncStatus();
      return status.storageUsage.isNearQuota;
    } catch (e) {
      print('Error checking storage quota: $e');
      return false;
    }
  }

  Future<bool> isStorageOverQuota() async {
    try {
      final status = await getSyncStatus();
      return status.storageUsage.isOverQuota;
    } catch (e) {
      print('Error checking storage quota: $e');
      return false;
    }
  }

  // Clean up resources
  void dispose() {
    _client.close();
  }
}