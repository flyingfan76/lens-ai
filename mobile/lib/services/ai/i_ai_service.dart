import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';

/// Base interface for all AI services
/// This defines the core contract that all AI implementations must follow
abstract class IAIService {
  /// Initialize the AI service
  Future<void> initialize();
  
  /// Check if the service is initialized and ready to use
  bool get isInitialized;
  
  /// Analyze an image and return scene analysis data
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes);
  
  /// Generate AI suggestions based on scene analysis
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  });
  
  /// Test if the service is available and working
  Future<bool> testConnection();
  
  /// Get service capabilities
  AIServiceCapabilities get capabilities;
  
  /// Get service information
  AIServiceInfo get serviceInfo;
  
  /// Dispose resources
  void dispose();
}

/// Capabilities of an AI service
class AIServiceCapabilities {
  final bool supportsImageAnalysis;
  final bool supportsRealtimeAnalysis;
  final bool requiresNetworkConnection;
  final bool supportsCustomPrompts;
  final bool supportsCameraSettings;
  final bool supportsCompositionSuggestions;
  final List<AISuggestionCategory> supportedCategories;
  
  const AIServiceCapabilities({
    required this.supportsImageAnalysis,
    required this.supportsRealtimeAnalysis,
    required this.requiresNetworkConnection,
    required this.supportsCustomPrompts,
    required this.supportsCameraSettings,
    required this.supportsCompositionSuggestions,
    required this.supportedCategories,
  });
}

/// Information about an AI service
class AIServiceInfo {
  final String name;
  final String version;
  final String description;
  final AIServiceType type;
  final TargetPlatform? targetPlatform;
  
  const AIServiceInfo({
    required this.name,
    required this.version,
    required this.description,
    required this.type,
    this.targetPlatform,
  });
}

/// Types of AI services
enum AIServiceType {
  local('Local AI'),
  cloud('Cloud AI'),
  hybrid('Hybrid AI');
  
  const AIServiceType(this.displayName);
  final String displayName;
}

/// Configuration for AI services
class AIServiceConfiguration {
  final double confidenceThreshold;
  final int maxSuggestions;
  final List<AISuggestionCategory> enabledCategories;
  final bool enableFallback;
  final Duration timeout;
  final Map<String, dynamic> customSettings;
  
  const AIServiceConfiguration({
    this.confidenceThreshold = 0.6,
    this.maxSuggestions = 10,
    this.enabledCategories = const [
      AISuggestionCategory.iso,
      AISuggestionCategory.aperture,
      AISuggestionCategory.shutterSpeed,
      AISuggestionCategory.whiteBalance,
      AISuggestionCategory.flashMode,
      AISuggestionCategory.focusMode,
      AISuggestionCategory.exposureCompensation,
      AISuggestionCategory.hdr,
      AISuggestionCategory.stabilization,
      AISuggestionCategory.ruleOfThirds,
    ],
    this.enableFallback = true,
    this.timeout = const Duration(seconds: 30),
    this.customSettings = const {},
  });
  
  AIServiceConfiguration copyWith({
    double? confidenceThreshold,
    int? maxSuggestions,
    List<AISuggestionCategory>? enabledCategories,
    bool? enableFallback,
    Duration? timeout,
    Map<String, dynamic>? customSettings,
  }) {
    return AIServiceConfiguration(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      maxSuggestions: maxSuggestions ?? this.maxSuggestions,
      enabledCategories: enabledCategories ?? this.enabledCategories,
      enableFallback: enableFallback ?? this.enableFallback,
      timeout: timeout ?? this.timeout,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Exception thrown by AI services
class AIServiceException implements Exception {
  final String message;
  final String? serviceType;
  final Object? originalError;
  final StackTrace? stackTrace;
  
  const AIServiceException({
    required this.message,
    this.serviceType,
    this.originalError,
    this.stackTrace,
  });
  
  @override
  String toString() {
    if (serviceType != null) {
      return 'AIServiceException ($serviceType): $message';
    }
    return 'AIServiceException: $message';
  }
}