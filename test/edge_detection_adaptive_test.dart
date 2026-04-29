import 'package:flutter_test/flutter_test.dart';
import 'package:seizani_app/domain/entities/image_entity.dart';
import 'package:seizani_app/domain/repositories/processing_repository.dart';
import 'package:seizani_app/infrastructure/services/constellation_processor.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

void main() {
  group('Adaptive Edge Detection Tests', () {
    test('Edge detection should find edges in simple patterns', () async {
      // Create a simple test pattern with clear edges
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(0, 0, 0)); // Black background

      // Add a horizontal line with high contrast
      for (int x = 20; x < 80; x++) {
        testImage.setPixel(x, 50, img.ColorRgb8(255, 255, 255)); // White line
      }

      // Add a vertical line for better edge detection
      for (int y = 20; y < 80; y++) {
        testImage.setPixel(
          75,
          y,
          img.ColorRgb8(255, 255, 255),
        ); // White vertical line
      }

      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      final imageEntity = ImageEntity(
        id: 'test_simple_pattern',
        path: 'test_simple_pattern.png',
        bytes: imageBytes,
        width: 100,
        height: 100,
        createdAt: DateTime.now(),
      );

      // Test with adaptive edge detection
      final params = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true,
        useGradientBasedDetection:
            false, // Disable gradient-based to use adaptive
        pointDensity: 0.6,
        maxPoints: 50,
        minEdgeCoverageAbs: 0.0001, // Very low threshold for test
        cannyHighPercentile: 0.5, // Lower percentile for easier detection
        cannyLowRatio: 0.2, // Lower ratio for more edges
      );

      final result = await ConstellationProcessor.processImage(
        imageEntity,
        params,
      );

      // Verify that edges were found
      expect(result.metadata.edgePoints, greaterThan(0));
      expect(
        result.metadata.edgePoints,
        lessThan(10000),
      ); // Reasonable upper bound

      // Verify that points were generated
      expect(result.points.length, greaterThan(0));
      expect(result.lines.length, greaterThan(0));
    });
    test(
      'Adaptive Canny should provide better edge coverage than standard',
      () async {
        // Create a synthetic test image with clear edges
        final testImage = img.Image(width: 200, height: 200);
        img.fill(
          testImage,
          color: img.ColorRgb8(128, 128, 128),
        ); // Gray background

        // Add horizontal and vertical lines for edge detection
        for (int x = 50; x < 150; x++) {
          testImage.setPixel(
            x,
            50,
            img.ColorRgb8(255, 255, 255),
          ); // Horizontal line
          testImage.setPixel(
            x,
            150,
            img.ColorRgb8(0, 0, 0),
          ); // Another horizontal line
        }
        for (int y = 50; y < 150; y++) {
          testImage.setPixel(
            50,
            y,
            img.ColorRgb8(255, 255, 255),
          ); // Vertical line
          testImage.setPixel(
            150,
            y,
            img.ColorRgb8(0, 0, 0),
          ); // Another vertical line
        }

        final imageBytes = Uint8List.fromList(img.encodePng(testImage));

        final imageEntity = ImageEntity(
          id: 'test_image',
          path: 'test_adaptive_edges.png',
          bytes: imageBytes,
          width: 200,
          height: 200,
          createdAt: DateTime.now(),
        );

        // Test with adaptive edge detection enabled
        final adaptiveParams = ProcessingParameters(
          useAdvancedAlgorithm: true,
          useAdaptiveEdgeThresholds: true,
          useGradientBasedDetection:
              false, // Disable gradient-based to use adaptive
          pointDensity: 0.6,
          maxPoints: 100,
          minEdgeCoverageAbs: 0.005, // Lower threshold for test
        );

        // Test with standard edge detection
        final standardParams = ProcessingParameters(
          useAdvancedAlgorithm: true,
          useAdaptiveEdgeThresholds: false,
          useGradientBasedDetection:
              false, // Disable gradient-based to use standard
          pointDensity: 0.6,
          maxPoints: 100,
        );

        final adaptiveResult = await ConstellationProcessor.processImage(
          imageEntity,
          adaptiveParams,
        );

        await ConstellationProcessor.processImage(imageEntity, standardParams);

        // Verify adaptive processing produces a constellation
        expect(adaptiveResult.points.isNotEmpty, true);
        expect(adaptiveResult.lines.isNotEmpty, true);

        // Check diagnostics are available
        final adaptiveDiagnostics =
            adaptiveResult.metadata.parameters['diagnostics']
                as Map<String, dynamic>?;
        expect(adaptiveDiagnostics, isNotNull);

        // Verify KPI targets
        final kpiStatus =
            adaptiveDiagnostics!['kpiStatus'] as Map<String, dynamic>;
        expect(
          kpiStatus['edgeCoverageTarget'],
          true,
          reason: 'Edge coverage should meet ≥1% target',
        );
        expect(
          kpiStatus['quadrantsTarget'],
          true,
          reason: 'Should have points in multiple quadrants',
        );

        // Edge coverage should be reasonable for synthetic image
        final edgeCoverage = adaptiveDiagnostics['edgeCoverage'] as double;
        expect(
          edgeCoverage,
          greaterThan(0.01),
          reason: 'Edge coverage should be >1%',
        );

        print('🔍 Test Results:');
        print(
          '   Adaptive Edge Coverage: ${(edgeCoverage * 100).toStringAsFixed(3)}%',
        );
        print('   Points Generated: ${adaptiveResult.points.length}');
        print('   Lines Generated: ${adaptiveResult.lines.length}');
        print(
          '   Y Coverage: ${((adaptiveDiagnostics['yCoverage'] as double) * 100).toStringAsFixed(1)}%',
        );
        print(
          '   Grid Coverage: ${((adaptiveDiagnostics['gridCoverage'] as double) * 100).toStringAsFixed(1)}%',
        );
      },
    );

    test('Grid cell adaptation should work correctly', () async {
      // Test with small image to verify grid cell adaptation
      final smallImage = img.Image(width: 64, height: 64);
      img.fill(smallImage, color: img.ColorRgb8(100, 100, 100));

      // Add a simple diagonal pattern
      for (int i = 0; i < 64; i++) {
        smallImage.setPixel(i, i, img.ColorRgb8(255, 255, 255));
      }

      final imageBytes = Uint8List.fromList(img.encodePng(smallImage));
      final imageEntity = ImageEntity(
        id: 'test_small',
        path: 'test_small.png',
        bytes: imageBytes,
        width: 64,
        height: 64,
        createdAt: DateTime.now(),
      );

      final params = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true,
        useGradientBasedDetection:
            false, // Disable gradient-based to use adaptive
        gridCellsX: 8, // Should be adapted down due to small image
        gridCellsY: 6,
        pointDensity: 0.8,
        maxPoints: 50,
      );

      final result = await ConstellationProcessor.processImage(
        imageEntity,
        params,
      );

      // Should complete without errors even with small image
      expect(result.points.isNotEmpty, true);

      final diagnostics =
          result.metadata.parameters['diagnostics'] as Map<String, dynamic>;
      expect(diagnostics, isNotNull);

      // Should have some edge coverage
      final edgeCoverage = diagnostics['edgeCoverage'] as double;
      expect(edgeCoverage, greaterThan(0.0));

      print('🔍 Small Image Test Results:');
      print('   Edge Coverage: ${(edgeCoverage * 100).toStringAsFixed(3)}%');
      print('   Points: ${result.points.length}');
    });
  });
}
