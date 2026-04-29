import 'constellation_entity.dart';
import 'image_entity.dart';

/// Represents the result of a constellation processing operation
class ProcessingResult {
  final String id;
  final ImageEntity originalImage;
  final ConstellationEntity? constellation;
  final ProcessingStatus status;
  final String? errorMessage;
  final double progress; // 0.0 - 1.0
  final String currentStep;
  final DateTime startTime;
  final DateTime? endTime;

  const ProcessingResult({
    required this.id,
    required this.originalImage,
    this.constellation,
    required this.status,
    this.errorMessage,
    required this.progress,
    required this.currentStep,
    required this.startTime,
    this.endTime,
  });

  ProcessingResult copyWith({
    String? id,
    ImageEntity? originalImage,
    ConstellationEntity? constellation,
    ProcessingStatus? status,
    String? errorMessage,
    double? progress,
    String? currentStep,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return ProcessingResult(
      id: id ?? this.id,
      originalImage: originalImage ?? this.originalImage,
      constellation: constellation ?? this.constellation,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Duration? get processingDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  bool get isCompleted => status == ProcessingStatus.completed;
  bool get isFailed => status == ProcessingStatus.failed;
  bool get isProcessing => status == ProcessingStatus.processing;
  bool get isPending => status == ProcessingStatus.pending;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessingResult &&
        other.id == id &&
        other.originalImage == originalImage &&
        other.status == status &&
        other.progress == progress;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        originalImage.hashCode ^
        status.hashCode ^
        progress.hashCode;
  }

  @override
  String toString() {
    return 'ProcessingResult(id: $id, status: $status, progress: $progress, currentStep: $currentStep)';
  }
}

/// Status of the processing operation
enum ProcessingStatus { pending, processing, completed, failed, cancelled }

extension ProcessingStatusExtension on ProcessingStatus {
  String get displayName {
    switch (this) {
      case ProcessingStatus.pending:
        return '待機中';
      case ProcessingStatus.processing:
        return '処理中';
      case ProcessingStatus.completed:
        return '完了';
      case ProcessingStatus.failed:
        return '失敗';
      case ProcessingStatus.cancelled:
        return 'キャンセル';
    }
  }

  bool get isActive {
    return this == ProcessingStatus.pending ||
        this == ProcessingStatus.processing;
  }

  bool get isFinished {
    return this == ProcessingStatus.completed ||
        this == ProcessingStatus.failed ||
        this == ProcessingStatus.cancelled;
  }
}
