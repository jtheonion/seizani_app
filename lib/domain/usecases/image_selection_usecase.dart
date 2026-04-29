import 'dart:typed_data';

import '../entities/image_entity.dart';
import '../repositories/image_repository.dart';

/// Use case for selecting and validating images
class ImageSelectionUseCase {
  final ImageRepository _imageRepository;

  const ImageSelectionUseCase(this._imageRepository);

  /// Select image from camera
  Future<ImageSelectionResult> selectFromCamera() async {
    try {
      final image = await _imageRepository.pickFromCamera();
      if (image == null) {
        return const ImageSelectionResult.cancelled();
      }

      final validationResult = await _validateImage(image);
      if (!validationResult.isValid) {
        return ImageSelectionResult.error(validationResult.error!);
      }

      return ImageSelectionResult.success(image);
    } on Exception catch (e) {
      // Enhanced error handling with detailed context
      String errorMessage = 'カメラからの画像取得に失敗しました';

      if (e.toString().contains('カメラの許可が必要です')) {
        errorMessage = 'カメラの使用許可が必要です。設定から許可してください。';
      } else if (e.toString().contains('カメラへのアクセスが拒否されました')) {
        errorMessage = 'カメラへのアクセスが拒否されました。設定から許可してください。';
      } else if (e.toString().contains('デコードに失敗')) {
        errorMessage = '撮影した画像の処理に失敗しました。もう一度お試しください。';
      }

      return ImageSelectionResult.error('$errorMessage ($e)');
    } catch (e) {
      return ImageSelectionResult.error('予期しないエラーが発生しました: $e');
    }
  }

  /// Select image from gallery
  Future<ImageSelectionResult> selectFromGallery() async {
    try {
      final image = await _imageRepository.pickFromGallery();
      if (image == null) {
        return const ImageSelectionResult.cancelled();
      }

      final validationResult = await _validateImage(image);
      if (!validationResult.isValid) {
        return ImageSelectionResult.error(validationResult.error!);
      }

      return ImageSelectionResult.success(image);
    } on Exception catch (e) {
      // Enhanced error handling with detailed context
      String errorMessage = 'ギャラリーからの画像取得に失敗しました';

      if (e.toString().contains('写真ライブラリの許可が必要です')) {
        errorMessage = '写真ライブラリの使用許可が必要です。設定から許可してください。';
      } else if (e.toString().contains('写真ライブラリへのアクセスが拒否されました')) {
        errorMessage = '写真ライブラリへのアクセスが拒否されました。設定から許可してください。';
      } else if (e.toString().contains('デコードに失敗')) {
        errorMessage = '選択した画像の処理に失敗しました。別の画像をお試しください。';
      }

      return ImageSelectionResult.error('$errorMessage ($e)');
    } catch (e) {
      return ImageSelectionResult.error('予期しないエラーが発生しました: $e');
    }
  }

  /// Load image from file path
  Future<ImageSelectionResult> loadFromFile(String filePath) async {
    try {
      if (!_imageRepository.isValidImageFile(filePath)) {
        return const ImageSelectionResult.error('サポートされていない画像形式です');
      }

      final image = await _imageRepository.loadFromFile(filePath);
      if (image == null) {
        return const ImageSelectionResult.error('画像の読み込みに失敗しました');
      }

      final validationResult = await _validateImage(image);
      if (!validationResult.isValid) {
        return ImageSelectionResult.error(validationResult.error!);
      }

      return ImageSelectionResult.success(image);
    } catch (e) {
      return ImageSelectionResult.error('画像の読み込みに失敗しました: $e');
    }
  }

  /// Load image from raw bytes, used for bundled validation samples.
  Future<ImageSelectionResult> loadFromBytes(
    Uint8List bytes, {
    String? id,
  }) async {
    try {
      final image = await _imageRepository.loadFromBytes(
        bytes,
        id ?? 'bytes_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (image == null) {
        return const ImageSelectionResult.error('画像の読み込みに失敗しました');
      }

      final validationResult = await _validateImage(image);
      if (!validationResult.isValid) {
        return ImageSelectionResult.error(validationResult.error!);
      }

      return ImageSelectionResult.success(image);
    } catch (e) {
      return ImageSelectionResult.error('画像データの読み込みに失敗しました: $e');
    }
  }

  /// Prepare image for processing (resize if needed)
  Future<ImageSelectionResult> prepareImageForProcessing(
    ImageEntity image,
  ) async {
    try {
      // Check if image needs resizing for better performance
      const maxWidth = 1200;
      const maxHeight = 1200;

      if (image.width > maxWidth || image.height > maxHeight) {
        final resizedImage = await _imageRepository.resizeImage(
          image,
          maxWidth,
          maxHeight,
        );

        if (resizedImage == null) {
          return const ImageSelectionResult.error('画像のリサイズに失敗しました');
        }

        return ImageSelectionResult.success(resizedImage);
      }

      return ImageSelectionResult.success(image);
    } catch (e) {
      return ImageSelectionResult.error('画像の前処理に失敗しました: $e');
    }
  }

  /// Validate image for processing with enhanced error messages
  Future<ImageValidationResult> _validateImage(ImageEntity image) async {
    // Check minimum dimensions
    const minWidth = 100;
    const minHeight = 100;

    if (image.width < minWidth || image.height < minHeight) {
      return ImageValidationResult.invalid(
        '画像が小さすぎます。最小サイズ: ${minWidth}x${minHeight}px '
        '(現在: ${image.width}x${image.height}px)',
      );
    }

    // Check maximum dimensions
    const maxWidth = 4000;
    const maxHeight = 4000;

    if (image.width > maxWidth || image.height > maxHeight) {
      return ImageValidationResult.invalid(
        '画像が大きすぎます。最大サイズ: ${maxWidth}x${maxHeight}px '
        '(現在: ${image.width}x${image.height}px)',
      );
    }

    // Check aspect ratio (should be reasonable)
    final aspectRatio = image.width / image.height;
    if (aspectRatio < 0.1 || aspectRatio > 10.0) {
      return ImageValidationResult.invalid(
        '画像のアスペクト比が極端すぎます。'
        '横縦比: ${aspectRatio.toStringAsFixed(2)}:1',
      );
    }

    // Check file size if available
    if (image.bytes != null) {
      final fileSizeMB = image.bytes!.lengthInBytes / (1024 * 1024);
      const maxFileSizeMB = 50; // 50MB limit

      if (fileSizeMB > maxFileSizeMB) {
        return ImageValidationResult.invalid(
          'ファイルサイズが大きすぎます。最大: ${maxFileSizeMB}MB '
          '(現在: ${fileSizeMB.toStringAsFixed(1)}MB)',
        );
      }
    }

    return const ImageValidationResult.valid();
  }

  /// Get supported image formats
  List<String> getSupportedFormats() {
    return _imageRepository.getSupportedFormats();
  }
}

/// Result of image selection operation
class ImageSelectionResult {
  final ImageEntity? image;
  final String? error;
  final bool isSuccess;
  final bool isCancelled;

  const ImageSelectionResult.success(ImageEntity image)
    : image = image,
      error = null,
      isSuccess = true,
      isCancelled = false;

  const ImageSelectionResult.error(String error)
    : image = null,
      error = error,
      isSuccess = false,
      isCancelled = false;

  const ImageSelectionResult.cancelled()
    : image = null,
      error = null,
      isSuccess = false,
      isCancelled = true;
}

/// Result of image validation
class ImageValidationResult {
  final bool isValid;
  final String? error;

  const ImageValidationResult.valid() : isValid = true, error = null;
  const ImageValidationResult.invalid(String error)
    : isValid = false,
      error = error;
}
