# Platform-Specific Custom Prompt Testing Guide

## ✅ **Platform Coverage**

The custom prompt functionality now works consistently across **all platforms**:

- ✅ **Web (Browser)** - Chrome, Safari, Firefox, Edge
- ✅ **iOS** - iPhone, iPad (native Flutter app)
- ✅ **Android** - Phone, Tablet (native Flutter app)
- ✅ **macOS** - Desktop (for development/testing)
- ✅ **Windows/Linux** - Desktop (for development/testing)

---

## 🧪 **Platform-Specific Testing**

### 📱 **iOS Testing**

**How to Test:**
1. Build for iOS: `flutter build ios --debug`
2. Deploy to iPhone/iPad or iOS Simulator
3. Open AI Settings → Prompts tab
4. Try these iOS-specific prompts:

**iOS-Optimized Prompts:**
```
Professional iOS portrait photography with depth effects.
Use iOS Night mode for low light conditions.
Take advantage of iOS computational photography features.
```

**Expected iOS-Specific Suggestions:**
- ✅ **iOS Portrait Mode** - Depth sensing and bokeh effects
- ✅ **iOS Night Mode** - Computational photography for low light
- ✅ **iOS Processing Optimization** - Faster 200ms processing delay
- ✅ **Platform Indicator** - Shows "(iOS)" in custom prompt note

---

### 🤖 **Android Testing**

**How to Test:**
1. Build for Android: `flutter build android --debug`
2. Deploy to Android device or emulator
3. Open AI Settings → Prompts tab
4. Try these Android-specific prompts:

**Android-Optimized Prompts:**
```
Professional Android Pro mode manual controls.
Use Android AI scene detection for automatic optimization.
Advanced manual camera settings for Android photography.
```

**Expected Android-Specific Suggestions:**
- ✅ **Android Pro Mode** - Manual controls and histogram display
- ✅ **Android AI Scene Detection** - Automatic scene optimization
- ✅ **Android Processing** - 250ms processing delay for compatibility
- ✅ **Platform Indicator** - Shows "(Android)" in custom prompt note

---

### 🌐 **Web Testing**

**How to Test:**
1. Build for web: `flutter build web --debug`
2. Serve locally: `flutter run -d chrome` or `flutter run -d web-server`
3. Open in browser (Chrome, Safari, Firefox, Edge)
4. Try these web-specific prompts:

**Web-Optimized Prompts:**
```
Web browser photography with composition focus.
Optimize camera settings for web capture and desktop use.
Browser-based photography with limited hardware controls.
```

**Expected Web-Specific Suggestions:**
- ✅ **Web Image Optimization** - JPEG format, 85% quality
- ✅ **Web Camera Composition** - Focus on framing (hardware limitations)
- ✅ **Web Processing** - Faster 150ms processing for responsiveness
- ✅ **Platform Indicator** - Shows "(Web)" in custom prompt note

---

## 🔄 **Cross-Platform Consistency**

### **Universal Features (All Platforms):**
- ✅ **Custom Prompt Processing** - Keyword detection system
- ✅ **Technical Suggestions** - ISO, aperture, exposure compensation
- ✅ **Creative Suggestions** - Bokeh, white balance, artistic effects
- ✅ **Advanced Settings** - HDR, stabilization, focus modes
- ✅ **Settings Persistence** - Custom prompts saved across sessions

### **Platform-Aware Adaptations:**
- ✅ **Processing Speed** - Optimized delays per platform
- ✅ **Feature Availability** - Platform-specific camera capabilities
- ✅ **UI Responsiveness** - Tailored for each platform's performance
- ✅ **Platform Identification** - Clear platform indicators in suggestions

---

## 🚀 **Universal Test Prompts**

These prompts work on **all platforms** and generate comprehensive suggestions:

### **Comprehensive Test Prompt:**
```
Professional technical analysis with creative suggestions.
Include HDR, focus, stabilization, flash, and composition recommendations.
Optimize for current platform capabilities and scene conditions.
```

### **Expected Results (All Platforms):**
- **8-15+ suggestions** (vs 3-4 default)
- **Technical settings**: ISO, aperture, exposure compensation
- **Advanced features**: HDR, stabilization, focus modes  
- **Creative options**: Bokeh, artistic white balance
- **Platform-specific**: iOS Portrait/Night mode, Android Pro mode, Web composition
- **Custom prompt note**: Shows platform and template used

---

## 🔧 **Platform Build Commands**

### **iOS:**
```bash
flutter build ios --debug
flutter run -d ios
```

### **Android:**
```bash
flutter build android --debug  
flutter run -d android
```

### **Web:**
```bash
flutter build web --debug
flutter run -d chrome
flutter run -d web-server --port 8080
```

### **macOS (Development):**
```bash
flutter build macos --debug
flutter run -d macos
```

---

## ✅ **Verification Checklist**

For each platform, verify:

- [ ] **Custom prompts save and load correctly**
- [ ] **Platform detection works** (check custom prompt note)
- [ ] **Platform-specific suggestions appear** (iOS/Android/Web features)
- [ ] **Processing speed feels appropriate** for platform
- [ ] **All universal features work** (technical, creative, advanced)
- [ ] **Settings persist** after app restart
- [ ] **UI responds smoothly** to prompt changes

---

## 🐛 **Platform-Specific Troubleshooting**

### **iOS Issues:**
- Ensure iOS deployment target is compatible
- Check camera permissions in iOS Settings
- Verify iOS simulator has camera access

### **Android Issues:**
- Check Android SDK version compatibility  
- Verify camera permissions in app settings
- Test on both physical device and emulator

### **Web Issues:**
- Enable camera permissions in browser
- Test on multiple browsers (Chrome, Safari, Firefox)
- Check browser console for any JavaScript errors
- Ensure HTTPS for camera access (production)

### **Universal Issues:**
- Clear app data/cache and restart
- Check Flutter version compatibility
- Verify all dependencies are up to date

---

The custom prompt functionality is now **fully cross-platform** and optimized for each platform's unique capabilities! 🎉📱💻🌐