// Configuration for the web debug frontend
const CONFIG = {
  // Backend server configuration
  BACKEND_URL: process.env.BACKEND_URL || 'http://localhost:3000',
  
  // WebSocket configuration
  WS_URL: process.env.WS_URL || 'ws://localhost:3000',
  
  // Debug server configuration
  DEBUG_PORT: process.env.DEBUG_PORT || 3001,
  
  // Environment settings
  ENVIRONMENT: process.env.NODE_ENV || 'development',
  
  // API endpoints
  API: {
    HEALTH: '/health',
    CAMERA: '/api/camera',
    AI: '/api/ai',
    PRESETS: '/api/presets',
    CLOUD: '/api/cloud',
    AUTO_ADJUSTMENT: '/api/auto-adjustment',
    EDUCATION: '/api/education',
    STORAGE: '/storage'
  }
};

// Export for Node.js environment
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}

// Export for browser environment
if (typeof window !== 'undefined') {
  window.CONFIG = CONFIG;
}