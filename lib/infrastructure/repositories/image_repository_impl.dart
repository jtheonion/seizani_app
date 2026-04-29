import 'dart:typed_data';
import '../../domain/entities/image_entity.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/local_image_datasource.dart';

/// Implementation of ImageRepository using local data sources
class ImageRepositoryImpl implements ImageRepository {
  final LocalImageDataSource _localImageDataSource;

  const ImageRepositoryImpl({
    required LocalImageDataSource localImageDataSource,
  }) : _localImageDataSource = localImageDataSource;

  @override
  Future<ImageEntity?> pickFromCamera() async {
    try {
      return await _localImageDataSource.pickFromCamera();
    } catch (e) {
      throw ImageRepositoryException('カメラからの画像選択に失敗: $e');
    }
  }

  @override
  Future<ImageEntity?> pickFromGallery() async {
    try {
      return await _localImageDataSource.pickFromGallery();
    } catch (e) {
      throw ImageRepositoryException('ギャラリーからの画像選択に失敗: $e');
    }
  }

  @override
  Future<ImageEntity?> loadFromFile(String filePath) async {
    try {
      return await _localImageDataSource.loadFromFile(filePath);
    } catch (e) {
      throw ImageRepositoryException('ファイルからの画像読み込みに失敗: $e');
    }
  }

  @override
  Future<ImageEntity?> loadFromBytes(Uint8List bytes, String id) async {
    try {
      return await _localImageDataSource.loadFromBytes(bytes, id);
    } catch (e) {
      throw ImageRepositoryException('バイト配列からの画像読み込みに失敗: $e');
    }
  }

  @override
  Future<bool> saveToGallery(ImageEntity image, {String? fileName}) async {
    try {
      return await _localImageDataSource.saveToGallery(
        image,
        fileName: fileName,
      );
    } catch (e) {
      throw ImageRepositoryException('ギャラリー保存に失敗: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getImageMetadata(String filePath) async {
    try {
      return await _localImageDataSource.getImageMetadata(filePath);
    } catch (e) {
      throw ImageRepositoryException('画像メタデータ取得に失敗: $e');
    }
  }

  @override
  Future<ImageEntity?> resizeImage(
    ImageEntity image,
    int maxWidth,
    int maxHeight,
  ) async {
    try {
      return await _localImageDataSource.resizeImage(
        image,
        maxWidth,
        maxHeight,
      );
    } catch (e) {
      throw ImageRepositoryException('画像リサイズに失敗: $e');
    }
  }

  @override
  Future<ImageEntity?> convertImageFormat(
    ImageEntity image,
    String format,
  ) async {
    try {
      return await _localImageDataSource.convertImageFormat(image, format);
    } catch (e) {
      throw ImageRepositoryException('画像フォーマット変換に失敗: $e');
    }
  }

  @override
  bool isValidImageFile(String filePath) {
    return _localImageDataSource.isValidImageFile(filePath);
  }

  @override
  List<String> getSupportedFormats() {
    return _localImageDataSource.getSupportedFormats();
  }

  @override
  Future<void> cleanupTempFiles() async {
    try {
      await _localImageDataSource.cleanupTempFiles();
    } catch (e) {
      // Silently fail for cleanup operations
    }
  }
}

/// Exception for image repository operations
class ImageRepositoryException implements Exception {
  final String message;
  const ImageRepositoryException(this.message);

  @override
  String toString() => 'ImageRepositoryException: $message';
}
