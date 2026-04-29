import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/constellation_entity.dart';
import '../../domain/entities/line_art_decoration_entity.dart';
import '../../domain/entities/line_art_entity.dart';
import '../../domain/entities/processing_result.dart';
import '../../domain/repositories/processing_repository.dart';
import '../services/constellation_processor.dart';
import '../services/line_art_star_decorator.dart';
import '../services/line_art_processor.dart';
import '../datasources/local_storage_datasource.dart';

/// Implementation of ProcessingRepository using local processing
class ProcessingRepositoryImpl implements ProcessingRepository {
  final LocalStorageDataSource _storageDataSource;
  final Map<String, StreamController<ProcessingResult>> _activeProcessing = {};

  // Storage keys
  static const String _historyKey = 'processing_results';
  static const String _statisticsKey = 'processing_statistics';

  ProcessingRepositoryImpl({required LocalStorageDataSource storageDataSource})
    : _storageDataSource = storageDataSource;

  @override
  Stream<ProcessingResult> processImage(
    ImageEntity image, {
    ProcessingParameters? parameters,
  }) async* {
    final processingId = DateTime.now().millisecondsSinceEpoch.toString();
    final controller = StreamController<ProcessingResult>();
    final effectiveParameters = parameters ?? const ProcessingParameters();

    _activeProcessing[processingId] = controller;

    try {
      // Initial state
      var result = ProcessingResult(
        id: processingId,
        originalImage: image,
        status: ProcessingStatus.processing,
        progress: 0.0,
        currentStep: '処理を開始しています...',
        startTime: DateTime.now(),
      );

      yield result;

      // Step 1: Preprocessing
      result = result.copyWith(progress: 0.2, currentStep: '画像の前処理中...');
      yield result;

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate processing time

      // Step 2: Edge detection
      result = result.copyWith(progress: 0.4, currentStep: 'エッジを検出中...');
      yield result;

      await Future.delayed(const Duration(milliseconds: 800));

      // Step 3: Feature extraction
      result = result.copyWith(progress: 0.6, currentStep: '特徴点を抽出中...');
      yield result;

      await Future.delayed(const Duration(milliseconds: 600));

      // Step 4: Constellation generation
      result = result.copyWith(progress: 0.8, currentStep: '星座パターンを生成中...');
      yield result;

      await Future.delayed(const Duration(milliseconds: 700));

      // Process the actual constellation
      print('🎯 [CONSOLE] ConstellationProcessor.processImage開始...');
      if (kDebugMode) debugPrint('Starting constellation processing');
      final constellation = await ConstellationProcessor.processImage(
        image,
        effectiveParameters,
      );
      print('✨ [CONSOLE] Constellation生成完了: ${constellation.id}');
      if (kDebugMode)
        debugPrint('Constellation processing completed: ${constellation.id}');
      print(
        '🖼️ [CONSOLE] 星座画像バイト数: ${constellation.renderedImageBytes.length} bytes',
      );

      // Step 5: Finalization
      result = result.copyWith(
        constellation: constellation,
        status: ProcessingStatus.completed,
        progress: 1.0,
        currentStep: '処理完了',
        endTime: DateTime.now(),
      );
      print(
        '🎊 [CONSOLE] 処理結果をyield: status=${result.status}, hasConstellation=${result.constellation != null}',
      );
      yield result;

      // Save to history
      await saveProcessingResult(result);
    } catch (e) {
      final errorResult = ProcessingResult(
        id: processingId,
        originalImage: image,
        status: ProcessingStatus.failed,
        errorMessage: e.toString(),
        progress: 0.0,
        currentStep: 'エラーが発生しました',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      yield errorResult;
    } finally {
      _activeProcessing.remove(processingId);
      controller.close();
    }
  }

  @override
  Future<void> cancelProcessing(String processingId) async {
    final controller = _activeProcessing[processingId];
    if (controller != null) {
      controller.close();
      _activeProcessing.remove(processingId);
    }
  }

  @override
  Future<List<ProcessingResult>> getProcessingHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final historyData = await _storageDataSource.loadJsonList(_historyKey);

      // Convert to ProcessingResult objects
      final results = historyData
          .map((data) => _mapToProcessingResult(data))
          .toList();

      // Sort by start time (newest first)
      results.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Apply pagination
      final startIndex = offset;
      final endIndex = (startIndex + limit).clamp(0, results.length);

      return results.sublist(startIndex, endIndex);
    } catch (e) {
      throw ProcessingRepositoryException('履歴取得に失敗: $e');
    }
  }

  @override
  Future<void> saveProcessingResult(ProcessingResult result) async {
    try {
      final currentHistory = await _storageDataSource.loadJsonList(_historyKey);

      // Add new result to history
      currentHistory.insert(0, _mapFromProcessingResult(result));

      // Keep only last 100 results
      if (currentHistory.length > 100) {
        currentHistory.removeRange(100, currentHistory.length);
      }

      await _storageDataSource.saveJsonList(_historyKey, currentHistory);

      // Update statistics
      await _updateStatistics(result);
    } catch (e) {
      throw ProcessingRepositoryException('結果保存に失敗: $e');
    }
  }

  @override
  Future<void> deleteProcessingResult(String resultId) async {
    try {
      final currentHistory = await _storageDataSource.loadJsonList(_historyKey);
      currentHistory.removeWhere((data) => data['id'] == resultId);
      await _storageDataSource.saveJsonList(_historyKey, currentHistory);
    } catch (e) {
      throw ProcessingRepositoryException('結果削除に失敗: $e');
    }
  }

  @override
  Future<ProcessingResult?> getProcessingResult(String resultId) async {
    try {
      final history = await getProcessingHistory();
      return history.cast<ProcessingResult?>().firstWhere(
        (result) => result?.id == resultId,
        orElse: () => null,
      );
    } catch (e) {
      throw ProcessingRepositoryException('結果取得に失敗: $e');
    }
  }

  @override
  Future<void> clearProcessingHistory() async {
    try {
      await _storageDataSource.removeKey(_historyKey);
      await _storageDataSource.removeKey(_statisticsKey);
    } catch (e) {
      throw ProcessingRepositoryException('履歴削除に失敗: $e');
    }
  }

  @override
  Future<ProcessingStatistics> getProcessingStatistics() async {
    try {
      final statsData = await _storageDataSource.loadJson(_statisticsKey);
      if (statsData == null) {
        return ProcessingStatistics(
          totalProcessed: 0,
          successfulProcessing: 0,
          failedProcessing: 0,
          averageProcessingTime: Duration.zero,
          lastProcessedAt: DateTime.now(),
        );
      }

      return ProcessingStatistics(
        totalProcessed: statsData['totalProcessed'] ?? 0,
        successfulProcessing: statsData['successfulProcessing'] ?? 0,
        failedProcessing: statsData['failedProcessing'] ?? 0,
        averageProcessingTime: Duration(
          milliseconds: statsData['averageProcessingTimeMs'] ?? 0,
        ),
        lastProcessedAt: DateTime.parse(
          statsData['lastProcessedAt'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      throw ProcessingRepositoryException('統計取得に失敗: $e');
    }
  }

  /// Update processing statistics
  Future<void> _updateStatistics(ProcessingResult result) async {
    try {
      final currentStats = await getProcessingStatistics();

      final newTotalProcessed = currentStats.totalProcessed + 1;
      final newSuccessful =
          currentStats.successfulProcessing + (result.isCompleted ? 1 : 0);
      final newFailed =
          currentStats.failedProcessing + (result.isFailed ? 1 : 0);

      // Calculate new average processing time
      Duration newAverageTime = currentStats.averageProcessingTime;
      if (result.processingDuration != null) {
        final totalMs =
            currentStats.averageProcessingTime.inMilliseconds *
            currentStats.totalProcessed;
        final newTotalMs = totalMs + result.processingDuration!.inMilliseconds;
        newAverageTime = Duration(
          milliseconds: (newTotalMs / newTotalProcessed).round(),
        );
      }

      final statsData = {
        'totalProcessed': newTotalProcessed,
        'successfulProcessing': newSuccessful,
        'failedProcessing': newFailed,
        'averageProcessingTimeMs': newAverageTime.inMilliseconds,
        'lastProcessedAt':
            result.endTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      };

      await _storageDataSource.saveJson(_statisticsKey, statsData);
    } catch (e) {
      // Silently fail - statistics are not critical
    }
  }

  /// Map ProcessingResult to JSON
  Map<String, dynamic> _mapFromProcessingResult(ProcessingResult result) {
    return {
      'id': result.id,
      'originalImageId': result.originalImage.id,
      'constellationId': result.constellation?.id,
      'status': result.status.name,
      'errorMessage': result.errorMessage,
      'progress': result.progress,
      'currentStep': result.currentStep,
      'startTime': result.startTime.toIso8601String(),
      'endTime': result.endTime?.toIso8601String(),
    };
  }

  @override
  Future<LineArtEntity> processImageToLineArt(
    ImageEntity image, {
    LineArtParameters? parameters,
  }) async {
    try {
      final effectiveParameters = parameters ?? const LineArtParameters();

      debugPrint(
        '🎨 [DEBUG] ProcessingRepositoryImpl.processImageToLineArt開始 - 画像: ${image.id}',
      );

      final lineArt = await LineArtProcessor.processToLineArt(
        image,
        effectiveParameters,
      );

      debugPrint(
        '✅ [DEBUG] ProcessingRepositoryImpl.processImageToLineArt完了 - 線画: ${lineArt.id}',
      );

      return lineArt;
    } catch (e) {
      debugPrint(
        '💥 [ERROR] ProcessingRepositoryImpl.processImageToLineArt失敗: $e',
      );
      throw ProcessingRepositoryException('線画変換処理に失敗しました: $e');
    }
  }

  @override
  Future<ConstellationEntity> processLineArt(
    LineArtEntity lineArt, {
    ProcessingParameters? parameters,
  }) async {
    try {
      final effectiveParameters = parameters ?? const ProcessingParameters();

      debugPrint(
        '🌟 [DEBUG] ProcessingRepositoryImpl.processLineArt開始 - 線画: ${lineArt.id}',
      );

      final constellation = await ConstellationProcessor.processImage(
        lineArt,
        effectiveParameters,
      );

      debugPrint(
        '✅ [DEBUG] ProcessingRepositoryImpl.processLineArt完了 - 星座: ${constellation.id}',
      );

      return constellation;
    } catch (e) {
      debugPrint('💥 [ERROR] ProcessingRepositoryImpl.processLineArt失敗: $e');
      throw ProcessingRepositoryException('星座変換処理に失敗しました: $e');
    }
  }

  @override
  Future<LineArtDecorationEntity> decorateLineArt(
    LineArtEntity lineArt, {
    StarDecorationParams? params,
  }) async {
    try {
      final effectiveParams = params ?? const StarDecorationParams();

      debugPrint(
        '🌟 [DEBUG] ProcessingRepositoryImpl.decorateLineArt開始 - 線画: ${lineArt.id}',
      );

      final output = await LineArtStarDecorator.decorate(
        lineArt,
        effectiveParams,
      );

      final decoration = LineArtDecorationEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceLineArtId: lineArt.id,
        decoratedImageBytes: output.decoratedBytes,
        width: output.width,
        height: output.height,
        createdAt: DateTime.now(),
        metadata: LineArtDecorationMetadata(
          processingTime: output.processingTime,
          algorithmVersion: LineArtStarDecorator.algorithmVersion,
          starCount: output.starCount,
          maskInverted: output.maskInverted,
          parameters: effectiveParams,
        ),
      );

      debugPrint(
        '✅ [DEBUG] ProcessingRepositoryImpl.decorateLineArt完了 - 星: ${output.starCount}',
      );

      return decoration;
    } catch (e) {
      debugPrint('💥 [ERROR] ProcessingRepositoryImpl.decorateLineArt失敗: $e');
      throw ProcessingRepositoryException('星装飾処理に失敗しました: $e');
    }
  }

  /// Map JSON to ProcessingResult
  ProcessingResult _mapToProcessingResult(Map<String, dynamic> data) {
    // Create a minimal ImageEntity for the original image
    final originalImage = ImageEntity(
      id: data['originalImageId'] ?? '',
      path: '',
      width: 0,
      height: 0,
      createdAt: DateTime.now(),
    );

    return ProcessingResult(
      id: data['id'] ?? '',
      originalImage: originalImage,
      constellation: null, // Would need to load separately if needed
      status: ProcessingStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => ProcessingStatus.failed,
      ),
      errorMessage: data['errorMessage'],
      progress: (data['progress'] ?? 0.0).toDouble(),
      currentStep: data['currentStep'] ?? '',
      startTime: DateTime.parse(
        data['startTime'] ?? DateTime.now().toIso8601String(),
      ),
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
    );
  }
}

/// Exception for processing repository operations
class ProcessingRepositoryException implements Exception {
  final String message;
  const ProcessingRepositoryException(this.message);

  @override
  String toString() => 'ProcessingRepositoryException: $message';
}
