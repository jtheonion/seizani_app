import '../entities/image_entity.dart';
import '../entities/constellation_entity.dart';
import '../repositories/image_repository.dart';
import '../repositories/storage_repository.dart';

/// Use case for saving and sharing processed constellation images
class ImageSaveUseCase {
  final ImageRepository _imageRepository;
  final StorageRepository _storageRepository;

  const ImageSaveUseCase(this._imageRepository, this._storageRepository);

  /// Save constellation image to device gallery
  Future<SaveResult> saveToGallery(
    ConstellationEntity constellation, {
    String? customFileName,
    SaveOptions? options,
  }) async {
    try {
      // Generate filename if not provided
      final fileName = customFileName ?? _generateFileName(constellation);

      // Create image entity from constellation
      final imageEntity = ImageEntity(
        id: constellation.id,
        path: '', // Will be set by repository
        bytes: constellation.renderedImageBytes,
        width: constellation.width,
        height: constellation.height,
        createdAt: constellation.createdAt,
        metadata: {
          'type': 'constellation',
          'originalImageId': constellation.originalImageId,
          'pointCount': constellation.points.length,
          'lineCount': constellation.lines.length,
        },
      );

      // Save to gallery
      final success = await _imageRepository.saveToGallery(
        imageEntity,
        fileName: fileName,
      );

      if (!success) {
        return const SaveResult.error('ギャラリーへの保存に失敗しました');
      }

      // Update save statistics
      await _updateSaveStatistics(constellation);

      return SaveResult.success(fileName);
    } catch (e) {
      return SaveResult.error('保存中にエラーが発生しました: $e');
    }
  }

  /// Get save statistics
  Future<SaveStatistics> getSaveStatistics() async {
    try {
      final stats = await _storageRepository.loadUserPreferences();
      if (stats != null && stats.containsKey('saveStats')) {
        return SaveStatistics.fromJson(stats['saveStats']);
      }
      return const SaveStatistics();
    } catch (e) {
      return const SaveStatistics();
    }
  }

  /// Check if we have permission to save to gallery
  Future<bool> checkSavePermission() async {
    try {
      // This would typically check device permissions
      // For now, we'll assume permission is granted
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get available save formats
  List<String> getAvailableSaveFormats() {
    return ['PNG', 'JPEG'];
  }

  /// Generate unique filename for constellation
  String _generateFileName(ConstellationEntity constellation) {
    final timestamp = constellation.createdAt.millisecondsSinceEpoch;
    final shortId = constellation.id.substring(0, 8);
    return 'seizani_constellation_${shortId}_$timestamp.png';
  }

  /// Update save statistics
  Future<void> _updateSaveStatistics(ConstellationEntity constellation) async {
    try {
      final currentStats = await getSaveStatistics();
      final updatedStats = currentStats.copyWith(
        totalSaves: currentStats.totalSaves + 1,
        lastSavedAt: DateTime.now(),
      );

      final preferences = await _storageRepository.loadUserPreferences() ?? {};
      preferences['saveStats'] = updatedStats.toJson();
      await _storageRepository.saveUserPreferences(preferences);
    } catch (e) {
      // Silently fail - statistics are not critical
    }
  }
}

/// Options for saving images
class SaveOptions {
  final String format; // 'PNG', 'JPEG'
  final int quality; // 0-100 for JPEG
  final bool includeMetadata;
  final bool addWatermark;

  const SaveOptions({
    this.format = 'PNG',
    this.quality = 90,
    this.includeMetadata = true,
    this.addWatermark = false,
  });
}

/// Result of save operation
class SaveResult {
  final String? fileName;
  final String? error;
  final bool isSuccess;

  const SaveResult.success(String fileName)
    : fileName = fileName,
      error = null,
      isSuccess = true;

  const SaveResult.error(String error)
    : fileName = null,
      error = error,
      isSuccess = false;
}

/// Statistics for save operations
class SaveStatistics {
  final int totalSaves;
  final DateTime? lastSavedAt;
  final Map<String, int> formatCounts; // Format -> count

  const SaveStatistics({
    this.totalSaves = 0,
    this.lastSavedAt,
    this.formatCounts = const {},
  });

  SaveStatistics copyWith({
    int? totalSaves,
    DateTime? lastSavedAt,
    Map<String, int>? formatCounts,
  }) {
    return SaveStatistics(
      totalSaves: totalSaves ?? this.totalSaves,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      formatCounts: formatCounts ?? this.formatCounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSaves': totalSaves,
      'lastSavedAt': lastSavedAt?.toIso8601String(),
      'formatCounts': formatCounts,
    };
  }

  factory SaveStatistics.fromJson(Map<String, dynamic> json) {
    return SaveStatistics(
      totalSaves: (json['totalSaves'] as int?) ?? 0,
      lastSavedAt: json['lastSavedAt'] != null
          ? DateTime.parse(json['lastSavedAt'] as String)
          : null,
      formatCounts: Map<String, int>.from(json['formatCounts'] ?? {}),
    );
  }
}
