import 'package:flutter/foundation.dart';

/// Represents a camera preset with all configurable settings
class CameraPreset {
  final String id;
  final String name;
  final String description;
  final PresetCategory category;
  final PresetSource source;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int usageCount;
  final bool isFavorite;
  
  // Camera settings
  final CameraSettings settings;
  
  // Visual representation
  final String? iconName;
  final String? thumbnailPath;

  const CameraPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.source,
    required this.createdAt,
    required this.lastUsedAt,
    required this.usageCount,
    required this.isFavorite,
    required this.settings,
    this.iconName,
    this.thumbnailPath,
  });

  CameraPreset copyWith({
    String? id,
    String? name,
    String? description,
    PresetCategory? category,
    PresetSource? source,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? usageCount,
    bool? isFavorite,
    CameraSettings? settings,
    String? iconName,
    String? thumbnailPath,
  }) {
    return CameraPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      settings: settings ?? this.settings,
      iconName: iconName ?? this.iconName,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'usageCount': usageCount,
      'isFavorite': isFavorite,
      'settings': settings.toJson(),
      'iconName': iconName,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory CameraPreset.fromJson(Map<String, dynamic> json) {
    return CameraPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: PresetCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PresetCategory.custom,
      ),
      source: PresetSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => PresetSource.user,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      usageCount: json['usageCount'] as int,
      isFavorite: json['isFavorite'] as bool,
      settings: CameraSettings.fromJson(json['settings'] as Map<String, dynamic>),
      iconName: json['iconName'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CameraPreset(id: $id, name: $name, category: $category)';
  }
}

/// Camera settings that can be saved in a preset
class CameraSettings {
  // Exposure settings
  final double? iso;
  final double? aperture;
  final String? shutterSpeed;
  final double? exposureCompensation;

  // Focus settings
  final FocusMode focusMode;
  final MeteringMode meteringMode;

  // White balance
  final WhiteBalanceMode whiteBalanceMode;
  final double? colorTemperature;
  final double? tint;

  // Image quality
  final ResolutionPreset resolution;
  final ImageFormat imageFormat;
  final bool enableHDR;

  // Advanced settings
  final FlashMode flashMode;
  final bool gridLines;
  final bool histogram;
  final int? timer;

  const CameraSettings({
    this.iso,
    this.aperture,
    this.shutterSpeed,
    this.exposureCompensation,
    this.focusMode = FocusMode.auto,
    this.meteringMode = MeteringMode.matrix,
    this.whiteBalanceMode = WhiteBalanceMode.auto,
    this.colorTemperature,
    this.tint,
    this.resolution = ResolutionPreset.high,
    this.imageFormat = ImageFormat.jpeg,
    this.enableHDR = false,
    this.flashMode = FlashMode.auto,
    this.gridLines = false,
    this.histogram = false,
    this.timer,
  });

  CameraSettings copyWith({
    double? iso,
    double? aperture,
    String? shutterSpeed,
    double? exposureCompensation,
    FocusMode? focusMode,
    MeteringMode? meteringMode,
    WhiteBalanceMode? whiteBalanceMode,
    double? colorTemperature,
    double? tint,
    ResolutionPreset? resolution,
    ImageFormat? imageFormat,
    bool? enableHDR,
    FlashMode? flashMode,
    bool? gridLines,
    bool? histogram,
    int? timer,
  }) {
    return CameraSettings(
      iso: iso ?? this.iso,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      exposureCompensation: exposureCompensation ?? this.exposureCompensation,
      focusMode: focusMode ?? this.focusMode,
      meteringMode: meteringMode ?? this.meteringMode,
      whiteBalanceMode: whiteBalanceMode ?? this.whiteBalanceMode,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      tint: tint ?? this.tint,
      resolution: resolution ?? this.resolution,
      imageFormat: imageFormat ?? this.imageFormat,
      enableHDR: enableHDR ?? this.enableHDR,
      flashMode: flashMode ?? this.flashMode,
      gridLines: gridLines ?? this.gridLines,
      histogram: histogram ?? this.histogram,
      timer: timer ?? this.timer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iso': iso,
      'aperture': aperture,
      'shutterSpeed': shutterSpeed,
      'exposureCompensation': exposureCompensation,
      'focusMode': focusMode.name,
      'meteringMode': meteringMode.name,
      'whiteBalanceMode': whiteBalanceMode.name,
      'colorTemperature': colorTemperature,
      'tint': tint,
      'resolution': resolution.name,
      'imageFormat': imageFormat.name,
      'enableHDR': enableHDR,
      'flashMode': flashMode.name,
      'gridLines': gridLines,
      'histogram': histogram,
      'timer': timer,
    };
  }

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      iso: json['iso'] as double?,
      aperture: json['aperture'] as double?,
      shutterSpeed: json['shutterSpeed'] as String?,
      exposureCompensation: json['exposureCompensation'] as double?,
      focusMode: FocusMode.values.firstWhere(
        (e) => e.name == json['focusMode'],
        orElse: () => FocusMode.auto,
      ),
      meteringMode: MeteringMode.values.firstWhere(
        (e) => e.name == json['meteringMode'],
        orElse: () => MeteringMode.matrix,
      ),
      whiteBalanceMode: WhiteBalanceMode.values.firstWhere(
        (e) => e.name == json['whiteBalanceMode'],
        orElse: () => WhiteBalanceMode.auto,
      ),
      colorTemperature: json['colorTemperature'] as double?,
      tint: json['tint'] as double?,
      resolution: ResolutionPreset.values.firstWhere(
        (e) => e.name == json['resolution'],
        orElse: () => ResolutionPreset.high,
      ),
      imageFormat: ImageFormat.values.firstWhere(
        (e) => e.name == json['imageFormat'],
        orElse: () => ImageFormat.jpeg,
      ),
      enableHDR: json['enableHDR'] as bool? ?? false,
      flashMode: FlashMode.values.firstWhere(
        (e) => e.name == json['flashMode'],
        orElse: () => FlashMode.auto,
      ),
      gridLines: json['gridLines'] as bool? ?? false,
      histogram: json['histogram'] as bool? ?? false,
      timer: json['timer'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraSettings &&
        other.iso == iso &&
        other.aperture == aperture &&
        other.shutterSpeed == shutterSpeed &&
        other.exposureCompensation == exposureCompensation &&
        other.focusMode == focusMode &&
        other.meteringMode == meteringMode &&
        other.whiteBalanceMode == whiteBalanceMode &&
        other.colorTemperature == colorTemperature &&
        other.tint == tint &&
        other.resolution == resolution &&
        other.imageFormat == imageFormat &&
        other.enableHDR == enableHDR &&
        other.flashMode == flashMode &&
        other.gridLines == gridLines &&
        other.histogram == histogram &&
        other.timer == timer;
  }

  @override
  int get hashCode {
    return Object.hash(
      iso,
      aperture,
      shutterSpeed,
      exposureCompensation,
      focusMode,
      meteringMode,
      whiteBalanceMode,
      colorTemperature,
      tint,
      resolution,
      imageFormat,
      enableHDR,
      flashMode,
      gridLines,
      histogram,
      timer,
    );
  }
}

// Enums for preset categorization
enum PresetCategory {
  portrait,
  landscape,
  sports,
  lowLight,
  macro,
  street,
  event,
  studio,
  sunset,
  indoor,
  beach,
  snow,
  blackAndWhite,
  vintage,
  hdr,
  longExposure,
  custom,
}

enum PresetSource {
  builtin,
  user,
  imported,
  ai,
}

// Camera setting enums
enum FocusMode {
  auto,
  manual,
  single,
  continuous,
}

enum MeteringMode {
  matrix,
  center,
  spot,
}

enum WhiteBalanceMode {
  auto,
  daylight,
  cloudy,
  shade,
  tungsten,
  fluorescent,
  flash,
  custom,
}

enum ResolutionPreset {
  low,
  medium,
  high,
  veryHigh,
  ultraHigh,
  max,
}

enum ImageFormat {
  jpeg,
  raw,
  heic,
}

enum FlashMode {
  off,
  auto,
  always,
  torch,
}

// Extension methods for better UX
extension PresetCategoryExtension on PresetCategory {
  String get displayName {
    switch (this) {
      case PresetCategory.portrait:
        return 'Portrait';
      case PresetCategory.landscape:
        return 'Landscape';
      case PresetCategory.sports:
        return 'Sports';
      case PresetCategory.lowLight:
        return 'Low Light';
      case PresetCategory.macro:
        return 'Macro';
      case PresetCategory.street:
        return 'Street';
      case PresetCategory.event:
        return 'Event';
      case PresetCategory.studio:
        return 'Studio';
      case PresetCategory.sunset:
        return 'Sunset';
      case PresetCategory.indoor:
        return 'Indoor';
      case PresetCategory.beach:
        return 'Beach';
      case PresetCategory.snow:
        return 'Snow';
      case PresetCategory.blackAndWhite:
        return 'B&W';
      case PresetCategory.vintage:
        return 'Vintage';
      case PresetCategory.hdr:
        return 'HDR';
      case PresetCategory.longExposure:
        return 'Long Exposure';
      case PresetCategory.custom:
        return 'Custom';
    }
  }

  String get iconName {
    switch (this) {
      case PresetCategory.portrait:
        return 'person_outline';
      case PresetCategory.landscape:
        return 'landscape';
      case PresetCategory.sports:
        return 'sports';
      case PresetCategory.lowLight:
        return 'nights_stay';
      case PresetCategory.macro:
        return 'center_focus_strong';
      case PresetCategory.street:
        return 'location_city';
      case PresetCategory.event:
        return 'event';
      case PresetCategory.studio:
        return 'studio';
      case PresetCategory.sunset:
        return 'wb_sunny';
      case PresetCategory.indoor:
        return 'home';
      case PresetCategory.beach:
        return 'beach_access';
      case PresetCategory.snow:
        return 'ac_unit';
      case PresetCategory.blackAndWhite:
        return 'filter_b_and_w';
      case PresetCategory.vintage:
        return 'filter_vintage';
      case PresetCategory.hdr:
        return 'hdr_on';
      case PresetCategory.longExposure:
        return 'slow_motion_video';
      case PresetCategory.custom:
        return 'tune';
    }
  }
}