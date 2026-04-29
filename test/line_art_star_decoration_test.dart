import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:seizani_app/domain/entities/constellation_entity.dart';
import 'package:seizani_app/domain/entities/image_entity.dart';
import 'package:seizani_app/domain/entities/line_art_decoration_entity.dart';
import 'package:seizani_app/domain/entities/line_art_entity.dart';
import 'package:seizani_app/domain/entities/processing_result.dart';
import 'package:seizani_app/domain/repositories/processing_repository.dart';
import 'package:seizani_app/domain/repositories/storage_repository.dart';
import 'package:seizani_app/infrastructure/services/line_art_star_decorator.dart';
import 'package:seizani_app/presentation/providers/dependencies.dart';
import 'package:seizani_app/presentation/screens/line_art_conversion_screen.dart';

void main() {
  group('StarDecorationParams', () {
    test('round-trips through JSON and falls back to defaults', () {
      const params = StarDecorationParams(
        lineWidthThreshold: 3.4,
        starDensity: 1.6,
        starMinSize: 1.5,
        starMaxSize: 4.2,
        starBrightness: 0.8,
        starGlow: 0.3,
        seed: 42,
      );

      final decoded = StarDecorationParams.fromJson(params.toJson());
      final legacy = StarDecorationParams.fromJson(const {});

      expect(decoded.lineWidthThreshold, 3.4);
      expect(decoded.starDensity, 1.6);
      expect(decoded.starMinSize, 1.5);
      expect(decoded.starMaxSize, 4.2);
      expect(decoded.starBrightness, 0.8);
      expect(decoded.starGlow, 0.3);
      expect(decoded.seed, 42);
      expect(legacy.lineWidthThreshold, 2.0);
      expect(legacy.starDensity, 1.0);
      expect(legacy.starGlow, 0.6);
    });
  });

  group('LineArtStarDecorator', () {
    test('adds stars for thick simple line art', () async {
      final lineArt = _createLineArt(lineWidth: 5);
      const params = StarDecorationParams(
        lineWidthThreshold: 2.0,
        starDensity: 1.4,
        seed: 42,
      );

      final result = await LineArtStarDecorator.decorate(lineArt, params);

      expect(result.starCount, greaterThan(0));
      expect(result.decoratedBytes, isNotEmpty);
    });

    test('is deterministic with a fixed seed', () async {
      final lineArt = _createLineArt(lineWidth: 4);
      const params = StarDecorationParams(
        lineWidthThreshold: 1.5,
        starDensity: 1.2,
        seed: 1234,
      );

      final first = await LineArtStarDecorator.decorate(lineArt, params);
      final second = await LineArtStarDecorator.decorate(lineArt, params);

      expect(listEquals(first.decoratedBytes, second.decoratedBytes), isTrue);
    });

    test('higher star density increases selected stars', () async {
      final lineArt = _createLineArt(lineWidth: 6, size: 96);
      const sparse = StarDecorationParams(
        lineWidthThreshold: 2.0,
        starDensity: 0.5,
        seed: 7,
      );
      const dense = StarDecorationParams(
        lineWidthThreshold: 2.0,
        starDensity: 1.8,
        seed: 7,
      );

      final sparseResult = await LineArtStarDecorator.decorate(lineArt, sparse);
      final denseResult = await LineArtStarDecorator.decorate(lineArt, dense);

      expect(denseResult.starCount, greaterThan(sparseResult.starCount));
    });
  });

  group('2-stage line art screen', () {
    testWidgets(
      'uses simple star decoration instead of line-art constellation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final lineArt = _createLineArt(lineWidth: 5);
        final repository = _FakeProcessingRepository(lineArt);
        final storage = _FakeStorageRepository();
        final image = ImageEntity(
          id: 'image',
          path: '',
          width: lineArt.width,
          height: lineArt.height,
          createdAt: DateTime(2026, 4, 28),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              processingRepositoryProvider.overrideWithValue(repository),
              storageRepositoryProvider.overrideWithValue(storage),
            ],
            child: MaterialApp(
              home: LineArtConversionScreen(imageEntity: image),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('写真'));
        await _pumpUntilFound(tester, find.text('線の太さ閾値'));

        expect(find.text('線の太さ閾値'), findsOneWidget);
        expect(find.text('星密度'), findsOneWidget);
        expect(find.text('星サイズ最小'), findsOneWidget);
        expect(find.text('星座に変換'), findsOneWidget);

        await tester.tap(find.text('星座に変換'));
        await _pumpUntilFound(tester, find.text('星座アート完成！'));

        expect(repository.decorateLineArtCalled, isTrue);
        expect(repository.processLineArtCalled, isFalse);
        expect(find.text('星座アート完成！'), findsOneWidget);
        expect(find.textContaining('星:'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected finder to match within timeout: $finder');
}

LineArtEntity _createLineArt({int lineWidth = 3, int size = 64}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));

  final center = image.height ~/ 2;
  for (var y = center - lineWidth; y <= center + lineWidth; y++) {
    for (var x = 8; x < image.width - 8; x++) {
      image.setPixelRgba(x, y, 0, 0, 0, 255);
    }
  }

  final bytes = Uint8List.fromList(img.encodePng(image));

  return LineArtEntity(
    id: 'line_art_test',
    originalImageId: 'original',
    lineArtImageBytes: bytes,
    width: image.width,
    height: image.height,
    createdAt: DateTime(2026, 4, 28),
    metadata: const LineArtMetadata(
      processingTime: Duration.zero,
      algorithm: LineArtAlgorithm.sobel,
      edgeStrength: 0.3,
      contrastLevel: 1.0,
      algorithmVersion: 'test',
      parameters: {},
    ),
  );
}

class _FakeProcessingRepository implements ProcessingRepository {
  _FakeProcessingRepository(this.lineArt);

  final LineArtEntity lineArt;
  bool decorateLineArtCalled = false;
  bool processLineArtCalled = false;

  @override
  Future<LineArtDecorationEntity> decorateLineArt(
    LineArtEntity lineArt, {
    StarDecorationParams? params,
  }) async {
    decorateLineArtCalled = true;
    final effectiveParams = params ?? const StarDecorationParams(seed: 1);

    return LineArtDecorationEntity(
      id: 'decoration',
      sourceLineArtId: lineArt.id,
      decoratedImageBytes: lineArt.lineArtImageBytes,
      width: lineArt.width,
      height: lineArt.height,
      createdAt: DateTime(2026, 4, 28),
      metadata: LineArtDecorationMetadata(
        processingTime: const Duration(milliseconds: 12),
        algorithmVersion: LineArtStarDecorator.algorithmVersion,
        starCount: 3,
        maskInverted: true,
        parameters: effectiveParams,
      ),
    );
  }

  @override
  Future<LineArtEntity> processImageToLineArt(
    ImageEntity image, {
    LineArtParameters? parameters,
  }) async {
    return lineArt;
  }

  @override
  Future<ConstellationEntity> processLineArt(
    LineArtEntity lineArt, {
    ProcessingParameters? parameters,
  }) async {
    processLineArtCalled = true;
    throw StateError('processLineArt should not be used for 2-stage star flow');
  }

  @override
  Stream<ProcessingResult> processImage(
    ImageEntity image, {
    ProcessingParameters? parameters,
  }) async* {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorageRepository implements StorageRepository {
  @override
  Future<void> saveLineArt(LineArtEntity lineArt) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
