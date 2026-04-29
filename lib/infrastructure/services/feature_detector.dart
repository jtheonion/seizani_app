import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/entities/constellation_entity.dart';
import 'processing_parameters.dart';

/// 骨格画像から特徴点を検出するプロセッサ
///
/// 端点、分岐点、高曲率点を階層的に検出し、星配置の優先度を付与
class FeatureDetector {
  /// 骨格画像から全特徴点を検出
  ///
  /// [skeleton]: Zhang-Suen法で骨格化された二値画像
  /// 戻り値: 検出された特徴点群
  static SkeletonFeatures detectFeatures(List<List<bool>> skeleton) {
    if (skeleton.isEmpty || skeleton[0].isEmpty) {
      return SkeletonFeatures(
        endpoints: [],
        junctions: [],
        highCurvaturePoints: [],
      );
    }

    List<math.Point<int>> endpoints = [];
    List<math.Point<int>> junctions = [];
    List<math.Point<int>> highCurvaturePoints = [];
    final foregroundPoints = <math.Point<int>>[];

    final int height = skeleton.length;
    final int width = skeleton[0].length;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!skeleton[y][x]) continue;
        foregroundPoints.add(math.Point(x, y));

        final neighborCount = _countNeighbors(skeleton, x, y);
        final connectivityGroups = _countConnectivityGroups(skeleton, x, y);

        // 端点: 1つの接続塊、または孤立した単一ピクセル
        if (neighborCount == 0 || connectivityGroups == 1) {
          endpoints.add(math.Point(x, y));
        }
        // 分岐点: 近傍の接続塊が3つ以上
        else if (connectivityGroups >= 3) {
          junctions.add(math.Point(x, y));
        }
        // 通常点で曲率をチェック
        else if (connectivityGroups == 2) {
          double curvature = _calculateCurvature(skeleton, x, y);
          if (curvature > 0.5) {
            // 高曲率閾値
            highCurvaturePoints.add(math.Point(x, y));
          }
        }
      }
    }

    if (endpoints.isEmpty &&
        junctions.isEmpty &&
        highCurvaturePoints.isEmpty &&
        foregroundPoints.isNotEmpty) {
      highCurvaturePoints.addAll(
        _selectRepresentativeContourPoints(foregroundPoints),
      );
    }

    debugPrint(
      '🎯 特徴点検出: 端点${endpoints.length}個, '
      '分岐点${junctions.length}個, '
      '高曲率点${highCurvaturePoints.length}個',
    );

    return SkeletonFeatures(
      endpoints: endpoints,
      junctions: junctions,
      highCurvaturePoints: highCurvaturePoints,
    );
  }

  /// 8連結近傍のピクセル数をカウント
  static int _countNeighbors(List<List<bool>> skeleton, int x, int y) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (_isForeground(skeleton, x + dx, y + dy)) count++;
      }
    }
    return count;
  }

  /// 8近傍を時計回りに見たときの接続塊数を数える。
  ///
  /// 単純な近傍数だけだと、T字の端点が斜め接触を持つだけで通常点扱いに
  /// なってしまうため、骨格のトポロジーで端点・分岐点を判定する。
  static int _countConnectivityGroups(List<List<bool>> skeleton, int x, int y) {
    final neighbors = <bool>[
      _isForeground(skeleton, x, y - 1),
      _isForeground(skeleton, x + 1, y - 1),
      _isForeground(skeleton, x + 1, y),
      _isForeground(skeleton, x + 1, y + 1),
      _isForeground(skeleton, x, y + 1),
      _isForeground(skeleton, x - 1, y + 1),
      _isForeground(skeleton, x - 1, y),
      _isForeground(skeleton, x - 1, y - 1),
    ];

    var groups = 0;
    for (var i = 0; i < neighbors.length; i++) {
      final previous = neighbors[(i + neighbors.length - 1) % neighbors.length];
      if (neighbors[i] && !previous) {
        groups++;
      }
    }
    return groups;
  }

  static bool _isForeground(List<List<bool>> skeleton, int x, int y) {
    return y >= 0 &&
        y < skeleton.length &&
        x >= 0 &&
        x < skeleton[y].length &&
        skeleton[y][x];
  }

  static List<math.Point<int>> _selectRepresentativeContourPoints(
    List<math.Point<int>> points,
  ) {
    final representatives = <math.Point<int>>[
      points.reduce((a, b) => a.x <= b.x ? a : b),
      points.reduce((a, b) => a.x >= b.x ? a : b),
      points.reduce((a, b) => a.y <= b.y ? a : b),
      points.reduce((a, b) => a.y >= b.y ? a : b),
    ];

    final seen = <String>{};
    return representatives.where((point) {
      final key = '${point.x}_${point.y}';
      return seen.add(key);
    }).toList();
  }

  /// 局所的な曲率を計算
  ///
  /// 隣接する2点との角度から曲率を算出
  static double _calculateCurvature(List<List<bool>> skeleton, int x, int y) {
    // 連結する2つの隣接点を探す
    List<math.Point<int>> neighbors = [];

    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (_isForeground(skeleton, x + dx, y + dy)) {
          neighbors.add(math.Point(x + dx, y + dy));
        }
      }
    }

    if (neighbors.length != 2) return 0.0;

    // 2つのベクトル間の角度を計算
    var v1 = math.Point(neighbors[0].x - x, neighbors[0].y - y);
    var v2 = math.Point(neighbors[1].x - x, neighbors[1].y - y);

    double dotProduct = (v1.x * v2.x + v1.y * v2.y).toDouble();
    double mag1 = math.sqrt((v1.x * v1.x + v1.y * v1.y).toDouble());
    double mag2 = math.sqrt((v2.x * v2.x + v2.y * v2.y).toDouble());

    if (mag1 == 0 || mag2 == 0) return 0.0;

    double cosAngle = dotProduct / (mag1 * mag2);
    double angle = math.acos(cosAngle.clamp(-1.0, 1.0));

    // 曲率を0-1の範囲で正規化（0=直線、1=90度）
    return (math.pi - angle) / math.pi;
  }

  /// 階層的星配置システム
  ///
  /// 特徴点を重要度別に階層化し、星座点を生成
  static List<ConstellationPoint> placeStarsHierarchically(
    SkeletonFeatures features,
    List<List<bool>> skeleton,
    BasicProcessingParameters parameters,
  ) {
    List<ConstellationPoint> stars = [];
    int pointId = 0;

    // ポイント予算を階層ごとに配分
    int totalBudget = parameters.maxPoints;
    int level1Budget = (totalBudget * 0.3).round(); // 30% 重要
    int level2Budget = (totalBudget * 0.4).round(); // 40% 中程度
    int level3Budget = totalBudget - level1Budget - level2Budget; // 残り

    // Level 1: 重要な特徴点（端点・主要分岐点）
    stars.addAll(_placeCriticalFeatures(features, level1Budget, pointId));
    pointId += stars.length;

    // Level 2: 重要な特徴点（高曲率点・線分中点）
    stars.addAll(
      _placeImportantFeatures(features, skeleton, level2Budget, pointId),
    );
    pointId = stars.length;

    // Level 3: バランス調整点
    stars.addAll(_placeBalancingPoints(skeleton, stars, level3Budget, pointId));

    return _optimizeDistribution(stars, parameters);
  }

  /// レベル1: 重要な特徴点を配置
  static List<ConstellationPoint> _placeCriticalFeatures(
    SkeletonFeatures features,
    int budget,
    int startId,
  ) {
    List<ConstellationPoint> points = [];
    int id = startId;

    // すべての端点は重要
    for (var endpoint in features.endpoints) {
      if (points.length >= budget) break;

      points.add(
        ConstellationPoint(
          x: endpoint.x.toDouble(),
          y: endpoint.y.toDouble(),
          intensity: 1.0, // 最大輝度
          id: id++,
        ),
      );
    }

    // 主要分岐点（4つ以上の接続）
    for (var junction in features.junctions) {
      if (points.length >= budget) break;

      points.add(
        ConstellationPoint(
          x: junction.x.toDouble(),
          y: junction.y.toDouble(),
          intensity: 0.9,
          id: id++,
        ),
      );
    }

    return points;
  }

  /// レベル2: 重要な特徴点を配置
  static List<ConstellationPoint> _placeImportantFeatures(
    SkeletonFeatures features,
    List<List<bool>> skeleton,
    int budget,
    int startId,
  ) {
    List<ConstellationPoint> points = [];
    int id = startId;

    // 高曲率点
    for (var curvPoint in features.highCurvaturePoints) {
      if (points.length >= budget) break;

      points.add(
        ConstellationPoint(
          x: curvPoint.x.toDouble(),
          y: curvPoint.y.toDouble(),
          intensity: 0.7,
          id: id++,
        ),
      );
    }

    // 長い線分の中点を追加
    var longSegments = _findLongSegments(skeleton);
    for (var segment in longSegments) {
      if (points.length >= budget) break;

      var midpoint = segment.midpoint;
      points.add(
        ConstellationPoint(
          x: midpoint.x,
          y: midpoint.y,
          intensity: 0.6,
          id: id++,
        ),
      );
    }

    return points;
  }

  /// レベル3: バランス調整点を配置
  static List<ConstellationPoint> _placeBalancingPoints(
    List<List<bool>> skeleton,
    List<ConstellationPoint> existingPoints,
    int budget,
    int startId,
  ) {
    List<ConstellationPoint> points = [];
    int id = startId;

    // 空の骨格をチェック
    if (skeleton.isEmpty || skeleton[0].isEmpty) {
      return points;
    }

    final int height = skeleton.length;
    final int width = skeleton[0].length;

    // 密度マップを作成
    var densityMap = _createDensityMap(existingPoints, width, height);

    // 疎な領域を探し、そこに点を配置
    var sparseRegions = _findSparseRegions(densityMap, skeleton);

    for (var region in sparseRegions) {
      if (points.length >= budget) break;

      var candidatePoint = _findBestPointInRegion(
        region,
        skeleton,
        existingPoints,
      );
      if (candidatePoint != null) {
        points.add(
          ConstellationPoint(
            x: candidatePoint.x,
            y: candidatePoint.y,
            intensity: 0.5,
            id: id++,
          ),
        );
      }
    }

    return points;
  }

  /// 最終的な点分布を最適化
  static List<ConstellationPoint> _optimizeDistribution(
    List<ConstellationPoint> points,
    BasicProcessingParameters parameters,
  ) {
    double minDistance = parameters.minStarDistance ?? 10.0;

    List<ConstellationPoint> optimized = [];

    for (var point in points) {
      bool tooClose = false;

      for (var existing in optimized) {
        double distance = math.sqrt(
          math.pow(point.x - existing.x, 2) + math.pow(point.y - existing.y, 2),
        );

        if (distance < minDistance) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        optimized.add(point);
      }
    }

    return optimized;
  }

  /// 長い線分を検出
  static List<LineSegment> _findLongSegments(List<List<bool>> skeleton) {
    // 簡単な実装: 長い直線セグメントを検出
    List<LineSegment> segments = [];

    // 空の骨格をチェック
    if (skeleton.isEmpty || skeleton[0].isEmpty) {
      return segments;
    }

    final int height = skeleton.length;
    final int width = skeleton[0].length;

    // 水平および垂直方向の長い線分を検出
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width - 20; x++) {
        // 最小長20ピクセル
        if (skeleton[y][x]) {
          int length = 1;
          while (x + length < width && skeleton[y][x + length]) {
            length++;
          }
          if (length > 20) {
            segments.add(
              LineSegment(
                start: math.Point(x.toDouble(), y.toDouble()),
                end: math.Point((x + length - 1).toDouble(), y.toDouble()),
              ),
            );
          }
        }
      }
    }

    return segments;
  }

  /// 密度マップを作成
  static List<List<double>> _createDensityMap(
    List<ConstellationPoint> points,
    int width,
    int height,
  ) {
    List<List<double>> densityMap = List.generate(
      height,
      (_) => List.filled(width, 0.0),
    );

    const double influence = 30.0; // 影響半径

    for (var point in points) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          double distance = math.sqrt(
            math.pow(x - point.x, 2) + math.pow(y - point.y, 2),
          );
          if (distance < influence) {
            densityMap[y][x] += 1.0 - (distance / influence);
          }
        }
      }
    }

    return densityMap;
  }

  /// 疎な領域を検出
  static List<Region> _findSparseRegions(
    List<List<double>> densityMap,
    List<List<bool>> skeleton,
  ) {
    List<Region> regions = [];
    final int height = densityMap.length;
    final int width = densityMap[0].length;
    const int regionSize = 50;

    for (int y = 0; y < height - regionSize; y += regionSize ~/ 2) {
      for (int x = 0; x < width - regionSize; x += regionSize ~/ 2) {
        double avgDensity = 0.0;
        int skeletonPixels = 0;

        // 領域内の平均密度と骨格ピクセル数を計算
        for (int dy = 0; dy < regionSize; dy++) {
          for (int dx = 0; dx < regionSize; dx++) {
            if (y + dy < height && x + dx < width) {
              avgDensity += densityMap[y + dy][x + dx];
              if (skeleton[y + dy][x + dx]) skeletonPixels++;
            }
          }
        }

        avgDensity /= (regionSize * regionSize);

        // 低密度で骨格ピクセルがある領域を疎領域とする
        if (avgDensity < 0.3 && skeletonPixels > 5) {
          regions.add(
            Region(
              x: x,
              y: y,
              width: regionSize,
              height: regionSize,
              density: avgDensity,
            ),
          );
        }
      }
    }

    return regions;
  }

  /// 疎領域内の最適な点を見つける
  static math.Point<double>? _findBestPointInRegion(
    Region region,
    List<List<bool>> skeleton,
    List<ConstellationPoint> existingPoints,
  ) {
    math.Point<double>? bestPoint;
    double bestScore = -1.0;

    for (int y = region.y; y < region.y + region.height; y++) {
      for (int x = region.x; x < region.x + region.width; x++) {
        if (y >= 0 &&
            y < skeleton.length &&
            x >= 0 &&
            x < skeleton[0].length &&
            skeleton[y][x]) {
          // 既存点との距離をスコア化
          double minDistance = double.infinity;
          for (var existing in existingPoints) {
            double distance = math.sqrt(
              math.pow(x - existing.x, 2) + math.pow(y - existing.y, 2),
            );
            minDistance = math.min(minDistance, distance);
          }

          if (minDistance > bestScore) {
            bestScore = minDistance;
            bestPoint = math.Point(x.toDouble(), y.toDouble());
          }
        }
      }
    }

    return bestPoint;
  }
}

/// 骨格特徴点群のコンテナ
class SkeletonFeatures {
  final List<math.Point<int>> endpoints;
  final List<math.Point<int>> junctions;
  final List<math.Point<int>> highCurvaturePoints;

  SkeletonFeatures({
    required this.endpoints,
    required this.junctions,
    required this.highCurvaturePoints,
  });

  int get totalFeatures =>
      endpoints.length + junctions.length + highCurvaturePoints.length;

  @override
  String toString() {
    return 'SkeletonFeatures(endpoints: ${endpoints.length}, '
        'junctions: ${junctions.length}, '
        'curvature: ${highCurvaturePoints.length})';
  }
}

/// 線分クラス
class LineSegment {
  final math.Point<double> start;
  final math.Point<double> end;

  LineSegment({required this.start, required this.end});

  math.Point<double> get midpoint =>
      math.Point((start.x + end.x) / 2, (start.y + end.y) / 2);

  double get length =>
      math.sqrt(math.pow(end.x - start.x, 2) + math.pow(end.y - start.y, 2));
}

/// 領域クラス
class Region {
  final int x;
  final int y;
  final int width;
  final int height;
  final double density;

  Region({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.density,
  });
}

// ProcessingParametersクラスは constellation_processor.dart からインポート
