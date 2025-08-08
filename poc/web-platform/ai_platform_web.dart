import 'dart:typed_data';

// Note: In POC context, we need to define our own models or import from correct paths
// This file needs to be updated to work with actual model definitions

/// Simplified AI suggestion for POC
class AISuggestion {
  final String id;
  final String type;
  final String category;
  final String title;
  final String message;
  final String? icon;
  final double priority;
  final double confidence;
  final bool actionable;
  final Map<String, dynamic>? action;
  final Map<String, dynamic>? visual;
  final String? explanation;

  AISuggestion({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    this.icon,
    required this.priority,
    required this.confidence,
    required this.actionable,
    this.action,
    this.visual,
    this.explanation,
  });
}

/// Simplified scene analysis for POC
class SceneAnalysis {
  final String sceneType;
  final String lightingCondition;
  final String subjectDistance;
  final bool movementDetected;
  final double? brightness;
  final double? contrast;
  final double? colorTemperature;
  final List<String>? dominantColors;

  SceneAnalysis({
    required this.sceneType,
    required this.lightingCondition,
    required this.subjectDistance,
    required this.movementDetected,
    this.brightness,
    this.contrast,
    this.colorTemperature,
    this.dominantColors,
  });
}

/// Simplified suggestion action for POC
class SuggestionAction {
  final String type;
  final Map<String, dynamic> settings;

  SuggestionAction({
    required this.type,
    required this.settings,
  });
}

/// Simplified suggestion visual for POC
class SuggestionVisual {
  final String type;
  final String overlay;

  SuggestionVisual({
    required this.type,
    required this.overlay,
  });
}

/// Platform interface for POC
abstract class LocalAIPlatform {
  Future<void> initializeModel();
  Future<List<AISuggestion>> runAdvancedAnalysis(SceneAnalysis sceneAnalysis, Uint8List imageBytes);
  void dispose();
}

/// Web platform implementation for local AI processing
class WebLocalAIPlatform implements LocalAIPlatform {
  bool _isInitialized = false;
  
  @override
  Future<void> initializeModel() async {
    try {
      // Web platform uses JavaScript-based ML or simplified heuristics
      // No TensorFlow Lite support due to FFI limitations
      await Future.delayed(const Duration(milliseconds: 100));
      _isInitialized = true;
      print('WebLocalAIPlatform: Web-based AI model initialized');
    } catch (e) {
      print('WebLocalAIPlatform: Failed to initialize: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<AISuggestion>> runAdvancedAnalysis(SceneAnalysis sceneAnalysis, Uint8List imageBytes) async {
    if (!_isInitialized) {
      return [];
    }
    
    try {
      // Web-specific analysis using browser capabilities
      final suggestions = <AISuggestion>[];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Web camera limitations - focus on composition and basic settings
      
      // Web camera quality optimization
      suggestions.add(AISuggestion(
        id: 'web_quality_$timestamp',
        type: 'cameraSettings',
        category: 'imageFormat',
        title: 'Optimize for Web Camera',
        message: 'Adjust settings for webcam limitations',
        icon: 'videocam',
        priority: 0.7,
        confidence: 0.8,
        actionable: true,
        action: {'type': 'apply_settings', 'settings': {'resolution': 'high', 'compression': 'low'}},
        explanation: 'Web cameras have limited controls - focus on getting the highest quality possible',
      ));
      
      // Lighting compensation for web cameras
      if ((sceneAnalysis.brightness ?? 0.5) < 0.4) {
        suggestions.add(AISuggestion(
          id: 'web_lighting_$timestamp',
          type: 'technique',
          category: 'lighting',
          title: 'Improve Lighting',
          message: 'Web cameras need good lighting',
          icon: 'wb_incandescent',
          priority: 0.9,
          confidence: 0.85,
          actionable: false,
          explanation: 'Move closer to a window or add artificial lighting - web cameras perform poorly in low light',
        ));
      }
      
      // Composition emphasis for web platform
      suggestions.add(AISuggestion(
        id: 'web_composition_$timestamp',
        type: 'composition',
        category: 'ruleOfThirds',
        title: 'Focus on Composition',
        message: 'Web cameras have limited settings - make composition count',
        icon: 'grid_on',
        priority: 0.8,
        confidence: 0.9,
        actionable: false,
        visual: {'type': 'overlay', 'overlay': 'rule_of_thirds_highlight'},
        explanation: 'Since web cameras have limited manual controls, focus on composition and framing',
      ));
      
      // Browser-specific suggestions (simplified, no kIsWeb check in POC)
      suggestions.add(AISuggestion(
        id: 'web_browser_$timestamp',
        type: 'technique',
        category: 'imageFormat',
        title: 'Browser Camera Tips',
        message: 'Maximize browser camera performance',
        icon: 'web',
        priority: 0.6,
        confidence: 0.7,
        actionable: false,
        explanation: 'Close other browser tabs, ensure good lighting, and position yourself well in frame',
      ));
      
      // Color temperature adjustment for web
      final colorTemp = sceneAnalysis.colorTemperature ?? 5500;
      if (colorTemp < 4000 || colorTemp > 7000) {
        suggestions.add(AISuggestion(
          id: 'web_color_$timestamp',
          type: 'technique',
          category: 'whiteBalance',
          title: 'Adjust Room Lighting',
          message: 'Web cameras struggle with mixed lighting',
          icon: 'wb_sunny',
          priority: 0.7,
          confidence: 0.75,
          actionable: false,
          explanation: 'Try to use consistent lighting - avoid mixing daylight and artificial light',
        ));
      }
      
      return suggestions;
    } catch (e) {
      print('WebLocalAIPlatform: Advanced analysis failed: $e');
      return [];
    }
  }
  
  @override
  void dispose() {
    _isInitialized = false;
    print('WebLocalAIPlatform: Disposed');
  }
}

LocalAIPlatform createLocalAIPlatform() => WebLocalAIPlatform();