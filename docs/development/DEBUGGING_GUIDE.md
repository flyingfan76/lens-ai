# 🐛 Debugging Guide for Camera Companion on Mac

This comprehensive guide will help you set up and use debugging for the Camera Companion project on macOS.

## 🚀 Quick Start Debugging

### Prerequisites Setup

1. **Install Required Tools**:
   ```bash
   # Install Node.js (if not installed)
   brew install node
   
   # Install Flutter (if not installed)
   brew install --cask flutter
   
   # Install Python 3.9+ (if not installed)
   brew install python@3.9
   
   # Install Docker (for services)
   brew install --cask docker
   
   # Install VSCode extensions
   code --install-extension ms-vscode.vscode-json
   code --install-extension ms-python.python
   code --install-extension dart-code.flutter
   code --install-extension ms-vscode.node-debug2
   ```

2. **Project Setup**:
   ```bash
   # Clone and setup the project
   git clone https://github.com/camera-company/camera-companion.git
   cd camera-companion
   
   # Complete setup
   make setup
   
   # Install dependencies
   make install
   ```

### Environment Configuration

1. **Create Environment File**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your configuration**:
   ```bash
   # Backend Configuration
   NODE_ENV=development
   PORT=3000
   MONGODB_URI=mongodb://localhost:27017/camera_companion
   JWT_SECRET=your_development_secret_here
   
   # AI Service Configuration
   AI_SERVICE_URL=http://localhost:8000
   NERF_SERVICE_URL=http://localhost:8001
   
   # Camera SDK Paths (adjust for your system)
   CANON_SDK_PATH=/path/to/canon/sdk
   SONY_API_KEY=your_sony_api_key
   NIKON_SDK_PATH=/path/to/nikon/sdk
   
   # AWS Configuration (for cloud features)
   AWS_ACCESS_KEY_ID=your_aws_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret
   AWS_S3_BUCKET=camera-companion-dev
   
   # Debug Configuration
   DEBUG=camera-companion:*
   LOG_LEVEL=debug
   ```

## 🔧 Backend Debugging

### VSCode Debugging

1. **Open VSCode** in the project root:
   ```bash
   code .
   ```

2. **Start Debugging**:
   - Press `F5` or go to Run & Debug panel
   - Select "🔧 Debug Backend API" from the dropdown
   - Click the green play button

3. **Debug Features Available**:
   - **Breakpoints**: Click in the gutter next to line numbers
   - **Watch Variables**: Add variables to the Watch panel
   - **Call Stack**: View the execution stack
   - **Debug Console**: Execute JavaScript expressions

### Alternative Debugging Options

#### Option 1: Debug with Nodemon (Auto-restart)
```bash
# In VSCode Debug panel, select:
"🔧 Debug Backend with Nodemon"
```

#### Option 2: Command Line Debugging
```bash
# Start backend with debugging enabled
cd backend
npm run dev

# Or with Node.js built-in debugger
node --inspect=0.0.0.0:9229 src/app.js
```

#### Option 3: Test Debugging
```bash
# Debug backend tests
# In VSCode Debug panel, select:
"🧪 Debug Backend Tests"
```

### Debugging Specific Services

#### Camera Auto Detector
```bash
# Debug camera detection issues
# In VSCode Debug panel, select:
"🔍 Debug Camera Auto Detector"
```

#### Auto Adjustment Service
```bash
# Debug AI-powered parameter adjustment
# In VSCode Debug panel, select:
"🎯 Debug Auto Adjustment Service"
```

### Common Backend Debugging Scenarios

#### 1. Camera Connection Issues
```javascript
// Set breakpoints in these files:
// backend/src/services/camera_manager.js
// backend/src/services/canon_sdk_service.js
// backend/src/services/sony_sdk_service.js

// Debug camera discovery
const cameras = await cameraManager.discoverAllCameras();
console.log('Discovered cameras:', cameras);
```

#### 2. API Endpoint Issues
```javascript
// Set breakpoints in API routes:
// backend/src/api/camera.js
// backend/src/api/auto_adjustment.js

// Check request/response flow
app.post('/api/camera/connect', (req, res) => {
  console.log('Request body:', req.body); // Set breakpoint here
  // ... rest of the handler
});
```

#### 3. Database Connection Issues
```javascript
// Set breakpoints in models:
// backend/src/models/User.js
// backend/src/models/StylePreset.js

// Debug MongoDB queries
const user = await User.findById(userId);
console.log('Found user:', user); // Set breakpoint here
```

## 📱 Flutter/Mobile Debugging

### Flutter Debugging Setup

1. **Connect Device or Start Simulator**:
   ```bash
   # List available devices
   flutter devices
   
   # Start iOS Simulator
   open -a Simulator
   
   # Start Android Emulator
   emulator -avd Pixel_4_API_30
   ```

2. **Start Flutter Debugging**:
   ```bash
   # Method 1: Using VSCode
   # Press F5 and select "📱 Debug Flutter (Attach)"
   
   # Method 2: Command line
   cd mobile
   flutter run --debug
   
   # Method 3: Using VSCode task
   # Ctrl+Shift+P -> "Tasks: Run Task" -> "📱 Start Flutter Hot Reload"
   ```

### Flutter Debugging Features

#### Hot Reload & Hot Restart
```bash
# During debug session:
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'o' for platform override
# Press 'q' to quit
```

#### Debug Console Commands
```dart
// Add debug prints in Dart code
print('Debug: Camera connection status: $status');
debugPrint('Detailed debug info: $details');

// Use Flutter Inspector
flutter inspector
```

### Common Flutter Debugging Scenarios

#### 1. Camera Service Integration
```dart
// Set breakpoints in:
// mobile/lib/core/services/camera_service.dart
// mobile/lib/core/providers/camera_provider.dart

class CameraService {
  Future<List<Camera>> discoverCameras() async {
    print('Starting camera discovery...'); // Set breakpoint here
    // ... rest of the method
  }
}
```

#### 2. State Management Issues
```dart
// Debug provider state changes:
// mobile/lib/core/providers/camera_provider.dart

class CameraProvider extends ChangeNotifier {
  void updateCameraStatus(CameraStatus status) {
    print('Updating camera status: $status'); // Set breakpoint here
    _cameraStatus = status;
    notifyListeners();
  }
}
```

#### 3. UI Widget Issues
```dart
// Debug widget builds and state:
// mobile/lib/widgets/auto_adjustment_widget.dart

class AutoAdjustmentWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    print('Building AutoAdjustmentWidget'); // Set breakpoint here
    return Container(/* ... */);
  }
}
```

## 🤖 AI Service Debugging

### Python Debugging Setup

1. **Start AI Service Debugging**:
   ```bash
   # Method 1: Using VSCode
   # Press F5 and select "🤖 Debug AI Service"
   
   # Method 2: Command line
   cd ai
   python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
   
   # Method 3: Direct Python debugging
   python -m pdb main.py
   ```

2. **NeRF Service Debugging**:
   ```bash
   # Using VSCode
   # Press F5 and select "🧠 Debug NeRF Service"
   
   # Or using the script
   ./scripts/start_nerf_service.sh start --debug
   ```

### Python Debugging Features

#### Breakpoints and Debugging
```python
# Set breakpoints in Python code:
# ai/inference/scene_analyzer.py
# ai/nerf/camera_nerf_analyzer.py

def analyze_scene(image_path):
    print(f"Analyzing image: {image_path}")  # Set breakpoint here
    # ... rest of the method
```

#### Debug Console Usage
```python
# In debug console, you can execute:
# - Variables inspection: locals(), globals()
# - Function calls: analyze_scene("/path/to/image.jpg")
# - Module imports: import torch; torch.cuda.is_available()
```

### Common AI Debugging Scenarios

#### 1. Scene Analysis Issues
```python
# Debug in ai/inference/scene_analyzer.py
class SceneAnalyzer:
    def analyze(self, image_data):
        print(f"Image shape: {image_data.shape}")  # Set breakpoint
        # ... analysis code
```

#### 2. NeRF Model Issues
```python
# Debug in ai/nerf/nerf_model.py
class NeRFModel:
    def forward(self, ray_origins, ray_directions):
        print(f"Processing {len(ray_origins)} rays")  # Set breakpoint
        # ... forward pass
```

#### 3. API Endpoint Issues
```python
# Debug in ai/main.py or ai/nerf/nerf_service.py
@app.post("/analyze")
async def analyze_image(image: UploadFile):
    print(f"Received image: {image.filename}")  # Set breakpoint
    # ... processing
```

## 🔄 Full Stack Debugging

### Multi-Service Debugging

1. **Start All Services in Debug Mode**:
   ```bash
   # Using VSCode compound configuration
   # Press F5 and select "🚀 Debug Full Stack"
   
   # Or manually start each service:
   # Terminal 1: Backend
   cd backend && npm run dev
   
   # Terminal 2: AI Service
   cd ai && python -m uvicorn main:app --reload --port 8000
   
   # Terminal 3: NeRF Service
   ./scripts/start_nerf_service.sh start
   
   # Terminal 4: Frontend (if applicable)
   cd mobile && flutter run
   ```

2. **Debug Communication Between Services**:
   ```javascript
   // Backend to AI service communication
   // Set breakpoints in backend/src/services/nerf_integration_service.js
   
   const analysisResult = await fetch('http://localhost:8000/analyze', {
     method: 'POST',
     body: imageData
   });
   console.log('AI response:', analysisResult); // Set breakpoint here
   ```

### Docker Debugging

1. **Debug Containerized Services**:
   ```bash
   # Start services with debugging enabled
   docker-compose -f docker-compose.debug.yml up
   
   # Attach to running container for debugging
   docker exec -it camera-companion-backend /bin/bash
   ```

2. **Debug Database Issues**:
   ```bash
   # Connect to MongoDB container
   docker exec -it camera-companion-mongo mongosh
   
   # Run database queries
   use camera_companion
   db.users.find({})
   db.cameras.find({})
   ```

## 🛠️ Debugging Tools & Tips

### Performance Debugging

1. **Monitor Application Performance**:
   ```bash
   # Backend performance monitoring
   cd backend
   node --prof src/app.js
   
   # Generate performance report
   node --prof-process isolate-*.log > performance.txt
   ```

2. **Memory Usage Debugging**:
   ```bash
   # Monitor memory usage
   node --inspect --max-old-space-size=4096 src/app.js
   
   # Use Chrome DevTools for memory profiling
   # Open chrome://inspect in Chrome browser
   ```

### Network Debugging

1. **API Request Debugging**:
   ```bash
   # Test API endpoints with curl
   curl -X GET http://localhost:3000/api/camera/discover
   curl -X POST http://localhost:3000/api/camera/connect \
     -H "Content-Type: application/json" \
     -d '{"cameraId": "canon_0"}'
   ```

2. **WebSocket Debugging**:
   ```bash
   # Test WebSocket connections
   npm install -g wscat
   wscat -c ws://localhost:3000/ws/camera/live-view
   ```

### Log Analysis

1. **Backend Logs**:
   ```bash
   # View application logs
   tail -f logs/combined.log
   tail -f logs/error.log
   
   # Filter specific log levels
   grep "ERROR" logs/combined.log
   grep "DEBUG" logs/combined.log
   ```

2. **Service Logs**:
   ```bash
   # AI service logs
   tail -f ai/logs/service.log
   
   # NeRF service logs
   tail -f logs/nerf_service.log
   ```

## 🚨 Common Issues & Solutions

### Backend Issues

#### 1. Port Already in Use
```bash
# Find process using port 3000
lsof -ti:3000
kill -9 $(lsof -ti:3000)

# Or use different port
PORT=3001 npm run dev
```

#### 2. MongoDB Connection Failed
```bash
# Check MongoDB status
brew services list | grep mongodb
brew services start mongodb-community

# Or start Docker MongoDB
docker-compose up mongodb
```

#### 3. Camera SDK Not Found
```bash
# Check SDK paths in .env
CANON_SDK_PATH=/Applications/Canon_SDK/EDSDK
SONY_API_KEY=your_actual_api_key
NIKON_SDK_PATH=/Applications/Nikon_SDK
```

### Flutter Issues

#### 1. Build Failures
```bash
# Clean build cache
cd mobile
flutter clean
flutter pub get
flutter build apk --debug
```

#### 2. Device Not Recognized
```bash
# Check connected devices
flutter devices

# Restart ADB (Android)
adb kill-server
adb start-server

# Reset iOS Simulator
xcrun simctl erase all
```

### AI Service Issues

#### 1. Python Dependencies
```bash
# Reinstall dependencies
cd ai
pip install -r requirements.txt --force-reinstall

# Check CUDA availability
python -c "import torch; print(torch.cuda.is_available())"
```

#### 2. Model Loading Issues
```bash
# Check model files
ls -la ai/models/
python scripts/validate_nerf_setup.py
```

## 📋 Debugging Checklist

### Before Starting Development

- [ ] All services start without errors
- [ ] Environment variables are properly configured
- [ ] Database connection is established
- [ ] Camera SDKs are properly installed
- [ ] VSCode debug configurations work
- [ ] Hot reload functions properly

### During Development

- [ ] Set appropriate breakpoints
- [ ] Use debug console for variable inspection
- [ ] Monitor application logs
- [ ] Test API endpoints manually
- [ ] Verify database state
- [ ] Check service communication

### Troubleshooting Steps

1. **Check service status**: `curl http://localhost:3000/health`
2. **Verify logs**: `tail -f logs/combined.log`
3. **Test database**: Connect to MongoDB
4. **Validate environment**: Check `.env` file
5. **Restart services**: `make docker-down && make dev`

This debugging guide should help you efficiently identify and resolve issues across the entire Camera Companion stack on macOS.