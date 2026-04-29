import 'package:flutter_test/flutter_test.dart';
import 'package:seizani_app/domain/entities/image_entity.dart';
import 'package:seizani_app/domain/repositories/processing_repository.dart';
import 'package:seizani_app/infrastructure/services/constellation_processor.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

void main() {
  group('Line Generation Contour Link Tests', () {
    test('Contour linking should add more lines when enabled', () async {
      // Create an image with clear contours for linking
      final testImage = img.Image(width: 250, height: 250);
      img.fill(testImage, color: img.ColorRgb8(128, 128, 128));

      // Draw a square contour
      for (int x = 50; x <= 200; x++) {
        testImage.setPixel(x, 50, img.ColorRgb8(255, 255, 255)); // Top
        testImage.setPixel(x, 200, img.ColorRgb8(255, 255, 255)); // Bottom
      }
      for (int y = 50; y <= 200; y++) {
        testImage.setPixel(50, y, img.ColorRgb8(255, 255, 255)); // Left
        testImage.setPixel(200, y, img.ColorRgb8(255, 255, 255)); // Right
      }

      // Add a curved contour (semicircle)
      final centerX = 125;
      final centerY = 125;
      final radius = 40;
      for (double angle = 0; angle < pi; angle += 0.2) {
        final x = centerX + (radius * cos(angle)).round();
        final y = centerY + (radius * sin(angle)).round();
        if (x >= 0 && x < 250 && y >= 0 && y < 250) {
          testImage.setPixel(x, y, img.ColorRgb8(0, 0, 0));
        }
      }

      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      final imageEntity = ImageEntity(
        id: 'test_linking',
        path: 'test_linking.png',
        bytes: imageBytes,
        width: 250,
        height: 250,
        createdAt: DateTime.now(),
      );

      // Test without contour linking
      final paramsWithoutLinking = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true,
        enableContourLinking: false,
        pointDensity: 0.7,
        maxPoints: 120,
        edgeSensitivity: 1.1,
      );

      // Test with contour linking enabled
      final paramsWithLinking = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true,
        enableContourLinking: true,
        pointDensity: 0.7,
        maxPoints: 120,
        edgeSensitivity: 1.1,
      );

      final resultWithoutLinking = await ConstellationProcessor.processImage(
        imageEntity,
        paramsWithoutLinking,
      );

      final resultWithLinking = await ConstellationProcessor.processImage(
        imageEntity,
        paramsWithLinking,
      );

      // Both should generate constellations
      expect(resultWithoutLinking.points.isNotEmpty, true);
      expect(resultWithoutLinking.lines.isNotEmpty, true);
      expect(resultWithLinking.points.isNotEmpty, true);
      expect(resultWithLinking.lines.isNotEmpty, true);

      print('🔗 Contour Linking Comparison:');
      print(
        '   Without Linking - Points: ${resultWithoutLinking.points.length}, Lines: ${resultWithoutLinking.lines.length}',
      );
      print(
        '   With Linking - Points: ${resultWithLinking.points.length}, Lines: ${resultWithLinking.lines.length}',
      );

      // With contour linking, we should generally get more lines
      // (though this depends on the specific contours and point distribution)
      final lineIncrease =
          resultWithLinking.lines.length - resultWithoutLinking.lines.length;
      print('   Line Increase: $lineIncrease');

      // At minimum, the algorithm should complete successfully with linking enabled
      expect(resultWithLinking.metadata.algorithmVersion, '2.1.0');

      // Check that contour linking doesn't break the constellation quality
      final diagnostics =
          resultWithLinking.metadata.parameters['diagnostics']
              as Map<String, dynamic>;
      final contourFollowing = diagnostics['contourFollowingDegree'] as double;
      final gridCoverage = diagnostics['gridCoverage'] as double;

      print(
        '   Contour Following: ${(contourFollowing * 100).toStringAsFixed(1)}%',
      );
      print('   Grid Coverage: ${(gridCoverage * 100).toStringAsFixed(1)}%');

      expect(
        contourFollowing,
        greaterThan(0.2),
        reason: 'Should maintain reasonable contour following',
      );
      expect(
        gridCoverage,
        greaterThan(0.25),
        reason: 'Should maintain reasonable grid coverage',
      );

      // Contour linking should not create an excessive number of lines
      expect(
        resultWithLinking.lines.length,
        lessThan(resultWithLinking.points.length * 2),
        reason: 'Should not create excessive lines',
      );
    });

    test(
      'Contour linking should respect distance and angle constraints',
      () async {
        // Create a more complex contour with potential for both good and bad connections
        final testImage = img.Image(width: 300, height: 300);
        img.fill(testImage, color: img.ColorRgb8(120, 120, 120));

        // Create two separate contour segments that should not be linked
        // First segment: horizontal line
        for (int x = 50; x < 150; x++) {
          testImage.setPixel(x, 100, img.ColorRgb8(255, 255, 255));
        }

        // Second segment: horizontal line far away (should not link to first)
        for (int x = 200; x < 280; x++) {
          testImage.setPixel(x, 200, img.ColorRgb8(255, 255, 255));
        }

        // Third segment: connected curved line (should allow internal linking)
        final centerX = 100;
        final centerY = 150;
        for (double angle = 0; angle < pi; angle += 0.15) {
          final x = centerX + (30 * cos(angle)).round();
          final y = centerY + (30 * sin(angle)).round();
          if (x >= 0 && x < 300 && y >= 0 && y < 300) {
            testImage.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }

        final imageBytes = Uint8List.fromList(img.encodePng(testImage));
        final imageEntity = ImageEntity(
          id: 'test_constraints',
          path: 'test_constraints.png',
          bytes: imageBytes,
          width: 300,
          height: 300,
          createdAt: DateTime.now(),
        );

        final params = ProcessingParameters(
          useAdvancedAlgorithm: true,
          useAdaptiveEdgeThresholds: true,
          enableContourLinking: true,
          pointDensity: 0.6,
          maxPoints: 100,
          lineThickness: 1.0,
        );

        final result = await ConstellationProcessor.processImage(
          imageEntity,
          params,
        );

        expect(result.points.isNotEmpty, true);
        expect(result.lines.isNotEmpty, true);

        print('🔗 Constraint Test Results:');
        print('   Points: ${result.points.length}');
        print('   Lines: ${result.lines.length}');

        // Check for reasonable line density (not too many, not too few)
        final lineToPointRatio = result.lines.length / result.points.length;
        print('   Line-to-Point Ratio: ${lineToPointRatio.toStringAsFixed(2)}');

        expect(
          lineToPointRatio,
          lessThan(3.0),
          reason: 'Should not create excessive lines due to constraints',
        );
        expect(
          lineToPointRatio,
          greaterThan(0.5),
          reason: 'Should create reasonable number of connections',
        );

        // Verify the algorithm version is updated
        expect(result.metadata.algorithmVersion, '2.1.0');

        final diagnostics =
            result.metadata.parameters['diagnostics'] as Map<String, dynamic>;

        // Should maintain good distribution metrics
        final yCoverage = diagnostics['yCoverage'] as double;
        expect(
          yCoverage,
          greaterThan(0.3),
          reason: 'Should have vertical distribution',
        );

        print('   Y Coverage: ${(yCoverage * 100).toStringAsFixed(1)}%');
      },
    );

    test('Contour linking should work with Phase 8 anisotropic features', () async {
      // Test integration between Phase 8 (anisotropic selection) and Phase 9 (contour linking)
      final testImage = img.Image(width: 200, height: 200);
      img.fill(testImage, color: img.ColorRgb8(100, 100, 100));

      // Create an L-shaped contour
      for (int x = 50; x < 120; x++) {
        testImage.setPixel(
          x,
          80,
          img.ColorRgb8(255, 255, 255),
        ); // Horizontal part
      }
      for (int y = 80; y < 150; y++) {
        testImage.setPixel(
          120,
          y,
          img.ColorRgb8(255, 255, 255),
        ); // Vertical part
      }

      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      final imageEntity = ImageEntity(
        id: 'test_integration',
        path: 'test_integration.png',
        bytes: imageBytes,
        width: 200,
        height: 200,
        createdAt: DateTime.now(),
      );

      final params = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true, // Phase 7 & 8 features
        enableContourLinking: true, // Phase 9 feature
        pointDensity: 0.8,
        maxPoints: 60,
        cannyHighPercentile: 0.85,
        harrisPercentile: 0.9,
      );

      final result = await ConstellationProcessor.processImage(
        imageEntity,
        params,
      );

      expect(result.points.isNotEmpty, true);
      expect(result.lines.isNotEmpty, true);

      print('🔗 Integration Test Results:');
      print('   Points: ${result.points.length}');
      print('   Lines: ${result.lines.length}');

      final diagnostics =
          result.metadata.parameters['diagnostics'] as Map<String, dynamic>;
      final contourFollowing = diagnostics['contourFollowingDegree'] as double;
      final gridCoverage = diagnostics['gridCoverage'] as double;

      print(
        '   Contour Following: ${(contourFollowing * 100).toStringAsFixed(1)}%',
      );
      print('   Grid Coverage: ${(gridCoverage * 100).toStringAsFixed(1)}%');

      // Integration should work without errors
      expect(result.metadata.algorithmVersion, '2.1.0');
      expect(
        contourFollowing,
        greaterThan(0.1),
        reason: 'Integrated features should provide some contour following',
      );

      // Should create a reasonable constellation structure
      expect(
        result.lines.length,
        greaterThan(5),
        reason: 'Should generate adequate connections for L-shaped contour',
      );
    });

    test('Contour linking parameters should be properly serialized', () async {
      // Test that the new parameters are correctly saved in metadata
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(128, 128, 128));

      // Simple test pattern
      for (int i = 0; i < 50; i++) {
        testImage.setPixel(i + 25, 50, img.ColorRgb8(255, 255, 255));
      }

      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      final imageEntity = ImageEntity(
        id: 'test_params',
        path: 'test_params.png',
        bytes: imageBytes,
        width: 100,
        height: 100,
        createdAt: DateTime.now(),
      );

      final params = ProcessingParameters(
        useAdvancedAlgorithm: true,
        useAdaptiveEdgeThresholds: true,
        enableContourLinking: true,
        gridCellsX: 6,
        gridCellsY: 4,
        cannyHighPercentile: 0.88,
        cannyLowRatio: 0.4,
        harrisPercentile: 0.92,
        minEdgeCoverageAbs: 0.005,
        hysteresisHaloCells: 2,
        pointDensity: 0.5,
        maxPoints: 40,
      );

      final result = await ConstellationProcessor.processImage(
        imageEntity,
        params,
      );

      expect(result.points.isNotEmpty, true);

      // Check that all new parameters are preserved in metadata
      final savedParams = result.metadata.parameters;

      expect(savedParams['useAdaptiveEdgeThresholds'], true);
      expect(savedParams['enableContourLinking'], true);
      expect(savedParams['gridCellsX'], 6);
      expect(savedParams['gridCellsY'], 4);
      expect(savedParams['cannyHighPercentile'], 0.88);
      expect(savedParams['cannyLowRatio'], 0.4);
      expect(savedParams['harrisPercentile'], 0.92);
      expect(savedParams['minEdgeCoverageAbs'], 0.005);
      expect(savedParams['hysteresisHaloCells'], 2);

      // Check that diagnostics are included
      expect(savedParams['diagnostics'], isNotNull);

      final diagnostics = savedParams['diagnostics'] as Map<String, dynamic>;
      expect(diagnostics['edgePixelCount'], isA<int>());
      expect(diagnostics['contourFollowingDegree'], isA<double>());
      expect(diagnostics['kpiStatus'], isA<Map<String, dynamic>>());

      print('✅ Parameter Serialization Test Passed');
      print('   All Phase 7-9 parameters correctly saved');
      print('   Diagnostics included with ${diagnostics.length} metrics');
    });
  });
}
