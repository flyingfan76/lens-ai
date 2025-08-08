import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Advanced memory manager for efficient image processing and resource handling
class MemoryManager {
  static const int _lowMemoryThreshold = 100 * 1024 * 1024; // 100MB
  static const int _criticalMemoryThreshold = 50 * 1024 * 1024; // 50MB
  static const int _maxImageBufferSize = 200 * 1024 * 1024; // 200MB
  static const int _maxBufferPoolSize = 10;
  
  // Buffer pool for reusing image memory
  final List<Uint8List> _bufferPool = [];
  final Map<String, Uint8List> _tempAllocations = {};
  
  // Memory monitoring
  int _currentMemoryUsage = 0;
  int _peakMemoryUsage = 0;
  final List<MemoryAllocation> _activeAllocations = [];
  
  // Performance tracking
  int _bufferReuses = 0;
  int _memoryOptimizations = 0;
  int _gcTriggers = 0;
  
  // Singleton pattern for global memory management
  static MemoryManager? _instance;
  static MemoryManager get instance => _instance ??= MemoryManager._internal();
  
  MemoryManager._internal() {
    _startMemoryMonitoring();
  }
  
  factory MemoryManager() => instance;
  
  /// Check if sufficient memory is available for allocation
  Future<bool> ensureMemoryAvailable(int requiredBytes) async {
    final systemMemory = await _getAvailableSystemMemory();
    
    if (systemMemory != null && systemMemory < _criticalMemoryThreshold) {
      // Trigger aggressive cleanup
      await _aggressiveCleanup();
      _gcTriggers++;
      
      // Recheck after cleanup
      final newSystemMemory = await _getAvailableSystemMemory();
      if (newSystemMemory != null && newSystemMemory < requiredBytes) {
        throw MemoryException('Insufficient memory: ${newSystemMemory}B available, ${requiredBytes}B required');
      }
    }
    
    // Check if we need to free buffers
    if (_currentMemoryUsage + requiredBytes > _maxImageBufferSize) {
      await _freeOldestBuffers(requiredBytes);
    }
    
    return true;
  }
  
  /// Allocate optimized buffer with reuse capability
  Uint8List allocateBuffer(int size, {String? tag}) {
    // Try to reuse existing buffer
    final reusableBuffer = _findReusableBuffer(size);
    if (reusableBuffer != null) {
      _bufferReuses++;
      _recordAllocation(size, tag ?? 'reused_buffer');
      return reusableBuffer;
    }
    
    // Allocate new buffer
    final buffer = Uint8List(size);
    _recordAllocation(size, tag ?? 'new_buffer');
    
    return buffer;
  }
  
  /// Release buffer back to pool for reuse
  void releaseBuffer(Uint8List buffer, {bool allowReuse = true}) {
    _removeAllocation(buffer);
    
    if (allowReuse && _bufferPool.length < _maxBufferPoolSize && buffer.length >= 1024) {
      // Clear buffer and add to pool
      buffer.fillRange(0, buffer.length, 0);
      _bufferPool.add(buffer);
    }
  }
  
  /// Create temporary allocation that will be auto-cleaned
  Uint8List allocateTemp(int size, String tag) {
    final buffer = allocateBuffer(size, tag: 'temp_$tag');
    _tempAllocations[tag] = buffer;
    return buffer;
  }
  
  /// Release all temporary allocations
  Future<void> releaseTempMemory() async {
    for (final entry in _tempAllocations.entries) {
      releaseBuffer(entry.value);
    }
    _tempAllocations.clear();
    
    // Trigger minor GC if we have many temp allocations
    if (_tempAllocations.length > 5) {
      await _triggerMinorGC();
    }
  }
  
  /// Get optimized image buffer for processing
  ImageBuffer getImageBuffer(int width, int height, {int channels = 4}) {
    final size = width * height * channels;
    final buffer = allocateBuffer(size, tag: 'image_${width}x${height}');
    
    return ImageBuffer(
      data: buffer,
      width: width,
      height: height,
      channels: channels,
      manager: this,
    );
  }
  
  /// Optimize memory layout for better cache performance
  Uint8List optimizeMemoryLayout(Uint8List source, int width, int height, {int channels = 4}) {
    final optimized = allocateBuffer(source.length, tag: 'optimized_layout');
    
    // Reorganize data for better spatial locality
    if (channels == 4) {
      _optimizeRGBALayout(source, optimized, width, height);
    } else if (channels == 3) {
      _optimizeRGBLayout(source, optimized, width, height);
    } else {
      // Default: just copy
      optimized.setAll(0, source);
    }
    
    _memoryOptimizations++;
    return optimized;
  }
  
  /// Get current memory statistics
  MemoryStats getMemoryStats() {
    return MemoryStats(
      currentUsage: _currentMemoryUsage,
      peakUsage: _peakMemoryUsage,
      bufferPoolSize: _bufferPool.length,
      activeAllocations: _activeAllocations.length,
      bufferReuses: _bufferReuses,
      optimizations: _memoryOptimizations,
      gcTriggers: _gcTriggers,
    );
  }
  
  /// Check if we're in low memory condition
  Future<bool> isLowMemory() async {
    final systemMemory = await _getAvailableSystemMemory();
    return systemMemory != null && systemMemory < _lowMemoryThreshold;
  }
  
  /// Force garbage collection and cleanup
  Future<void> forceCleanup() async {
    await _aggressiveCleanup();
    await _triggerMajorGC();
  }
  
  // Private methods
  
  void _startMemoryMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final stats = getMemoryStats();
      
      if (stats.currentUsage > _maxImageBufferSize * 0.8) {
        debugPrint('MemoryManager: High memory usage detected: ${stats.currentUsage}B');
        await _moderateCleanup();
      }
      
      // Update peak usage
      if (_currentMemoryUsage > _peakMemoryUsage) {
        _peakMemoryUsage = _currentMemoryUsage;
      }
    });
  }
  
  Future<int?> _getAvailableSystemMemory() async {
    try {
      if (Platform.isAndroid) {
        // On Android, we can get memory info through platform channels
        const platform = MethodChannel('com.lensai.memory');
        final result = await platform.invokeMethod<int>('getAvailableMemory');
        return result;
      } else if (Platform.isIOS) {
        // On iOS, use similar approach
        const platform = MethodChannel('com.lensai.memory');
        final result = await platform.invokeMethod<int>('getAvailableMemory');
        return result;
      }
    } catch (e) {
      debugPrint('MemoryManager: Failed to get system memory: $e');
    }
    return null;
  }
  
  Uint8List? _findReusableBuffer(int requiredSize) {
    for (int i = 0; i < _bufferPool.length; i++) {
      final buffer = _bufferPool[i];
      if (buffer.length >= requiredSize) {
        _bufferPool.removeAt(i);
        return buffer;
      }
    }
    return null;
  }
  
  void _recordAllocation(int size, String tag) {
    _currentMemoryUsage += size;
    _activeAllocations.add(MemoryAllocation(
      size: size,
      tag: tag,
      timestamp: DateTime.now(),
    ));
  }
  
  void _removeAllocation(Uint8List buffer) {
    final size = buffer.length;
    _currentMemoryUsage -= size;
    
    // Remove from active allocations (simple approach - find by size)
    _activeAllocations.removeWhere((alloc) => alloc.size == size);
  }
  
  Future<void> _freeOldestBuffers(int requiredBytes) async {
    // Sort by timestamp and free oldest first
    _activeAllocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    int freed = 0;
    final toRemove = <MemoryAllocation>[];
    
    for (final allocation in _activeAllocations) {
      if (freed >= requiredBytes) break;
      
      freed += allocation.size;
      toRemove.add(allocation);
    }
    
    // Remove freed allocations
    for (final allocation in toRemove) {
      _activeAllocations.remove(allocation);
      _currentMemoryUsage -= allocation.size;
    }
    
    debugPrint('MemoryManager: Freed ${freed}B from ${toRemove.length} allocations');
  }
  
  Future<void> _moderateCleanup() async {
    // Clear half of buffer pool
    final halfSize = _bufferPool.length ~/ 2;
    _bufferPool.removeRange(0, halfSize);
    
    // Release temp allocations
    await releaseTempMemory();
    
    await _triggerMinorGC();
  }
  
  Future<void> _aggressiveCleanup() async {
    // Clear entire buffer pool
    _bufferPool.clear();
    
    // Release all temp allocations
    await releaseTempMemory();
    
    // Clear old allocations
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _activeAllocations.removeWhere((alloc) => alloc.timestamp.isBefore(cutoff));
    
    await _triggerMajorGC();
    
    debugPrint('MemoryManager: Aggressive cleanup completed');
  }
  
  Future<void> _triggerMinorGC() async {
    // Minor GC suggestion
    if (!kIsWeb) {
      // Allow other operations to complete
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
  
  Future<void> _triggerMajorGC() async {
    // Major GC suggestion
    if (!kIsWeb) {
      // Force a longer pause to allow GC
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
  
  void _optimizeRGBALayout(Uint8List source, Uint8List dest, int width, int height) {
    // Convert from interleaved RGBA to planar layout for better cache locality
    final pixels = width * height;
    
    for (int i = 0; i < pixels; i++) {
      final srcIdx = i * 4;
      dest[i] = source[srcIdx]; // R plane
      dest[pixels + i] = source[srcIdx + 1]; // G plane
      dest[pixels * 2 + i] = source[srcIdx + 2]; // B plane
      dest[pixels * 3 + i] = source[srcIdx + 3]; // A plane
    }
  }
  
  void _optimizeRGBLayout(Uint8List source, Uint8List dest, int width, int height) {
    // Convert from interleaved RGB to planar layout
    final pixels = width * height;
    
    for (int i = 0; i < pixels; i++) {
      final srcIdx = i * 3;
      dest[i] = source[srcIdx]; // R plane
      dest[pixels + i] = source[srcIdx + 1]; // G plane
      dest[pixels * 2 + i] = source[srcIdx + 2]; // B plane
    }
  }
  
  void dispose() {
    _bufferPool.clear();
    _tempAllocations.clear();
    _activeAllocations.clear();
    _currentMemoryUsage = 0;
    debugPrint('MemoryManager: Disposed');
  }
}

/// Wrapper for image buffer with automatic memory management
class ImageBuffer {
  final Uint8List data;
  final int width;
  final int height;
  final int channels;
  final MemoryManager manager;
  
  bool _disposed = false;
  
  ImageBuffer({
    required this.data,
    required this.width,
    required this.height,
    required this.channels,
    required this.manager,
  });
  
  /// Get pixel at coordinates
  List<int> getPixel(int x, int y) {
    if (_disposed) throw StateError('Buffer has been disposed');
    
    final index = (y * width + x) * channels;
    if (channels == 4) {
      return [data[index], data[index + 1], data[index + 2], data[index + 3]];
    } else if (channels == 3) {
      return [data[index], data[index + 1], data[index + 2]];
    } else {
      return [data[index]];
    }
  }
  
  /// Set pixel at coordinates
  void setPixel(int x, int y, List<int> pixel) {
    if (_disposed) throw StateError('Buffer has been disposed');
    
    final index = (y * width + x) * channels;
    for (int i = 0; i < pixel.length && i < channels; i++) {
      data[index + i] = pixel[i];
    }
  }
  
  /// Create a copy of this buffer
  ImageBuffer copy() {
    if (_disposed) throw StateError('Buffer has been disposed');
    
    final newData = manager.allocateBuffer(data.length, tag: 'image_copy');
    newData.setAll(0, data);
    
    return ImageBuffer(
      data: newData,
      width: width,
      height: height,
      channels: channels,
      manager: manager,
    );
  }
  
  /// Dispose the buffer
  void dispose() {
    if (!_disposed) {
      manager.releaseBuffer(data);
      _disposed = true;
    }
  }
}

/// Memory allocation tracking
class MemoryAllocation {
  final int size;
  final String tag;
  final DateTime timestamp;
  
  MemoryAllocation({
    required this.size,
    required this.tag,
    required this.timestamp,
  });
}

/// Memory usage statistics
class MemoryStats {
  final int currentUsage;
  final int peakUsage;
  final int bufferPoolSize;
  final int activeAllocations;
  final int bufferReuses;
  final int optimizations;
  final int gcTriggers;
  
  MemoryStats({
    required this.currentUsage,
    required this.peakUsage,
    required this.bufferPoolSize,
    required this.activeAllocations,
    required this.bufferReuses,
    required this.optimizations,
    required this.gcTriggers,
  });
  
  double get reuseRatio => bufferReuses / (bufferReuses + activeAllocations);
  double get memoryEfficiency => currentUsage / peakUsage;
  
  @override
  String toString() {
    return 'MemoryStats(current: ${(currentUsage / 1024 / 1024).toStringAsFixed(1)}MB, '
           'peak: ${(peakUsage / 1024 / 1024).toStringAsFixed(1)}MB, '
           'pool: $bufferPoolSize, active: $activeAllocations, '
           'reuse: ${(reuseRatio * 100).toStringAsFixed(1)}%, '
           'efficiency: ${(memoryEfficiency * 100).toStringAsFixed(1)}%)';
  }
}

/// Custom exception for memory-related errors
class MemoryException implements Exception {
  final String message;
  
  MemoryException(this.message);
  
  @override
  String toString() => 'MemoryException: $message';
}