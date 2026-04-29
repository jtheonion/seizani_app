import '../entities/image_entity.dart';
import '../entities/processing_result.dart';
import '../repositories/processing_repository.dart';
import '../repositories/storage_repository.dart';

/// Use case for constellation processing operations
class ConstellationProcessingUseCase {
  final ProcessingRepository _processingRepository;
  final StorageRepository _storageRepository;

  const ConstellationProcessingUseCase(
    this._processingRepository,
    this._storageRepository,
  );

  /// Process image to create constellation pattern
  Stream<ProcessingResult> processImage(
    ImageEntity image, {
    ProcessingParameters? customParameters,
  }) async* {
    try {
      // Load processing parameters (custom or default)
      final parameters =
          customParameters ?? await _getDefaultProcessingParameters();

      // Start processing stream
      await for (final result in _processingRepository.processImage(
        image,
        parameters: parameters,
      )) {
        // Save intermediate results for recovery
        if (result.progress > 0.5) {
          await _saveProcessingProgress(result);
        }

        // Save completed results
        if (result.isCompleted && result.constellation != null) {
          await _processingRepository.saveProcessingResult(result);
          await _updateProcessingStatistics();
        }

        yield result;
      }
    } catch (e) {
      yield ProcessingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImage: image,
        status: ProcessingStatus.failed,
        errorMessage: '処理中にエラーが発生しました: $e',
        progress: 0.0,
        currentStep: 'エラー',
        startTime: DateTime.now(),
      );
    }
  }

  /// Cancel ongoing processing
  Future<bool> cancelProcessing(String processingId) async {
    try {
      await _processingRepository.cancelProcessing(processingId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get processing history with filtering and pagination
  Future<ProcessingHistoryResult> getProcessingHistory({
    int page = 0,
    int pageSize = 20,
    ProcessingHistoryFilter? filter,
  }) async {
    try {
      final offset = page * pageSize;
      final allResults = await _processingRepository.getProcessingHistory(
        limit: pageSize,
        offset: offset,
      );

      List<ProcessingResult> filteredResults = allResults;

      // Apply filters
      if (filter != null) {
        filteredResults = _applyFilters(allResults, filter);
      }

      return ProcessingHistoryResult.success(
        results: filteredResults,
        totalCount: filteredResults.length,
        currentPage: page,
        hasMore: filteredResults.length == pageSize,
      );
    } catch (e) {
      return ProcessingHistoryResult.error('履歴の取得に失敗しました: $e');
    }
  }

  /// Delete processing result
  Future<bool> deleteProcessingResult(String resultId) async {
    try {
      await _processingRepository.deleteProcessingResult(resultId);
      await _updateProcessingStatistics();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all processing history
  Future<bool> clearProcessingHistory() async {
    try {
      await _processingRepository.clearProcessingHistory();
      await _updateProcessingStatistics();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get processing statistics
  Future<ProcessingStatistics> getProcessingStatistics() async {
    return await _processingRepository.getProcessingStatistics();
  }

  /// Save custom processing parameters as default
  Future<bool> saveDefaultProcessingParameters(
    ProcessingParameters parameters,
  ) async {
    try {
      await _storageRepository.saveDefaultProcessingParameters(
        parameters.toJson(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load default processing parameters
  Future<ProcessingParameters> _getDefaultProcessingParameters() async {
    try {
      final savedParams = await _storageRepository
          .loadDefaultProcessingParameters();
      if (savedParams != null) {
        return ProcessingParameters.fromJson(savedParams);
      }
      return const ProcessingParameters(); // Return default values
    } catch (e) {
      return const ProcessingParameters();
    }
  }

  /// Save processing progress for recovery
  Future<void> _saveProcessingProgress(ProcessingResult result) async {
    try {
      // Save to temporary storage for potential recovery
      // This could be extended to save to a recovery storage
      // For now, we'll just ensure the processing state is maintained
    } catch (e) {
      // Silently fail - progress saving is not critical
    }
  }

  /// Update processing statistics after operations
  Future<void> _updateProcessingStatistics() async {
    try {
      // Statistics are automatically calculated by the repository
      // This method is a placeholder for any additional statistics updates
    } catch (e) {
      // Silently fail - statistics updates are not critical
    }
  }

  /// Apply filters to processing history
  List<ProcessingResult> _applyFilters(
    List<ProcessingResult> results,
    ProcessingHistoryFilter filter,
  ) {
    return results.where((result) {
      // Filter by status
      if (filter.status != null && result.status != filter.status) {
        return false;
      }

      // Filter by date range
      if (filter.startDate != null &&
          result.startTime.isBefore(filter.startDate!)) {
        return false;
      }

      if (filter.endDate != null && result.startTime.isAfter(filter.endDate!)) {
        return false;
      }

      // Filter by completion status
      if (filter.onlyCompleted == true && !result.isCompleted) {
        return false;
      }

      return true;
    }).toList();
  }
}

/// Filter for processing history
class ProcessingHistoryFilter {
  final ProcessingStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? onlyCompleted;

  const ProcessingHistoryFilter({
    this.status,
    this.startDate,
    this.endDate,
    this.onlyCompleted,
  });
}

/// Result of processing history operation
class ProcessingHistoryResult {
  final List<ProcessingResult>? results;
  final String? error;
  final int totalCount;
  final int currentPage;
  final bool hasMore;
  final bool isSuccess;

  const ProcessingHistoryResult.success({
    required List<ProcessingResult> results,
    required int totalCount,
    required int currentPage,
    required bool hasMore,
  }) : results = results,
       error = null,
       totalCount = totalCount,
       currentPage = currentPage,
       hasMore = hasMore,
       isSuccess = true;

  const ProcessingHistoryResult.error(String error)
    : results = null,
      error = error,
      totalCount = 0,
      currentPage = 0,
      hasMore = false,
      isSuccess = false;
}
