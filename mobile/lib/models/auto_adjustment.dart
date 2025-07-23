import 'dart:convert';

class AutoAdjustmentResult {
  final SceneAnalysis analysis;
  final CameraSettings originalSettings;
  final CameraSettings optimizedSettings;
  final Map<String, dynamic> adjustmentsMade;
  final double confidence;
  final int processingTime;
  final List<Recommendation> recommendations;
  final List<StylePreset> suggestedPresets;

  AutoAdjustmentResult({
    required this.analysis,
    required this.originalSettings,
    required this.optimizedSettings,
    required this.adjustmentsMade,
    required this.confidence,
    required this.processingTime,
    required this.recommendations,
    required this.suggestedPresets,
  });

  factory AutoAdjustmentResult.fromJson(Map<String, dynamic> json) {
    return AutoAdjustmentResult(
      analysis: SceneAnalysis.fromJson(json['analysis'] ?? {}),
      originalSettings: CameraSettings.fromJson(json['originalSettings'] ?? {}),
      optimizedSettings: CameraSettings.fromJson(json['optimizedSettings'] ?? {}),
      adjustmentsMade: Map<String, dynamic>.from(json['adjustmentsMade'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      processingTime: json['processingTime'] ?? 0,
      recommendations: (json['recommendations'] as List? ?? [])
          .map((r) => Recommendation.fromJson(r))
          .toList(),
      suggestedPresets: (json['suggestedPresets'] as List? ?? [])
          .map((p) => StylePreset.fromJson(p))
          .toList(),
    );
  }
}

class SceneAnalysis {
  final String sceneType;
  final String lightingCondition;
  final bool hasFaces;
  final double confidence;
  final int timestamp;
  final ExposureAnalysis? exposureAnalysis;
  final FocusAnalysis? focusAnalysis;
  final NoiseAnalysis? noiseAnalysis;
  final ColorAnalysis? colorAnalysis;

  SceneAnalysis({
    required this.sceneType,
    required this.lightingCondition,
    required this.hasFaces,
    required this.confidence,
    required this.timestamp,
    this.exposureAnalysis,
    this.focusAnalysis,
    this.noiseAnalysis,
    this.colorAnalysis,
  });

  factory SceneAnalysis.fromJson(Map<String, dynamic> json) {
    return SceneAnalysis(
      sceneType: json['scene_type'] ?? 'general',
      lightingCondition: json['lighting_condition'] ?? 'normal',
      hasFaces: json['has_faces'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] ?? 0,
      exposureAnalysis: json['exposureAnalysis'] != null 
          ? ExposureAnalysis.fromJson(json['exposureAnalysis'])
          : null,
      focusAnalysis: json['focusAnalysis'] != null 
          ? FocusAnalysis.fromJson(json['focusAnalysis'])
          : null,
      noiseAnalysis: json['noiseAnalysis'] != null 
          ? NoiseAnalysis.fromJson(json['noiseAnalysis'])
          : null,
      colorAnalysis: json['colorAnalysis'] != null 
          ? ColorAnalysis.fromJson(json['colorAnalysis'])
          : null,
    );
  }

  String get displaySceneType {
    switch (sceneType) {
      case 'portrait': return 'Portrait';
      case 'landscape': return 'Landscape';
      case 'sports': return 'Sports';
      case 'macro': return 'Macro';
      case 'low_light': return 'Low Light';
      case 'street': return 'Street';
      default: return 'General';
    }
  }

  String get displayLightingCondition {
    switch (lightingCondition) {
      case 'bright': return 'Bright';
      case 'normal': return 'Normal';
      case 'dim': return 'Dim';
      case 'very_dark': return 'Very Dark';
      case 'golden_hour': return 'Golden Hour';
      default: return 'Normal';
    }
  }
}

class ExposureAnalysis {
  final double underexposed;
  final double overexposed;
  final double wellExposed;
  final double averageBrightness;
  final double dynamicRange;
  final Map<String, double> clipping;

  ExposureAnalysis({
    required this.underexposed,
    required this.overexposed,
    required this.wellExposed,
    required this.averageBrightness,
    required this.dynamicRange,
    required this.clipping,
  });

  factory ExposureAnalysis.fromJson(Map<String, dynamic> json) {
    return ExposureAnalysis(
      underexposed: (json['underexposed'] ?? 0.0).toDouble(),
      overexposed: (json['overexposed'] ?? 0.0).toDouble(),
      wellExposed: (json['wellExposed'] ?? 0.0).toDouble(),
      averageBrightness: (json['averageBrightness'] ?? 0.0).toDouble(),
      dynamicRange: (json['dynamicRange'] ?? 0.0).toDouble(),
      clipping: Map<String, double>.from(json['clipping'] ?? {}),
    );
  }

  String get exposureQuality {
    if (wellExposed > 0.8) return 'Excellent';
    if (wellExposed > 0.6) return 'Good';
    if (wellExposed > 0.4) return 'Fair';
    return 'Poor';
  }
}

class FocusAnalysis {
  final double sharpness;
  final List<FocusPoint> focusPoints;
  final String depth;

  FocusAnalysis({
    required this.sharpness,
    required this.focusPoints,
    required this.depth,
  });

  factory FocusAnalysis.fromJson(Map<String, dynamic> json) {
    return FocusAnalysis(
      sharpness: (json['sharpness'] ?? 0.0).toDouble(),
      focusPoints: (json['focusPoints'] as List? ?? [])
          .map((fp) => FocusPoint.fromJson(fp))
          .toList(),
      depth: json['depth'] ?? 'medium',
    );
  }

  String get focusQuality {
    if (sharpness > 0.8) return 'Sharp';
    if (sharpness > 0.6) return 'Good';
    if (sharpness > 0.4) return 'Soft';
    return 'Out of Focus';
  }
}

class FocusPoint {
  final double x;
  final double y;
  final double confidence;

  FocusPoint({
    required this.x,
    required this.y,
    required this.confidence,
  });

  factory FocusPoint.fromJson(Map<String, dynamic> json) {
    return FocusPoint(
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

class NoiseAnalysis {
  final double level;
  final String type;
  final String distribution;

  NoiseAnalysis({
    required this.level,
    required this.type,
    required this.distribution,
  });

  factory NoiseAnalysis.fromJson(Map<String, dynamic> json) {
    return NoiseAnalysis(
      level: (json['level'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'gaussian',
      distribution: json['distribution'] ?? 'uniform',
    );
  }

  String get noiseLevel {
    if (level < 0.1) return 'Low';
    if (level < 0.2) return 'Medium';
    if (level < 0.3) return 'High';
    return 'Very High';
  }
}

class ColorAnalysis {
  final Map<String, double> averages;
  final Map<String, dynamic> colorCast;
  final double saturation;
  final int temperature;

  ColorAnalysis({
    required this.averages,
    required this.colorCast,
    required this.saturation,
    required this.temperature,
  });

  factory ColorAnalysis.fromJson(Map<String, dynamic> json) {
    return ColorAnalysis(
      averages: Map<String, double>.from(json['averages'] ?? {}),
      colorCast: Map<String, dynamic>.from(json['colorCast'] ?? {}),
      saturation: (json['saturation'] ?? 0.0).toDouble(),
      temperature: json['temperature'] ?? 5500,
    );
  }
}

class CameraSettings {
  final int iso;
  final String aperture;
  final String shutterSpeed;
  final String whiteBalance;
  final String? exposureCompensation;
  final String? focusMode;
  final String? meteringMode;

  CameraSettings({
    required this.iso,
    required this.aperture,
    required this.shutterSpeed,
    required this.whiteBalance,
    this.exposureCompensation,
    this.focusMode,
    this.meteringMode,
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      iso: json['iso'] is String ? int.parse(json['iso']) : (json['iso'] ?? 400),
      aperture: json['aperture'] ?? 'f/4.0',
      shutterSpeed: json['shutter_speed'] ?? json['shutterSpeed'] ?? '1/125',
      whiteBalance: json['white_balance'] ?? json['whiteBalance'] ?? 'auto',
      exposureCompensation: json['exposure_compensation'] ?? json['exposureCompensation'],
      focusMode: json['focus_mode'] ?? json['focusMode'],
      meteringMode: json['metering_mode'] ?? json['meteringMode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iso': iso,
      'aperture': aperture,
      'shutter_speed': shutterSpeed,
      'white_balance': whiteBalance,
      if (exposureCompensation != null) 'exposure_compensation': exposureCompensation,
      if (focusMode != null) 'focus_mode': focusMode,
      if (meteringMode != null) 'metering_mode': meteringMode,
    };
  }

  String get displayISO => 'ISO $iso';
  String get displayAperture => aperture;
  String get displayShutterSpeed => shutterSpeed;
  String get displayWhiteBalance => whiteBalance;
}

class Recommendation {
  final String type;
  final String priority;
  final String message;

  Recommendation({
    required this.type,
    required this.priority,
    required this.message,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: json['type'] ?? '',
      priority: json['priority'] ?? 'low',
      message: json['message'] ?? '',
    );
  }

  bool get isHighPriority => priority == 'high';
  bool get isMediumPriority => priority == 'medium';
}

class UserPreferences {
  final bool preferLowISO;
  final int maxPreferredISO;
  final bool preferWideAperture;
  final bool autoFocus;
  final String priorityMode;
  final bool preserveAperture;
  final bool allowHighISO;
  final String? minimumShutterSpeed;
  final int maxLowLightISO;
  final double minSportsShutter;
  final String portraitMode;

  UserPreferences({
    this.preferLowISO = true,
    this.maxPreferredISO = 800,
    this.preferWideAperture = false,
    this.autoFocus = true,
    this.priorityMode = 'balanced',
    this.preserveAperture = false,
    this.allowHighISO = false,
    this.minimumShutterSpeed,
    this.maxLowLightISO = 1600,
    this.minSportsShutter = 1/500,
    this.portraitMode = 'natural',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferLowISO: json['preferLowISO'] ?? true,
      maxPreferredISO: json['maxPreferredISO'] ?? 800,
      preferWideAperture: json['preferWideAperture'] ?? false,
      autoFocus: json['autoFocus'] ?? true,
      priorityMode: json['priorityMode'] ?? 'balanced',
      preserveAperture: json['preserveAperture'] ?? false,
      allowHighISO: json['allowHighISO'] ?? false,
      minimumShutterSpeed: json['minimumShutterSpeed'],
      maxLowLightISO: json['maxLowLightISO'] ?? 1600,
      minSportsShutter: (json['minSportsShutter'] ?? 1/500).toDouble(),
      portraitMode: json['portraitMode'] ?? 'natural',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferLowISO': preferLowISO,
      'maxPreferredISO': maxPreferredISO,
      'preferWideAperture': preferWideAperture,
      'autoFocus': autoFocus,
      'priorityMode': priorityMode,
      'preserveAperture': preserveAperture,
      'allowHighISO': allowHighISO,
      if (minimumShutterSpeed != null) 'minimumShutterSpeed': minimumShutterSpeed,
      'maxLowLightISO': maxLowLightISO,
      'minSportsShutter': minSportsShutter,
      'portraitMode': portraitMode,
    };
  }

  UserPreferences copyWith({
    bool? preferLowISO,
    int? maxPreferredISO,
    bool? preferWideAperture,
    bool? autoFocus,
    String? priorityMode,
    bool? preserveAperture,
    bool? allowHighISO,
    String? minimumShutterSpeed,
    int? maxLowLightISO,
    double? minSportsShutter,
    String? portraitMode,
  }) {
    return UserPreferences(
      preferLowISO: preferLowISO ?? this.preferLowISO,
      maxPreferredISO: maxPreferredISO ?? this.maxPreferredISO,
      preferWideAperture: preferWideAperture ?? this.preferWideAperture,
      autoFocus: autoFocus ?? this.autoFocus,
      priorityMode: priorityMode ?? this.priorityMode,
      preserveAperture: preserveAperture ?? this.preserveAperture,
      allowHighISO: allowHighISO ?? this.allowHighISO,
      minimumShutterSpeed: minimumShutterSpeed ?? this.minimumShutterSpeed,
      maxLowLightISO: maxLowLightISO ?? this.maxLowLightISO,
      minSportsShutter: minSportsShutter ?? this.minSportsShutter,
      portraitMode: portraitMode ?? this.portraitMode,
    );
  }
}

class LearningInsight {
  final String type;
  final String message;
  final double confidence;

  LearningInsight({
    required this.type,
    required this.message,
    required this.confidence,
  });

  factory LearningInsight.fromJson(Map<String, dynamic> json) {
    return LearningInsight(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  String get displayType {
    switch (type) {
      case 'acceptance_rate': return 'Learning Progress';
      case 'scene_preference': return 'Shooting Style';
      case 'iso_preference': return 'ISO Preference';
      case 'aperture_preference': return 'Aperture Style';
      default: return 'Insight';
    }
  }
}

// Import StylePreset from the existing style preset model
class StylePreset {
  final String id;
  final String name;
  final String description;
  
  StylePreset({
    required this.id,
    required this.name,
    required this.description,
  });
  
  factory StylePreset.fromJson(Map<String, dynamic> json) {
    return StylePreset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}