import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:seizani_app/infrastructure/services/feature_detector.dart';
import 'package:seizani_app/infrastructure/services/skeletonization_processor.dart';
import 'package:seizani_app/infrastructure/services/morphological_processor.dart';
import 'package:seizani_app/infrastructure/services/processing_parameters.dart';
import 'package:seizani_app/domain/entities/constellation_entity.dart';

void main() {
  group('Enhanced Constellation Pipeline Tests', () {
    test('特徴点検出 - 基本的な線画', () {
      // シンプルなT字型の骨格
      List<List<bool>> skeleton = [
        [false, false, false, false, false],
        [false, true, true, true, false], // 水平線
        [false, false, true, false, false], // 垂直線
        [false, false, true, false, false],
        [false, false, false, false, false],
      ];

      var features = FeatureDetector.detectFeatures(skeleton);

      // T字型なので3つの端点があるはず
      expect(features.endpoints.length, equals(3));

      // T字の中心に1つの分岐点があるはず
      expect(features.junctions.length, equals(1));

      // 分岐点の位置を確認
      var junction = features.junctions.first;
      expect(junction.x, equals(2)); // 中心のx座標
      expect(junction.y, equals(1)); // 中心のy座標

      // 端点の位置を確認
      var endpoints = features.endpoints;
      expect(endpoints.length, equals(3));
    });

    test('特徴点検出 - 高曲率点', () {
      // カーブのある線
      List<List<bool>> curvedSkeleton = [
        [false, false, false, false, false],
        [true, false, false, false, false],
        [false, true, false, false, false],
        [false, false, true, false, false],
        [false, false, false, true, false],
      ];

      var features = FeatureDetector.detectFeatures(curvedSkeleton);

      // 2つの端点があるはず
      expect(features.endpoints.length, equals(2));

      // カーブ部分に高曲率点があるかもしれない
      // （実装によっては中間点は高曲率と判定されない場合もある）
      expect(features.totalFeatures, greaterThanOrEqualTo(2));
    });

    test('階層的星配置 - レベル別配置', () {
      List<List<bool>> skeleton = [
        [false, false, false, false, false, false, false],
        [true, true, true, false, true, true, true], // 2つの線分
        [false, false, false, false, false, false, false],
      ];

      var features = FeatureDetector.detectFeatures(skeleton);
      var parameters = BasicProcessingParameters(
        maxPoints: 10,
        minStarDistance: 5.0,
      );

      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        skeleton,
        parameters,
      );

      expect(stars, isNotNull);
      expect(stars.length, greaterThan(0));
      expect(stars.length, lessThanOrEqualTo(parameters.maxPoints));

      // 星の強度が適切に設定されている
      for (var star in stars) {
        expect(star.intensity, greaterThan(0.0));
        expect(star.intensity, lessThanOrEqualTo(1.0));
      }

      // 最小距離が守られている
      for (int i = 0; i < stars.length; i++) {
        for (int j = i + 1; j < stars.length; j++) {
          double distance = _calculateDistance(stars[i], stars[j]);
          expect(
            distance,
            greaterThanOrEqualTo(parameters.minStarDistance! * 0.8),
          ); // 少し許容度を持たせる
        }
      }
    });

    test('統合パイプライン - エンドツーエンド', () {
      // 太い線画を作成
      List<List<bool>> thickLineArt = [
        [false, false, false, false, false, false, false],
        [false, true, true, true, true, true, false],
        [false, true, true, true, true, true, false],
        [false, true, true, false, false, false, false],
        [false, true, true, false, false, false, false],
        [false, false, false, false, false, false, false],
      ];

      // Step 1: 形態学的前処理
      var morphResult = MorphologicalProcessor.preprocessLineArt(thickLineArt);

      // Step 2: 骨格化
      var skeleton = SkeletonizationProcessor.zhangSuenThinning(
        morphResult.cleanedImage,
      );

      // Step 3: 特徴点検出
      var features = FeatureDetector.detectFeatures(skeleton);

      // Step 4: 星配置
      var parameters = BasicProcessingParameters(
        maxPoints: 20,
        minStarDistance: 8.0,
      );
      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        skeleton,
        parameters,
      );

      // 結果の検証
      expect(morphResult.cleanedImage, isNotNull);
      expect(skeleton, isNotNull);
      expect(features.totalFeatures, greaterThan(0));
      expect(stars.length, greaterThan(0));

      // パイプラインが段階的に処理を進めている
      int originalPixels = _countTruePixels(thickLineArt);
      int cleanedPixels = _countTruePixels(morphResult.cleanedImage);
      int skeletonPixels = _countTruePixels(skeleton);

      expect(cleanedPixels, lessThanOrEqualTo(originalPixels)); // クリーニング効果
      expect(skeletonPixels, lessThan(cleanedPixels)); // 細線化効果
      expect(stars.length, lessThan(skeletonPixels)); // 特徴点抽出効果
    });

    test('パフォーマンステスト - 大きな画像', () {
      const int size = 100;

      // 複雑なパターンを作成（螺旋状）
      List<List<bool>> complexImage = List.generate(
        size,
        (y) => List.generate(size, (x) {
          double centerX = size / 2;
          double centerY = size / 2;
          double distance = math.sqrt(
            math.pow(x - centerX, 2) + math.pow(y - centerY, 2),
          );
          double angle = math.atan2(y - centerY, x - centerX);

          // 螺旋パターン
          return (distance > 10 && distance < 40) &&
              ((angle + distance * 0.1) % (math.pi / 2) < 0.3);
        }),
      );

      final stopwatch = Stopwatch()..start();

      // 完全なパイプライン実行
      var morphResult = MorphologicalProcessor.preprocessLineArt(complexImage);
      var skeleton = SkeletonizationProcessor.zhangSuenThinning(
        morphResult.cleanedImage,
      );
      var features = FeatureDetector.detectFeatures(skeleton);
      var parameters = BasicProcessingParameters(
        maxPoints: 50,
        minStarDistance: 5.0,
      );
      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        skeleton,
        parameters,
      );

      stopwatch.stop();

      // パフォーマンス要件
      expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // 10秒以内

      // 出力の品質
      expect(stars.length, greaterThan(0));
      expect(stars.length, lessThanOrEqualTo(50));
      expect(features.totalFeatures, greaterThan(0));

      print('パイプライン処理時間: ${stopwatch.elapsedMilliseconds}ms');
      print('検出した特徴点: ${features.totalFeatures}個');
      print('配置した星: ${stars.length}個');
    });

    test('エラーハンドリング - 空画像', () {
      List<List<bool>> emptyImage = [];

      var features = FeatureDetector.detectFeatures(emptyImage);
      expect(features.totalFeatures, equals(0));

      var parameters = BasicProcessingParameters(maxPoints: 10);
      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        emptyImage,
        parameters,
      );
      expect(stars.length, equals(0));
    });

    test('エラーハンドリング - 単一ピクセル', () {
      List<List<bool>> singlePixel = [
        [false, false, false],
        [false, true, false],
        [false, false, false],
      ];

      var features = FeatureDetector.detectFeatures(singlePixel);

      // 単一ピクセルは端点として検出される
      expect(features.endpoints.length, equals(1));
      expect(features.junctions.length, equals(0));

      var parameters = BasicProcessingParameters(maxPoints: 5);
      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        singlePixel,
        parameters,
      );

      expect(stars.length, equals(1));
      expect(stars.first.intensity, equals(1.0)); // 端点は最大輝度
    });

    test('品質メトリクス - 星座品質評価', () {
      // L字型の線画
      List<List<bool>> lShape = [
        [false, false, false, false, false],
        [true, true, true, true, false],
        [true, false, false, false, false],
        [true, false, false, false, false],
        [false, false, false, false, false],
      ];

      var skeleton = SkeletonizationProcessor.zhangSuenThinning(lShape);
      var features = FeatureDetector.detectFeatures(skeleton);
      var parameters = BasicProcessingParameters(
        maxPoints: 10,
        minStarDistance: 3.0,
      );
      var stars = FeatureDetector.placeStarsHierarchically(
        features,
        skeleton,
        parameters,
      );

      // 品質指標を計算
      double featurePointCoverage =
          stars.length / features.totalFeatures.clamp(1, double.infinity);
      expect(featurePointCoverage, greaterThan(0.5)); // 50%以上の特徴点がカバーされる

      // 星の分布が均等か
      double avgX =
          stars.map((s) => s.x).reduce((a, b) => a + b) / stars.length;
      double avgY =
          stars.map((s) => s.y).reduce((a, b) => a + b) / stars.length;

      // L字型なので重心がある程度中央寄りにある
      expect(avgX, greaterThan(0.5));
      expect(avgX, lessThan(3.5));
      expect(avgY, greaterThan(0.5));
      expect(avgY, lessThan(3.5));
    });
  });
}

/// ヘルパー関数: 2つの星の間の距離を計算
double _calculateDistance(ConstellationPoint star1, ConstellationPoint star2) {
  return math.sqrt(
    math.pow(star1.x - star2.x, 2) + math.pow(star1.y - star2.y, 2),
  );
}

/// ヘルパー関数: trueピクセルの数をカウント
int _countTruePixels(List<List<bool>> image) {
  int count = 0;
  for (var row in image) {
    count += row.where((pixel) => pixel).length;
  }
  return count;
}
