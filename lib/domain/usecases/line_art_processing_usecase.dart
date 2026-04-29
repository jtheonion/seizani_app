import '../entities/image_entity.dart';
import '../entities/line_art_entity.dart';
import '../entities/constellation_entity.dart';
import '../repositories/processing_repository.dart';
import '../repositories/storage_repository.dart';

/// Use case for line art processing operations
class LineArtProcessingUseCase {
  final ProcessingRepository _processingRepository;
  final StorageRepository _storageRepository;

  const LineArtProcessingUseCase(
    this._processingRepository,
    this._storageRepository,
  );

  /// Process image to create line art
  Stream<LineArtProcessingResult> processImage(
    ImageEntity image, {
    LineArtParameters? customParameters,
  }) async* {
    try {
      // Use custom parameters or default
      final parameters = customParameters ?? const LineArtParameters();

      // Yield starting state
      yield LineArtProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        status: LineArtProcessingStatus.processing,
        progress: 0.0,
        currentStep: '線画変換開始',
        startTime: DateTime.now(),
        parameters: parameters,
      );

      // Process image to line art
      yield LineArtProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        status: LineArtProcessingStatus.processing,
        progress: 0.3,
        currentStep: parameters.algorithm == LineArtAlgorithm.dexined
            ? 'DexiNed推論中...'
            : 'エッジ検出中...',
        startTime: DateTime.now(),
        parameters: parameters,
      );

      final lineArt = await _processingRepository.processImageToLineArt(
        image,
        parameters: parameters,
      );

      yield LineArtProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        status: LineArtProcessingStatus.processing,
        progress: 0.8,
        currentStep: '線画生成中...',
        startTime: DateTime.now(),
        parameters: parameters,
      );

      // Save result
      await _storageRepository.saveLineArt(lineArt);

      // Yield completed result
      yield LineArtProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        lineArt: lineArt,
        status: LineArtProcessingStatus.completed,
        progress: 1.0,
        currentStep: '完了',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        parameters: parameters,
      );
    } catch (e) {
      yield LineArtProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        status: LineArtProcessingStatus.failed,
        errorMessage: '線画変換処理に失敗しました: $e',
        progress: 0.0,
        currentStep: 'エラー',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        parameters: customParameters ?? const LineArtParameters(),
      );
    }
  }

  /// Get available line art algorithms
  List<LineArtAlgorithm> getAvailableAlgorithms() {
    return LineArtAlgorithm.values;
  }

  /// Create preset parameters for specific use cases
  LineArtParameters getPresetParameters(LineArtPreset preset) {
    switch (preset) {
      case LineArtPreset.photograph:
        return const LineArtParameters(
          algorithm: LineArtAlgorithm.xdog,
          edgeThreshold: 0.4,
          contrast: 1.3,
          smoothLines: true,
          sigma1: 0.8,
          sigma2: 1.2,
          tau: 0.97,
          phi: 2.5,
          epsilon: -0.1,
        );
      case LineArtPreset.illustration:
        return const LineArtParameters(
          algorithm: LineArtAlgorithm.sobel,
          edgeThreshold: 0.3,
          contrast: 1.5,
          smoothLines: false,
        );
      case LineArtPreset.landscape:
        return const LineArtParameters(
          algorithm: LineArtAlgorithm.canny,
          edgeThreshold: 0.35,
          contrast: 1.2,
          smoothLines: true,
        );
      case LineArtPreset.pencilSketch:
        return const LineArtParameters(
          algorithm: LineArtAlgorithm.pencilSketch,
          edgeThreshold: 0.5,
          contrast: 1.0,
          smoothLines: true,
          sigma1: 1.0,
        );
      case LineArtPreset.dexined:
        return LineArtParameters.dexinedDefaults;
    }
  }

  /// Convert line art to constellation
  Future<ConstellationEntity> processLineArtToConstellation(
    LineArtEntity lineArt, {
    ProcessingParameters? parameters,
  }) async {
    return await _processingRepository.processLineArt(
      lineArt,
      parameters: parameters,
    );
  }
}

/// Processing result for line art operations
class LineArtProcessingResult {
  final String id;
  final ImageEntity originalImage;
  final LineArtEntity? lineArt;
  final LineArtProcessingStatus status;
  final double progress;
  final String currentStep;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime? endTime;
  final LineArtParameters parameters;

  const LineArtProcessingResult({
    required this.id,
    required this.originalImage,
    this.lineArt,
    required this.status,
    required this.progress,
    required this.currentStep,
    this.errorMessage,
    required this.startTime,
    this.endTime,
    required this.parameters,
  });

  bool get isCompleted => status == LineArtProcessingStatus.completed;
  bool get isFailed => status == LineArtProcessingStatus.failed;
  bool get isProcessing => status == LineArtProcessingStatus.processing;

  Duration get processingTime {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  LineArtProcessingResult copyWith({
    String? id,
    ImageEntity? originalImage,
    LineArtEntity? lineArt,
    LineArtProcessingStatus? status,
    double? progress,
    String? currentStep,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
    LineArtParameters? parameters,
  }) {
    return LineArtProcessingResult(
      id: id ?? this.id,
      originalImage: originalImage ?? this.originalImage,
      lineArt: lineArt ?? this.lineArt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      parameters: parameters ?? this.parameters,
    );
  }
}

/// Processing status for line art operations
enum LineArtProcessingStatus { idle, processing, completed, failed }

/// Preset configurations for different types of images
enum LineArtPreset {
  photograph,
  illustration,
  landscape,
  pencilSketch,
  dexined,
}
