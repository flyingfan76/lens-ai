# 🏗�? Build Instructions for Camera Companion

This guide provides comprehensive instructions for building Camera Companion on macOS for development, testing, and production environments.

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Quick Start Build](#-quick-start-build)
- [Development Build](#-development-build)
- [Production Build](#-production-build)
- [Platform-Specific Builds](#-platform-specific-builds)
- [Docker Builds](#-docker-builds)
- [CI/CD Builds](#-cicd-builds)
- [Troubleshooting](#-troubleshooting)

## 🔧 Prerequisites

### System Requirements

**macOS Version**: 12.0+ (Monterey or newer)  
**Architecture**: Intel x64 or Apple Silicon (M1/M2)  
**RAM**: 8GB minimum, 16GB recommended  
**Storage**: 20GB free space  
**Xcode**: 14.0+ (for iOS builds)  
**Android Studio**: 2022.3.1+ (for Android builds)

### Required Tools Installation

#### 1. Install Homebrew (if not installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install Core Development Tools
```bash
# Node.js (Backend)
brew install node@18
echo 'export PATH="/opt/homebrew/opt/node@18/bin:$PATH"' >> ~/.zshrc

# Python (AI Services)
brew install python@3.9
brew install python@3.10  # For NeRF compatibility

# Flutter (Mobile)
brew install --cask flutter

# Docker (Containerization)
brew install --cask docker

# Additional build tools
brew install cmake
brew install pkg-config
brew install git-lfs
```

#### 3. Install Platform-Specific Tools

**For iOS Development:**
```bash
# Install Xcode from App Store
# Install Xcode Command Line Tools
sudo xcode-select --install

# Install CocoaPods
sudo gem install cocoapods
```

**For Android Development:**
```bash
# Install Android Studio from https://developer.android.com/studio
# Or using Homebrew
brew install --cask android-studio

# Install Android SDK command line tools
brew install --cask android-commandlinetools
```

#### 4. Camera SDK Prerequisites

**SDK Directory Structure:**
```
lens-ai/
├── sdk/
│   ├── canon/     # Canon EDSDK files
│   ├── nikon/     # Nikon SDK files  
│   └── sony/      # Sony SDK files (if applicable)
```

**Download and Setup:**
```bash
# Create SDK directory structure
mkdir -p sdk/canon sdk/nikon sdk/sony

# Canon SDK (Download from Canon Developer Program)
# Extract EDSDK to: ./sdk/canon/

# Nikon SDK (Download from Nikon Developer Program)  
# Extract SDK contents to: ./sdk/nikon/
# Should contain: Command/ and Module/ folders

# Sony SDK (Register at Sony Developer World)
# Get API key and configure in .env (no local files needed)
```

**Note:** The `sdk/` folder is excluded from git tracking to keep SDK files private.

### Environment Setup

#### 1. Clone Repository
```bash
git clone https://github.com/flyingfan76/lens-ai.git
cd lens-ai
```

#### 2. Install Git LFS (for models and assets)
```bash
git lfs install
git lfs pull
```

#### 3. Create Environment Configuration
```bash
cp .env.example .env
```

#### 4. Configure Environment Variables
```bash
# Edit .env file with your configuration
nano .env
```

**Required Environment Variables:**
```bash
# Core Configuration
NODE_ENV=development
PORT=3000
PYTHON_ENV=development

# Database Configuration
MONGODB_URI=mongodb://localhost:27017/lens-ai
REDIS_URL=redis://localhost:6379

# JWT Configuration
JWT_SECRET=your_secure_jwt_secret_here

# Camera SDK Configuration
CANON_SDK_PATH=./sdk/canon
SONY_API_KEY=your_sony_api_key_here
NIKON_SDK_PATH=./sdk/nikon

# Storage Configuration
# Set STORAGE_MODE to 'local' for local file storage simulation (no AWS required)
# Set to 'cloud' for actual AWS S3 storage
STORAGE_MODE=local

# AWS Configuration (only needed when STORAGE_MODE=cloud)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_S3_BUCKET=camera-companion-dev

# Local Storage Configuration (used when STORAGE_MODE=local)
LOCAL_STORAGE_PATH=./storage

# AI Service Configuration
AI_SERVICE_URL=http://localhost:8000
NERF_SERVICE_URL=http://localhost:8001

# Build Configuration
BUILD_MODE=development
LOG_LEVEL=debug
```

## 🚀 Quick Start Build

### One-Command Setup
```bash
# Complete setup and build
make setup && make build

# Start development environment
make dev
```

This will:
- Install all dependencies
- Set up the development environment
- Build all components
- Start all services

## 🛠�? Development Build

### Backend Development Build

#### 1. Install Dependencies
```bash
cd backend
npm install
```

#### 2. Build Native Modules
```bash
# Build Canon SDK bindings
cd native/canon && npm install && npm run build

# Build Sony SDK bindings  
cd ../sony && npm install && npm run build

# Build Nikon SDK bindings
cd ../nikon && npm install && npm run build
```

#### 3. Initialize Database
```bash
# Start MongoDB (via Docker or local)
make docker-up

# Initialize presets and education content
npm run init-presets
npm run init-education
```

#### 4. Start Development Server
```bash
npm run dev
```

**Build Verification:**
```bash
# Test API endpoints
curl http://localhost:3000/api/health
curl http://localhost:3000/api/camera/discover

# Test local storage mode (if STORAGE_MODE=local)
curl http://localhost:3000/api/cloud/health
```

### Local Storage Mode Setup (for Development)

For development and testing without AWS setup, the project includes a local storage simulation mode:

#### 1. Configure Local Storage Mode
```bash
# In your .env file, set:
STORAGE_MODE=local
LOCAL_STORAGE_PATH=./storage

# Optional: remove AWS credentials (they won't be needed)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
```

#### 2. Features in Local Mode
- **File Storage**: Photos stored locally in `./storage/users/{userId}/photos/`
- **Thumbnails**: Generated and stored alongside photos
- **Metadata**: JSON metadata files stored in `./storage/metadata/`
- **API Compatibility**: Same API endpoints work identically
- **File Serving**: Photos accessible via `http://localhost:3000/storage/{filepath}`

#### 3. Local Storage Directory Structure
```
storage/
├── users/
│   └── {userId}/
│       └── photos/
│           ├── {timestamp}-{hash}.jpg
│           ├── {timestamp}-{hash}_thumb_small.jpg
│           ├── {timestamp}-{hash}_thumb_medium.jpg
│           └── {timestamp}-{hash}_thumb_large.jpg
└── metadata/
    ├── {timestamp}-{hash}.json
    ├── {timestamp}-{hash}_thumb_small.json
    ├── {timestamp}-{hash}_thumb_medium.json
    └── {timestamp}-{hash}_thumb_large.json
```

#### 4. Test Local Storage
```bash
# Start backend with local storage
npm run dev

# Test photo upload (requires authentication)
curl -X POST http://localhost:3000/api/cloud/photos/upload \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "photo=@test_image.jpg"

# View uploaded photos
ls -la storage/users/*/photos/

# Access photo via URL
curl http://localhost:3000/storage/users/USER_ID/photos/FILENAME.jpg
```

### Mobile Development Build

#### 1. Install Flutter Dependencies
```bash
cd mobile
flutter pub get
```

#### 2. Generate Code (if needed)
```bash
flutter packages pub run build_runner build
```

#### 3. Build for Development
```bash
# iOS Development Build
flutter build ios --debug --simulator

# Android Development Build  
flutter build apk --debug
```

#### 4. Run on Device/Simulator
```bash
# List available devices
flutter devices

# Run on iOS Simulator
flutter run -d "iPhone 14 Pro"

# Run on Android Emulator
flutter run -d emulator-5554
```

### AI Service Development Build

#### 1. Create Python Virtual Environment
```bash
cd ai
python3.9 -m venv venv
source venv/bin/activate
```

#### 2. Install Python Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

#### 3. Install PyTorch with CUDA (if available)
```bash
# For Apple Silicon Macs
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# For Intel Macs with CUDA support
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
```

#### 4. Validate NeRF Setup
```bash
python ../scripts/validate_nerf_setup.py
```

#### 5. Start AI Service
```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Build Verification:**
```bash
# Test AI service endpoints
curl http://localhost:8000/health
curl -X POST http://localhost:8000/analyze -F "image=@test_image.jpg"
```

## 🎯 Production Build

### Backend Production Build

#### 1. Install Production Dependencies
```bash
cd backend
npm ci --only=production
```

#### 2. Build for Production
```bash
npm run build
```

#### 3. Optimize Native Modules
```bash
# Rebuild native modules for production
npm rebuild --production

# Build optimized native bindings
cd native/canon && npm run build:release
cd ../sony && npm run build:release  
cd ../nikon && npm run build:release
```

#### 4. Create Production Bundle
```bash
# Create distribution package
npm run package

# Verify bundle
node dist/app.js
```

### Mobile Production Build

#### 1. Configure Build Settings

**iOS Configuration (`ios/Runner/Info.plist`):**
```xml
<key>CFBundleDisplayName</key>
<string>Camera Companion</string>
<key>CFBundleVersion</key>
<string>1.0.0</string>
```

**Android Configuration (`android/app/build.gradle`):**
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.cameracompanion.app"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

#### 2. Build Release APK (Android)
```bash
cd mobile

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Verify build
ls build/app/outputs/flutter-apk/
```

#### 3. Build iOS Release
```bash
# Build for iOS
flutter build ios --release

# Create iOS Archive (requires Xcode)
cd ios
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -destination generic/platform=iOS \
           -archivePath build/Runner.xcarchive \
           archive
```

### AI Service Production Build

#### 1. Create Production Environment
```bash
cd ai
python3.9 -m venv prod_env
source prod_env/bin/activate
```

#### 2. Install Production Dependencies
```bash
pip install --no-dev -r requirements.txt
```

#### 3. Optimize Models
```bash
# Convert models to production format
python scripts/optimize_models.py

# Validate model performance
python scripts/benchmark_models.py
```

#### 4. Create Production Image
```bash
# Build Docker image
docker build -t camera-companion-ai:production .

# Test production image
docker run -p 8000:8000 camera-companion-ai:production
```

## 📱 Platform-Specific Builds

### iOS Build Instructions

#### Prerequisites
```bash
# Ensure Xcode is installed and up to date
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Install iOS deployment tools
gem install fastlane
```

#### Development Build
```bash
cd mobile

# Clean previous builds
flutter clean
flutter pub get

# Build for iOS Simulator
flutter build ios --debug --simulator

# Build for physical device
flutter build ios --debug --no-simulator
```

#### Release Build
```bash
# Build iOS release
flutter build ios --release --no-simulator

# Create archive for App Store
cd ios
fastlane build_app_store
```

#### Code Signing Setup
```bash
# Configure automatic signing in Xcode
open ios/Runner.xcworkspace

# Or manual signing
security find-identity -v -p codesigning
codesign --sign "iPhone Developer: Your Name" build/ios/Release-iphoneos/Runner.app
```

### Android Build Instructions

#### Prerequisites
```bash
# Set Android SDK path
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export ANDROID_HOME=$ANDROID_SDK_ROOT

# Add tools to PATH
export PATH=$PATH:$ANDROID_SDK_ROOT/tools
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
```

#### Development Build
```bash
cd mobile

# Clean previous builds
flutter clean
flutter pub get

# Build debug APK
flutter build apk --debug

# Install on connected device
flutter install
```

#### Release Build
```bash
# Generate keystore (first time only)
keytool -genkey -v -keystore camera-companion-release.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias camera-companion

# Configure key.properties
echo "storePassword=your_password" >> android/key.properties
echo "keyPassword=your_password" >> android/key.properties
echo "keyAlias=camera-companion" >> android/key.properties
echo "storeFile=../camera-companion-release.jks" >> android/key.properties

# Build release APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

#### Signing Verification
```bash
# Verify APK signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# Check App Bundle
bundletool validate --bundle=build/app/outputs/bundle/release/app-release.aab
```

## 🐳 Docker Builds

### Development Docker Build

#### 1. Build All Services
```bash
# Build all Docker images
docker-compose build

# Start development environment
docker-compose up -d
```

#### 2. Individual Service Builds
```bash
# Build backend only
docker-compose build backend

# Build AI service only
docker-compose build ai_service

# Build with no cache
docker-compose build --no-cache
```

### Production Docker Build

#### 1. Multi-stage Production Build
```bash
# Build production images
docker-compose -f docker-compose.prod.yml build

# Push to registry (if configured)
docker-compose -f docker-compose.prod.yml push
```

#### 2. Optimize Image Sizes
```bash
# Build with BuildKit for optimization
DOCKER_BUILDKIT=1 docker build \
  --target production \
  -t camera-companion-backend:latest \
  ./backend

# Use multi-stage builds for minimal images
docker build --target production-minimal \
  -t camera-companion-ai:minimal \
  ./ai
```

### Docker Build Verification
```bash
# Check image sizes
docker images camera-companion*

# Test containers
docker run --rm -p 3000:3000 camera-companion-backend:latest
docker run --rm -p 8000:8000 camera-companion-ai:latest

# Health checks
curl http://localhost:3000/health
curl http://localhost:8000/health
```

## 🔄 CI/CD Builds

### GitHub Actions Build

Create `.github/workflows/build.yml`:
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  backend-build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: backend/package-lock.json
    
    - name: Install dependencies
      run: cd backend && npm ci
    
    - name: Run tests
      run: cd backend && npm test
    
    - name: Build
      run: cd backend && npm run build

  mobile-build:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Install dependencies
      run: cd mobile && flutter pub get
    
    - name: Run tests
      run: cd mobile && flutter test
    
    - name: Build APK
      run: cd mobile && flutter build apk --release
    
    - name: Build iOS
      run: cd mobile && flutter build ios --release --no-codesign

  ai-build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        cd ai
        pip install -r requirements.txt
    
    - name: Run tests
      run: cd ai && python -m pytest tests/
    
    - name: Build Docker image
      run: docker build -t camera-companion-ai ./ai
```

### Build Automation Scripts

#### `scripts/build.sh`
```bash
#!/bin/bash
set -e

echo "🏗�? Building Camera Companion..."

# Build backend
echo "📦 Building backend..."
cd backend && npm run build && cd ..

# Build mobile
echo "📱 Building mobile..."
cd mobile && flutter build apk --release && cd ..

# Build AI service  
echo "🤖 Building AI service..."
cd ai && docker build -t camera-companion-ai . && cd ..

echo "�? Build completed successfully!"
```

#### `scripts/test-build.sh`
```bash
#!/bin/bash
set -e

echo "🧪 Testing builds..."

# Test backend
echo "Testing backend..."
cd backend && npm test && cd ..

# Test mobile
echo "Testing mobile..."
cd mobile && flutter test && cd ..

# Test AI service
echo "Testing AI service..."
cd ai && python -m pytest tests/ && cd ..

echo "�? All tests passed!"
```

## 🚨 Troubleshooting

### Common Build Issues

#### 1. Node.js Native Module Build Failures
```bash
# Problem: gyp ERR! stack Error: `make` failed with exit code: 2
# Solution: Install build tools
xcode-select --install
npm install -g node-gyp

# Rebuild native modules
npm rebuild
```

#### 2. Flutter Build Failures
```bash
# Problem: Flutter version mismatch
# Solution: Update Flutter
flutter upgrade
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
rm -rf build/
flutter build apk --debug
```

#### 3. Python/AI Service Issues
```bash
# Problem: CUDA not available
# Solution: Install CPU-only PyTorch
pip uninstall torch torchvision
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Problem: Memory issues during build
# Solution: Increase Python memory limit
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
```

#### 4. Docker Build Issues
```bash
# Problem: Build context too large
# Solution: Use .dockerignore
echo "node_modules" >> .dockerignore
echo "mobile/build" >> .dockerignore
echo "ai/models" >> .dockerignore

# Problem: Out of disk space
# Solution: Clean Docker
docker system prune -af
docker volume prune -f
```

#### 5. Camera SDK Issues
```bash
# Problem: SDK not found
# Solution: Verify SDK paths
ls -la /Applications/Canon_SDK/EDSDK
export CANON_SDK_PATH=/Applications/Canon_SDK/EDSDK

# Problem: Permission denied
# Solution: Fix permissions
sudo chown -R $(whoami) /Applications/Canon_SDK/
```

### Build Performance Optimization

#### 1. Parallel Builds
```bash
# Use multiple CPU cores
export MAKEFLAGS="-j$(nproc)"

# Flutter parallel builds
flutter build apk --release --build-number=1 --dart-define=PARALLEL_BUILD=true
```

#### 2. Incremental Builds
```bash
# Enable incremental builds
export FLUTTER_BUILD_MODE=debug
export NODE_ENV=development

# Use build caching
npm ci --cache .npm-cache
flutter build apk --release --build-shared-library
```

#### 3. Build Caching
```bash
# Docker build cache
docker build --cache-from camera-companion-backend:latest .

# NPM build cache
npm ci --prefer-offline --cache .npm-cache

# Flutter build cache
flutter precache
```

### Build Verification Checklist

#### Pre-Build Checklist
- [ ] All dependencies installed
- [ ] Environment variables configured
- [ ] SDKs properly set up
- [ ] Database services running
- [ ] Network connectivity verified

#### Post-Build Checklist
- [ ] All services start without errors
- [ ] API endpoints respond correctly
- [ ] Mobile app installs and runs
- [ ] AI services process requests
- [ ] Database connections work
- [ ] File permissions correct

#### Production Build Checklist
- [ ] Environment set to production
- [ ] Secrets properly configured
- [ ] SSL certificates valid
- [ ] Performance optimizations applied
- [ ] Security hardening complete
- [ ] Monitoring configured

This comprehensive build guide should help you successfully build Camera Companion across all platforms and environments. For additional support, refer to the project documentation or create an issue in the repository.