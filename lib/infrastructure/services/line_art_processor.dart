import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint, kDebugMode;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../domain/entities/image_entity.dart';
import '../../domain/entities/line_art_entity.dart';
import 'dexined_onnx_line_art_service.dart' hide ProcessingException;

/// Service for processing images into line art
class LineArtProcessor {
  static const String algorithmVersion = '1.0.0';
  static const Uuid _uuid = Uuid();

  /// Process image into line art using specified algorithm
  static Future<LineArtEntity> processToLineArt(
    ImageEntity imageEntity,
    LineArtParameters parameters,
  ) async {
    try {
      debugPrint(
        '🎨 [DEBUG] LineArtProcessor.processToLineArt開始 - 画像: ${imageEntity.id}',
      );

      final stopwatch = Stopwatch()..start();

      if (parameters.algorithm == LineArtAlgorithm.dexined) {
        if (imageEntity.bytes == null) {
          throw ProcessingException('画像データが見つかりません');
        }

        final lineArtData = await DexiNedOnnxLineArtService.process(
          imageEntity.bytes!,
          parameters: parameters,
        );
        stopwatch.stop();

        final metadata = LineArtMetadata(
          processingTime: stopwatch.elapsed,
          algorithm: parameters.algorithm,
          edgeStrength: parameters.edgeThreshold,
          contrastLevel: parameters.contrast,
          algorithmVersion: algorithmVersion,
          parameters: {
            ...parameters.toJson(),
            'modelAsset': DexiNedOnnxLineArtService.modelAssetPath,
            'modelInput': DexiNedOnnxLineArtService.inputName,
            'modelOutput': DexiNedOnnxLineArtService.outputName,
            'modelInputShape': [
              1,
              3,
              DexiNedOnnxLineArtService.modelHeight,
              DexiNedOnnxLineArtService.modelWidth,
            ],
            'percentile': parameters.dexinedPercentile,
            'minThreshold': parameters.dexinedMinThreshold,
            'dexinedPercentile': parameters.dexinedPercentile,
            'dexinedMinThreshold': parameters.dexinedMinThreshold,
            'lineThickness': parameters.lineThickness,
          },
        );

        debugPrint(
          '✅ [DEBUG] DexiNed線画処理完了 - 処理時間: ${stopwatch.elapsedMilliseconds}ms',
        );

        return LineArtEntity(
          id: _uuid.v4(),
          originalImageId: imageEntity.id,
          lineArtImageBytes: lineArtData.bytes,
          width: lineArtData.width,
          height: lineArtData.height,
          createdAt: DateTime.now(),
          metadata: metadata,
        );
      }

      // Process in isolate for performance
      final lineArtData = await compute(
        _processLineArtIsolate,
        LineArtProcessingTask(
          imageBytes: imageEntity.bytes!,
          width: imageEntity.width,
          height: imageEntity.height,
          parameters: parameters,
        ),
      );

      stopwatch.stop();

      debugPrint(
        '✅ [DEBUG] LineArt処理完了 - 処理時間: ${stopwatch.elapsedMilliseconds}ms',
      );

      // Create metadata
      final metadata = LineArtMetadata(
        processingTime: stopwatch.elapsed,
        algorithm: parameters.algorithm,
        edgeStrength: parameters.edgeThreshold,
        contrastLevel: parameters.contrast,
        algorithmVersion: algorithmVersion,
        parameters: parameters.toJson(),
      );

      // Create LineArtEntity
      return LineArtEntity(
        id: _uuid.v4(),
        originalImageId: imageEntity.id,
        lineArtImageBytes: lineArtData['processedBytes'] as Uint8List,
        width: lineArtData['width'] as int,
        height: lineArtData['height'] as int,
        createdAt: DateTime.now(),
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      debugPrint('💥 [ERROR] LineArtProcessor.processToLineArt失敗: $e');
      debugPrint('📋 [ERROR] Stack trace: $stackTrace');
      throw ProcessingException('線画変換処理に失敗しました: $e');
    }
  }

  /// Isolate function for line art processing
  static Map<String, dynamic> _processLineArtIsolate(
    LineArtProcessingTask task,
  ) {
    if (kDebugMode) debugPrint('Starting line art processing in isolate');

    // Decode image
    final image = img.decodeImage(task.imageBytes);
    if (image == null) {
      throw ProcessingException('画像のデコードに失敗しました');
    }

    // Resize if needed for performance
    final processedImage = _preprocessImage(image, task.parameters);

    // Apply line art algorithm based on parameters
    final lineArtImage = _applyLineArtAlgorithm(
      processedImage,
      task.parameters,
    );

    // Post-process (contrast, inversion, etc.)
    final finalImage = _postProcessImage(lineArtImage, task.parameters);

    // Encode result
    final processedBytes = Uint8List.fromList(img.encodePng(finalImage));

    debugPrint(
      '✅ [DEBUG] Isolate線画処理完了 - サイズ: ${finalImage.width}x${finalImage.height}',
    );

    return {
      'processedBytes': processedBytes,
      'width': finalImage.width,
      'height': finalImage.height,
    };
  }

  /// Preprocess image (resize, normalize)
  static img.Image _preprocessImage(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) {
      debugPrint(
        'Starting image preprocessing - original size: ${image.width}x${image.height}',
      );
    }

    // Convert to grayscale for edge detection
    img.Image processed = img.grayscale(image);

    // Apply gaussian blur if smoothing is enabled
    if (parameters.smoothLines) {
      processed = img.gaussianBlur(processed, radius: 1);
    }

    // Normalize contrast
    processed = img.adjustColor(processed, contrast: parameters.contrast);

    if (kDebugMode) debugPrint('Image preprocessing completed');
    return processed;
  }

  /// Apply line art algorithm based on parameters
  static img.Image _applyLineArtAlgorithm(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) {
      debugPrint('Starting line art algorithm: ${parameters.algorithm}');
    }

    switch (parameters.algorithm) {
      case LineArtAlgorithm.sobel:
        return _applySobelEdgeDetection(image, parameters);
      case LineArtAlgorithm.canny:
        return _applyCannyEdgeDetection(image, parameters);
      case LineArtAlgorithm.xdog:
        return _applyXDoG(image, parameters);
      case LineArtAlgorithm.pencilSketch:
        return _applyPencilSketch(image, parameters);
      case LineArtAlgorithm.adaptiveEdge:
        return _applyAdaptiveEdgeDetection(image, parameters);
      case LineArtAlgorithm.dexined:
        throw ProcessingException('DexiNedはONNX推論サービス経由で実行してください');
    }
  }

  /// Apply Sobel edge detection
  static img.Image _applySobelEdgeDetection(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Applying Sobel edge detection');

    // Apply Sobel filter with amount parameter
    final sobelImage = img.sobel(image, amount: parameters.edgeThreshold * 2);

    // Apply threshold to create clean lines
    final threshold = (255 * (1.0 - parameters.edgeThreshold)).round();

    for (int y = 0; y < sobelImage.height; y++) {
      for (int x = 0; x < sobelImage.width; x++) {
        final pixel = sobelImage.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        // Threshold to create binary image
        final newColor = luminance < threshold
            ? img.ColorRgb8(0, 0, 0) // Black for edges
            : img.ColorRgb8(255, 255, 255); // White for background

        sobelImage.setPixel(x, y, newColor);
      }
    }

    if (kDebugMode) debugPrint('Sobel edge detection completed');
    return sobelImage;
  }

  /// Apply Canny edge detection (simplified version using convolution)
  static img.Image _applyCannyEdgeDetection(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Applying Canny edge detection');

    // First apply Gaussian blur
    final blurred = img.gaussianBlur(image, radius: 1);

    // Apply Sobel X and Y kernels
    final sobelX = img.convolution(
      blurred,
      filter: [-1, 0, 1, -2, 0, 2, -1, 0, 1],
    );

    final sobelY = img.convolution(
      blurred,
      filter: [-1, -2, -1, 0, 0, 0, 1, 2, 1],
    );

    // Calculate gradient magnitude
    final result = img.Image(width: image.width, height: image.height);

    final threshold = parameters.edgeThreshold * 255;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixelX = img.getLuminance(sobelX.getPixel(x, y));
        final pixelY = img.getLuminance(sobelY.getPixel(x, y));

        final magnitude = math.sqrt(pixelX * pixelX + pixelY * pixelY);

        final newColor = magnitude > threshold
            ? img.ColorRgb8(0, 0, 0) // Black for edges
            : img.ColorRgb8(255, 255, 255); // White for background

        result.setPixel(x, y, newColor);
      }
    }

    if (kDebugMode) debugPrint('Canny edge detection completed');
    return result;
  }

  /// Apply XDoG (Extended Difference of Gaussians)
  static img.Image _applyXDoG(img.Image image, LineArtParameters parameters) {
    if (kDebugMode) debugPrint('Applying XDoG algorithm');

    // Apply two different Gaussian blurs
    final blur1 = img.gaussianBlur(image, radius: parameters.sigma1.round());
    final blur2 = img.gaussianBlur(image, radius: parameters.sigma2.round());

    // Calculate difference
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel1 = img.getLuminance(blur1.getPixel(x, y));
        final pixel2 = img.getLuminance(blur2.getPixel(x, y));

        // XDoG formula: DoG = (1 + τ) * G1 - τ * G2
        final dog = (1 + parameters.tau) * pixel1 - parameters.tau * pixel2;

        // Apply threshold function with phi and epsilon
        double output;
        if (dog < parameters.epsilon) {
          output = 1.0;
        } else {
          // tanh approximation: tanh(x) = (exp(2x) - 1) / (exp(2x) + 1)
          final x = parameters.phi * dog;
          final exp2x = math.exp(2 * x);
          final tanh = (exp2x - 1) / (exp2x + 1);
          output = 1.0 + tanh;
        }

        final colorValue = (output * 255).clamp(0, 255).round();
        final newColor = img.ColorRgb8(colorValue, colorValue, colorValue);
        result.setPixel(x, y, newColor);
      }
    }

    if (kDebugMode) debugPrint('XDoG completed');
    return result;
  }

  /// Apply pencil sketch effect
  static img.Image _applyPencilSketch(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Applying pencil sketch effect');

    // Convert to grayscale (already done in preprocessing)
    final grayscale = image;

    // Create inverted image
    final inverted = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(grayscale.getPixel(x, y));
        final invertedValue = 255 - pixel.round();
        final color = img.ColorRgb8(
          invertedValue,
          invertedValue,
          invertedValue,
        );
        inverted.setPixel(x, y, color);
      }
    }

    // Apply heavy blur to inverted image
    final blurredInverted = img.gaussianBlur(
      inverted,
      radius: (parameters.sigma1 * 10).round(),
    );

    // Blend original grayscale with blurred inverted (divide blend)
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = img.getLuminance(grayscale.getPixel(x, y));
        final blurred = img.getLuminance(blurredInverted.getPixel(x, y));

        // Divide blend mode (with protection against division by zero)
        final blendValue = blurred == 0
            ? 255
            : ((original * 256) / (256 - blurred)).clamp(0, 255);
        final colorValue = blendValue.round();

        final color = img.ColorRgb8(colorValue, colorValue, colorValue);
        result.setPixel(x, y, color);
      }
    }

    if (kDebugMode) debugPrint('Pencil sketch completed');
    return result;
  }

  /// Apply adaptive edge detection
  static img.Image _applyAdaptiveEdgeDetection(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Applying adaptive edge detection');

    // Use Sobel as base but with local threshold adaptation
    final sobelImage = img.sobel(image, amount: 1.0);

    // Calculate local statistics for adaptive thresholding
    final windowSize = 15;
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Calculate local mean in window
        double localSum = 0;
        int count = 0;

        for (int dy = -windowSize ~/ 2; dy <= windowSize ~/ 2; dy++) {
          for (int dx = -windowSize ~/ 2; dx <= windowSize ~/ 2; dx++) {
            final nx = (x + dx).clamp(0, image.width - 1);
            final ny = (y + dy).clamp(0, image.height - 1);
            localSum += img.getLuminance(sobelImage.getPixel(nx, ny));
            count++;
          }
        }

        final localMean = localSum / count;
        final localThreshold = localMean * parameters.edgeThreshold;

        final pixel = img.getLuminance(sobelImage.getPixel(x, y));

        final newColor = pixel > localThreshold
            ? img.ColorRgb8(0, 0, 0) // Black for edges
            : img.ColorRgb8(255, 255, 255); // White for background

        result.setPixel(x, y, newColor);
      }
    }

    if (kDebugMode) debugPrint('Adaptive edge detection completed');
    return result;
  }

  /// Post-process image (inversion, final adjustments)
  static img.Image _postProcessImage(
    img.Image image,
    LineArtParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Starting image post-processing');

    img.Image result = image;

    // Apply color inversion if requested
    if (parameters.invertColors) {
      result = img.Image(width: image.width, height: image.height);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = 255 - pixel.r.round();
          final g = 255 - pixel.g.round();
          final b = 255 - pixel.b.round();

          result.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
    }

    // Apply final contrast adjustment
    result = img.adjustColor(
      result,
      contrast: 1.2, // Slightly increase contrast for cleaner lines
    );

    if (kDebugMode) debugPrint('Image post-processing completed');
    return result;
  }
}

/// Task data for line art processing in isolate
class LineArtProcessingTask {
  final Uint8List imageBytes;
  final int width;
  final int height;
  final LineArtParameters parameters;

  const LineArtProcessingTask({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.parameters,
  });
}

/// Exception thrown when line art processing fails
class ProcessingException implements Exception {
  final String message;

  const ProcessingException(this.message);

  @override
  String toString() => 'ProcessingException: $message';
}
