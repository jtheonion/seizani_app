import 'dart:math';
import 'package:flutter/foundation.dart';
import 'feature_detector.dart';

/// 骨格画像から線分を追跡するクラス
class SkeletonTracer {
  /// 骨格画像から線分のリストを抽出する
  static List<SkeletonSegment> traceSkeleton(
    List<List<bool>> skeleton,
    SkeletonFeatures features,
  ) {
    debugPrint(
      '🦴 [TRACE] 骨格追跡開始 - 端点: ${features.endpoints.length}個, 分岐点: ${features.junctions.length}個',
    );

    List<SkeletonSegment> segments = [];
    Set<Point<int>> visited = {};

    // Phase 1: 端点から追跡開始
    for (Point<int> endpoint in features.endpoints) {
      if (!visited.contains(endpoint)) {
        SkeletonSegment? segment = _traceFromPoint(
          skeleton,
          endpoint,
          visited,
          features.junctions,
        );

        if (segment != null && segment.pixels.length > 3) {
          segments.add(segment);
          debugPrint(
            '🔗 [TRACE] 端点から線分を追跡: 長さ${segment.pixels.length}px, 曲率${segment.curvature.toStringAsFixed(3)}',
          );
        }
      }
    }

    // Phase 2: 分岐点から未訪問方向へ追跡
    for (Point<int> junction in features.junctions) {
      List<SkeletonSegment> branches = _traceFromJunction(
        skeleton,
        junction,
        visited,
        features.junctions,
      );
      segments.addAll(branches);
    }

    // Phase 3: 残った未訪問ピクセル（閉ループなど）を追跡
    List<SkeletonSegment> loops = _findClosedLoops(skeleton, visited);
    segments.addAll(loops);

    debugPrint('✅ [TRACE] 骨格追跡完了 - 線分数: ${segments.length}個');
    return segments;
  }

  /// 指定点から線分を追跡する
  static SkeletonSegment? _traceFromPoint(
    List<List<bool>> skeleton,
    Point<int> startPoint,
    Set<Point<int>> visited,
    List<Point<int>> junctions,
  ) {
    List<Point<int>> path = [];
    Point<int> current = startPoint;
    Point<int>? previous;

    while (true) {
      path.add(current);
      visited.add(current);

      // 8近傍から次の候補を探す
      List<Point<int>> neighbors = _get8Neighbors(current)
          .where(
            (p) =>
                p != previous && // 戻らない
                _isValidPixel(p, skeleton) &&
                skeleton[p.y][p.x] &&
                !visited.contains(p),
          )
          .toList();

      if (neighbors.isEmpty) {
        // 行き止まりまたは分岐点に到達
        break;
      } else if (neighbors.length == 1) {
        // 一本道を追跡継続
        previous = current;
        current = neighbors.first;

        // 分岐点に到達した場合は追跡終了
        if (junctions.contains(current) && path.length > 1) {
          path.add(current);
          visited.add(current);
          break;
        }
      } else {
        // 複数の選択肢がある = 分岐点
        if (junctions.contains(current)) {
          break;
        } else {
          // 予期しない分岐（ノイズの可能性）
          previous = current;
          current = neighbors.first; // 最初の選択肢を取る
        }
      }
    }

    if (path.length < 3) {
      return null;
    }

    return SkeletonSegment(
      pixels: path,
      isClosed: false,
      startPoint: path.first,
      endPoint: path.last,
      curvature: _calculateCurvature(path),
    );
  }

  /// 分岐点から各方向へ追跡
  static List<SkeletonSegment> _traceFromJunction(
    List<List<bool>> skeleton,
    Point<int> junction,
    Set<Point<int>> visited,
    List<Point<int>> junctions,
  ) {
    List<SkeletonSegment> branches = [];

    // 分岐点の8近傍で未訪問の骨格ピクセルを探す
    List<Point<int>> unvisitedNeighbors = _get8Neighbors(junction)
        .where(
          (p) =>
              _isValidPixel(p, skeleton) &&
              skeleton[p.y][p.x] &&
              !visited.contains(p),
        )
        .toList();

    // 各方向から追跡開始
    for (Point<int> neighbor in unvisitedNeighbors) {
      if (!visited.contains(neighbor)) {
        // 分岐点から1ピクセル進んだ地点から追跡開始
        SkeletonSegment? segment = _traceFromPoint(
          skeleton,
          neighbor,
          visited,
          junctions,
        );

        if (segment != null) {
          // 分岐点を開始点として追加
          List<Point<int>> enhancedPath = [junction] + segment.pixels;
          SkeletonSegment enhancedSegment = SkeletonSegment(
            pixels: enhancedPath,
            isClosed: false,
            startPoint: junction,
            endPoint: segment.endPoint,
            curvature: _calculateCurvature(enhancedPath),
          );
          branches.add(enhancedSegment);
          debugPrint('🌿 [TRACE] 分岐点から線分を追跡: 長さ${enhancedPath.length}px');
        }
      }
    }

    return branches;
  }

  /// 閉じた線（ループ）を検出
  static List<SkeletonSegment> _findClosedLoops(
    List<List<bool>> skeleton,
    Set<Point<int>> visited,
  ) {
    List<SkeletonSegment> loops = [];

    for (int y = 0; y < skeleton.length; y++) {
      for (int x = 0; x < skeleton[0].length; x++) {
        Point<int> startPoint = Point(x, y);

        if (skeleton[y][x] && !visited.contains(startPoint)) {
          List<Point<int>> path = [];
          Point<int> current = startPoint;
          Point<int>? previous;
          Set<Point<int>> loopVisited = {};

          while (true) {
            path.add(current);
            loopVisited.add(current);
            visited.add(current);

            List<Point<int>> neighbors = _get8Neighbors(current)
                .where(
                  (p) =>
                      p != previous &&
                      _isValidPixel(p, skeleton) &&
                      skeleton[p.y][p.x],
                )
                .toList();

            if (neighbors.isEmpty) {
              break;
            } else if (neighbors.contains(startPoint) && path.length > 3) {
              // ループ発見
              loops.add(
                SkeletonSegment(
                  pixels: path,
                  isClosed: true,
                  startPoint: startPoint,
                  endPoint: startPoint,
                  curvature: _calculateCurvature(path),
                ),
              );
              debugPrint('⭕ [TRACE] 閉ループを発見: 長さ${path.length}px');
              break;
            } else {
              previous = current;
              current = neighbors.first;

              if (loopVisited.contains(current)) {
                // 既に訪問済み（ループではない）
                break;
              }
            }
          }
        }
      }
    }

    return loops;
  }

  /// 線分の曲率を計算
  static double _calculateCurvature(List<Point<int>> pixels) {
    if (pixels.length < 3) return 0.0;

    double totalAngleChange = 0.0;
    int validPoints = 0;

    for (int i = 1; i < pixels.length - 1; i++) {
      Point<int> p1 = pixels[i - 1];
      Point<int> p2 = pixels[i];
      Point<int> p3 = pixels[i + 1];

      // ベクトルの角度を計算
      double angle1 = atan2(p2.y - p1.y, p2.x - p1.x);
      double angle2 = atan2(p3.y - p2.y, p3.x - p2.x);

      // 角度変化（-π to π の範囲に正規化）
      double angleChange = (angle2 - angle1).abs();
      if (angleChange > pi) angleChange = 2 * pi - angleChange;

      totalAngleChange += angleChange;
      validPoints++;
    }

    if (validPoints == 0) return 0.0;

    // 平均角度変化を曲率として使用（0.0〜1.0に正規化）
    return min(totalAngleChange / validPoints, 1.0);
  }

  /// 8近傍のピクセル座標を取得
  static List<Point<int>> _get8Neighbors(Point<int> p) {
    return [
      Point(p.x - 1, p.y - 1),
      Point(p.x, p.y - 1),
      Point(p.x + 1, p.y - 1),
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x - 1, p.y + 1),
      Point(p.x, p.y + 1),
      Point(p.x + 1, p.y + 1),
    ];
  }

  /// ピクセル座標が有効範囲内かチェック
  static bool _isValidPixel(Point<int> p, List<List<bool>> skeleton) {
    return p.x >= 0 &&
        p.x < skeleton[0].length &&
        p.y >= 0 &&
        p.y < skeleton.length;
  }
}

/// 骨格線分を表すクラス
class SkeletonSegment {
  final List<Point<int>> pixels; // 線を構成するピクセルのリスト
  final bool isClosed; // 閉じた線かどうか
  final Point<int> startPoint; // 開始点
  final Point<int> endPoint; // 終了点
  final double curvature; // 線の曲率（0.0〜1.0）

  const SkeletonSegment({
    required this.pixels,
    required this.isClosed,
    required this.startPoint,
    required this.endPoint,
    required this.curvature,
  });

  /// 線分の長さを計算
  double get length {
    if (pixels.length < 2) return 0.0;

    double totalLength = 0.0;
    for (int i = 1; i < pixels.length; i++) {
      Point<int> p1 = pixels[i - 1];
      Point<int> p2 = pixels[i];
      totalLength += sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
    }
    return totalLength;
  }

  /// 指定された間隔で線分上の点をサンプリング
  List<Point<int>> samplePoints(double interval) {
    if (pixels.isEmpty) return [];

    // 線分が短すぎる場合は中点のみ返す
    if (pixels.length * 1.0 < interval) {
      if (pixels.length > 2) {
        return [pixels[pixels.length ~/ 2]];
      }
      return [];
    }

    List<Point<int>> sampled = [];
    double accumulatedDistance = 0.0;

    for (int i = 1; i < pixels.length; i++) {
      Point<int> p1 = pixels[i - 1];
      Point<int> p2 = pixels[i];
      double distance = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
      accumulatedDistance += distance;

      if (accumulatedDistance >= interval) {
        sampled.add(p2);
        accumulatedDistance = 0.0;
      }
    }

    return sampled;
  }
}
