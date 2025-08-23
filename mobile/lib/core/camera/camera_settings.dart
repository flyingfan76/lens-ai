/// Camera settings definitions for the unified camera system
library;

/// Camera setting identifiers
enum CameraSetting {
  // Exposure settings
  iso('ISO'),
  aperture('Aperture'),
  shutterSpeed('Shutter Speed'),
  exposureCompensation('Exposure Compensation'),
  
  // Focus settings
  focusMode('Focus Mode'),
  focusPoint('Focus Point'),
  
  // White balance
  whiteBalance('White Balance'),
  
  // Shooting settings
  shootingMode('Shooting Mode'),
  imageFormat('Image Format'),
  imageQuality('Image Quality'),
  
  // Advanced settings
  meteringMode('Metering Mode'),
  flashMode('Flash Mode'),
  driveMode('Drive Mode'),
  
  unknown('Unknown');
  
  const CameraSetting(this.displayName);
  final String displayName;
}

/// Range of values for numeric camera settings
class CameraSettingRange {
  final double min;
  final double max;
  final double step;
  final List<dynamic>? discreteValues;
  final String? unit;
  
  const CameraSettingRange({
    required this.min,
    required this.max,
    this.step = 1.0,
    this.discreteValues,
    this.unit,
  });
  
  /// Create range from a list of discrete values
  CameraSettingRange.fromList(List<dynamic> values, {this.unit}) 
    : min = 0,
      max = values.length.toDouble() - 1,
      step = 1.0,
      discreteValues = values;
  
  /// Standard ISO range for most cameras
  factory CameraSettingRange.iso() {
    return CameraSettingRange.fromList([
      100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
      1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000,
      10000, 12800, 16000, 20000, 25600
    ], unit: 'ISO');
  }
  
  /// Standard aperture range
  factory CameraSettingRange.aperture() {
    return CameraSettingRange.fromList([
      'f/1.0', 'f/1.1', 'f/1.2', 'f/1.4', 'f/1.6', 'f/1.8', 'f/2.0', 'f/2.2',
      'f/2.5', 'f/2.8', 'f/3.2', 'f/3.5', 'f/4.0', 'f/4.5', 'f/5.0', 'f/5.6',
      'f/6.3', 'f/7.1', 'f/8.0', 'f/9.0', 'f/10', 'f/11', 'f/13', 'f/14',
      'f/16', 'f/18', 'f/20', 'f/22', 'f/25', 'f/29', 'f/32'
    ]);
  }
  
  /// Standard shutter speed range
  factory CameraSettingRange.shutterSpeed() {
    return CameraSettingRange.fromList([
      '30"', '25"', '20"', '15"', '13"', '10"', '8"', '6"', '5"', '4"', '3.2"', '2.5"', '2"', '1.6"', '1.3"', '1"',
      '1/1.3', '1/1.6', '1/2', '1/2.5', '1/3', '1/4', '1/5', '1/6', '1/8', '1/10', '1/13', '1/15', '1/20', '1/25',
      '1/30', '1/40', '1/50', '1/60', '1/80', '1/100', '1/125', '1/160', '1/200', '1/250', '1/320', '1/400', '1/500',
      '1/640', '1/800', '1/1000', '1/1250', '1/1600', '1/2000', '1/2500', '1/3200', '1/4000', '1/5000', '1/6400',
      '1/8000'
    ], unit: 'sec');
  }
  
  /// Exposure compensation range (typically -3 to +3 EV)
  factory CameraSettingRange.exposureCompensation() {
    return const CameraSettingRange(
      min: -3.0,
      max: 3.0,
      step: 1.0/3.0, // 1/3 stop increments
      unit: 'EV',
    );
  }
  
  /// Check if a value is within this range
  bool contains(dynamic value) {
    if (discreteValues != null) {
      return discreteValues!.contains(value);
    }
    
    if (value is num) {
      return value >= min && value <= max;
    }
    
    return false;
  }
  
  /// Get the closest valid value to the given input
  dynamic getClosestValue(dynamic input) {
    if (discreteValues != null) {
      if (input is int && input >= 0 && input < discreteValues!.length) {
        return discreteValues![input];
      }
      return discreteValues!.first;
    }
    
    if (input is num) {
      if (input < min) return min;
      if (input > max) return max;
      
      // Snap to step increments
      final steps = ((input - min) / step).round();
      return min + (steps * step);
    }
    
    return min;
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
      'step': step,
      'discreteValues': discreteValues,
      'unit': unit,
    };
  }
  
  factory CameraSettingRange.fromJson(Map<String, dynamic> json) {
    return CameraSettingRange(
      min: json['min']?.toDouble() ?? 0.0,
      max: json['max']?.toDouble() ?? 0.0,
      step: json['step']?.toDouble() ?? 1.0,
      discreteValues: json['discreteValues'],
      unit: json['unit'],
    );
  }
}

/// Camera setting value with metadata
class CameraSettingValue<T> {
  final T value;
  final String displayValue;
  final bool isValid;
  final String? error;
  
  const CameraSettingValue({
    required this.value,
    required this.displayValue,
    this.isValid = true,
    this.error,
  });
  
  CameraSettingValue.invalid({
    required T value,
    required String error,
  }) : this(
    value: value,
    displayValue: value.toString(),
    isValid: false,
    error: error,
  );
}

/// Helper functions for camera settings
class CameraSettingHelper {
  /// Convert ISO number to display string
  static String formatISO(int iso) => 'ISO $iso';
  
  /// Convert aperture value to f-stop string
  static String formatAperture(double aperture) => 'f/$aperture';
  
  /// Convert shutter speed fraction to display string
  static String formatShutterSpeed(String speed) => speed;
  
  /// Parse ISO from string
  static int? parseISO(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
  
  /// Parse aperture from f-stop string
  static double? parseAperture(String value) {
    final match = RegExp(r'f[/\s]*(\d+\.?\d*)').firstMatch(value.toLowerCase());
    return match != null ? double.tryParse(match.group(1)!) : null;
  }
}