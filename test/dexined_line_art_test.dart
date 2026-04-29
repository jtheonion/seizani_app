import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:seizani_app/domain/entities/image_entity.dart';
import 'package:seizani_app/domain/entities/line_art_entity.dart';
import 'package:seizani_app/infrastructure/services/dexined_onnx_line_art_service.dart';
import 'package:seizani_app/presentation/providers/line_art_processing_provider.dart';
import 'package:seizani_app/presentation/screens/line_art_conversion_screen.dart';

void main() {
  group('DexiNed line art post-processing', () {
    test('turns strong edge responses into black lines on white', () {
      final logits = List<num>.filled(16, -10);
      logits[5] = 10;
      logits[10] = 10;

      final lineArt = DexiNedOnnxLineArtService.postProcessLogitsForTesting(
        logits,
        outputWidth: 4,
        outputHeight: 4,
        targetWidth: 4,
        targetHeight: 4,
        percentile: 90,
        minThreshold: 0,
      );

      expect(img.getLuminance(lineArt.getPixel(1, 1)), lessThan(10));
      expect(img.getLuminance(lineArt.getPixel(2, 2)), lessThan(10));
      expect(img.getLuminance(lineArt.getPixel(0, 0)), greaterThan(240));
    });

    test('line thickness increases black line pixels', () {
      final logits = List<num>.filled(25, -10);
      logits[12] = 10;

      final thinLineArt = DexiNedOnnxLineArtService.postProcessLogitsForTesting(
        logits,
        outputWidth: 5,
        outputHeight: 5,
        targetWidth: 5,
        targetHeight: 5,
        percentile: 95,
        minThreshold: 1,
        lineThickness: 1,
      );
      final thickLineArt =
          DexiNedOnnxLineArtService.postProcessLogitsForTesting(
            logits,
            outputWidth: 5,
            outputHeight: 5,
            targetWidth: 5,
            targetHeight: 5,
            percentile: 95,
            minThreshold: 1,
            lineThickness: 3,
          );

      expect(
        _countBlackPixels(thickLineArt),
        greaterThan(_countBlackPixels(thinLineArt)),
      );
    });
  });

  group('DexiNed parameters', () {
    test('round-trips through LineArtParameters JSON', () {
      final encoded = LineArtParameters.dexinedDefaults
          .copyWith(
            dexinedPercentile: 88.5,
            dexinedMinThreshold: 41,
            lineThickness: 3,
          )
          .toJson();
      final decoded = LineArtParameters.fromJson(encoded);

      expect(decoded.algorithm, LineArtAlgorithm.dexined);
      expect(decoded.dexinedPercentile, 88.5);
      expect(decoded.dexinedMinThreshold, 41);
      expect(decoded.lineThickness, 3);
      expect(decoded.smoothLines, isFalse);
    });

    test('uses DexiNed defaults for legacy JSON without adjustable values', () {
      final decoded = LineArtParameters.fromJson({
        'algorithm': 'dexined',
        'edgeThreshold': 0.3,
      });

      expect(decoded.algorithm, LineArtAlgorithm.dexined);
      expect(
        decoded.dexinedPercentile,
        LineArtParameters.dexinedDefaultPercentile,
      );
      expect(
        decoded.dexinedMinThreshold,
        LineArtParameters.dexinedDefaultMinThreshold,
      );
    });

    test('round-trips through LineArtMetadata JSON', () {
      const metadata = LineArtMetadata(
        processingTime: Duration(milliseconds: 123),
        algorithm: LineArtAlgorithm.dexined,
        edgeStrength: 0.3,
        contrastLevel: 1.0,
        algorithmVersion: 'test',
        parameters: {'algorithm': 'dexined'},
      );

      final decoded = LineArtMetadata.fromJson(metadata.toJson());

      expect(decoded.algorithm, LineArtAlgorithm.dexined);
      expect(decoded.parameters['algorithm'], 'dexined');
    });

    test(
      'keeps legacy metadata readable when algorithm is missing or unknown',
      () {
        final parameters = LineArtParameters.fromJson({
          'algorithm': 'oldAlgorithm',
        });
        final metadata = LineArtMetadata.fromJson({
          'processingTime': 12,
          'algorithm': 'oldAlgorithm',
        });

        expect(parameters.algorithm, LineArtAlgorithm.sobel);
        expect(metadata.algorithm, LineArtAlgorithm.sobel);
      },
    );
  });

  group('line art presets', () {
    test('include DexiNed together with existing conversion cards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final presets = container.read(lineArtPresetsProvider);

      expect(
        presets.keys,
        containsAll(['写真', 'イラスト', '風景', '鉛筆スケッチ', 'DexiNed線画']),
      );
      expect(presets['DexiNed線画']?.algorithm, LineArtAlgorithm.dexined);
      expect(presets['写真']?.algorithm, LineArtAlgorithm.xdog);
    });

    testWidgets('conversion screen shows DexiNed selection card', (
      tester,
    ) async {
      final image = ImageEntity(
        id: 'test-image',
        path: '',
        width: 0,
        height: 0,
        createdAt: DateTime(2026, 4, 28),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: LineArtConversionScreen(imageEntity: image)),
        ),
      );

      expect(find.text('変換方法を選択:'), findsOneWidget);
      expect(find.text('写真'), findsOneWidget);
      expect(find.text('DexiNed線画'), findsWidgets);
    });

    testWidgets('DexiNed card opens adjustable settings sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final image = ImageEntity(
        id: 'test-image',
        path: '',
        width: 0,
        height: 0,
        createdAt: DateTime(2026, 4, 28),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: LineArtConversionScreen(imageEntity: image)),
        ),
      );

      await tester.tap(find.text('DexiNed線画').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DexiNed線画調整'), findsOneWidget);
      expect(find.text('線の量'), findsOneWidget);
      expect(find.text('ノイズ抑制'), findsOneWidget);
      expect(find.text('線の太さ'), findsOneWidget);
      expect(find.text('デフォルトに戻す'), findsOneWidget);
      expect(find.text('DexiNed線画を生成'), findsOneWidget);
    });
  });
}

int _countBlackPixels(img.Image image) {
  var count = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (img.getLuminance(image.getPixel(x, y)) < 128) {
        count++;
      }
    }
  }
  return count;
}
