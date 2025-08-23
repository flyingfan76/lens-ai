# Camera Architecture Redesign Plan

## Current Architecture Problems

### 1. **Fragmented Camera Types**
- **3 Different Camera Models**: `ExternalCamera`, `BuiltInCamera`, `CameraDescription` (Flutter)
- **3 Different Provider Types**: `CameraSourceType.builtin`, `CameraSourceType.builtinMacOS`, `CameraSourceType.external`  
- **Inconsistent Interfaces**: Each camera type has different methods, properties, and capabilities
- **Platform-Specific Logic**: Scattered across multiple files with platform conditionals

### 2. **Capability System Mess**
- **External Cameras**: Have rich `CameraCapabilities` class with detailed feature detection
- **Built-in Cameras**: No capability system at all - blind assumptions about features
- **AI Suggestions**: Cannot determine if camera supports the suggested settings
- **Settings Application**: No validation against camera capabilities

### 3. **Inconsistent AI Integration**
- **External Cameras**: AI can suggest ISO, aperture, shutter speed, focus control
- **Built-in Cameras**: AI suggests settings that **CANNOT BE APPLIED** (no manual controls)
- **No Capability Filtering**: AI doesn't know what each camera can actually do
- **Broken User Experience**: Users get suggestions they can't use

### 4. **Service Architecture Chaos**
- **Multiple Services**: `ExternalCameraService`, `MacOSCameraService`, `UnifiedCameraProvider`
- **Duplicate Logic**: Connection handling, live view, capture logic scattered everywhere
- **State Management Nightmare**: Different state patterns for each camera type
- **No Common Interface**: Each service has different methods and error handling

## Proposed Unified Architecture

### 1. **Universal Camera Interface**

```dart
abstract class ICamera {
  // Identity
  String get id;
  String get name;
  String get model;
  CameraType get type;
  CameraBrand get brand;
  
  // Capabilities - EVERY camera has this
  CameraCapabilities get capabilities;
  
  // Connection
  Future<bool> connect();
  Future<void> disconnect();
  bool get isConnected;
  
  // Core functions - capability-dependent
  Future<bool> startLiveView();
  Future<void> stopLiveView();
  Stream<Uint8List>? get liveViewStream;
  
  Future<CaptureResult> capturePhoto();
  Future<CaptureResult> startVideoRecording();
  Future<CaptureResult> stopVideoRecording();
  
  // Settings - only if supported
  Future<T?> getSetting<T>(CameraSetting setting);
  Future<bool> setSetting<T>(CameraSetting setting, T value);
  List<CameraSetting> get supportedSettings;
  
  // Status
  CameraStatus get status;
  Stream<CameraStatus> get statusStream;
}
```

### 2. **Unified Capability System**

```dart
class CameraCapabilities {
  // Basic capabilities
  final bool supportsLiveView;
  final bool supportsRemoteCapture;
  final bool supportsVideoRecording;
  
  // Manual controls - KEY FOR AI INTEGRATION
  final bool supportsManualISO;
  final bool supportsManualAperture;
  final bool supportsManualShutter;
  final bool supportsManualFocus;
  final bool supportsManualWhiteBalance;
  final bool supportsExposureCompensation;
  
  // Advanced features
  final bool supportsFocusControl;
  final bool supportsZoomControl;
  final bool supportsBracketingModes;
  final bool supportsTimeLapse;
  
  // Available settings with ranges
  final CameraSettingRange? isoRange;
  final CameraSettingRange? apertureRange;
  final CameraSettingRange? shutterRange;
  final List<String> supportedImageFormats;
  final List<String> supportedVideoFormats;
  
  // Platform-specific limitations
  final bool isBuiltInCamera;
  final PlatformLimitations platformLimitations;
}

class PlatformLimitations {
  final bool canOnlyUseAutoMode;
  final bool limitedToBasicCapture;
  final String reason; // "Built-in mobile camera" vs "External DSLR"
}
```

### 3. **Concrete Camera Implementations**

```dart
// Built-in mobile cameras (iOS/Android)
class BuiltInMobileCamera implements ICamera {
  final CameraDescription flutterCamera;
  
  @override
  CameraCapabilities get capabilities => CameraCapabilities(
    supportsLiveView: true,
    supportsRemoteCapture: true,
    supportsVideoRecording: true,
    
    // NO MANUAL CONTROLS - key difference
    supportsManualISO: false,
    supportsManualAperture: false,
    supportsManualShutter: false,
    supportsManualFocus: false,
    
    isBuiltInCamera: true,
    platformLimitations: PlatformLimitations(
      canOnlyUseAutoMode: true,
      reason: "Built-in mobile camera - auto controls only"
    ),
  );
}

// Built-in desktop cameras (macOS)
class BuiltInDesktopCamera implements ICamera {
  @override
  CameraCapabilities get capabilities => CameraCapabilities(
    supportsLiveView: true,
    supportsRemoteCapture: true,
    supportsVideoRecording: true,
    
    // Limited manual controls
    supportsManualFocus: true,
    supportsManualISO: false, // Usually not available
    supportsManualAperture: false,
    supportsManualShutter: false,
    
    isBuiltInCamera: true,
    platformLimitations: PlatformLimitations(
      canOnlyUseAutoMode: false,
      reason: "Built-in desktop camera - limited manual controls"
    ),
  );
}

// External DSLR/Mirrorless cameras
class ExternalDSLRCamera implements ICamera {
  @override
  CameraCapabilities get capabilities => CameraCapabilities(
    supportsLiveView: true,
    supportsRemoteCapture: true,
    supportsVideoRecording: model.supportsVideo,
    
    // FULL MANUAL CONTROLS - key advantage
    supportsManualISO: true,
    supportsManualAperture: true,
    supportsManualShutter: true,
    supportsManualFocus: true,
    supportsManualWhiteBalance: true,
    supportsExposureCompensation: true,
    
    // Professional features
    supportsFocusControl: true,
    supportsBracketingModes: true,
    
    isBuiltInCamera: false,
    platformLimitations: PlatformLimitations(
      canOnlyUseAutoMode: false,
      reason: "External DSLR - full manual control available"
    ),
    
    // Actual setting ranges from camera
    isoRange: CameraSettingRange(min: 100, max: 25600, step: 100),
    apertureRange: CameraSettingRange.fromList(["f/1.4", "f/2.0", "f/2.8"]),
    shutterRange: CameraSettingRange.fromList(["1/4000", "1/2000", "1/1000"]),
  );
}
```

### 4. **Capability-Aware AI Integration**

```dart
class CapabilityAwareAICoordinator extends AICoordinator {
  @override
  Future<AIAnalysisResult> generateSuggestions({
    required SceneAnalysis sceneAnalysis,
    required ICamera camera, // Now knows camera capabilities!
    String? userRequest,
    Uint8List? imageBytes,
  }) async {
    
    // Filter suggestions based on camera capabilities
    final allSuggestions = await super.generateSuggestions(...);
    final applicableSuggestions = _filterByCapabilities(
      allSuggestions, 
      camera.capabilities
    );
    
    return AIAnalysisResult(
      success: true,
      suggestions: applicableSuggestions,
      analysisTimestamp: DateTime.now(),
      confidence: allSuggestions.confidence,
    );
  }
  
  List<AISuggestion> _filterByCapabilities(
    AIAnalysisResult result, 
    CameraCapabilities capabilities
  ) {
    return result.suggestions.where((suggestion) {
      switch (suggestion.type) {
        case AISuggestionType.isoAdjustment:
          return capabilities.supportsManualISO;
        case AISuggestionType.apertureAdjustment:
          return capabilities.supportsManualAperture;
        case AISuggestionType.shutterAdjustment:
          return capabilities.supportsManualShutter;
        case AISuggestionType.focusAdjustment:
          return capabilities.supportsManualFocus;
        case AISuggestionType.compositionTip:
          return true; // Always applicable
        default:
          return true;
      }
    }).toList();
  }
}
```

### 5. **Unified Camera Service**

```dart
class UnifiedCameraService {
  final List<ICameraProvider> _providers = [
    BuiltInCameraProvider(),
    ExternalCameraProvider(),
    DesktopCameraProvider(),
  ];
  
  ICamera? _activeCamera;
  
  Future<List<ICamera>> discoverCameras() async {
    final allCameras = <ICamera>[];
    
    for (final provider in _providers) {
      try {
        final cameras = await provider.discoverCameras();
        allCameras.addAll(cameras);
      } catch (e) {
        debugPrint('Provider ${provider.name} failed: $e');
      }
    }
    
    return allCameras;
  }
  
  Future<bool> switchToCamera(ICamera camera) async {
    // Disconnect current camera
    if (_activeCamera != null) {
      await _activeCamera!.disconnect();
    }
    
    // Connect to new camera
    final success = await camera.connect();
    if (success) {
      _activeCamera = camera;
      _logCameraCapabilities(camera);
    }
    
    return success;
  }
  
  void _logCameraCapabilities(ICamera camera) {
    final caps = camera.capabilities;
    debugPrint('Camera: ${camera.name}');
    debugPrint('  Manual ISO: ${caps.supportsManualISO}');
    debugPrint('  Manual Aperture: ${caps.supportsManualAperture}');
    debugPrint('  Manual Shutter: ${caps.supportsManualShutter}');
    debugPrint('  Manual Focus: ${caps.supportsManualFocus}');
    
    if (caps.platformLimitations.canOnlyUseAutoMode) {
      debugPrint('  ⚠️ LIMITED: ${caps.platformLimitations.reason}');
    }
  }
}
```

## Implementation Strategy

### Phase 1: Core Interface Design
1. **Define `ICamera` interface** with capability-aware methods
2. **Create unified `CameraCapabilities`** class 
3. **Implement capability detection** for each camera type
4. **Update AI coordinator** to be capability-aware

### Phase 2: Camera Implementation Migration  
1. **Migrate `ExternalCamera`** to implement `ICamera`
2. **Migrate built-in cameras** to implement `ICamera`
3. **Create unified camera providers** replacing separate services
4. **Update UI components** to use unified interface

### Phase 3: AI Integration Fixes
1. **Filter AI suggestions** by camera capabilities
2. **Add capability indicators** in UI (show what cameras can do)
3. **Prevent invalid setting applications** 
4. **Add capability-based help text**

### Phase 4: State Management Cleanup
1. **Unified camera state management**
2. **Single camera switching logic**
3. **Consistent error handling patterns**
4. **Simplified connection management**

## Key Benefits

### 1. **Proper AI Integration**
- AI only suggests settings the camera can actually apply
- No more "set ISO to 800" on built-in mobile cameras
- Capability-aware suggestions improve user experience

### 2. **Simplified Development** 
- One interface for all camera types
- Consistent patterns across the codebase
- Easier to add new camera types

### 3. **Better User Experience**
- Clear indication of camera capabilities  
- No confusion about what features are available
- Proper error messages when features aren't supported

### 4. **Maintainable Architecture**
- Single responsibility principle
- Clear separation of concerns  
- Testable components with well-defined interfaces

This architecture fixes the fundamental problems while maintaining backward compatibility and improving the overall user experience.