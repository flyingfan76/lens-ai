const AWS = require('aws-sdk');
const sharp = require('sharp');
const crypto = require('crypto');
const path = require('path');
const logger = require('../utils/logger');

class AWSService {
  constructor() {
    this.s3 = null;
    this.bucketName = process.env.AWS_S3_BUCKET || 'camera-companion-images';
    this.region = process.env.AWS_REGION || 'us-east-1';
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

  initialize() {
    try {
      // Configure AWS SDK
      if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
        logger.warn('AWS credentials not configured. S3 features will be disabled.');
        return;
      }

      AWS.config.update({
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        region: this.region
      });

      this.s3 = new AWS.S3({
        apiVersion: '2006-03-01',
        signatureVersion: 'v4'
      });

      this.initialized = true;
      logger.info('AWS S3 service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize AWS service:', error);
    }
  }

  async uploadPhoto(file, userId, options = {}) {
    if (!this.initialized) {
      throw new Error('AWS service not initialized');
    }

    try {
      // Validate file
      this.validateFile(file);

      // Generate unique key
      const fileKey = this.generateFileKey(userId, file.originalname || file.filename);
      
      // Process image if needed
      let processedBuffer = file.buffer;
      let metadata = {};

      if (this.isImageFile(file.mimetype)) {
        const imageInfo = await this.processImage(file.buffer, options);
        processedBuffer = imageInfo.buffer;
        metadata = imageInfo.metadata;
      }

      // Upload main file
      const uploadResult = await this.uploadToS3({
        buffer: processedBuffer,
        key: fileKey,
        contentType: file.mimetype,
        metadata: {
          userId: userId.toString(),
          originalName: file.originalname || file.filename,
          uploadedAt: new Date().toISOString(),
          ...metadata
        }
      });

      // Generate thumbnails for images
      let thumbnails = {};
      if (this.isImageFile(file.mimetype)) {
        thumbnails = await this.generateThumbnails(processedBuffer, fileKey, userId);
      }

      return {
        success: true,
        s3Key: fileKey,
        url: uploadResult.Location,
        etag: uploadResult.ETag,
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
      throw new Error('AWS service not initialized');
    }

    try {
      // Verify user has access to this file
      const headResult = await this.s3.headObject({
        Bucket: this.bucketName,
        Key: s3Key
      }).promise();

      if (headResult.Metadata.userid !== userId.toString()) {
        throw new Error('Unauthorized access to file');
      }

      const result = await this.s3.getObject({
        Bucket: this.bucketName,
        Key: s3Key
      }).promise();

      return {
        success: true,
        buffer: result.Body,
        contentType: result.ContentType,
        metadata: result.Metadata
      };

    } catch (error) {
      logger.error('Photo download failed:', error);
      throw error;
    }
  }

  async deletePhoto(s3Key, userId) {
    if (!this.initialized) {
      throw new Error('AWS service not initialized');
    }

    try {
      // Verify ownership before deletion
      const headResult = await this.s3.headObject({
        Bucket: this.bucketName,
        Key: s3Key
      }).promise();

      if (headResult.Metadata.userid !== userId.toString()) {
        throw new Error('Unauthorized deletion attempt');
      }

      // Delete main file
      await this.s3.deleteObject({
        Bucket: this.bucketName,
        Key: s3Key
      }).promise();

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
      throw new Error('AWS service not initialized');
    }

    try {
      // Verify user has access
      const headResult = await this.s3.headObject({
        Bucket: this.bucketName,
        Key: s3Key
      }).promise();

      if (headResult.Metadata.userid !== userId.toString()) {
        throw new Error('Unauthorized access to file');
      }

      const url = this.s3.getSignedUrl('getObject', {
        Bucket: this.bucketName,
        Key: s3Key,
        Expires: expiresIn
      });

      return { success: true, url };

    } catch (error) {
      logger.error('Presigned URL generation failed:', error);
      throw error;
    }
  }

  async getUserStorageUsage(userId) {
    if (!this.initialized) {
      throw new Error('AWS service not initialized');
    }

    try {
      let totalSize = 0;
      let objectCount = 0;
      const prefix = `users/${userId}/`;

      const listParams = {
        Bucket: this.bucketName,
        Prefix: prefix
      };

      let isTruncated = true;
      let continuationToken = null;

      while (isTruncated) {
        if (continuationToken) {
          listParams.ContinuationToken = continuationToken;
        }

        const result = await this.s3.listObjectsV2(listParams).promise();
        
        result.Contents.forEach(object => {
          totalSize += object.Size;
          objectCount++;
        });

        isTruncated = result.IsTruncated;
        continuationToken = result.NextContinuationToken;
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

  async createBatch(operations, userId) {
    if (!this.initialized) {
      throw new Error('AWS service not initialized');
    }

    const results = [];
    const batchSize = 10; // Process in batches to avoid overwhelming S3

    for (let i = 0; i < operations.length; i += batchSize) {
      const batch = operations.slice(i, i + batchSize);
      const batchPromises = batch.map(async (operation) => {
        try {
          switch (operation.type) {
            case 'upload':
              return await this.uploadPhoto(operation.file, userId, operation.options);
            case 'delete':
              return await this.deletePhoto(operation.s3Key, userId);
            case 'copy':
              return await this.copyObject(operation.sourceKey, operation.destKey, userId);
            default:
              throw new Error(`Unknown batch operation: ${operation.type}`);
          }
        } catch (error) {
          return { success: false, error: error.message, operation };
        }
      });

      const batchResults = await Promise.allSettled(batchPromises);
      results.push(...batchResults.map(result => 
        result.status === 'fulfilled' ? result.value : { success: false, error: result.reason }
      ));
    }

    return results;
  }

  // Private helper methods
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

  async uploadToS3({ buffer, key, contentType, metadata = {} }) {
    const params = {
      Bucket: this.bucketName,
      Key: key,
      Body: buffer,
      ContentType: contentType,
      Metadata: metadata,
      ServerSideEncryption: 'AES256'
    };

    return this.s3.upload(params).promise();
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
        
        const uploadResult = await this.uploadToS3({
          buffer: thumbnailBuffer,
          key: thumbnailKey,
          contentType: 'image/jpeg',
          metadata: {
            userId: userId.toString(),
            thumbnailSize: size,
            originalKey: originalKey
          }
        });

        thumbnails[size] = {
          key: thumbnailKey,
          url: uploadResult.Location,
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
    const deletePromises = sizes.map(size => {
      const thumbnailKey = originalKey.replace(/(\.[^.]+)$/, `_thumb_${size}$1`);
      return this.s3.deleteObject({
        Bucket: this.bucketName,
        Key: thumbnailKey
      }).promise().catch(error => {
        logger.warn(`Failed to delete thumbnail ${thumbnailKey}:`, error);
      });
    });

    await Promise.all(deletePromises);
  }

  async copyObject(sourceKey, destKey, userId) {
    const copySource = `${this.bucketName}/${sourceKey}`;
    
    const params = {
      Bucket: this.bucketName,
      CopySource: copySource,
      Key: destKey,
      MetadataDirective: 'COPY'
    };

    return this.s3.copyObject(params).promise();
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
      await this.s3.headBucket({ Bucket: this.bucketName }).promise();
      return { healthy: true, service: 'AWS S3', bucket: this.bucketName };
    } catch (error) {
      return { healthy: false, error: error.message };
    }
  }
}

module.exports = AWSService;