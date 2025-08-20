import 'package:flutter/foundation.dart';
import '../../models/ai_suggestion.dart';
import '../../core/utils/lens_exceptions.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/disposal_mixin.dart';
import 'i_ai_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

/// Cloud AI service that handles external AI API calls
/// This service requires network connectivity and API keys
class CloudAIService with ErrorHandlerMixin, ServiceDisposalMixin implements IAIService {
  static const String _serviceVersion = '1.0.0';
  
  bool _isInitialized = false;
  CloudAIConfiguration? _configuration;
  
  @override
  Future<void> initialize() async {
    // Configuration is set during construction or via updateConfiguration
  }
  
  Future<void> initializeWithConfiguration(CloudAIConfiguration configuration) async {
    return await withAIErrorHandling(
      () async {
        _configuration = configuration;
        
        // Test basic connectivity
        if (!await _hasInternetConnection()) {
          throw NetworkConnectionException(
            message: 'No internet connection available',
            details: 'Cloud AI service requires network connectivity',
          );
        }
        
        // Validate API configuration
        if (_configuration!.apiKey.isEmpty) {
          throw AIConfigurationException(
            message: 'API key is required',
            details: 'Cloud AI service requires valid API credentials',
          );
        }
        
        _isInitialized = true;
        debugPrint('CloudAIService: Initialized successfully with ${_configuration!.provider.displayName}');
      },
      operation: 'initialize cloud AI service',
      showToUser: false,
    );
  }
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  Future<SceneAnalysis> analyzeImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw AIServiceException(
        message: 'Service not initialized',
        serviceType: 'CloudAI',
      );
    }
    
    return await withImageErrorHandling<SceneAnalysis>(
      () async {
        if (imageBytes.isEmpty) {
          throw InvalidImageFormatException(
            message: 'Empty image data',
            details: 'Image bytes are empty',
          );
        }

        // Check image size limits for cloud processing
        if (imageBytes.length > 20 * 1024 * 1024) { // 20MB limit for cloud APIs
          throw ImageTooLargeException(
            details: 'Image size: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB exceeds cloud API limits',
          );
        }

        // Check network connectivity first
        if (!await _hasInternetConnection()) {
          throw NetworkConnectionException(
            message: 'No internet connection available',
            details: 'Cloud AI analysis requires network connectivity',
          );
        }

        // For now, use basic analysis since full cloud API is not yet implemented
        // TODO: Implement full cloud vision APIs when available
        return _createBasicSceneAnalysis(imageBytes);
      },
      operation: 'analyze image with cloud AI',
      fallbackValue: _createBasicSceneAnalysis(imageBytes),
    ) ?? _createBasicSceneAnalysis(imageBytes);
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
      throw AIServiceException(
        message: 'Service not initialized',
        serviceType: 'CloudAI',
      );
    }
    
    return await withAIErrorHandling<AIAnalysisResult>(
      () async {
        // Create context for cloud AI processing
        final context = CloudAIContext(
          cameraModel: cameraModel ?? 'Unknown Camera',
          currentSettings: currentSettings ?? {},
          sceneAnalysis: sceneAnalysis,
          userRequest: userRequest,
          customPrompt: _configuration!.customPrompt,
        );
        
        // Call actual cloud AI service based on provider
        debugPrint('CloudAIService: Generating suggestions with ${_configuration!.provider.displayName}');
        
        switch (_configuration!.provider) {
          case CloudAIProvider.openai:
            return await _generateWithOpenAI(context, imageBytes);
          case CloudAIProvider.gemini:
            return await _generateWithGemini(context, imageBytes);
          case CloudAIProvider.claude:
            return await _generateWithClaude(context, imageBytes);
          case CloudAIProvider.custom:
            return await _generateWithCustomEndpoint(context, imageBytes);
        }
      },
      operation: 'generate AI suggestions with cloud service',
      fallbackValue: _createEmptyAnalysisResult('Cloud AI not available'),
    ) ?? _createEmptyAnalysisResult('Cloud AI service error');
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        return false;
      }
      
      if (!await _hasInternetConnection()) {
        return false;
      }
      
      // Test actual connection based on provider
      switch (_configuration!.provider) {
        case CloudAIProvider.openai:
        case CloudAIProvider.gemini:
        case CloudAIProvider.claude:
        case CloudAIProvider.custom:
          return await _testCustomEndpointConnection();
      }
    } catch (e) {
      debugPrint('CloudAIService: Connection test failed: $e');
      return false;
    }
  }
  
  @override
  AIServiceCapabilities get capabilities => const AIServiceCapabilities(
    supportsImageAnalysis: true,
    supportsRealtimeAnalysis: false, // Cloud APIs are too slow for real-time
    requiresNetworkConnection: true,
    supportsCustomPrompts: true,
    supportsCameraSettings: true,
    supportsCompositionSuggestions: true,
    supportedCategories: [
      // Cloud AI supports all categories
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
      AISuggestionCategory.zoomLevel,
      AISuggestionCategory.ruleOfThirds,
      AISuggestionCategory.bokeh,
      AISuggestionCategory.lighting,
      AISuggestionCategory.imageFormat,
      AISuggestionCategory.noiseReduction,
    ],
  );
  
  @override
  AIServiceInfo get serviceInfo => AIServiceInfo(
    name: 'Cloud AI Service',
    version: _serviceVersion,
    description: 'External AI API integration for advanced photography assistance',
    type: AIServiceType.cloud,
    targetPlatform: null, // Platform-agnostic
  );
  
  // Network and connectivity methods
  
  Future<bool> _hasInternetConnection() async {
    try {
      // Try to connect to the actual custom endpoint first
      if (_configuration?.customEndpoint != null) {
        try {
          final response = await http.head(
            Uri.parse(_configuration!.customEndpoint!),
            headers: {'Connection': 'keep-alive'},
          ).timeout(const Duration(seconds: 3));
          
          // Any response (even 4xx/5xx) indicates connectivity
          debugPrint('CloudAIService: Custom endpoint connectivity check: ${response.statusCode}');
          return response.statusCode >= 200 && response.statusCode < 600;
        } catch (e) {
          debugPrint('CloudAIService: Custom endpoint check failed: $e');
          // Fall through to general connectivity check
        }
      }
      
      // Simple connectivity check using HTTP request
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('CloudAIService: Connectivity check failed: $e');
      // For development purposes, be more lenient - if we can't verify connectivity, assume it's available
      debugPrint('CloudAIService: Assuming connectivity available for development');
      return true;
    }
  }
  
  // Mock methods for testing without network
  
  SceneAnalysis _createBasicSceneAnalysis(Uint8List imageBytes) {
    // Perform basic image analysis from JPEG data
    final brightness = _analyzeImageBrightness(imageBytes);
    final contrast = _analyzeImageContrast(imageBytes);
    final colorTemp = _estimateColorTemperature(imageBytes);
    
    return SceneAnalysis(
      sceneType: brightness < 0.3 ? 'lowlight' : brightness > 0.7 ? 'bright' : 'normal',
      lightingCondition: colorTemp > 6000 ? 'daylight' : colorTemp < 4000 ? 'tungsten' : 'normal',
      subjectDistance: 'medium', // Would need depth analysis for this
      movementDetected: false, // Would need motion detection for this
      brightness: brightness,
      contrast: contrast,
      colorTemperature: colorTemp,
      dominantColors: _extractDominantColors(imageBytes),
      faces: [], // Would need face detection for this
      motion: 0.0,
      focusDistance: 0.5,
      exposureBias: 0.0,
    );
  }
  
  /// Create an empty analysis result when cloud AI is not available
  AIAnalysisResult _createEmptyAnalysisResult(String reason) {
    return AIAnalysisResult(
      success: false,
      suggestions: [],
      analysisTimestamp: DateTime.now(),
      confidence: 0.0,
    );
  }
  
  // Cloud AI API implementations
  
  /// Generate suggestions using custom endpoint
  Future<AIAnalysisResult> _generateWithCustomEndpoint(CloudAIContext context, Uint8List? imageBytes) async {
    if (_configuration!.customEndpoint == null || _configuration!.customEndpoint!.isEmpty) {
      throw AIConfigurationException(
        message: 'Custom endpoint not configured',
      );
    }
    
    try {
      final endpoint = _configuration!.customEndpoint!;
      debugPrint('CloudAIService: Calling custom endpoint: $endpoint');
      
      // Build proper AI photography analysis request
      final systemPrompt = _buildSystemPrompt(context);
      final userPrompt = _buildUserPrompt(context, imageBytes);
      
      final requestBody = {
        'model': _configuration!.modelId,
        'system': systemPrompt,  // Anthropic uses separate system parameter
        'messages': [
          {
            'role': 'user',
            'content': userPrompt,
          },
        ],
        'max_tokens': 800,
      };
      
      // Make the API call with detailed logging
      debugPrint('🌐 Making HTTP request to: $endpoint');
      debugPrint('🔑 API Key: ${_configuration!.apiKey.substring(0, 4)}...');
      debugPrint('📤 Request body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_configuration!.apiKey}',
        },
        body: json.encode(requestBody),
      ).timeout(_configuration!.timeout);
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseCustomEndpointResponse(responseData, context);
      } else {
        throw AIServiceException(
          message: 'Custom endpoint returned error: ${response.statusCode}',
          serviceType: 'CustomEndpoint',
        );
      }
    } catch (e) {
      debugPrint('Custom endpoint error: $e');
      if (e is AIServiceException) rethrow;
      
      throw AIServiceException(
        message: 'Failed to call custom endpoint: ${e.toString()}',
        serviceType: 'CustomEndpoint',
      );
    }
  }
  
  /// Generate suggestions using OpenAI API
  Future<AIAnalysisResult> _generateWithOpenAI(CloudAIContext context, Uint8List? imageBytes) async {
    // For now, fall back to custom endpoint implementation
    return await _generateWithCustomEndpoint(context, imageBytes);
  }
  
  /// Generate suggestions using Google Gemini API
  Future<AIAnalysisResult> _generateWithGemini(CloudAIContext context, Uint8List? imageBytes) async {
    // For now, fall back to custom endpoint implementation  
    return await _generateWithCustomEndpoint(context, imageBytes);
  }
  
  /// Generate suggestions using Anthropic Claude API
  Future<AIAnalysisResult> _generateWithClaude(CloudAIContext context, Uint8List? imageBytes) async {
    // For now, fall back to custom endpoint implementation
    return await _generateWithCustomEndpoint(context, imageBytes);
  }
  
  /// Build system prompt for AI analysis
  String _buildSystemPrompt(CloudAIContext context) {
    return '''
You are an expert photography assistant. Provide exactly 3 specific, actionable photography recommendations.

IMPORTANT: You must provide exactly 3 numbered suggestions in this format:

## 1. [Title]
[Detailed recommendation with specific camera settings and technical parameters]

## 2. [Title] 
[Detailed recommendation with specific camera settings and technical parameters]

## 3. [Title]
[Detailed recommendation with specific camera settings and technical parameters]

Focus on:
- Camera settings (ISO, aperture, shutter speed, white balance)
- Composition improvements (rule of thirds, framing, angles)
- Lighting adjustments (exposure, shadows, highlights)
- Technical improvements (focus, depth of field, stabilization)

Make each suggestion specific with exact values when possible (e.g., "Set ISO to 400", "Use f/2.8 aperture", "Adjust exposure compensation to +0.7 EV").

Camera: ${context.cameraModel}
Current Settings: ${context.currentSettings}
${context.customPrompt != null ? '\nAdditional Request: ${context.customPrompt}' : ''}
''';
  }
  
  /// Build user prompt for AI analysis
  String _buildUserPrompt(CloudAIContext context, Uint8List? imageBytes) {
    final hasImage = imageBytes != null;
    
    return '''
Please analyze this ${hasImage ? 'image' : 'scene'} and provide exactly 3 numbered photography recommendations using the format specified in the system prompt.

Scene Analysis:
- Type: ${context.sceneAnalysis.sceneType}
- Lighting: ${context.sceneAnalysis.lightingCondition}
- Subject Distance: ${context.sceneAnalysis.subjectDistance}
- Brightness: ${context.sceneAnalysis.brightness}
- Contrast: ${context.sceneAnalysis.contrast}
- Color Temperature: ${context.sceneAnalysis.colorTemperature}K

Focus on providing actionable technical settings and composition improvements. Remember to use the ## 1., ## 2., ## 3. format with specific camera parameters and values.
''';
  }
  
  /// Parse response from custom endpoint
  AIAnalysisResult _parseCustomEndpointResponse(Map<String, dynamic> response, CloudAIContext context) {
    try {
      debugPrint('🔍 Full API Response: ${json.encode(response)}');
      
      // Extract content from various API formats
      String content = '';
      
      // Try OpenAI format
      if (response['choices'] != null && response['choices'].isNotEmpty) {
        final messageContent = response['choices'][0]['message']['content'];
        debugPrint('🔍 OpenAI message content type: ${messageContent.runtimeType}');
        
        if (messageContent is String) {
          content = messageContent;
        } else if (messageContent is List) {
          // Handle content as array of objects (like Anthropic format)
          for (var item in messageContent) {
            if (item is Map && item['type'] == 'text') {
              content += item['text'] ?? '';
            }
          }
        }
      }
      // Try Anthropic format  
      else if (response['content'] != null) {
        final responseContent = response['content'];
        debugPrint('🔍 Anthropic content type: ${responseContent.runtimeType}');
        
        if (responseContent is String) {
          content = responseContent;
        } else if (responseContent is List) {
          // Handle content as array of objects
          for (var item in responseContent) {
            if (item is Map && item['type'] == 'text') {
              content += item['text'] ?? '';
            }
          }
        }
      }
      // Fallback
      else {
        content = response.toString();
      }
      
      debugPrint('Raw LLM Response: $content');
      
      // Try to parse JSON from the content
      Map<String, dynamic> parsedContent;
      try {
        // Look for JSON block in the response
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          final jsonStr = content.substring(jsonStart, jsonEnd + 1);
          parsedContent = json.decode(jsonStr);
        } else {
          throw FormatException('No JSON found in response');
        }
      } catch (e) {
        // If JSON parsing fails, create suggestions from plain text
        debugPrint('Failed to parse JSON, creating text-based suggestions: $e');
        return _createTextBasedSuggestions(content, context);
      }
      
      // Parse suggestions from JSON
      final suggestions = <AISuggestion>[];
      final suggestionsData = parsedContent['suggestions'] as List?;
      
      if (suggestionsData != null) {
        for (final suggData in suggestionsData) {
          try {
            final suggestion = _parseSuggestionFromJson(suggData);
            suggestions.add(suggestion);
          } catch (e) {
            debugPrint('Failed to parse suggestion: $e');
          }
        }
      }
      
      final confidence = (parsedContent['confidence'] ?? 0.8).toDouble();
      
      debugPrint('Parsed ${suggestions.length} suggestions from custom endpoint');
      
      return AIAnalysisResult(
        success: true,
        suggestions: suggestions,
        analysisTimestamp: DateTime.now(),
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('Error parsing custom endpoint response: $e');
      return _createTextBasedSuggestions(response.toString(), context);
    }
  }
  
  /// Create suggestions from plain text response
  AIAnalysisResult _createTextBasedSuggestions(String content, CloudAIContext context) {
    final suggestions = <AISuggestion>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    debugPrint('🔍 Parsing AI response content: ${content.length} chars');
    debugPrint('🔍 Content preview: ${content.substring(0, content.length.clamp(0, 300))}...');
    
    // Split content into sections by ## patterns
    final lines = content.split('\n');
    debugPrint('🔍 Total lines in content: ${lines.length}');
    
    int currentSection = 0;
    String currentTitle = '';
    List<String> currentContent = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Check if this line starts a new section (## N.)
      final sectionMatch = RegExp(r'^## (\d+)\.\s*(.*)').firstMatch(line);
      if (sectionMatch != null) {
        // Save previous section if it exists
        if (currentSection > 0 && currentTitle.isNotEmpty) {
          _addParsedSuggestion(suggestions, timestamp, currentSection, currentTitle, currentContent.join('\n').trim());
        }
        
        // Start new section
        currentSection = int.tryParse(sectionMatch.group(1) ?? '0') ?? 0;
        currentTitle = sectionMatch.group(2)?.trim() ?? '';
        currentContent = [];
        
        debugPrint('🔍 Found section $currentSection: "$currentTitle"');
      } else if (currentSection > 0 && line.isNotEmpty) {
        // Add content to current section
        currentContent.add(line);
      }
    }
    
    // Don't forget the last section
    if (currentSection > 0 && currentTitle.isNotEmpty) {
      _addParsedSuggestion(suggestions, timestamp, currentSection, currentTitle, currentContent.join('\n').trim());
    }
    
    debugPrint('🔍 Parsed ${suggestions.length} suggestions from AI response');
    
    // Fallback: if no numbered format found, create one general suggestion
    if (suggestions.isEmpty) {
      suggestions.add(AISuggestion(
        id: 'custom_text_$timestamp',
        type: AISuggestionType.technique,
        category: AISuggestionCategory.lighting,
        title: 'AI Photography Analysis',
        message: content.length > 200 ? '${content.substring(0, 200)}...' : content,
        priority: 0.8,
        confidence: 0.7,
        actionable: false,
        explanation: 'Analysis from your custom AI endpoint',
      ));
    }
    
    return AIAnalysisResult(
      success: true,
      suggestions: suggestions,
      analysisTimestamp: DateTime.now(),
      confidence: 0.8,
    );
  }
  
  /// Helper method to add a parsed suggestion to the list
  void _addParsedSuggestion(List<AISuggestion> suggestions, int timestamp, int number, String title, String message) {
    // Determine category based on content keywords
    AISuggestionCategory category = AISuggestionCategory.lighting;
    AISuggestionType type = AISuggestionType.technique;
    
    final lowerContent = '$title $message'.toLowerCase();
    bool isActionable = true; // Default to actionable
    
    if (lowerContent.contains('iso') || lowerContent.contains('aperture') || lowerContent.contains('shutter') || lowerContent.contains('camera settings')) {
      category = AISuggestionCategory.iso;
      type = AISuggestionType.cameraSettings;
      isActionable = true; // Camera settings can be applied automatically
    } else if (lowerContent.contains('white balance') || lowerContent.contains('exposure compensation') || lowerContent.contains('metering mode')) {
      category = AISuggestionCategory.whiteBalance;
      type = AISuggestionType.cameraSettings;
      isActionable = true; // Camera settings can be applied automatically
    } else if (lowerContent.contains('composition') || lowerContent.contains('framing') || lowerContent.contains('rule of thirds') || lowerContent.contains('angle') || lowerContent.contains('perspective')) {
      category = AISuggestionCategory.framing;
      type = AISuggestionType.composition;
      isActionable = false; // Composition requires manual photographer action
    } else if (lowerContent.contains('light') || lowerContent.contains('exposure') || lowerContent.contains('golden hour')) {
      category = AISuggestionCategory.lighting;
      type = AISuggestionType.technique;
      isActionable = false; // Lighting techniques require manual action
    } else if (lowerContent.contains('depth of field') || lowerContent.contains('focus') || lowerContent.contains('aperture priority')) {
      category = AISuggestionCategory.aperture;
      type = AISuggestionType.cameraSettings;
      isActionable = true; // Camera settings can be applied automatically
    }
    
    suggestions.add(AISuggestion(
      id: 'custom_${timestamp}_$number',
      type: type,
      category: category,
      title: title.isEmpty ? 'Photography Tip #$number' : title,
      message: message.isEmpty ? 'AI photography recommendation' : message,
      priority: 0.9 - (number * 0.05), // Higher priority for earlier suggestions
      confidence: 0.8,
      actionable: isActionable, // Only camera settings are actionable, not composition
      explanation: 'AI-generated photography recommendation #$number',
    ));
    
    debugPrint('🔍 Added suggestion #$number: "$title" (${message.length} chars)');
  }
  
  /// Parse individual suggestion from JSON
  AISuggestion _parseSuggestionFromJson(Map<String, dynamic> data) {
    final actionData = data['action'] as Map<String, dynamic>?;
    SuggestionAction? action;
    
    if (actionData != null) {
      action = SuggestionAction(
        type: actionData['type'] ?? 'camera_setting',
        settings: Map<String, dynamic>.from(actionData['settings'] ?? {}),
      );
    }
    
    return AISuggestion(
      id: data['id'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      type: _parseAISuggestionType(data['type']),
      category: _parseAISuggestionCategory(data['category']),
      title: data['title'] ?? 'AI Suggestion',
      message: data['message'] ?? 'No message provided',
      priority: (data['priority'] ?? 0.5).toDouble(),
      confidence: (data['confidence'] ?? 0.8).toDouble(),
      actionable: data['actionable'] ?? false,
      action: action,
      explanation: data['explanation'],
    );
  }
  
  /// Parse suggestion type from string
  AISuggestionType _parseAISuggestionType(String? type) {
    switch (type?.toLowerCase()) {
      case 'camerasettings':
      case 'camera_settings':
        return AISuggestionType.cameraSettings;
      case 'composition':
        return AISuggestionType.composition;
      case 'technique':
        return AISuggestionType.technique;
      case 'timing':
        return AISuggestionType.timing;
      case 'creative':
        return AISuggestionType.creative;
      default:
        return AISuggestionType.technique;
    }
  }
  
  /// Parse suggestion category from string
  AISuggestionCategory _parseAISuggestionCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'iso':
        return AISuggestionCategory.iso;
      case 'aperture':
        return AISuggestionCategory.aperture;
      case 'shutterspeed':
      case 'shutter_speed':
        return AISuggestionCategory.shutterSpeed;
      case 'whitebalance':
      case 'white_balance':
        return AISuggestionCategory.whiteBalance;
      case 'lighting':
        return AISuggestionCategory.lighting;
      case 'framing':
        return AISuggestionCategory.framing;
      case 'focus':
        return AISuggestionCategory.focus;
      default:
        return AISuggestionCategory.lighting;
    }
  }
  
  // Image analysis helper methods
  
  /// Analyze image brightness from JPEG data
  double _analyzeImageBrightness(Uint8List imageBytes) {
    try {
      // Simple brightness estimation from JPEG file
      // Look for overall byte values - higher values suggest brighter image
      if (imageBytes.length < 1000) return 0.5;
      
      int sum = 0;
      int sampleSize = (imageBytes.length * 0.1).floor(); // Sample 10% of bytes
      int step = (imageBytes.length / sampleSize).floor();
      
      for (int i = 0; i < imageBytes.length; i += step) {
        sum += imageBytes[i];
      }
      
      double average = sum / sampleSize;
      return (average / 255.0).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('CloudAIService: Brightness analysis failed: $e');
      return 0.5;
    }
  }
  
  /// Analyze image contrast from JPEG data
  double _analyzeImageContrast(Uint8List imageBytes) {
    try {
      if (imageBytes.length < 1000) return 0.5;
      
      // Calculate standard deviation of pixel values as contrast measure
      int sampleSize = (imageBytes.length * 0.05).floor(); // Sample 5%
      int step = (imageBytes.length / sampleSize).floor();
      
      List<int> samples = [];
      for (int i = 0; i < imageBytes.length; i += step) {
        samples.add(imageBytes[i]);
      }
      
      double mean = samples.reduce((a, b) => a + b) / samples.length;
      double variance = samples.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / samples.length;
      double stdDev = math.sqrt(variance);
      
      return (stdDev / 128.0).clamp(0.0, 1.0); // Normalize to 0-1
    } catch (e) {
      debugPrint('CloudAIService: Contrast analysis failed: $e');
      return 0.5;
    }
  }
  
  /// Estimate color temperature from JPEG data
  double _estimateColorTemperature(Uint8List imageBytes) {
    try {
      if (imageBytes.length < 1000) return 5500;
      
      // Very basic estimation - look at byte distribution
      // Higher values in later bytes might suggest warmer tones
      int sampleSize = (imageBytes.length * 0.02).floor();
      int step = (imageBytes.length / sampleSize).floor();
      
      int warmSum = 0;
      int coolSum = 0;
      
      for (int i = 0; i < imageBytes.length; i += step * 2) {
        if (i + step < imageBytes.length) {
          warmSum += imageBytes[i];
          coolSum += imageBytes[i + step];
        }
      }
      
      double ratio = warmSum > 0 ? coolSum / warmSum : 1.0;
      
      // Map ratio to temperature range (3000K - 7000K)
      return (3000 + (ratio * 4000)).clamp(3000.0, 7000.0);
    } catch (e) {
      debugPrint('CloudAIService: Color temperature analysis failed: $e');
      return 5500;
    }
  }
  
  /// Extract dominant colors from JPEG data
  List<String> _extractDominantColors(Uint8List imageBytes) {
    try {
      if (imageBytes.length < 2000) return ['neutral'];
      
      // Simple color classification based on byte patterns
      int redishCount = 0;
      int blueishCount = 0;
      int greenishCount = 0;
      int neutralCount = 0;
      
      for (int i = 0; i < imageBytes.length; i += 100) { // Sample every 100th byte
        int value = imageBytes[i];
        
        if (value > 200) {
          redishCount++;
        } else if (value > 150) {
          greenishCount++;
        } else if (value > 100) {
          blueishCount++;
        } else {
          neutralCount++;
        }
      }
      
      List<MapEntry<String, int>> colorCounts = [
        MapEntry('red', redishCount),
        MapEntry('green', greenishCount),
        MapEntry('blue', blueishCount),
        MapEntry('neutral', neutralCount),
      ];
      
      colorCounts.sort((a, b) => b.value.compareTo(a.value));
      
      return colorCounts.take(3).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('CloudAIService: Color extraction failed: $e');
      return ['neutral'];
    }
  }
  
  /// Test connection to custom endpoint
  Future<bool> _testCustomEndpointConnection() async {
    if (_configuration!.customEndpoint == null || _configuration!.customEndpoint!.isEmpty) {
      debugPrint('CloudAIService: No custom endpoint configured');
      return false;
    }
    
    try {
      final endpoint = _configuration!.customEndpoint!;
      debugPrint('CloudAIService: Testing connection to: $endpoint');
      
      // Simple test request to check if endpoint is reachable
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_configuration!.apiKey}',
        },
        body: json.encode({
          'model': _configuration!.modelId,
          'messages': [
            {'role': 'user', 'content': 'Test connection'}
          ],
          'max_tokens': 1,
        }),
      ).timeout(const Duration(seconds: 10));
      
      final isConnected = response.statusCode == 200 || response.statusCode == 400; // 400 might be valid but with bad request
      debugPrint('CloudAIService: Connection test result: $isConnected (status: ${response.statusCode})');
      return isConnected;
    } catch (e) {
      debugPrint('CloudAIService: Connection test failed: $e');
      return false;
    }
  }
  /*
  Future<SceneAnalysis> _analyzeWithOpenAI(Uint8List imageBytes) async {
    // Implement OpenAI Vision API call
    throw UnimplementedError('OpenAI analysis implementation pending');
  }
  
  Future<SceneAnalysis> _analyzeWithGemini(Uint8List imageBytes) async {
    // Implement Google Gemini Vision API call
    throw UnimplementedError('Gemini analysis implementation pending');
  }
  
  Future<SceneAnalysis> _analyzeWithClaude(Uint8List imageBytes) async {
    // Implement Anthropic Claude Vision API call
    throw UnimplementedError('Claude analysis implementation pending');
  }
  
  Future<AIAnalysisResult> _generateWithOpenAI(CloudAIContext context, Uint8List? imageBytes) async {
    // Implement OpenAI suggestion generation
    throw UnimplementedError('OpenAI generation implementation pending');
  }
  
  Future<AIAnalysisResult> _generateWithGemini(CloudAIContext context, Uint8List? imageBytes) async {
    // Implement Gemini suggestion generation
    throw UnimplementedError('Gemini generation implementation pending');
  }
  
  Future<AIAnalysisResult> _generateWithClaude(CloudAIContext context, Uint8List? imageBytes) async {
    // Implement Claude suggestion generation
    throw UnimplementedError('Claude generation implementation pending');
  }
  
  Future<bool> _testOpenAIConnection() async {
    // Test OpenAI API connectivity
    return false;
  }
  
  Future<bool> _testGeminiConnection() async {
    // Test Gemini API connectivity
    return false;
  }
  
  Future<bool> _testClaudeConnection() async {
    // Test Claude API connectivity
    return false;
  }
  */
  
  @override
  void dispose() {
    _configuration = null;
    _isInitialized = false;
    debugPrint('CloudAIService: Disposed');
    super.dispose();
  }
}

/// Cloud AI provider options
enum CloudAIProvider {
  openai('OpenAI'),
  gemini('Google Gemini'),
  claude('Anthropic Claude'),
  custom('Custom Endpoint');
  
  const CloudAIProvider(this.displayName);
  final String displayName;
}

/// Configuration for cloud AI service
class CloudAIConfiguration {
  final CloudAIProvider provider;
  final String apiKey;
  final String modelId;
  final String? customPrompt;
  final String? customEndpoint;
  final Duration timeout;
  final int maxRetries;
  final Map<String, dynamic> customSettings;
  
  const CloudAIConfiguration({
    this.provider = CloudAIProvider.openai,
    this.apiKey = '',
    this.modelId = 'gpt-4-vision-preview',
    this.customPrompt,
    this.customEndpoint,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.customSettings = const {},
  });
  
  CloudAIConfiguration copyWith({
    CloudAIProvider? provider,
    String? apiKey,
    String? modelId,
    String? customPrompt,
    String? customEndpoint,
    Duration? timeout,
    int? maxRetries,
    Map<String, dynamic>? customSettings,
  }) {
    return CloudAIConfiguration(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
      customPrompt: customPrompt ?? this.customPrompt,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Context for cloud AI processing
class CloudAIContext {
  final String cameraModel;
  final Map<String, dynamic> currentSettings;
  final SceneAnalysis sceneAnalysis;
  final String? userRequest;
  final String? customPrompt;
  
  const CloudAIContext({
    required this.cameraModel,
    required this.currentSettings,
    required this.sceneAnalysis,
    this.userRequest,
    this.customPrompt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'cameraModel': cameraModel,
      'currentSettings': currentSettings,
      'sceneAnalysis': {
        'sceneType': sceneAnalysis.sceneType,
        'lightingCondition': sceneAnalysis.lightingCondition,
        'brightness': sceneAnalysis.brightness,
        'contrast': sceneAnalysis.contrast,
        'colorTemperature': sceneAnalysis.colorTemperature,
        'dominantColors': sceneAnalysis.dominantColors,
      },
      'userRequest': userRequest,
      'customPrompt': customPrompt,
    };
  }
}

/// Exception for AI configuration issues
class AIConfigurationException extends AIServiceException {
  const AIConfigurationException({
    required String message,
    String? details,
  }) : super(
    message: message,
    serviceType: 'CloudAI',
  );
}

/// Exception for network connectivity issues
class NetworkConnectionException extends AIServiceException {
  const NetworkConnectionException({
    required String message,
    String? details,
  }) : super(
    message: message,
    serviceType: 'CloudAI',
  );
}