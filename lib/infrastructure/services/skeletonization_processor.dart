import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Zhang-Suen骨格化アルゴリズムの実装
///
/// 線画を1ピクセル幅の骨格に細線化する処理を提供
class SkeletonizationProcessor {
  /// Zhang-Suen細線化アルゴリズムを適用
  ///
  /// [image]: 二値化された画像データ (true=前景, false=背景)
  /// 戻り値: 細線化された骨格データ
  static List<List<bool>> zhangSuenThinning(List<List<bool>> image) {
    if (image.isEmpty || image[0].isEmpty) {
      throw ArgumentError('入力画像が空です');
    }

    final int height = image.length;
    final int width = image[0].length;

    // 作業用コピーを作成
    List<List<bool>> skeleton = List.generate(
      height,
      (i) => List.from(image[i]),
    );

    bool hasChanged = true;
    int iterationCount = 0;
    final int maxIterations = 100; // 無限ループ防止

    while (hasChanged && iterationCount < maxIterations) {
      hasChanged = false;
      iterationCount++;

      // Step 1: 第1サブ反復
      List<math.Point<int>> toRemove = [];

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (skeleton[y][x] && _shouldRemoveStep1(skeleton, x, y)) {
            toRemove.add(math.Point(x, y));
          }
        }
      }

      // 除去を適用
      for (var point in toRemove) {
        skeleton[point.y][point.x] = false;
        hasChanged = true;
      }

      // Step 2: 第2サブ反復
      toRemove.clear();

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (skeleton[y][x] && _shouldRemoveStep2(skeleton, x, y)) {
            toRemove.add(math.Point(x, y));
          }
        }
      }

      // 除去を適用
      for (var point in toRemove) {
        skeleton[point.y][point.x] = false;
        hasChanged = true;
      }
    }

    if (_countForeground(skeleton) == 0 && _countForeground(image) > 0) {
      skeleton = _buildMedialFallbackSkeleton(image);
    }

    debugPrint('🦴 骨格化完了: $iterationCount回の反復で収束');
    return skeleton;
  }

  /// Step 1の除去条件をチェック
  ///
  /// Zhang-Suenアルゴリズムの第1サブ反復で使用される条件
  static bool _shouldRemoveStep1(List<List<bool>> image, int x, int y) {
    // 8近傍を時計回りで取得 (上から開始)
    List<bool> neighbors = _getNeighbors(image, x, y);

    // 黒い近傍の数 B(P)
    int blackCount = neighbors.where((n) => n).length;

    // 白から黒への遷移数 A(P)
    int transitions = _countTransitions(neighbors);

    // Zhang-Suen Step 1の条件
    return blackCount >= 2 &&
        blackCount <= 6 &&
        transitions == 1 &&
        (!neighbors[0] || !neighbors[2] || !neighbors[4]) && // P2 * P4 * P6 = 0
        (!neighbors[2] || !neighbors[4] || !neighbors[6]); // P4 * P6 * P8 = 0
  }

  /// Step 2の除去条件をチェック
  ///
  /// Zhang-Suenアルゴリズムの第2サブ反復で使用される条件
  static bool _shouldRemoveStep2(List<List<bool>> image, int x, int y) {
    List<bool> neighbors = _getNeighbors(image, x, y);
    int blackCount = neighbors.where((n) => n).length;
    int transitions = _countTransitions(neighbors);

    // Zhang-Suen Step 2の条件
    return blackCount >= 2 &&
        blackCount <= 6 &&
        transitions == 1 &&
        (!neighbors[0] || !neighbors[2] || !neighbors[6]) && // P2 * P4 * P8 = 0
        (!neighbors[0] || !neighbors[4] || !neighbors[6]); // P2 * P6 * P8 = 0
  }

  /// 8連結近傍を時計回りで取得
  ///
  /// P9 P2 P3
  /// P8 P1 P4
  /// P7 P6 P5
  ///
  /// P1が中心ピクセル、P2から開始して時計回り
  static List<bool> _getNeighbors(List<List<bool>> image, int x, int y) {
    return [
      image[y - 1][x], // P2 (上)
      image[y - 1][x + 1], // P3 (右上)
      image[y][x + 1], // P4 (右)
      image[y + 1][x + 1], // P5 (右下)
      image[y + 1][x], // P6 (下)
      image[y + 1][x - 1], // P7 (左下)
      image[y][x - 1], // P8 (左)
      image[y - 1][x - 1], // P9 (左上)
    ];
  }

  /// 白から黒への遷移数をカウント
  ///
  /// 時計回りに近傍をチェックし、false→trueの遷移をカウント
  static int _countTransitions(List<bool> neighbors) {
    int count = 0;
    for (int i = 0; i < neighbors.length; i++) {
      int next = (i + 1) % neighbors.length;
      if (!neighbors[i] && neighbors[next]) {
        count++;
      }
    }
    return count;
  }

  /// 骨格化の品質を評価
  ///
  /// 細線化が適切に行われたかを定量的に評価
  static SkeletonizationMetrics evaluateSkeletonization(
    List<List<bool>> original,
    List<List<bool>> skeleton,
  ) {
    int originalPixels = 0;
    int skeletonPixels = 0;
    int thickLines = 0;

    final int height = skeleton.length;
    final int width = skeleton[0].length;

    // ピクセル数をカウント
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (original[y][x]) originalPixels++;
        if (skeleton[y][x]) skeletonPixels++;
      }
    }

    // 太い線（2ピクセル以上の幅）をチェック
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (skeleton[y][x]) {
          int neighborCount = _countNeighbors(skeleton, x, y);
          if (neighborCount >= 4) {
            thickLines++;
          }
        }
      }
    }

    double compressionRatio = originalPixels > 0
        ? (skeletonPixels / originalPixels)
        : 0.0;
    double thinningQuality = skeletonPixels > 0
        ? (1.0 - (thickLines / skeletonPixels))
        : 1.0;

    return SkeletonizationMetrics(
      originalPixelCount: originalPixels,
      skeletonPixelCount: skeletonPixels,
      compressionRatio: compressionRatio,
      thinningQuality: thinningQuality,
      thickLineCount: thickLines,
    );
  }

  /// 8連結近傍の数をカウント
  static int _countNeighbors(List<List<bool>> skeleton, int x, int y) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (skeleton[y + dy][x + dx]) count++;
      }
    }
    return count;
  }

  static int _countForeground(List<List<bool>> image) {
    var count = 0;
    for (final row in image) {
      count += row.where((pixel) => pixel).length;
    }
    return count;
  }

  static List<List<bool>> _buildMedialFallbackSkeleton(List<List<bool>> image) {
    final height = image.length;
    final width = image[0].length;
    final fallback = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        while (x < width && !image[y][x]) {
          x++;
        }
        if (x >= width) break;

        final start = x;
        while (x < width && image[y][x]) {
          x++;
        }
        final end = x - 1;
        fallback[y][(start + end) ~/ 2] = true;
      }
    }

    for (int x = 0; x < width; x++) {
      var y = 0;
      while (y < height) {
        while (y < height && !image[y][x]) {
          y++;
        }
        if (y >= height) break;

        final start = y;
        while (y < height && image[y][x]) {
          y++;
        }
        final end = y - 1;
        fallback[(start + end) ~/ 2][x] = true;
      }
    }

    return fallback;
  }

  /// 二値画像から骨格を生成（前処理付き）
  ///
  /// [imageData]: RGB画像データ
  /// [threshold]: 二値化の閾値 (0-255)
  /// 戻り値: 骨格化された二値画像
  static List<List<bool>> skeletonizeFromGrayscale(
    List<List<int>> grayscaleData, {
    int threshold = 128,
  }) {
    final int height = grayscaleData.length;
    final int width = grayscaleData[0].length;

    // 二値化
    List<List<bool>> binaryImage = List.generate(
      height,
      (y) => List.generate(width, (x) => grayscaleData[y][x] >= threshold),
    );

    // 骨格化を適用
    return zhangSuenThinning(binaryImage);
  }
}

/// 骨格化処理の品質メトリクス
class SkeletonizationMetrics {
  final int originalPixelCount;
  final int skeletonPixelCount;
  final double compressionRatio;
  final double thinningQuality;
  final int thickLineCount;

  const SkeletonizationMetrics({
    required this.originalPixelCount,
    required this.skeletonPixelCount,
    required this.compressionRatio,
    required this.thinningQuality,
    required this.thickLineCount,
  });

  @override
  String toString() {
    return 'SkeletonizationMetrics('
        'original: $originalPixelCount, '
        'skeleton: $skeletonPixelCount, '
        'compression: ${(compressionRatio * 100).toStringAsFixed(1)}%, '
        'quality: ${(thinningQuality * 100).toStringAsFixed(1)}%, '
        'thick_lines: $thickLineCount)';
  }
}
