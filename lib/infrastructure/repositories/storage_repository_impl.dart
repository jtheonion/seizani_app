import 'dart:convert';
import '../../domain/entities/line_art_entity.dart';
import '../../domain/repositories/storage_repository.dart';
import '../datasources/local_storage_datasource.dart' as datasource;

/// Implementation of StorageRepository using local data sources
class StorageRepositoryImpl implements StorageRepository {
  final datasource.LocalStorageDataSource _localStorageDataSource;

  // Storage keys
  static const String _appSettingsKey = 'app_settings';
  static const String _processingParametersKey = 'processing_parameters';
  static const String _userPreferencesKey = 'user_preferences';
  static const String _processingHistoryKey = 'processing_history';
  static const String _lineArtsKey = 'line_arts';

  const StorageRepositoryImpl({
    required datasource.LocalStorageDataSource localStorageDataSource,
  }) : _localStorageDataSource = localStorageDataSource;

  @override
  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      await _localStorageDataSource.saveJson(_appSettingsKey, settings);
    } catch (e) {
      throw StorageRepositoryException('アプリ設定の保存に失敗: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> loadAppSettings() async {
    try {
      return await _localStorageDataSource.loadJson(_appSettingsKey);
    } catch (e) {
      throw StorageRepositoryException('アプリ設定の読み込みに失敗: $e');
    }
  }

  @override
  Future<void> saveDefaultProcessingParameters(
    Map<String, dynamic> parameters,
  ) async {
    try {
      await _localStorageDataSource.saveJson(
        _processingParametersKey,
        parameters,
      );
    } catch (e) {
      throw StorageRepositoryException('処理パラメータの保存に失敗: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> loadDefaultProcessingParameters() async {
    try {
      return await _localStorageDataSource.loadJson(_processingParametersKey);
    } catch (e) {
      throw StorageRepositoryException('処理パラメータの読み込みに失敗: $e');
    }
  }

  @override
  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      await _localStorageDataSource.saveJson(_userPreferencesKey, preferences);
    } catch (e) {
      throw StorageRepositoryException('ユーザー設定の保存に失敗: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> loadUserPreferences() async {
    try {
      return await _localStorageDataSource.loadJson(_userPreferencesKey);
    } catch (e) {
      throw StorageRepositoryException('ユーザー設定の読み込みに失敗: $e');
    }
  }

  @override
  Future<void> saveProcessingHistoryMetadata(
    List<Map<String, dynamic>> history,
  ) async {
    try {
      await _localStorageDataSource.saveJsonList(
        _processingHistoryKey,
        history,
      );
    } catch (e) {
      throw StorageRepositoryException('処理履歴の保存に失敗: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadProcessingHistoryMetadata() async {
    try {
      return await _localStorageDataSource.loadJsonList(_processingHistoryKey);
    } catch (e) {
      throw StorageRepositoryException('処理履歴の読み込みに失敗: $e');
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      await _localStorageDataSource.clear();
    } catch (e) {
      throw StorageRepositoryException('データクリアに失敗: $e');
    }
  }

  @override
  Future<StorageInfo> getStorageInfo() async {
    try {
      final info = await _localStorageDataSource.getStorageInfo();
      return StorageInfo(
        totalKeys: info.totalKeys,
        keySizes: info.keySizes,
        totalSize: info.totalSize,
      );
    } catch (e) {
      throw StorageRepositoryException('ストレージ情報の取得に失敗: $e');
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _localStorageDataSource.containsKey(key);
    } catch (e) {
      throw StorageRepositoryException('キー存在確認に失敗: $e');
    }
  }

  @override
  Future<void> removeKey(String key) async {
    try {
      await _localStorageDataSource.removeKey(key);
    } catch (e) {
      throw StorageRepositoryException('キー削除に失敗: $e');
    }
  }

  @override
  Future<List<String>> getAllKeys() async {
    try {
      final keys = await _localStorageDataSource.getAllKeys();
      return keys.toList();
    } catch (e) {
      throw StorageRepositoryException('全キー取得に失敗: $e');
    }
  }

  /// Save specific data types with convenience methods

  /// Save theme settings
  Future<void> saveThemeSettings(Map<String, dynamic> themeSettings) async {
    const key = 'theme_settings';
    await _localStorageDataSource.saveJson(key, themeSettings);
  }

  /// Load theme settings
  Future<Map<String, dynamic>?> loadThemeSettings() async {
    const key = 'theme_settings';
    return await _localStorageDataSource.loadJson(key);
  }

  /// Save onboarding completion status
  Future<void> saveOnboardingCompleted(bool completed) async {
    const key = 'onboarding_completed';
    await _localStorageDataSource.saveBool(key, completed);
  }

  /// Load onboarding completion status
  Future<bool> loadOnboardingCompleted() async {
    const key = 'onboarding_completed';
    return await _localStorageDataSource.loadBool(key) ?? false;
  }

  /// Save usage statistics
  Future<void> saveUsageStatistics(Map<String, dynamic> stats) async {
    const key = 'usage_statistics';
    await _localStorageDataSource.saveJson(key, stats);
  }

  /// Load usage statistics
  Future<Map<String, dynamic>?> loadUsageStatistics() async {
    const key = 'usage_statistics';
    return await _localStorageDataSource.loadJson(key);
  }

  /// Create backup of all data
  Future<Map<String, dynamic>> createBackup() async {
    try {
      return await _localStorageDataSource.backupData();
    } catch (e) {
      throw StorageRepositoryException('バックアップ作成に失敗: $e');
    }
  }

  /// Restore data from backup
  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    try {
      await _localStorageDataSource.restoreData(backup);
    } catch (e) {
      throw StorageRepositoryException('バックアップ復元に失敗: $e');
    }
  }

  @override
  Future<void> saveAppVersion(String version) async {
    const key = 'app_version';
    try {
      await _localStorageDataSource.saveString(key, version);
    } catch (e) {
      throw StorageRepositoryException('アプリバージョン保存に失敗: $e');
    }
  }

  @override
  Future<String?> loadAppVersion() async {
    const key = 'app_version';
    try {
      return await _localStorageDataSource.loadString(key);
    } catch (e) {
      throw StorageRepositoryException('アプリバージョン読み込みに失敗: $e');
    }
  }

  @override
  Future<void> saveLineArt(LineArtEntity lineArt) async {
    try {
      // Load existing line arts
      final existingLineArts = await _loadLineArtsList();

      // Create line art data map
      final lineArtData = _mapFromLineArt(lineArt);

      // Add or update
      final existingIndex = existingLineArts.indexWhere(
        (data) => data['id'] == lineArt.id,
      );
      if (existingIndex >= 0) {
        existingLineArts[existingIndex] = lineArtData;
      } else {
        existingLineArts.add(lineArtData);
      }

      // Save updated list
      await _localStorageDataSource.saveJsonList(
        _lineArtsKey,
        existingLineArts,
      );
    } catch (e) {
      throw StorageRepositoryException('線画保存に失敗: $e');
    }
  }

  @override
  Future<LineArtEntity?> loadLineArt(String id) async {
    try {
      final lineArtsList = await _loadLineArtsList();
      final lineArtData = lineArtsList.firstWhere(
        (data) => data['id'] == id,
        orElse: () => <String, dynamic>{},
      );

      if (lineArtData.isEmpty) return null;

      return _mapToLineArt(lineArtData);
    } catch (e) {
      throw StorageRepositoryException('線画読み込みに失敗: $e');
    }
  }

  @override
  Future<List<LineArtEntity>> getAllLineArts() async {
    try {
      final lineArtsList = await _loadLineArtsList();
      return lineArtsList.map((data) => _mapToLineArt(data)).toList();
    } catch (e) {
      throw StorageRepositoryException('線画一覧取得に失敗: $e');
    }
  }

  @override
  Future<void> deleteLineArt(String id) async {
    try {
      final existingLineArts = await _loadLineArtsList();
      existingLineArts.removeWhere((data) => data['id'] == id);
      await _localStorageDataSource.saveJsonList(
        _lineArtsKey,
        existingLineArts,
      );
    } catch (e) {
      throw StorageRepositoryException('線画削除に失敗: $e');
    }
  }

  /// Load line arts list from storage
  Future<List<Map<String, dynamic>>> _loadLineArtsList() async {
    try {
      return await _localStorageDataSource.loadJsonList(_lineArtsKey);
    } catch (e) {
      return [];
    }
  }

  /// Map LineArtEntity to JSON
  Map<String, dynamic> _mapFromLineArt(LineArtEntity lineArt) {
    return {
      'id': lineArt.id,
      'originalImageId': lineArt.originalImageId,
      'lineArtImageBytes': base64Encode(lineArt.lineArtImageBytes),
      'width': lineArt.width,
      'height': lineArt.height,
      'createdAt': lineArt.createdAt.toIso8601String(),
      'metadata': lineArt.metadata.toJson(),
    };
  }

  /// Map JSON to LineArtEntity
  LineArtEntity _mapToLineArt(Map<String, dynamic> data) {
    return LineArtEntity(
      id: data['id'] ?? '',
      originalImageId: data['originalImageId'] ?? '',
      lineArtImageBytes: base64Decode(data['lineArtImageBytes'] ?? ''),
      width: data['width'] ?? 0,
      height: data['height'] ?? 0,
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      metadata: LineArtMetadata.fromJson(data['metadata'] ?? {}),
    );
  }
}

/// Exception for storage repository operations
class StorageRepositoryException implements Exception {
  final String message;
  const StorageRepositoryException(this.message);

  @override
  String toString() => 'StorageRepositoryException: $message';
}
