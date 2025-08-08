# Lens AI Debug Web Application

A web-based debugging tool for the Lens AI mobile application. This provides real-time monitoring of camera events, AI processing, and performance metrics during development.

## Features

### 📱 Device Monitoring
- Real-time device connection status
- Device registration and heartbeat tracking
- Multiple device support for testing

### 📷 Camera Event Logging
- Camera initialization and connection events
- Settings changes and capture events
- Real-time event streaming to debug dashboard

### 🧠 AI Processing Insights
- Local AI model performance monitoring
- Suggestion confidence tracking
- Processing time analysis
- Error logging and debugging

### ⚡ Performance Metrics
- Memory usage tracking
- Processing time measurements
- Frame rate monitoring
- Resource utilization alerts

### 🖥️ Web Dashboard
- Real-time updates via WebSocket
- Tabbed interface for different log types
- Device management sidebar
- Log filtering and clearing

## Quick Start

### Installation
```bash
cd web-debug
npm install
```

### Development
```bash
npm run dev  # Uses nodemon for auto-reload
```

### Production
```bash
npm start
```

The debug server will run on `http://localhost:3001`

## Mobile Integration

The mobile app can send debug information to this server using HTTP endpoints:

### Device Registration
```dart
POST /api/debug/register-device
{
  "deviceId": "unique-device-id",
  "deviceInfo": {
    "model": "iPhone 15 Pro",
    "platform": "iOS",
    "version": "17.1"
  }
}
```

### Camera Events
```dart
POST /api/debug/camera-event
{
  "deviceId": "device-id",
  "event": "camera_connected",
  "data": { "cameraId": "mobile_camera_0" }
}
```

### AI Processing Logs
```dart
POST /api/debug/ai-processing
{
  "deviceId": "device-id", 
  "operation": "scene_analysis",
  "duration": 150,
  "confidence": 0.85,
  "suggestions": [...]
}
```

### Performance Metrics
```dart
POST /api/debug/performance
{
  "deviceId": "device-id",
  "metric": "memory_usage", 
  "value": 45.2,
  "unit": "MB"
}
```

## Usage in Mobile App

Add debug service integration to your mobile app for development builds:

```dart
class DebugService {
  static const bool enabled = kDebugMode;
  static const String serverUrl = 'http://localhost:3001';
  
  static Future<void> logCameraEvent(String event, Map<String, dynamic> data) async {
    if (!enabled) return;
    
    try {
      await http.post(
        Uri.parse('$serverUrl/api/debug/camera-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': await _getDeviceId(),
          'event': event,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('Debug log failed: $e');
    }
  }
}
```

## Architecture

### Backend (Node.js/Express)
- Express server with WebSocket support
- File upload handling for image analysis
- In-memory debug state management
- RESTful API for mobile communication

### Frontend (Vanilla HTML/JS)
- Real-time dashboard with Socket.IO
- Responsive design for desktop debugging
- Tab-based organization of different log types
- Device management and statistics

### Mobile Integration
- HTTP-based logging (no WebSocket needed on mobile)
- Lightweight debug payload to minimize performance impact
- Conditional compilation for release builds

## Configuration

### Environment Variables
- `PORT`: Server port (default: 3001)
- `NODE_ENV`: Environment mode

### Debug Categories
- Camera events: Connection, settings, capture
- AI processing: Model loading, inference, suggestions
- Performance: Memory, CPU, timing metrics
- Device management: Registration, heartbeat, status

## Development Notes

### Mobile-First Approach
- This debug tool is designed specifically for the mobile-first architecture
- No external camera debugging (focused on mobile camera provider)
- Local AI processing monitoring and optimization

### Performance Considerations
- Debug logging only enabled in development builds
- Minimal payload sizes for mobile communication
- Efficient in-memory storage with automatic cleanup
- Non-blocking async operations

### Future Enhancements
- Performance visualization charts
- Export logs to file
- Log filtering and search
- Alert system for performance thresholds
- Image analysis visualization