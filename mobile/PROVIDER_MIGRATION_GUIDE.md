# Camera Provider Architecture Migration Guide

## Overview

This document outlines the migration from the complex, multi-responsibility provider architecture to a clean, single-responsibility provider hierarchy.

## New Provider Architecture

### 1. Abstract `CameraProvider` Interface

**Location**: `/lib/core/providers/camera_provider.dart`

**Purpose**: Defines the contract for all camera hardware providers.

**Key Methods**:
- `initializeCameras()` - Initialize camera system
- `connectToCamera()` - Connect to specific camera
- `captureImage()` - Capture photos
- Hardware control methods (ISO, aperture, etc.)

### 2. `MobileCameraProvider` (Hardware Control)

**Location**: `/lib/core/providers/mobile_camera_provider.dart`

**Purpose**: Platform-specific camera hardware control and operations.

**Responsibilities**:
- Camera initialization and connection
- Hardware settings management (ISO, aperture, shutter speed, etc.)
- Image capture operations
- Live view management
- Error handling for camera operations

**Key Features**:
- Implements abstract `CameraProvider` interface
- Platform-aware (iOS/Android/macOS/Web)
- Comprehensive error handling with `LensException`
- Performance optimized with proper disposal patterns

### 3. `CameraStateProvider` (UI State Management)

**Location**: `/lib/core/providers/camera_state_provider.dart`

**Purpose**: Manages all UI-related state for camera screens.

**Responsibilities**:
- UI control visibility (advanced controls, AI suggestions, etc.)
- Display settings (ISO, aperture values for UI)
- Preview states (composition grid, histogram)
- Capture states and loading indicators
- Status message management

**Key Features**:
- Reactive UI state management
- Temporary status message with auto-clear
- Comprehensive state reset functionality
- Performance optimized with minimal notifications

### 4. `CameraSettingsProvider` (Settings Persistence)

**Location**: `/lib/core/providers/camera_settings_provider.dart`

**Purpose**: Handles user preferences, presets, and settings persistence.

**Responsibilities**:
- User preference storage (auto-save, advanced mode, etc.)
- Camera preset management (built-in and user-defined)
- Last used settings persistence
- UI preference storage
- Settings import/export functionality

**Key Features**:
- Built-in presets (Portrait, Landscape, Low Light, Sports)
- User-defined preset creation and management
- Settings export/import for backup
- Async initialization with SharedPreferences

## Migration Steps

### Step 1: Update Provider Registration

**Before** (in `main.dart`):
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => UnifiedCameraProvider()),
    Provider<AICoordinator>.value(value: aiCoordinator),
  ],
```

**After**:
```dart
MultiProvider(
  providers: [
    // Core camera provider for hardware control
    ChangeNotifierProvider<MobileCameraProvider>(
      create: (_) => MobileCameraProvider(),
    ),
    // UI state management provider
    ChangeNotifierProvider<CameraStateProvider>(
      create: (_) => CameraStateProvider(),
    ),
    // Settings persistence provider (pre-initialized)
    ChangeNotifierProvider<CameraSettingsProvider>.value(
      value: cameraSettingsProvider,
    ),
    // AI coordinator service
    Provider<AICoordinator>.value(value: aiCoordinator),
  ],
```

### Step 2: Update Screen Usage

**Before**:
```dart
class _CameraScreenState extends State<CameraScreen> {
  final UnifiedCameraProvider _unifiedProvider = UnifiedCameraProvider();
  bool _showAdvancedControls = false;
  double _isoValue = 400;
  // ... more mixed state
```

**After**:
```dart
class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer3<MobileCameraProvider, CameraStateProvider, CameraSettingsProvider>(
      builder: (context, cameraProvider, stateProvider, settingsProvider, child) {
        // Use clean, separated providers
        return /* Your UI */;
      },
    );
  }
```

### Step 3: Update State Management Calls

**Before**:
```dart
setState(() {
  _showAdvancedControls = !_showAdvancedControls;
  _isoValue = newValue;
});
```

**After**:
```dart
// Update UI state
stateProvider.toggleAdvancedControls();
stateProvider.updateUISettings(iso: newValue);

// Update camera hardware
cameraProvider.updateISO(newValue);

// Save settings if needed
if (settingsProvider.autoSaveSettings) {
  await settingsProvider.updateLastUsedSettings({'iso': newValue});
}
```

### Step 4: Update Initialization Logic

**Before**:
```dart
await _unifiedProvider.initializeCameras();
if (_unifiedProvider.isConnected) {
  _cameraName = _unifiedProvider.currentCamera?.name;
}
```

**After**:
```dart
final cameraProvider = context.read<MobileCameraProvider>();
final stateProvider = context.read<CameraStateProvider>();
final settingsProvider = context.read<CameraSettingsProvider>();

stateProvider.setDiscovering(true);
try {
  await cameraProvider.initializeCameras();
  if (cameraProvider.isConnected) {
    stateProvider.setSelectedCameraName(
      cameraProvider.currentCamera?.name ?? 'Mobile Camera'
    );
    
    // Load last settings if enabled
    if (settingsProvider.useLastSettings) {
      final lastSettings = settingsProvider.lastUsedSettings;
      stateProvider.updateUISettings(
        iso: lastSettings['iso']?.toDouble(),
        aperture: lastSettings['aperture']?.toDouble(),
      );
    }
  }
} finally {
  stateProvider.setDiscovering(false);
}
```

## Benefits of New Architecture

### 1. Single Responsibility Principle
- **MobileCameraProvider**: Only handles camera hardware
- **CameraStateProvider**: Only manages UI state
- **CameraSettingsProvider**: Only handles persistence

### 2. Better Testability
- Each provider can be tested independently
- Clear interfaces make mocking easier
- Separated concerns reduce test complexity

### 3. Improved Performance
- Minimal change notifications
- Optimized state updates
- Proper disposal patterns

### 4. Enhanced Maintainability
- Clear separation of concerns
- Easier to add new features
- Reduced coupling between components

### 5. Better Error Handling
- Provider-specific error handling
- Clear error propagation
- User-friendly error messages

## Key Implementation Notes

### Error Handling
```dart
// Camera provider has comprehensive error handling
try {
  await cameraProvider.connectToCamera(cameraId: id);
} catch (e) {
  stateProvider.showTemporaryStatus('Connection failed: $e');
}
```

### Settings Management
```dart
// Built-in presets are immutable
final portraitPreset = settingsProvider.getPreset('portrait');

// User presets can be created and modified
await settingsProvider.createPreset('myPreset', {
  'name': 'My Custom Preset',
  'iso': 800.0,
  'aperture': 2.8,
});
```

### UI State Synchronization
```dart
// Keep UI and hardware in sync
cameraProvider.updateISO(newValue);
stateProvider.updateUISettings(iso: newValue);

// Save if auto-save enabled
if (settingsProvider.autoSaveSettings) {
  await settingsProvider.updateLastUsedSettings({'iso': newValue});
}
```

## Testing

Comprehensive tests are available in `/test/providers/camera_provider_test.dart`:

- **Unit Tests**: Each provider tested independently
- **Integration Tests**: Providers working together
- **Performance Tests**: Rapid updates and multiple listeners
- **Error Handling Tests**: Graceful failure scenarios

## Migration Checklist

- [ ] Update provider registration in `main.dart`
- [ ] Replace `UnifiedCameraProvider` usage with new providers
- [ ] Update state management calls
- [ ] Test camera initialization workflow
- [ ] Test settings persistence
- [ ] Test UI state management
- [ ] Run comprehensive tests
- [ ] Remove old provider files

## Conclusion

The new provider architecture provides:
- **Clean separation of concerns**
- **Better performance and maintainability**
- **Comprehensive testing coverage**
- **Enhanced error handling**
- **Scalable foundation for new features**

This architecture follows Flutter best practices and provides a solid foundation for the Lens AI mobile application's camera functionality.