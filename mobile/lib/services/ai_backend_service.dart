import 'package:flutter/foundation.dart';
// TODO: Add http dependency to pubspec.yaml when network features are enabled
// import 'package:http/http.dart' as http;
import 'ai_response_parser.dart';

/// Service to communicate with AI backend and handle camera settings application
class AIBackendService {
  static const String _logTag = 'AIBackendService';
  
  // Backend configuration would be configurable when network features are enabled
  
  /// Test connection to AI provider
  /// TODO: Enable when http dependency is added
  static Future<bool> testAIConnection({
    required String provider,
    required String endpoint,
    required String protocol,
    required String model,
    String? apiKey,
  }) async {
    // TODO: Implement when network features are enabled
    debugPrint('$_logTag: AI connection testing not available (network disabled)');
    return false;
    /*
    try {
      debugPrint('$_logTag: Testing AI connection to $provider');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/test-connection'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'endpoint': endpoint,
          'protocol': protocol,
          'model': model,
          'apiKey': apiKey,
        }),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final success = result['success'] ?? false;
        debugPrint('$_logTag: Connection test result: $success');
        return success;
      } else {
        debugPrint('$_logTag: Connection test failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('$_logTag: Connection test error: $e');
      return false;
    }
    */
  }
  
  /// Analyze image with AI backend and get camera settings + composition suggestions
  /// TODO: Enable when http dependency is added
  static Future<ParsedAIResponse> analyzeImage({
    required Uint8List imageBytes,
    required AIProviderConfig config,
    required PhotoContext context,
    String? customPrompt,
  }) async {
    // TODO: Implement when network features are enabled
    debugPrint('$_logTag: AI image analysis not available (network disabled)');
    
    // Return mock response for now
    return _getMockAnalysisResponse(config, context);
    
    /*
    try {
      debugPrint('$_logTag: Analyzing image with ${config.provider}');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/ai/analyze-image'),
      );
      
      // Add image
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'camera_image.jpg',
        ),
      );
      
      // Add configuration
      request.fields['config'] = jsonEncode(config.toJson());
      
      // Add prompt with context substitution
      final prompt = customPrompt ?? _getDefaultPrompt();
      request.fields['prompt'] = _substitutePromptContext(prompt, context);
      
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        return AIResponseParser.parseBackendResponse(responseJson);
      } else {
        throw Exception('AI analysis failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('$_logTag: Image analysis error: $e');
      rethrow;
    }
    */
  }
  
  /// Mock analysis response for testing without network
  static ParsedAIResponse _getMockAnalysisResponse(
    AIProviderConfig config,
    PhotoContext context,
  ) {
    // Mock camera settings based on context
    final settings = <String, dynamic>{
      'iso': 800,
      'aperture': 2.8,
      'shutterSpeed': 0.008, // 1/125
      'whiteBalance': 'daylight',
    };
    
    // Mock composition suggestions
    final suggestions = [
      CompositionSuggestion(
        type: CompositionType.distance,
        title: 'Move Closer',
        description: 'Get closer to your subject',
        icon: 'zoom_in',
      ),
      CompositionSuggestion(
        type: CompositionType.grid,
        title: 'Rule of Thirds',
        description: 'Position subject on grid lines',
        icon: 'grid_on',
      ),
    ];
    
    return ParsedAIResponse(
      cameraSettings: settings,
      displaySuggestions: suggestions,
      confidence: 0.85,
      provider: config.provider,
      model: config.model,
      responseTime: 1000,
    );
  }
  
}

/// AI provider configuration
class AIProviderConfig {
  final String provider;
  final String endpoint;
  final String protocol;
  final String model;
  final String? apiKey;
  final Map<String, dynamic> context;

  const AIProviderConfig({
    required this.provider,
    required this.endpoint,
    required this.protocol,
    required this.model,
    this.apiKey,
    this.context = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'endpoint': endpoint,
      'protocol': protocol,
      'model': model,
      'apiKey': apiKey,
      'context': context,
    };
  }
}

/// Photo context for AI analysis
class PhotoContext {
  final String cameraModel;
  final String? currentISO;
  final String? currentAperture;
  final String? currentShutterSpeed;
  final String? currentWhiteBalance;
  final String? sceneType;
  final String? userRequest;
  final String? lightingConditions;

  const PhotoContext({
    required this.cameraModel,
    this.currentISO,
    this.currentAperture,
    this.currentShutterSpeed,
    this.currentWhiteBalance,
    this.sceneType,
    this.userRequest,
    this.lightingConditions,
  });
}

/// Camera settings application service
class CameraSettingsApplicator {
  static const String _logTag = 'CameraSettingsApplicator';
  
  /// Apply AI-recommended settings to camera
  static Future<bool> applyCameraSettings(
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onApplySettings,
  ) async {
    try {
      if (settings.isEmpty) {
        debugPrint('$_logTag: No settings to apply');
        return false;
      }
      
      debugPrint('$_logTag: Applying camera settings: $settings');
      
      // Filter out invalid or non-applicable settings
      final validSettings = <String, dynamic>{};
      
      // Validate and convert settings
      if (settings.containsKey('iso')) {
        final iso = settings['iso'];
        if (iso is num && iso > 0 && iso <= 6400) {
          validSettings['iso'] = iso.toDouble();
        }
      }
      
      if (settings.containsKey('aperture')) {
        final aperture = settings['aperture'];
        if (aperture is num && aperture >= 1.0 && aperture <= 32.0) {
          validSettings['aperture'] = aperture.toDouble();
        }
      }
      
      if (settings.containsKey('shutterSpeed')) {
        final shutterSpeed = settings['shutterSpeed'];
        if (shutterSpeed is num && shutterSpeed > 0) {
          validSettings['shutterSpeed'] = shutterSpeed.toDouble();
        }
      }
      
      if (settings.containsKey('whiteBalance')) {
        final whiteBalance = settings['whiteBalance'];
        if (whiteBalance is String && _isValidWhiteBalance(whiteBalance)) {
          validSettings['whiteBalance'] = whiteBalance;
        }
      }
      
      if (settings.containsKey('exposureCompensation')) {
        final exposure = settings['exposureCompensation'];
        if (exposure is num && exposure >= -2.0 && exposure <= 2.0) {
          validSettings['exposureCompensation'] = exposure.toDouble();
        }
      }
      
      if (settings.containsKey('sceneMode')) {
        final sceneMode = settings['sceneMode'];
        if (sceneMode is String && _isValidSceneMode(sceneMode)) {
          validSettings['sceneMode'] = sceneMode;
        }
      }
      
      if (validSettings.isNotEmpty) {
        debugPrint('$_logTag: Applying ${validSettings.length} valid settings');
        onApplySettings(validSettings);
        return true;
      } else {
        debugPrint('$_logTag: No valid settings found to apply');
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag: Failed to apply camera settings: $e');
      return false;
    }
  }
  
  /// Check if white balance value is valid
  static bool _isValidWhiteBalance(String whiteBalance) {
    const validValues = [
      'auto', 'daylight', 'cloudy', 'tungsten', 'fluorescent', 'flash'
    ];
    return validValues.contains(whiteBalance.toLowerCase());
  }
  
  /// Check if scene mode is valid
  static bool _isValidSceneMode(String sceneMode) {
    const validValues = [
      'auto', 'portrait', 'landscape', 'macro', 'sport', 'night'
    ];
    return validValues.contains(sceneMode.toLowerCase());
  }
}