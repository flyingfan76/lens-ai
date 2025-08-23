import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import '../../core/camera/i_camera.dart';
import '../../core/camera/camera_adapter.dart';
import '../../core/providers/unified_camera_provider.dart';
import 'ai_coordinator.dart';
import 'capability_aware_ai_coordinator.dart';

/// Enhanced AI Coordinator that bridges old and new camera systems
/// Provides capability-aware suggestions while maintaining backward compatibility
/// 
/// This gradually introduces the new capability-aware system without breaking
/// existing functionality or requiring immediate migration of all code
class EnhancedAICoordinator {
  
  final AICoordinator _legacyCoordinator;
  final CapabilityAwareAICoordinator _capabilityAwareCoordinator;
  final CameraAdapter _cameraAdapter = CameraAdapter();
  
  // Track whether we're using new capability-aware system or old fallback
  bool _usingCapabilityAwareSystem = false;
  
  EnhancedAICoordinator({AICoordinatorConfiguration? configuration}) 
    : _legacyCoordinator = AICoordinator(configuration: configuration),
      _capabilityAwareCoordinator = CapabilityAwareAICoordinator(configuration: configuration);
  
  Future<void> initialize() async {
    try {
      // Initialize both systems
      await _legacyCoordinator.initialize();
      await _capabilityAwareCoordinator.initialize();
      
      debugPrint('🚀 EnhancedAICoordinator: Both AI systems initialized successfully');
      debugPrint('   - Legacy system: ${_legacyCoordinator.isInitialized}');
      debugPrint('   - Capability-aware system: ${_capabilityAwareCoordinator.isInitialized}');
      
    } catch (e) {
      debugPrint('❌ EnhancedAICoordinator: Initialization error: $e');
      rethrow;
    }
  }
  
  /// Delegate methods to legacy coordinator for backward compatibility
  bool get isInitialized => _legacyCoordinator.isInitialized;
  
  void updateConfiguration(AICoordinatorConfiguration configuration) {
    _legacyCoordinator.updateConfiguration(configuration);
    _capabilityAwareCoordinator.updateConfiguration(configuration);
  }
  
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    return await _legacyCoordinator.analyzeImage(imageBytes);
  }
  
  /// Generate suggestions with automatic capability awareness
  /// This is the new primary method that should be used going forward
  Future<AIAnalysisResult> generateEnhancedSuggestions({
    required SceneAnalysis sceneAnalysis,
    UnifiedCameraProvider? cameraProvider, // Optional for backward compatibility
    String? cameraModel, // Fallback for old system
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    
    // Try to use new capability-aware system if camera provider is available
    if (cameraProvider != null) {
      final activeCamera = _cameraAdapter.getCurrentActiveCamera(cameraProvider);
      
      if (activeCamera != null) {
        try {
          debugPrint('✨ EnhancedAICoordinator: Using capability-aware suggestions for ${activeCamera.name}');
          debugPrint('   - Camera type: ${activeCamera.type.displayName}');
          debugPrint('   - Manual controls: ${activeCamera.capabilities.canApplyManualSettings}');
          
          _usingCapabilityAwareSystem = true;
          
          final result = await _capabilityAwareCoordinator.generateCapabilityAwareSuggestions(
            sceneAnalysis: sceneAnalysis,
            camera: activeCamera,
            userRequest: userRequest,
            imageBytes: imageBytes,
          );
          
          // Add metadata to track which system was used
          final enhancedResult = AIAnalysisResult(
            success: result.success,
            suggestions: _addSystemMetadataToSuggestions(result.suggestions, activeCamera),
            analysisTimestamp: result.analysisTimestamp,
            confidence: result.confidence,
            error: result.error,
          );
          
          debugPrint('✅ EnhancedAICoordinator: Generated ${enhancedResult.suggestions.length} capability-aware suggestions');
          return enhancedResult;
          
        } catch (e) {
          debugPrint('⚠️ EnhancedAICoordinator: Capability-aware system failed, falling back to legacy: $e');
          // Fall through to legacy system
        }
      } else {
        debugPrint('⚠️ EnhancedAICoordinator: No active camera detected, using legacy system');
      }
    }
    
    // Fallback to legacy system
    debugPrint('🔄 EnhancedAICoordinator: Using legacy AI system');
    _usingCapabilityAwareSystem = false;
    
    final result = await _legacyCoordinator.generateSuggestions(
      sceneAnalysis: sceneAnalysis,
      cameraModel: cameraModel,
      currentSettings: currentSettings,
      userRequest: userRequest,
      imageBytes: imageBytes,
    );
    
    // Add warning metadata for suggestions that might not be applicable
    final warningResult = AIAnalysisResult(
      success: result.success,
      suggestions: _addLegacyWarningsToSuggestions(result.suggestions, cameraProvider),
      analysisTimestamp: result.analysisTimestamp,
      confidence: result.confidence,
      error: result.error,
    );
    
    debugPrint('⚠️ EnhancedAICoordinator: Generated ${warningResult.suggestions.length} legacy suggestions (may include non-applicable ones)');
    return warningResult;
  }
  
  /// Backward-compatible method that automatically detects and uses best system
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    
    // Try to infer camera provider from context if not provided
    // This maintains backward compatibility for existing code
    return await generateEnhancedSuggestions(
      sceneAnalysis: sceneAnalysis,
      cameraModel: cameraModel,
      currentSettings: currentSettings,
      userRequest: userRequest,
      imageBytes: imageBytes,
    );
  }
  
  /// Check if a specific suggestion can be applied to the current camera
  bool canApplySuggestion(AISuggestion suggestion, {UnifiedCameraProvider? cameraProvider}) {
    if (!_usingCapabilityAwareSystem || cameraProvider == null) {
      // In legacy mode, assume all suggestions are applicable
      return true;
    }
    
    final activeCamera = _cameraAdapter.getCurrentActiveCamera(cameraProvider);
    if (activeCamera == null) return true;
    
    return _capabilityAwareCoordinator.canApplySuggestion(suggestion, activeCamera);
  }
  
  /// Get explanation for why a suggestion can't be applied
  String getSuggestionLimitationExplanation(AISuggestion suggestion, {UnifiedCameraProvider? cameraProvider}) {
    if (!_usingCapabilityAwareSystem || cameraProvider == null) {
      return '';
    }
    
    final activeCamera = _cameraAdapter.getCurrentActiveCamera(cameraProvider);
    if (activeCamera == null) return '';
    
    return _capabilityAwareCoordinator.getSuggestionLimitationExplanation(suggestion, activeCamera);
  }
  
  /// Get current camera capabilities (if available)
  Map<String, dynamic>? getCurrentCameraCapabilities({UnifiedCameraProvider? cameraProvider}) {
    if (cameraProvider == null) return null;
    
    final activeCamera = _cameraAdapter.getCurrentActiveCamera(cameraProvider);
    return activeCamera?.capabilities.toJson();
  }
  
  /// Check if current camera supports manual controls
  bool currentCameraSupportsManualControls({UnifiedCameraProvider? cameraProvider}) {
    if (cameraProvider == null) return true; // Assume yes in legacy mode
    
    return _cameraAdapter.currentCameraSupportsManualControls(cameraProvider);
  }
  
  /// Get capability summary for current camera
  String getCurrentCameraCapabilitySummary({UnifiedCameraProvider? cameraProvider}) {
    if (cameraProvider == null) return 'Unknown capabilities';
    
    return _cameraAdapter.getCurrentCameraCapabilitySummary(cameraProvider);
  }
  
  /// Add system metadata to suggestions to track which system generated them
  List<AISuggestion> _addSystemMetadataToSuggestions(List<AISuggestion> suggestions, ICamera camera) {
    return suggestions.map((suggestion) {
      // Create new suggestion with enhanced explanation
      return AISuggestion(
        id: suggestion.id,
        type: suggestion.type,
        category: suggestion.category,
        title: suggestion.title,
        message: suggestion.message,
        icon: suggestion.icon,
        priority: suggestion.priority,
        confidence: suggestion.confidence,
        actionable: suggestion.actionable,
        action: suggestion.action,
        visual: suggestion.visual,
        explanation: _enhanceExplanationWithCapabilityInfo(suggestion.explanation, camera),
      );
    }).toList();
  }
  
  /// Add warnings to legacy suggestions about potential applicability issues
  List<AISuggestion> _addLegacyWarningsToSuggestions(List<AISuggestion> suggestions, UnifiedCameraProvider? cameraProvider) {
    if (cameraProvider == null) return suggestions;
    
    return suggestions.map((suggestion) {
      // Check if this suggestion might not be applicable
      bool mightNotBeApplicable = false;
      String warningMessage = '';
      
      // Check for manual control suggestions on built-in cameras
      if (cameraProvider.activeCameraType == CameraSourceType.builtin) {
        switch (suggestion.category) {
          case AISuggestionCategory.iso:
            mightNotBeApplicable = true;
            warningMessage = 'Built-in cameras may not support manual ISO control.';
            break;
          case AISuggestionCategory.aperture:
            mightNotBeApplicable = true;
            warningMessage = 'Built-in cameras may not support manual aperture control.';
            break;
          case AISuggestionCategory.shutterSpeed:
            mightNotBeApplicable = true;
            warningMessage = 'Built-in cameras may not support manual shutter control.';
            break;
          case AISuggestionCategory.whiteBalance:
            mightNotBeApplicable = true;
            warningMessage = 'Built-in cameras may not support manual white balance control.';
            break;
          default:
            // Other categories are generally applicable
            break;
        }
      }
      
      if (mightNotBeApplicable) {
        return AISuggestion(
          id: suggestion.id,
          type: suggestion.type,
          category: suggestion.category,
          title: suggestion.title,
          message: suggestion.message,
          icon: suggestion.icon,
          priority: suggestion.priority * 0.8, // Lower priority for potentially non-applicable suggestions
          confidence: suggestion.confidence * 0.9, // Lower confidence
          actionable: suggestion.actionable,
          action: suggestion.action,
          visual: suggestion.visual,
          explanation: '${suggestion.explanation ?? ''}\n\n⚠️ $warningMessage',
        );
      }
      
      return suggestion;
    }).toList();
  }
  
  /// Enhance suggestion explanations with capability information
  String _enhanceExplanationWithCapabilityInfo(String? originalExplanation, ICamera camera) {
    final baseExplanation = originalExplanation ?? '';
    final capabilities = camera.capabilities;
    
    if (capabilities.isBuiltInCamera && capabilities.platformLimitations.canOnlyUseAutoMode) {
      return '$baseExplanation\n\n💡 This suggestion is optimized for your ${camera.type.displayName} camera, which uses automatic controls for best results.';
    } else if (!capabilities.isBuiltInCamera && capabilities.canApplyManualSettings) {
      return '$baseExplanation\n\n🎛️ You can apply this setting manually on your ${camera.brand.displayName} ${camera.model} camera.';
    }
    
    return baseExplanation;
  }
  
  /// Get comprehensive debug information
  Map<String, dynamic> getEnhancedDebugInfo({UnifiedCameraProvider? cameraProvider}) {
    return {
      'enhanced_ai_coordinator': {
        'using_capability_aware_system': _usingCapabilityAwareSystem,
        'legacy_system_initialized': _legacyCoordinator.isInitialized,
        'capability_aware_system_initialized': _capabilityAwareCoordinator.isInitialized,
      },
      'camera_adapter_info': cameraProvider != null ? _cameraAdapter.getDebugInfo(cameraProvider) : null,
      'current_capabilities': getCurrentCameraCapabilities(cameraProvider: cameraProvider),
    };
  }
  
  void dispose() {
    _capabilityAwareCoordinator.dispose();
    _legacyCoordinator.dispose();
    debugPrint('EnhancedAICoordinator: Disposed');
  }
}