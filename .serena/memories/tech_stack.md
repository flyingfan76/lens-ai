# Tech Stack and Dependencies

## Core Framework
- **Flutter 3.16.0+** with Dart 3.2.0+
- **Target Platforms**: iOS, Android, macOS desktop

## Key Flutter Dependencies

### Camera & Image Processing
- `camera: ^0.10.5+9` - Built-in camera support (iOS/Android only)
- `image: ^4.1.4` - Image processing and manipulation

### AI & ML
- `tflite_flutter: ^0.10.4` - Local AI processing with TensorFlow Lite
- `http: ^1.1.2` - API communication for cloud LLM providers

### External Camera Support  
- `network_info_plus: ^4.1.0` - WiFi camera discovery
- `udp: ^5.0.3` - UDP discovery for WiFi cameras
- `web_socket_channel: ^2.4.0` - Camera WebSocket communication

### State Management & Storage
- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.2` - Settings and AI model persistence
- `flutter_secure_storage: ^9.0.0` - Secure credentials storage

### Security & Privacy
- `crypto: ^3.0.3` - Cryptographic functions
- `encrypt: ^5.0.1` - Data encryption
- `local_auth: ^2.1.6` - Biometric authentication
- `pointycastle: ^3.7.3` - Cryptographic primitives

### UI Components
- `flutter_svg: ^2.0.9` - SVG asset support
- `lottie: ^3.0.0` - Animation support

### Development & Testing
- `flutter_lints: ^3.0.1` - Dart/Flutter linting rules
- `mockito: ^5.4.4` - Mock testing
- `integration_test` - Integration testing framework
- `patrol: ^3.2.1` - Advanced UI testing
- `coverage: ^1.7.1` - Code coverage analysis

## AI Architecture
- **Cloud AI**: OpenAI, Anthropic Claude, Google Gemini, Azure OpenAI, custom endpoints
- **Local AI**: TensorFlow Lite models for offline photography analysis
- **Intelligent Coordination**: Automatic fallback and service selection
- **Network Adaptive**: Works online with cloud AI or offline with local AI

## Camera Support Architecture
- **External Camera Service**: USB and WiFi camera management
- **LibGPhoto2 Service**: Primary camera control library (cross-platform)
- **Nikon SDK Service**: Native Nikon camera support for advanced features
- **macOS Camera Service**: macOS-specific camera integration
- **Unified Camera Provider**: Single interface for all camera types