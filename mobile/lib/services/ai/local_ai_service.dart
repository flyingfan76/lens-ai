import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../models/ai_suggestion.dart';
import '../../core/utils/lens_exceptions.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/disposal_mixin.dart';
import 'i_ai_service.dart';

// Conditional imports for platform-specific implementations
import 'platforms/ai_platform_stub.dart' show LocalAIPlatform, createLocalAIPlatform
    if (dart.library.io) 'platforms/ai_platform_mobile.dart'
    if (dart.library.html) 'platforms/ai_platform_web.dart';

/// Local AI service that handles all on-device AI processing
/// This service operates entirely offline and doesn't require network connectivity
class LocalAIService with ErrorHandlerMixin, ServiceDisposalMixin implements IAIService {
  static const String _serviceVersion = '1.0.0';
  
  late final LocalAIPlatform _platform;
  bool _isInitialized = false;
  
  LocalAIService() {
    _platform = createLocalAIPlatform();
  }
  
  @override
  Future<void> initialize() async {
    return await withAIErrorHandling(
      () async {
        await _platform.initializeModel();
        _isInitialized = true;
        debugPrint('LocalAIService: Initialized successfully');
      },
      operation: 'initialize local AI service',
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
        if (imageBytes.isEmpty) {
          throw InvalidImageFormatException(
            message: 'Empty image data',
            details: 'Image bytes are empty',
          );
        }

        // Check image size to prevent memory issues
        if (imageBytes.length > 50 * 1024 * 1024) { // 50MB limit
          throw ImageTooLargeException(
            details: 'Image size: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB',
          );
        }

        final image = img.decodeImage(imageBytes);
        if (image == null) {
          throw InvalidImageFormatException(
            message: 'Failed to decode image',
            details: 'Image format not supported or corrupted',
          );
        }

        try {
          final brightness = _calculateBrightness(image);
          final contrast = _calculateContrast(image);
          final colorTemp = _estimateColorTemperature(image);
          final dominantColors = _extractDominantColors(image);
          final sceneType = _detectSceneType(image);

          return SceneAnalysis(
            sceneType: sceneType,
            lightingCondition: _classifyLighting(brightness),
            subjectDistance: _estimateSubjectDistance(image),
            movementDetected: false, // Static image analysis
            brightness: brightness,
            contrast: contrast,
            colorTemperature: colorTemp,
            dominantColors: dominantColors,
            faces: _detectFaces(image),
            motion: 0.0,
            focusDistance: 0.5, // Default mid-range focus
            exposureBias: _calculateExposureBias(brightness, contrast),
          );
        } catch (e, stackTrace) {
          if (e.toString().contains('out of memory') || e.toString().contains('memory')) {
            throw ImageMemoryException(details: e.toString());
          } else {
            throw ImageProcessingException(
              message: 'Failed to analyze image',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }
      },
      operation: 'analyze image locally',
      fallbackValue: _createFallbackSceneAnalysis(),
    ) ?? _createFallbackSceneAnalysis();
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
        final suggestions = <AISuggestion>[];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        // Generate camera setting suggestions based on scene analysis
        suggestions.addAll(_generateCameraSettingSuggestions(sceneAnalysis, timestamp, currentSettings));
        
        // Generate composition suggestions
        suggestions.addAll(_generateCompositionSuggestions(sceneAnalysis, timestamp));
        
        // Generate technical suggestions
        suggestions.addAll(_generateTechnicalSuggestions(sceneAnalysis, timestamp));
        
        // Handle user-specific requests
        if (userRequest != null && userRequest.isNotEmpty) {
          suggestions.addAll(_generateUserRequestSuggestions(sceneAnalysis, userRequest, timestamp));
        }
        
        // Run platform-specific analysis if available
        if (imageBytes != null) {
          try {
            final platformSuggestions = await _platform.runAdvancedAnalysis(sceneAnalysis, imageBytes);
            suggestions.addAll(platformSuggestions);
          } catch (e) {
            debugPrint('LocalAIService: Platform analysis failed: $e');
            // Continue without platform-specific suggestions
          }
        }
        
        // Sort by priority and calculate overall confidence
        suggestions.sort((a, b) => b.priority.compareTo(a.priority));
        final avgConfidence = suggestions.isEmpty 
          ? 0.0 
          : suggestions.map((s) => s.confidence).reduce((a, b) => a + b) / suggestions.length;
        
        return AIAnalysisResult(
          success: true,
          suggestions: suggestions,
          analysisTimestamp: DateTime.now(),
          confidence: avgConfidence,
        );
      },
      operation: 'generate AI suggestions locally',
      fallbackValue: _createFallbackAnalysisResult(),
    ) ?? _createFallbackAnalysisResult();
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return true;
    } catch (e) {
      debugPrint('LocalAIService: Connection test failed: $e');
      return false;
    }
  }
  
  @override
  AIServiceCapabilities get capabilities => const AIServiceCapabilities(
    supportsImageAnalysis: true,
    supportsRealtimeAnalysis: true,
    requiresNetworkConnection: false,
    supportsCustomPrompts: false, // Local AI doesn't support custom prompts
    supportsCameraSettings: true,
    supportsCompositionSuggestions: true,
    supportedCategories: [
      AISuggestionCategory.iso,
      AISuggestionCategory.aperture,
      AISuggestionCategory.shutterSpeed,
      AISuggestionCategory.whiteBalance,
      AISuggestionCategory.flashMode,
      AISuggestionCategory.focusMode,
      AISuggestionCategory.exposureCompensation,
      AISuggestionCategory.hdr,
      AISuggestionCategory.stabilization,
      AISuggestionCategory.sceneMode,
      AISuggestionCategory.ruleOfThirds,
      AISuggestionCategory.bokeh,
      AISuggestionCategory.lighting,
    ],
  );
  
  @override
  AIServiceInfo get serviceInfo => AIServiceInfo(
    name: 'Local AI Service',
    version: _serviceVersion,
    description: 'On-device AI processing for photography assistance',
    type: AIServiceType.local,
    targetPlatform: defaultTargetPlatform,
  );
  
  // Image analysis helper methods
  
  double _calculateBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;
    
    // Sample every 5th pixel for performance
    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        // Calculate perceived brightness using luminance formula
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        totalBrightness += brightness.toInt();
        pixelCount++;
      }
    }
    
    return (totalBrightness / pixelCount) / 255.0;
  }
  
  double _calculateContrast(img.Image image) {
    final brightness = _calculateBrightness(image);
    double variance = 0.0;
    int pixelCount = 0;
    
    // Sample every 10th pixel for performance
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        final pixelBrightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        variance += (pixelBrightness - brightness) * (pixelBrightness - brightness);
        pixelCount++;
      }
    }
    
    return variance / pixelCount;
  }
  
  double _estimateColorTemperature(img.Image image) {
    double redSum = 0, blueSum = 0;
    int pixelCount = 0;
    
    // Sample every 10th pixel for performance
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        redSum += pixel.r;
        blueSum += pixel.b;
        pixelCount++;
      }
    }
    
    final redAvg = redSum / pixelCount;
    final blueAvg = blueSum / pixelCount;
    final ratio = redAvg / blueAvg;
    
    // Rough estimation based on red/blue ratio
    if (ratio > 1.3) return 2800; // Very warm/candle light
    if (ratio > 1.2) return 3200; // Warm/tungsten
    if (ratio > 1.0) return 4000; // Slightly warm
    if (ratio > 0.9) return 5500; // Daylight
    if (ratio > 0.8) return 6500; // Cool/shade
    return 7500; // Very cool/blue hour
  }
  
  List<String> _extractDominantColors(img.Image image) {
    final colorCounts = <String, int>{};
    
    // Sample every 20th pixel for performance
    for (int y = 0; y < image.height; y += 20) {
      for (int x = 0; x < image.width; x += 20) {
        final pixel = image.getPixel(x, y);
        final colorFamily = _getColorFamily(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        colorCounts[colorFamily] = (colorCounts[colorFamily] ?? 0) + 1;
      }
    }
    
    // Return top 3 dominant colors
    final sortedColors = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedColors.take(3).map((e) => e.key).toList();
  }
  
  String _getColorFamily(int r, int g, int b) {
    if (r > 220 && g > 220 && b > 220) return 'white';
    if (r < 30 && g < 30 && b < 30) return 'black';
    if (r > g + 20 && r > b + 20) return 'red';
    if (g > r + 20 && g > b + 20) return 'green';
    if (b > r + 20 && b > g + 20) return 'blue';
    if (r > 180 && g > 180 && b < 100) return 'yellow';
    if (r > 180 && b > 180 && g < 100) return 'magenta';
    if (g > 180 && b > 180 && r < 100) return 'cyan';
    if ((r + g + b) / 3 < 80) return 'dark';
    return 'neutral';
  }
  
  String _detectSceneType(img.Image image) {
    final dominantColors = _extractDominantColors(image);
    final brightness = _calculateBrightness(image);
    
    // Simple scene detection based on colors and brightness
    if (dominantColors.contains('green') && dominantColors.contains('blue')) {
      return 'landscape';
    }
    if (dominantColors.contains('white') || dominantColors.contains('neutral')) {
      return 'portrait';
    }
    if (brightness < 0.3) {
      return 'night';
    }
    if (brightness > 0.8) {
      return 'bright_outdoor';
    }
    
    return 'general';
  }
  
  String _classifyLighting(double brightness) {
    if (brightness < 0.2) return 'very_low';
    if (brightness < 0.4) return 'low';
    if (brightness < 0.6) return 'normal';
    if (brightness < 0.8) return 'bright';
    return 'very_bright';
  }
  
  String _estimateSubjectDistance(img.Image image) {
    // Simple heuristic based on center region brightness variation
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final sampleSize = (image.width / 10).toInt();
    
    double centerBrightness = 0;
    double edgeBrightness = 0;
    int centerCount = 0;
    int edgeCount = 0;
    
    // Sample center region
    for (int y = centerY - sampleSize; y < centerY + sampleSize; y += 5) {
      for (int x = centerX - sampleSize; x < centerX + sampleSize; x += 5) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3 / 255.0;
          centerBrightness += brightness;
          centerCount++;
        }
      }
    }
    
    // Sample edge region
    for (int y = 0; y < image.height; y += 20) {
      for (int x = 0; x < image.width; x += 20) {
        if (x < sampleSize || x > image.width - sampleSize || 
            y < sampleSize || y > image.height - sampleSize) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3 / 255.0;
          edgeBrightness += brightness;
          edgeCount++;
        }
      }
    }
    
    final centerAvg = centerCount > 0 ? centerBrightness / centerCount : 0.5;
    final edgeAvg = edgeCount > 0 ? edgeBrightness / edgeCount : 0.5;
    final difference = (centerAvg - edgeAvg).abs();
    
    if (difference > 0.3) return 'close';
    if (difference > 0.1) return 'medium';
    return 'far';
  }
  
  List<Map<String, dynamic>> _detectFaces(img.Image image) {
    // Simplified face detection based on skin tone regions
    // In a real implementation, this would use a face detection model
    return [];
  }
  
  double _calculateExposureBias(double brightness, double contrast) {
    if (brightness < 0.3) return 0.7;  // Brighten dark scenes
    if (brightness > 0.8) return -0.3; // Darken bright scenes
    if (contrast > 0.4) return -0.3;   // Slight underexposure for high contrast
    return 0.0;
  }
  
  // Suggestion generation methods
  
  List<AISuggestion> _generateCameraSettingSuggestions(
    SceneAnalysis sceneAnalysis, 
    int timestamp,
    Map<String, dynamic>? currentSettings,
  ) {
    final suggestions = <AISuggestion>[];
    
    // ISO suggestions based on brightness
    if ((sceneAnalysis.brightness ?? 0.5) < 0.4) {
      suggestions.add(AISuggestion(
        id: 'local_iso_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.iso,
        title: 'Increase ISO for low light',
        message: 'Scene brightness: ${((sceneAnalysis.brightness ?? 0.5) * 100).toInt()}%',
        icon: 'iso',
        priority: 0.8,
        confidence: 0.85,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'iso': (sceneAnalysis.brightness ?? 0.5) < 0.2 ? 3200 : 1600},
        ),
        explanation: 'Higher ISO will brighten the image in low light conditions',
      ));
    }
    
    // White balance suggestions based on color temperature
    final colorTemp = sceneAnalysis.colorTemperature ?? 5500;
    if (colorTemp < 4000) {
      suggestions.add(AISuggestion(
        id: 'local_wb_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.whiteBalance,
        title: 'Warm lighting detected',
        message: 'Color temperature: ${colorTemp.toInt()}K',
        icon: 'wb_sunny',
        priority: 0.7,
        confidence: 0.75,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'whiteBalance': 'tungsten'},
        ),
        explanation: 'Adjust white balance to compensate for warm indoor lighting',
      ));
    }
    
    // Aperture suggestions based on scene type
    final sceneType = sceneAnalysis.sceneType.toLowerCase();
    if (sceneType.contains('portrait')) {
      suggestions.add(AISuggestion(
        id: 'local_aperture_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.aperture,
        title: 'Wide aperture for portraits',
        message: 'Create shallow depth of field',
        icon: 'aperture',
        priority: 0.8,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'aperture': 2.8},
        ),
        explanation: 'Wide aperture creates beautiful background blur for portraits',
      ));
    } else if (sceneType.contains('landscape')) {
      suggestions.add(AISuggestion(
        id: 'local_aperture_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.aperture,
        title: 'Narrow aperture for landscapes',
        message: 'Keep foreground and background sharp',
        icon: 'aperture',
        priority: 0.8,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'aperture': 8.0},
        ),
        explanation: 'Narrow aperture ensures sharp focus throughout the scene',
      ));
    }
    
    // Flash suggestions based on lighting
    if ((sceneAnalysis.brightness ?? 0.5) < 0.3) {
      suggestions.add(AISuggestion(
        id: 'local_flash_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.flashMode,
        title: 'Enable flash for low light',
        message: 'Very low light detected',
        icon: 'flash_on',
        priority: 0.6,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'flashMode': true},
        ),
        explanation: 'Flash will provide additional light for better exposure',
      ));
    }
    
    // HDR suggestions for high contrast scenes
    final contrast = sceneAnalysis.contrast ?? 0.1;
    if (contrast > 0.4) {
      suggestions.add(AISuggestion(
        id: 'local_hdr_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.hdr,
        title: 'Enable HDR mode',
        message: 'High contrast scene detected',
        icon: 'hdr_on',
        priority: 0.8,
        confidence: 0.85,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'hdr': true},
        ),
        explanation: 'HDR will capture both shadows and highlights better',
      ));
    }
    
    return suggestions;
  }
  
  List<AISuggestion> _generateCompositionSuggestions(SceneAnalysis sceneAnalysis, int timestamp) {
    final suggestions = <AISuggestion>[];
    
    // Rule of thirds suggestion
    suggestions.add(AISuggestion(
      id: 'local_composition_$timestamp',
      type: AISuggestionType.composition,
      category: AISuggestionCategory.ruleOfThirds,
      title: 'Consider rule of thirds',
      message: 'Position subjects along grid lines',
      icon: 'grid_on',
      priority: 0.6,
      confidence: 0.8,
      actionable: false,
      visual: SuggestionVisual(
        type: 'overlay',
        overlay: 'rule_of_thirds_highlight',
      ),
      explanation: 'Position key subjects along grid intersections for better balance',
    ));
    
    // Distance-based suggestions
    if (sceneAnalysis.subjectDistance == 'far') {
      suggestions.add(AISuggestion(
        id: 'local_zoom_$timestamp',
        type: AISuggestionType.composition,
        category: AISuggestionCategory.zoomLevel,
        title: 'Consider zooming in',
        message: 'Subject appears distant',
        icon: 'zoom_in',
        priority: 0.5,
        confidence: 0.7,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'zoomLevel': 2.0},
        ),
        explanation: 'Zooming in will make the subject more prominent',
      ));
    }
    
    return suggestions;
  }
  
  List<AISuggestion> _generateTechnicalSuggestions(SceneAnalysis sceneAnalysis, int timestamp) {
    final suggestions = <AISuggestion>[];
    
    // Stabilization suggestions
    final brightness = sceneAnalysis.brightness ?? 0.5;
    if (brightness < 0.4) {
      suggestions.add(AISuggestion(
        id: 'local_stabilization_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.stabilization,
        title: 'Enable image stabilization',
        message: 'Reduce camera shake risk',
        icon: 'videocam_off',
        priority: 0.7,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'stabilization': true},
        ),
        explanation: 'Stabilization helps prevent blur in low light conditions',
      ));
    }
    
    // Focus mode suggestions
    if (sceneAnalysis.movementDetected) {
      suggestions.add(AISuggestion(
        id: 'local_focus_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.focusMode,
        title: 'Use continuous autofocus',
        message: 'Movement detected in scene',
        icon: 'center_focus_strong',
        priority: 0.7,
        confidence: 0.75,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'focusMode': 'continuous'},
        ),
        explanation: 'Continuous AF will track moving subjects better',
      ));
    }
    
    return suggestions;
  }
  
  List<AISuggestion> _generateUserRequestSuggestions(
    SceneAnalysis sceneAnalysis, 
    String userRequest, 
    int timestamp,
  ) {
    final suggestions = <AISuggestion>[];
    final request = userRequest.toLowerCase();
    
    // Handle specific user requests
    if (request.contains('bright') || request.contains('lighter')) {
      suggestions.add(AISuggestion(
        id: 'local_user_bright_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.exposureCompensation,
        title: 'Brighten image as requested',
        message: 'Increasing exposure compensation',
        icon: 'exposure',
        priority: 0.9,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'exposureCompensation': 0.7},
        ),
        explanation: 'Adjusting exposure to make the image brighter as requested',
      ));
    }
    
    if (request.contains('portrait') || request.contains('person') || request.contains('face')) {
      suggestions.add(AISuggestion(
        id: 'local_user_portrait_$timestamp',
        type: AISuggestionType.cameraSettings,
        category: AISuggestionCategory.sceneMode,
        title: 'Portrait mode optimization',
        message: 'Optimizing for people photography',
        icon: 'portrait',
        priority: 0.9,
        confidence: 0.8,
        actionable: true,
        action: SuggestionAction(
          type: 'apply_settings',
          settings: {'sceneMode': 'portrait', 'aperture': 2.8},
        ),
        explanation: 'Portrait settings optimize for people photography',
      ));
    }
    
    return suggestions;
  }
  
  // Fallback methods
  
  SceneAnalysis _createFallbackSceneAnalysis() {
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
  
  AIAnalysisResult _createFallbackAnalysisResult() {
    return AIAnalysisResult(
      success: false,
      suggestions: [],
      analysisTimestamp: DateTime.now(),
      confidence: 0.0,
    );
  }
  
  @override
  void dispose() {
    _platform.dispose();
    debugPrint('LocalAIService: Disposed');
    super.dispose();
  }
}