class StylePreset {
  final String id;
  final String name;
  final String description;
  final String category;
  final String type;
  final CameraSettings settings;
  final String thumbnail;
  final List<String> tags;
  final List<String> sceneTypes;
  final List<String> lightingConditions;
  final PresetMetadata metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StylePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.type,
    required this.settings,
    this.thumbnail = '',
    this.tags = const [],
    this.sceneTypes = const [],
    this.lightingConditions = const [],
    required this.metadata,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StylePreset.fromJson(Map<String, dynamic> json) {
    return StylePreset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'portrait',
      type: json['type'] ?? 'built_in',
      settings: CameraSettings.fromJson(json['settings'] ?? {}),
      thumbnail: json['thumbnail'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      sceneTypes: List<String>.from(json['sceneTypes'] ?? []),
      lightingConditions: List<String>.from(json['lightingConditions'] ?? []),
      metadata: PresetMetadata.fromJson(json['metadata'] ?? {}),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'type': type,
      'settings': settings.toJson(),
      'thumbnail': thumbnail,
      'tags': tags,
      'sceneTypes': sceneTypes,
      'lightingConditions': lightingConditions,
      'metadata': metadata.toJson(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  StylePreset copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? type,
    CameraSettings? settings,
    String? thumbnail,
    List<String>? tags,
    List<String>? sceneTypes,
    List<String>? lightingConditions,
    PresetMetadata? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StylePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      settings: settings ?? this.settings,
      thumbnail: thumbnail ?? this.thumbnail,
      tags: tags ?? this.tags,
      sceneTypes: sceneTypes ?? this.sceneTypes,
      lightingConditions: lightingConditions ?? this.lightingConditions,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'StylePreset(id: $id, name: $name, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StylePreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CameraSettings {
  final dynamic iso;
  final String aperture;
  final String shutterSpeed;
  final String whiteBalance;
  final String exposureCompensation;
  final String focusMode;
  final String meteringMode;
  final String colorProfile;

  CameraSettings({
    required this.iso,
    required this.aperture,
    required this.shutterSpeed,
    this.whiteBalance = 'auto',
    this.exposureCompensation = '0.0',
    this.focusMode = 'single',
    this.meteringMode = 'matrix',
    this.colorProfile = 'standard',
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      iso: json['iso'] ?? 400,
      aperture: json['aperture'] ?? 'f/4.0',
      shutterSpeed: json['shutterSpeed'] ?? '1/125',
      whiteBalance: json['whiteBalance'] ?? 'auto',
      exposureCompensation: json['exposureCompensation'] ?? '0.0',
      focusMode: json['focusMode'] ?? 'single',
      meteringMode: json['meteringMode'] ?? 'matrix',
      colorProfile: json['colorProfile'] ?? 'standard',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iso': iso,
      'aperture': aperture,
      'shutterSpeed': shutterSpeed,
      'whiteBalance': whiteBalance,
      'exposureCompensation': exposureCompensation,
      'focusMode': focusMode,
      'meteringMode': meteringMode,
      'colorProfile': colorProfile,
    };
  }

  CameraSettings copyWith({
    dynamic iso,
    String? aperture,
    String? shutterSpeed,
    String? whiteBalance,
    String? exposureCompensation,
    String? focusMode,
    String? meteringMode,
    String? colorProfile,
  }) {
    return CameraSettings(
      iso: iso ?? this.iso,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      whiteBalance: whiteBalance ?? this.whiteBalance,
      exposureCompensation: exposureCompensation ?? this.exposureCompensation,
      focusMode: focusMode ?? this.focusMode,
      meteringMode: meteringMode ?? this.meteringMode,
      colorProfile: colorProfile ?? this.colorProfile,
    );
  }

  String get displayISO {
    return 'ISO $iso';
  }

  String get displayAperture {
    return aperture;
  }

  String get displayShutterSpeed {
    return shutterSpeed;
  }

  @override
  String toString() {
    return 'CameraSettings(iso: $iso, aperture: $aperture, shutterSpeed: $shutterSpeed)';
  }
}

class PresetMetadata {
  final String? createdBy;
  final int usageCount;
  final PresetRating rating;
  final bool featured;
  final String difficulty;

  PresetMetadata({
    this.createdBy,
    this.usageCount = 0,
    required this.rating,
    this.featured = false,
    this.difficulty = 'beginner',
  });

  factory PresetMetadata.fromJson(Map<String, dynamic> json) {
    return PresetMetadata(
      createdBy: json['createdBy'],
      usageCount: json['usageCount'] ?? 0,
      rating: PresetRating.fromJson(json['rating'] ?? {}),
      featured: json['featured'] ?? false,
      difficulty: json['difficulty'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdBy': createdBy,
      'usageCount': usageCount,
      'rating': rating.toJson(),
      'featured': featured,
      'difficulty': difficulty,
    };
  }

  PresetMetadata copyWith({
    String? createdBy,
    int? usageCount,
    PresetRating? rating,
    bool? featured,
    String? difficulty,
  }) {
    return PresetMetadata(
      createdBy: createdBy ?? this.createdBy,
      usageCount: usageCount ?? this.usageCount,
      rating: rating ?? this.rating,
      featured: featured ?? this.featured,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

class PresetRating {
  final double average;
  final int count;

  PresetRating({
    this.average = 0.0,
    this.count = 0,
  });

  factory PresetRating.fromJson(Map<String, dynamic> json) {
    return PresetRating(
      average: (json['average'] ?? 0.0).toDouble(),
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average': average,
      'count': count,
    };
  }

  PresetRating copyWith({
    double? average,
    int? count,
  }) {
    return PresetRating(
      average: average ?? this.average,
      count: count ?? this.count,
    );
  }

  bool get hasRatings => count > 0;

  String get displayRating {
    if (!hasRatings) return 'No ratings';
    return '${average.toStringAsFixed(1)} ($count rating${count == 1 ? '' : 's'})';
  }
}

// Preset categories enum
enum PresetCategory {
  portrait('portrait', 'Portrait'),
  landscape('landscape', 'Landscape'),
  street('street', 'Street'),
  macro('macro', 'Macro'),
  creative('creative', 'Creative'),
  lowLight('low_light', 'Low Light');

  const PresetCategory(this.value, this.displayName);
  final String value;
  final String displayName;

  static PresetCategory fromString(String value) {
    return PresetCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => PresetCategory.portrait,
    );
  }
}

// Scene types enum
enum SceneType {
  portrait('portrait', 'Portrait'),
  landscape('landscape', 'Landscape'),
  macro('macro', 'Macro'),
  street('street', 'Street'),
  architecture('architecture', 'Architecture'),
  nature('nature', 'Nature'),
  sports('sports', 'Sports'),
  lowLight('low_light', 'Low Light'),
  backlight('backlight', 'Backlight'),
  sunset('sunset', 'Sunset');

  const SceneType(this.value, this.displayName);
  final String value;
  final String displayName;

  static SceneType fromString(String value) {
    return SceneType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SceneType.portrait,
    );
  }
}

// Lighting conditions enum
enum LightingCondition {
  bright('bright', 'Bright'),
  normal('normal', 'Normal'),
  dim('dim', 'Dim'),
  veryDark('very_dark', 'Very Dark'),
  goldenHour('golden_hour', 'Golden Hour'),
  blueHour('blue_hour', 'Blue Hour');

  const LightingCondition(this.value, this.displayName);
  final String value;
  final String displayName;

  static LightingCondition fromString(String value) {
    return LightingCondition.values.firstWhere(
      (condition) => condition.value == value,
      orElse: () => LightingCondition.normal,
    );
  }
}