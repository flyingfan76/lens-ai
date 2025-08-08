const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');
const crypto = require('crypto');
const logger = require('../utils/logger');

class LocalStorageService {
  constructor() {
    this.storageBasePath = process.env.LOCAL_STORAGE_PATH || path.join(process.cwd(), 'storage');
    this.bucketName = 'local-storage';
    this.region = 'local';
    this.initialized = false;
    
    this.uploadConfig = {
      maxFileSize: 50 * 1024 * 1024, // 50MB
      allowedMimeTypes: [
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/tiff',
        'image/x-canon-cr3',
        'image/x-nikon-nef',
        'image/x-sony-arw'
      ],
      thumbnailSizes: {
        small: { width: 150, height: 150 },
        medium: { width: 400, height: 400 },
        large: { width: 800, height: 800 }
      }
    };

    this.initialize();
  }

  async initialize() {
    try {
      // Create storage directories
      await this.ensureDirectoryExists(this.storageBasePath);
      await this.ensureDirectoryExists(path.join(this.storageBasePath, 'users'));
      await this.ensureDirectoryExists(path.join(this.storageBasePath, 'metadata'));
      
      this.initialized = true;
      logger.info('Local storage service initialized successfully at:', this.storageBasePath);
    } catch (error) {
      logger.error('Failed to initialize local storage service:', error);
    }
  }

  async ensureDirectoryExists(dirPath) {
    try {
      await fs.access(dirPath);
    } catch (error) {
      if (error.code === 'ENOENT') {
        await fs.mkdir(dirPath, { recursive: true });
        logger.debug(`Created directory: ${dirPath}`);
      } else {
        throw error;
      }
    }
  }

  async uploadPhoto(file, userId, options = {}) {
    if (!this.initialized) {
      throw new Error('Local storage service not initialized');
    }

    try {
      // Validate file
      this.validateFile(file);

      // Generate unique key
      const fileKey = this.generateFileKey(userId, file.originalname || file.filename);
      const filePath = path.join(this.storageBasePath, fileKey);
      
      // Ensure user directory exists
      await this.ensureDirectoryExists(path.dirname(filePath));
      
      // Process image if needed
      let processedBuffer = file.buffer;
      let metadata = {};

      if (this.isImageFile(file.mimetype)) {
        const imageInfo = await this.processImage(file.buffer, options);
        processedBuffer = imageInfo.buffer;
        metadata = imageInfo.metadata;
      }

      // Save main file
      await fs.writeFile(filePath, processedBuffer);
      
      // Save metadata
      const metadataPath = path.join(this.storageBasePath, 'metadata', `${path.basename(fileKey, path.extname(fileKey))}.json`);
      await this.ensureDirectoryExists(path.dirname(metadataPath));
      
      const fileMetadata = {
        userId: userId.toString(),
        originalName: file.originalname || file.filename,
        uploadedAt: new Date().toISOString(),
        contentType: file.mimetype,
        size: processedBuffer.length,
        ...metadata
      };
      
      await fs.writeFile(metadataPath, JSON.stringify(fileMetadata, null, 2));

      // Generate thumbnails for images
      let thumbnails = {};
      if (this.isImageFile(file.mimetype)) {
        thumbnails = await this.generateThumbnails(processedBuffer, fileKey, userId);
      }

      // Create mock S3-like URL
      const mockUrl = `http://localhost:${process.env.PORT || 3000}/storage/${fileKey}`;

      return {
        success: true,
        s3Key: fileKey,
        url: mockUrl,
        etag: this.generateETag(processedBuffer),
        size: processedBuffer.length,
        thumbnails,
        metadata
      };

    } catch (error) {
      logger.error('Photo upload failed:', error);
      throw error;
    }
  }

  async downloadPhoto(s3Key, userId) {
    if (!this.initialized) {
      throw new Error('Local storage service not initialized');
    }

    try {
      const filePath = path.join(this.storageBasePath, s3Key);
      const metadataPath = path.join(this.storageBasePath, 'metadata', `${path.basename(s3Key, path.extname(s3Key))}.json`);

      // Check if file exists
      try {
        await fs.access(filePath);
      } catch (error) {
        throw new Error('File not found');
      }

      // Verify user has access to this file
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf8');
        const metadata = JSON.parse(metadataContent);
        
        if (metadata.userId !== userId.toString()) {
          throw new Error('Unauthorized access to file');
        }
      } catch (error) {
        logger.warn('Could not verify file ownership:', error.message);
      }

      const buffer = await fs.readFile(filePath);
      
      // Get content type from metadata or guess from extension
      let contentType = 'application/octet-stream';
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf8');
        const metadata = JSON.parse(metadataContent);
        contentType = metadata.contentType || contentType;
      } catch (error) {
        // Fallback to guessing from extension
        const ext = path.extname(s3Key).toLowerCase();
        const mimeTypes = {
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.png': 'image/png',
          '.tiff': 'image/tiff',
          '.cr3': 'image/x-canon-cr3',
          '.nef': 'image/x-nikon-nef',
          '.arw': 'image/x-sony-arw'
        };
        contentType = mimeTypes[ext] || contentType;
      }

      return {
        success: true,
        buffer,
        contentType,
        metadata: {}
      };

    } catch (error) {
      logger.error('Photo download failed:', error);
      throw error;
    }
  }

  async deletePhoto(s3Key, userId) {
    if (!this.initialized) {
      throw new Error('Local storage service not initialized');
    }

    try {
      const filePath = path.join(this.storageBasePath, s3Key);
      const metadataPath = path.join(this.storageBasePath, 'metadata', `${path.basename(s3Key, path.extname(s3Key))}.json`);

      // Verify ownership before deletion
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf8');
        const metadata = JSON.parse(metadataContent);
        
        if (metadata.userId !== userId.toString()) {
          throw new Error('Unauthorized deletion attempt');
        }
      } catch (error) {
        logger.warn('Could not verify file ownership for deletion:', error.message);
      }

      // Delete main file
      try {
        await fs.unlink(filePath);
      } catch (error) {
        if (error.code !== 'ENOENT') {
          throw error;
        }
      }

      // Delete metadata
      try {
        await fs.unlink(metadataPath);
      } catch (error) {
        if (error.code !== 'ENOENT') {
          logger.warn('Could not delete metadata file:', error.message);
        }
      }

      // Delete associated thumbnails
      await this.deleteThumbnails(s3Key);

      return { success: true };

    } catch (error) {
      logger.error('Photo deletion failed:', error);
      throw error;
    }
  }

  async generatePresignedUrl(s3Key, userId, expiresIn = 3600) {
    if (!this.initialized) {
      throw new Error('Local storage service not initialized');
    }

    try {
      // In local mode, we just return a direct URL (no actual expiration)
      // In a real implementation, you might implement a token-based system
      const url = `http://localhost:${process.env.PORT || 3000}/storage/${s3Key}?userId=${userId}&expires=${Date.now() + (expiresIn * 1000)}`;
      
      return { success: true, url };

    } catch (error) {
      logger.error('Presigned URL generation failed:', error);
      throw error;
    }
  }

  async getUserStorageUsage(userId) {
    if (!this.initialized) {
      throw new Error('Local storage service not initialized');
    }

    try {
      let totalSize = 0;
      let objectCount = 0;
      const userDir = path.join(this.storageBasePath, 'users', userId.toString());

      try {
        await fs.access(userDir);
        const files = await this.getAllFilesRecursive(userDir);
        
        for (const file of files) {
          try {
            const stats = await fs.stat(file);
            totalSize += stats.size;
            objectCount++;
          } catch (error) {
            logger.warn(`Could not get stats for file ${file}:`, error.message);
          }
        }
      } catch (error) {
        if (error.code !== 'ENOENT') {
          throw error;
        }
        // User directory doesn't exist yet, return zero usage
      }

      return {
        success: true,
        totalBytes: totalSize,
        objectCount,
        formattedSize: this.formatBytes(totalSize)
      };

    } catch (error) {
      logger.error('Storage usage calculation failed:', error);
      throw error;
    }
  }

  async getAllFilesRecursive(dir) {
    const files = [];
    const entries = await fs.readdir(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        files.push(...await this.getAllFilesRecursive(fullPath));
      } else {
        files.push(fullPath);
      }
    }
    
    return files;
  }

  // Private helper methods (similar to AWS service)
  validateFile(file) {
    if (!file || !file.buffer) {
      throw new Error('Invalid file: no buffer provided');
    }

    if (file.size > this.uploadConfig.maxFileSize) {
      throw new Error(`File too large: ${file.size} bytes (max: ${this.uploadConfig.maxFileSize})`);
    }

    if (file.mimetype && !this.uploadConfig.allowedMimeTypes.includes(file.mimetype)) {
      throw new Error(`Unsupported file type: ${file.mimetype}`);
    }
  }

  generateFileKey(userId, filename) {
    const timestamp = Date.now();
    const random = crypto.randomBytes(8).toString('hex');
    const ext = path.extname(filename).toLowerCase();
    return `users/${userId}/photos/${timestamp}-${random}${ext}`;
  }

  isImageFile(mimetype) {
    return mimetype && mimetype.startsWith('image/');
  }

  async processImage(buffer, options = {}) {
    try {
      const sharpInstance = sharp(buffer);
      const metadata = await sharpInstance.metadata();

      let processedImage = sharpInstance;

      // Auto-rotate based on EXIF
      processedImage = processedImage.rotate();

      // Apply compression if specified
      if (options.quality && metadata.format === 'jpeg') {
        processedImage = processedImage.jpeg({ quality: options.quality });
      }

      // Resize if specified
      if (options.maxWidth || options.maxHeight) {
        processedImage = processedImage.resize(options.maxWidth, options.maxHeight, {
          withoutEnlargement: true,
          fit: 'inside'
        });
      }

      const processedBuffer = await processedImage.toBuffer();

      return {
        buffer: processedBuffer,
        metadata: {
          width: metadata.width,
          height: metadata.height,
          format: metadata.format,
          size: processedBuffer.length,
          hasExif: !!metadata.exif
        }
      };

    } catch (error) {
      logger.error('Image processing failed:', error);
      // Return original buffer if processing fails
      return {
        buffer,
        metadata: { processed: false, error: error.message }
      };
    }
  }

  async generateThumbnails(buffer, originalKey, userId) {
    const thumbnails = {};
    
    try {
      for (const [size, dimensions] of Object.entries(this.uploadConfig.thumbnailSizes)) {
        const thumbnailBuffer = await sharp(buffer)
          .resize(dimensions.width, dimensions.height, {
            fit: 'cover',
            position: 'center'
          })
          .jpeg({ quality: 80 })
          .toBuffer();

        const thumbnailKey = originalKey.replace(/(\.[^.]+)$/, `_thumb_${size}$1`);
        const thumbnailPath = path.join(this.storageBasePath, thumbnailKey);
        
        // Ensure thumbnail directory exists
        await this.ensureDirectoryExists(path.dirname(thumbnailPath));
        
        // Save thumbnail
        await fs.writeFile(thumbnailPath, thumbnailBuffer);
        
        // Save thumbnail metadata
        const thumbnailMetadataPath = path.join(this.storageBasePath, 'metadata', `${path.basename(thumbnailKey, path.extname(thumbnailKey))}.json`);
        const thumbnailMetadata = {
          userId: userId.toString(),
          thumbnailSize: size,
          originalKey: originalKey,
          contentType: 'image/jpeg',
          size: thumbnailBuffer.length
        };
        
        await fs.writeFile(thumbnailMetadataPath, JSON.stringify(thumbnailMetadata, null, 2));

        const mockUrl = `http://localhost:${process.env.PORT || 3000}/storage/${thumbnailKey}`;

        thumbnails[size] = {
          key: thumbnailKey,
          url: mockUrl,
          size: thumbnailBuffer.length,
          dimensions
        };
      }
    } catch (error) {
      logger.error('Thumbnail generation failed:', error);
    }

    return thumbnails;
  }

  async deleteThumbnails(originalKey) {
    const sizes = Object.keys(this.uploadConfig.thumbnailSizes);
    
    for (const size of sizes) {
      try {
        const thumbnailKey = originalKey.replace(/(\.[^.]+)$/, `_thumb_${size}$1`);
        const thumbnailPath = path.join(this.storageBasePath, thumbnailKey);
        const metadataPath = path.join(this.storageBasePath, 'metadata', `${path.basename(thumbnailKey, path.extname(thumbnailKey))}.json`);
        
        await fs.unlink(thumbnailPath);
        await fs.unlink(metadataPath);
      } catch (error) {
        if (error.code !== 'ENOENT') {
          logger.warn(`Failed to delete thumbnail:`, error);
        }
      }
    }
  }

  generateETag(buffer) {
    return crypto.createHash('md5').update(buffer).digest('hex');
  }

  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  // Health check method
  async healthCheck() {
    if (!this.initialized) {
      return { healthy: false, error: 'Service not initialized' };
    }

    try {
      await fs.access(this.storageBasePath);
      return { 
        healthy: true, 
        service: 'Local Storage', 
        storageBasePath: this.storageBasePath,
        bucket: this.bucketName
      };
    } catch (error) {
      return { healthy: false, error: error.message };
    }
  }
}

module.exports = LocalStorageService;