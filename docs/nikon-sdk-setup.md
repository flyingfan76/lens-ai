# Nikon SDK Integration Setup

This guide covers setting up real Nikon camera connectivity using the Nikon MAID (Multiple Application Interface for Digital cameras) SDK.

## Prerequisites

### 1. Nikon MAID SDK
- **Download**: Obtain the Nikon MAID SDK from Nikon's developer portal
- **License**: Requires a signed license agreement with Nikon
- **Supported Cameras**: Z series, D850, D780, and newer DSLR/mirrorless cameras
- **Platforms**: Windows, macOS, Linux (x64)

### 2. Development Environment
```bash
# Required tools
node --version    # >= 16.0.0
npm --version     # >= 8.0.0
python --version  # >= 3.8 (for node-gyp)

# Windows additional requirements
# - Visual Studio 2019/2022 with C++ build tools
# - Windows SDK 10

# macOS additional requirements  
# - Xcode Command Line Tools
# - macOS SDK 10.15+

# Linux additional requirements
# - build-essential package
# - libudev-dev libusb-1.0-0-dev
```

## Installation Steps

### 1. Install Nikon MAID SDK

```bash
# Create SDK directory structure
mkdir -p backend/sdk/nikon/{include,lib}

# Extract Nikon MAID SDK files:
# - Copy header files to backend/sdk/nikon/include/
# - Copy library files to backend/sdk/nikon/lib/
#   - Windows: NkMaid.lib, NkMaid.dll
#   - macOS: libNkMaid.dylib  
#   - Linux: libNkMaid.so
```

### 2. Install Native Module Dependencies

```bash
# Navigate to native module directory
cd backend/native/nikon

# Install dependencies
npm install

# Build the native module
npm run build

# Verify build
ls build/Release/nikon_sdk.node
```

### 3. Configure Environment

```bash
# Add to your .env file
NIKON_SDK_PATH=/path/to/nikon/sdk
NIKON_USB_VENDOR_ID=0x04B0  # Nikon USB Vendor ID
NIKON_DISCOVERY_TIMEOUT=5000
```

### 4. Install USB Drivers (Windows)

1. Download Nikon USB drivers from Nikon support
2. Install the drivers for your specific camera model
3. Connect camera via USB and verify it's recognized

### 5. Configure Camera Settings

Enable PC connection on your Nikon camera:
1. **Menu → Setup → Connect to smart device → OFF**
2. **Menu → Setup → USB → MTP/PTP** 
3. **Menu → Custom Functions → Enable PC Connection**

## Usage Examples

### Basic Connection

```javascript
const NikonSDKService = require('./services/nikon_sdk_service');

async function connectNikon() {
  const nikon = new NikonSDKService();
  
  try {
    // Initialize SDK
    await nikon.initialize();
    
    // Discover cameras
    const cameras = await nikon.discoverCameras();
    console.log('Found cameras:', cameras);
    
    // Connect to first camera
    if (cameras.length > 0) {
      const camera = await nikon.connectToCamera(0);
      console.log('Connected to:', camera.model);
      
      // Get camera settings
      const settings = await nikon.getCameraSettings();
      console.log('Current settings:', settings);
    }
    
  } catch (error) {
    console.error('Connection failed:', error);
  }
}
```

### Live View Streaming

```javascript
// Start live view
const liveViewInfo = await nikon.startLiveView();
console.log('Live view started:', liveViewInfo.streamUrl);

// Handle live view frames
nikon.on('liveViewFrame', (frameData) => {
  // Process frame data (JPEG buffer)
  console.log('Frame received:', frameData.frameNumber);
});

// Stop live view
await nikon.stopLiveView();
```

### Remote Capture

```javascript
// Set camera settings
await nikon.setCameraProperty('ISO', 800);
await nikon.setCameraProperty('APERTURE', 'f/2.8');
await nikon.setCameraProperty('SHUTTER_SPEED', '1/250');

// Capture image
const imageInfo = await nikon.captureImage();
console.log('Image captured:', imageInfo.filename);

// Handle image download
nikon.on('imageCaptured', (imageData) => {
  console.log('Image downloaded:', imageData.filename);
  // Process NEF/JPEG file
});
```

## Connection Methods

### USB Connection
- **Requirements**: USB 3.0+ cable, camera in PC mode
- **Advantages**: Fast, reliable, can charge camera
- **Latency**: ~50-100ms for live view
- **Range**: Cable length (max 5m with active cable)

### WiFi Connection (SnapBridge)
- **Requirements**: Camera with WiFi, same network
- **Setup**: Configure camera's WiFi settings
- **Advantages**: Wireless, longer range
- **Latency**: ~200-500ms depending on network
- **Range**: WiFi network range

### Ethernet Connection (Pro Models)
- **Requirements**: Camera with Ethernet port (D6, Z9)
- **Setup**: Configure static IP on camera
- **Advantages**: Most reliable, lowest latency
- **Latency**: ~30-50ms for live view
- **Range**: Network infrastructure dependent

## Supported Camera Models

### Z Mount Mirrorless
- **Z9**: Full support (USB, Ethernet, WiFi)
- **Z8**: Full support (USB, WiFi)  
- **Z7II/Z6II**: Full support (USB, WiFi)
- **Z7/Z6**: Basic support (USB only)
- **Z5**: Basic support (USB, WiFi)
- **Z50**: Basic support (USB, WiFi)

### F Mount DSLR
- **D850**: Full support (USB)
- **D780**: Full support (USB, WiFi)
- **D500**: Basic support (USB, WiFi)
- **D7500**: Basic support (USB, WiFi)

## Troubleshooting

### Camera Not Detected

```bash
# Check USB connection
lsusb | grep -i nikon  # Linux
system_profiler SPUSBDataType | grep -i nikon  # macOS

# Check camera mode
# Ensure camera is in PC connection mode, not smart device mode

# Check drivers (Windows)
# Device Manager → Imaging Devices → Should show Nikon camera
```

### Build Errors

```bash
# Clean and rebuild
cd backend/native/nikon
npm run clean
npm run build

# Check SDK paths in binding.gyp
# Verify library files are in correct locations

# Windows: Check Visual Studio installation
# macOS: Check Xcode Command Line Tools
# Linux: Check build-essential package
```

### Permission Issues (Linux)

```bash
# Add user to camera group
sudo usermod -a -G plugdev $USER

# Create udev rule for Nikon cameras
sudo tee /etc/udev/rules.d/99-nikon-cameras.rules << EOF
SUBSYSTEM=="usb", ATTR{idVendor}=="04b0", MODE="0666", GROUP="plugdev"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Performance Optimization

```javascript
// Optimize live view settings
await nikon.setCameraProperty('LIVE_VIEW_SIZE', 'SMALL');  // Reduce bandwidth
await nikon.setCameraProperty('LIVE_VIEW_QUALITY', 'NORMAL');  // Balance quality/speed

// Batch property updates
const settings = {
  'ISO': 400,
  'APERTURE': 'f/4.0',
  'SHUTTER_SPEED': '1/125'
};
await nikon.updateBulkSettings(settings);
```

## Security Considerations

1. **Camera Access**: Physical access to camera required for initial setup
2. **Network Security**: Use WPA3 for WiFi connections
3. **Firmware Updates**: Keep camera firmware updated
4. **SDK Licensing**: Ensure compliance with Nikon SDK license terms

## API Reference

### Core Methods
- `initialize()` - Initialize MAID SDK
- `discoverCameras()` - Find connected cameras
- `connectToCamera(index)` - Connect to specific camera
- `disconnectCamera()` - Disconnect current camera

### Settings Management  
- `getCameraSettings()` - Get all current settings
- `setCameraProperty(property, value)` - Set individual property
- `getCapabilities()` - Get supported capabilities

### Image Operations
- `startLiveView()` - Begin live view streaming
- `stopLiveView()` - End live view streaming  
- `captureImage(settings)` - Take photo with optional settings
- `downloadImage(objectId)` - Download specific image

### Event Handling
- `on('cameraConnected', callback)` - Camera connection events
- `on('imageCaptured', callback)` - Image capture events
- `on('liveViewFrame', callback)` - Live view frame events
- `on('batteryWarning', callback)` - Low battery warnings

## Support

- **Nikon Developer Portal**: https://developers.nikon.com
- **MAID SDK Documentation**: Included with SDK download
- **Technical Support**: Available with valid SDK license