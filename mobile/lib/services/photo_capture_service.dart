import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../models/external_camera.dart';
import 'libgphoto2_service.dart';

/// Comprehensive photo capture service for external cameras
/// Handles camera capture, format conversion, and dual storage (camera + phone)
class PhotoCaptureService {
  static final PhotoCaptureService _instance = PhotoCaptureService._internal();
  factory PhotoCaptureService() => _instance;
  PhotoCaptureService._internal();

  final LibGPhoto2Service _libGPhoto2Service = LibGPhoto2Service();

  /// Capture photo with external camera and handle dual storage
  Future<PhotoCaptureResult> capturePhoto({
    required ExternalCamera camera,
    bool saveToPhone = true,
  }) async {
    debugPrint('PhotoCaptureService: Starting photo capture with ${camera.name}');
    
    try {
      // Step 1: Trigger camera capture
      final cameraResult = await _triggerCameraCapture(camera);
      if (!cameraResult.success) {
        return PhotoCaptureResult(
          success: false,
          error: cameraResult.error,
        );
      }

      // Step 2: Handle phone storage if enabled
      String? phoneFilePath;
      if (saveToPhone) {
        phoneFilePath = await _saveToPhone(
          camera: camera,
          cameraFilePath: cameraResult.filePath,
          originalFormat: cameraResult.format,
          imageData: cameraResult.imageData,
        );
      }

      return PhotoCaptureResult(
        success: true,
        cameraFilePath: cameraResult.filePath,
        phoneFilePath: phoneFilePath,
        originalFormat: cameraResult.format,
        phoneFormat: 'jpg',
        metadata: cameraResult.metadata,
      );

    } catch (e) {
      debugPrint('PhotoCaptureService: Capture error: $e');
      return PhotoCaptureResult(
        success: false,
        error: 'Photo capture failed: $e',
      );
    }
  }

  /// Trigger camera capture based on connection type
  Future<CameraCaptureResult> _triggerCameraCapture(ExternalCamera camera) async {
    if (camera.connectionType == CameraConnectionType.usb) {
      return await _captureUSBCamera(camera);
    } else if (camera.connectionType == CameraConnectionType.wifi) {
      return await _captureWiFiCamera(camera);
    } else {
      return CameraCaptureResult(
        success: false,
        error: 'Unsupported camera connection type: ${camera.connectionType}',
      );
    }
  }

  /// Capture photo from USB-connected camera using libgphoto2
  Future<CameraCaptureResult> _captureUSBCamera(ExternalCamera camera) async {
    debugPrint('PhotoCaptureService: Capturing from USB camera ${camera.name}');

    // Ensure libgphoto2 is connected
    if (!_libGPhoto2Service.isConnected) {
      debugPrint('PhotoCaptureService: Connecting to libgphoto2...');
      final connected = await _libGPhoto2Service.connect();
      if (!connected) {
        return CameraCaptureResult(
          success: false,
          error: 'Failed to connect to camera via USB',
        );
      }
    }

    // Trigger capture
    final photoInfo = await _libGPhoto2Service.capturePhoto();
    if (photoInfo == null) {
      return CameraCaptureResult(
        success: false,
        error: 'Camera capture returned no result',
      );
    }

    // Download the captured image if needed for phone storage
    Uint8List? imageData;
    final needsDownload = await _shouldSaveToPhone();
    if (needsDownload) {
      final fileName = photoInfo['filename'];
      final folder = photoInfo['folder'] ?? '/';
      if (fileName != null) {
        imageData = await _libGPhoto2Service.downloadFile(folder, fileName);
      }
    }

    return CameraCaptureResult(
      success: true,
      filePath: photoInfo['path'] ?? photoInfo['filename'],
      format: _extractFileFormat(photoInfo['filename'] ?? ''),
      imageData: imageData,
      metadata: Map<String, dynamic>.from(photoInfo),
    );
  }

  /// Capture photo from WiFi-connected camera
  Future<CameraCaptureResult> _captureWiFiCamera(ExternalCamera camera) async {
    debugPrint('PhotoCaptureService: Capturing from WiFi camera ${camera.name}');
    
    // TODO: Implement WiFi camera capture based on camera brand
    // This would use HTTP requests to the camera's web API
    
    // For now, simulate capture for demonstration
    await Future.delayed(const Duration(seconds: 1));
    
    // Generate a simulated result
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return CameraCaptureResult(
      success: true,
      filePath: 'IMG_${timestamp}.jpg',
      format: 'jpg',
      imageData: null, // Would contain actual image data from WiFi API
      metadata: {
        'camera': camera.name,
        'timestamp': timestamp,
        'connection': 'wifi',
      },
    );
  }

  /// Save captured photo to phone storage
  Future<String?> _saveToPhone({
    required ExternalCamera camera,
    String? cameraFilePath,
    required String originalFormat,
    Uint8List? imageData,
  }) async {
    try {
      debugPrint('PhotoCaptureService: Saving photo to phone (format: $originalFormat -> jpg)');

      // Get image data if not provided
      if (imageData == null) {
        debugPrint('PhotoCaptureService: No image data provided, cannot save to phone');
        return null;
      }

      // Convert to JPG if needed
      final jpgData = await _convertToJPG(imageData, originalFormat);
      if (jpgData == null) {
        debugPrint('PhotoCaptureService: Failed to convert image to JPG');
        return null;
      }

      // Generate filename
      final timestamp = DateTime.now();
      final fileName = 'LensAI_${camera.brand.name}_${timestamp.millisecondsSinceEpoch}.jpg';

      // Get app directory
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/Photos');
      
      // Create photos directory if it doesn't exist
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // Save file
      final filePath = '${photosDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(jpgData);

      debugPrint('PhotoCaptureService: Photo saved to phone: $filePath');
      return filePath;

    } catch (e) {
      debugPrint('PhotoCaptureService: Error saving to phone: $e');
      return null;
    }
  }

  /// Convert image data to JPG format
  Future<Uint8List?> _convertToJPG(Uint8List imageData, String originalFormat) async {
    try {
      // If already JPG, return as-is
      if (originalFormat.toLowerCase() == 'jpg' || originalFormat.toLowerCase() == 'jpeg') {
        return imageData;
      }

      // Decode image
      img.Image? image;
      
      switch (originalFormat.toLowerCase()) {
        case 'raw':
        case 'nef': // Nikon RAW
        case 'cr2': // Canon RAW
        case 'arw': // Sony RAW
          // For RAW formats, we'd need a specialized RAW decoder
          // For now, assume the camera provides a JPG preview
          debugPrint('PhotoCaptureService: RAW format detected, using embedded preview');
          image = img.decodeImage(imageData);
          break;
        
        case 'png':
          image = img.decodePng(imageData);
          break;
        
        case 'tiff':
        case 'tif':
          image = img.decodeTiff(imageData);
          break;
        
        default:
          // Try generic decode
          image = img.decodeImage(imageData);
      }

      if (image == null) {
        debugPrint('PhotoCaptureService: Failed to decode image format: $originalFormat');
        return null;
      }

      // Encode as JPG with high quality
      final jpgData = img.encodeJpg(image, quality: 95);
      return Uint8List.fromList(jpgData);

    } catch (e) {
      debugPrint('PhotoCaptureService: Image conversion error: $e');
      return null;
    }
  }

  /// Extract file format from filename
  String _extractFileFormat(String filename) {
    final parts = filename.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'unknown';
  }

  /// Check if user wants to save photos to phone
  Future<bool> _shouldSaveToPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('save_pictures_to_phone') ?? true;
    } catch (e) {
      debugPrint('PhotoCaptureService: Error reading phone save preference: $e');
      return true; // Default to saving
    }
  }

  /// Get phone storage info
  Future<PhoneStorageInfo> getPhoneStorageInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/Photos');
      
      if (!await photosDir.exists()) {
        return PhoneStorageInfo(
          totalPhotos: 0,
          totalSizeBytes: 0,
          availableSpaceBytes: 0,
          photosPath: photosDir.path,
        );
      }

      // Count photos and calculate size
      final photoFiles = await photosDir
          .list()
          .where((entity) => entity is File && 
                 (entity.path.endsWith('.jpg') || entity.path.endsWith('.jpeg')))
          .cast<File>()
          .toList();

      int totalSize = 0;
      for (final file in photoFiles) {
        try {
          final stat = await file.stat();
          totalSize += stat.size;
        } catch (e) {
          // Skip files that can't be accessed
        }
      }

      // Get available space (simplified - would need platform-specific implementation)
      final availableSpace = await _getAvailableSpace();

      return PhoneStorageInfo(
        totalPhotos: photoFiles.length,
        totalSizeBytes: totalSize,
        availableSpaceBytes: availableSpace,
        photosPath: photosDir.path,
      );

    } catch (e) {
      debugPrint('PhotoCaptureService: Error getting storage info: $e');
      return PhoneStorageInfo(
        totalPhotos: 0,
        totalSizeBytes: 0,
        availableSpaceBytes: 0,
        photosPath: '',
      );
    }
  }

  /// Get available storage space (platform-specific implementation needed)
  Future<int> _getAvailableSpace() async {
    // This would need platform-specific implementation
    // For now, return a reasonable estimate
    return 1024 * 1024 * 1024; // 1GB
  }

  /// Clear phone photo cache
  Future<bool> clearPhonePhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/Photos');
      
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
        debugPrint('PhotoCaptureService: Cleared phone photo cache');
        return true;
      }
      
      return true;
    } catch (e) {
      debugPrint('PhotoCaptureService: Error clearing phone photos: $e');
      return false;
    }
  }
}

/// Result of camera capture operation
class CameraCaptureResult {
  final bool success;
  final String? filePath;
  final String format;
  final Uint8List? imageData;
  final Map<String, dynamic>? metadata;
  final String? error;

  CameraCaptureResult({
    required this.success,
    this.filePath,
    this.format = 'unknown',
    this.imageData,
    this.metadata,
    this.error,
  });
}

/// Result of complete photo capture with dual storage
class PhotoCaptureResult {
  final bool success;
  final String? cameraFilePath;  // Path on camera storage
  final String? phoneFilePath;   // Path on phone storage
  final String originalFormat;   // Format stored on camera (e.g., 'raw', 'jpg')
  final String phoneFormat;      // Format stored on phone (always 'jpg')
  final Map<String, dynamic>? metadata;
  final String? error;

  PhotoCaptureResult({
    required this.success,
    this.cameraFilePath,
    this.phoneFilePath,
    this.originalFormat = 'unknown',
    this.phoneFormat = 'jpg',
    this.metadata,
    this.error,
  });

  /// Get a user-friendly description of the capture result
  String get description {
    if (!success) {
      return error ?? 'Capture failed';
    }

    final parts = <String>[];
    
    if (cameraFilePath != null) {
      parts.add('Saved to camera ($originalFormat)');
    }
    
    if (phoneFilePath != null) {
      parts.add('Saved to phone ($phoneFormat)');
    }

    return parts.isEmpty ? 'Photo captured' : parts.join(' • ');
  }
}

/// Phone storage information
class PhoneStorageInfo {
  final int totalPhotos;
  final int totalSizeBytes;
  final int availableSpaceBytes;
  final String photosPath;

  PhoneStorageInfo({
    required this.totalPhotos,
    required this.totalSizeBytes,
    required this.availableSpaceBytes,
    required this.photosPath,
  });

  /// Get human-readable size
  String get totalSizeFormatted => _formatBytes(totalSizeBytes);
  String get availableSpaceFormatted => _formatBytes(availableSpaceBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}