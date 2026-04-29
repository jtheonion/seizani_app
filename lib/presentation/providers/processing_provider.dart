import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/constellation_entity.dart';
import 'constellation_processing_provider.dart';

// Legacy compatibility provider - delegates to new Clean Architecture providers

enum ProcessingStatus {
  idle,
  preprocessing,
  edgeDetection,
  featureExtraction,
  constellationGeneration,
  rendering,
  completed,
  error,
}

class ProcessingState {
  final ProcessingStatus status;
  final double progress;
  final String? statusMessage;
  final File? processedImage;
  final String? error;
  final Map<String, dynamic>? processingParams;

  const ProcessingState({
    this.status = ProcessingStatus.idle,
    this.progress = 0.0,
    this.statusMessage,
    this.processedImage,
    this.error,
    this.processingParams,
  });

  ProcessingState copyWith({
    ProcessingStatus? status,
    double? progress,
    String? statusMessage,
    File? processedImage,
    String? error,
    Map<String, dynamic>? processingParams,
  }) {
    return ProcessingState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      processedImage: processedImage ?? this.processedImage,
      error: error ?? this.error,
      processingParams: processingParams ?? this.processingParams,
    );
  }

  bool get isProcessing {
    return status != ProcessingStatus.idle &&
        status != ProcessingStatus.completed &&
        status != ProcessingStatus.error;
  }

  String get statusText {
    switch (status) {
      case ProcessingStatus.idle:
        return '待機中';
      case ProcessingStatus.preprocessing:
        return '前処理中...';
      case ProcessingStatus.edgeDetection:
        return 'エッジ検出中...';
      case ProcessingStatus.featureExtraction:
        return '特徴点抽出中...';
      case ProcessingStatus.constellationGeneration:
        return '星座生成中...';
      case ProcessingStatus.rendering:
        return '画像生成中...';
      case ProcessingStatus.completed:
        return '完了';
      case ProcessingStatus.error:
        return 'エラー';
    }
  }
}

class ProcessingNotifier extends StateNotifier<ProcessingState> {
  final Ref _ref;

  ProcessingNotifier(this._ref) : super(const ProcessingState()) {
    // Listen to the new Clean Architecture provider
    _ref.listen(constellationProcessingProvider, (previous, next) {
      state = _mapFromConstellationProcessingState(next);
    });
  }

  Future<void> startProcessing(File inputImage) async {
    // デバッグログ追加
    if (kDebugMode)
      debugPrint('Starting constellation processing: ${inputImage.path}');
    print('🌟 [CONSOLE] 星座変換処理開始: ${inputImage.path}');

    try {
      // ファイルからバイト配列を読み込む
      final bytes = await inputImage.readAsBytes();
      if (kDebugMode) debugPrint('Image size: ${bytes.length} bytes');
      print('📊 [CONSOLE] 画像サイズ: ${bytes.length} bytes');

      // compute isolateで画像デコード（Thread Safety）
      final imageInfo = await compute(_decodeImageInfo, bytes);
      if (kDebugMode) {
        debugPrint(
          'Image dimensions: ${imageInfo['width']}x${imageInfo['height']}',
        );
      }
      print('📐 [CONSOLE] 画像サイズ: ${imageInfo['width']}x${imageInfo['height']}');

      // Create ImageEntity with actual data
      final imageEntity = ImageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: inputImage.path,
        bytes: bytes, // ✅ bytesを設定
        width: imageInfo['width'] ?? 0,
        height: imageInfo['height'] ?? 0,
        createdAt: DateTime.now(),
      );

      if (kDebugMode) debugPrint('ImageEntity created: ${imageEntity.id}');
      print('✅ [CONSOLE] ImageEntity作成完了: ${imageEntity.id}');

      // Check if constellation provider is available
      print('🔧 [CONSOLE] constellation provider 確認中...');
      final provider = _ref.read(constellationProcessingProvider.notifier);
      print('🔧 [CONSOLE] constellation provider 取得完了');

      // Delegate to new Clean Architecture provider
      print('🚀 [CONSOLE] constellation processing 開始...');
      await provider.startProcessing(imageEntity);
      print('🎉 [CONSOLE] constellation processing 完了');
    } catch (e, stackTrace) {
      debugPrint('❌ [ERROR] 処理開始失敗: $e');
      print('❌ [CONSOLE ERROR] 処理開始失敗: $e');
      print('📍 [STACK] $stackTrace');
      rethrow;
    }
  }

  /// Thread-safe画像情報取得
  static Map<String, int> _decodeImageInfo(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      return {'width': image?.width ?? 0, 'height': image?.height ?? 0};
    } catch (e) {
      debugPrint('⚠️ [WARNING] 画像デコード失敗: $e');
      return {'width': 0, 'height': 0};
    }
  }

  void reset() {
    _ref.read(constellationProcessingProvider.notifier).reset();
  }

  void clearError() {
    _ref.read(constellationProcessingProvider.notifier).clearError();
  }

  void updateProgress(double progress, String? message) {
    // This is handled automatically by the new provider
  }

  /// Map from new ConstellationProcessingState to legacy ProcessingState
  ProcessingState _mapFromConstellationProcessingState(
    ConstellationProcessingState newState,
  ) {
    print(
      '🔄 [CONSOLE] State mapping: hasResult=${newState.hasResult}, progress=${newState.progress}, isProcessing=${newState.isProcessing}',
    );
    debugPrint(
      '🔄 [DEBUG] State mapping: hasResult=${newState.hasResult}, progress=${newState.progress}',
    );

    ProcessingStatus legacyStatus;
    File? processedImageFile;

    if (newState.isProcessing) {
      // Map progress to processing steps
      final progress = newState.progress;
      if (progress < 0.2) {
        legacyStatus = ProcessingStatus.preprocessing;
      } else if (progress < 0.4) {
        legacyStatus = ProcessingStatus.edgeDetection;
      } else if (progress < 0.6) {
        legacyStatus = ProcessingStatus.featureExtraction;
      } else if (progress < 0.8) {
        legacyStatus = ProcessingStatus.constellationGeneration;
      } else {
        legacyStatus = ProcessingStatus.rendering;
      }
    } else if (newState.hasResult) {
      legacyStatus = ProcessingStatus.completed;
      print('🎉 [CONSOLE] 結果あり！星座生成完了');

      // 星座生成完了時にTemporary Fileを作成
      final lastResult = newState.lastResult;
      if (lastResult != null) {
        print(
          '🖼️ [CONSOLE] 星座画像バイトデータあり: ${lastResult.renderedImageBytes.length} bytes',
        );
        try {
          processedImageFile = _createTempFileFromBytes(
            lastResult.renderedImageBytes,
          );
          print('🎨 [CONSOLE] 星座画像ファイル作成完了: ${processedImageFile?.path}');
          debugPrint('🎨 [DEBUG] 星座画像ファイル作成完了: ${processedImageFile?.path}');
        } catch (e) {
          print('❌ [CONSOLE ERROR] 画像ファイル作成失敗: $e');
          debugPrint('❌ [ERROR] 画像ファイル作成失敗: $e');
        }
      } else {
        print('⚠️ [CONSOLE WARNING] 星座画像バイトデータなし');
      }
    } else if (newState.hasError) {
      legacyStatus = ProcessingStatus.error;
    } else {
      legacyStatus = ProcessingStatus.idle;
    }

    return ProcessingState(
      status: legacyStatus,
      progress: newState.progress,
      statusMessage: newState.currentStep,
      processedImage: processedImageFile, // ✅ 結果を設定
      error: newState.error,
      processingParams: newState.currentProcessing?.constellation?.metadata
          .toMap(),
    );
  }

  /// バイト配列から一時ファイルを作成
  File? _createTempFileFromBytes(Uint8List bytes) {
    try {
      // 実際の一時ファイルを作成
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/constellation_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      // 同期的にバイト配列を書き込み（UIスレッドで実行するため最小限に）
      tempFile.writeAsBytesSync(bytes);

      return tempFile;
    } catch (e) {
      debugPrint('⚠️ [WARNING] 一時ファイル作成失敗: $e');
      return null;
    }
  }
}

final processingProvider =
    StateNotifierProvider<ProcessingNotifier, ProcessingState>((ref) {
      return ProcessingNotifier(ref);
    });

// Extension to convert processing metadata to map
extension on ProcessingMetadata {
  Map<String, dynamic> toMap() {
    return {
      'processingTime': processingTime.inMilliseconds,
      'edgePoints': edgePoints,
      'complexity': complexity,
      'algorithmVersion': algorithmVersion,
      ...parameters,
    };
  }
}
