import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:seizani_app/domain/entities/line_art_entity.dart';
import 'package:seizani_app/infrastructure/services/pidinet_onnx_line_art_service.dart';

void main() {
  group('PiDiNet line art post-processing', () {
    test('turns strong edge responses into black lines on white', () {
      final edges = List<num>.filled(16, 0.05);
      edges[5] = 0.95;
      edges[10] = 0.95;

      final lineArt = PidinetOnnxLineArtService.postProcessEdgesForTesting(
        edges,
        outputWidth: 4,
        outputHeight: 4,
        targetWidth: 4,
        targetHeight: 4,
        edgeThreshold: 0.3,
      );

      expect(img.getLuminance(lineArt.getPixel(1, 1)), lessThan(10));
      expect(img.getLuminance(lineArt.getPixel(2, 2)), lessThan(10));
      expect(img.getLuminance(lineArt.getPixel(0, 0)), greaterThan(240));
    });

    test('line thickness increases black line pixels', () {
      final edges = List<num>.filled(25, 0.05);
      edges[12] = 0.95;

      final thinLineArt = PidinetOnnxLineArtService.postProcessEdgesForTesting(
        edges,
        outputWidth: 5,
        outputHeight: 5,
        targetWidth: 5,
        targetHeight: 5,
        edgeThreshold: 0.3,
        lineThickness: 1,
      );
      final thickLineArt = PidinetOnnxLineArtService.postProcessEdgesForTesting(
        edges,
        outputWidth: 5,
        outputHeight: 5,
        targetWidth: 5,
        targetHeight: 5,
        edgeThreshold: 0.3,
        lineThickness: 3,
      );

      expect(
        _countBlackPixels(thickLineArt),
        greaterThan(_countBlackPixels(thinLineArt)),
      );
    });

    test('accepts logits as well as probability responses', () {
      final logits = List<num>.filled(4, -10);
      logits[3] = 10;

      final lineArt = PidinetOnnxLineArtService.postProcessEdgesForTesting(
        logits,
        outputWidth: 2,
        outputHeight: 2,
        targetWidth: 2,
        targetHeight: 2,
        edgeThreshold: 0.3,
      );

      expect(img.getLuminance(lineArt.getPixel(1, 1)), lessThan(10));
      expect(img.getLuminance(lineArt.getPixel(0, 0)), greaterThan(240));
    });
  });

  group('PiDiNet parameters', () {
    test('round-trips through LineArtParameters JSON', () {
      final encoded = LineArtParameters.pidinetDefaults
          .copyWith(edgeThreshold: 0.42, lineThickness: 3, contrast: 1.25)
          .toJson();
      final decoded = LineArtParameters.fromJson(encoded);

      expect(decoded.algorithm, LineArtAlgorithm.pidinet);
      expect(decoded.edgeThreshold, 0.42);
      expect(decoded.lineThickness, 3);
      expect(decoded.contrast, 1.25);
      expect(decoded.smoothLines, isFalse);
    });

    test('round-trips through LineArtMetadata JSON', () {
      const metadata = LineArtMetadata(
        processingTime: Duration(milliseconds: 123),
        algorithm: LineArtAlgorithm.pidinet,
        edgeStrength: 0.3,
        contrastLevel: 1.0,
        algorithmVersion: 'test',
        parameters: {
          'algorithm': 'pidinet',
          'modelAsset': PidinetOnnxLineArtService.modelAssetPath,
          'checkpointSha256': PidinetOnnxLineArtService.checkpointSha256,
          'licensePolicy': PidinetOnnxLineArtService.licensePolicy,
        },
      );

      final decoded = LineArtMetadata.fromJson(metadata.toJson());

      expect(decoded.algorithm, LineArtAlgorithm.pidinet);
      expect(decoded.parameters['algorithm'], 'pidinet');
      expect(
        decoded.parameters['modelAsset'],
        PidinetOnnxLineArtService.modelAssetPath,
      );
      expect(
        decoded.parameters['checkpointSha256'],
        PidinetOnnxLineArtService.checkpointSha256,
      );
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
