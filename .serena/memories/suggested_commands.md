# Development Commands

## Flutter Development Commands

### Running the Application
```bash
# macOS desktop testing (primary for external camera development)
flutter run -d macos --verbose
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d macos

# iOS development
flutter run -d ios --debug
open ios/Runner.xcworkspace  # Open in Xcode

# Android development (requires JDK 17+)
flutter run -d android --debug
flutter doctor  # Check Android setup
```

### Code Quality & Analysis
```bash
# Code analysis and linting
flutter analyze
dart format lib/ test/  # Code formatting
flutter test  # Run unit tests
```

### Building
```bash
# Release builds
flutter build ios --release
flutter build android --release  
flutter build macos --release

# Development builds
flutter build ios --debug
flutter build android --debug
```

### Package Management
```bash
flutter pub get      # Install dependencies
flutter pub upgrade  # Update dependencies
flutter clean        # Clean build artifacts
```

## Project-Specific Commands

### Backend Development (POC)
```bash
cd poc/web-debug && npm install && npm run dev     # Web debug dashboard
cd poc/camera-sdk-backend && npm install && npm start  # Camera SDK testing
```

### Testing & Quality Assurance
```bash
flutter test --coverage                    # Run tests with coverage
flutter test integration_test/            # Run integration tests
dart analyze lib/ test/                   # Static analysis
```

### macOS Platform-Specific
```bash
# Check Xcode setup
xcode-select --print-path
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version

# Simulator management
xcrun simctl list devices available
```

## Git Workflow
```bash
git status           # Check current status
git add .           # Stage changes
git commit -m "feat: description"  # Commit with conventional format
git push origin feature/branch-name  # Push to feature branch
```

## Common Development Tasks
```bash
# Full development setup
flutter pub get && flutter analyze && flutter test

# Clean rebuild
flutter clean && flutter pub get && flutter run -d macos

# Debug with verbose output
flutter run -d macos --verbose --debug
```