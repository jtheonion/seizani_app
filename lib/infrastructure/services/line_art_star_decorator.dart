import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/line_art_decoration_entity.dart';
import '../../domain/entities/line_art_entity.dart';

class LineArtStarDecorator {
  static const String algorithmVersion = '0.1.0';

  static Future<StarDecorationOutput> decorate(
    LineArtEntity lineArt,
    StarDecorationParams params,
  ) async {
    final stopwatch = Stopwatch()..start();

    final result = await compute(
      _decorateIsolate,
      StarDecorationTask(
        lineArtBytes: lineArt.lineArtImageBytes,
        width: lineArt.width,
        height: lineArt.height,
        params: params,
      ),
    );

    stopwatch.stop();

    return StarDecorationOutput(
      decoratedBytes: result['decoratedBytes'] as Uint8List,
      width: result['width'] as int,
      height: result['height'] as int,
      starCount: result['starCount'] as int,
      maskInverted: result['maskInverted'] as bool,
      processingTime: stopwatch.elapsed,
    );
  }

  static Map<String, dynamic> _decorateIsolate(StarDecorationTask task) {
    final image = img.decodeImage(task.lineArtBytes);
    if (image == null) {
      throw Exception('画像のデコードに失敗しました');
    }

    final grayscale = img.grayscale(image);
    final baseStats = _luminanceStats(grayscale, invert: false);
    final invertMask = baseStats.mean > 150.0;

    final stats = _luminanceStats(grayscale, invert: invertMask);
    final threshold = (stats.mean + stats.stdDev * 0.7).clamp(140.0, 235.0);

    final width = grayscale.width;
    final height = grayscale.height;
    final size = width * height;

    final mask = List<bool>.filled(size, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = grayscale.getPixel(x, y);
        var lum = img.getLuminance(pixel).toDouble();
        if (invertMask) lum = 255.0 - lum;
        mask[y * width + x] = lum >= threshold;
      }
    }

    final distance = _distanceTransform(mask, width, height);

    final safeDensity = task.params.starDensity <= 0
        ? 1.0
        : task.params.starDensity;
    final minDist = (8.0 / safeDensity).clamp(3.0, 18.0);
    final minDistSq = minDist * minDist;
    final lineThreshold = task.params.lineWidthThreshold.clamp(0.5, 12.0);

    final stride = lineThreshold >= 3.0 ? 2 : 1;
    final candidates = <math.Point<int>>[];
    for (var y = 0; y < height; y += stride) {
      for (var x = 0; x < width; x += stride) {
        final idx = y * width + x;
        if (!mask[idx]) continue;
        if (distance[idx] * 2 < lineThreshold) continue;
        candidates.add(math.Point<int>(x, y));
      }
    }

    final seed =
        task.params.seed ?? _deriveSeed(task.lineArtBytes, task.params);
    final rng = math.Random(seed);
    candidates.shuffle(rng);

    final targetCount = (width * height / (minDist * minDist)).round().clamp(
      1,
      20000,
    );

    final stars = _selectStars(
      candidates,
      width,
      height,
      minDistSq,
      targetCount,
    );

    final decorated = _renderStars(image, stars, task.params, rng);
    final decoratedBytes = Uint8List.fromList(img.encodePng(decorated));

    return {
      'decoratedBytes': decoratedBytes,
      'width': decorated.width,
      'height': decorated.height,
      'starCount': stars.length,
      'maskInverted': invertMask,
    };
  }

  static _LuminanceStats _luminanceStats(
    img.Image image, {
    required bool invert,
  }) {
    final total = image.width * image.height;
    if (total == 0) return const _LuminanceStats(0, 0);

    var sum = 0.0;
    var sumSq = 0.0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        var lum = img.getLuminance(pixel).toDouble();
        if (invert) lum = 255.0 - lum;
        sum += lum;
        sumSq += lum * lum;
      }
    }

    final mean = sum / total;
    final variance = (sumSq / total) - (mean * mean);
    final stdDev = math.sqrt(math.max(variance, 0));

    return _LuminanceStats(mean, stdDev);
  }

  static List<int> _distanceTransform(List<bool> mask, int width, int height) {
    const large = 1 << 20;
    final dist = List<int>.filled(mask.length, large);

    for (var i = 0; i < mask.length; i++) {
      if (!mask[i]) dist[i] = 0;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final idx = y * width + x;
        if (!mask[idx]) continue;
        var best = dist[idx];
        if (x > 0) best = math.min(best, dist[idx - 1] + 1);
        if (y > 0) best = math.min(best, dist[idx - width] + 1);
        if (x > 0 && y > 0) {
          best = math.min(best, dist[idx - width - 1] + 2);
        }
        if (x < width - 1 && y > 0) {
          best = math.min(best, dist[idx - width + 1] + 2);
        }
        dist[idx] = best;
      }
    }

    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final idx = y * width + x;
        if (!mask[idx]) continue;
        var best = dist[idx];
        if (x < width - 1) best = math.min(best, dist[idx + 1] + 1);
        if (y < height - 1) best = math.min(best, dist[idx + width] + 1);
        if (x < width - 1 && y < height - 1) {
          best = math.min(best, dist[idx + width + 1] + 2);
        }
        if (x > 0 && y < height - 1) {
          best = math.min(best, dist[idx + width - 1] + 2);
        }
        dist[idx] = best;
      }
    }

    return dist;
  }

  static List<math.Point<int>> _selectStars(
    List<math.Point<int>> candidates,
    int width,
    int height,
    double minDistSq,
    int maxStars,
  ) {
    if (candidates.isEmpty) return const [];

    final cellSize = math.max(1.0, math.sqrt(minDistSq));
    final gridWidth = (width / cellSize).ceil();
    final grid = <int, List<math.Point<int>>>{};
    final selected = <math.Point<int>>[];

    for (final point in candidates) {
      final gx = (point.x / cellSize).floor();
      final gy = (point.y / cellSize).floor();
      var ok = true;

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = gx + dx;
          final ny = gy + dy;
          if (nx < 0 || ny < 0) continue;
          final key = ny * gridWidth + nx;
          final neighbors = grid[key];
          if (neighbors == null) continue;
          for (final other in neighbors) {
            final dxp = (point.x - other.x).toDouble();
            final dyp = (point.y - other.y).toDouble();
            final distSq = dxp * dxp + dyp * dyp;
            if (distSq < minDistSq) {
              ok = false;
              break;
            }
          }
          if (!ok) break;
        }
        if (!ok) break;
      }

      if (!ok) continue;

      selected.add(point);
      final key = gy * gridWidth + gx;
      grid.putIfAbsent(key, () => []).add(point);

      if (selected.length >= maxStars) break;
    }

    return selected;
  }

  static img.Image _renderStars(
    img.Image source,
    List<math.Point<int>> stars,
    StarDecorationParams params,
    math.Random rng,
  ) {
    final base = img.Image.from(source);
    if (stars.isEmpty) return base;

    final coreLayer = img.Image(width: base.width, height: base.height);
    img.Image? glowLayer;

    final brightness = params.starBrightness.clamp(0.0, 1.0);
    final glowStrength = params.starGlow.clamp(0.0, 1.0);
    final coreColor = _toColor(_applyBrightness(params.starColor, brightness));

    img.Color? glowColor;
    var glowRadiusOffset = 0.0;
    if (glowStrength > 0.01) {
      glowLayer = img.Image(width: base.width, height: base.height);
      final glowAlpha = (0.25 + 0.55 * glowStrength).clamp(0.2, 0.9);
      glowColor = _toColor(
        _withAlpha(params.starColor, (255 * glowAlpha * brightness).round()),
      );
      glowRadiusOffset = 1.0 + 4.0 * glowStrength;
    }

    final minSize = math
        .min(params.starMinSize, params.starMaxSize)
        .clamp(0.5, 6.0)
        .toDouble();
    final maxSize = math
        .max(params.starMinSize, params.starMaxSize)
        .clamp(0.5, 8.0)
        .toDouble();

    for (final star in stars) {
      final radius = (minSize + (maxSize - minSize) * rng.nextDouble())
          .clamp(0.5, 8.0)
          .toDouble();
      final coreRadius = radius.round().clamp(1, 8).toInt();
      img.fillCircle(
        coreLayer,
        x: star.x,
        y: star.y,
        radius: coreRadius,
        color: coreColor,
      );

      if (glowLayer != null && glowColor != null) {
        final glowRadius = (radius + glowRadiusOffset).round().clamp(1, 14);
        img.fillCircle(
          glowLayer,
          x: star.x,
          y: star.y,
          radius: glowRadius.toInt(),
          color: glowColor,
        );
      }
    }

    if (glowLayer != null) {
      final blurRadius = (1 + glowStrength * 4).round();
      final blurred = img.gaussianBlur(glowLayer, radius: blurRadius);
      img.compositeImage(
        base,
        blurred,
        dstX: 0,
        dstY: 0,
        blend: img.BlendMode.addition,
      );
    }

    img.compositeImage(
      base,
      coreLayer,
      dstX: 0,
      dstY: 0,
      blend: img.BlendMode.alpha,
    );

    return base;
  }

  static int _deriveSeed(Uint8List bytes, StarDecorationParams params) {
    final stride = math.max(1, (bytes.length / 2048).round());
    var hash = 0x811C9DC5;
    for (var i = 0; i < bytes.length; i += stride) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    var paramHash = 17;
    paramHash = 31 * paramHash + (params.lineWidthThreshold * 100).round();
    paramHash = 31 * paramHash + (params.starDensity * 100).round();
    paramHash = 31 * paramHash + (params.starMinSize * 100).round();
    paramHash = 31 * paramHash + (params.starMaxSize * 100).round();
    paramHash = 31 * paramHash + (params.starBrightness * 100).round();
    paramHash = 31 * paramHash + (params.starGlow * 100).round();
    paramHash = 31 * paramHash + (params.starColor & 0xFFFFFFFF);

    return (hash ^ paramHash) & 0x7fffffff;
  }

  static int _applyBrightness(int argb, double brightness) {
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final scale = brightness.clamp(0.0, 1.0);

    final na = (a * scale).round().clamp(0, 255);
    final nr = (r * scale).round().clamp(0, 255);
    final ng = (g * scale).round().clamp(0, 255);
    final nb = (b * scale).round().clamp(0, 255);

    return (na << 24) | (nr << 16) | (ng << 8) | nb;
  }

  static int _withAlpha(int argb, int alpha) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final a = alpha.clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static img.Color _toColor(int argb) {
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }
}

class StarDecorationTask {
  final Uint8List lineArtBytes;
  final int width;
  final int height;
  final StarDecorationParams params;

  const StarDecorationTask({
    required this.lineArtBytes,
    required this.width,
    required this.height,
    required this.params,
  });
}

class StarDecorationOutput {
  final Uint8List decoratedBytes;
  final int width;
  final int height;
  final int starCount;
  final bool maskInverted;
  final Duration processingTime;

  const StarDecorationOutput({
    required this.decoratedBytes,
    required this.width,
    required this.height,
    required this.starCount,
    required this.maskInverted,
    required this.processingTime,
  });
}

class _LuminanceStats {
  final double mean;
  final double stdDev;

  const _LuminanceStats(this.mean, this.stdDev);
}
