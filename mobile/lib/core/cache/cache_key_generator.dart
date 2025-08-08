import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Advanced cache key generator with content-aware and hierarchical key strategies
/// 
/// Features:
/// - Content-based keys using hashing algorithms
/// - Hierarchical namespace management
/// - Collision-resistant key generation
/// - Configurable key formats and lengths
/// - Support for compound keys and prefixes
class CacheKeyGenerator {
  static const String _defaultSeparator = ':';
  static const int _defaultHashLength = 16;
  
  final String _separator;
  final int _hashLength;
  
  CacheKeyGenerator({
    String separator = _defaultSeparator,
    int hashLength = _defaultHashLength,
  })  : _separator = separator,
        _hashLength = hashLength;
  
  /// Generate a cache key with optional namespace and parameters
  String generate(String baseKey, {
    String? namespace,
    Map<String, dynamic>? parameters,
    String? version,
  }) {
    final parts = <String>[];
    
    // Add namespace if provided
    if (namespace != null && namespace.isNotEmpty) {
      parts.add(_sanitizeComponent(namespace));
    }
    
    // Add version if provided
    if (version != null && version.isNotEmpty) {
      parts.add('v$version');
    }
    
    // Add base key
    parts.add(_sanitizeComponent(baseKey));
    
    // Add parameters hash if provided
    if (parameters != null && parameters.isNotEmpty) {
      final paramHash = _hashParameters(parameters);
      parts.add(paramHash);
    }
    
    return parts.join(_separator);
  }
  
  /// Generate content-based key using image or data hash
  String generateContentKey(Uint8List content, {
    String? prefix,
    String? namespace,
    ContentHashAlgorithm algorithm = ContentHashAlgorithm.sha256,
  }) {
    final contentHash = _hashContent(content, algorithm);
    
    final parts = <String>[];
    
    if (namespace != null) {
      parts.add(_sanitizeComponent(namespace));
    }
    
    if (prefix != null) {
      parts.add(_sanitizeComponent(prefix));
    }
    
    parts.add(contentHash);
    
    return parts.join(_separator);
  }
  
  /// Generate hierarchical key for nested data structures
  String generateHierarchicalKey(List<String> hierarchy, {
    String? namespace,
    Map<String, dynamic>? parameters,
  }) {
    final parts = <String>[];
    
    if (namespace != null) {
      parts.add(_sanitizeComponent(namespace));
    }
    
    // Add hierarchy levels
    for (final level in hierarchy) {
      parts.add(_sanitizeComponent(level));
    }
    
    // Add parameters if provided
    if (parameters != null && parameters.isNotEmpty) {
      final paramHash = _hashParameters(parameters);
      parts.add(paramHash);
    }
    
    return parts.join(_separator);
  }
  
  /// Generate compound key from multiple components
  String generateCompoundKey(Map<String, dynamic> components, {
    String? namespace,
  }) {
    final sortedComponents = Map.fromEntries(
      components.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    
    final parts = <String>[];
    
    if (namespace != null) {
      parts.add(_sanitizeComponent(namespace));
    }
    
    for (final entry in sortedComponents.entries) {
      final key = _sanitizeComponent(entry.key);
      final value = _sanitizeComponent(entry.value.toString());
      parts.add('$key=$value');
    }
    
    // If compound key is too long, hash it
    final compoundKey = parts.join(_separator);
    if (compoundKey.length > 200) {
      final hash = _hashString(compoundKey);
      return namespace != null ? '$namespace$_separator$hash' : hash;
    }
    
    return compoundKey;
  }
  
  /// Generate AI-specific cache key for model results
  String generateAIKey({
    required String modelId,
    required String inputHash,
    Map<String, dynamic>? parameters,
    String? version,
  }) {
    return generate(
      'ai_$modelId',
      namespace: 'ai_results',
      parameters: {
        'input': inputHash,
        if (parameters != null) ...parameters,
      },
      version: version,
    );
  }
  
  /// Generate image-specific cache key
  String generateImageKey({
    required Uint8List imageData,
    String? operation,
    Map<String, dynamic>? settings,
  }) {
    final imageHash = _hashContent(imageData, ContentHashAlgorithm.sha256);
    
    return generate(
      operation ?? 'processed',
      namespace: 'images',
      parameters: {
        'image': imageHash,
        if (settings != null) ...settings,
      },
    );
  }
  
  /// Generate thumbnail cache key
  String generateThumbnailKey({
    required String originalImageKey,
    required int width,
    required int height,
    String quality = 'medium',
  }) {
    return generate(
      'thumb',
      namespace: 'thumbnails',
      parameters: {
        'original': originalImageKey,
        'size': '${width}x$height',
        'quality': quality,
      },
    );
  }
  
  /// Generate camera settings cache key
  String generateCameraSettingsKey({
    required String sceneType,
    required Map<String, dynamic> conditions,
    String? cameraModel,
  }) {
    return generate(
      'settings',
      namespace: 'camera',
      parameters: {
        'scene': sceneType,
        'conditions': _hashParameters(conditions),
        if (cameraModel != null) 'model': cameraModel,
      },
    );
  }
  
  /// Generate user preference cache key
  String generateUserPreferenceKey({
    required String userId,
    required String preferenceType,
    String? context,
  }) {
    return generate(
      preferenceType,
      namespace: 'user_prefs',
      parameters: {
        'user': _hashString(userId), // Hash for privacy
        if (context != null) 'context': context,
      },
    );
  }
  
  /// Extract namespace from cache key
  String? extractNamespace(String cacheKey) {
    final parts = cacheKey.split(_separator);
    if (parts.length > 1) {
      return parts.first;
    }
    return null;
  }
  
  /// Check if key matches pattern
  bool matchesPattern(String key, String pattern) {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    return regex.hasMatch(key);
  }
  
  /// Generate pattern for namespace-based clearing
  String generateNamespacePattern(String namespace) {
    return '^${RegExp.escape(namespace)}$_separator.*';
  }
  
  /// Validate cache key format
  bool isValidKey(String key) {
    // Check for invalid characters
    if (key.contains(RegExp(r'[<>:"/\\|?*]'))) {
      return false;
    }
    
    // Check length limits
    if (key.length > 250 || key.isEmpty) {
      return false;
    }
    
    // Check for valid structure
    final parts = key.split(_separator);
    return parts.every((part) => part.isNotEmpty);
  }
  
  // Private helper methods
  
  String _sanitizeComponent(String component) {
    // Remove or replace invalid characters
    return component
        .replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
  
  String _hashParameters(Map<String, dynamic> parameters) {
    // Sort parameters for consistent hashing
    final sortedParams = Map.fromEntries(
      parameters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    
    final paramString = jsonEncode(sortedParams);
    return _hashString(paramString);
  }
  
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, _hashLength);
  }
  
  String _hashContent(Uint8List content, ContentHashAlgorithm algorithm) {
    late Digest digest;
    
    switch (algorithm) {
      case ContentHashAlgorithm.md5:
        digest = md5.convert(content);
        break;
      case ContentHashAlgorithm.sha1:
        digest = sha1.convert(content);
        break;
      case ContentHashAlgorithm.sha256:
        digest = sha256.convert(content);
        break;
    }
    
    return digest.toString().substring(0, _hashLength);
  }
}

/// Content hashing algorithms for cache keys
enum ContentHashAlgorithm {
  md5,
  sha1,
  sha256,
}

/// Cache key utility functions
class CacheKeyUtils {
  /// Extract timestamp from versioned cache key
  static DateTime? extractTimestamp(String key) {
    final timestampMatch = RegExp(r'ts(\d{13})').firstMatch(key);
    if (timestampMatch != null) {
      final timestamp = int.tryParse(timestampMatch.group(1)!);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    return null;
  }
  
  /// Add timestamp to cache key
  static String addTimestamp(String key, [DateTime? timestamp]) {
    final ts = timestamp ?? DateTime.now();
    return '${key}_ts${ts.millisecondsSinceEpoch}';
  }
  
  /// Remove timestamp from cache key
  static String removeTimestamp(String key) {
    return key.replaceAll(RegExp(r'_ts\d{13}'), '');
  }
  
  /// Check if two keys represent the same content
  static bool isSameContent(String key1, String key2) {
    final clean1 = removeTimestamp(key1);
    final clean2 = removeTimestamp(key2);
    return clean1 == clean2;
  }
  
  /// Generate batch key for multiple related items
  static String generateBatchKey(List<String> individualKeys, String batchType) {
    final keyHash = sha256.convert(utf8.encode(individualKeys.join('|')));
    return 'batch_${batchType}_${keyHash.toString().substring(0, 16)}';
  }
  
  /// Parse compound key into components
  static Map<String, String> parseCompoundKey(String key, String separator) {
    final parts = key.split(separator);
    final components = <String, String>{};
    
    for (final part in parts) {
      if (part.contains('=')) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          components[keyValue[0]] = keyValue[1];
        }
      }
    }
    
    return components;
  }
}

/// Specialized key generators for different data types
class ImageCacheKeyGenerator extends CacheKeyGenerator {
  /// Generate key for raw image data
  String rawImageKey(Uint8List imageData) {
    return generateContentKey(
      imageData,
      prefix: 'raw',
      namespace: 'images',
    );
  }
  
  /// Generate key for processed image
  String processedImageKey(Uint8List originalData, String operation, Map<String, dynamic> params) {
    final originalHash = _hashContent(originalData, ContentHashAlgorithm.sha256);
    return generate(
      '${operation}_$originalHash',
      namespace: 'processed',
      parameters: params,
    );
  }
  
  /// Generate key for image analysis results
  String analysisKey(Uint8List imageData, String analysisType) {
    return generateContentKey(
      imageData,
      prefix: analysisType,
      namespace: 'analysis',
    );
  }
}

class AICacheKeyGenerator extends CacheKeyGenerator {
  /// Generate key for AI model inference
  String inferenceKey(String modelId, Uint8List inputData, Map<String, dynamic> params) {
    final inputHash = _hashContent(inputData, ContentHashAlgorithm.sha256);
    return generate(
      'inference',
      namespace: 'ai_$modelId',
      parameters: {
        'input': inputHash,
        ...params,
      },
    );
  }
  
  /// Generate key for scene analysis
  String sceneAnalysisKey(Uint8List imageData, String analysisVersion) {
    return generateContentKey(
      imageData,
      prefix: 'scene',
      namespace: 'analysis',
      algorithm: ContentHashAlgorithm.sha256,
    );
  }
  
  /// Generate key for AI suggestions
  String suggestionsKey(String sceneAnalysisKey, Map<String, dynamic> context) {
    return generate(
      'suggestions',
      namespace: 'ai_results',
      parameters: {
        'scene': sceneAnalysisKey,
        'context': _hashParameters(context),
      },
    );
  }
}