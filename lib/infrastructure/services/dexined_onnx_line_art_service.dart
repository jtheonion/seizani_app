import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/line_art_entity.dart';

/// Runs the OpenCV DexiNed ONNX model and converts its edge response to line art.
class DexiNedOnnxLineArtService {
  static const String modelAssetPath =
      'assets/models/edge_detection_dexined_2024sep_ort.onnx';
  static const String inputName = 'img';
  static const String outputName = 'block_cat';
  static const int modelWidth = 640;
  static const int modelHeight = 480;
  static const double defaultPercentile = 92.0;
  static const int defaultMinThreshold = 24;

  static final OnnxRuntime _runtime = OnnxRuntime();
  static Future<OrtSession>? _sessionFuture;

  const DexiNedOnnxLineArtService._();

  static Future<DexiNedLineArtResult> process(
    Uint8List imageBytes, {
    LineArtParameters parameters = LineArtParameters.dexinedDefaults,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const ProcessingException('DexiNed入力画像のデコードに失敗しました');
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
        throw const ProcessingException('DexiNed ONNX出力が空でした');
      }

      final flattened = await output.asFlattenedList();
      final lineArtImage = postProcessLogitsForTesting(
        flattened.cast<num>(),
        outputWidth: modelWidth,
        outputHeight: modelHeight,
        targetWidth: decoded.width,
        targetHeight: decoded.height,
        percentile: parameters.dexinedPercentile,
        minThreshold: parameters.dexinedMinThreshold,
        lineThickness: parameters.lineThickness,
      );

      return DexiNedLineArtResult(
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
        tensor[offset] = pixel.b.toDouble() - 103.5;
        tensor[channelSize + offset] = pixel.g.toDouble() - 116.2;
        tensor[channelSize * 2 + offset] = pixel.r.toDouble() - 123.6;
      }
    }

    return tensor;
  }

  @visibleForTesting
  static img.Image postProcessLogitsForTesting(
    List<num> logits, {
    required int outputWidth,
    required int outputHeight,
    required int targetWidth,
    required int targetHeight,
    double percentile = defaultPercentile,
    int minThreshold = defaultMinThreshold,
    double lineThickness = 1.0,
  }) {
    final expectedLength = outputWidth * outputHeight;
    if (logits.length != expectedLength) {
      throw ProcessingException(
        'DexiNed ONNX出力サイズが不正です: ${logits.length} != $expectedLength',
      );
    }

    final normalized = _normalizeToUint8(logits);
    final responseImage = img.Image(width: outputWidth, height: outputHeight);
    for (var y = 0; y < outputHeight; y++) {
      for (var x = 0; x < outputWidth; x++) {
        final value = normalized[y * outputWidth + x];
        responseImage.setPixelRgb(x, y, value, value, value);
      }
    }

    final resized = targetWidth == outputWidth && targetHeight == outputHeight
        ? responseImage
        : img.copyResize(
            responseImage,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          );

    final values = List<int>.filled(resized.width * resized.height, 0);
    var index = 0;
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        values[index++] = img.getLuminance(resized.getPixel(x, y)).round();
      }
    }

    final threshold = math.max(
      minThreshold,
      _percentileThreshold(values, percentile),
    );

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

  static Uint8List _normalizeToUint8(List<num> logits) {
    final probabilities = Float64List(logits.length);
    var minValue = double.infinity;
    var maxValue = double.negativeInfinity;

    for (var i = 0; i < logits.length; i++) {
      final probability = _sigmoid(logits[i].toDouble());
      probabilities[i] = probability;
      if (probability < minValue) minValue = probability;
      if (probability > maxValue) maxValue = probability;
    }

    final range = maxValue - minValue;
    final normalized = Uint8List(logits.length);
    if (range <= 1e-12) return normalized;

    for (var i = 0; i < probabilities.length; i++) {
      normalized[i] = (((probabilities[i] - minValue) / range) * 255)
          .clamp(0, 255)
          .round();
    }
    return normalized;
  }

  static double _sigmoid(double value) {
    if (value >= 0) {
      final exp = math.exp(-value);
      return 1.0 / (1.0 + exp);
    }
    final exp = math.exp(value);
    return exp / (1.0 + exp);
  }

  static int _percentileThreshold(List<int> values, double percentile) {
    if (values.isEmpty) return 255;
    final sorted = List<int>.from(values)..sort();
    final clipped = percentile.clamp(0.0, 100.0);
    final rank = ((clipped / 100.0) * (sorted.length - 1)).round();
    return sorted[rank];
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

class DexiNedLineArtResult {
  const DexiNedLineArtResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Exception thrown when DexiNed processing fails before repository wrapping.
class ProcessingException implements Exception {
  final String message;

  const ProcessingException(this.message);

  @override
  String toString() => 'ProcessingException: $message';
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
