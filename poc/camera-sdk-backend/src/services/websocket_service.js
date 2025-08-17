const WebSocket = require('ws');
const logger = require('../utils/logger');

class WebSocketService {
  constructor(server) {
    this.wss = new WebSocket.Server({ 
      server,
      path: '/liveview'
    });
    
    this.clients = new Set();
    this.liveViewActive = false;
    this.frameBuffer = null;
    
    // Frame rate limiting
    this.targetFPS = 30;
    this.frameInterval = 1000 / this.targetFPS;
    this.lastFrameTime = 0;
    this.droppedFrames = 0;
    
    // Performance optimizations
    this.clientBuffers = new Map(); // Per-client frame buffers
    this.maxQueueSize = 3; // Maximum frames queued per client
    
    this.setupWebSocketServer();
  }

  setupWebSocketServer() {
    this.wss.on('connection', (ws, req) => {
      logger.info(`Live view client connected from ${req.socket.remoteAddress}`);
      
      this.clients.add(ws);
      this.clientBuffers.set(ws, []); // Initialize client buffer
      
      // Send current frame if available
      if (this.frameBuffer && this.liveViewActive) {
        this.sendFrame(ws, this.frameBuffer);
      }
      
      ws.on('message', (message) => {
        try {
          const data = JSON.parse(message);
          this.handleClientMessage(ws, data);
        } catch (error) {
          logger.error('Invalid WebSocket message:', error);
        }
      });
      
      ws.on('close', () => {
        logger.info('Live view client disconnected');
        this.clients.delete(ws);
        this.clientBuffers.delete(ws); // Clean up client buffer
      });
      
      ws.on('error', (error) => {
        logger.error('WebSocket error:', error);
        this.clients.delete(ws);
        this.clientBuffers.delete(ws); // Clean up client buffer
      });
      
      // Send connection confirmation
      ws.send(JSON.stringify({
        type: 'connection',
        status: 'connected',
        liveViewActive: this.liveViewActive
      }));
    });
    
    logger.info('WebSocket server initialized for live view streaming');
  }

  handleClientMessage(ws, data) {
    switch (data.type) {
      case 'ping':
        ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
        break;
        
      case 'requestFrame':
        if (this.frameBuffer && this.liveViewActive) {
          this.sendFrame(ws, this.frameBuffer);
        }
        break;
        
      case 'quality':
        // Handle quality change requests
        logger.info(`Client requested quality change: ${data.quality}`);
        break;
        
      default:
        logger.warn(`Unknown message type: ${data.type}`);
    }
  }

  startLiveViewStream() {
    this.liveViewActive = true;
    this.broadcastMessage({
      type: 'liveViewStarted',
      timestamp: Date.now()
    });
    
    logger.info('Live view stream started');
  }

  stopLiveViewStream() {
    this.liveViewActive = false;
    this.frameBuffer = null;
    
    this.broadcastMessage({
      type: 'liveViewStopped',
      timestamp: Date.now()
    });
    
    logger.info('Live view stream stopped');
  }

  onLiveViewFrame(frameData) {
    if (!this.liveViewActive || this.clients.size === 0) {
      return;
    }
    
    // Debug logging
    logger.info('WebSocket received frame data:', {
      type: typeof frameData,
      frameDataType: frameData?.type,
      hasData: !!frameData?.data,
      dataLength: frameData?.data?.length
    });
    
    // Frame rate limiting
    const now = Date.now();
    if (now - this.lastFrameTime < this.frameInterval) {
      this.droppedFrames++;
      return; // Drop frame to maintain target FPS
    }
    this.lastFrameTime = now;
    
    // Handle different frame data types
    let processedFrame;
    if (frameData && typeof frameData === 'object') {
      if (frameData.type === 'svg') {
        logger.info('✅ Processing as SVG frame');
        // SVG frame data
        processedFrame = {
          type: 'liveViewFrame',
          frameType: 'svg',
          data: frameData.data, // Already base64
          width: frameData.width,
          height: frameData.height,
          timestamp: now,
          frameNumber: frameData.frameNumber
        };
      } else if (frameData.type === 'jpeg') {
        // Real camera JPEG frame data
        processedFrame = {
          type: 'liveViewFrame',
          frameType: 'svg', // We'll treat the overlaid image as SVG
          data: frameData.data, // Already base64 encoded SVG with embedded JPEG
          width: frameData.width,
          height: frameData.height,
          timestamp: now,
          frameNumber: frameData.frameNumber
        };
      } else {
        logger.info('❌ Processing as binary frame (fallback)', { frameDataType: frameData.type });
        // Legacy binary frame data
        processedFrame = {
          type: 'liveViewFrame',
          frameType: 'binary',
          data: frameData,
          timestamp: now,
          frameNumber: this.getFrameNumber()
        };
      }
    } else {
      // Legacy binary frame data
      processedFrame = {
        type: 'liveViewFrame',
        frameType: 'binary',
        data: frameData,
        timestamp: now,
        frameNumber: this.getFrameNumber()
      };
    }
    
    this.frameBuffer = processedFrame;
    
    // Broadcast to all connected clients asynchronously
    setImmediate(() => this.broadcastFrame(this.frameBuffer));
  }

  sendFrame(ws, frameData) {
    if (ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(JSON.stringify(frameData));
      } catch (error) {
        logger.error('Error sending frame to client:', error);
        this.clients.delete(ws);
      }
    }
  }

  async broadcastFrame(frameData) {
    const disconnectedClients = [];
    
    // Prepare frame data based on type
    let frameJson;
    if (frameData.frameType === 'svg') {
      // SVG data is already base64 encoded
      frameJson = JSON.stringify(frameData);
    } else {
      // Legacy binary data needs conversion
      frameJson = JSON.stringify({
        ...frameData,
        data: frameData.data ? frameData.data.toString('base64') : ''
      });
    }
    
    // Use Promise.allSettled for concurrent sending
    const sendPromises = Array.from(this.clients).map(async (client) => {
      if (client.readyState === WebSocket.OPEN) {
        try {
          // Check client buffer size to prevent memory buildup
          const clientBuffer = this.clientBuffers.get(client);
          if (clientBuffer && clientBuffer.length >= this.maxQueueSize) {
            clientBuffer.shift(); // Remove oldest frame
          }
          
          return new Promise((resolve, reject) => {
            client.send(frameJson, (error) => {
              if (error) reject(error);
              else resolve();
            });
          });
        } catch (error) {
          logger.error('Error broadcasting frame:', error);
          disconnectedClients.push(client);
        }
      } else {
        disconnectedClients.push(client);
      }
    });
    
    await Promise.allSettled(sendPromises);
    
    // Remove disconnected clients
    for (const client of disconnectedClients) {
      this.clients.delete(client);
      this.clientBuffers.delete(client);
    }
  }

  broadcastMessage(message) {
    const disconnectedClients = [];
    
    for (const client of this.clients) {
      if (client.readyState === WebSocket.OPEN) {
        try {
          client.send(JSON.stringify(message));
        } catch (error) {
          logger.error('Error broadcasting message:', error);
          disconnectedClients.push(client);
        }
      } else {
        disconnectedClients.push(client);
      }
    }
    
    // Remove disconnected clients
    for (const client of disconnectedClients) {
      this.clients.delete(client);
    }
  }

  getFrameNumber() {
    if (!this.frameCounter) {
      this.frameCounter = 0;
    }
    return ++this.frameCounter;
  }

  getStats() {
    return {
      connectedClients: this.clients.size,
      liveViewActive: this.liveViewActive,
      framesSent: this.frameCounter || 0,
      droppedFrames: this.droppedFrames,
      targetFPS: this.targetFPS,
      actualFPS: this.calculateActualFPS()
    };
  }
  
  calculateActualFPS() {
    const now = Date.now();
    if (!this.fpsStartTime) {
      this.fpsStartTime = now;
      return 0;
    }
    
    const elapsed = (now - this.fpsStartTime) / 1000;
    return elapsed > 0 ? Math.round((this.frameCounter || 0) / elapsed) : 0;
  }
  
  setTargetFPS(fps) {
    this.targetFPS = Math.max(1, Math.min(60, fps)); // Clamp between 1-60 FPS
    this.frameInterval = 1000 / this.targetFPS;
    logger.info(`WebSocket target FPS set to ${this.targetFPS}`);
  }

  close() {
    this.liveViewActive = false;
    
    // Close all client connections
    for (const client of this.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.close(1000, 'Server shutting down');
      }
    }
    
    this.wss.close(() => {
      logger.info('WebSocket server closed');
    });
  }
}

module.exports = WebSocketService;