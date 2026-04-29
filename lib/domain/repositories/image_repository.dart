import 'dart:typed_data';
import '../entities/image_entity.dart';

/// Abstract repository for image operations
abstract class ImageRepository {
  /// Pick an image from the camera
  Future<ImageEntity?> pickFromCamera();

  /// Pick an image from the gallery
  Future<ImageEntity?> pickFromGallery();

  /// Load an image from a file path
  Future<ImageEntity?> loadFromFile(String filePath);

  /// Load an image from bytes
  Future<ImageEntity?> loadFromBytes(Uint8List bytes, String id);

  /// Save an image to the device gallery
  Future<bool> saveToGallery(ImageEntity image, {String? fileName});

  /// Get image metadata (dimensions, file size, etc.)
  Future<Map<String, dynamic>> getImageMetadata(String filePath);

  /// Resize an image to specified dimensions
  Future<ImageEntity?> resizeImage(
    ImageEntity image,
    int maxWidth,
    int maxHeight,
  );

  /// Convert image to different format (JPEG, PNG, etc.)
  Future<ImageEntity?> convertImageFormat(ImageEntity image, String format);

  /// Validate if file is a supported image format
  bool isValidImageFile(String filePath);

  /// Get supported image formats
  List<String> getSupportedFormats();

  /// Clean up temporary files
  Future<void> cleanupTempFiles();
}
