enum AISuggestionType {
  cameraSettings,
  composition,
  technique,
  timing,
  creative,
}

enum AISuggestionCategory {
  // Camera Settings - Basic
  iso,
  aperture,
  shutterSpeed,
  whiteBalance,
  
  // Camera Settings - Advanced
  exposureCompensation,
  focusMode,
  meteringMode,
  flashMode,
  zoomLevel,
  stabilization,
  focusPoint,
  exposurePoint,
  exposureLock,
  focusLock,
  
  // Image Quality Settings
  imageFormat,
  colorSpace,
  noiseReduction,
  sharpness,
  contrast,
  saturation,
  hdr,
  
  // Shooting Modes
  burstMode,
  timerMode,
  aspectRatio,
  sceneMode,
  
  // Composition
  ruleOfThirds,
  horizon,
  framing,
  symmetry,
  leadingLines,

  // Technique
  lighting,
  focus,
  stability,
  timing,

  // Creative
  silhouette,
  bokeh,
  motion,
  perspective,
  
  // Enhanced categories
  colorGrading,
  depthOfField,
  motionBlur,
}

class AISuggestion {
  final String id;
  final AISuggestionType type;
  final AISuggestionCategory category;
  final String title;
  final String message;
  final String? icon;
  final double priority;
  final double confidence;
  final bool actionable;
  final SuggestionAction? action;
  final SuggestionVisual? visual;
  final String? explanation;
  final DateTime timestamp;

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
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AISuggestion.fromJson(Map<String, dynamic> json) {
    return AISuggestion(
      id: json['id'],
      type: AISuggestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AISuggestionType.cameraSettings,
      ),
      category: AISuggestionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AISuggestionCategory.iso,
      ),
      title: json['title'],
      message: json['message'],
      icon: json['icon'],
      priority: (json['priority'] ?? 0.5).toDouble(),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      actionable: json['actionable'] ?? false,
      action: json['action'] != null 
        ? SuggestionAction.fromJson(json['action'])
        : null,
      visual: json['visual'] != null 
        ? SuggestionVisual.fromJson(json['visual'])
        : null,
      explanation: json['explanation'],
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'])
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'category': category.name,
      'title': title,
      'message': message,
      'icon': icon,
      'priority': priority,
      'confidence': confidence,
      'actionable': actionable,
      'action': action?.toJson(),
      'visual': visual?.toJson(),
      'explanation': explanation,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isExpired {
    return DateTime.now().difference(timestamp).inMinutes > 5;
  }

  double get relevanceScore {
    return priority * confidence;
  }

  /// Convert to Map for compatibility
  Map<String, dynamic> toMap() {
    return toJson();
  }
}

class SuggestionAction {
  final String type;
  final Map<String, dynamic> settings;

  SuggestionAction({
    required this.type,
    required this.settings,
  });

  factory SuggestionAction.fromJson(Map<String, dynamic> json) {
    return SuggestionAction(
      type: json['type'],
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'settings': settings,
    };
  }
}

class SuggestionVisual {
  final String type;
  final String overlay;
  final Map<String, dynamic>? parameters;

  SuggestionVisual({
    required this.type,
    required this.overlay,
    this.parameters,
  });

  factory SuggestionVisual.fromJson(Map<String, dynamic> json) {
    return SuggestionVisual(
      type: json['type'],
      overlay: json['overlay'],
      parameters: json['parameters'] != null 
        ? Map<String, dynamic>.from(json['parameters'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'overlay': overlay,
      'parameters': parameters,
    };
  }
}

class AIAnalysisResult {
  final bool success;
  final List<AISuggestion> suggestions;
  final DateTime analysisTimestamp;
  final double confidence;
  final String? error;

  AIAnalysisResult({
    required this.success,
    required this.suggestions,
    required this.analysisTimestamp,
    required this.confidence,
    this.error,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      success: json['success'] ?? false,
      suggestions: (json['suggestions'] as List<dynamic>?)
          ?.map((s) => AISuggestion.fromJson(s))
          .toList() ?? [],
      analysisTimestamp: DateTime.parse(json['analysisTimestamp'] ?? DateTime.now().toIso8601String()),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
      'analysisTimestamp': analysisTimestamp.toIso8601String(),
      'confidence': confidence,
      'error': error,
    };
  }
}

class SceneAnalysis {
  final String sceneType;
  final String lightingCondition;
  final String subjectDistance;
  final bool movementDetected;
  final String? subjectPosition;
  final bool? horizonDetected;
  final String? weather;
  final double? colorTemperature;
  final Map<String, dynamic>? compositionAnalysis;
  
  // Additional properties for local AI analysis
  final double? brightness;
  final double? contrast;
  final List<String>? dominantColors;
  final List<dynamic>? faces;
  final double? motion;
  final double? focusDistance;
  final double? exposureBias;

  SceneAnalysis({
    required this.sceneType,
    required this.lightingCondition,
    required this.subjectDistance,
    required this.movementDetected,
    this.subjectPosition,
    this.horizonDetected,
    this.weather,
    this.colorTemperature,
    this.compositionAnalysis,
    this.brightness,
    this.contrast,
    this.dominantColors,
    this.faces,
    this.motion,
    this.focusDistance,
    this.exposureBias,
  });

  factory SceneAnalysis.fromJson(Map<String, dynamic> json) {
    return SceneAnalysis(
      sceneType: json['scene_type'] ?? 'portrait',
      lightingCondition: json['lighting_condition'] ?? 'normal',
      subjectDistance: json['subject_distance'] ?? 'medium',
      movementDetected: json['movement_detected'] ?? false,
      subjectPosition: json['subject_position'],
      horizonDetected: json['horizon_detected'],
      weather: json['weather'],
      colorTemperature: json['color_temperature']?.toDouble(),
      compositionAnalysis: json['composition_analysis'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scene_type': sceneType,
      'lighting_condition': lightingCondition,
      'subject_distance': subjectDistance,
      'movement_detected': movementDetected,
      'subject_position': subjectPosition,
      'horizon_detected': horizonDetected,
      'weather': weather,
      'color_temperature': colorTemperature,
      'composition_analysis': compositionAnalysis,
    };
  }
}