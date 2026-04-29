import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 形態学的処理操作を提供するプロセッサ
///
/// 画像の前処理として、ノイズ除去、断線修復、連結成分分析を実行
class MorphologicalProcessor {
  /// 膨張(Dilation)演算
  ///
  /// 前景領域を拡大し、小さな穴や断線を修復
  /// [image]: 二値画像 (true=前景, false=背景)
  /// [kernelSize]: カーネルサイズ (奇数を推奨)
  static List<List<bool>> dilate(List<List<bool>> image, int kernelSize) {
    if (image.isEmpty || image[0].isEmpty) {
      throw ArgumentError('入力画像が空です');
    }

    final int height = image.length;
    final int width = image[0].length;
    final int radius = kernelSize ~/ 2;

    List<List<bool>> result = List.generate(
      height,
      (i) => List.filled(width, false),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (image[y][x]) {
          // カーネル内のすべてのピクセルを前景に設定
          for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
              int ny = y + dy;
              int nx = x + dx;
              if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
                result[ny][nx] = true;
              }
            }
          }
        }
      }
    }

    return result;
  }

  /// 収縮(Erosion)演算
  ///
  /// 前景領域を縮小し、ノイズやほこりを除去
  /// [image]: 二値画像
  /// [kernelSize]: カーネルサイズ (奇数を推奨)
  static List<List<bool>> erode(List<List<bool>> image, int kernelSize) {
    if (image.isEmpty || image[0].isEmpty) {
      throw ArgumentError('入力画像が空です');
    }

    final int height = image.length;
    final int width = image[0].length;
    final int radius = kernelSize ~/ 2;

    List<List<bool>> result = List.generate(
      height,
      (i) => List.filled(width, false),
    );

    for (int y = radius; y < height - radius; y++) {
      for (int x = radius; x < width - radius; x++) {
        bool allTrue = true;

        // カーネル内のすべてのピクセルが前景かチェック
        for (int dy = -radius; dy <= radius && allTrue; dy++) {
          for (int dx = -radius; dx <= radius && allTrue; dx++) {
            if (!image[y + dy][x + dx]) {
              allTrue = false;
            }
          }
        }

        result[y][x] = allTrue;
      }
    }

    return result;
  }

  /// 開放(Opening)演算
  ///
  /// 収縮→膨張の順で実行。ノイズ除去に効果的
  static List<List<bool>> opening(List<List<bool>> image, int kernelSize) {
    var eroded = erode(image, kernelSize);
    return dilate(eroded, kernelSize);
  }

  /// 閉鎖(Closing)演算
  ///
  /// 膨張→収縮の順で実行。断線修復に効果的
  static List<List<bool>> closing(List<List<bool>> image, int kernelSize) {
    var dilated = dilate(image, kernelSize);
    return erode(dilated, kernelSize);
  }

  /// 連結成分分析
  ///
  /// 画像内の連結した前景領域を特定し、ラベル付け
  static ConnectedComponentResult analyzeConnectedComponents(
    List<List<bool>> image,
  ) {
    if (image.isEmpty || image[0].isEmpty) {
      return ConnectedComponentResult(labels: [], components: []);
    }

    final int height = image.length;
    final int width = image[0].length;

    List<List<int>> labels = List.generate(
      height,
      (i) => List.filled(width, 0),
    );

    List<ConnectedComponent> components = [];
    int currentLabel = 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (image[y][x] && labels[y][x] == 0) {
          // 新しい連結成分を発見
          var component = _floodFill(image, labels, x, y, currentLabel);
          components.add(component);
          currentLabel++;
        }
      }
    }

    debugPrint('🔍 連結成分分析: ${components.length}個の成分を検出');
    return ConnectedComponentResult(labels: labels, components: components);
  }

  /// Flood fillアルゴリズムで連結成分をラベル付け
  static ConnectedComponent _floodFill(
    List<List<bool>> image,
    List<List<int>> labels,
    int startX,
    int startY,
    int label,
  ) {
    List<math.Point<int>> pixels = [];
    Queue<math.Point<int>> queue = Queue();

    queue.add(math.Point(startX, startY));
    labels[startY][startX] = label;

    while (queue.isNotEmpty) {
      var point = queue.removeFirst();
      pixels.add(point);

      // 8連結近傍をチェック
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;

          int nx = point.x + dx;
          int ny = point.y + dy;

          if (nx >= 0 &&
              nx < image[0].length &&
              ny >= 0 &&
              ny < image.length &&
              image[ny][nx] &&
              labels[ny][nx] == 0) {
            labels[ny][nx] = label;
            queue.add(math.Point(nx, ny));
          }
        }
      }
    }

    return ConnectedComponent(
      label: label,
      pixels: pixels,
      boundingBox: _calculateBoundingBox(pixels),
    );
  }

  /// ピクセル群の外接矩形を計算
  static math.Rectangle<int> _calculateBoundingBox(
    List<math.Point<int>> pixels,
  ) {
    if (pixels.isEmpty) {
      return math.Rectangle(0, 0, 0, 0);
    }

    int minX = pixels.first.x;
    int maxX = pixels.first.x;
    int minY = pixels.first.y;
    int maxY = pixels.first.y;

    for (var pixel in pixels) {
      minX = math.min(minX, pixel.x);
      maxX = math.max(maxX, pixel.x);
      minY = math.min(minY, pixel.y);
      maxY = math.max(maxY, pixel.y);
    }

    return math.Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }

  /// 連結成分をサイズでフィルタリング
  ///
  /// [minSize]: 最小ピクセル数
  /// [maxSize]: 最大ピクセル数 (null=無制限)
  static List<ConnectedComponent> filterComponentsBySize(
    List<ConnectedComponent> components,
    int minSize, {
    int? maxSize,
  }) {
    return components.where((component) {
      final size = component.area;
      return size >= minSize && (maxSize == null || size <= maxSize);
    }).toList();
  }

  /// アスペクト比によるフィルタリング
  ///
  /// [minRatio]: 最小アスペクト比 (幅/高さ)
  /// [maxRatio]: 最大アスペクト比
  static List<ConnectedComponent> filterComponentsByAspectRatio(
    List<ConnectedComponent> components,
    double minRatio,
    double maxRatio,
  ) {
    return components.where((component) {
      final ratio = component.aspectRatio;
      return ratio >= minRatio && ratio <= maxRatio;
    }).toList();
  }

  /// 複数段階の形態学的前処理
  ///
  /// ノイズ除去と断線修復を組み合わせた包括的な前処理
  static MorphologicalResult preprocessLineArt(
    List<List<bool>> binaryImage, {
    int noiseRemovalKernel = 3,
    int gapClosingKernel = 5,
    int minComponentSize = 10,
    double minAspectRatio = 0.1,
    double maxAspectRatio = 10.0,
  }) {
    // Step 1: ノイズ除去 (opening演算)
    var denoised = opening(binaryImage, noiseRemovalKernel);
    if (!_hasForeground(denoised) && _hasForeground(binaryImage)) {
      denoised = binaryImage;
    }

    // Step 2: 断線修復 (closing演算)
    var gapClosed = closing(denoised, gapClosingKernel);
    if (!_hasForeground(gapClosed) && _hasForeground(denoised)) {
      gapClosed = denoised;
    }

    // Step 3: 連結成分分析
    var ccResult = analyzeConnectedComponents(gapClosed);

    // Step 4: 小さな成分を除去
    var filteredComponents = filterComponentsBySize(
      ccResult.components,
      minComponentSize,
    );

    // Step 5: 形状によるフィルタリング
    filteredComponents = filterComponentsByAspectRatio(
      filteredComponents,
      minAspectRatio,
      maxAspectRatio,
    );
    if (filteredComponents.isEmpty && ccResult.components.isNotEmpty) {
      filteredComponents = [
        ccResult.components.reduce((a, b) => a.area >= b.area ? a : b),
      ];
    }

    // Step 6: フィルタされた成分から画像を再構築
    var cleanedImage = _reconstructImageFromComponents(
      gapClosed,
      filteredComponents,
    );

    return MorphologicalResult(
      cleanedImage: cleanedImage,
      components: filteredComponents,
      originalComponentCount: ccResult.components.length,
      filteredComponentCount: filteredComponents.length,
    );
  }

  static bool _hasForeground(List<List<bool>> image) {
    for (final row in image) {
      if (row.any((pixel) => pixel)) return true;
    }
    return false;
  }

  /// 連結成分から画像を再構築
  static List<List<bool>> _reconstructImageFromComponents(
    List<List<bool>> originalImage,
    List<ConnectedComponent> components,
  ) {
    final int height = originalImage.length;
    final int width = originalImage[0].length;

    // 空の画像を作成
    List<List<bool>> result = List.generate(
      height,
      (i) => List.filled(width, false),
    );

    // 選択された成分のピクセルを復元
    for (var component in components) {
      for (var pixel in component.pixels) {
        if (pixel.y >= 0 &&
            pixel.y < height &&
            pixel.x >= 0 &&
            pixel.x < width) {
          result[pixel.y][pixel.x] = true;
        }
      }
    }

    return result;
  }
}

/// 連結成分分析の結果
class ConnectedComponentResult {
  final List<List<int>> labels;
  final List<ConnectedComponent> components;

  ConnectedComponentResult({required this.labels, required this.components});
}

/// 単一の連結成分
class ConnectedComponent {
  final int label;
  final List<math.Point<int>> pixels;
  final math.Rectangle<int> boundingBox;

  ConnectedComponent({
    required this.label,
    required this.pixels,
    required this.boundingBox,
  });

  /// 面積（ピクセル数）
  int get area => pixels.length;

  /// アスペクト比（幅/高さ）
  double get aspectRatio =>
      boundingBox.height > 0 ? boundingBox.width / boundingBox.height : 0.0;

  /// 重心
  math.Point<double> get centroid {
    if (pixels.isEmpty) return math.Point(0.0, 0.0);

    double sumX = 0;
    double sumY = 0;

    for (var pixel in pixels) {
      sumX += pixel.x;
      sumY += pixel.y;
    }

    return math.Point(sumX / pixels.length, sumY / pixels.length);
  }

  /// 密度（面積/外接矩形面積）
  double get density {
    final boxArea = boundingBox.width * boundingBox.height;
    return boxArea > 0 ? pixels.length / boxArea : 0.0;
  }

  @override
  String toString() {
    return 'ConnectedComponent(label: $label, area: $area, '
        'bbox: ${boundingBox.width}x${boundingBox.height}, '
        'aspect: ${aspectRatio.toStringAsFixed(2)}, '
        'density: ${density.toStringAsFixed(2)})';
  }
}

/// 形態学的前処理の結果
class MorphologicalResult {
  final List<List<bool>> cleanedImage;
  final List<ConnectedComponent> components;
  final int originalComponentCount;
  final int filteredComponentCount;

  MorphologicalResult({
    required this.cleanedImage,
    required this.components,
    required this.originalComponentCount,
    required this.filteredComponentCount,
  });

  /// フィルタリング効果
  double get filteringEfficiency => originalComponentCount > 0
      ? 1.0 - (filteredComponentCount / originalComponentCount)
      : 0.0;

  @override
  String toString() {
    return 'MorphologicalResult('
        'components: $originalComponentCount → $filteredComponentCount, '
        'efficiency: ${(filteringEfficiency * 100).toStringAsFixed(1)}%)';
  }
}
