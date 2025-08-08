const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Add no-cache headers to prevent browser caching issues
app.use((req, res, next) => {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
  next();
});

app.use(express.static('public'));

// Storage for uploaded images
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `debug-${Date.now()}-${file.originalname}`);
  }
});

const upload = multer({ storage: storage, limits: { fileSize: 50 * 1024 * 1024 } });

// Debug state
let debugState = {
  connectedDevices: new Map(),
  cameraEvents: [],
  aiProcessingLogs: [],
  performanceMetrics: [],
  lastHeartbeat: {}
};

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`Debug client connected: ${socket.id}`);
  
  // Send current debug state to new client
  socket.emit('debug-state', {
    connectedDevices: Array.from(debugState.connectedDevices.values()),
    cameraEvents: debugState.cameraEvents.slice(-50), // Last 50 events
    aiProcessingLogs: debugState.aiProcessingLogs.slice(-50),
    performanceMetrics: debugState.performanceMetrics.slice(-20)
  });
  
  socket.on('disconnect', () => {
    console.log(`Debug client disconnected: ${socket.id}`);
  });
});

// Routes

// Debug dashboard
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'camera-control.html'));
});

// Camera control dashboard
app.get('/camera', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'camera-control.html'));
});

// AI testing dashboard
app.get('/ai-testing', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'ai-testing.html'));
});

// Mobile device registration
app.post('/api/debug/register-device', (req, res) => {
  const { deviceId, deviceInfo } = req.body;
  
  debugState.connectedDevices.set(deviceId, {
    id: deviceId,
    info: deviceInfo,
    connectedAt: new Date().toISOString(),
    lastSeen: new Date().toISOString()
  });
  
  debugState.lastHeartbeat[deviceId] = Date.now();
  
  // Broadcast to debug clients
  io.emit('device-connected', {
    deviceId,
    deviceInfo,
    connectedAt: new Date().toISOString()
  });
  
  console.log(`Mobile device registered: ${deviceId}`);
  res.json({ success: true, registered: true });
});

// Device heartbeat
app.post('/api/debug/heartbeat', (req, res) => {
  const { deviceId } = req.body;
  
  if (debugState.connectedDevices.has(deviceId)) {
    const device = debugState.connectedDevices.get(deviceId);
    device.lastSeen = new Date().toISOString();
    debugState.lastHeartbeat[deviceId] = Date.now();
    
    io.emit('device-heartbeat', { deviceId, timestamp: device.lastSeen });
  }
  
  res.json({ success: true });
});

// Camera events logging
app.post('/api/debug/camera-event', (req, res) => {
  const event = {
    id: Date.now().toString(),
    timestamp: new Date().toISOString(),
    deviceId: req.body.deviceId,
    event: req.body.event,
    data: req.body.data
  };
  
  debugState.cameraEvents.push(event);
  
  // Keep only last 100 events
  if (debugState.cameraEvents.length > 100) {
    debugState.cameraEvents = debugState.cameraEvents.slice(-100);
  }
  
  // Broadcast to debug clients
  io.emit('camera-event', event);
  
  console.log(`Camera event from ${event.deviceId}: ${event.event}`);
  res.json({ success: true });
});

// AI processing logs
app.post('/api/debug/ai-processing', (req, res) => {
  const log = {
    id: Date.now().toString(),
    timestamp: new Date().toISOString(),
    deviceId: req.body.deviceId,
    operation: req.body.operation,
    duration: req.body.duration,
    confidence: req.body.confidence,
    suggestions: req.body.suggestions,
    error: req.body.error
  };
  
  debugState.aiProcessingLogs.push(log);
  
  // Keep only last 100 logs
  if (debugState.aiProcessingLogs.length > 100) {
    debugState.aiProcessingLogs = debugState.aiProcessingLogs.slice(-100);
  }
  
  // Broadcast to debug clients
  io.emit('ai-processing-log', log);
  
  console.log(`AI processing from ${log.deviceId}: ${log.operation} (${log.duration}ms)`);
  res.json({ success: true });
});

// Performance metrics
app.post('/api/debug/performance', (req, res) => {
  const metric = {
    id: Date.now().toString(),
    timestamp: new Date().toISOString(),
    deviceId: req.body.deviceId,
    metric: req.body.metric,
    value: req.body.value,
    unit: req.body.unit
  };
  
  debugState.performanceMetrics.push(metric);
  
  // Keep only last 200 metrics
  if (debugState.performanceMetrics.length > 200) {
    debugState.performanceMetrics = debugState.performanceMetrics.slice(-200);
  }
  
  // Broadcast to debug clients
  io.emit('performance-metric', metric);
  
  res.json({ success: true });
});

// Image upload for analysis
app.post('/api/debug/upload-image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image uploaded' });
    }
    
    const { deviceId, metadata } = req.body;
    
    // Generate thumbnail
    const thumbnailPath = req.file.path.replace('.', '-thumb.');
    await sharp(req.file.path)
      .resize(300, 300, { fit: 'inside' })
      .jpeg({ quality: 80 })
      .toFile(thumbnailPath);
    
    // Get image info
    const imageInfo = await sharp(req.file.path).metadata();
    
    const imageData = {
      id: Date.now().toString(),
      timestamp: new Date().toISOString(),
      deviceId,
      originalPath: req.file.path,
      thumbnailPath,
      filename: req.file.filename,
      size: req.file.size,
      metadata: JSON.parse(metadata || '{}'),
      imageInfo: {
        width: imageInfo.width,
        height: imageInfo.height,
        format: imageInfo.format,
        channels: imageInfo.channels
      }
    };
    
    // Broadcast to debug clients
    io.emit('image-uploaded', imageData);
    
    console.log(`Image uploaded from ${deviceId}: ${req.file.filename}`);
    res.json({ 
      success: true, 
      imageId: imageData.id,
      thumbnailUrl: `/uploads/${path.basename(thumbnailPath)}`
    });
    
  } catch (error) {
    console.error('Image upload error:', error);
    res.status(500).json({ error: 'Failed to process image' });
  }
});

// Serve uploaded files
app.use('/uploads', express.static('uploads'));

// Get debug state
app.get('/api/debug/state', (req, res) => {
  res.json({
    connectedDevices: Array.from(debugState.connectedDevices.values()),
    cameraEvents: debugState.cameraEvents.slice(-50),
    aiProcessingLogs: debugState.aiProcessingLogs.slice(-50),
    performanceMetrics: debugState.performanceMetrics.slice(-20),
    stats: {
      totalEvents: debugState.cameraEvents.length,
      totalAiLogs: debugState.aiProcessingLogs.length,
      totalMetrics: debugState.performanceMetrics.length,
      activeDevices: debugState.connectedDevices.size
    }
  });
});

// Clear debug data
app.post('/api/debug/clear', (req, res) => {
  const { type } = req.body;
  
  switch (type) {
    case 'events':
      debugState.cameraEvents = [];
      break;
    case 'ai-logs':
      debugState.aiProcessingLogs = [];
      break;
    case 'performance':
      debugState.performanceMetrics = [];
      break;
    case 'all':
      debugState.cameraEvents = [];
      debugState.aiProcessingLogs = [];
      debugState.performanceMetrics = [];
      break;
  }
  
  io.emit('debug-cleared', { type });
  res.json({ success: true, cleared: type });
});

// Clean up stale devices (devices that haven't sent heartbeat in 5 minutes)
setInterval(() => {
  const now = Date.now();
  const staleDevices = [];
  
  for (const [deviceId, lastHeartbeat] of Object.entries(debugState.lastHeartbeat)) {
    if (now - lastHeartbeat > 5 * 60 * 1000) { // 5 minutes
      staleDevices.push(deviceId);
    }
  }
  
  staleDevices.forEach(deviceId => {
    debugState.connectedDevices.delete(deviceId);
    delete debugState.lastHeartbeat[deviceId];
    io.emit('device-disconnected', { deviceId });
    console.log(`Removed stale device: ${deviceId}`);
  });
}, 60000); // Check every minute

server.listen(PORT, () => {
  console.log(`Lens AI Debug Server running on http://localhost:${PORT}`);
  console.log(`WebSocket server ready for mobile device connections`);
});