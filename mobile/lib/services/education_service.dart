import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/education.dart';

class EducationService {
  static const String baseUrl = 'http://localhost:3000/api/education';
  final http.Client _client;
  String? _authToken;

  EducationService({http.Client? client}) : _client = client ?? http.Client();

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Glossary Methods
  Future<GlossaryResponse> getGlossary({
    String? category,
    String? difficulty,
    String? search,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/glossary').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GlossaryResponse.fromJson(data);
      } else {
        throw EducationException('Failed to load glossary: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading glossary: $e');
    }
  }

  Future<GlossaryTerm> getGlossaryTerm(String term) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/glossary/$term'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GlossaryTerm.fromJson(data);
      } else if (response.statusCode == 404) {
        throw EducationException('Term not found');
      } else {
        throw EducationException('Failed to load term: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading term: $e');
    }
  }

  // Tutorial Methods
  Future<TutorialResponse> getTutorials({
    String? category,
    String? difficulty,
    bool? featured,
    int limit = 10,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (featured != null) queryParams['featured'] = featured.toString();

      final uri = Uri.parse('$baseUrl/tutorials').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TutorialResponse.fromJson(data);
      } else {
        throw EducationException('Failed to load tutorials: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading tutorials: $e');
    }
  }

  Future<Tutorial> getTutorial(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tutorials/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Tutorial.fromJson(data);
      } else if (response.statusCode == 404) {
        throw EducationException('Tutorial not found');
      } else {
        throw EducationException('Failed to load tutorial: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading tutorial: $e');
    }
  }

  Future<void> completeTutorial(
    String tutorialId, {
    int? completionTime,
    int? rating,
    String? feedback,
    int? score,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (completionTime != null) body['completionTime'] = completionTime;
      if (rating != null) body['rating'] = rating;
      if (feedback != null) body['feedback'] = feedback;
      if (score != null) body['score'] = score;

      final response = await _client.post(
        Uri.parse('$baseUrl/tutorials/$tutorialId/complete'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        throw EducationException('Failed to complete tutorial: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error completing tutorial: $e');
    }
  }

  // Comparison Methods
  Future<ComparisonResponse> getComparisons({
    String? category,
    String? difficulty,
    int limit = 10,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;

      final uri = Uri.parse('$baseUrl/comparisons').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ComparisonResponse.fromJson(data);
      } else {
        throw EducationException('Failed to load comparisons: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading comparisons: $e');
    }
  }

  Future<Comparison> getComparison(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/comparisons/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Comparison.fromJson(data);
      } else if (response.statusCode == 404) {
        throw EducationException('Comparison not found');
      } else {
        throw EducationException('Failed to load comparison: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading comparison: $e');
    }
  }

  // User Progress Methods
  Future<UserProgress> getUserProgress() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/progress'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProgress.fromJson(data);
      } else {
        throw EducationException('Failed to load user progress: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error loading user progress: $e');
    }
  }

  Future<UserProgress> updateLearningPreferences(LearningPreferences preferences) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/progress/preferences'),
        headers: _headers,
        body: json.encode(preferences.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProgress.fromJson(data);
      } else {
        throw EducationException('Failed to update preferences: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error updating preferences: $e');
    }
  }

  // Contextual Help Methods
  Future<ContextualHelpResponse> getContextualHelp({
    String? sceneType,
    CameraSettings? cameraSettings,
    String? userLevel,
    List<String>? commonIssues,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (sceneType != null) body['sceneType'] = sceneType;
      if (cameraSettings != null) body['cameraSettings'] = cameraSettings.toJson();
      if (userLevel != null) body['userLevel'] = userLevel;
      if (commonIssues != null) body['commonIssues'] = commonIssues;

      final response = await _client.post(
        Uri.parse('$baseUrl/contextual-help'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ContextualHelpResponse.fromJson(data);
      } else {
        throw EducationException('Failed to get contextual help: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error getting contextual help: $e');
    }
  }

  // Learning Recommendations
  Future<LearningRecommendations> getLearningRecommendations() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/recommendations'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LearningRecommendations.fromJson(data);
      } else {
        throw EducationException('Failed to get recommendations: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error getting recommendations: $e');
    }
  }

  // Search Methods
  Future<Map<String, dynamic>> searchEducationContent(
    String query, {
    String? type,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'query': query,
        'limit': limit.toString(),
      };
      
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('$baseUrl/search').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw EducationException('Failed to search: ${response.statusCode}');
      }
    } on SocketException {
      throw EducationException('No internet connection');
    } catch (e) {
      throw EducationException('Error searching: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class EducationException implements Exception {
  final String message;
  
  EducationException(this.message);
  
  @override
  String toString() => 'EducationException: $message';
}