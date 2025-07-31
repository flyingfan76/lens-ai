import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_suggestion.dart';
import '../core/config/api_config.dart';

class AIService {
  static const String _baseUrl = ApiConfig.baseUrl;
  
  Future<AIAnalysisResult> analyzeSuggestions(SceneAnalysis sceneAnalysis, {String? cameraModel}) async {
    // Use mock data for development - replace with actual API call in production
    return getMockSuggestions();
    
    /* Production code:
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai-suggestions/analyze'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sceneAnalysis': sceneAnalysis.toJson(),
          'cameraModel': cameraModel,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AIAnalysisResult.fromJson(data['data']);
      } else {
        throw Exception('Failed to analyze scene: ${response.statusCode}');
      }
    } catch (e) {
      return AIAnalysisResult(
        success: false,
        suggestions: [],
        analysisTimestamp: DateTime.now(),
        confidence: 0.0,
        error: e.toString(),
      );
    }
    */
  }

  Future<bool> applyCameraSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai-suggestions/apply-settings'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'settings': settings,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        throw Exception('Failed to apply settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error applying camera settings: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentCameraSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai-suggestions/camera/settings'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to get camera settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting camera settings: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCameraInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai-suggestions/camera/info'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to get camera info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting camera info: $e');
      return null;
    }
  }

  Future<bool> connectToCamera() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai-suggestions/camera/connect'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['connected'] ?? false;
      } else {
        throw Exception('Failed to connect to camera: ${response.statusCode}');
      }
    } catch (e) {
      print('Error connecting to camera: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> capturePhoto() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai-suggestions/camera/capture'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to capture photo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error capturing photo: $e');
      return null;
    }
  }

  // Simulate suggestions for demo purposes
  Future<AIAnalysisResult> getMockSuggestions() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate API delay
    
    final suggestions = [
      AISuggestion(
        id: 'iso_001',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.iso,
        title: 'Increase ISO',
        message: 'Low light detected. Try ISO 1600-3200',
        icon: 'iso',
        priority: 0.9,
        confidence: 0.85,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'iso': 1600},
        ),
        explanation: 'Higher ISO will brighten the image in low light conditions',
      ),
      AISuggestion(
        id: 'composition_001',
        type: AISuggestionType.composition,
        category: AISuggestionCategory.ruleOfThirds,
        title: 'Rule of thirds',
        message: 'Try placing subject on grid intersection',
        icon: 'grid_on',
        priority: 0.6,
        confidence: 0.7,
        actionable: false,
        visual: SuggestionVisual(
          type: 'overlay',
          overlay: 'rule_of_thirds_highlight',
        ),
        explanation: 'Creates more dynamic and visually interesting composition',
      ),
      AISuggestion(
        id: 'wb_001',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.whiteBalance,
        title: 'Adjust White Balance',
        message: 'Tungsten lighting detected. Try WB + M2',
        icon: 'wb_sunny',
        priority: 0.7,
        confidence: 0.75,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {
            'whiteBalance': {
              'mode': 'tungsten',
              'shift': {
                'magentaGreen': 2,
                'blueAmber': 0,
              },
            },
          },
        ),
        explanation: 'Corrects color cast from artificial lighting',
      ),
    ];

    return AIAnalysisResult(
      success: true,
      suggestions: suggestions,
      analysisTimestamp: DateTime.now(),
      confidence: 0.8,
    );
  }
}