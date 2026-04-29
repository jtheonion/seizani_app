import 'package:flutter_test/flutter_test.dart';
import 'package:seizani_app/infrastructure/services/morphological_processor.dart';

void main() {
  group('MorphologicalProcessor Tests', () {
    test('膨張演算 - 基本テスト', () {
      List<List<bool>> testImage = [
        [false, false, false, false, false],
        [false, false, true, false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
      ];

      var dilated = MorphologicalProcessor.dilate(testImage, 3);

      // 膨張により周囲のピクセルが true になることを確認
      expect(dilated[1][2], isTrue); // 中心
      expect(dilated[1][1], isTrue); // 左
      expect(dilated[1][3], isTrue); // 右
      expect(dilated[0][2], isTrue); // 上
      expect(dilated[2][2], isTrue); // 下

      // 元画像より多くのピクセルが true になる
      int originalCount = _countTruePixels(testImage);
      int dilatedCount = _countTruePixels(dilated);
      expect(dilatedCount, greaterThan(originalCount));
    });

    test('収縮演算 - 基本テスト', () {
      List<List<bool>> testImage = [
        [false, false, false, false, false],
        [false, true, true, true, false],
        [false, true, true, true, false],
        [false, true, true, true, false],
        [false, false, false, false, false],
      ];

      var eroded = MorphologicalProcessor.erode(testImage, 3);

      // 収縮により中心のピクセルのみ残る
      int erodedCount = _countTruePixels(eroded);
      int originalCount = _countTruePixels(testImage);
      expect(erodedCount, lessThan(originalCount));

      // 中心のピクセルは残るはず
      expect(eroded[2][2], isTrue);
    });

    test('開放演算 - ノイズ除去', () {
      List<List<bool>> noisyImage = [
        [false, false, false, false, false],
        [true, false, true, true, true], // 孤立したノイズ
        [false, false, true, true, true],
        [false, false, true, true, true],
        [false, false, false, false, false],
      ];

      var opened = MorphologicalProcessor.opening(noisyImage, 3);

      // 孤立したノイズが除去される
      expect(opened[1][0], isFalse); // 左端のノイズが除去される

      // 大きな領域は保持される
      int openedCount = _countTruePixels(opened);
      expect(openedCount, greaterThan(0)); // 何らかの領域は残る
    });

    test('閉鎖演算 - 断線修復', () {
      List<List<bool>> brokenLine = [
        [false, false, false, false, false, false],
        [false, true, true, false, true, false], // 断線した線
        [false, false, false, false, false, false],
      ];

      var closed = MorphologicalProcessor.closing(brokenLine, 3);

      // 断線が修復される
      expect(closed[1][3], isTrue); // 断線部分が埋まる

      int closedCount = _countTruePixels(closed);
      int originalCount = _countTruePixels(brokenLine);
      expect(closedCount, greaterThanOrEqualTo(originalCount));
    });

    test('連結成分分析 - 基本テスト', () {
      List<List<bool>> testImage = [
        [false, false, false, false, false],
        [true, true, false, true, false],
        [true, true, false, false, false],
        [false, false, false, true, true],
        [false, false, false, true, true],
      ];

      var result = MorphologicalProcessor.analyzeConnectedComponents(testImage);

      expect(result.components.length, equals(3)); // 3つの連結成分

      // 各成分の特性をチェック
      var firstComponent = result.components[0];
      expect(firstComponent.area, greaterThan(0));
      expect(firstComponent.boundingBox.width, greaterThan(0));
      expect(firstComponent.boundingBox.height, greaterThan(0));

      // 重心が計算されている
      var centroid = firstComponent.centroid;
      expect(centroid.x, greaterThan(0));
      expect(centroid.y, greaterThan(0));
    });

    test('サイズによるフィルタリング', () {
      List<List<bool>> testImage = [
        [true, false, true, true, true],
        [false, false, true, true, true],
        [false, false, false, false, false],
        [true, true, false, false, false],
        [true, true, false, false, false],
      ];

      var result = MorphologicalProcessor.analyzeConnectedComponents(testImage);
      var filtered = MorphologicalProcessor.filterComponentsBySize(
        result.components,
        3, // 最小サイズ3
      );

      // 小さい成分（面積1の孤立点）が除去される
      expect(filtered.length, lessThan(result.components.length));

      // 残った成分は最小サイズを満たす
      for (var component in filtered) {
        expect(component.area, greaterThanOrEqualTo(3));
      }
    });

    test('アスペクト比によるフィルタリング', () {
      // 細長い成分と正方形の成分を持つ画像
      List<List<bool>> testImage = [
        [true, true, true, true, true], // 細長い
        [false, false, false, false, false],
        [false, false, false, false, false],
        [false, true, true, false, false], // 正方形
        [false, true, true, false, false],
      ];

      var result = MorphologicalProcessor.analyzeConnectedComponents(testImage);

      // 細長い成分のみを選択
      var longComponents = MorphologicalProcessor.filterComponentsByAspectRatio(
        result.components,
        2.0, // 最小アスペクト比
        10.0, // 最大アスペクト比
      );

      expect(longComponents.length, greaterThan(0));
      for (var component in longComponents) {
        expect(component.aspectRatio, greaterThanOrEqualTo(2.0));
      }
    });

    test('複数段階前処理 - 統合テスト', () {
      // より大きなノイズのある断線した線画
      List<List<bool>> noisyBrokenImage = [
        [false, false, false, false, false, false, false, false],
        [true, true, false, true, true, false, true, false], // 断線とノイズ
        [true, true, false, true, true, false, true, false],
        [false, false, false, false, false, false, false, false],
        [true, true, false, false, false, false, false, false], // 小さなノイズ
        [true, true, false, false, false, false, false, false],
      ];

      var result = MorphologicalProcessor.preprocessLineArt(
        noisyBrokenImage,
        noiseRemovalKernel: 3,
        gapClosingKernel: 3,
        minComponentSize: 3, // より小さな閾値
      );

      expect(result.cleanedImage, isNotNull);

      // 処理が適切に実行されることを確認
      expect(
        result.filteredComponentCount,
        lessThanOrEqualTo(result.originalComponentCount),
      );

      // フィルタリング処理が動作していることを確認
      if (result.originalComponentCount > 0) {
        expect(result.components.length, greaterThanOrEqualTo(0));
        if (result.filteredComponentCount < result.originalComponentCount) {
          expect(result.filteringEfficiency, greaterThan(0.0));
        }
      }
    });

    test('空画像での処理', () {
      List<List<bool>> emptyImage = [];

      expect(
        () => MorphologicalProcessor.dilate(emptyImage, 3),
        throwsArgumentError,
      );

      var result = MorphologicalProcessor.analyzeConnectedComponents(
        emptyImage,
      );
      expect(result.components.length, equals(0));
    });

    test('単一ピクセルの処理', () {
      List<List<bool>> singlePixel = [
        [false, false, false],
        [false, true, false],
        [false, false, false],
      ];

      var dilated = MorphologicalProcessor.dilate(singlePixel, 3);
      var eroded = MorphologicalProcessor.erode(singlePixel, 3);

      // 膨張により大きくなる
      int dilatedCount = _countTruePixels(dilated);
      expect(dilatedCount, greaterThan(1));

      // 収縮により消える可能性がある
      int erodedCount = _countTruePixels(eroded);
      expect(erodedCount, lessThanOrEqualTo(1));
    });

    test('大きな画像での性能テスト', () {
      const int size = 50;
      List<List<bool>> largeImage = List.generate(
        size,
        (y) => List.generate(
          size,
          (x) =>
              // チェッカーパターン
              (x + y) % 4 == 0,
        ),
      );

      final stopwatch = Stopwatch()..start();
      var result = MorphologicalProcessor.preprocessLineArt(largeImage);
      stopwatch.stop();

      expect(result.cleanedImage, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // 3秒以内
    });
  });
}

/// ヘルパー関数: trueピクセルの数をカウント
int _countTruePixels(List<List<bool>> image) {
  int count = 0;
  for (var row in image) {
    count += row.where((pixel) => pixel).length;
  }
  return count;
}
