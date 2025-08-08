import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/utils/lens_exceptions.dart';
import '../core/utils/error_handler.dart';

/// Model for stored photo metadata
class StoredPhoto {
  final String id;
  final String fileName;
  final String filePath;
  final DateTime capturedAt;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? aiAnalysis;
  final Map<String, dynamic>? cameraSettings;
  final bool isSynced;
  final List<String> syncTargets;
  final int fileSize;
  final String? thumbnailPath;

  const StoredPhoto({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.capturedAt,
    this.metadata = const {},
    this.aiAnalysis,
    this.cameraSettings,
    this.isSynced = false,
    this.syncTargets = const [],
    required this.fileSize,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'capturedAt': capturedAt.toIso8601String(),
      'metadata': metadata,
      'aiAnalysis': aiAnalysis,
      'cameraSettings': cameraSettings,
      'isSynced': isSynced,
      'syncTargets': syncTargets,
      'fileSize': fileSize,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory StoredPhoto.fromJson(Map<String, dynamic> json) {
    return StoredPhoto(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      capturedAt: DateTime.parse(json['capturedAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      aiAnalysis: json['aiAnalysis'] != null 
        ? Map<String, dynamic>.from(json['aiAnalysis'])
        : null,
      cameraSettings: json['cameraSettings'] != null
        ? Map<String, dynamic>.from(json['cameraSettings'])
        : null,
      isSynced: json['isSynced'] ?? false,
      syncTargets: List<String>.from(json['syncTargets'] ?? []),
      fileSize: json['fileSize'] ?? 0,
      thumbnailPath: json['thumbnailPath'],
    );
  }

  StoredPhoto copyWith({
    String? id,
    String? fileName,
    String? filePath,
    DateTime? capturedAt,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? aiAnalysis,
    Map<String, dynamic>? cameraSettings,
    bool? isSynced,
    List<String>? syncTargets,
    int? fileSize,
    String? thumbnailPath,
  }) {
    return StoredPhoto(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      capturedAt: capturedAt ?? this.capturedAt,
      metadata: metadata ?? this.metadata,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      cameraSettings: cameraSettings ?? this.cameraSettings,
      isSynced: isSynced ?? this.isSynced,
      syncTargets: syncTargets ?? this.syncTargets,
      fileSize: fileSize ?? this.fileSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

/// Local photo storage service for mobile devices
class LocalPhotoStorage with ErrorHandlerMixin {
  static const String _logTag = 'LocalPhotoStorage';
  static const String _metadataFileName = 'photos_metadata.json';
  static const String _photosDirectoryName = 'photos';
  static const String _thumbnailsDirectoryName = 'thumbnails';

  static LocalPhotoStorage? _instance;
  static LocalPhotoStorage get instance => _instance ??= LocalPhotoStorage._();
  
  LocalPhotoStorage._();

  Directory? _photosDirectory;
  Directory? _thumbnailsDirectory;
  File? _metadataFile;
  List<StoredPhoto> _photos = [];
  bool _isInitialized = false;

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) return;

    return await withFileErrorHandling(
      () async {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          
          // Create photos directory
          _photosDirectory = Directory(path.join(appDir.path, _photosDirectoryName));
          if (!await _photosDirectory!.exists()) {
            await _photosDirectory!.create(recursive: true);
          }

          // Create thumbnails directory
          _thumbnailsDirectory = Directory(path.join(appDir.path, _thumbnailsDirectoryName));
          if (!await _thumbnailsDirectory!.exists()) {
            await _thumbnailsDirectory!.create(recursive: true);
          }

          // Initialize metadata file
          _metadataFile = File(path.join(appDir.path, _metadataFileName));
          
          // Load existing photos
          await _loadPhotosMetadata();
          
          _isInitialized = true;
          debugPrint('$_logTag: Initialized with ${_photos.length} photos');
          
        } catch (e, stackTrace) {
          if (e.toString().contains('permission')) {
            throw StoragePermissionException(
              details: e.toString(),
            );
          } else if (e.toString().contains('space') || e.toString().contains('storage')) {
            throw InsufficientStorageException(
              details: e.toString(),
            );
          } else {
            throw FileIOException(
              message: 'Failed to initialize photo storage',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }
      },
      operation: 'initialize photo storage',
      showToUser: false,
    );
  }

  /// Store a photo with metadata locally
  Future<StoredPhoto> storePhoto({
    required Uint8List imageBytes,
    required String originalFileName,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? cameraSettings,
    Map<String, dynamic>? aiAnalysis,
  }) async {
    return await withFileErrorHandling<StoredPhoto>(
      () async {
        if (!_isInitialized) await initialize();

        // Validate input
        if (imageBytes.isEmpty) {
          throw FileIOException(
            message: 'Cannot store empty image',
            details: 'Image data is empty',
          );
        }

        if (originalFileName.isEmpty) {
          throw FileIOException(
            message: 'Invalid file name',
            details: 'File name cannot be empty',
          );
        }

        // Check available disk space
        final photoSize = imageBytes.length;
        if (await _checkInsufficientSpace(photoSize)) {
          throw InsufficientStorageException(
            details: 'Need at least ${_formatBytes(photoSize)} free space',
          );
        }

        try {
          final photoId = _generatePhotoId();
          final timestamp = DateTime.now();
          final extension = path.extension(originalFileName).toLowerCase();
          
          // Validate file extension
          final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
          if (!allowedExtensions.contains(extension)) {
            throw FileIOException(
              message: 'Unsupported image format',
              details: 'Extension "$extension" is not supported',
              suggestion: 'Use JPG, PNG, or WEBP format',
            );
          }
          
          final fileName = '$photoId$extension';
          
          // Store main image with error handling
          final photoFile = File(path.join(_photosDirectory!.path, fileName));
          try {
            await photoFile.writeAsBytes(imageBytes);
          } catch (e, stackTrace) {
            if (e.toString().contains('permission')) {
              throw StoragePermissionException(
                details: 'Cannot write to photos directory: $e',
              );
            } else if (e.toString().contains('space') || e.toString().contains('full')) {
              throw InsufficientStorageException(
                details: e.toString(),
              );
            } else {
              throw FileIOException(
                message: 'Failed to write photo file',
                details: e.toString(),
                originalError: e,
                stackTrace: stackTrace,
              );
            }
          }
          
          // Generate thumbnail with error handling
          String? thumbnailPath;
          try {
            thumbnailPath = await _generateThumbnail(imageBytes, photoId);
          } catch (e) {
            // Thumbnail generation is optional - log but don't fail
            debugPrint('$_logTag: Failed to generate thumbnail: $e');
          }
          
          // Create photo record
          final storedPhoto = StoredPhoto(
            id: photoId,
            fileName: fileName,
            filePath: photoFile.path,
            capturedAt: timestamp,
            metadata: metadata ?? {},
            cameraSettings: cameraSettings,
            aiAnalysis: aiAnalysis,
            fileSize: imageBytes.length,
            thumbnailPath: thumbnailPath,
          );

          // Add to collection and save metadata
          _photos.add(storedPhoto);
          try {
            await _savePhotosMetadata();
          } catch (e) {
            // If metadata save fails, remove the photo file to maintain consistency
            try {
              await photoFile.delete();
            } catch (_) {}
            throw FileIOException(
              message: 'Failed to save photo metadata',
              details: e.toString(),
              originalError: e,
            );
          }
          
          debugPrint('$_logTag: Stored photo $photoId (${_formatBytes(imageBytes.length)})');
          return storedPhoto;
          
        } catch (e, stackTrace) {
          if (e is LensException) {
            rethrow;
          } else {
            throw FileIOException(
              message: 'Failed to store photo',
              details: e.toString(),
              originalError: e,
              stackTrace: stackTrace,
            );
          }
        }
      },
      operation: 'store photo',
    ) ?? (throw FileIOException(message: 'Photo storage failed completely'));
  }

  /// Get all stored photos
  List<StoredPhoto> getAllPhotos() {
    return List.from(_photos);
  }

  /// Get photos with filtering options
  List<StoredPhoto> getPhotos({
    DateTime? fromDate,
    DateTime? toDate,
    bool? synced,
    String? searchTerm,
  }) {
    var filtered = _photos.where((photo) {
      if (fromDate != null && photo.capturedAt.isBefore(fromDate)) {
        return false;
      }
      if (toDate != null && photo.capturedAt.isAfter(toDate)) {
        return false;
      }
      if (synced != null && photo.isSynced != synced) {
        return false;
      }
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final term = searchTerm.toLowerCase();
        if (!photo.fileName.toLowerCase().contains(term) &&
            !photo.metadata.toString().toLowerCase().contains(term)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort by capture date (newest first)
    filtered.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    
    return filtered;
  }

  /// Get a specific photo by ID
  StoredPhoto? getPhotoById(String id) {
    try {
      return _photos.firstWhere((photo) => photo.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update photo metadata (e.g., after AI analysis)
  Future<StoredPhoto> updatePhotoMetadata({
    required String photoId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? aiAnalysis,
    Map<String, dynamic>? cameraSettings,
    bool? isSynced,
    List<String>? syncTargets,
  }) async {
    final photoIndex = _photos.indexWhere((photo) => photo.id == photoId);
    if (photoIndex == -1) {
      throw Exception('Photo not found: $photoId');
    }

    final updatedPhoto = _photos[photoIndex].copyWith(
      metadata: metadata,
      aiAnalysis: aiAnalysis,
      cameraSettings: cameraSettings,
      isSynced: isSynced,
      syncTargets: syncTargets,
    );

    _photos[photoIndex] = updatedPhoto;
    await _savePhotosMetadata();
    
    debugPrint('$_logTag: Updated metadata for photo $photoId');
    return updatedPhoto;
  }

  /// Delete a photo and its metadata
  Future<bool> deletePhoto(String photoId) async {
    try {
      final photo = getPhotoById(photoId);
      if (photo == null) return false;

      // Delete main image file
      final photoFile = File(photo.filePath);
      if (await photoFile.exists()) {
        await photoFile.delete();
      }

      // Delete thumbnail if exists
      if (photo.thumbnailPath != null) {
        final thumbnailFile = File(photo.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }

      // Remove from collection
      _photos.removeWhere((p) => p.id == photoId);
      await _savePhotosMetadata();

      debugPrint('$_logTag: Deleted photo $photoId');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag: Failed to delete photo $photoId: $e');
      return false;
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    if (!_isInitialized) await initialize();

    final totalPhotos = _photos.length;
    final totalBytes = _photos.fold<int>(0, (sum, photo) => sum + photo.fileSize);
    final syncedPhotos = _photos.where((p) => p.isSynced).length;
    final unsyncedPhotos = totalPhotos - syncedPhotos;

    return {
      'totalPhotos': totalPhotos,
      'totalBytes': totalBytes,
      'totalSize': _formatBytes(totalBytes),
      'syncedPhotos': syncedPhotos,
      'unsyncedPhotos': unsyncedPhotos,
      'syncedPercentage': totalPhotos > 0 ? (syncedPhotos / totalPhotos * 100).round() : 0,
    };
  }

  /// Load photos metadata from disk
  Future<void> _loadPhotosMetadata() async {
    try {
      if (await _metadataFile!.exists()) {
        final jsonString = await _metadataFile!.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _photos = jsonList.map((json) => StoredPhoto.fromJson(json)).toList();
        
        // Validate file existence and remove missing photos
        final validPhotos = <StoredPhoto>[];
        for (final photo in _photos) {
          if (await File(photo.filePath).exists()) {
            validPhotos.add(photo);
          } else {
            debugPrint('$_logTag: Removing missing photo: ${photo.filePath}');
          }
        }
        
        if (validPhotos.length != _photos.length) {
          _photos = validPhotos;
          await _savePhotosMetadata();
        }
      }
    } catch (e) {
      debugPrint('$_logTag: Failed to load metadata: $e');
      _photos = [];
    }
  }

  /// Save photos metadata to disk
  Future<void> _savePhotosMetadata() async {
    try {
      final jsonList = _photos.map((photo) => photo.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _metadataFile!.writeAsString(jsonString);
    } catch (e) {
      debugPrint('$_logTag: Failed to save metadata: $e');
    }
  }

  /// Generate unique photo ID
  String _generatePhotoId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'photo_${timestamp}_$random';
  }

  /// Generate thumbnail for photo (basic implementation)
  Future<String?> _generateThumbnail(Uint8List imageBytes, String photoId) async {
    try {
      // For now, just save the original image as thumbnail
      // In a real implementation, you'd resize the image
      final thumbnailFileName = '$photoId.thumb.jpg';
      final thumbnailFile = File(path.join(_thumbnailsDirectory!.path, thumbnailFileName));
      
      // Simple implementation - just copy original (should be resized in production)
      await thumbnailFile.writeAsBytes(imageBytes);
      
      return thumbnailFile.path;
    } catch (e) {
      debugPrint('$_logTag: Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// Check if there's insufficient storage space
  Future<bool> _checkInsufficientSpace(int requiredBytes) async {
    try {
      if (_photosDirectory == null) return true;
      
      final directory = _photosDirectory!;
      final stat = await directory.stat();
      
      // Simple check - if we can't determine space, assume we have enough
      return false;
    } catch (e) {
      // If we can't check space, assume we have enough
      return false;
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Clear all stored photos (for testing/debugging)
  Future<void> clearAllPhotos() async {
    if (!_isInitialized) await initialize();
    
    try {
      // Delete all photo files
      if (await _photosDirectory!.exists()) {
        await _photosDirectory!.delete(recursive: true);
        await _photosDirectory!.create();
      }
      
      // Delete all thumbnails
      if (await _thumbnailsDirectory!.exists()) {
        await _thumbnailsDirectory!.delete(recursive: true);
        await _thumbnailsDirectory!.create();
      }
      
      // Clear metadata
      _photos.clear();
      await _savePhotosMetadata();
      
      debugPrint('$_logTag: Cleared all photos');
      
    } catch (e) {
      debugPrint('$_logTag: Failed to clear photos: $e');
    }
  }
}