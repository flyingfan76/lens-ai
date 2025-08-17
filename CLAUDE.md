# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lens AI is an **external camera control application** that enables remote operation of professional DSLR and mirrorless cameras (Nikon, Canon, Sony, etc.) via USB or WiFi connections. The app provides AI-powered photography suggestions by connecting to external LLM providers like OpenAI, Anthropic, or custom endpoints.

**Repository:** https://github.com/flyingfan76/lens-ai.git

## Architecture Overview

### Mobile Applications (iOS/Android/macOS) - **PRIMARY PLATFORM**
- **External camera control**: Remote operation of DSLR/mirrorless cameras via USB or WiFi
- **Multi-brand support**: Nikon (D90, D850), Canon (EOS series), Sony (A7 series), Fujifilm, Olympus, Panasonic  
- **LLM-based AI suggestions**: Photography recommendations from OpenAI, Anthropic, or custom AI providers
- **Camera detection**: Automatic discovery of USB and WiFi-connected cameras
- **Professional controls**: ISO, aperture, shutter speed, white balance, focus control
- **Remote capture**: Take photos and videos directly from the mobile app

### Web Application - **BACKEND DEPENDENT** (Development/POC)
- **Development/debugging interface**: For testing and development purposes only
- **Server-side AI processing**: More powerful AI models running on backend servers
- **API integrations**: Optional connections to external photography services
- **Development tools**: Real-time debugging, analytics, advanced AI features
- **POC implementations**: Located in `/poc/` directory for concept validation

## POC Development

### Proof of Concept Directory Structure
The `/poc/` directory contains web-based prototypes and debugging tools:

```bash
poc/
├── web-debug/           # Real-time mobile app debugging dashboard
├── web-platform/        # Web browser AI implementation testing
├── mobile-web-bridge/   # Flutter Web build artifacts
├── camera-sdk-backend/  # External camera SDK integration and AI testing
└── web-ai-testing/      # AI provider integration testing (future)
```

### POC Usage
```bash
# Web debug dashboard
cd poc/web-debug
npm install && npm run dev
# Access at http://localhost:3001

# Web platform testing
flutter run -d chrome --web-renderer html
# Test browser-based AI features

# Camera SDK backend testing
cd poc/camera-sdk-backend
npm install && npm start
# Access at http://localhost:3000 for camera SDK testing
```

## Development Setup

### Mobile Development
```bash
cd mobile
flutter pub get
flutter run -d macos    # For macOS desktop testing
flutter run -d ios      # For iOS development
flutter run -d android  # For Android development
```

### Dependencies Structure
**Mobile (Hybrid AI + External Camera Control):**
- `camera: ^0.10.5+9` - Built-in camera support (iOS/Android only)
- `http: ^1.1.2` - API communication for cloud LLM providers
- `tflite_flutter: ^0.10.4` - Local AI processing with TensorFlow Lite
- `network_info_plus: ^4.1.0` - WiFi camera discovery
- `udp: ^5.0.3` - UDP discovery for WiFi cameras  
- `web_socket_channel: ^2.4.0` - Camera WebSocket communication
- `shared_preferences: ^2.2.2` - Settings and AI model persistence

**AI Architecture:**
- **Cloud AI**: OpenAI, Anthropic Claude, Google Gemini, Azure OpenAI, custom endpoints
- **Local AI**: TensorFlow Lite models for offline photography analysis
- **Intelligent Coordination**: Automatic fallback and service selection
- **Network Adaptive**: Works online with cloud AI or offline with local AI

## Architecture Details

### External Camera Service (`external_camera_service.dart`)
- **USB Camera Detection**: Automatic discovery of connected DSLR/mirrorless cameras
- **WiFi Camera Discovery**: Network scanning for WiFi-enabled cameras
- **Multi-brand Support**: Vendor ID mapping for Nikon, Canon, Sony, Fujifilm, Olympus, Panasonic
- **Connection Management**: Persistent camera connections and state management
- **Camera Database**: Model identification and capability mapping

### AI Integration (`ai_coordinator.dart`)
- **Hybrid AI Architecture**: Intelligent coordination between cloud and local AI services
- **Cloud AI Providers**: OpenAI, Anthropic Claude, Google Gemini, Azure OpenAI, custom endpoints
- **Local AI Processing**: TensorFlow Lite models for offline photography analysis  
- **Protocol Flexibility**: Supports OpenAI-compatible, Anthropic, Google, and custom API protocols
- **Intelligent Fallback**: Automatically falls back to local AI when network unavailable
- **Adaptive Selection**: Chooses optimal AI service based on connectivity and user preferences

### Camera Control System
- **Unified Camera Provider**: Manages both built-in (mobile only) and external cameras
- **Professional Controls**: ISO, aperture, shutter speed, white balance, focus
- **Remote Capture**: Photo and video capture via camera APIs
- **Real-time Settings**: Live camera setting synchronization

## Commands

### Development
```bash
# Mobile development
flutter run -d macos --verbose              # macOS desktop testing
flutter run -d ios --debug                  # iOS development
flutter run -d android --debug              # Android development
flutter analyze                             # Code analysis
flutter test                                # Run tests

# Build commands
flutter build ios --release                 # iOS release build
flutter build android --release             # Android release build
flutter build macos --release               # macOS desktop build
```

### Platform-Specific Setup
```bash
# macOS desktop support (for testing)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d macos

# iOS development
open ios/Runner.xcworkspace                 # Open in Xcode

# Android development - Requires JDK 17+
# Current setup has JDK 11, need to request JDK 17+ from IT
# Run setup script once JDK 17+ is available: ./setup-android-sdk.sh
flutter doctor                              # Check Android setup
```

## Key Implementation Notes

1. **External Camera Focus**: Primary purpose is controlling professional DSLR/mirrorless cameras
2. **Hybrid AI Architecture**: Supports both cloud LLM providers AND local TensorFlow Lite processing
3. **Multi-Platform Support**: Works on iOS, Android, and macOS (macOS supports external cameras only)
4. **USB & WiFi Connectivity**: Supports both wired and wireless camera connections
5. **Professional Photography**: Designed for photographers using external cameras, not mobile phone cameras
6. **Intelligent AI Selection**: Automatically chooses between cloud AI (when connected) and local AI (offline)
7. **Network Adaptive**: Fully functional offline with local AI, enhanced with cloud AI when online

## Supported Camera Brands and Models

### USB Connection (All Platforms)
- **Nikon**: D90, D850, D780, D500, D7500, Z series
- **Canon**: EOS series (DSLR and mirrorless R series)  
- **Sony**: A7 series, Alpha series mirrorless cameras
- **Fujifilm**: X-T series, X-H series mirrorless cameras
- **Olympus**: OM-D series mirrorless cameras
- **Panasonic**: Lumix series cameras

### WiFi Connection (Network Discovery)
- Any camera brand with WiFi capabilities
- Automatic network discovery via UDP broadcast
- Manual IP configuration support

## Platform-Specific Camera Support

### iOS/Android
- **Built-in cameras**: Supported via Flutter camera plugin
- **External cameras**: Full USB and WiFi support

### macOS Desktop  
- **Built-in cameras**: Not supported (Flutter camera plugin limitation)
- **External cameras**: Full USB and WiFi support - primary use case
- **Development/Testing**: Ideal platform for external camera development