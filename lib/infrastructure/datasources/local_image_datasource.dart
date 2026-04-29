import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/image_entity.dart';
import '../../core/services/image_cache_service.dart';

/// Local data source for image operations with memory optimization
class LocalImageDataSource {
  final ImagePicker _imagePicker;
  final ImageCacheService _cacheService;

  LocalImageDataSource({
    ImagePicker? imagePicker,
    ImageCacheService? cacheService,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _cacheService = cacheService ?? ImageCacheService();

  /// Pick image from camera
  Future<ImageEntity?> pickFromCamera() async {
    try {
      // Check camera permission
      final cameraPermission = await Permission.camera.status;
      if (cameraPermission.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          throw ImageDataSourceException('カメラの許可が必要です');
        }
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await _createImageEntityFromFile(File(pickedFile.path));
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw ImageDataSourceException('カメラへのアクセスが拒否されました');
      } else if (e.code == 'photo_access_denied') {
        throw ImageDataSourceException('写真ライブラリへのアクセスが拒否されました');
      }
      throw ImageDataSourceException('カメラからの画像取得に失敗: ${e.message}');
    } catch (e) {
      throw ImageDataSourceException('カメラからの画像取得に失敗: $e');
    }
  }

  /// Pick image from gallery
  Future<ImageEntity?> pickFromGallery() async {
    try {
      // Check photos permission
      Permission photosPermission = Permission.photos;
      if (Platform.isAndroid) {
        // Use mediaLibrary for Android
        photosPermission = Permission.mediaLibrary;
      }

      final photoPermission = await photosPermission.status;
      if (photoPermission.isDenied) {
        final result = await photosPermission.request();
        if (result.isDenied) {
          throw ImageDataSourceException('写真ライブラリの許可が必要です');
        }
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await _createImageEntityFromFile(File(pickedFile.path));
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        throw ImageDataSourceException('写真ライブラリへのアクセスが拒否されました');
      }
      throw ImageDataSourceException('ギャラリーからの画像取得に失敗: ${e.message}');
    } catch (e) {
      throw ImageDataSourceException('ギャラリーからの画像取得に失敗: $e');
    }
  }

  /// Load image from file path
  Future<ImageEntity?> loadFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ImageDataSourceException('ファイルが存在しません: $filePath');
      }

      return await _createImageEntityFromFile(file);
    } catch (e) {
      throw ImageDataSourceException('ファイル読み込みに失敗: $e');
    }
  }

  /// Load image from bytes
  Future<ImageEntity?> loadFromBytes(Uint8List bytes, String id) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw ImageDataSourceException('画像のデコードに失敗');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, '${id}_temp.png');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);

      return ImageEntity(
        id: id,
        path: tempPath,
        bytes: bytes,
        width: image.width,
        height: image.height,
        createdAt: DateTime.now(),
        metadata: await _getImageMetadata(tempPath),
      );
    } catch (e) {
      throw ImageDataSourceException('バイト配列からの画像読み込みに失敗: $e');
    }
  }

  /// Save image to gallery
  Future<bool> saveToGallery(
    ImageEntity imageEntity, {
    String? fileName,
  }) async {
    try {
      Uint8List? imageBytes = imageEntity.bytes;

      // If bytes are not available, read from file
      if (imageBytes == null && imageEntity.path.isNotEmpty) {
        final file = File(imageEntity.path);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      if (imageBytes == null) {
        throw ImageDataSourceException('画像データが見つかりません');
      }

      // Get the pictures directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw ImageDataSourceException('外部ストレージにアクセスできません');
      }

      final picturesDir = Directory('${directory.path}/Pictures');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final fileNameWithExt =
          fileName ?? 'seizani_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = path.join(picturesDir.path, fileNameWithExt);

      final imageFile = File(filePath);
      await imageFile.writeAsBytes(imageBytes);

      return true;
    } catch (e) {
      throw ImageDataSourceException('ギャラリー保存に失敗: $e');
    }
  }

  /// Get image metadata
  Future<Map<String, dynamic>> getImageMetadata(String filePath) async {
    return await _getImageMetadata(filePath);
  }

  /// Resize image (Thread-safe with caching)
  Future<ImageEntity?> resizeImage(
    ImageEntity imageEntity,
    int maxWidth,
    int maxHeight,
  ) async {
    try {
      // Check cache first
      if (imageEntity.path.isNotEmpty) {
        final cachedBytes = await _cacheService.getCachedImage(
          imageEntity.path,
          maxWidth,
          maxHeight,
        );

        if (cachedBytes != null) {
          // Return cached resized image
          final tempDir = await getTemporaryDirectory();
          final tempPath = path.join(
            tempDir.path,
            '${imageEntity.id}_resized_cached.png',
          );
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(cachedBytes);

          // Decode to get dimensions
          final imageData = await compute(_decodeImageInIsolate, cachedBytes);

          return ImageEntity(
            id: '${imageEntity.id}_resized_cached',
            path: tempPath,
            bytes: cachedBytes,
            width: imageData?['width'] ?? maxWidth,
            height: imageData?['height'] ?? maxHeight,
            createdAt: DateTime.now(),
            metadata: {
              ...imageEntity.metadata,
              'resized': true,
              'cached': true,
              'originalWidth': imageEntity.width,
              'originalHeight': imageEntity.height,
            },
          );
        }
      }

      Uint8List? imageBytes = imageEntity.bytes;

      // Get image bytes
      if (imageBytes == null && imageEntity.path.isNotEmpty) {
        final file = File(imageEntity.path);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      if (imageBytes == null) {
        throw ImageDataSourceException('画像データが見つかりません');
      }

      // Thread-safe image decoding and resizing
      final resizeData = await compute(_resizeImageInIsolate, {
        'bytes': imageBytes,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'originalId': imageEntity.id,
      });

      if (resizeData == null) {
        final fileSize = imageBytes.lengthInBytes;
        throw ImageDataSourceException(
          '画像のリサイズに失敗しました。'
          'ファイルサイズ: ${(fileSize / 1024).toStringAsFixed(1)}KB',
        );
      }

      final resizedBytes = resizeData['bytes'] as Uint8List;
      final newWidth = resizeData['width'] as int;
      final newHeight = resizeData['height'] as int;

      // Cache the resized image
      if (imageEntity.path.isNotEmpty) {
        await _cacheService.cacheImage(
          imageEntity.path,
          maxWidth,
          maxHeight,
          resizedBytes,
        );
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, '${imageEntity.id}_resized.png');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(resizedBytes);

      return ImageEntity(
        id: '${imageEntity.id}_resized',
        path: tempPath,
        bytes: resizedBytes,
        width: newWidth,
        height: newHeight,
        createdAt: DateTime.now(),
        metadata: {
          ...imageEntity.metadata,
          'resized': true,
          'originalWidth': imageEntity.width,
          'originalHeight': imageEntity.height,
        },
      );
    } catch (e) {
      throw ImageDataSourceException('画像リサイズに失敗: $e');
    }
  }

  /// Convert image format
  Future<ImageEntity?> convertImageFormat(
    ImageEntity imageEntity,
    String format,
  ) async {
    try {
      Uint8List? imageBytes = imageEntity.bytes;

      if (imageBytes == null && imageEntity.path.isNotEmpty) {
        final file = File(imageEntity.path);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      if (imageBytes == null) {
        throw ImageDataSourceException('画像データが見つかりません');
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw ImageDataSourceException('画像のデコードに失敗');
      }

      // Convert format
      Uint8List convertedBytes;
      String extension;

      switch (format.toUpperCase()) {
        case 'PNG':
          convertedBytes = Uint8List.fromList(img.encodePng(image));
          extension = 'png';
          break;
        case 'JPEG':
        case 'JPG':
          convertedBytes = Uint8List.fromList(
            img.encodeJpg(image, quality: 90),
          );
          extension = 'jpg';
          break;
        default:
          throw ImageDataSourceException('サポートされていない形式: $format');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(
        tempDir.path,
        '${imageEntity.id}_converted.$extension',
      );
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(convertedBytes);

      return ImageEntity(
        id: '${imageEntity.id}_converted',
        path: tempPath,
        bytes: convertedBytes,
        width: imageEntity.width,
        height: imageEntity.height,
        createdAt: DateTime.now(),
        metadata: {
          ...imageEntity.metadata,
          'converted': true,
          'format': format.toUpperCase(),
          'originalFormat': imageEntity.metadata['format'],
        },
      );
    } catch (e) {
      throw ImageDataSourceException('画像変換に失敗: $e');
    }
  }

  /// Check if file is valid image
  bool isValidImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const supportedExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.bmp',
      '.gif',
    ];
    return supportedExtensions.contains(extension);
  }

  /// Get supported formats
  List<String> getSupportedFormats() {
    return ['JPEG', 'PNG', 'WebP', 'BMP', 'GIF'];
  }

  /// Clean up temporary files and cache
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File &&
            (file.path.contains('_temp') || file.path.contains('_resized'))) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore individual file deletion errors
          }
        }
      }

      // Clean up old cache entries
      await _cacheService.clearCache();
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }

  /// Get cache statistics for monitoring
  Future<CacheStats> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }

  /// Clear all cached images
  Future<void> clearImageCache() async {
    await _cacheService.clearCache();
  }

  /// Create ImageEntity from File (Thread-safe)
  Future<ImageEntity> _createImageEntityFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileSize = bytes.lengthInBytes;

      // Thread-safe image decoding using compute isolate
      final imageData = await compute(_decodeImageInIsolate, bytes);

      if (imageData == null) {
        final filePath = file.path;
        final extension = path.extension(filePath).toLowerCase();
        throw ImageDataSourceException(
          '画像のデコードに失敗しました。'
          'ファイルサイズ: ${(fileSize / 1024).toStringAsFixed(1)}KB, '
          '形式: $extension',
        );
      }

      final id = DateTime.now().millisecondsSinceEpoch.toString();

      return ImageEntity(
        id: id,
        path: file.path,
        bytes: bytes,
        width: imageData['width'],
        height: imageData['height'],
        createdAt: DateTime.now(),
        metadata: await _getImageMetadata(file.path),
      );
    } catch (e) {
      if (e is ImageDataSourceException) {
        rethrow;
      }
      final fileSize = await file.length();
      throw ImageDataSourceException(
        'ImageEntity作成に失敗: $e '
        '(ファイルサイズ: ${(fileSize / 1024).toStringAsFixed(1)}KB)',
      );
    }
  }

  /// Static function for image decoding in isolate (Thread-safe)
  static Map<String, dynamic>? _decodeImageInIsolate(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      return {
        'width': image.width,
        'height': image.height,
        'hasAlpha': image.hasAlpha,
        'numChannels': image.numChannels,
      };
    } catch (e) {
      return null;
    }
  }

  /// Static function for image resizing in isolate (Thread-safe)
  static Map<String, dynamic>? _resizeImageInIsolate(
    Map<String, dynamic> data,
  ) {
    try {
      final bytes = data['bytes'] as Uint8List;
      final maxWidth = data['maxWidth'] as int;
      final maxHeight = data['maxHeight'] as int;

      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calculate new dimensions maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int newWidth, newHeight;

      if (image.width > image.height) {
        newWidth = maxWidth;
        newHeight = (maxWidth / aspectRatio).round();
        if (newHeight > maxHeight) {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      } else {
        newHeight = maxHeight;
        newWidth = (maxHeight * aspectRatio).round();
        if (newWidth > maxWidth) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        }
      }

      // Resize image
      final resized = img.copyResize(image, width: newWidth, height: newHeight);
      final resizedBytes = Uint8List.fromList(img.encodePng(resized));

      return {'bytes': resizedBytes, 'width': newWidth, 'height': newHeight};
    } catch (e) {
      return null;
    }
  }

  /// Get image metadata from file
  Future<Map<String, dynamic>> _getImageMetadata(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      return {
        'fileSize': stat.size,
        'format': path.extension(filePath).toUpperCase().replaceFirst('.', ''),
        'width': image?.width ?? 0,
        'height': image?.height ?? 0,
        'hasAlpha': image?.hasAlpha ?? false,
        'numberOfChannels': image?.numChannels ?? 0,
      };
    } catch (e) {
      return {};
    }
  }
}

/// Exception for image data source operations
class ImageDataSourceException implements Exception {
  final String message;
  const ImageDataSourceException(this.message);

  @override
  String toString() => 'ImageDataSourceException: $message';
}
