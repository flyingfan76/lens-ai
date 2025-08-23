import 'camera_types.dart';
import 'camera_settings.dart';

/// Comprehensive capability information for a camera
/// This is CRITICAL for AI integration - it tells the system exactly what
/// manual controls and features are available on each camera
class CameraCapabilities {
  // ===== BASIC CAPABILITIES =====
  
  /// Can display live preview from camera
  final bool supportsLiveView;
  
  /// Can capture photos remotely
  final bool supportsRemoteCapture;
  
  /// Can record video
  final bool supportsVideoRecording;
  
  // ===== MANUAL CONTROLS - KEY FOR AI INTEGRATION =====
  
  /// Can manually set ISO sensitivity
  final bool supportsManualISO;
  
  /// Can manually set aperture (f-stop)
  final bool supportsManualAperture;
  
  /// Can manually set shutter speed
  final bool supportsManualShutter;
  
  /// Can manually control focus
  final bool supportsManualFocus;
  
  /// Can manually set white balance
  final bool supportsManualWhiteBalance;
  
  /// Can adjust exposure compensation
  final bool supportsExposureCompensation;
  
  // ===== ADVANCED FEATURES =====
  
  /// Can control focus point selection
  final bool supportsFocusControl;
  
  /// Can control zoom (if lens supports it)
  final bool supportsZoomControl;
  
  /// Supports exposure bracketing modes
  final bool supportsBracketingModes;
  
  /// Supports time-lapse photography
  final bool supportsTimeLapse;
  
  /// Supports bulb mode for long exposures
  final bool supportsBulbMode;
  
  /// Can read current camera settings
  final bool supportsSettingsRead;
  
  /// Can modify camera settings
  final bool supportsSettingsWrite;
  
  // ===== SETTING RANGES AND OPTIONS =====
  
  /// Available ISO values/range
  final CameraSettingRange? isoRange;
  
  /// Available aperture values/range
  final CameraSettingRange? apertureRange;
  
  /// Available shutter speed values/range
  final CameraSettingRange? shutterRange;
  
  /// Available focus modes
  final List<String> supportedFocusModes;
  
  /// Available shooting modes
  final List<String> supportedShootingModes;
  
  /// Available white balance presets
  final List<String> supportedWhiteBalanceModes;
  
  /// Supported image file formats
  final List<String> supportedImageFormats;
  
  /// Supported video file formats  
  final List<String> supportedVideoFormats;
  
  // ===== PLATFORM LIMITATIONS =====
  
  /// Is this a built-in camera (vs external)
  final bool isBuiltInCamera;
  
  /// Platform-specific limitations and explanations
  final PlatformLimitations platformLimitations;
  
  const CameraCapabilities({
    // Basic capabilities
    this.supportsLiveView = false,
    this.supportsRemoteCapture = false,
    this.supportsVideoRecording = false,
    
    // Manual controls
    this.supportsManualISO = false,
    this.supportsManualAperture = false,
    this.supportsManualShutter = false,
    this.supportsManualFocus = false,
    this.supportsManualWhiteBalance = false,
    this.supportsExposureCompensation = false,
    
    // Advanced features
    this.supportsFocusControl = false,
    this.supportsZoomControl = false,
    this.supportsBracketingModes = false,
    this.supportsTimeLapse = false,
    this.supportsBulbMode = false,
    this.supportsSettingsRead = false,
    this.supportsSettingsWrite = false,
    
    // Setting ranges
    this.isoRange,
    this.apertureRange,
    this.shutterRange,
    this.supportedFocusModes = const [],
    this.supportedShootingModes = const [],
    this.supportedWhiteBalanceModes = const [],
    this.supportedImageFormats = const [],
    this.supportedVideoFormats = const [],
    
    // Platform info
    this.isBuiltInCamera = false,
    this.platformLimitations = const PlatformLimitations.none(),
  });
  
  /// Factory for built-in mobile cameras (iOS/Android)
  factory CameraCapabilities.builtInMobile({
    String? model,
  }) {
    return CameraCapabilities(
      // Basic capabilities
      supportsLiveView: true,
      supportsRemoteCapture: true,
      supportsVideoRecording: true,
      
      // NO manual controls - this is key!
      supportsManualISO: false,
      supportsManualAperture: false, 
      supportsManualShutter: false,
      supportsManualFocus: false,
      supportsManualWhiteBalance: false,
      supportsExposureCompensation: false,
      
      // Limited advanced features
      supportsFocusControl: true, // Tap to focus
      supportsZoomControl: false, // Usually digital zoom only
      
      // Platform limitations
      isBuiltInCamera: true,
      platformLimitations: PlatformLimitations(
        canOnlyUseAutoMode: true,
        limitedToBasicCapture: true,
        reason: "Built-in mobile camera - automatic controls only",
        explanation: "Mobile cameras use computational photography and don't expose manual controls like ISO, aperture, or shutter speed.",
      ),
      
      // Basic formats
      supportedImageFormats: ['JPEG', 'HEIC'],
      supportedVideoFormats: ['MP4', 'MOV'],
    );
  }
  
  /// Factory for built-in desktop cameras (macOS/Windows)
  factory CameraCapabilities.builtInDesktop({
    String? model,
  }) {
    return CameraCapabilities(
      // Basic capabilities
      supportsLiveView: true,
      supportsRemoteCapture: true,
      supportsVideoRecording: true,
      
      // Very limited manual controls
      supportsManualFocus: true, // Sometimes available
      supportsExposureCompensation: true, // Basic exposure adjustment
      supportsManualISO: false,
      supportsManualAperture: false,
      supportsManualShutter: false,
      supportsManualWhiteBalance: false,
      
      // Basic features
      supportsFocusControl: true,
      
      // Platform limitations
      isBuiltInCamera: true,
      platformLimitations: PlatformLimitations(
        canOnlyUseAutoMode: false,
        limitedToBasicCapture: true,
        reason: "Built-in desktop camera - limited manual controls",
        explanation: "Desktop cameras typically only support basic focus and exposure adjustments.",
      ),
      
      // Basic formats
      supportedImageFormats: ['JPEG'],
      supportedVideoFormats: ['MP4'],
    );
  }
  
  /// Factory for external DSLR cameras
  factory CameraCapabilities.externalDSLR({
    required String model,
    required CameraBrand brand,
    CameraSettingRange? isoRange,
    CameraSettingRange? apertureRange,
    CameraSettingRange? shutterRange,
  }) {
    return CameraCapabilities(
      // Full basic capabilities
      supportsLiveView: true,
      supportsRemoteCapture: true,
      supportsVideoRecording: true, // Most modern DSLRs
      
      // FULL manual controls - this is the key advantage!
      supportsManualISO: true,
      supportsManualAperture: true,
      supportsManualShutter: true,
      supportsManualFocus: true,
      supportsManualWhiteBalance: true,
      supportsExposureCompensation: true,
      
      // Professional features
      supportsFocusControl: true,
      supportsZoomControl: true,
      supportsBracketingModes: true,
      supportsTimeLapse: true,
      supportsBulbMode: true,
      supportsSettingsRead: true,
      supportsSettingsWrite: true,
      
      // Setting ranges (camera-specific)
      isoRange: isoRange ?? CameraSettingRange.iso(),
      apertureRange: apertureRange ?? CameraSettingRange.aperture(),
      shutterRange: shutterRange ?? CameraSettingRange.shutterSpeed(),
      
      // Professional modes
      supportedFocusModes: ['Single', 'Continuous', 'Manual'],
      supportedShootingModes: ['Manual', 'Aperture Priority', 'Shutter Priority', 'Program Auto'],
      supportedWhiteBalanceModes: ['Auto', 'Daylight', 'Cloudy', 'Tungsten', 'Fluorescent', 'Flash'],
      
      // Professional formats
      supportedImageFormats: ['RAW', 'JPEG', 'RAW+JPEG'],
      supportedVideoFormats: ['MP4', 'MOV'],
      
      // No platform limitations
      isBuiltInCamera: false,
      platformLimitations: PlatformLimitations.none(),
    );
  }
  
  /// Check if this camera can apply manual camera settings
  bool get canApplyManualSettings {
    return supportsManualISO || 
           supportsManualAperture || 
           supportsManualShutter || 
           supportsManualFocus ||
           supportsManualWhiteBalance ||
           supportsExposureCompensation;
  }
  
  /// Get a summary of manual control capabilities for logging
  String get manualControlSummary {
    final controls = <String>[];
    if (supportsManualISO) controls.add('ISO');
    if (supportsManualAperture) controls.add('Aperture');
    if (supportsManualShutter) controls.add('Shutter');
    if (supportsManualFocus) controls.add('Focus');
    if (supportsManualWhiteBalance) controls.add('WB');
    if (supportsExposureCompensation) controls.add('Exposure');
    
    if (controls.isEmpty) {
      return 'No manual controls';
    }
    return 'Manual: ${controls.join(', ')}';
  }
  
  /// Convert to JSON for storage/debugging
  Map<String, dynamic> toJson() {
    return {
      'supportsLiveView': supportsLiveView,
      'supportsRemoteCapture': supportsRemoteCapture,
      'supportsVideoRecording': supportsVideoRecording,
      'supportsManualISO': supportsManualISO,
      'supportsManualAperture': supportsManualAperture,
      'supportsManualShutter': supportsManualShutter,
      'supportsManualFocus': supportsManualFocus,
      'supportsManualWhiteBalance': supportsManualWhiteBalance,
      'supportsExposureCompensation': supportsExposureCompensation,
      'supportsFocusControl': supportsFocusControl,
      'supportsZoomControl': supportsZoomControl,
      'supportsBracketingModes': supportsBracketingModes,
      'supportsTimeLapse': supportsTimeLapse,
      'supportsBulbMode': supportsBulbMode,
      'supportsSettingsRead': supportsSettingsRead,
      'supportsSettingsWrite': supportsSettingsWrite,
      'isoRange': isoRange?.toJson(),
      'apertureRange': apertureRange?.toJson(),
      'shutterRange': shutterRange?.toJson(),
      'supportedFocusModes': supportedFocusModes,
      'supportedShootingModes': supportedShootingModes,
      'supportedWhiteBalanceModes': supportedWhiteBalanceModes,
      'supportedImageFormats': supportedImageFormats,
      'supportedVideoFormats': supportedVideoFormats,
      'isBuiltInCamera': isBuiltInCamera,
      'platformLimitations': platformLimitations.toJson(),
    };
  }
}

/// Platform-specific limitations and explanations
class PlatformLimitations {
  /// Camera can only operate in automatic mode
  final bool canOnlyUseAutoMode;
  
  /// Camera is limited to basic capture operations
  final bool limitedToBasicCapture;
  
  /// Brief reason for limitations
  final String reason;
  
  /// Detailed explanation for user
  final String explanation;
  
  const PlatformLimitations({
    this.canOnlyUseAutoMode = false,
    this.limitedToBasicCapture = false,
    this.reason = '',
    this.explanation = '',
  });
  
  /// No limitations (external cameras)
  const PlatformLimitations.none() : this();
  
  Map<String, dynamic> toJson() {
    return {
      'canOnlyUseAutoMode': canOnlyUseAutoMode,
      'limitedToBasicCapture': limitedToBasicCapture,
      'reason': reason,
      'explanation': explanation,
    };
  }
}