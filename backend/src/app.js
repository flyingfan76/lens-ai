const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const mongoose = require('mongoose');
const logger = require('./utils/logger');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const http = require('http');
const server = http.createServer(app);

const WebSocketService = require('./services/websocket_service');
const webSocketService = new WebSocketService(server);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.use('/api/auth', require('./api/auth'));
// app.use('/api/images', require('./api/images')); // TODO: Create images API
app.use('/api/camera', require('./api/camera'));
app.use('/api/ai', require('./api/ai'));
app.use('/api/presets', require('./api/presets'));
app.use('/api/cloud', require('./api/cloud'));
app.use('/api/auto-adjustment', require('./api/auto_adjustment'));
app.use('/api/education', require('./api/education'));

// Local storage file serving (only in development/local mode)
app.use('/storage', require('./api/storage'));

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

if (process.env.MONGODB_URI) {
  mongoose.connect(process.env.MONGODB_URI)
    .then(() => logger.info('Connected to MongoDB'))
    .catch(err => logger.error('MongoDB connection error:', err));
}

server.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`WebSocket live view available at ws://localhost:${PORT}/liveview`);
});

// Make WebSocket service available to camera routes
app.locals.webSocketService = webSocketService;

// Set up camera manager to WebSocket service integration
const cameraRouter = require('./api/camera');
if (cameraRouter.cameraManager) {
  cameraRouter.cameraManager.on('liveViewFrame', (frameData) => {
    webSocketService.onLiveViewFrame(frameData.data);
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  webSocketService.close();
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

module.exports = { app, server, webSocketService };