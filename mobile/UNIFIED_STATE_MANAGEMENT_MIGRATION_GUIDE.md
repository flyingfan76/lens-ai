# Unified State Management Migration Guide

This guide helps you migrate from the existing state management patterns to the new unified state management system in the Lens AI mobile app.

## Overview

The new unified state management system provides:
- **Consistent patterns** across all features
- **Better error handling** with centralized error management
- **Automatic state persistence** with backup/restore capabilities
- **Performance optimizations** with batched updates
- **Comprehensive testing** with built-in test utilities

## Architecture Changes

### Before (Legacy Pattern)
```dart
// Multiple separate providers with different patterns
MultiProvider(
  providers: [
    ChangeNotifierProvider<MobileCameraProvider>(create: (_) => MobileCameraProvider()),
    ChangeNotifierProvider<CameraStateProvider>(create: (_) => CameraStateProvider()),
    ChangeNotifierProvider<CameraSettingsProvider>.value(value: settingsProvider),
    Provider<AICoordinator>.value(value: aiCoordinator),
  ],
  child: MyApp(),
)
```

### After (Unified Pattern)
```dart
// Single state manager coordinating all providers
void main() async {
  final stateManager = await StateManager.initialize();
  runApp(LensAIApp(stateManager: stateManager));
}

class LensAIApp extends StatelessWidget {
  final StateManager stateManager;
  
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: stateManager.getProviders(),
      child: MyApp(),
    );
  }
}
```

## Migration Steps

### Step 1: Update App Initialization

**Replace this:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final aiCoordinator = AICoordinator();
  await aiCoordinator.initialize();
  
  final cameraSettingsProvider = CameraSettingsProvider();
  await cameraSettingsProvider.initialize();
  
  runApp(LensAIApp(
    aiCoordinator: aiCoordinator,
    cameraSettingsProvider: cameraSettingsProvider,
  ));
}
```

**With this:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final stateManager = await StateManager.initialize();
  runApp(LensAIApp(stateManager: stateManager));
}
```

### Step 2: Update Provider Access Patterns

**Before (Direct Provider Access):**
```dart
class CameraScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<MobileCameraProvider>();
    final cameraState = context.watch<CameraStateProvider>();
    final cameraSettings = context.watch<CameraSettingsProvider>();
    
    return Column(
      children: [
        if (cameraProvider.isConnected) CameraPreview(),
        if (cameraState.showAdvancedControls) AdvancedControls(),
      ],
    );
  }
}
```

**After (Unified Provider Access):**
```dart
class CameraScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    final cameraFeature = context.watch<CameraFeatureProvider>();
    final uiState = context.watch<UIStateProvider>();
    
    return Column(
      children: [
        if (cameraFeature.isConnected) CameraPreview(),
        if (cameraFeature.showAdvancedControls) AdvancedControls(),
        
        // Global error handling is automatic
        // Global loading states are handled automatically
      ],
    );
  }
}
```

### Step 3: Update State Management Calls

**Camera Settings (Before):**
```dart
// Scattered across multiple providers
final cameraProvider = context.read<MobileCameraProvider>();
final cameraState = context.read<CameraStateProvider>();
final cameraSettings = context.read<CameraSettingsProvider>();

cameraProvider.updateISO(400);
cameraState.setAdvancedControlsVisible(true);
await cameraSettings.updateLastUsedSettings({'iso': 400});
```

**Camera Settings (After):**
```dart
// Single unified provider
final cameraFeature = context.read<CameraFeatureProvider>();

await cameraFeature.updateCameraSettings({'iso': 400});
cameraFeature.setAdvancedControlsVisible(true);
// Settings persistence is automatic
```

**Error Handling (Before):**
```dart
// Manual error handling in each component
try {
  await cameraProvider.captureImage();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Capture failed: $e')),
  );
}
```

**Error Handling (After):**
```dart
// Unified error handling
final errorState = context.read<ErrorStateProvider>();
final image = await cameraFeature.captureImage();
// Errors are automatically handled and displayed globally
```

### Step 4: Update UI State Management

**Loading States (Before):**
```dart
bool _isLoading = false;

void _performAction() async {
  setState(() => _isLoading = true);
  try {
    await someOperation();
  } finally {
    setState(() => _isLoading = false);
  }
}
```

**Loading States (After):**
```dart
void _performAction() async {
  final uiState = context.read<UIStateProvider>();
  uiState.setLoadingState('my_operation', true, message: 'Processing...');
  
  try {
    await someOperation();
  } finally {
    uiState.setLoadingState('my_operation', false);
  }
}

// In build method:
Widget build(BuildContext context) {
  final uiState = context.watch<UIStateProvider>();
  
  return Stack(
    children: [
      MyContent(),
      if (uiState.isLoading('my_operation'))
        LoadingOverlay(message: uiState.getLoadingMessage('my_operation')),
    ],
  );
}
```

## Provider Mapping Reference

| Legacy Provider | Unified Provider | Purpose |
|----------------|------------------|---------|
| `MobileCameraProvider` | `CameraFeatureProvider` | Camera hardware control + UI state |
| `CameraStateProvider` | `CameraFeatureProvider` | Consolidated into camera feature |
| `CameraSettingsProvider` | `CameraFeatureProvider` + `PersistentStateProvider` | Settings with automatic persistence |
| N/A | `AppStateProvider` | Global app state (theme, preferences, etc.) |
| N/A | `AIFeatureProvider` | AI functionality and suggestions |
| N/A | `UIStateProvider` | Transient UI state (loading, dialogs, etc.) |
| N/A | `ErrorStateProvider` | Centralized error management |

## Feature-Specific Migration

### Camera Features

**Before:**
```dart
// Multiple providers for camera functionality
final cameraProvider = context.read<MobileCameraProvider>();
final cameraState = context.read<CameraStateProvider>();
final cameraSettings = context.read<CameraSettingsProvider>();

// Initialize camera
await cameraProvider.initializeCameras();

// Update UI state
cameraState.setAdvancedControlsVisible(true);
cameraState.updateUISettings(iso: 400, aperture: 2.8);

// Save settings
await cameraSettings.updateLastUsedSettings({...});
```

**After:**
```dart
// Single unified provider
final cameraFeature = context.read<CameraFeatureProvider>();

// Initialize camera (includes UI state sync)
await cameraFeature.initializeCameras();

// Update settings (includes UI update and auto-save)
cameraFeature.setAdvancedControlsVisible(true);
await cameraFeature.updateCameraSettings({
  'iso': 400,
  'aperture': 2.8,
});
```

### AI Features

**Before:**
```dart
// Manual AI coordinator usage
final aiCoordinator = context.read<AICoordinator>();

if (await aiCoordinator.isServiceAvailable()) {
  final suggestions = await aiCoordinator.generateSuggestions(...);
  // Manual state management for suggestions
}
```

**After:**
```dart
// Integrated AI feature provider
final aiFeature = context.read<AIFeatureProvider>();

await aiFeature.generateSuggestions(context: 'portrait');
// Suggestions automatically managed with confidence filtering
// Error handling is automatic
// Performance metrics tracked automatically
```

### Theme and App State

**Before:**
```dart
// Manual theme management
MaterialApp(
  themeMode: ThemeMode.system, // Hardcoded
  // ...
)
```

**After:**
```dart
// Dynamic theme from app state
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    return MaterialApp(
      themeMode: appState.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: appState.textScaleFactor,
          ),
          child: child!,
        );
      },
    );
  },
)
```

## Testing Migration

### Old Testing Pattern
```dart
testWidgets('Camera screen test', (tester) async {
  final cameraProvider = MockMobileCameraProvider();
  final cameraState = MockCameraStateProvider();
  
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MobileCameraProvider>.value(value: cameraProvider),
        ChangeNotifierProvider<CameraStateProvider>.value(value: cameraState),
      ],
      child: CameraScreen(),
    ),
  );
  
  // Test implementation
});
```

### New Testing Pattern
```dart
testWidgets('Camera screen test', (tester) async {
  final stateManager = await StateManager.initialize();
  
  await tester.pumpWidget(
    MultiProvider(
      providers: stateManager.getProviders(),
      child: CameraScreen(),
    ),
  );
  
  // Test with unified providers
  final cameraFeature = tester.read<CameraFeatureProvider>();
  await cameraFeature.initializeCameras();
  
  // Test implementation
  
  await stateManager.dispose();
});
```

## Performance Considerations

### Batched Updates
The new system automatically batches state updates for better performance:

```dart
// Automatic batching in unified providers
cameraFeature.batchStateUpdates(() {
  cameraFeature.setAdvancedControlsVisible(true);
  cameraFeature.setAISuggestionsVisible(true);
  cameraFeature.setCameraControlsVisible(false);
}); // Single notification sent
```

### Automatic Persistence
State is automatically persisted with configurable intervals:

```dart
// Automatic every 30 seconds (configurable)
persistentStateProvider.setAutoSaveInterval(Duration(seconds: 30));

// Manual save all
await stateManager.saveAllStates();
```

### Error Recovery
Automatic error recovery with configurable retry attempts:

```dart
// Automatic recovery for recoverable errors
errorStateProvider.setAutoRecoveryEnabled(true);
errorStateProvider.setMaxRecoveryAttempts(3);
```

## Backward Compatibility

The migration maintains backward compatibility by:

1. **Keeping legacy providers** available during transition
2. **Gradual migration** - you can migrate screen by screen
3. **Same API surfaces** where possible
4. **Clear deprecation warnings** for old patterns

### Gradual Migration Example
```dart
// You can mix old and new patterns during migration
class MyScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    // New unified provider
    final cameraFeature = context.watch<CameraFeatureProvider>();
    
    // Legacy provider (still works)
    final aiCoordinator = context.read<AICoordinator>();
    
    return Column(
      children: [
        // New pattern
        if (cameraFeature.isConnected) NewCameraControls(),
        
        // Legacy pattern (still works)
        LegacyAIControls(coordinator: aiCoordinator),
      ],
    );
  }
}
```

## Common Migration Issues

### Issue 1: Provider Not Found
**Error:** `Provider<CameraFeatureProvider> not found`

**Solution:** Ensure StateManager is initialized and providers are registered:
```dart
// Make sure this is called before runApp
final stateManager = await StateManager.initialize();
```

### Issue 2: State Not Persisting
**Problem:** Settings reset on app restart

**Solution:** Verify provider is registered for persistence:
```dart
// StateManager automatically registers key providers
// Manual registration if needed:
await persistentStateProvider.registerProvider('my_provider', myProvider);
```

### Issue 3: Errors Not Displayed
**Problem:** Errors not showing to user

**Solution:** Ensure error banner is included in app builder:
```dart
MaterialApp(
  builder: (context, child) {
    return Stack(
      children: [
        child!,
        if (context.watch<ErrorStateProvider>().showErrorBanner)
          ErrorBanner(),
      ],
    );
  },
)
```

## Best Practices

### 1. Use Appropriate Provider
- `AppStateProvider` - Global settings, theme, user preferences
- `CameraFeatureProvider` - Camera functionality (hardware + UI + settings)
- `AIFeatureProvider` - AI suggestions and analysis
- `UIStateProvider` - Loading states, dialogs, navigation
- `ErrorStateProvider` - Error display and recovery

### 2. Leverage Automatic Features
```dart
// Let the system handle persistence automatically
cameraFeature.setAutoSaveSettings(true);

// Use built-in error handling
// Don't wrap every operation in try-catch

// Use UI state provider for loading states
uiState.setLoadingState('operation', true);
// System will automatically show global loading indicator
```

### 3. Test with Unified System
```dart
// Test complete state management system
final stateManager = await StateManager.initialize();

// Test state coordination
expect(stateManager.isHealthy, true);

// Test error handling
stateManager.errorStateProvider.reportError(testError);
expect(stateManager.isHealthy, false);
```

## Troubleshooting

### Debugging State Issues
```dart
// Get comprehensive state information
final stats = stateManager.getStateStatistics();
print('State Statistics: $stats');

// Check system health
final health = stateManager.getHealthReport();
print('System Health: $health');

// Monitor errors
final errorStats = stateManager.errorStateProvider.getErrorStatistics();
print('Error Statistics: $errorStats');
```

### Performance Monitoring
```dart
// Check if any operations are slow
if (stateManager.isHealthy) {
  final stats = stateManager.getStateStatistics();
  // Check initialization times, error counts, etc.
}
```

## Rollback Plan

If you need to rollback to the legacy system:

1. **Remove StateManager initialization** from main.dart
2. **Restore original MultiProvider** setup
3. **Update provider imports** back to legacy providers
4. **Remove unified provider usage** from components

The legacy providers remain available and functional during the migration period.

## Support and Resources

- **State Management Tests:** `/test/core/state/`
- **Performance Tests:** `/test/core/state/performance_tests.dart`
- **Example Usage:** See updated screens in `/lib/screens/`
- **API Documentation:** Each provider has comprehensive inline documentation

For questions or issues during migration, refer to the test suite for usage examples and expected behavior patterns.