# AI Service Architecture Documentation

This document describes the consolidated AI service architecture implemented for the Lens AI mobile photography app.

## Overview

The new architecture consolidates 12+ overlapping AI services into a focused, non-overlapping implementation with clear responsibilities and intelligent orchestration.

## Architecture Components

### 1. IAIService (Base Interface)
**Location:** `lib/services/ai/i_ai_service.dart`

Defines the core contract that all AI implementations must follow:
- `initialize()` - Initialize the AI service
- `analyzeImage()` - Analyze an image and return scene analysis
- `generateSuggestions()` - Generate AI suggestions based on scene analysis
- `testConnection()` - Test if the service is available
- Service capabilities and information

### 2. LocalAIService (On-Device Processing)
**Location:** `lib/services/ai/local_ai_service.dart`

Handles all on-device AI processing:
- **Platform-optimized:** Different processing delays for iOS/Android/Web/Desktop
- **Offline capable:** No network dependencies
- **Real-time analysis:** Fast processing for live camera feed
- **Image analysis:** Brightness, contrast, color temperature, dominant colors
- **Scene classification:** Portrait, landscape, night, architectural, general
- **Smart suggestions:** ISO, aperture, white balance, flash, HDR, stabilization
- **User request handling:** Adapts suggestions based on user input

#### Key Features:
- Platform-specific optimizations (iOS Night mode, Android Pro mode, Web limitations)
- Comprehensive image analysis without external APIs
- Scene-aware suggestion generation
- Configuration-based filtering (categories, confidence, count limits)
- Robust error handling with fallbacks

### 3. CloudAIService (External API Integration)
**Location:** `lib/services/ai/cloud_ai_service.dart`

Handles external AI API calls for advanced analysis:
- **Multi-provider support:** OpenAI, Google Gemini, Anthropic Claude
- **Custom prompts:** Full support for user-defined analysis prompts
- **Advanced analysis:** Leverages powerful cloud AI models
- **Configuration-driven:** API keys, models, timeouts, retry logic
- **Graceful degradation:** Proper fallback when network unavailable

#### Supported Providers:
- **OpenAI:** GPT-4 Vision, GPT-4o, GPT-4o Mini
- **Google Gemini:** Gemini 1.5 Pro, Gemini 1.5 Flash, Gemini Pro Vision
- **Anthropic Claude:** Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku

### 4. AICoordinator (Intelligent Orchestration)
**Location:** `lib/services/ai/cloud_ai_service.dart`

Main coordinator that orchestrates AI services and provides intelligent service selection:
- **Single entry point:** All AI operations go through the coordinator
- **Strategy-based selection:** Multiple service selection strategies
- **Hybrid processing:** Can combine local and cloud results
- **Intelligent fallback:** Automatic fallback between services
- **Performance optimization:** Concurrent processing where appropriate

#### Service Selection Strategies:
- **Local First:** Try local service first, fallback to cloud if needed
- **Cloud First:** Try cloud service first, fallback to local if needed
- **Hybrid:** Run both services concurrently and merge results
- **Local Only:** Use only local processing (offline mode)
- **Cloud Only:** Use only cloud processing (when available)

## Platform Implementations

### Platform Abstraction Layer
**Location:** `lib/services/ai/platforms/`

- `ai_platform_stub.dart` - Abstract interface
- `ai_platform_mobile.dart` - Mobile-specific implementation (TensorFlow Lite)
- `ai_platform_web.dart` - Web-specific implementation (JavaScript ML)

## Usage Examples

### Basic Usage (Recommended)
```dart
// Initialize coordinator with default settings
final coordinator = AICoordinator();
await coordinator.initialize();

// Analyze image
final sceneAnalysis = await coordinator.analyzeImage(imageBytes);

// Generate suggestions
final result = await coordinator.generateSuggestions(
  sceneAnalysis: sceneAnalysis,
  cameraModel: 'iPhone 15 Pro',
  currentSettings: {'iso': 400, 'aperture': 2.8},
  userRequest: 'Better portrait photography',
);
```

### Advanced Configuration
```dart
// Configure cloud AI
final cloudConfig = CloudAIConfiguration(
  provider: CloudAIProvider.openai,
  apiKey: 'your-api-key',
  modelId: 'gpt-4-vision-preview',
  customPrompt: 'Analyze this photo for professional photography...',
);

// Configure coordinator
final config = AICoordinatorConfiguration(
  selectionStrategy: ServiceSelectionStrategy.hybrid,
  enableCloudAI: true,
  cloudConfiguration: cloudConfig,
  maxSuggestions: 5,
  confidenceThreshold: 0.8,
);

final coordinator = AICoordinator(configuration: config);
await coordinator.initialize();
```

### Local-Only Usage
```dart
final localService = LocalAIService();
await localService.initialize();

final result = await localService.generateSuggestions(
  sceneAnalysis: sceneAnalysis,
  userRequest: 'Landscape photography tips',
);
```

## Configuration Options

### AICoordinatorConfiguration
- `selectionStrategy` - How to choose between services
- `enableCloudAI` - Whether to use cloud services
- `cloudConfiguration` - Cloud service settings
- `allowFallbackToLocal` - Allow fallback when cloud fails
- `confidenceThreshold` - Minimum confidence for suggestions
- `maxSuggestions` - Maximum number of suggestions
- `cloudTimeout` - Timeout for cloud operations

### CloudAIConfiguration
- `provider` - AI provider (OpenAI, Gemini, Claude)
- `apiKey` - API authentication key
- `modelId` - Specific model to use
- `customPrompt` - Custom analysis prompt
- `timeout` - Request timeout
- `maxRetries` - Retry attempts
- `customSettings` - Provider-specific settings

### AIServiceConfiguration (Local)
- `confidenceThreshold` - Filter suggestions by confidence
- `maxSuggestions` - Limit suggestion count
- `enabledCategories` - Which suggestion types to include
- `enableFallback` - Allow fallback processing
- `timeout` - Processing timeout
- `customSettings` - Service-specific settings

## Error Handling

The architecture includes comprehensive error handling:

### Exception Types
- `AIServiceException` - General AI service errors
- `AIConfigurationException` - Configuration validation errors
- `NetworkConnectionException` - Network connectivity issues
- `InvalidImageFormatException` - Image format/decoding errors
- `ImageTooLargeException` - Image size limit exceeded
- `ImageMemoryException` - Memory allocation issues
- `ImageProcessingException` - General image processing errors

### Error Recovery
- Automatic fallback between services
- Graceful degradation when services unavailable
- Mock responses for testing/development
- Detailed error logging and reporting

## Testing

Comprehensive test suite covering:
- Unit tests for each service
- Integration tests for coordinator
- Configuration validation tests
- Error handling and fallback tests
- Performance and memory tests

**Run tests:**
```bash
flutter test test/services/ai/
```

## Performance Optimizations

### Local Service Optimizations
- **Platform-aware processing delays:** Different optimization per platform
- **Pixel sampling:** Efficient image analysis using sampling
- **Scene-based suggestions:** Only generate relevant suggestions
- **Configuration filtering:** Early filtering by categories and confidence

### Cloud Service Optimizations
- **Concurrent processing:** Run multiple services simultaneously in hybrid mode
- **Intelligent timeouts:** Reasonable timeouts with retry logic
- **Request batching:** Efficient API usage patterns
- **Caching strategy:** Cache frequently used responses

### Memory Management
- **Proper disposal patterns:** All services implement proper cleanup
- **Image size limits:** Prevent memory issues with large images
- **Resource pooling:** Efficient resource management
- **Memory leak prevention:** Comprehensive disposal tracking

## Migration Guide

### From Old Services

**Old Usage:**
```dart
final unifiedService = UnifiedAIService();
final result = await unifiedService.getAISuggestions(sceneAnalysis: analysis);
```

**New Usage:**
```dart
final coordinator = AICoordinator();
final result = await coordinator.generateSuggestions(sceneAnalysis: analysis);
```

### Breaking Changes
- Method names changed (`getAISuggestions()` → `generateSuggestions()`)
- Configuration structure simplified
- Service initialization patterns updated
- Some legacy features removed (custom prompt templates for local service)

## Future Enhancements

### Planned Features
- **TensorFlow Lite models:** Real ML models for mobile platforms
- **WebAssembly models:** Client-side ML for web platform
- **Model versioning:** Ability to update AI models
- **Performance monitoring:** Real-time performance metrics
- **A/B testing:** Compare different AI strategies
- **Custom model training:** User-specific model fine-tuning

### Extensibility
The architecture is designed for easy extension:
- Add new AI providers through `CloudAIService`
- Implement platform-specific optimizations via platform layer
- Create new service selection strategies
- Add custom suggestion categories
- Integrate additional ML frameworks

## Troubleshooting

### Common Issues

**Service Not Initializing:**
- Check configuration parameters
- Verify API keys for cloud services
- Ensure network connectivity for cloud services

**Poor Suggestion Quality:**
- Adjust confidence threshold
- Try different service selection strategies
- Check image quality and format
- Verify scene analysis accuracy

**Performance Issues:**
- Use local-only mode for real-time processing
- Optimize image sizes before analysis
- Adjust processing timeouts
- Monitor memory usage

**Network Issues:**
- Enable fallback to local processing
- Check API rate limits
- Verify SSL/TLS connectivity
- Monitor request timeouts

### Debug Mode
Enable detailed logging:
```dart
// Set debug mode for detailed logging
debugPrint('AI Coordinator initialized with strategy: ${config.selectionStrategy}');
```

## Conclusion

The new AI service architecture provides:
- **Clear separation of concerns** between local and cloud processing
- **Intelligent orchestration** with multiple selection strategies
- **Robust error handling** and graceful degradation
- **Platform optimizations** for best performance
- **Extensible design** for future enhancements
- **Comprehensive testing** for reliability

This architecture consolidates the previous 12+ AI services into 3 focused services (LocalAIService, CloudAIService, AICoordinator) with clear responsibilities and no overlapping functionality.