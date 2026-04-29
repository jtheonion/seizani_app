import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for caching processed images to improve performance
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, String> _diskCache = {};
  late Directory _cacheDir;
  bool _isInitialized = false;

  /// Maximum memory cache size (in bytes) - 50MB
  static const int _maxMemoryCacheSize = 50 * 1024 * 1024;

  /// Maximum disk cache size (in bytes) - 200MB
  static const int _maxDiskCacheSize = 200 * 1024 * 1024;

  /// Current memory cache size
  int _currentMemoryCacheSize = 0;

  /// Initialize cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/image_cache');

      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      _isInitialized = true;

      // Clean up old cache entries on startup
      await _cleanupOldCacheEntries();
    } catch (e) {
      throw Exception('Failed to initialize image cache: $e');
    }
  }

  /// Generate cache key from image data
  String _generateCacheKey(String originalPath, int width, int height) {
    final fileName = originalPath.split('/').last;
    final timestamp = File(
      originalPath,
    ).statSync().modified.millisecondsSinceEpoch;
    return '${fileName}_${width}x${height}_$timestamp';
  }

  /// Get cached image bytes
  Future<Uint8List?> getCachedImage(
    String originalPath,
    int width,
    int height,
  ) async {
    if (!_isInitialized) await initialize();

    final cacheKey = _generateCacheKey(originalPath, width, height);

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Check disk cache
    if (_diskCache.containsKey(cacheKey)) {
      try {
        final cacheFile = File(_diskCache[cacheKey]!);
        if (await cacheFile.exists()) {
          final bytes = await cacheFile.readAsBytes();

          // Add to memory cache if there's space
          await _addToMemoryCache(cacheKey, bytes);

          return bytes;
        } else {
          // Remove invalid disk cache entry
          _diskCache.remove(cacheKey);
        }
      } catch (e) {
        // Remove corrupted cache entry
        _diskCache.remove(cacheKey);
      }
    }

    return null;
  }

  /// Cache processed image
  Future<void> cacheImage(
    String originalPath,
    int width,
    int height,
    Uint8List imageBytes,
  ) async {
    if (!_isInitialized) await initialize();

    final cacheKey = _generateCacheKey(originalPath, width, height);

    try {
      // Add to memory cache
      await _addToMemoryCache(cacheKey, imageBytes);

      // Add to disk cache
      await _addToDiskCache(cacheKey, imageBytes);
    } catch (e) {
      // Cache operation failed, but don't throw error
      debugPrint('Warning: Failed to cache image: $e');
    }
  }

  /// Add image to memory cache with size management
  Future<void> _addToMemoryCache(String cacheKey, Uint8List imageBytes) async {
    final imageSize = imageBytes.lengthInBytes;

    // Ensure we don't exceed memory cache limit
    while (_currentMemoryCacheSize + imageSize > _maxMemoryCacheSize &&
        _memoryCache.isNotEmpty) {
      // Remove oldest entry (simple FIFO strategy)
      final oldestKey = _memoryCache.keys.first;
      final removedSize = _memoryCache[oldestKey]!.lengthInBytes;
      _memoryCache.remove(oldestKey);
      _currentMemoryCacheSize -= removedSize;
    }

    // Add new entry
    if (imageSize <= _maxMemoryCacheSize) {
      _memoryCache[cacheKey] = imageBytes;
      _currentMemoryCacheSize += imageSize;
    }
  }

  /// Add image to disk cache
  Future<void> _addToDiskCache(String cacheKey, Uint8List imageBytes) async {
    try {
      final cacheFile = File('${_cacheDir.path}/$cacheKey.cache');
      await cacheFile.writeAsBytes(imageBytes);
      _diskCache[cacheKey] = cacheFile.path;

      // Check disk cache size and cleanup if needed
      await _manageDiskCacheSize();
    } catch (e) {
      // Disk cache operation failed - use debugPrint for logging
      debugPrint('Warning: Failed to write to disk cache: $e');
    }
  }

  /// Manage disk cache size
  Future<void> _manageDiskCacheSize() async {
    try {
      final files = _cacheDir.listSync().whereType<File>().toList();
      int totalSize = 0;

      // Calculate total cache size
      for (final file in files) {
        totalSize += await file.length();
      }

      // If over limit, remove oldest files
      if (totalSize > _maxDiskCacheSize) {
        // Sort by modification time (oldest first)
        files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );

        for (final file in files) {
          if (totalSize <= _maxDiskCacheSize * 0.8) break; // Keep 80% of limit

          try {
            final fileSize = await file.length();
            await file.delete();
            totalSize -= fileSize;

            // Remove from cache map
            _diskCache.removeWhere((key, value) => value == file.path);
          } catch (e) {
            // Continue with next file if deletion fails
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to manage disk cache size: $e');
    }
  }

  /// Clean up old cache entries (older than 7 days)
  Future<void> _cleanupOldCacheEntries() async {
    try {
      final now = DateTime.now();
      const maxAge = Duration(days: 7);

      final files = _cacheDir.listSync().whereType<File>().toList();

      for (final file in files) {
        final fileAge = now.difference(file.statSync().modified);
        if (fileAge > maxAge) {
          try {
            await file.delete();
            // Remove from cache map
            _diskCache.removeWhere((key, value) => value == file.path);
          } catch (e) {
            // Continue with next file if deletion fails
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to cleanup old cache entries: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      // Clear memory cache
      _memoryCache.clear();
      _currentMemoryCacheSize = 0;

      // Clear disk cache
      if (_isInitialized && await _cacheDir.exists()) {
        final files = _cacheDir.listSync().whereType<File>().toList();
        for (final file in files) {
          try {
            await file.delete();
          } catch (e) {
            // Continue with next file if deletion fails
          }
        }
      }

      _diskCache.clear();
    } catch (e) {
      debugPrint('Warning: Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    if (!_isInitialized) await initialize();

    int diskCacheSize = 0;
    int diskCacheFiles = 0;

    try {
      final files = _cacheDir.listSync().whereType<File>().toList();
      diskCacheFiles = files.length;

      for (final file in files) {
        diskCacheSize += await file.length();
      }
    } catch (e) {
      // Ignore errors for statistics
    }

    return CacheStats(
      memoryEntries: _memoryCache.length,
      memorySizeBytes: _currentMemoryCacheSize,
      diskEntries: diskCacheFiles,
      diskSizeBytes: diskCacheSize,
    );
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}

/// Cache statistics
class CacheStats {
  final int memoryEntries;
  final int memorySizeBytes;
  final int diskEntries;
  final int diskSizeBytes;

  const CacheStats({
    required this.memoryEntries,
    required this.memorySizeBytes,
    required this.diskEntries,
    required this.diskSizeBytes,
  });

  double get memorySizeMB => memorySizeBytes / (1024 * 1024);
  double get diskSizeMB => diskSizeBytes / (1024 * 1024);
  int get totalEntries => memoryEntries + diskEntries;
  double get totalSizeMB => memorySizeMB + diskSizeMB;

  @override
  String toString() {
    return 'CacheStats('
        'memory: $memoryEntries entries (${memorySizeMB.toStringAsFixed(1)}MB), '
        'disk: $diskEntries entries (${diskSizeMB.toStringAsFixed(1)}MB)'
        ')';
  }
}
