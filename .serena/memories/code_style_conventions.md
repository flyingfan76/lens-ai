# Code Style and Conventions

## Dart/Flutter Code Style

### General Principles
- Follow official Dart style guide
- Use meaningful variable and function names
- Prefer composition over inheritance
- Use dependency injection through Provider pattern

### Naming Conventions
- **Classes**: PascalCase (e.g., `ExternalCameraService`)
- **Methods/Variables**: camelCase (e.g., `startLiveView`, `isConnected`)
- **Constants**: camelCase with const (e.g., `const String defaultModel`)
- **Private members**: Leading underscore (e.g., `_isLiveViewActive`)
- **Files**: snake_case (e.g., `external_camera_service.dart`)

### Type Annotations
- Always use explicit type annotations for public APIs
- Use `var` for local variables when type is obvious
- Prefer `final` for immutable variables
- Use nullable types (`String?`) appropriately

### Documentation
- **NO COMMENTS** unless explicitly requested by user
- Use descriptive method and variable names instead of comments
- Self-documenting code is preferred

### Error Handling
```dart
// Use try-catch with specific error handling
try {
  final result = await someAsyncOperation();
  return result;
} catch (e) {
  debugPrint('Operation failed: $e');
  return fallbackValue;
}
```

### Async/Await Patterns
```dart
// Prefer async/await over Future.then()
Future<bool> startLiveView() async {
  try {
    final success = await _cameraService.connect();
    return success;
  } catch (e) {
    debugPrint('Connection failed: $e');
    return false;
  }
}
```

### State Management (Provider Pattern)
```dart
// Use ChangeNotifier for state management
class CameraProvider extends ChangeNotifier {
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      notifyListeners();
    }
  }
}
```

### Widget Organization
- Extract complex widgets to separate files
- Use const constructors where possible
- Prefer composition over deeply nested widgets
- Use Builder widgets for context-dependent operations

### File Organization
```
lib/
├── core/           # Core providers and utilities
├── features/       # Feature-specific code
├── models/         # Data models
├── screens/        # UI screens
├── services/       # Business logic services
├── shared/         # Shared utilities
└── widgets/        # Reusable UI components
```

## Analysis Configuration
- Uses `package:flutter_lints/flutter.yaml` as base
- Style-related warnings suppressed to focus on functionality
- Critical errors (undefined_method, undefined_class) remain as errors
- Prefer functionality over strict style compliance during development