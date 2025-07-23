import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/auto_adjustment.dart';

class AutoAdjustmentService {
  static const String baseUrl = 'http://localhost:3000/api/auto-adjustment';
  final http.Client _client;

  AutoAdjustmentService({http.Client? client}) : _client = client ?? http.Client();

  // Analyze image and get parameter recommendations
  Future<AutoAdjustmentResult> analyzeAndAdjust({
    required File imageFile,
    required CameraSettings currentSettings,
    String? cameraBrand,
    String? mode,
    UserPreferences? userPreferences,
    Map<String, dynamic>? constraints,
    String? userId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      request.headers['Content-Type'] = 'multipart/form-data';
      
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      request.fields['currentSettings'] = json.encode(currentSettings.toJson());
      
      if (cameraBrand != null) {
        request.fields['cameraBrand'] = cameraBrand;
      }
      
      if (mode != null) {
        request.fields['mode'] = mode;
      }
      
      if (userPreferences != null) {
        request.fields['userPreferences'] = json.encode(userPreferences.toJson());
      }
      
      if (constraints != null) {
        request.fields['constraints'] = json.encode(constraints);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AutoAdjustmentResult.fromJson(data['data']);
      } else {
        throw Exception('Analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during analysis: $e');
    }
  }

  // Get parameter recommendations without image analysis
  Future<AutoAdjustmentResult> getRecommendations({
    required String sceneType,
    required CameraSettings currentSettings,
    String? lightiningCondition,
    String? cameraBrand,
    String? mode,
    UserPreferences? userPreferences,
    Map<String, dynamic>? constraints,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sceneType': sceneType,
          'lightingCondition': lightiningCondition,
          'currentSettings': currentSettings.toJson(),
          'cameraBrand': cameraBrand,
          'mode': mode,
          'userPreferences': userPreferences?.toJson(),
          'constraints': constraints,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AutoAdjustmentResult.fromJson(data['data']);
      } else {
        throw Exception('Recommendation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting recommendations: $e');
    }
  }

  // Start real-time adjustment session
  Future<String> startRealtimeAdjustment({
    String? cameraBrand,
    int? interval,
  }) async {
    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final response = await _client.post(
        Uri.parse('$baseUrl/realtime/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sessionId': sessionId,
          'cameraBrand': cameraBrand,
          'interval': interval,
        }),
      );

      if (response.statusCode == 200) {
        return sessionId;
      } else {
        throw Exception('Failed to start real-time adjustment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error starting real-time adjustment: $e');
    }
  }

  // Stop real-time adjustment session
  Future<void> stopRealtimeAdjustment(String sessionId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/realtime/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sessionId': sessionId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to stop real-time adjustment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error stopping real-time adjustment: $e');
    }
  }

  // Get user preferences
  Future<UserPreferences> getUserPreferences([String? userId]) async {
    try {
      final endpoint = userId != null ? '$baseUrl/preferences/$userId' : '$baseUrl/preferences';
      
      final response = await _client.get(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserPreferences.fromJson(data['data']);
      } else {
        throw Exception('Failed to get preferences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting preferences: $e');
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(UserPreferences preferences, [String? userId]) async {
    try {
      final endpoint = userId != null ? '$baseUrl/preferences/$userId' : '$baseUrl/preferences';
      
      final response = await _client.put(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(preferences.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update preferences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error updating preferences: $e');
    }
  }

  // Record user feedback for learning
  Future<void> recordUserFeedback({
    required String userId,
    required String sceneType,
    required String lightingCondition,
    required CameraSettings originalSettings,
    required CameraSettings suggestedSettings,
    required CameraSettings finalSettings,
    required String userAction, // 'accepted', 'modified', 'rejected'
    double? confidence,
    int? processingTime,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'sceneType': sceneType,
          'lightingCondition': lightingCondition,
          'originalSettings': originalSettings.toJson(),
          'suggestedSettings': suggestedSettings.toJson(),
          'finalSettings': finalSettings.toJson(),
          'userAction': userAction,
          'confidence': confidence,
          'processingTime': processingTime,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to record feedback: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error recording feedback: $e');
    }
  }

  // Get learning insights for user
  Future<List<LearningInsight>> getLearningInsights(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/insights/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final insights = data['data']['insights'] as List;
        return insights.map((insight) => LearningInsight.fromJson(insight)).toList();
      } else {
        throw Exception('Failed to get insights: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting insights: $e');
    }
  }

  // Get adjustment history
  Future<List<Map<String, dynamic>>> getAdjustmentHistory({
    String? userId,
    int limit = 50,
    String? sceneType,
    String? lightingCondition,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (sceneType != null) queryParams['sceneType'] = sceneType;
      if (lightingCondition != null) queryParams['lightingCondition'] = lightingCondition;

      final endpoint = userId != null ? '$baseUrl/history/$userId' : '$baseUrl/history';
      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']['entries'] ?? []);
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting history: $e');
    }
  }

  // Get adjustment statistics
  Future<Map<String, dynamic>> getAdjustmentStats() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting stats: $e');
    }
  }

  // Validate camera settings
  Future<Map<String, dynamic>> validateSettings({
    required CameraSettings settings,
    String? cameraBrand,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/validate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'settings': settings.toJson(),
          'cameraBrand': cameraBrand,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to validate settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error validating settings: $e');
    }
  }

  // Check service health
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
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

  // Helper method to determine if auto-adjustment should be triggered
  bool shouldTriggerAutoAdjustment({
    required CameraSettings currentSettings,
    required String sceneType,
    required String lightingCondition,
  }) {
    // Simple heuristics for when to suggest auto-adjustment
    
    // Always trigger for scene type changes
    if (sceneType == 'sports' || sceneType == 'macro') {
      return true;
    }
    
    // Trigger for extreme lighting conditions
    if (lightingCondition == 'very_dark' || lightingCondition == 'bright') {
      return true;
    }
    
    // Trigger for potentially problematic ISO values
    if (currentSettings.iso > 1600 || currentSettings.iso < 100) {
      return true;
    }
    
    return false;
  }

  // Calculate similarity between two camera settings
  double calculateSettingsSimilarity(CameraSettings settings1, CameraSettings settings2) {
    double isoSimilarity = 1.0 - (settings1.iso - settings2.iso).abs() / 
        [settings1.iso, settings2.iso].reduce((a, b) => a > b ? a : b);
    
    // Simplified aperture comparison
    double aperture1 = double.parse(settings1.aperture.replaceAll('f/', ''));
    double aperture2 = double.parse(settings2.aperture.replaceAll('f/', ''));
    double apertureSimilarity = 1.0 - (aperture1 - aperture2).abs() / 
        [aperture1, aperture2].reduce((a, b) => a > b ? a : b);
    
    return (isoSimilarity + apertureSimilarity) / 2;
  }

  // Generate user-friendly explanation for adjustments
  String generateAdjustmentExplanation(
    CameraSettings original, 
    CameraSettings optimized,
    String sceneType,
  ) {
    final List<String> explanations = [];
    
    // ISO changes
    if (original.iso != optimized.iso) {
      if (optimized.iso > original.iso) {
        explanations.add('Increased ISO to ${optimized.iso} for better exposure');
      } else {
        explanations.add('Reduced ISO to ${optimized.iso} to minimize noise');
      }
    }
    
    // Aperture changes
    if (original.aperture != optimized.aperture) {
      final originalF = double.parse(original.aperture.replaceAll('f/', ''));
      final optimizedF = double.parse(optimized.aperture.replaceAll('f/', ''));
      
      if (optimizedF < originalF) {
        explanations.add('Opened aperture to ${optimized.aperture} for shallower depth of field');
      } else {
        explanations.add('Stopped down to ${optimized.aperture} for sharper overall focus');
      }
    }
    
    // Shutter speed changes
    if (original.shutterSpeed != optimized.shutterSpeed) {
      explanations.add('Adjusted shutter speed to ${optimized.shutterSpeed}');
    }
    
    if (explanations.isEmpty) {
      return 'Settings are already optimized for $sceneType photography';
    }
    
    return explanations.join('; ');
  }

  // Clean up resources
  void dispose() {
    _client.close();
  }
}