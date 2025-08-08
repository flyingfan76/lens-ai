import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/disposal_mixin.dart';
import 'i_ai_service.dart';
import 'local_ai_service.dart';
import 'cloud_ai_service.dart';

/// Main coordinator that orchestrates AI services and provides intelligent service selection
/// This is the single entry point for all AI operations in the application
class AICoordinator with ErrorHandlerMixin, ServiceDisposalMixin implements IAIService {
  static const String _coordinatorVersion = '1.0.0';
  
  // Service instances
  late final LocalAIService _localService;
  CloudAIService? _cloudService;
  
  // Configuration
  AICoordinatorConfiguration _configuration;
  bool _isInitialized = false;
  bool _aiServiceAvailable = false;
  
  // Singleton pattern
  static AICoordinator? _instance;
  
  AICoordinator._(this._configuration) {
    _localService = LocalAIService();
  }
  
  /// Get singleton instance of AICoordinator
  factory AICoordinator({AICoordinatorConfiguration? configuration}) {
    _instance ??= AICoordinator._(configuration ?? const AICoordinatorConfiguration());
    return _instance!;
  }
  
  /// Reset singleton for testing purposes
  @visibleForTesting
  static void resetSingleton() {
    _instance?.dispose();
    _instance = null;
  }
  
  @override
  Future<void> initialize() async {
    return await withAIErrorHandling(
      () async {
        if (_isInitialized) {
          debugPrint('AICoordinator: Already initialized');
          return;
        }
        
        // Always initialize local service
        await _localService.initialize();
        debugPrint('AICoordinator: Local AI service initialized');
        
        // Initialize cloud service if configured
        if (_configuration.enableCloudAI && _configuration.cloudConfiguration != null) {
          try {
            _cloudService = CloudAIService();
            await _cloudService!.initializeWithConfiguration(_configuration.cloudConfiguration!);
            debugPrint('AICoordinator: Cloud AI service initialized');
          } catch (e) {
            debugPrint('AICoordinator: Cloud AI initialization failed: $e');
            if (!_configuration.allowFallbackToLocal) {
              rethrow;
            }
            // Continue with local-only mode
          }
        }
        
        _isInitialized = true;
        _aiServiceAvailable = true;
        debugPrint('AICoordinator: Initialization complete (Strategy: ${_configuration.selectionStrategy.name})');
      },
      operation: 'initialize AI coordinator',
      showToUser: false,
    );
  }
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await withImageErrorHandling<SceneAnalysis>(
      () async {
        final service = _selectServiceForImageAnalysis();
        debugPrint('AICoordinator: Using ${service.serviceInfo.name} for image analysis');
        
        try {
          return await service.analyzeImage(imageBytes);
        } catch (e) {
          // Fallback to local service if cloud fails
          if (service != _localService && _configuration.allowFallbackToLocal) {
            debugPrint('AICoordinator: Falling back to local service for image analysis');
            return await _localService.analyzeImage(imageBytes);
          }
          rethrow;
        }
      },
      operation: 'coordinate image analysis',
      fallbackValue: await _createFallbackSceneAnalysis(),
    ) ?? await _createFallbackSceneAnalysis();
  }
  
  @override
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await withAIErrorHandling<AIAnalysisResult>(
      () async {
        AIAnalysisResult? result;
        
        // Try different strategies based on configuration
        switch (_configuration.selectionStrategy) {
          case ServiceSelectionStrategy.localFirst:
            result = await _tryLocalFirst(
              sceneAnalysis: sceneAnalysis,
              cameraModel: cameraModel,
              currentSettings: currentSettings,
              userRequest: userRequest,
              imageBytes: imageBytes,
            );
            break;
            
          case ServiceSelectionStrategy.cloudFirst:
            result = await _tryCloudFirst(
              sceneAnalysis: sceneAnalysis,
              cameraModel: cameraModel,
              currentSettings: currentSettings,
              userRequest: userRequest,
              imageBytes: imageBytes,
            );
            break;
            
          case ServiceSelectionStrategy.hybrid:
            result = await _tryHybrid(
              sceneAnalysis: sceneAnalysis,
              cameraModel: cameraModel,
              currentSettings: currentSettings,
              userRequest: userRequest,
              imageBytes: imageBytes,
            );
            break;
            
          case ServiceSelectionStrategy.localOnly:
            result = await _localService.generateSuggestions(
              sceneAnalysis: sceneAnalysis,
              cameraModel: cameraModel,
              currentSettings: currentSettings,
              userRequest: userRequest,
              imageBytes: imageBytes,
            );
            break;
            
          case ServiceSelectionStrategy.cloudOnly:
            if (_cloudService == null) {
              throw AIServiceException(
                message: 'Cloud service not available',
                serviceType: 'AICoordinator',
              );
            }
            result = await _cloudService!.generateSuggestions(
              sceneAnalysis: sceneAnalysis,
              cameraModel: cameraModel,
              currentSettings: currentSettings,
              userRequest: userRequest,
              imageBytes: imageBytes,
            );
            break;
        }
        
        // Post-process and filter suggestions
        return _postProcessSuggestions(result);
      },
      operation: 'coordinate AI suggestion generation',
      fallbackValue: await _createFallbackAnalysisResult(),
    ) ?? await _createFallbackAnalysisResult();
  }
  
  @override
  Future<bool> testConnection() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Test local service
      final localConnectionOk = await _localService.testConnection();
      
      // Test cloud service if available
      bool cloudConnectionOk = true;
      if (_cloudService != null) {
        cloudConnectionOk = await _cloudService!.testConnection();
      }
      
      final allOk = localConnectionOk && cloudConnectionOk;
      debugPrint('AICoordinator: Connection test - Local: $localConnectionOk, Cloud: $cloudConnectionOk, Overall: $allOk');
      
      return allOk;
    } catch (e) {
      debugPrint('AICoordinator: Connection test failed: $e');
      return false;
    }
  }
  
  @override
  AIServiceCapabilities get capabilities {
    // Combine capabilities from all available services
    final localCaps = _localService.capabilities;
    final cloudCaps = _cloudService?.capabilities;
    
    final combinedCategories = {
      ...localCaps.supportedCategories,
      if (cloudCaps != null) ...cloudCaps.supportedCategories,
    }.toList();
    
    return AIServiceCapabilities(
      supportsImageAnalysis: localCaps.supportsImageAnalysis || (cloudCaps?.supportsImageAnalysis ?? false),
      supportsRealtimeAnalysis: localCaps.supportsRealtimeAnalysis, // Only local supports real-time
      requiresNetworkConnection: _configuration.selectionStrategy == ServiceSelectionStrategy.cloudOnly,
      supportsCustomPrompts: cloudCaps?.supportsCustomPrompts ?? false,
      supportsCameraSettings: localCaps.supportsCameraSettings || (cloudCaps?.supportsCameraSettings ?? false),
      supportsCompositionSuggestions: localCaps.supportsCompositionSuggestions || (cloudCaps?.supportsCompositionSuggestions ?? false),
      supportedCategories: combinedCategories,
    );
  }
  
  @override
  AIServiceInfo get serviceInfo => AIServiceInfo(
    name: 'AI Coordinator',
    version: _coordinatorVersion,
    description: 'Intelligent coordination of local and cloud AI services',
    type: AIServiceType.hybrid,
    targetPlatform: defaultTargetPlatform,
  );
  
  // Configuration methods
  
  /// Update coordinator configuration
  void updateConfiguration(AICoordinatorConfiguration configuration) {
    _configuration = configuration;
    debugPrint('AICoordinator: Configuration updated - Strategy: ${_configuration.selectionStrategy.name}');
  }
  
  /// Get current configuration
  AICoordinatorConfiguration get configuration => _configuration;
  
  /// Get available services
  List<IAIService> get availableServices {
    final services = <IAIService>[_localService];
    if (_cloudService != null) {
      services.add(_cloudService!);
    }
    return services;
  }
  
  /// Get service statistics
  Map<String, dynamic> getServiceStatistics() {
    return {
      'localService': {
        'available': _localService.isInitialized,
        'capabilities': _localService.capabilities.supportedCategories.length,
      },
      'cloudService': {
        'available': _cloudService?.isInitialized ?? false,
        'capabilities': _cloudService?.capabilities.supportedCategories.length ?? 0,
      },
      'configuration': {
        'strategy': _configuration.selectionStrategy.name,
        'cloudEnabled': _configuration.enableCloudAI,
        'fallbackEnabled': _configuration.allowFallbackToLocal,
      },
    };
  }
  
  // Service selection logic
  
  IAIService _selectServiceForImageAnalysis() {
    switch (_configuration.selectionStrategy) {
      case ServiceSelectionStrategy.localFirst:
      case ServiceSelectionStrategy.localOnly:
        return _localService;
        
      case ServiceSelectionStrategy.cloudFirst:
      case ServiceSelectionStrategy.cloudOnly:
        return (_cloudService ?? _localService) as IAIService;
        
      case ServiceSelectionStrategy.hybrid:
        // For image analysis, prefer local for speed
        return _localService;
    }
  }
  
  Future<AIAnalysisResult> _tryLocalFirst({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    try {
      final result = await _localService.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
      debugPrint('AICoordinator: Local service succeeded');
      return result;
    } catch (e) {
      debugPrint('AICoordinator: Local service failed: $e');
      
      if (_cloudService != null && _configuration.allowFallbackToLocal) {
        try {
          final result = await _cloudService!.generateSuggestions(
            sceneAnalysis: sceneAnalysis,
            cameraModel: cameraModel,
            currentSettings: currentSettings,
            userRequest: userRequest,
            imageBytes: imageBytes,
          );
          debugPrint('AICoordinator: Fallback to cloud service succeeded');
          return result;
        } catch (cloudError) {
          debugPrint('AICoordinator: Cloud service also failed: $cloudError');
        }
      }
      
      rethrow;
    }
  }
  
  Future<AIAnalysisResult> _tryCloudFirst({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    if (_cloudService == null) {
      debugPrint('AICoordinator: Cloud service not available, using local');
      return await _localService.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
    }
    
    try {
      final result = await _cloudService!.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
      debugPrint('AICoordinator: Cloud service succeeded');
      return result;
    } catch (e) {
      debugPrint('AICoordinator: Cloud service failed: $e');
      
      if (_configuration.allowFallbackToLocal) {
        try {
          final result = await _localService.generateSuggestions(
            sceneAnalysis: sceneAnalysis,
            cameraModel: cameraModel,
            currentSettings: currentSettings,
            userRequest: userRequest,
            imageBytes: imageBytes,
          );
          debugPrint('AICoordinator: Fallback to local service succeeded');
          return result;
        } catch (localError) {
          debugPrint('AICoordinator: Local service also failed: $localError');
        }
      }
      
      rethrow;
    }
  }
  
  Future<AIAnalysisResult> _tryHybrid({
    required SceneAnalysis sceneAnalysis,
    String? cameraModel,
    Map<String, dynamic>? currentSettings,
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    // Run both services concurrently if cloud is available
    if (_cloudService == null) {
      return await _localService.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
    }
    
    try {
      // Start both services concurrently
      final localFuture = _localService.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
      
      final cloudFuture = _cloudService!.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: cameraModel,
        currentSettings: currentSettings,
        userRequest: userRequest,
        imageBytes: imageBytes,
      );
      
      // Wait for both results with error handling
      AIAnalysisResult? localResult;
      AIAnalysisResult? cloudResult;
      
      try {
        localResult = await localFuture;
      } catch (e) {
        debugPrint('AICoordinator: Local service failed in hybrid mode: $e');
      }
      
      try {
        cloudResult = await cloudFuture.timeout(_configuration.cloudTimeout);
      } catch (e) {
        debugPrint('AICoordinator: Cloud service failed in hybrid mode: $e');
      }
      
      // Merge results if both are available
      if (localResult != null && cloudResult != null) {
        return _mergeResults(localResult, cloudResult);
      }
      
      // Return whichever result is available
      if (localResult != null) {
        debugPrint('AICoordinator: Using local result in hybrid mode');
        return localResult;
      }
      
      if (cloudResult != null) {
        debugPrint('AICoordinator: Using cloud result in hybrid mode');
        return cloudResult;
      }
      
      throw AIServiceException(
        message: 'Both local and cloud services failed in hybrid mode',
        serviceType: 'AICoordinator',
      );
    } catch (e) {
      debugPrint('AICoordinator: Hybrid processing failed: $e');
      rethrow;
    }
  }
  
  // Result processing methods
  
  AIAnalysisResult _mergeResults(AIAnalysisResult localResult, AIAnalysisResult cloudResult) {
    final mergedSuggestions = <AISuggestion>[];
    
    // Add all local suggestions
    mergedSuggestions.addAll(localResult.suggestions);
    
    // Add cloud suggestions that don't duplicate local ones
    for (final cloudSuggestion in cloudResult.suggestions) {
      final isDuplicate = mergedSuggestions.any((localSugg) => 
        localSugg.category == cloudSuggestion.category &&
        localSugg.type == cloudSuggestion.type
      );
      
      if (!isDuplicate) {
        // Create a modified version of the cloud suggestion
        final modifiedSuggestion = AISuggestion(
          id: '${cloudSuggestion.id}_cloud',
          type: cloudSuggestion.type,
          category: cloudSuggestion.category,
          title: cloudSuggestion.title,
          message: cloudSuggestion.message,
          icon: cloudSuggestion.icon,
          priority: cloudSuggestion.priority,
          confidence: cloudSuggestion.confidence,
          actionable: cloudSuggestion.actionable,
          action: cloudSuggestion.action,
          visual: cloudSuggestion.visual,
          explanation: '${cloudSuggestion.explanation} (Cloud AI)',
        );
        mergedSuggestions.add(modifiedSuggestion);
      }
    }
    
    // Sort by priority and limit count
    mergedSuggestions.sort((a, b) => b.priority.compareTo(a.priority));
    final limitedSuggestions = mergedSuggestions.take(_configuration.maxSuggestions).toList();
    
    // Calculate combined confidence
    final avgConfidence = (localResult.confidence + cloudResult.confidence) / 2;
    
    debugPrint('AICoordinator: Merged ${localResult.suggestions.length} local + ${cloudResult.suggestions.length} cloud = ${limitedSuggestions.length} final suggestions');
    
    return AIAnalysisResult(
      success: true,
      suggestions: limitedSuggestions,
      analysisTimestamp: DateTime.now(),
      confidence: avgConfidence,
    );
  }
  
  AIAnalysisResult _postProcessSuggestions(AIAnalysisResult result) {
    if (!result.success || result.suggestions.isEmpty) {
      return result;
    }
    
    // Filter by confidence threshold
    final filteredSuggestions = result.suggestions.where((suggestion) {
      return suggestion.confidence >= _configuration.confidenceThreshold;
    }).toList();
    
    // Sort by priority
    filteredSuggestions.sort((a, b) => b.priority.compareTo(a.priority));
    
    // Limit count
    final limitedSuggestions = filteredSuggestions.take(_configuration.maxSuggestions).toList();
    
    return AIAnalysisResult(
      success: result.success,
      suggestions: limitedSuggestions,
      analysisTimestamp: result.analysisTimestamp,
      confidence: result.confidence,
    );
  }
  
  // Fallback methods
  
  Future<SceneAnalysis> _createFallbackSceneAnalysis() async {
    return SceneAnalysis(
      sceneType: 'general',
      lightingCondition: 'normal',
      subjectDistance: 'medium',
      movementDetected: false,
      brightness: 0.5,
      contrast: 0.5,
      colorTemperature: 5500,
      dominantColors: [],
      faces: [],
      motion: 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }
  
  Future<AIAnalysisResult> _createFallbackAnalysisResult() async {
    return AIAnalysisResult(
      success: false,
      suggestions: [],
      analysisTimestamp: DateTime.now(),
      confidence: 0.0,
    );
  }
  
  /// Check if AI service is available
  bool isServiceAvailable() {
    return _isInitialized && _aiServiceAvailable;
  }
  
  /// Get current AI provider
  String get currentProvider {
    if (_cloudService?.isInitialized == true) {
      return 'cloud';
    }
    return 'local';
  }
  
  /// Check if service is available (async version)
  Future<bool> get isServiceAvailableAsync async {
    if (!_isInitialized) {
      await initialize();
    }
    return isServiceAvailable();
  }
  
  /// Get capabilities as Map for compatibility
  Future<Map<String, dynamic>> getCapabilities() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final caps = capabilities;
    return {
      'supportsImageAnalysis': caps.supportsImageAnalysis,
      'supportsRealtimeAnalysis': caps.supportsRealtimeAnalysis,
      'requiresNetworkConnection': caps.requiresNetworkConnection,
      'supportsCustomPrompts': caps.supportsCustomPrompts,
      'supportsCameraSettings': caps.supportsCameraSettings,
      'supportsCompositionSuggestions': caps.supportsCompositionSuggestions,
      'supportedCategories': caps.supportedCategories.map((c) => c.name).toList(),
    };
  }
  
  /// Analyze image with path (compatibility method)
  Future<Map<String, dynamic>> analyzeImageFromPath({
    String? imagePath,
    String analysisType = 'scene',
  }) async {
    // This is a compatibility method that returns a simple Map
    // The actual image analysis would require image bytes
    if (!_isInitialized) {
      await initialize();
    }
    
    return {
      'type': analysisType,
      'success': true,
      'timestamp': DateTime.now().toIso8601String(),
      'analysis': {
        'sceneType': 'general',
        'lightingCondition': 'normal',
        'confidence': 0.75,
      },
    };
  }

  @override
  void dispose() {
    _localService.dispose();
    _cloudService?.dispose();
    debugPrint('AICoordinator: Disposed');
    super.dispose();
  }
}

/// Service selection strategies
enum ServiceSelectionStrategy {
  localFirst('Local First'),
  cloudFirst('Cloud First'),
  hybrid('Hybrid'),
  localOnly('Local Only'),
  cloudOnly('Cloud Only');
  
  const ServiceSelectionStrategy(this.displayName);
  final String displayName;
}


/// Configuration for AI coordinator
class AICoordinatorConfiguration {
  final ServiceSelectionStrategy selectionStrategy;
  final bool enableCloudAI;
  final CloudAIConfiguration? cloudConfiguration;
  final bool allowFallbackToLocal;
  final double confidenceThreshold;
  final int maxSuggestions;
  final Duration cloudTimeout;
  
  const AICoordinatorConfiguration({
    this.selectionStrategy = ServiceSelectionStrategy.localFirst,
    this.enableCloudAI = false,
    this.cloudConfiguration,
    this.allowFallbackToLocal = true,
    this.confidenceThreshold = 0.6,
    this.maxSuggestions = 10,
    this.cloudTimeout = const Duration(seconds: 10),
  });
  
  AICoordinatorConfiguration copyWith({
    ServiceSelectionStrategy? selectionStrategy,
    bool? enableCloudAI,
    CloudAIConfiguration? cloudConfiguration,
    bool? allowFallbackToLocal,
    double? confidenceThreshold,
    int? maxSuggestions,
    Duration? cloudTimeout,
  }) {
    return AICoordinatorConfiguration(
      selectionStrategy: selectionStrategy ?? this.selectionStrategy,
      enableCloudAI: enableCloudAI ?? this.enableCloudAI,
      cloudConfiguration: cloudConfiguration ?? this.cloudConfiguration,
      allowFallbackToLocal: allowFallbackToLocal ?? this.allowFallbackToLocal,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      maxSuggestions: maxSuggestions ?? this.maxSuggestions,
      cloudTimeout: cloudTimeout ?? this.cloudTimeout,
    );
  }
}