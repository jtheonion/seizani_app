import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/line_art_entity.dart';

/// Runs a PiDiNet ONNX model and converts its edge response to line art.
class PidinetOnnxLineArtService {
  static const String modelAssetPath =
      'assets/models/pidinet_table5_carv4_ort.onnx';
  static const String inputName = 'input';
  static const String outputName = 'edge';
  static const int modelWidth = 640;
  static const int modelHeight = 480;
  static const String checkpointSha256 =
      '80860ac267258b5f27486e0ef152a211d0b08120f62aeb185a050acc30da486c';
  static const String licensePolicy = 'non-commercial-app-assumption';

  static final OnnxRuntime _runtime = OnnxRuntime();
  static Future<OrtSession>? _sessionFuture;

  const PidinetOnnxLineArtService._();

  static Future<PidinetLineArtResult> process(
    Uint8List imageBytes, {
    LineArtParameters parameters = LineArtParameters.pidinetDefaults,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const ProcessingException('PiDiNet入力画像のデコードに失敗しました');
    }

    final session = await _loadSession();
    final inputTensor = _createInputTensor(decoded);
    final inputValue = await OrtValue.fromList(inputTensor, [
      1,
      3,
      modelHeight,
      modelWidth,
    ]);

    Map<String, OrtValue> outputs = const {};
    try {
      outputs = await session.run({inputName: inputValue});
      final output = outputs[outputName] ?? outputs.values.lastOrNull;
      if (output == null) {
        throw const ProcessingException('PiDiNet ONNX出力が空でした');
      }

      final flattened = await output.asFlattenedList();
      final lineArtImage = postProcessEdgesForTesting(
        flattened.cast<num>(),
        outputWidth: modelWidth,
        outputHeight: modelHeight,
        targetWidth: decoded.width,
        targetHeight: decoded.height,
        edgeThreshold: parameters.edgeThreshold,
        contrast: parameters.contrast,
        lineThickness: parameters.lineThickness,
      );

      return PidinetLineArtResult(
        bytes: Uint8List.fromList(img.encodePng(lineArtImage)),
        width: lineArtImage.width,
        height: lineArtImage.height,
      );
    } finally {
      await inputValue.dispose();
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }

  static Future<OrtSession> _loadSession() {
    final existing = _sessionFuture;
    if (existing != null) return existing;

    final future = _runtime.createSessionFromAsset(
      modelAssetPath,
      options: OrtSessionOptions(
        providers: const [OrtProvider.CPU],
        intraOpNumThreads: 2,
      ),
    );
    _sessionFuture = future;
    return future;
  }

  static Float32List _createInputTensor(img.Image source) {
    final resized = img.copyResize(
      source,
      width: modelWidth,
      height: modelHeight,
      interpolation: img.Interpolation.linear,
    );
    final tensor = Float32List(3 * modelHeight * modelWidth);
    final channelSize = modelHeight * modelWidth;

    for (var y = 0; y < modelHeight; y++) {
      for (var x = 0; x < modelWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final offset = y * modelWidth + x;
        tensor[offset] = (pixel.r / 255.0 - 0.485) / 0.229;
        tensor[channelSize + offset] = (pixel.g / 255.0 - 0.456) / 0.224;
        tensor[channelSize * 2 + offset] = (pixel.b / 255.0 - 0.406) / 0.225;
      }
    }

    return tensor;
  }

  @visibleForTesting
  static img.Image postProcessEdgesForTesting(
    List<num> edges, {
    required int outputWidth,
    required int outputHeight,
    required int targetWidth,
    required int targetHeight,
    double edgeThreshold = 0.3,
    double contrast = 1.0,
    double lineThickness = 1.0,
  }) {
    final expectedLength = outputWidth * outputHeight;
    if (edges.length != expectedLength) {
      throw ProcessingException(
        'PiDiNet ONNX出力サイズが不正です: ${edges.length} != $expectedLength',
      );
    }

    final responseImage = img.Image(width: outputWidth, height: outputHeight);
    for (var y = 0; y < outputHeight; y++) {
      for (var x = 0; x < outputWidth; x++) {
        final probability = _edgeProbability(
          edges[y * outputWidth + x].toDouble(),
        );
        final value = (probability * 255).clamp(0, 255).round();
        responseImage.setPixelRgb(x, y, value, value, value);
      }
    }

    var resized = targetWidth == outputWidth && targetHeight == outputHeight
        ? responseImage
        : img.copyResize(
            responseImage,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          );
    resized = img.adjustColor(resized, contrast: contrast);

    final threshold = (edgeThreshold.clamp(0.0, 1.0) * 255).round();
    final lineArt = img.Image(width: resized.width, height: resized.height);
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final value = img.getLuminance(resized.getPixel(x, y)).round();
        if (value >= threshold) {
          lineArt.setPixelRgb(x, y, 0, 0, 0);
        } else {
          lineArt.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }

    return _applyLineThickness(lineArt, lineThickness);
  }

  static double _edgeProbability(double value) {
    if (value >= 0.0 && value <= 1.0) return value;
    if (value >= 0) {
      final exp = math.exp(-value);
      return 1.0 / (1.0 + exp);
    }
    final exp = math.exp(value);
    return exp / (1.0 + exp);
  }

  static img.Image _applyLineThickness(img.Image source, double lineThickness) {
    final radius = lineThickness.clamp(1.0, 3.0).round() - 1;
    if (radius <= 0) return source;

    final thickened = img.Image(width: source.width, height: source.height);
    img.fill(thickened, color: img.ColorRgb8(255, 255, 255));

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (img.getLuminance(source.getPixel(x, y)) >= 128) continue;

        for (var dy = -radius; dy <= radius; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= source.height) continue;

          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= source.width) continue;
            thickened.setPixelRgb(nx, ny, 0, 0, 0);
          }
        }
      }
    }

    return thickened;
  }
}

class PidinetLineArtResult {
  const PidinetLineArtResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Exception thrown when PiDiNet processing fails before repository wrapping.
class ProcessingException implements Exception {
  final String message;

  const ProcessingException(this.message);

  @override
  String toString() => 'ProcessingException: $message';
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
