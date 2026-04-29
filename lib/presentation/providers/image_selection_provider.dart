import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/usecases/image_selection_usecase.dart';
import '../providers/dependencies.dart';

/// State for image selection
class ImageSelectionState {
  final ImageEntity? selectedImage;
  final bool isLoading;
  final String? error;
  final String? lastAction; // 'camera' or 'gallery'

  const ImageSelectionState({
    this.selectedImage,
    this.isLoading = false,
    this.error,
    this.lastAction,
  });

  ImageSelectionState copyWith({
    ImageEntity? selectedImage,
    bool? isLoading,
    String? error,
    String? lastAction,
  }) {
    return ImageSelectionState(
      selectedImage: selectedImage ?? this.selectedImage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  bool get hasImage => selectedImage != null;
  bool get hasError => error != null;
}

/// Notifier for image selection state
class ImageSelectionNotifier extends StateNotifier<ImageSelectionState> {
  final ImageSelectionUseCase _imageSelectionUseCase;

  ImageSelectionNotifier(this._imageSelectionUseCase)
    : super(const ImageSelectionState());

  /// Select image from camera
  Future<void> selectFromCamera() async {
    print('🎬 [DEBUG] カメラボタンがタップされました');
    state = state.copyWith(isLoading: true, error: null, lastAction: 'camera');

    try {
      final result = await _imageSelectionUseCase.selectFromCamera();

      if (result.isSuccess && result.image != null) {
        // Prepare image for processing
        final prepareResult = await _imageSelectionUseCase
            .prepareImageForProcessing(result.image!);

        if (prepareResult.isSuccess) {
          state = state.copyWith(
            selectedImage: prepareResult.image,
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: prepareResult.error);
        }
      } else if (result.isCancelled) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'カメラからの画像選択に失敗しました: $e');
    }
  }

  /// Select image from gallery
  Future<void> selectFromGallery() async {
    print('📷 [DEBUG] ギャラリーボタンがタップされました');
    state = state.copyWith(isLoading: true, error: null, lastAction: 'gallery');

    try {
      final result = await _imageSelectionUseCase.selectFromGallery();

      if (result.isSuccess && result.image != null) {
        // Prepare image for processing
        final prepareResult = await _imageSelectionUseCase
            .prepareImageForProcessing(result.image!);

        if (prepareResult.isSuccess) {
          state = state.copyWith(
            selectedImage: prepareResult.image,
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: prepareResult.error);
        }
      } else if (result.isCancelled) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'ギャラリーからの画像選択に失敗しました: $e',
      );
    }
  }

  /// Load image from file path
  Future<void> loadFromFile(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _imageSelectionUseCase.loadFromFile(filePath);

      if (result.isSuccess && result.image != null) {
        final prepareResult = await _imageSelectionUseCase
            .prepareImageForProcessing(result.image!);

        if (prepareResult.isSuccess) {
          state = state.copyWith(
            selectedImage: prepareResult.image,
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: prepareResult.error);
        }
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'ファイルからの画像読み込みに失敗しました: $e',
      );
    }
  }

  /// Load bundled/sample asset image.
  Future<void> loadFromAsset(String assetPath) async {
    state = state.copyWith(isLoading: true, error: null, lastAction: 'asset');

    try {
      final data = await rootBundle.load(assetPath);
      final result = await _imageSelectionUseCase.loadFromBytes(
        data.buffer.asUint8List(),
        id: assetPath.split('/').last,
      );

      if (result.isSuccess && result.image != null) {
        final prepareResult = await _imageSelectionUseCase
            .prepareImageForProcessing(result.image!);

        if (prepareResult.isSuccess) {
          state = state.copyWith(
            selectedImage: prepareResult.image,
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: prepareResult.error);
        }
      } else if (result.isCancelled) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'サンプル画像の読み込みに失敗しました: $e');
    }
  }

  /// Clear selected image
  void clearImage() {
    state = const ImageSelectionState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get supported formats
  List<String> getSupportedFormats() {
    return _imageSelectionUseCase.getSupportedFormats();
  }
}

/// Provider for image selection state
final imageSelectionProvider =
    StateNotifierProvider<ImageSelectionNotifier, ImageSelectionState>((ref) {
      final imageSelectionUseCase = ref.read(imageSelectionUseCaseProvider);
      return ImageSelectionNotifier(imageSelectionUseCase);
    });

/// Convenience providers for specific state properties
final selectedImageProvider = Provider<ImageEntity?>((ref) {
  return ref.watch(imageSelectionProvider).selectedImage;
});

final imageSelectionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(imageSelectionProvider).isLoading;
});

final imageSelectionErrorProvider = Provider<String?>((ref) {
  return ref.watch(imageSelectionProvider).error;
});

final hasSelectedImageProvider = Provider<bool>((ref) {
  return ref.watch(imageSelectionProvider).hasImage;
});

final supportedFormatsProvider = Provider<List<String>>((ref) {
  final notifier = ref.read(imageSelectionProvider.notifier);
  return notifier.getSupportedFormats();
});

/// Actions for image selection
class ImageSelectionActions {
  static Future<void> selectFromCamera(WidgetRef ref) async {
    await ref.read(imageSelectionProvider.notifier).selectFromCamera();
  }

  static Future<void> selectFromGallery(WidgetRef ref) async {
    await ref.read(imageSelectionProvider.notifier).selectFromGallery();
  }

  static Future<void> loadFromFile(WidgetRef ref, String filePath) async {
    await ref.read(imageSelectionProvider.notifier).loadFromFile(filePath);
  }

  static Future<void> loadFromAsset(WidgetRef ref, String assetPath) async {
    await ref.read(imageSelectionProvider.notifier).loadFromAsset(assetPath);
  }

  static void clearImage(WidgetRef ref) {
    ref.read(imageSelectionProvider.notifier).clearImage();
  }

  static void clearError(WidgetRef ref) {
    ref.read(imageSelectionProvider.notifier).clearError();
  }
}
