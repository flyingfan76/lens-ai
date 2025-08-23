import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import '../../core/camera/i_camera.dart';
import '../../core/camera/camera_capabilities.dart';
import '../../core/camera/camera_settings.dart';
import 'ai_coordinator.dart';

/// Capability-aware AI coordinator that filters suggestions based on camera capabilities
/// This is the KEY FIX for the architecture - AI only suggests what cameras can do
class CapabilityAwareAICoordinator {
  
  final AICoordinator _baseCoordinator;
  
  CapabilityAwareAICoordinator({AICoordinatorConfiguration? configuration}) 
    : _baseCoordinator = AICoordinator(configuration: configuration);
    
  /// Delegate initialization to base coordinator
  Future<void> initialize() async {
    await _baseCoordinator.initialize();
  }
  
  /// Check if initialized
  bool get isInitialized => _baseCoordinator.isInitialized;
  
  /// Update configuration
  void updateConfiguration(AICoordinatorConfiguration configuration) {
    _baseCoordinator.updateConfiguration(configuration);
  }
  
  /// Dispose resources
  void dispose() {
    _baseCoordinator.dispose();
  }
  
  /// Generate suggestions filtered by camera capabilities
  /// This is the core method that prevents invalid suggestions
  Future<AIAnalysisResult> generateCapabilityAwareSuggestions({
    required SceneAnalysis sceneAnalysis,
    required ICamera camera, // Now requires camera reference!
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    
    debugPrint('🎯 CapabilityAwareAICoordinator: Generating suggestions for ${camera.name}');
    debugPrint('🎯 Camera capabilities: ${camera.capabilities.manualControlSummary}');
    
    // Generate all possible suggestions first
    final allSuggestions = await _baseCoordinator.generateSuggestions(
      sceneAnalysis: sceneAnalysis,
      cameraModel: '${camera.brand.displayName} ${camera.model}',
      currentSettings: await _getCurrentCameraSettings(camera),
      userRequest: userRequest,
      imageBytes: imageBytes,
    );
    
    if (!allSuggestions.success || allSuggestions.suggestions.isEmpty) {
      debugPrint('🎯 No base suggestions generated, returning empty result');
      return allSuggestions;
    }
    
    // Filter suggestions based on camera capabilities
    final applicableSuggestions = _filterSuggestionsByCapabilities(
      allSuggestions.suggestions, 
      camera.capabilities
    );
    
    // Add capability-specific alternative suggestions
    final enhancedSuggestions = _addCapabilitySpecificSuggestions(
      applicableSuggestions,
      allSuggestions.suggestions, // Original suggestions for context
      camera.capabilities,
      sceneAnalysis,
    );
    
    debugPrint('🎯 Filtered ${allSuggestions.suggestions.length} -> ${enhancedSuggestions.length} applicable suggestions');
    
    return AIAnalysisResult(
      success: true,
      suggestions: enhancedSuggestions,
      analysisTimestamp: allSuggestions.analysisTimestamp,
      confidence: allSuggestions.confidence,
    );
  }
  
  /// Filter suggestions based on what the camera can actually do
  List<AISuggestion> _filterSuggestionsByCapabilities(
    List<AISuggestion> suggestions, 
    CameraCapabilities capabilities
  ) {
    return suggestions.where((suggestion) {
      // Check by category since the current system uses categories for specific settings
      switch (suggestion.category) {
        // Manual exposure control suggestions
        case AISuggestionCategory.iso:
          final canApply = capabilities.supportsManualISO;
          if (!canApply) {
            debugPrint('🚫 Filtered ISO suggestion: camera doesn\'t support manual ISO');
          }
          return canApply;
          
        case AISuggestionCategory.aperture:
          final canApply = capabilities.supportsManualAperture;
          if (!canApply) {
            debugPrint('🚫 Filtered aperture suggestion: camera doesn\'t support manual aperture');
          }
          return canApply;
          
        case AISuggestionCategory.shutterSpeed:
          final canApply = capabilities.supportsManualShutter;
          if (!canApply) {
            debugPrint('🚫 Filtered shutter suggestion: camera doesn\'t support manual shutter');
          }
          return canApply;
          
        case AISuggestionCategory.exposureCompensation:
          final canApply = capabilities.supportsExposureCompensation;
          if (!canApply) {
            debugPrint('🚫 Filtered exposure compensation: not supported');
          }
          return canApply;
          
        // Focus control suggestions
        case AISuggestionCategory.focusMode:
        case AISuggestionCategory.focusPoint:
          final canApply = capabilities.supportsManualFocus || capabilities.supportsFocusControl;
          if (!canApply) {
            debugPrint('🚫 Filtered focus suggestion: camera doesn\'t support focus control');
          }
          return canApply;
          
        // White balance suggestions
        case AISuggestionCategory.whiteBalance:
          final canApply = capabilities.supportsManualWhiteBalance;
          if (!canApply) {
            debugPrint('🚫 Filtered white balance suggestion: not supported');
          }
          return canApply;
          
        // These are always applicable regardless of camera type
        case AISuggestionCategory.ruleOfThirds:
        case AISuggestionCategory.horizon:
        case AISuggestionCategory.framing:
        case AISuggestionCategory.symmetry:
        case AISuggestionCategory.leadingLines:
        case AISuggestionCategory.lighting:
        case AISuggestionCategory.perspective:
          debugPrint('✅ Keeping universal suggestion: ${suggestion.category}');
          return true;
          
        // Check for camera settings type suggestions
        default:
          if (suggestion.type == AISuggestionType.cameraSettings) {
            // For camera settings type, we need to be more restrictive for built-in cameras
            if (capabilities.isBuiltInCamera && capabilities.platformLimitations.canOnlyUseAutoMode) {
              debugPrint('🚫 Filtered camera settings suggestion: built-in camera auto-only');
              return false;
            }
          }
          // Keep composition, technique, timing, and creative suggestions
          debugPrint('✅ Keeping suggestion: ${suggestion.type}/${suggestion.category}');
          return true;
      }
    }).toList();
  }
  
  /// Add alternative suggestions for capabilities not available
  List<AISuggestion> _addCapabilitySpecificSuggestions(
    List<AISuggestion> applicableSuggestions,
    List<AISuggestion> originalSuggestions,
    CameraCapabilities capabilities,
    SceneAnalysis sceneAnalysis,
  ) {
    final enhancedSuggestions = List<AISuggestion>.from(applicableSuggestions);
    
    // If camera can't do manual controls, suggest alternative approaches
    if (!capabilities.canApplyManualSettings) {
      _addBuiltInCameraAlternatives(enhancedSuggestions, originalSuggestions, sceneAnalysis);
    }
    
    // Add capability explanation if helpful
    if (capabilities.isBuiltInCamera && capabilities.platformLimitations.canOnlyUseAutoMode) {
      enhancedSuggestions.add(_createCapabilityExplanationSuggestion(capabilities));
    }
    
    return enhancedSuggestions;
  }
  
  /// Add alternative suggestions for built-in cameras that can't do manual controls
  void _addBuiltInCameraAlternatives(
    List<AISuggestion> suggestions,
    List<AISuggestion> originalSuggestions,
    SceneAnalysis sceneAnalysis,
  ) {
    // Look for manual control suggestions that were filtered out
    final filteredISOSuggestions = originalSuggestions.where((s) => s.category == AISuggestionCategory.iso);
    final filteredApertureSuggestions = originalSuggestions.where((s) => s.category == AISuggestionCategory.aperture);
    
    // If ISO was suggested but filtered, suggest lighting alternatives
    if (filteredISOSuggestions.isNotEmpty) {
      suggestions.add(AISuggestion(
        id: 'builtin_lighting_alternative',
        type: AISuggestionType.technique,
        category: AISuggestionCategory.lighting,
        title: 'Improve lighting instead of ISO',
        message: 'Move closer to a window or add more light to the scene',
        explanation: 'Since this camera doesn\'t support manual ISO control, improving the available light is the best way to get better image quality.',
        icon: '💡',
        priority: 8,
        confidence: 0.85,
        actionable: true,
      ));
    }
    
    // If aperture was suggested but filtered, suggest distance alternatives
    if (filteredApertureSuggestions.isNotEmpty) {
      suggestions.add(AISuggestion(
        id: 'builtin_distance_alternative',
        type: AISuggestionType.technique,
        category: AISuggestionCategory.perspective,
        title: 'Adjust distance instead of aperture',
        message: 'Move closer or further from your subject to control depth',
        explanation: 'Since this camera doesn\'t support manual aperture control, changing your distance from the subject is the best way to control how much of the image is in focus.',
        icon: '📏',
        priority: 7,
        confidence: 0.8,
        actionable: true,
      ));
    }
  }
  
  /// Create a suggestion explaining camera capabilities/limitations
  AISuggestion _createCapabilityExplanationSuggestion(CameraCapabilities capabilities) {
    return AISuggestion(
      id: 'capability_explanation',
      type: AISuggestionType.technique,
      category: AISuggestionCategory.lighting, // Use an existing category
      title: 'About your camera\'s controls',
      message: capabilities.platformLimitations.reason,
      explanation: capabilities.platformLimitations.explanation,
      icon: 'ℹ️',
      priority: 3, // Lower priority, informational
      confidence: 1.0,
      actionable: false,
    );
  }
  
  /// Get current camera settings for context
  Future<Map<String, dynamic>?> _getCurrentCameraSettings(ICamera camera) async {
    if (!camera.capabilities.supportsSettingsRead || !camera.isConnected) {
      return null;
    }
    
    try {
      final settings = <String, dynamic>{};
      
      // Try to read common settings if supported
      if (camera.capabilities.supportsManualISO) {
        final iso = await camera.getSetting<int>(CameraSetting.iso);
        if (iso != null) settings['iso'] = iso;
      }
      
      if (camera.capabilities.supportsManualAperture) {
        final aperture = await camera.getSetting<String>(CameraSetting.aperture);
        if (aperture != null) settings['aperture'] = aperture;
      }
      
      if (camera.capabilities.supportsManualShutter) {
        final shutter = await camera.getSetting<String>(CameraSetting.shutterSpeed);
        if (shutter != null) settings['shutterSpeed'] = shutter;
      }
      
      return settings.isNotEmpty ? settings : null;
    } catch (e) {
      debugPrint('CapabilityAwareAICoordinator: Error reading camera settings: $e');
      return null;
    }
  }
  
  /// Validate that a suggestion can be applied to the camera
  bool canApplySuggestion(AISuggestion suggestion, ICamera camera) {
    switch (suggestion.category) {
      case AISuggestionCategory.iso:
        return camera.capabilities.supportsManualISO;
      case AISuggestionCategory.aperture:
        return camera.capabilities.supportsManualAperture;
      case AISuggestionCategory.shutterSpeed:
        return camera.capabilities.supportsManualShutter;
      case AISuggestionCategory.focusMode:
      case AISuggestionCategory.focusPoint:
        return camera.capabilities.supportsManualFocus;
      case AISuggestionCategory.whiteBalance:
        return camera.capabilities.supportsManualWhiteBalance;
      case AISuggestionCategory.exposureCompensation:
        return camera.capabilities.supportsExposureCompensation;
      default:
        return true; // Composition and lighting tips are always applicable
    }
  }
  
  /// Get explanation of why a suggestion can't be applied
  String getSuggestionLimitationExplanation(AISuggestion suggestion, ICamera camera) {
    if (canApplySuggestion(suggestion, camera)) {
      return '';
    }
    
    if (camera.capabilities.isBuiltInCamera) {
      switch (suggestion.category) {
        case AISuggestionCategory.iso:
          return 'Built-in cameras don\'t support manual ISO control. Try improving lighting instead.';
        case AISuggestionCategory.aperture:
          return 'Built-in cameras don\'t support manual aperture control. Try adjusting your distance from the subject.';
        case AISuggestionCategory.shutterSpeed:
          return 'Built-in cameras don\'t support manual shutter control. The camera will automatically adjust shutter speed.';
        default:
          return 'This setting is not available on built-in cameras.';
      }
    }
    
    return 'This camera doesn\'t support this type of manual control.';
  }
}

/// Extension to add camera-specific methods to existing AI enums
extension AISuggestionCategoryCapability on AISuggestionCategory {
  /// Check if this suggestion category requires manual camera controls
  bool get requiresManualControls {
    switch (this) {
      case AISuggestionCategory.iso:
      case AISuggestionCategory.aperture:
      case AISuggestionCategory.shutterSpeed:
      case AISuggestionCategory.focusMode:
      case AISuggestionCategory.focusPoint:
      case AISuggestionCategory.whiteBalance:
      case AISuggestionCategory.exposureCompensation:
        return true;
      default:
        return false;
    }
  }
}