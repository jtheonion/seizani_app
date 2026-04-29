import '../entities/line_art_entity.dart';

/// Abstract repository for local storage operations
abstract class StorageRepository {
  /// Save app settings
  Future<void> saveAppSettings(Map<String, dynamic> settings);

  /// Load app settings
  Future<Map<String, dynamic>?> loadAppSettings();

  /// Save processing parameters as defaults
  Future<void> saveDefaultProcessingParameters(Map<String, dynamic> parameters);

  /// Load default processing parameters
  Future<Map<String, dynamic>?> loadDefaultProcessingParameters();

  /// Save user preferences
  Future<void> saveUserPreferences(Map<String, dynamic> preferences);

  /// Load user preferences
  Future<Map<String, dynamic>?> loadUserPreferences();

  /// Save line art result
  Future<void> saveLineArt(LineArtEntity lineArt);

  /// Load line art by ID
  Future<LineArtEntity?> loadLineArt(String id);

  /// Get all saved line arts
  Future<List<LineArtEntity>> getAllLineArts();

  /// Delete line art
  Future<void> deleteLineArt(String id);

  /// Save processing history metadata
  Future<void> saveProcessingHistoryMetadata(
    List<Map<String, dynamic>> history,
  );

  /// Load processing history metadata
  Future<List<Map<String, dynamic>>> loadProcessingHistoryMetadata();

  /// Clear all stored data
  Future<void> clearAllData();

  /// Get storage usage statistics
  Future<StorageInfo> getStorageInfo();

  /// Check if key exists
  Future<bool> containsKey(String key);

  /// Remove specific key
  Future<void> removeKey(String key);

  /// Get all keys
  Future<List<String>> getAllKeys();

  /// Save app version for migration tracking
  Future<void> saveAppVersion(String version);

  /// Load app version for migration tracking
  Future<String?> loadAppVersion();
}

/// Storage information
class StorageInfo {
  final int totalKeys;
  final Map<String, int> keySizes;
  final int totalSize;

  const StorageInfo({
    required this.totalKeys,
    required this.keySizes,
    required this.totalSize,
  });

  double get totalSizeInMB => totalSize / (1024 * 1024);
}
