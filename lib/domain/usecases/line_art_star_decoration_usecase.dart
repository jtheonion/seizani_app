import '../entities/line_art_decoration_entity.dart';
import '../entities/line_art_entity.dart';
import '../repositories/processing_repository.dart';

/// Use case for the simple star decoration flow after line art processing.
class LineArtStarDecorationUseCase {
  final ProcessingRepository _processingRepository;

  const LineArtStarDecorationUseCase(this._processingRepository);

  Stream<LineArtStarDecorationResult> decorate(
    LineArtEntity lineArt, {
    StarDecorationParams? params,
  }) async* {
    final applied = params ?? const StarDecorationParams();
    final startTime = DateTime.now();

    try {
      yield LineArtStarDecorationResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArt: lineArt,
        status: LineArtStarDecorationStatus.processing,
        progress: 0.0,
        currentStep: '星装飾を準備中...',
        startTime: startTime,
        parameters: applied,
      );

      yield LineArtStarDecorationResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArt: lineArt,
        status: LineArtStarDecorationStatus.processing,
        progress: 0.4,
        currentStep: '線の解析中...',
        startTime: startTime,
        parameters: applied,
      );

      final decoration = await _processingRepository.decorateLineArt(
        lineArt,
        params: applied,
      );

      yield LineArtStarDecorationResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArt: lineArt,
        decoration: decoration,
        status: LineArtStarDecorationStatus.processing,
        progress: 0.85,
        currentStep: '星を描画中...',
        startTime: startTime,
        parameters: applied,
      );

      yield LineArtStarDecorationResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArt: lineArt,
        decoration: decoration,
        status: LineArtStarDecorationStatus.completed,
        progress: 1.0,
        currentStep: '完了',
        startTime: startTime,
        endTime: DateTime.now(),
        parameters: applied,
      );
    } catch (e) {
      yield LineArtStarDecorationResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArt: lineArt,
        status: LineArtStarDecorationStatus.failed,
        progress: 0.0,
        currentStep: 'エラー',
        errorMessage: '星装飾処理に失敗しました: $e',
        startTime: startTime,
        endTime: DateTime.now(),
        parameters: applied,
      );
    }
  }
}

class LineArtStarDecorationResult {
  final String id;
  final LineArtEntity sourceLineArt;
  final LineArtDecorationEntity? decoration;
  final LineArtStarDecorationStatus status;
  final double progress;
  final String currentStep;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime? endTime;
  final StarDecorationParams parameters;

  const LineArtStarDecorationResult({
    required this.id,
    required this.sourceLineArt,
    this.decoration,
    required this.status,
    required this.progress,
    required this.currentStep,
    this.errorMessage,
    required this.startTime,
    this.endTime,
    required this.parameters,
  });

  bool get isCompleted => status == LineArtStarDecorationStatus.completed;
  bool get isFailed => status == LineArtStarDecorationStatus.failed;
  bool get isProcessing => status == LineArtStarDecorationStatus.processing;

  Duration get processingTime {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}

enum LineArtStarDecorationStatus { idle, processing, completed, failed }
