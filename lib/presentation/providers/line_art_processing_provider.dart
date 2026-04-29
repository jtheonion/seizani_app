import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/line_art_entity.dart';
import '../../domain/entities/constellation_entity.dart';
import '../../domain/entities/line_art_decoration_entity.dart';
import '../../domain/repositories/processing_repository.dart';
import '../../domain/usecases/line_art_processing_usecase.dart';
import '../../domain/usecases/line_art_star_decoration_usecase.dart';
import 'dependencies.dart';

const Object _unsetLineArtProcessingStateValue = Object();

/// State for line art processing operations
class LineArtProcessingState {
  final LineArtProcessingStatus status;
  final double progress;
  final String currentStep;
  final ImageEntity? originalImage;
  final LineArtEntity? lineArt;
  final ConstellationEntity? constellation;
  final LineArtDecorationEntity? decoration;
  final LineArtParameters? parameters;
  final StarDecorationParams starDecorationParameters;
  final String? error;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool showParameterPanel; // Parameter adjustment panel visibility

  const LineArtProcessingState({
    this.status = LineArtProcessingStatus.idle,
    this.progress = 0.0,
    this.currentStep = '待機中',
    this.originalImage,
    this.lineArt,
    this.constellation,
    this.decoration,
    this.parameters,
    this.starDecorationParameters = const StarDecorationParams(),
    this.error,
    this.startTime,
    this.endTime,
    this.showParameterPanel = false, // Default to hidden
  });

  LineArtProcessingState copyWith({
    LineArtProcessingStatus? status,
    double? progress,
    String? currentStep,
    Object? originalImage = _unsetLineArtProcessingStateValue,
    Object? lineArt = _unsetLineArtProcessingStateValue,
    Object? constellation = _unsetLineArtProcessingStateValue,
    Object? decoration = _unsetLineArtProcessingStateValue,
    Object? parameters = _unsetLineArtProcessingStateValue,
    StarDecorationParams? starDecorationParameters,
    Object? error = _unsetLineArtProcessingStateValue,
    Object? startTime = _unsetLineArtProcessingStateValue,
    Object? endTime = _unsetLineArtProcessingStateValue,
    bool? showParameterPanel,
  }) {
    return LineArtProcessingState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      originalImage: identical(originalImage, _unsetLineArtProcessingStateValue)
          ? this.originalImage
          : originalImage as ImageEntity?,
      lineArt: identical(lineArt, _unsetLineArtProcessingStateValue)
          ? this.lineArt
          : lineArt as LineArtEntity?,
      constellation: identical(constellation, _unsetLineArtProcessingStateValue)
          ? this.constellation
          : constellation as ConstellationEntity?,
      decoration: identical(decoration, _unsetLineArtProcessingStateValue)
          ? this.decoration
          : decoration as LineArtDecorationEntity?,
      parameters: identical(parameters, _unsetLineArtProcessingStateValue)
          ? this.parameters
          : parameters as LineArtParameters?,
      starDecorationParameters:
          starDecorationParameters ?? this.starDecorationParameters,
      error: identical(error, _unsetLineArtProcessingStateValue)
          ? this.error
          : error as String?,
      startTime: identical(startTime, _unsetLineArtProcessingStateValue)
          ? this.startTime
          : startTime as DateTime?,
      endTime: identical(endTime, _unsetLineArtProcessingStateValue)
          ? this.endTime
          : endTime as DateTime?,
      showParameterPanel: showParameterPanel ?? this.showParameterPanel,
    );
  }

  bool get isProcessing =>
      status == LineArtProcessingStatus.processingToLineArt ||
      status == LineArtProcessingStatus.processingToConstellation;
  bool get hasLineArt =>
      lineArt != null && status != LineArtProcessingStatus.failed;
  bool get hasConstellation =>
      constellation != null && status == LineArtProcessingStatus.completed;
  bool get hasDecoration =>
      decoration != null && status == LineArtProcessingStatus.completed;
  bool get hasCompletedResult => hasConstellation || hasDecoration;
  bool get hasError =>
      error != null && status == LineArtProcessingStatus.failed;

  Duration? get processingTime {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }
}

/// Processing status for 2-stage conversion
enum LineArtProcessingStatus {
  idle, // 待機中
  processingToLineArt, // 画像→線画変換中
  lineArtReady, // 線画準備完了
  processingToConstellation, // 線画→星座変換中
  completed, // 完了
  failed, // エラー
}

/// Notifier for managing 2-stage line art processing
class LineArtProcessingNotifier extends StateNotifier<LineArtProcessingState> {
  final LineArtProcessingUseCase _useCase;
  final LineArtStarDecorationUseCase _starDecorationUseCase;

  LineArtProcessingNotifier(this._useCase, this._starDecorationUseCase)
    : super(const LineArtProcessingState());

  /// Start image to line art conversion (Stage 1)
  Future<void> startImageToLineArtProcessing(
    ImageEntity image, {
    LineArtParameters? customParameters,
  }) async {
    if (state.isProcessing) return;

    state = state.copyWith(
      status: LineArtProcessingStatus.processingToLineArt,
      progress: 0.0,
      currentStep: '線画変換を開始しています...',
      originalImage: image,
      lineArt: null,
      constellation: null,
      decoration: null,
      parameters: customParameters,
      starDecorationParameters: const StarDecorationParams(),
      error: null,
      startTime: DateTime.now(),
      endTime: null,
      showParameterPanel: false,
    );

    try {
      if (kDebugMode) {
        debugPrint('LineArtProcessingNotifier: Starting line art conversion');
      }

      await for (final result in _useCase.processImage(
        image,
        customParameters: customParameters,
      )) {
        state = state.copyWith(
          status: result.isCompleted
              ? LineArtProcessingStatus.lineArtReady
              : result.isFailed
              ? LineArtProcessingStatus.failed
              : LineArtProcessingStatus.processingToLineArt,
          progress: result.progress,
          currentStep: result.currentStep,
          lineArt: result.lineArt,
          error: result.errorMessage,
          endTime: result.isCompleted || result.isFailed
              ? DateTime.now()
              : null,
        );

        if (result.isCompleted) {
          debugPrint(
            '✅ [DEBUG] LineArtProcessingNotifier: 線画変換完了 - ${result.lineArt?.id}',
          );
        } else if (result.isFailed) {
          debugPrint(
            '❌ [ERROR] LineArtProcessingNotifier: 線画変換失敗 - ${result.errorMessage}',
          );
        }
      }
    } catch (e) {
      debugPrint('💥 [ERROR] LineArtProcessingNotifier: 線画変換例外 - $e');
      state = state.copyWith(
        status: LineArtProcessingStatus.failed,
        error: e.toString(),
        endTime: DateTime.now(),
      );
    }
  }

  /// Start line art to simple star decoration conversion (Stage 2)
  Future<void> startLineArtToConstellationProcessing({
    StarDecorationParams? starDecorationParameters,
  }) async {
    if (state.lineArt == null || state.isProcessing) return;

    final lineArt = state.lineArt!;
    final effectiveParameters =
        starDecorationParameters ?? state.starDecorationParameters;

    state = state.copyWith(
      status: LineArtProcessingStatus.processingToConstellation,
      progress: 0.0,
      currentStep: '星装飾を開始しています...',
      constellation: null,
      decoration: null,
      starDecorationParameters: effectiveParameters,
      error: null,
      endTime: null,
    );

    try {
      if (kDebugMode) {
        debugPrint(
          'LineArtProcessingNotifier: Starting simple star decoration',
        );
      }

      await for (final result in _starDecorationUseCase.decorate(
        lineArt,
        params: effectiveParameters,
      )) {
        state = state.copyWith(
          status: result.isCompleted
              ? LineArtProcessingStatus.completed
              : result.isFailed
              ? LineArtProcessingStatus.failed
              : LineArtProcessingStatus.processingToConstellation,
          progress: result.progress,
          currentStep: result.currentStep,
          decoration: result.decoration,
          starDecorationParameters: result.parameters,
          error: result.errorMessage,
          endTime: result.isCompleted || result.isFailed
              ? DateTime.now()
              : null,
        );
      }

      debugPrint(
        '✨ [DEBUG] LineArtProcessingNotifier: 星装飾完了 - ${state.decoration?.id}',
      );
    } catch (e) {
      debugPrint('💥 [ERROR] LineArtProcessingNotifier: 星座変換失敗 - $e');
      state = state.copyWith(
        status: LineArtProcessingStatus.failed,
        error: e.toString(),
        endTime: DateTime.now(),
      );
    }
  }

  /// Reset processing state
  void reset() {
    state = const LineArtProcessingState();
  }

  /// Clear error and reset to line art ready state
  void clearError() {
    if (state.hasLineArt && state.hasError) {
      state = state.copyWith(
        status: LineArtProcessingStatus.lineArtReady,
        error: null,
      );
    }
  }

  /// Toggle parameter adjustment panel visibility
  void toggleParameterPanel() {
    state = state.copyWith(showParameterPanel: !state.showParameterPanel);
  }

  void updateStarDecorationParameters(StarDecorationParams newParameters) {
    state = state.copyWith(starDecorationParameters: newParameters);
  }

  /// Update line art parameters and reprocess if needed
  Future<void> updateParameters(LineArtParameters newParameters) async {
    if (state.originalImage != null &&
        state.status != LineArtProcessingStatus.processingToLineArt) {
      await startImageToLineArtProcessing(
        state.originalImage!,
        customParameters: newParameters,
      );
    }
  }
}

/// Provider for line art processing
final lineArtProcessingProvider =
    StateNotifierProvider<LineArtProcessingNotifier, LineArtProcessingState>((
      ref,
    ) {
      final useCase = ref.read(lineArtProcessingUseCaseProvider);
      final starDecorationUseCase = ref.read(
        lineArtStarDecorationUseCaseProvider,
      );
      return LineArtProcessingNotifier(useCase, starDecorationUseCase);
    });

/// Provider for line art parameters presets
final lineArtPresetsProvider = Provider<Map<String, LineArtParameters>>((ref) {
  final useCase = ref.read(lineArtProcessingUseCaseProvider);

  return {
    'DexiNed線画': useCase.getPresetParameters(LineArtPreset.dexined),
    '写真': useCase.getPresetParameters(LineArtPreset.photograph),
    'イラスト': useCase.getPresetParameters(LineArtPreset.illustration),
    '風景': useCase.getPresetParameters(LineArtPreset.landscape),
    '鉛筆スケッチ': useCase.getPresetParameters(LineArtPreset.pencilSketch),
  };
});

/// Provider for available line art algorithms
final lineArtAlgorithmsProvider = Provider<List<LineArtAlgorithm>>((ref) {
  final useCase = ref.read(lineArtProcessingUseCaseProvider);
  return useCase.getAvailableAlgorithms();
});

/// Provider for constellation processing parameters (seiza_graph.md inspired)
/// Manages real-time parameter adjustments for glow effects
final processingParametersProvider = StateProvider<ProcessingParameters>((ref) {
  return const ProcessingParameters(); // Default parameters
});

/// Provider for simple star decoration parameters in the 2-stage flow
final starDecorationParametersProvider = StateProvider<StarDecorationParams>((
  ref,
) {
  return const StarDecorationParams();
});

/// Temporary file creation helper
File? createTempFileFromBytes(Uint8List bytes, String suffix) {
  try {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/${suffix}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    tempFile.writeAsBytesSync(bytes);
    return tempFile;
  } catch (e) {
    debugPrint('⚠️ [WARNING] 一時ファイル作成失敗: $e');
    return null;
  }
}
