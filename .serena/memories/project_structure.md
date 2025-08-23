# Project Structure Overview

## Main Directory Structure
```
lens-ai/
├── mobile/              # Flutter mobile application (PRIMARY)
├── poc/                 # Proof of concept implementations
├── ai/                  # AI model training and testing
├── design/              # Design assets and specifications
├── docs/                # Documentation
├── config/              # Configuration files
├── scripts/             # Build and deployment scripts
└── lib/                 # Shared libraries
```

## Mobile Application Structure (`mobile/`)
```
mobile/
├── lib/
│   ├── core/               # Core providers and utilities
│   │   ├── providers/      # State management (camera, AI, etc.)
│   │   └── state/          # Application state classes
│   ├── features/           # Feature-specific implementations
│   ├── models/             # Data models and DTOs
│   ├── screens/            # UI screens and pages
│   ├── services/           # Business logic services
│   │   ├── ai/            # AI coordination and services
│   │   └── *.dart         # Camera, photo, sync services
│   ├── shared/             # Shared utilities and helpers
│   └── widgets/            # Reusable UI components
├── assets/                 # Static assets
│   ├── images/            # Image assets
│   ├── icons/             # Icon assets
│   ├── models/            # AI model files
│   └── animations/        # Animation files
├── test/                   # Unit and widget tests
├── integration_test/       # Integration tests
├── ios/                    # iOS platform-specific code
├── android/                # Android platform-specific code
├── macos/                  # macOS platform-specific code
└── web/                    # Web platform code (minimal)
```

## Key Service Architecture
- **ExternalCameraService**: USB/WiFi camera management and control
- **LibGPhoto2Service**: Cross-platform camera control library integration
- **NikonSDKService**: Native Nikon camera SDK integration
- **MacOSCameraService**: macOS-specific camera operations
- **AICoordinator**: Hybrid AI service coordination (cloud + local)
- **UnifiedCameraProvider**: Single interface for all camera types

## POC Directory (`poc/`)
```
poc/
├── web-debug/              # Real-time mobile app debugging dashboard
├── web-platform/           # Web browser AI implementation testing  
├── mobile-web-bridge/      # Flutter Web build artifacts
├── camera-sdk-backend/     # External camera SDK integration testing
└── web-ai-testing/         # AI provider integration testing
```

## Core Providers (State Management)
- **UnifiedCameraProvider**: Master camera controller
- **CameraStateProvider**: Camera state and settings
- **CameraFeatureProvider**: Feature flags and capabilities  
- **MobileCameraProvider**: Built-in mobile camera handling

## Important Configuration Files
- `pubspec.yaml`: Flutter dependencies and configuration
- `analysis_options.yaml`: Dart/Flutter linting rules
- `CLAUDE.md`: Project instructions and guidelines
- `.gitignore`: Git ignore patterns
- `docker-compose.yml`: Container orchestration for POC services