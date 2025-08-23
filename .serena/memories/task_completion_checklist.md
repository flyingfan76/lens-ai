# Task Completion Checklist

## When a Development Task is Completed

### 1. Code Quality Checks
```bash
# MANDATORY: Run these commands after any code changes
flutter analyze          # Static analysis - MUST pass
dart format lib/ test/   # Code formatting
flutter test            # Unit tests - MUST pass
```

### 2. Platform-Specific Testing
```bash
# For macOS external camera features (primary platform)
flutter run -d macos --verbose

# For mobile platforms (if applicable)  
flutter run -d ios --debug
flutter run -d android --debug
```

### 3. Build Verification
```bash
# Verify builds work for target platforms
flutter build macos --debug     # macOS desktop
flutter build ios --debug       # iOS (if changes affect mobile)
flutter build android --debug   # Android (if changes affect mobile)
```

### 4. Integration Testing
```bash
# Run integration tests if they exist
flutter test integration_test/

# Manual testing checklist:
# - Camera detection works
# - Live view starts successfully  
# - AI suggestions generate properly
# - Settings persist correctly
```

### 5. Documentation Updates
- Update relevant README files if significant features added
- Update CLAUDE.md if new commands or workflows introduced
- **Only create documentation if explicitly requested by user**

### 6. Git Workflow
```bash
# Standard commit process (only if user requests)
git add .
git commit -m "feat: descriptive commit message"
# DO NOT push unless explicitly requested
```

## Critical Requirements

### Before Marking Task Complete
- [ ] `flutter analyze` passes without errors
- [ ] `flutter test` passes all tests
- [ ] Code builds successfully on target platform(s)
- [ ] Manual testing confirms functionality works
- [ ] No debugging print statements left in production code

### Platform-Specific Considerations
- **macOS**: Primary platform for external camera features
- **iOS/Android**: Secondary platforms, mainly for mobile camera and AI features
- **Web**: Development/POC only, not production target

### Quality Gates
1. **Analysis**: Zero critical errors in `flutter analyze`
2. **Testing**: All unit tests must pass
3. **Build**: Clean build with no compilation errors
4. **Function**: Manual verification of implemented features
5. **Performance**: No obvious performance regressions

## DO NOT DO These Actions
- **DO NOT** create documentation files unless explicitly requested
- **DO NOT** commit or push code unless user explicitly asks
- **DO NOT** add comments to code unless user specifically requests them
- **DO NOT** run commands that modify system configuration