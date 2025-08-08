import 'package:flutter/foundation.dart';

/// AI response from backend analysis
class AIAnalysisResponse {
  final bool success;
  final Map<String, dynamic>? recommendedSettings;
  final List<String> compositionSuggestions;
  final String? reasoning;
  final double confidence;
  final int responseTime;
  final String provider;
  final String model;
  final Map<String, dynamic>? usage;
  final String? cost;

  const AIAnalysisResponse({
    required this.success,
    this.recommendedSettings,
    this.compositionSuggestions = const [],
    this.reasoning,
    required this.confidence,
    required this.responseTime,
    required this.provider,
    required this.model,
    this.usage,
    this.cost,
  });

  factory AIAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? {};
    final recommendedSettings = analysis['recommended_settings'] as Map<String, dynamic>?;
    final alternativeApproaches = analysis['alternative_approaches'] as List<dynamic>? ?? [];
    
    return AIAnalysisResponse(
      success: json['success'] ?? false,
      recommendedSettings: recommendedSettings,
      compositionSuggestions: alternativeApproaches.map((e) => e.toString()).toList(),
      reasoning: analysis['reasoning'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      responseTime: json['responseTime'] ?? 0,
      provider: json['provider'] ?? 'unknown',
      model: json['model'] ?? 'unknown',
      usage: json['usage'] as Map<String, dynamic>?,
      cost: json['cost']?.toString(),
    );
  }
}

/// Service to parse AI responses and convert to camera settings and suggestions
class AIResponseParser {
  static const String _logTag = 'AIResponseParser';

  /// Parse AI backend response and extract camera settings + composition suggestions
  static ParsedAIResponse parseBackendResponse(Map<String, dynamic> responseJson) {
    try {
      final aiResponse = AIAnalysisResponse.fromJson(responseJson);
      
      if (!aiResponse.success) {
        throw Exception('AI analysis failed');
      }

      // Extract camera settings
      final cameraSettings = _extractCameraSettings(aiResponse.recommendedSettings);
      
      // Extract composition suggestions for display
      final displaySuggestions = _extractCompositionSuggestions(aiResponse.compositionSuggestions);
      
      debugPrint('$_logTag: Parsed ${cameraSettings.length} camera settings, ${displaySuggestions.length} composition suggestions');
      
      return ParsedAIResponse(
        cameraSettings: cameraSettings,
        displaySuggestions: displaySuggestions,
        confidence: aiResponse.confidence,
        provider: aiResponse.provider,
        model: aiResponse.model,
        responseTime: aiResponse.responseTime,
      );
      
    } catch (e) {
      debugPrint('$_logTag: Failed to parse AI response: $e');
      rethrow;
    }
  }

  /// Extract camera settings that can be applied directly
  static Map<String, dynamic> _extractCameraSettings(Map<String, dynamic>? recommendedSettings) {
    if (recommendedSettings == null) return {};
    
    final cameraSettings = <String, dynamic>{};
    
    // Map AI response settings to camera control values
    if (recommendedSettings.containsKey('iso')) {
      final iso = recommendedSettings['iso'];
      if (iso is num) {
        cameraSettings['iso'] = iso.toDouble();
      }
    }
    
    if (recommendedSettings.containsKey('aperture')) {
      final aperture = recommendedSettings['aperture'];
      if (aperture is String) {
        // Parse "f/2.8" format
        final match = RegExp(r'f/(\d+\.?\d*)').firstMatch(aperture);
        if (match != null) {
          cameraSettings['aperture'] = double.tryParse(match.group(1) ?? '');
        }
      } else if (aperture is num) {
        cameraSettings['aperture'] = aperture.toDouble();
      }
    }
    
    if (recommendedSettings.containsKey('shutter_speed')) {
      final shutterSpeed = recommendedSettings['shutter_speed'];
      if (shutterSpeed is String) {
        // Parse "1/125" format
        if (shutterSpeed.startsWith('1/')) {
          final denominator = int.tryParse(shutterSpeed.substring(2));
          if (denominator != null) {
            cameraSettings['shutterSpeed'] = 1.0 / denominator;
          }
        }
      } else if (shutterSpeed is num) {
        cameraSettings['shutterSpeed'] = shutterSpeed.toDouble();
      }
    }
    
    if (recommendedSettings.containsKey('white_balance')) {
      final whiteBalance = recommendedSettings['white_balance'];
      if (whiteBalance is String) {
        cameraSettings['whiteBalance'] = whiteBalance;
      }
    }
    
    // Additional settings
    if (recommendedSettings.containsKey('scene')) {
      cameraSettings['sceneMode'] = recommendedSettings['scene'];
    }
    
    if (recommendedSettings.containsKey('lighting')) {
      // Map lighting conditions to camera settings
      final lighting = recommendedSettings['lighting']?.toString().toLowerCase();
      if (lighting?.contains('bright') == true) {
        cameraSettings['exposureCompensation'] = -0.3;
      } else if (lighting?.contains('low') == true || lighting?.contains('dark') == true) {
        cameraSettings['exposureCompensation'] = 0.3;
      }
    }
    
    debugPrint('$_logTag: Extracted camera settings: $cameraSettings');
    return cameraSettings;
  }

  /// Extract composition suggestions for display in AI panel
  static List<CompositionSuggestion> _extractCompositionSuggestions(List<String> suggestions) {
    final displaySuggestions = <CompositionSuggestion>[];
    
    for (final suggestion in suggestions) {
      if (suggestion.isEmpty) continue;
      
      // Categorize and shorten suggestions for display
      final compositionSuggestion = _categorizeCompositionSuggestion(suggestion);
      if (compositionSuggestion != null) {
        displaySuggestions.add(compositionSuggestion);
      }
    }
    
    // Limit to 3 most relevant suggestions for display
    return displaySuggestions.take(3).toList();
  }

  /// Categorize and create display-friendly composition suggestions
  static CompositionSuggestion? _categorizeCompositionSuggestion(String suggestion) {
    final lowerSuggestion = suggestion.toLowerCase();
    
    // Pattern matching for different suggestion types
    if (lowerSuggestion.contains('close') || lowerSuggestion.contains('zoom')) {
      return CompositionSuggestion(
        type: CompositionType.distance,
        title: 'Move Closer',
        description: 'Get closer to your subject',
        icon: 'zoom_in',
      );
    }
    
    if (lowerSuggestion.contains('wide') || lowerSuggestion.contains('landscape') || lowerSuggestion.contains('scene')) {
      return CompositionSuggestion(
        type: CompositionType.framing,
        title: 'Wider View',
        description: 'Include more of the scene',
        icon: 'landscape',
      );
    }
    
    if (lowerSuggestion.contains('rule of thirds') || lowerSuggestion.contains('grid') || lowerSuggestion.contains('position')) {
      return CompositionSuggestion(
        type: CompositionType.grid,
        title: 'Rule of Thirds',
        description: 'Position subject on grid lines',
        icon: 'grid_on',
      );
    }
    
    if (lowerSuggestion.contains('angle') || lowerSuggestion.contains('perspective') || lowerSuggestion.contains('different')) {
      return CompositionSuggestion(
        type: CompositionType.angle,
        title: 'Try Different Angle',
        description: 'Change your shooting angle',
        icon: 'architecture',
      );
    }
    
    if (lowerSuggestion.contains('portrait') || lowerSuggestion.contains('depth') || lowerSuggestion.contains('blur')) {
      return CompositionSuggestion(
        type: CompositionType.depth,
        title: 'Portrait Mode',
        description: 'Use shallow depth of field',
        icon: 'portrait',
      );
    }
    
    if (lowerSuggestion.contains('hdr') || lowerSuggestion.contains('bracket') || lowerSuggestion.contains('exposure')) {
      return CompositionSuggestion(
        type: CompositionType.exposure,
        title: 'HDR Mode',
        description: 'Try HDR for better dynamic range',
        icon: 'hdr_on',
      );
    }
    
    if (lowerSuggestion.contains('light') || lowerSuggestion.contains('time') || lowerSuggestion.contains('golden')) {
      return CompositionSuggestion(
        type: CompositionType.lighting,
        title: 'Better Lighting',
        description: 'Consider timing or position',
        icon: 'wb_sunny',
      );
    }
    
    // Generic suggestion if no specific pattern matches
    if (suggestion.length > 10) {
      return CompositionSuggestion(
        type: CompositionType.general,
        title: 'Photography Tip',
        description: _shortenDescription(suggestion),
        icon: 'auto_awesome',
      );
    }
    
    return null;
  }

  /// Shorten long descriptions for display
  static String _shortenDescription(String description) {
    if (description.length <= 40) return description;
    
    // Find good break point
    final words = description.split(' ');
    final buffer = StringBuffer();
    
    for (final word in words) {
      if ((buffer.length + word.length + 1) > 35) break;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(word);
    }
    
    return '${buffer.toString()}...';
  }
}

/// Parsed AI response ready for application
class ParsedAIResponse {
  final Map<String, dynamic> cameraSettings;
  final List<CompositionSuggestion> displaySuggestions;
  final double confidence;
  final String provider;
  final String model;
  final int responseTime;

  const ParsedAIResponse({
    required this.cameraSettings,
    required this.displaySuggestions,
    required this.confidence,
    required this.provider,
    required this.model,
    required this.responseTime,
  });
}

/// Composition suggestion for display in AI panel
class CompositionSuggestion {
  final CompositionType type;
  final String title;
  final String description;
  final String icon;

  const CompositionSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Types of composition suggestions
enum CompositionType {
  distance,
  framing,
  grid,
  angle,
  depth,
  exposure,
  lighting,
  general,
}