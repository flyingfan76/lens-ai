import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/style_preset.dart';

class StylePresetService {
  static const String baseUrl = 'http://localhost:3000/api/presets';
  final http.Client _client;

  StylePresetService({http.Client? client}) : _client = client ?? http.Client();

  // Get all presets with optional filtering
  Future<List<StylePreset>> getAllPresets({
    String? category,
    String? type,
    String? sceneType,
    String? lightingCondition,
    String? difficulty,
    bool? featured,
    String sortBy = 'popularity',
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'sort_by': sortBy,
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (type != null) queryParams['type'] = type;
      if (sceneType != null) queryParams['scene_type'] = sceneType;
      if (lightingCondition != null) queryParams['lighting_condition'] = lightingCondition;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (featured != null) queryParams['featured'] = featured.toString();

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> presetList = data['data'] ?? [];
        return presetList.map((preset) => StylePreset.fromJson(preset)).toList();
      } else {
        throw Exception('Failed to load presets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error loading presets: $e');
    }
  }

  // Get featured presets
  Future<List<StylePreset>> getFeaturedPresets({int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/featured').replace(
        queryParameters: {'limit': limit.toString()},
      );
      
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> presetList = data['data'] ?? [];
        return presetList.map((preset) => StylePreset.fromJson(preset)).toList();
      } else {
        throw Exception('Failed to load featured presets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error loading featured presets: $e');
    }
  }

  // Get preset by ID
  Future<StylePreset> getPresetById(String presetId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/$presetId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StylePreset.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        throw Exception('Preset not found');
      } else {
        throw Exception('Failed to load preset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error loading preset: $e');
    }
  }

  // Get recommended presets based on scene analysis
  Future<List<StylePreset>> getRecommendedPresets({
    required Map<String, dynamic> analysis,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'analysis': analysis,
          'userPreferences': userPreferences ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> presetList = data['data'] ?? [];
        return presetList.map((preset) => StylePreset.fromJson(preset)).toList();
      } else {
        throw Exception('Failed to get recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting recommendations: $e');
    }
  }

  // Search presets
  Future<List<StylePreset>> searchPresets(
    String searchTerm, {
    String? category,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;

      final uri = Uri.parse('$baseUrl/search/$searchTerm').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> presetList = data['data'] ?? [];
        return presetList.map((preset) => StylePreset.fromJson(preset)).toList();
      } else {
        throw Exception('Failed to search presets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error searching presets: $e');
    }
  }

  // Create new user preset
  Future<StylePreset> createUserPreset({
    required String name,
    required String description,
    required String category,
    required CameraSettings settings,
    String? thumbnail,
    List<String> tags = const [],
    List<String> sceneTypes = const [],
    List<String> lightingConditions = const [],
    File? thumbnailFile,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['settings'] = json.encode(settings.toJson());
      request.fields['tags'] = json.encode(tags);
      request.fields['sceneTypes'] = json.encode(sceneTypes);
      request.fields['lightingConditions'] = json.encode(lightingConditions);

      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('thumbnail', thumbnailFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return StylePreset.fromJson(data['data']);
      } else {
        throw Exception('Failed to create preset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error creating preset: $e');
    }
  }

  // Update preset
  Future<StylePreset> updatePreset(
    String presetId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/$presetId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StylePreset.fromJson(data['data']);
      } else {
        throw Exception('Failed to update preset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error updating preset: $e');
    }
  }

  // Delete preset
  Future<void> deletePreset(String presetId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/$presetId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete preset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error deleting preset: $e');
    }
  }

  // Record preset usage
  Future<void> recordPresetUsage(String presetId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/$presetId/use'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to record usage: ${response.statusCode}');
      }
    } catch (e) {
      // Don't throw error for usage tracking failures
      print('Warning: Failed to record preset usage: $e');
    }
  }

  // Rate preset
  Future<void> ratePreset(String presetId, int rating) async {
    try {
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Rating must be between 1 and 5');
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/$presetId/rate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'rating': rating}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rate preset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error rating preset: $e');
    }
  }

  // Get preset statistics
  Future<Map<String, dynamic>> getPresetStatistics() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/stats/overview'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to get statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error getting statistics: $e');
    }
  }

  // Initialize built-in presets (admin function)
  Future<void> initializeBuiltInPresets() async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/initialize'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to initialize presets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error initializing presets: $e');
    }
  }

  // Get presets by category
  Future<List<StylePreset>> getPresetsByCategory(String category) async {
    return getAllPresets(category: category);
  }

  // Get presets for scene type
  Future<List<StylePreset>> getPresetsForScene(String sceneType) async {
    return getAllPresets(sceneType: sceneType);
  }

  // Get presets for lighting condition
  Future<List<StylePreset>> getPresetsForLighting(String lightingCondition) async {
    return getAllPresets(lightingCondition: lightingCondition);
  }

  // Clean up resources
  void dispose() {
    _client.close();
  }
}