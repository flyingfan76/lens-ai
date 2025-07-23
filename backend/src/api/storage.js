const express = require('express');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../utils/logger');

const router = express.Router();

// Serve local storage files (only in development/local mode)
router.get('/:filePath(*)', async (req, res) => {
  try {
    // Only serve files in local/development mode
    const isLocalMode = process.env.STORAGE_MODE === 'local' || process.env.NODE_ENV === 'development';
    
    if (!isLocalMode) {
      return res.status(404).json({
        success: false,
        error: 'Storage endpoint not available in production mode'
      });
    }

    const filePath = req.params.filePath;
    const storageBasePath = process.env.LOCAL_STORAGE_PATH || path.join(process.cwd(), 'storage');
    const fullPath = path.join(storageBasePath, filePath);
    
    // Security check: ensure the path is within the storage directory
    if (!fullPath.startsWith(storageBasePath)) {
      return res.status(403).json({
        success: false,
        error: 'Access denied'
      });
    }

    // Check if file exists
    try {
      await fs.access(fullPath);
    } catch (error) {
      return res.status(404).json({
        success: false,
        error: 'File not found'
      });
    }

    // Optional: Add basic authorization check
    const userId = req.query.userId;
    if (userId && filePath.includes('users/')) {
      const expectedUserPath = `users/${userId}/`;
      if (!filePath.startsWith(expectedUserPath)) {
        return res.status(403).json({
          success: false,
          error: 'Unauthorized access to file'
        });
      }
    }

    // Set appropriate content type
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.tiff': 'image/tiff',
      '.cr3': 'image/x-canon-cr3',
      '.nef': 'image/x-nikon-nef',
      '.arw': 'image/x-sony-arw',
      '.json': 'application/json'
    };
    
    const contentType = mimeTypes[ext] || 'application/octet-stream';
    res.set('Content-Type', contentType);

    // Add cache headers for images
    if (contentType.startsWith('image/')) {
      res.set('Cache-Control', 'public, max-age=86400'); // 24 hours
    }

    // Stream the file
    const fileBuffer = await fs.readFile(fullPath);
    res.send(fileBuffer);

    logger.debug(`Served local file: ${filePath}`);

  } catch (error) {
    logger.error('Error serving local storage file:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

module.exports = router;