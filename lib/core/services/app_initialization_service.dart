import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/dependencies.dart';

/// Service to handle app initialization
class AppInitializationService {
  final ProviderContainer container;

  AppInitializationService(this.container);

  /// Initialize the application
  Future<void> initialize() async {
    try {
      // Set initialization status to initializing
      container.read(initializationStatusProvider.notifier).state =
          InitializationStatus.initializing;

      // Step 1: Initialize storage
      await _initializeStorage();

      // Step 2: Load app configuration
      await _loadAppConfiguration();

      // Step 3: Initialize services
      await _initializeServices();

      // Step 4: Perform database migrations if needed
      await _performMigrations();

      // Step 5: Load user preferences
      await _loadUserPreferences();

      // Mark initialization as completed
      container.read(initializationStatusProvider.notifier).state =
          InitializationStatus.completed;

      _logSuccess('App initialization completed successfully');
    } catch (e, stackTrace) {
      container.read(initializationStatusProvider.notifier).state =
          InitializationStatus.failed;

      _logError('App initialization failed', e, stackTrace);
      rethrow;
    }
  }

  /// Initialize without updating state (for use in providers)
  Future<void> initializeWithoutStateUpdate() async {
    try {
      // Step 1: Initialize storage
      await _initializeStorage();

      // Step 2: Load app configuration
      await _loadAppConfiguration();

      // Step 3: Initialize services
      await _initializeServices();

      // Step 4: Perform database migrations if needed
      await _performMigrations();

      // Step 5: Load user preferences
      await _loadUserPreferences();

      _logSuccess('App initialization completed successfully');
    } catch (e, stackTrace) {
      _logError('App initialization failed', e, stackTrace);
      rethrow;
    }
  }

  /// Initialize local storage
  Future<void> _initializeStorage() async {
    _logInfo('Initializing storage...');

    final storageDataSource = container.read(localStorageDataSourceProvider);
    await storageDataSource.initialize();

    _logSuccess('Storage initialized');
  }

  /// Load app configuration
  Future<void> _loadAppConfiguration() async {
    _logInfo('Loading app configuration...');

    final storageRepo = container.read(storageRepositoryProvider);
    final appSettings = await storageRepo.loadAppSettings();

    if (appSettings == null) {
      // Create default app settings
      final defaultSettings = {
        'theme': 'dark',
        'language': 'ja',
        'enableAnalytics': false,
        'maxProcessingHistory': 100,
        'autoSave': true,
        'version': '1.0.0',
        'firstLaunch': true,
      };

      await storageRepo.saveAppSettings(defaultSettings);
      _logInfo('Created default app settings');
    } else {
      _logInfo('Loaded existing app settings');
    }

    _logSuccess('App configuration loaded');
  }

  /// Initialize various services
  Future<void> _initializeServices() async {
    _logInfo('Initializing services...');

    // Initialize image repository (cleanup temp files)
    final imageRepo = container.read(imageRepositoryProvider);
    await imageRepo.cleanupTempFiles();

    // Initialize error handler
    final errorHandler = container.read(errorHandlerProvider);
    errorHandler.logInfo('Services initialized');

    _logSuccess('Services initialized');
  }

  /// Perform database migrations
  Future<void> _performMigrations() async {
    _logInfo('Checking for database migrations...');

    final storageRepo = container.read(storageRepositoryProvider);
    final currentVersion = await storageRepo.loadAppVersion();
    const targetVersion = '1.0.0';

    if (currentVersion == null) {
      // First installation
      await storageRepo.saveAppVersion(targetVersion);
      _logInfo('First installation, set version to $targetVersion');
    } else if (currentVersion != targetVersion) {
      // Migration needed
      await _migrateFromVersion(currentVersion, targetVersion);
      await storageRepo.saveAppVersion(targetVersion);
      _logInfo('Migrated from $currentVersion to $targetVersion');
    } else {
      _logInfo('No migration needed, current version: $currentVersion');
    }

    _logSuccess('Database migrations completed');
  }

  /// Migrate from old version to new version
  Future<void> _migrateFromVersion(String fromVersion, String toVersion) async {
    _logInfo('Performing migration from $fromVersion to $toVersion');

    // Add migration logic here as needed
    // For now, this is a placeholder

    // Example migration:
    // if (fromVersion == '0.9.0' && toVersion == '1.0.0') {
    //   await _migrateToV1();
    // }
  }

  /// Load user preferences
  Future<void> _loadUserPreferences() async {
    _logInfo('Loading user preferences...');

    final storageRepo = container.read(storageRepositoryProvider);
    final preferences = await storageRepo.loadUserPreferences();

    if (preferences == null) {
      // Create default preferences
      final defaultPreferences = {
        'processingQuality': 'high',
        'autoSaveResults': true,
        'enableNotifications': true,
        'maxHistoryItems': 50,
        'compressionQuality': 90,
      };

      await storageRepo.saveUserPreferences(defaultPreferences);
      _logInfo('Created default user preferences');
    } else {
      _logInfo('Loaded existing user preferences');
    }

    _logSuccess('User preferences loaded');
  }

  /// Cleanup resources on app shutdown
  Future<void> dispose() async {
    try {
      _logInfo('Disposing app resources...');

      // Cleanup temporary files
      final imageRepo = container.read(imageRepositoryProvider);
      await imageRepo.cleanupTempFiles();

      // Dispose of container
      container.dispose();

      _logSuccess('App resources disposed');
    } catch (e, stackTrace) {
      _logError('Error during app disposal', e, stackTrace);
    }
  }

  /// Log info message
  void _logInfo(String message) {
    if (kDebugMode) {
      print('[AppInit] INFO: $message');
    }
  }

  /// Log success message
  void _logSuccess(String message) {
    if (kDebugMode) {
      print('[AppInit] SUCCESS: $message');
    }
  }

  /// Log error message
  void _logError(String message, Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('[AppInit] ERROR: $message - $error');
      if (stackTrace != null) {
        print('[AppInit] Stack trace: $stackTrace');
      }
    }
  }
}

/// Provider for app initialization service
final appInitializationServiceProvider = Provider<AppInitializationService>((
  ref,
) {
  return AppInitializationService(ProviderContainer());
});

/// Provider for initialization future
final initializationFutureProvider = FutureProvider<void>((ref) async {
  // Use the existing ref container instead of creating a new one
  final initService = AppInitializationService(ref.container);

  // Perform initialization without directly modifying other providers
  try {
    await initService.initializeWithoutStateUpdate();
    // Update state after initialization completes
    ref.read(initializationStatusProvider.notifier).state =
        InitializationStatus.completed;
  } catch (e) {
    ref.read(initializationStatusProvider.notifier).state =
        InitializationStatus.failed;
    rethrow;
  }
});

/// App startup configuration
class AppStartupConfig {
  final bool enableSplashScreen;
  final Duration minSplashDuration;
  final bool enableErrorReporting;
  final bool enablePerformanceMonitoring;

  const AppStartupConfig({
    this.enableSplashScreen = true,
    this.minSplashDuration = const Duration(seconds: 2),
    this.enableErrorReporting = false,
    this.enablePerformanceMonitoring = false,
  });
}

/// Provider for startup config
final appStartupConfigProvider = Provider<AppStartupConfig>((ref) {
  return const AppStartupConfig();
});
