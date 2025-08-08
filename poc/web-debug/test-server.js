const express = require('express');
const app = express();
const PORT = 3003;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Lens AI Debug Dashboard - TEST</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .container { max-width: 800px; margin: 0 auto; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔧 Lens AI Debug Dashboard</h1>
            <p>✅ Server is running successfully on port ${PORT}!</p>
            <p>This is a test version to verify connectivity.</p>
            <hr>
            <h2>Backend Status</h2>
            <button onclick="testBackend()">Test Backend Connection</button>
            <div id="backend-status"></div>
            
            <h2>Test API</h2>
            <button onclick="testAPI()">Test Debug API</button>
            <div id="api-status"></div>
        </div>
        
        <script>
            async function testBackend() {
                const status = document.getElementById('backend-status');
                status.innerHTML = 'Testing backend connection...';
                
                try {
                    const response = await fetch('http://localhost:3000/api/camera/status');
                    const data = await response.json();
                    status.innerHTML = '<p style="color: green;">✅ Backend connected successfully!</p><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    status.innerHTML = '<p style="color: red;">❌ Backend connection failed: ' + error.message + '</p>';
                }
            }
            
            async function testAPI() {
                const status = document.getElementById('api-status');
                status.innerHTML = 'Testing debug API...';
                
                try {
                    const response = await fetch('/api/debug/state');
                    const data = await response.json();
                    status.innerHTML = '<p style="color: green;">✅ Debug API working!</p><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    status.innerHTML = '<p style="color: red;">❌ API test failed: ' + error.message + '</p>';
                }
            }
        </script>
    </body>
    </html>
  `);
});

app.get('/api/debug/state', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Debug server is working',
    timestamp: new Date().toISOString(),
    connectedDevices: [],
    stats: {
      totalEvents: 0,
      totalAiLogs: 0,
      activeDevices: 0
    }
  });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`✅ Test Debug Server running on http://localhost:${PORT}`);
  console.log(`🌐 Open your browser to: http://localhost:${PORT}`);
});