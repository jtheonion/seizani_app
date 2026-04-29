import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/constellation_entity.dart';
import '../../domain/entities/processing_result.dart';
import '../../domain/repositories/processing_repository.dart';
import '../../domain/usecases/constellation_processing_usecase.dart';
import '../providers/dependencies.dart';

/// State for constellation processing
class ConstellationProcessingState {
  final ProcessingResult? currentProcessing;
  final ConstellationEntity? lastResult;
  final bool isProcessing;
  final String? error;
  final List<ProcessingResult> history;
  final ProcessingStatistics? statistics;

  const ConstellationProcessingState({
    this.currentProcessing,
    this.lastResult,
    this.isProcessing = false,
    this.error,
    this.history = const [],
    this.statistics,
  });

  ConstellationProcessingState copyWith({
    ProcessingResult? currentProcessing,
    ConstellationEntity? lastResult,
    bool? isProcessing,
    String? error,
    List<ProcessingResult>? history,
    ProcessingStatistics? statistics,
  }) {
    return ConstellationProcessingState(
      currentProcessing: currentProcessing ?? this.currentProcessing,
      lastResult: lastResult ?? this.lastResult,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      history: history ?? this.history,
      statistics: statistics ?? this.statistics,
    );
  }

  double get progress => currentProcessing?.progress ?? 0.0;
  String get currentStep => currentProcessing?.currentStep ?? '';
  bool get hasResult => lastResult != null;
  bool get hasError => error != null;
  bool get canProcess => !isProcessing;
}

/// Notifier for constellation processing state
class ConstellationProcessingNotifier
    extends StateNotifier<ConstellationProcessingState> {
  final ConstellationProcessingUseCase _processingUseCase;
  StreamSubscription<ProcessingResult>? _processingSubscription;

  ConstellationProcessingNotifier(this._processingUseCase)
    : super(const ConstellationProcessingState()) {
    _loadInitialData();
  }

  @override
  void dispose() {
    _processingSubscription?.cancel();
    super.dispose();
  }

  /// Load initial data (history, statistics)
  Future<void> _loadInitialData() async {
    try {
      final historyResult = await _processingUseCase.getProcessingHistory(
        pageSize: 10,
      );
      final statistics = await _processingUseCase.getProcessingStatistics();

      if (historyResult.isSuccess) {
        state = state.copyWith(
          history: historyResult.results ?? [],
          statistics: statistics,
        );
      }
    } catch (e) {
      // Silently fail for initial data loading
    }
  }

  /// Start processing an image
  Future<void> startProcessing(
    ImageEntity image, {
    ProcessingParameters? parameters,
  }) async {
    if (state.isProcessing) return;

    state = state.copyWith(
      isProcessing: true,
      error: null,
      currentProcessing: null,
      lastResult: null,
    );

    try {
      _processingSubscription?.cancel();

      final processingStream = _processingUseCase.processImage(
        image,
        customParameters: parameters,
      );

      _processingSubscription = processingStream.listen(
        (result) {
          print(
            '📡 [CONSOLE] Processing result received: status=${result.status}, progress=${result.progress}',
          );
          if (kDebugMode)
            debugPrint('Processing result received: ${result.status}');
          print(
            '🌟 [CONSOLE] Result constellation: ${result.constellation?.id ?? "null"}',
          );

          state = state.copyWith(
            currentProcessing: result,
            isProcessing: result.status.isActive,
            lastResult: result.constellation ?? state.lastResult,
          );

          print(
            '🔄 [CONSOLE] State updated: hasResult=${state.hasResult}, isProcessing=${state.isProcessing}',
          );

          // If processing completed, refresh history
          if (result.isCompleted || result.isFailed) {
            print('📚 [CONSOLE] Refreshing history...');
            _refreshHistory();
          }
        },
        onError: (error) {
          state = state.copyWith(
            isProcessing: false,
            error: 'Processing failed: $error',
          );
        },
        onDone: () {
          if (state.isProcessing) {
            state = state.copyWith(isProcessing: false);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: '処理の開始に失敗しました: $e');
    }
  }

  /// Cancel current processing
  Future<void> cancelProcessing() async {
    final currentProcessing = state.currentProcessing;
    if (currentProcessing != null && state.isProcessing) {
      try {
        final success = await _processingUseCase.cancelProcessing(
          currentProcessing.id,
        );
        if (success) {
          _processingSubscription?.cancel();
          state = state.copyWith(
            isProcessing: false,
            currentProcessing: null,
            error: null,
          );
        }
      } catch (e) {
        state = state.copyWith(error: 'Processing cancellation failed: $e');
      }
    }
  }

  /// Load processing history
  Future<void> loadHistory({int page = 0, int pageSize = 20}) async {
    try {
      final result = await _processingUseCase.getProcessingHistory(
        page: page,
        pageSize: pageSize,
      );

      if (result.isSuccess) {
        final newHistory = page == 0
            ? (result.results?.cast<ProcessingResult>() ?? <ProcessingResult>[])
            : [
                ...state.history,
                ...(result.results?.cast<ProcessingResult>() ??
                    <ProcessingResult>[]),
              ];

        state = state.copyWith(history: newHistory);
      } else {
        state = state.copyWith(error: result.error);
      }
    } catch (e) {
      state = state.copyWith(error: 'History loading failed: $e');
    }
  }

  /// Refresh history after processing completion
  Future<void> _refreshHistory() async {
    try {
      final result = await _processingUseCase.getProcessingHistory(
        pageSize: 10,
      );
      final statistics = await _processingUseCase.getProcessingStatistics();

      if (result.isSuccess) {
        state = state.copyWith(
          history: result.results ?? [],
          statistics: statistics,
        );
      }
    } catch (e) {
      // Silently fail for history refresh
    }
  }

  /// Delete processing result
  Future<void> deleteResult(String resultId) async {
    try {
      final success = await _processingUseCase.deleteProcessingResult(resultId);
      if (success) {
        final updatedHistory = state.history
            .where((r) => r.id != resultId)
            .toList();
        state = state.copyWith(history: updatedHistory);

        // Refresh statistics
        final statistics = await _processingUseCase.getProcessingStatistics();
        state = state.copyWith(statistics: statistics);
      } else {
        state = state.copyWith(error: 'Failed to delete result');
      }
    } catch (e) {
      state = state.copyWith(error: 'Delete operation failed: $e');
    }
  }

  /// Clear all processing history
  Future<void> clearHistory() async {
    try {
      final success = await _processingUseCase.clearProcessingHistory();
      if (success) {
        state = state.copyWith(
          history: [],
          statistics: ProcessingStatistics(
            totalProcessed: 0,
            successfulProcessing: 0,
            failedProcessing: 0,
            averageProcessingTime: Duration.zero,
            lastProcessedAt: DateTime.now(),
          ),
        );
      } else {
        state = state.copyWith(error: 'Failed to clear history');
      }
    } catch (e) {
      state = state.copyWith(error: 'Clear history failed: $e');
    }
  }

  /// Save processing parameters as default
  Future<void> saveDefaultParameters(ProcessingParameters parameters) async {
    try {
      await _processingUseCase.saveDefaultProcessingParameters(parameters);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save parameters: $e');
    }
  }

  /// Reset state
  void reset() {
    _processingSubscription?.cancel();
    state = const ConstellationProcessingState();
    _loadInitialData();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for constellation processing state
final constellationProcessingProvider =
    StateNotifierProvider<
      ConstellationProcessingNotifier,
      ConstellationProcessingState
    >((ref) {
      final processingUseCase = ref.read(
        constellationProcessingUseCaseProvider,
      );
      return ConstellationProcessingNotifier(processingUseCase);
    });

/// Convenience providers for specific state properties
final isProcessingProvider = Provider<bool>((ref) {
  return ref.watch(constellationProcessingProvider).isProcessing;
});

final processingProgressProvider = Provider<double>((ref) {
  return ref.watch(constellationProcessingProvider).progress;
});

final processingStepProvider = Provider<String>((ref) {
  return ref.watch(constellationProcessingProvider).currentStep;
});

final lastConstellationProvider = Provider<ConstellationEntity?>((ref) {
  return ref.watch(constellationProcessingProvider).lastResult;
});

final processingHistoryProvider = Provider<List<ProcessingResult>>((ref) {
  return ref.watch(constellationProcessingProvider).history;
});

final processingStatisticsProvider = Provider<ProcessingStatistics?>((ref) {
  return ref.watch(constellationProcessingProvider).statistics;
});

final processingErrorProvider = Provider<String?>((ref) {
  return ref.watch(constellationProcessingProvider).error;
});

final canProcessProvider = Provider<bool>((ref) {
  return ref.watch(constellationProcessingProvider).canProcess;
});

/// Actions for constellation processing
class ConstellationProcessingActions {
  static Future<void> startProcessing(
    WidgetRef ref,
    ImageEntity image, {
    ProcessingParameters? parameters,
  }) async {
    await ref
        .read(constellationProcessingProvider.notifier)
        .startProcessing(image, parameters: parameters);
  }

  static Future<void> cancelProcessing(WidgetRef ref) async {
    await ref.read(constellationProcessingProvider.notifier).cancelProcessing();
  }

  static Future<void> loadHistory(WidgetRef ref, {int page = 0}) async {
    await ref
        .read(constellationProcessingProvider.notifier)
        .loadHistory(page: page);
  }

  static Future<void> deleteResult(WidgetRef ref, String resultId) async {
    await ref
        .read(constellationProcessingProvider.notifier)
        .deleteResult(resultId);
  }

  static Future<void> clearHistory(WidgetRef ref) async {
    await ref.read(constellationProcessingProvider.notifier).clearHistory();
  }

  static void reset(WidgetRef ref) {
    ref.read(constellationProcessingProvider.notifier).reset();
  }

  static void clearError(WidgetRef ref) {
    ref.read(constellationProcessingProvider.notifier).clearError();
  }
}
