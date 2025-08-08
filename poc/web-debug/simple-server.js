const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3002;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static('public'));

// Debug state
let debugState = {
  connectedDevices: new Map(),
  cameraEvents: [],
  aiProcessingLogs: [],
  performanceMetrics: [],
  lastHeartbeat: {}
};

// Routes
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Lens AI Debug Dashboard</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { 
                font-family: Arial, sans-serif; 
                margin: 20px; 
                background: #f5f5f5; 
            }
            .container { 
                max-width: 1200px; 
                margin: 0 auto; 
                background: white; 
                padding: 20px; 
                border-radius: 8px; 
                box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
            }
            .header { 
                text-align: center; 
                margin-bottom: 30px; 
                padding-bottom: 20px; 
                border-bottom: 2px solid #eee; 
            }
            .section { 
                margin: 20px 0; 
                padding: 15px; 
                border: 1px solid #ddd; 
                border-radius: 5px; 
            }
            .section h3 { 
                margin-top: 0; 
                color: #333; 
            }
            .device { 
                background: #e8f5e8; 
                padding: 10px; 
                margin: 5px 0; 
                border-radius: 3px; 
            }
            .event { 
                background: #f0f8ff; 
                padding: 8px; 
                margin: 3px 0; 
                border-radius: 3px; 
                font-size: 12px; 
            }
            .ai-log { 
                background: #fff0f5; 
                padding: 8px; 
                margin: 3px 0; 
                border-radius: 3px; 
                font-size: 12px; 
            }
            .status { 
                display: inline-block; 
                padding: 2px 8px; 
                border-radius: 10px; 
                font-size: 11px; 
                color: white; 
            }
            .status.online { background: #28a745; }
            .status.offline { background: #dc3545; }
            .btn { 
                background: #007bff; 
                color: white; 
                border: none; 
                padding: 8px 16px; 
                border-radius: 4px; 
                cursor: pointer; 
                margin: 5px; 
            }
            .btn:hover { background: #0056b3; }
            .api-section { 
                background: #f8f9fa; 
                padding: 15px; 
                border-radius: 5px; 
                margin: 20px 0; 
            }
            .endpoint { 
                background: #fff; 
                padding: 10px; 
                margin: 5px 0; 
                border-left: 4px solid #007bff; 
                font-family: monospace; 
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🔧 Lens AI Debug Dashboard</h1>
                <p>Real-time monitoring for mobile AI camera features</p>
            </div>

            <div class="section">
                <h3>📱 Connected Mobile Devices</h3>
                <div id="devices">
                    <p>No devices connected yet...</p>
                </div>
            </div>

            <div class="section">
                <h3>📸 Recent Camera Events</h3>
                <div id="camera-events">
                    <p>No camera events yet...</p>
                </div>
            </div>

            <div class="section">
                <h3>🤖 AI Processing Logs</h3>
                <div id="ai-logs">
                    <p>No AI processing logs yet...</p>
                </div>
            </div>

            <div class="api-section">
                <h3>🔌 Available Features</h3>
                <div class="endpoint"><a href="/camera" target="_blank" style="color: #007bff; text-decoration: none;">📷 Camera Control Dashboard</a> - Control connected cameras</div>
                <div class="endpoint">POST /api/debug/register-device - Register mobile device</div>
                <div class="endpoint">POST /api/debug/ai-processing - Log AI processing events</div>
                <div class="endpoint">POST /api/debug/camera-event - Log camera events</div>
                <div class="endpoint">GET /api/debug/state - Get current debug state</div>
                <div class="endpoint">POST /api/debug/clear - Clear debug data</div>
            </div>

            <div class="section">
                <h3>🎮 Test Controls</h3>
                <button class="btn" onclick="clearLogs()">Clear All Logs</button>
                <button class="btn" onclick="testConnection()">Test Backend Connection</button>
                <button class="btn" onclick="refreshData()">Refresh Data</button>
            </div>
        </div>

        <script>
            // Auto-refresh data every 5 seconds
            setInterval(refreshData, 5000);
            
            async function refreshData() {
                try {
                    const response = await fetch('/api/debug/state');
                    const data = await response.json();
                    
                    updateDevices(data.connectedDevices);
                    updateCameraEvents(data.cameraEvents);
                    updateAILogs(data.aiProcessingLogs);
                } catch (error) {
                    console.error('Failed to refresh data:', error);
                }
            }
            
            function updateDevices(devices) {
                const container = document.getElementById('devices');
                if (devices.length === 0) {
                    container.innerHTML = '<p>No devices connected yet...</p>';
                    return;
                }
                
                container.innerHTML = devices.map(device => \`
                    <div class="device">
                        <strong>\${device.id}</strong> 
                        <span class="status online">ONLINE</span>
                        <br>
                        Platform: \${device.info?.platform || 'Unknown'}
                        <br>
                        Connected: \${new Date(device.connectedAt).toLocaleString()}
                        <br>
                        Last Seen: \${new Date(device.lastSeen).toLocaleString()}
                    </div>
                \`).join('');
            }
            
            function updateCameraEvents(events) {
                const container = document.getElementById('camera-events');
                if (events.length === 0) {
                    container.innerHTML = '<p>No camera events yet...</p>';
                    return;
                }
                
                container.innerHTML = events.slice(-10).reverse().map(event => \`
                    <div class="event">
                        <strong>\${event.event}</strong> from \${event.deviceId}
                        <br>
                        \${new Date(event.timestamp).toLocaleString()}
                        \${event.data ? '<br>Data: ' + JSON.stringify(event.data) : ''}
                    </div>
                \`).join('');
            }
            
            function updateAILogs(logs) {
                const container = document.getElementById('ai-logs');
                if (logs.length === 0) {
                    container.innerHTML = '<p>No AI processing logs yet...</p>';
                    return;
                }
                
                container.innerHTML = logs.slice(-10).reverse().map(log => \`
                    <div class="ai-log">
                        <strong>\${log.operation}</strong> from \${log.deviceId}
                        <br>
                        Duration: \${log.duration}ms | Confidence: \${log.confidence || 'N/A'}
                        <br>
                        \${new Date(log.timestamp).toLocaleString()}
                        \${log.suggestions ? '<br>Suggestions: ' + log.suggestions.length : ''}
                        \${log.error ? '<br><span style="color: red;">Error: ' + log.error + '</span>' : ''}
                    </div>
                \`).join('');
            }
            
            async function clearLogs() {
                try {
                    await fetch('/api/debug/clear', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ type: 'all' })
                    });
                    refreshData();
                    alert('All logs cleared!');
                } catch (error) {
                    alert('Failed to clear logs: ' + error.message);
                }
            }
            
            async function testConnection() {
                try {
                    const response = await fetch('http://localhost:3000/api/camera/status');
                    const data = await response.json();
                    alert('Backend connection successful! Camera service status: ' + JSON.stringify(data));
                } catch (error) {
                    alert('Backend connection failed: ' + error.message);
                }
            }
            
            // Load initial data
            refreshData();
        </script>
    </body>
    </html>
  `);
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
  
  console.log(`📱 Mobile device registered: ${deviceId} (${deviceInfo?.platform || 'Unknown'})`);
  res.json({ success: true, registered: true });
});

// Device heartbeat
app.post('/api/debug/heartbeat', (req, res) => {
  const { deviceId } = req.body;
  
  if (debugState.connectedDevices.has(deviceId)) {
    const device = debugState.connectedDevices.get(deviceId);
    device.lastSeen = new Date().toISOString();
    debugState.lastHeartbeat[deviceId] = Date.now();
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
  
  console.log(`📸 Camera event from ${event.deviceId}: ${event.event}`);
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
    error: req.body.error,
    provider: req.body.provider,
    model: req.body.model
  };
  
  debugState.aiProcessingLogs.push(log);
  
  // Keep only last 100 logs
  if (debugState.aiProcessingLogs.length > 100) {
    debugState.aiProcessingLogs = debugState.aiProcessingLogs.slice(-100);
  }
  
  console.log(`🤖 AI processing from ${log.deviceId}: ${log.operation} (${log.duration}ms) - Provider: ${log.provider || 'Local'}`);
  res.json({ success: true });
});

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
  
  console.log(`🧹 Debug data cleared: ${type}`);
  res.json({ success: true, cleared: type });
});

// Camera control dashboard
app.get('/camera', (req, res) => {
  try {
    res.sendFile(path.join(__dirname, 'public', 'camera-control.html'));
  } catch (error) {
    console.error('Error serving camera control dashboard:', error);
    res.status(500).send('Error loading camera control dashboard');
  }
});

// Test endpoint for AI providers
app.post('/api/debug/test-ai-provider', (req, res) => {
  const { provider, apiKey, model } = req.body;
  
  console.log(`🧪 Testing AI provider: ${provider} with model: ${model}`);
  
  // Simulate AI provider test
  setTimeout(() => {
    const success = apiKey && apiKey.length > 10; // Simple validation
    
    const testLog = {
      id: Date.now().toString(),
      timestamp: new Date().toISOString(),
      deviceId: 'debug-server',
      operation: 'provider-test',
      duration: Math.floor(Math.random() * 1000) + 500,
      confidence: success ? 0.95 : 0,
      suggestions: success ? ['Test successful', 'Provider is responding'] : [],
      error: success ? null : 'Invalid API key or connection failed',
      provider: provider,
      model: model
    };
    
    debugState.aiProcessingLogs.push(testLog);
    
    res.json({ 
      success: success, 
      message: success ? 'AI provider test successful' : 'AI provider test failed',
      testLog: testLog
    });
  }, 1000);
});

// Clean up stale devices
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
    console.log(`🔌 Removed stale device: ${deviceId}`);
  });
}, 60000); // Check every minute

server.listen(PORT, () => {
  console.log(`🔧 Lens AI Debug Server running on http://localhost:${PORT}`);
  console.log(`📊 Debug dashboard available at http://localhost:${PORT}`);
  console.log(`🔌 Ready to receive mobile device connections`);
  console.log('');
  console.log('📱 To connect mobile app, enable Online AI and it will automatically register with this debug server');
  console.log('🌐 Open your browser to: http://localhost:' + PORT);
});