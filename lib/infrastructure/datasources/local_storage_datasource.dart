import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local data source for storage operations using SharedPreferences
class LocalStorageDataSource {
  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure preferences are initialized
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  /// Save string data
  Future<void> saveString(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  /// Load string data
  Future<String?> loadString(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  }

  /// Save integer data
  Future<void> saveInt(String key, int value) async {
    final prefs = await _getPrefs();
    await prefs.setInt(key, value);
  }

  /// Load integer data
  Future<int?> loadInt(String key) async {
    final prefs = await _getPrefs();
    return prefs.getInt(key);
  }

  /// Save double data
  Future<void> saveDouble(String key, double value) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(key, value);
  }

  /// Load double data
  Future<double?> loadDouble(String key) async {
    final prefs = await _getPrefs();
    return prefs.getDouble(key);
  }

  /// Save boolean data
  Future<void> saveBool(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

  /// Load boolean data
  Future<bool?> loadBool(String key) async {
    final prefs = await _getPrefs();
    return prefs.getBool(key);
  }

  /// Save JSON data
  Future<void> saveJson(String key, Map<String, dynamic> data) async {
    final jsonString = json.encode(data);
    await saveString(key, jsonString);
  }

  /// Load JSON data
  Future<Map<String, dynamic>?> loadJson(String key) async {
    final jsonString = await loadString(key);
    if (jsonString == null) return null;

    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw StorageDataSourceException('JSON decode failed for key $key: $e');
    }
  }

  /// Save list of strings
  Future<void> saveStringList(String key, List<String> values) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(key, values);
  }

  /// Load list of strings
  Future<List<String>?> loadStringList(String key) async {
    final prefs = await _getPrefs();
    return prefs.getStringList(key);
  }

  /// Save list of JSON objects
  Future<void> saveJsonList(String key, List<Map<String, dynamic>> data) async {
    final jsonList = data.map((item) => json.encode(item)).toList();
    await saveStringList(key, jsonList);
  }

  /// Load list of JSON objects
  Future<List<Map<String, dynamic>>> loadJsonList(String key) async {
    final jsonStringList = await loadStringList(key);
    if (jsonStringList == null) return [];

    try {
      return jsonStringList
          .map((jsonString) => json.decode(jsonString) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw StorageDataSourceException(
        'JSON list decode failed for key $key: $e',
      );
    }
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    final prefs = await _getPrefs();
    return prefs.containsKey(key);
  }

  /// Remove key
  Future<void> removeKey(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  /// Get all keys
  Future<Set<String>> getAllKeys() async {
    final prefs = await _getPrefs();
    return prefs.getKeys();
  }

  /// Clear all data
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }

  /// Get storage size information
  Future<StorageInfo> getStorageInfo() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();

    final keySizes = <String, int>{};
    int totalSize = 0;

    for (final key in keys) {
      final value = prefs.get(key);
      int size = 0;

      if (value is String) {
        size = value.length * 2; // Approximate UTF-16 size
      } else if (value is List<String>) {
        size = value.fold(0, (sum, str) => sum + (str.length * 2));
      } else if (value is int) {
        size = 8; // 64-bit integer
      } else if (value is double) {
        size = 8; // 64-bit double
      } else if (value is bool) {
        size = 1; // Boolean
      }

      keySizes[key] = size;
      totalSize += size;
    }

    return StorageInfo(
      totalKeys: keys.length,
      keySizes: keySizes,
      totalSize: totalSize,
    );
  }

  /// Backup all data to JSON
  Future<Map<String, dynamic>> backupData() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    final backup = <String, dynamic>{};

    for (final key in keys) {
      final value = prefs.get(key);
      backup[key] = value;
    }

    return backup;
  }

  /// Restore data from backup
  Future<void> restoreData(Map<String, dynamic> backup) async {
    final prefs = await _getPrefs();

    // Clear existing data
    await prefs.clear();

    // Restore backup
    for (final entry in backup.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    }
  }
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
  double get totalSizeInKB => totalSize / 1024;
}

/// Exception for storage data source operations
class StorageDataSourceException implements Exception {
  final String message;
  const StorageDataSourceException(this.message);

  @override
  String toString() => 'StorageDataSourceException: $message';
}
