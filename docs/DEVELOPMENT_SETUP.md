# Development Setup Guide

## Overview

This guide covers setting up the development environment for both the self-contained mobile applications and the backend-dependent web debugging interface.

## Quick Setup Summary

### 📱 Mobile App Development (No Backend Needed)
```bash
# Prerequisites: Flutter 3.16+, Dart 3.3+
git clone https://github.com/flyingfan76/lens-ai.git
cd lens-ai/mobile
flutter pub get
flutter run -d macos  # or ios/android
```

### 🌐 Web Debug Development (Backend Required)
```bash
# Prerequisites: Node.js 18+, Python 3.9+
cd lens-ai
make install && make setup
make dev
```

## Mobile App Development Setup

### Prerequisites

#### Required Software
- **Flutter SDK**: 3.16.0 or later
- **Dart SDK**: 3.3.0 or later (included with Flutter)
- **Git**: For version control

#### Platform-Specific Requirements

**For iOS Development:**
- **macOS**: Required for iOS development
- **Xcode**: 15.0 or later
- **iOS Deployment Target**: 12.0 or later
- **Apple Developer Account**: For device testing and App Store deployment

**For Android Development:**
- **Android Studio**: 2023.1 or later
- **Android SDK**: API level 21 (Android 5.0) or later
- **Java Development Kit**: 11 or later

**For macOS Development (Testing):**
- **macOS**: 10.15 (Catalina) or later
- **Xcode Command Line Tools**: For native compilation

### Installation Steps

#### 1. Install Flutter
```bash
# macOS (using Homebrew)
brew install flutter

# Or download from https://flutter.dev/docs/get-started/install
# Add to PATH: export PATH="$PATH:[PATH_TO_FLUTTER_GIT_DIRECTORY]/flutter/bin"

# Verify installation
flutter doctor
```

#### 2. Setup IDE (Optional but Recommended)
```bash
# VS Code with Flutter extension
code --install-extension Dart-Code.flutter

# Android Studio with Flutter plugin
# Install Flutter plugin through Android Studio plugin manager
```

#### 3. Clone and Setup Project
```bash
# Clone repository
git clone https://github.com/flyingfan76/lens-ai.git
cd lens-ai/mobile

# Install dependencies
flutter pub get

# Verify project setup
flutter analyze
```

#### 4. Platform-Specific Setup

**iOS Setup:**
```bash
# Open iOS project in Xcode
open ios/Runner.xcworkspace

# Setup signing and provisioning profiles in Xcode
# Build -> Archive -> Distribute App

# Run on iOS simulator
flutter run -d ios

# Run on iOS device
flutter run -d ios --device-id [DEVICE_ID]
```

**Android Setup:**
```bash
# Accept Android SDK licenses
flutter doctor --android-licenses

# Run on Android emulator
flutter run -d android

# Run on Android device (with USB debugging enabled)
flutter run -d android --device-id [DEVICE_ID]
```

**macOS Setup (for testing):**
```bash
# Enable macOS support
flutter config --enable-macos-desktop

# Set developer directory
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Run on macOS
flutter run -d macos
```

### Development Workflow

#### Running the App
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d [DEVICE_ID]

# Run with hot reload (default)
flutter run -d macos
# Press 'r' for hot reload, 'R' for hot restart, 'q' to quit

# Run in debug mode (default)
flutter run --debug -d macos

# Run in release mode
flutter run --release -d macos
```

#### Code Quality
```bash
# Static analysis
flutter analyze

# Format code
flutter format .

# Run tests
flutter test

# Run integration tests
flutter test integration_test/
```

#### Building for Release
```bash
# iOS release build
flutter build ios --release

# Android release build
flutter build android --release

# macOS release build
flutter build macos --release
```

### Project Structure
```
mobile/
├── lib/
│   ├── core/                   # Core functionality
│   │   ├── providers/          # State management (Provider pattern)
│   │   ├── theme/              # App theming and colors
│   │   └── utils/              # Utility functions
│   ├── screens/                # UI screens
│   │   ├── camera_screen.dart  # Main camera interface
│   │   ├── gallery_screen.dart # Photo gallery
│   │   ├── presets_screen.dart # Photography presets
│   │   ├── profile_screen.dart # User profile
│   │   └── settings_screen.dart # App settings
│   ├── services/               # Business logic
│   │   └── ai_service_simple.dart # Local AI processing
│   ├── widgets/                # Reusable UI components
│   └── main.dart               # App entry point
├── ios/                        # iOS-specific files
├── android/                    # Android-specific files
├── macos/                      # macOS-specific files
├── assets/                     # Images, fonts, etc.
├── pubspec.yaml                # Dependencies (no network libs)
└── test/                       # Unit and widget tests
```

### Key Dependencies
```yaml
# pubspec.yaml - Mobile (Local Only)
dependencies:
  flutter: sdk: flutter
  
  # Local camera control
  camera: ^0.10.5+5
  
  # Local image processing  
  image: ^4.0.17
  
  # Local AI processing
  tflite_flutter: ^0.10.1
  
  # Local storage
  shared_preferences: ^2.2.2
  
  # State management
  provider: ^6.1.1
  
  # UI utilities
  cupertino_icons: ^1.0.2

# Explicitly NO network dependencies:
# ❌ http, dio, web_socket_channel
# ❌ cached_network_image, connectivity_plus
```

### Troubleshooting Mobile Setup

#### Common Issues
```bash
# Flutter doctor issues
flutter doctor -v  # Verbose output for detailed diagnostics

# iOS issues
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Android issues
flutter doctor --android-licenses  # Accept all licenses
flutter clean && flutter pub get   # Clean and reinstall

# macOS permission issues
# Add camera permissions to macos/Runner/DebugProfile.entitlements:
# <key>com.apple.security.device.camera</key>
# <true/>
```

#### Performance Optimization
```bash
# Enable Flutter performance overlay
flutter run --enable-software-rendering  # For debugging
flutter run --trace-startup              # Startup performance
flutter run --profile                    # Profile mode

# Build optimizations
flutter build --release --split-debug-info=symbols/
flutter build --obfuscate --split-debug-info=symbols/
```

## Web Debug Development Setup

### Prerequisites

#### Required Software
- **Node.js**: 18.0 or later
- **Python**: 3.9 or later
- **Docker**: Latest version (optional)
- **Git**: For version control

#### System Requirements
- **Memory**: 8GB RAM minimum (16GB recommended)
- **Storage**: 5GB free space for dependencies
- **GPU**: CUDA-compatible GPU recommended for AI processing

### Installation Steps

#### 1. Install System Dependencies
```bash
# macOS
brew install node python@3.9 docker

# Ubuntu/Debian
sudo apt update
sudo apt install nodejs npm python3.9 python3-pip docker.io

# Windows (using Chocolatey)
choco install nodejs python docker-desktop
```

#### 2. Clone and Setup Project
```bash
# Clone repository
git clone https://github.com/flyingfan76/lens-ai.git
cd lens-ai

# Install using make (recommended)
make install
make setup

# Or manual installation
npm install          # Backend dependencies
pip install -r ai/requirements.txt  # AI service dependencies
```

#### 3. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

#### 4. Environment Variables
```bash
# .env file configuration
NODE_ENV=development
PORT=3000

# Database
MONGODB_URI=mongodb://localhost:27017/lens_ai

# Authentication
JWT_SECRET=your_jwt_secret_here

# Camera SDKs (optional)
CANON_SDK_PATH=/path/to/canon/sdk
NIKON_SDK_PATH=/path/to/nikon/sdk
SONY_API_KEY=your_sony_api_key

# AI Service
AI_SERVICE_URL=http://localhost:8001
ENABLE_NERF_ANALYSIS=true

# AWS (for cloud features)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_S3_BUCKET=lens-ai-images

# Debug settings
DEBUG_LEVEL=debug
ENABLE_PERFORMANCE_MONITORING=true
```

### Backend Development

#### Starting Services
```bash
# Start all services
make dev

# Or start individually
npm run dev          # Backend API server
python ai/nerf/nerf_service.py  # AI service
npm run dev:frontend # Web debug interface
```

#### Database Setup
```bash
# Start MongoDB (if not using Docker)
mongod --dbpath ./data/db

# Initialize database
npm run db:init

# Seed with sample data
npm run db:seed
```

#### Camera SDK Setup
```bash
# Install camera SDKs (optional)
./scripts/install-camera-sdks.sh

# Test camera detection
node -e "
const detector = require('./src/services/camera_auto_detector');
new detector().detectAllCameras().then(console.log);
"
```

### AI Service Development

#### Python Environment Setup
```bash
# Create virtual environment
python -m venv ai_env
source ai_env/bin/activate  # Linux/macOS
# ai_env\Scripts\activate   # Windows

# Install dependencies
pip install -r ai/requirements.txt

# Install CUDA dependencies (optional, for GPU acceleration)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

#### NeRF Service Setup
```bash
# Start NeRF service
cd ai
python -m uvicorn nerf.nerf_service:app --host 0.0.0.0 --port 8001 --reload

# Test NeRF service
curl http://localhost:8001/health

# Validate setup
python ../scripts/validate_nerf_setup.py
```

### Frontend Development

#### Web Debug Interface Setup
```bash
# Navigate to web debug directory
cd web-debug

# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build
```

### Development Workflow

#### Running Full Stack
```bash
# Start all services with one command
make dev

# This starts:
# - Backend API server (localhost:3000)
# - AI service (localhost:8001)  
# - Web debug interface (localhost:3001)
# - MongoDB database
```

#### Testing
```bash
# Run all tests
make test

# Run specific test suites
npm test                    # Backend tests
npm run test:integration    # Integration tests
python -m pytest ai/tests/ # AI service tests
npm test --prefix web-debug # Frontend tests
```

#### Code Quality
```bash
# Linting
make lint

# Format code
make format

# Type checking
npm run type-check
```

### Project Structure (Web Debug)
```
lens-ai/
├── backend/                    # Node.js backend
│   ├── src/
│   │   ├── api/               # REST API endpoints
│   │   ├── services/          # Business logic
│   │   ├── models/            # Database models
│   │   └── middleware/        # Express middleware
│   ├── test/                  # Backend tests
│   └── package.json           # Backend dependencies
├── ai/                        # Python AI services
│   ├── nerf/                  # NeRF-based analysis
│   ├── inference/             # Traditional AI processing
│   ├── training/              # ML model training
│   └── requirements.txt       # Python dependencies
├── web-debug/                 # React frontend
│   ├── src/
│   │   ├── components/        # React components
│   │   ├── pages/             # Application pages
│   │   ├── services/          # API clients
│   │   └── utils/             # Utility functions
│   └── package.json           # Frontend dependencies
├── config/                    # Configuration files
├── scripts/                   # Build and deployment scripts
├── docs/                      # Documentation
└── docker-compose.yml         # Docker services
```

### Docker Setup (Optional)

#### Using Docker Compose
```bash
# Start all services with Docker
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild services
docker-compose up --build
```

#### Docker Configuration
```yaml
# docker-compose.yml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - MONGODB_URI=mongodb://mongo:27017/lens_ai
    depends_on:
      - mongo
      
  ai-service:
    build: ./ai
    ports:
      - "8001:8001"
    volumes:
      - ./ai:/app
    environment:
      - PYTHONPATH=/app
      
  mongo:
    image: mongo:6
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      
  web-debug:
    build: ./web-debug
    ports:
      - "3001:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:3000

volumes:
  mongodb_data:
```

### Troubleshooting Web Debug Setup

#### Common Issues
```bash
# Node.js version issues
nvm use 18                    # Use Node.js 18
npm install -g npm@latest     # Update npm

# Python dependency issues
pip install --upgrade pip
pip install --force-reinstall -r ai/requirements.txt

# MongoDB connection issues
# Check if MongoDB is running
brew services start mongodb-community  # macOS
sudo systemctl start mongod            # Linux

# Port conflicts
lsof -i :3000    # Check what's using port 3000
kill -9 [PID]    # Kill process using port

# Camera SDK issues
# Ensure proper permissions and SDK installation
./scripts/diagnose-camera-setup.sh
```

#### Performance Optimization
```bash
# Enable production optimizations
NODE_ENV=production npm run start

# GPU acceleration for AI
CUDA_VISIBLE_DEVICES=0 python ai/nerf/nerf_service.py

# Memory optimization
NODE_OPTIONS="--max-old-space-size=4096" npm run dev
```

### IDE Configuration

#### VS Code Setup
```json
// .vscode/settings.json
{
  "typescript.preferences.importModuleSpecifier": "relative",
  "python.defaultInterpreterPath": "./ai_env/bin/python",
  "flutter.sdkPath": "/path/to/flutter",
  "files.exclude": {
    "**/node_modules": true,
    "**/.git": true,
    "**/build": true
  }
}
```

#### Recommended Extensions
```bash
# VS Code extensions for development
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension ms-python.python
code --install-extension Dart-Code.flutter
code --install-extension bradlc.vscode-tailwindcss
code --install-extension ms-vscode.vscode-json
```

## Development Commands Reference

### Mobile Development
```bash
flutter pub get              # Install dependencies
flutter run -d macos        # Run on macOS
flutter run -d ios          # Run on iOS
flutter run -d android      # Run on Android
flutter analyze             # Static analysis
flutter test                # Run tests
flutter build ios --release # Build iOS release
flutter build android --release # Build Android release
```

### Web Debug Development
```bash
make install                # Install all dependencies
make setup                  # Setup development environment
make dev                    # Start all development services
make test                   # Run all tests
make lint                   # Run code linting
make build                  # Build all projects
make clean                  # Clean build artifacts
make docker-up              # Start with Docker
make docker-down            # Stop Docker services
```

### Individual Service Commands
```bash
# Backend
npm run dev                 # Start backend server
npm test                    # Run backend tests
npm run lint               # Lint backend code

# AI Service
python ai/nerf/nerf_service.py    # Start AI service
python -m pytest ai/tests/        # Run AI tests
python scripts/validate_nerf_setup.py # Validate setup

# Frontend
npm start --prefix web-debug       # Start frontend
npm test --prefix web-debug        # Run frontend tests
npm run build --prefix web-debug   # Build frontend
```

This comprehensive setup guide ensures you can develop both the self-contained mobile applications and the backend-dependent web debugging interface efficiently.