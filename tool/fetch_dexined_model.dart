import 'dart:io';

import 'package:crypto/crypto.dart';

const modelUrl =
    'https://huggingface.co/opencv/edge_detection_dexined/resolve/main/'
    'edge_detection_dexined_2024sep.onnx';
const modelPath = 'assets/models/edge_detection_dexined_2024sep.onnx';
const expectedSha256 =
    'a50d01dc8481549c7dedb9eb3e0123b810a016520df75e4669a504609982cdd0';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final modelFile = File(modelPath);

  if (!force && await modelFile.exists()) {
    final digest = await _sha256Of(modelFile);
    if (digest == expectedSha256) {
      stdout.writeln('DexiNed model already exists: $modelPath');
      return;
    }
    stderr.writeln('Existing DexiNed model checksum mismatch; downloading.');
  }

  await modelFile.parent.create(recursive: true);
  final tempFile = File('$modelPath.download');
  if (await tempFile.exists()) {
    await tempFile.delete();
  }

  stdout.writeln('Downloading DexiNed ONNX model...');
  await _download(modelUrl, tempFile);

  final digest = await _sha256Of(tempFile);
  if (digest != expectedSha256) {
    await tempFile.delete();
    stderr.writeln('SHA256 mismatch for downloaded model.');
    stderr.writeln('Expected: $expectedSha256');
    stderr.writeln('Actual:   $digest');
    exitCode = 65;
    return;
  }

  if (await modelFile.exists()) {
    await modelFile.delete();
  }
  await tempFile.rename(modelPath);
  stdout.writeln('DexiNed model saved: $modelPath');
}

Future<void> _download(String url, File output) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to download DexiNed model: HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    await response.pipe(output.openWrite());
  } finally {
    client.close(force: true);
  }
}

Future<String> _sha256Of(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
