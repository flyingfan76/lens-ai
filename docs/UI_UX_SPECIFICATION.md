# Lens AI Mobile App - UI/UX Specification

## Overview
Lens AI is an AI-powered mobile camera control and photography assistant. The interface should be intuitive, modern, and photography-focused with easy access to camera controls and AI features.

## Design Principles
- **Photography-First**: Interface designed around camera viewfinder and shooting experience
- **AI-Powered**: Seamless integration of AI suggestions and automation
- **Professional Yet Accessible**: Appeals to both amateur and professional photographers
- **Gesture-Friendly**: Optimized for one-handed operation while holding camera

## Color Palette
### Primary Colors
- **Primary**: `#6366F1` (Indigo) - Professional, trustworthy
- **Primary Light**: `#A5B4FC` 
- **Primary Dark**: `#4338CA`

### Secondary Colors
- **Accent**: `#F59E0B` (Amber) - Photography/creative energy
- **Success**: `#10B981` (Emerald) - Connected status
- **Warning**: `#F59E0B` (Amber) - Attention needed
- **Error**: `#EF4444` (Red) - Disconnected/error

### Neutral Colors
- **Background**: `#FAFAFA` (Light mode), `#0F0F23` (Dark mode)
- **Surface**: `#FFFFFF` (Light), `#1E1E3F` (Dark)
- **Text Primary**: `#111827` (Light), `#F9FAFB` (Dark)
- **Text Secondary**: `#6B7280` (Light), `#9CA3AF` (Dark)

## Typography
- **Primary Font**: SF Pro Display (iOS) / Roboto (Android)
- **Headers**: Bold, 24-32px
- **Body**: Regular, 16px
- **Captions**: Medium, 14px
- **Small Text**: Regular, 12px

## Screen Specifications

### 1. Splash Screen
**Purpose**: App loading and brand introduction
**Duration**: 2-3 seconds
**Elements**:
- Lens AI logo (animated)
- Loading indicator
- "AI-Powered Camera Control" tagline

### 2. Onboarding Flow (3 screens)
**Screen 2.1 - Welcome**
- Hero illustration: Camera + AI brain
- Title: "Welcome to Lens AI"
- Subtitle: "Your intelligent photography companion"
- CTA: "Get Started"

**Screen 2.2 - Camera Connection**
- Illustration: Phone connecting to professional camera
- Title: "Connect Your Camera"
- Subtitle: "Works with Canon, Nikon, Sony, and more"
- Features list with icons
- CTA: "Continue"

**Screen 2.3 - AI Features**
- Illustration: AI analyzing photo composition
- Title: "AI-Powered Assistance"
- Subtitle: "Get real-time suggestions and automatic adjustments"
- Features preview
- CTA: "Start Photography"

### 3. Main Dashboard
**Layout**: Bottom navigation with 4 tabs
**Header**: Status bar with camera connection status

**Navigation Tabs**:
1. **Camera** (Primary) - Live viewfinder
2. **Gallery** - Photo management
3. **Presets** - Style presets and settings
4. **Profile** - User settings and learning

### 4. Camera Control Screen (Main)
**Layout**: Full-screen camera viewfinder simulation

**Top Bar**:
- Connection status indicator (Green dot + camera model)
- Battery level (camera battery)
- Settings gear icon
- Menu hamburger

**Viewfinder Area**:
- Live preview (or placeholder when not connected)
- AI overlay suggestions (composition guides, rule of thirds)
- Focus points and exposure indicators
- Real-time histogram (collapsible)

**Bottom Control Panel**:
- **Primary Actions** (Always visible):
  - Shutter button (large, center)
  - Preview last shot (thumbnail, left)
  - Switch camera mode (right)

- **Secondary Controls** (Swipe up to reveal):
  - ISO, Aperture, Shutter Speed sliders
  - White Balance preset buttons
  - Focus mode toggle
  - Exposure compensation dial

**Side Panels** (Swipe from edges):
- Left: Quick presets carousel
- Right: AI suggestions panel

### 5. Gallery Screen
**Layout**: Grid view with smart organization

**Header**:
- Search bar with AI-powered filtering
- View toggle (Grid/List)
- Sort options (Date, AI Score, Manual rating)

**Content**:
- Photo grid (3x3 or 2x2 toggle)
- Smart albums: "Best Shots", "Recent", "Favorites"
- AI-generated tags for easy filtering
- Sync status indicators

**Photo Detail View**:
- Full-screen photo view
- EXIF data panel (swipe up)
- AI analysis results
- Edit/Share/Delete actions
- Similar photos suggestions

### 6. Presets Screen
**Layout**: Card-based preset library

**Categories**:
- **My Presets**: User-created presets
- **AI Recommended**: Based on shooting history
- **Popular**: Community favorites
- **Professional**: Curated by pros

**Preset Card Design**:
- Preview image showing effect
- Preset name and description
- Creator attribution
- Download/Heart/Share icons
- Settings preview (ISO, Aperture, etc.)

### 7. Profile & Settings Screen
**Sections**:

**User Profile**:
- Avatar and name
- Photography stats (shots taken, AI improvements)
- Achievement badges

**Camera Settings**:
- Connected cameras list
- Auto-connect preferences
- Calibration tools

**App Preferences**:
- Theme (Light/Dark/Auto)
- Notification settings
- Storage and sync options
- Tutorial replays

**Learning Center**:
- Photography tips
- AI feature explanations
- Video tutorials
- Community forums link

## User Workflows

### Workflow 1: First-Time Camera Connection
1. User opens app → Onboarding
2. Complete onboarding → Dashboard
3. Tap "Connect Camera" → Camera detection screen
4. Select camera model → Connection instructions
5. Successful connection → Camera control screen
6. AI calibration prompt → Quick setup wizard
7. Ready to shoot

### Workflow 2: Taking a Photo with AI Assistance
1. Open camera screen → Live viewfinder active
2. AI analyzes scene → Composition suggestions appear
3. User adjusts based on AI hints → Real-time feedback
4. AI suggests optimal settings → User accepts/modifies
5. Tap shutter → Photo captured and analyzed
6. AI provides post-shot analysis → Save to gallery

### Workflow 3: Using Style Presets
1. Navigate to Presets tab → Browse categories
2. Select interesting preset → Preview applied
3. Tap "Apply" → Settings sent to camera
4. Return to camera screen → Preset active
5. Take photos with preset → Consistent style maintained

### Workflow 4: Gallery Management with AI
1. Open Gallery tab → Smart-organized photos
2. AI highlights "Best Shots" → Review suggestions
3. Search by AI tags → Quick filtering
4. Select photos for editing → Batch operations
5. AI suggests improvements → Apply enhancements
6. Share to social media → Optimized for platform

## Interactive Elements

### Gestures
- **Pinch to zoom**: Adjust camera zoom
- **Double tap**: Auto-focus on point
- **Swipe left/right**: Switch between modes
- **Swipe up**: Access advanced controls
- **Long press**: Lock focus/exposure
- **Two-finger rotate**: Adjust horizon level

### Haptic Feedback
- **Light tap**: Button presses
- **Medium tap**: Photo capture confirmation
- **Success pattern**: Connection established
- **Warning pattern**: Low battery/error states

### Animations
- **Smooth transitions**: Between screens (300ms ease-out)
- **Micro-interactions**: Button press states
- **Loading states**: Skeleton screens while loading
- **Success celebrations**: Achievement unlocks

## Responsive Design

### Mobile Sizes
- **Small phones**: 5.4" (iPhone 12 mini)
- **Standard phones**: 6.1" (iPhone 14)
- **Large phones**: 6.7" (iPhone 14 Pro Max)
- **Tablets**: iPad and Android tablets (future)

### Orientation Support
- **Portrait**: Primary interface
- **Landscape**: Camera control optimized for landscape shooting

## Accessibility Features
- **VoiceOver/TalkBack**: Full screen reader support
- **Dynamic Type**: Respects system font size settings
- **High Contrast**: Enhanced contrast mode
- **Voice Commands**: "Take photo", "Switch mode", etc.
- **Large Touch Targets**: Minimum 44px tap areas

## Error States & Edge Cases

### Connection Issues
- **No Camera Detected**: Clear instructions with troubleshooting
- **Connection Lost**: Automatic reconnection with progress indicator
- **Incompatible Camera**: Alternative options and workarounds

### Network Issues
- **Offline Mode**: Local functionality with sync when available
- **Slow Connection**: Progressive loading with placeholders
- **Failed Uploads**: Retry mechanisms with user notification

### Storage Issues
- **Low Storage**: Smart cleanup suggestions
- **Full Gallery**: Archive/backup recommendations
- **Sync Failures**: Manual retry options

## Performance Requirements
- **App Launch**: < 3 seconds cold start
- **Camera Connection**: < 5 seconds
- **Photo Capture**: < 1 second lag
- **Gallery Loading**: Progressive, no blocking
- **Smooth Animations**: 60fps target

## Future Enhancements
- **AR Overlay**: Composition guides in camera view
- **Social Features**: Photo sharing community
- **Advanced AI**: Scene recognition and auto-presets
- **Professional Tools**: Focus stacking, HDR bracketing
- **Cloud Integration**: Cross-device sync and backup

---

This specification serves as the foundation for implementing the Lens AI mobile app interface. Each screen should be implemented iteratively, starting with the core camera functionality and expanding to advanced features.