# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lens AI is an AI-powered mobile camera control and photography assistant that bridges professional camera capabilities with user-friendly operation through advanced AI technology. The project uses a **hybrid architecture** with completely self-contained mobile applications and optional web debugging tools.

**Repository:** https://github.com/flyingfan76/lens-ai.git

## Hybrid Architecture

### Mobile Applications (iOS/Android) - **NO BACKEND DEPENDENCIES**
- **Pure self-contained operation**: All AI processing happens locally on device
- **Local camera control**: Direct integration with device cameras via Flutter camera plugin
- **Local image analysis**: Device-side algorithms for brightness, contrast, color temperature analysis
- **Local AI suggestions**: Photography recommendations generated using on-device logic
- **Local storage**: Photos and settings stored entirely on device
- **Zero network dependencies**: No backend APIs, no server calls, works completely offline

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
**Mobile (No Network Dependencies):**
- `camera: ^0.10.5+5` - Local camera control
- `image: ^4.0.17` - Local image processing
- `tflite_flutter: ^0.10.1` - Local AI processing
- All removed: `http`, `dio`, `web_socket_channel`, `cached_network_image`, `connectivity_plus`

**Web (Future - With Backend Dependencies):**
- Network libraries for API communication
- Server-side AI model integration
- Real-time debugging capabilities

## Architecture Details

### Mobile AI Service (`ai_service_simple.dart`)
- Platform-aware implementation (mobile vs web)
- Local image analysis methods:
  - `analyzeImage()` - Local brightness, contrast, color analysis
  - `generateAISuggestions()` - Device-side photography recommendations
  - `analyzeScene()` - Local scene understanding
- Zero network calls, all processing on-device

### Camera Integration
- Flutter camera plugin for direct device camera access
- Platform-specific implementations (iOS/Android/macOS)
- Local camera settings control (ISO, aperture, shutter speed, white balance)
- Real-time camera preview and capture

### State Management
- Provider pattern for camera state management
- Local settings persistence
- No cloud sync dependencies

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

1. **Mobile-First**: Mobile apps are completely independent and self-contained
2. **No Backend Overhead**: Mobile apps have zero server dependencies or costs
3. **Local Processing**: All AI features work offline using device capabilities
4. **Web for Development**: Web interface is purely for debugging/development
5. **Platform Awareness**: Code conditionally handles different platforms (iOS/Android/macOS/Web)