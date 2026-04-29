import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

// Domain
import '../../domain/repositories/image_repository.dart';
import '../../domain/repositories/processing_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/usecases/image_selection_usecase.dart';
import '../../domain/usecases/constellation_processing_usecase.dart';
import '../../domain/usecases/line_art_processing_usecase.dart';
import '../../domain/usecases/line_art_star_decoration_usecase.dart';
import '../../domain/usecases/image_save_usecase.dart';

// Infrastructure
import '../../infrastructure/datasources/local_image_datasource.dart';
import '../../infrastructure/datasources/local_storage_datasource.dart';
import '../../infrastructure/repositories/image_repository_impl.dart';
import '../../infrastructure/repositories/processing_repository_impl.dart';
import '../../infrastructure/repositories/storage_repository_impl.dart';

/// Data Sources Providers
final localImageDataSourceProvider = Provider<LocalImageDataSource>((ref) {
  return LocalImageDataSource();
});

final localStorageDataSourceProvider = Provider<LocalStorageDataSource>((ref) {
  return LocalStorageDataSource();
});

/// External Dependencies Providers
final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

/// Repository Providers
final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  final localDataSource = ref.read(localImageDataSourceProvider);
  return ImageRepositoryImpl(localImageDataSource: localDataSource);
});

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  final storageDataSource = ref.read(localStorageDataSourceProvider);
  return ProcessingRepositoryImpl(storageDataSource: storageDataSource);
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final localDataSource = ref.read(localStorageDataSourceProvider);
  return StorageRepositoryImpl(localStorageDataSource: localDataSource);
});

/// Use Case Providers
final imageSelectionUseCaseProvider = Provider<ImageSelectionUseCase>((ref) {
  final imageRepository = ref.read(imageRepositoryProvider);
  return ImageSelectionUseCase(imageRepository);
});

final constellationProcessingUseCaseProvider =
    Provider<ConstellationProcessingUseCase>((ref) {
      final processingRepository = ref.read(processingRepositoryProvider);
      final storageRepository = ref.read(storageRepositoryProvider);
      return ConstellationProcessingUseCase(
        processingRepository,
        storageRepository,
      );
    });

final lineArtProcessingUseCaseProvider = Provider<LineArtProcessingUseCase>((
  ref,
) {
  final processingRepository = ref.read(processingRepositoryProvider);
  final storageRepository = ref.read(storageRepositoryProvider);
  return LineArtProcessingUseCase(processingRepository, storageRepository);
});

final lineArtStarDecorationUseCaseProvider =
    Provider<LineArtStarDecorationUseCase>((ref) {
      final processingRepository = ref.read(processingRepositoryProvider);
      return LineArtStarDecorationUseCase(processingRepository);
    });

final imageSaveUseCaseProvider = Provider<ImageSaveUseCase>((ref) {
  final imageRepository = ref.read(imageRepositoryProvider);
  final storageRepository = ref.read(storageRepositoryProvider);
  return ImageSaveUseCase(imageRepository, storageRepository);
});

/// Initialize all required services
final initializationProvider = FutureProvider<void>((ref) async {
  // Initialize storage
  final storageDataSource = ref.read(localStorageDataSourceProvider);
  await storageDataSource.initialize();

  // Initialize other services if needed
  // Add any additional initialization logic here
});

/// Dependency container for testing and configuration
class DependencyContainer {
  static void configure(ProviderContainer container) {
    // This method can be used to override providers for testing
    // or different configurations
  }

  /// Create a test container with mock providers
  static ProviderContainer createTestContainer({
    ImageRepository? imageRepository,
    ProcessingRepository? processingRepository,
    StorageRepository? storageRepository,
  }) {
    return ProviderContainer(
      overrides: [
        if (imageRepository != null)
          imageRepositoryProvider.overrideWithValue(imageRepository),
        if (processingRepository != null)
          processingRepositoryProvider.overrideWithValue(processingRepository),
        if (storageRepository != null)
          storageRepositoryProvider.overrideWithValue(storageRepository),
      ],
    );
  }

  /// Dispose of resources when needed
  static Future<void> dispose(WidgetRef ref) async {
    // Clean up resources
    final imageRepository = ref.read(imageRepositoryProvider);
    await imageRepository.cleanupTempFiles();

    // Add any other cleanup operations
  }
}

/// Provider for app-wide configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  return const AppConfig();
});

/// App configuration
class AppConfig {
  final bool enableDebugMode;
  final bool enableLogging;
  final int maxProcessingHistory;
  final Duration processingTimeout;
  final String appVersion;

  const AppConfig({
    this.enableDebugMode = false,
    this.enableLogging = true,
    this.maxProcessingHistory = 100,
    this.processingTimeout = const Duration(minutes: 5),
    this.appVersion = '1.0.0',
  });
}

/// Error handling provider
final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  return const ErrorHandler();
});

/// Global error handler
class ErrorHandler {
  const ErrorHandler();

  void handleError(Object error, StackTrace? stackTrace) {
    // Log error
    print('Error: $error');
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }

    // In a real app, you might want to:
    // - Send errors to crash reporting service
    // - Show user-friendly error messages
    // - Log to file for debugging
  }

  void logInfo(String message) {
    print('Info: $message');
  }

  void logWarning(String message) {
    print('Warning: $message');
  }
}

/// Initialization status provider
final initializationStatusProvider = StateProvider<InitializationStatus>((ref) {
  return InitializationStatus.notStarted;
});

enum InitializationStatus { notStarted, initializing, completed, failed }

/// Helper to check if app is ready
final isAppReadyProvider = Provider<bool>((ref) {
  final initStatus = ref.watch(initializationStatusProvider);
  return initStatus == InitializationStatus.completed;
});

/// Global app state provider
final appStateProvider = StateProvider<AppState>((ref) {
  return const AppState();
});

/// Global app state
class AppState {
  final bool isOnline;
  final String currentRoute;
  final Map<String, dynamic> metadata;

  const AppState({
    this.isOnline = true,
    this.currentRoute = '/',
    this.metadata = const {},
  });

  AppState copyWith({
    bool? isOnline,
    String? currentRoute,
    Map<String, dynamic>? metadata,
  }) {
    return AppState(
      isOnline: isOnline ?? this.isOnline,
      currentRoute: currentRoute ?? this.currentRoute,
      metadata: metadata ?? this.metadata,
    );
  }
}
