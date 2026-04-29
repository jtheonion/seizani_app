import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/image_entity.dart';
import 'image_selection_provider.dart';

// Legacy compatibility provider - delegates to new Clean Architecture providers

class ImageState {
  final File? selectedImage;
  final bool isLoading;
  final String? error;

  const ImageState({this.selectedImage, this.isLoading = false, this.error});

  ImageState copyWith({File? selectedImage, bool? isLoading, String? error}) {
    return ImageState(
      selectedImage: selectedImage ?? this.selectedImage,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Create from ImageEntity
  factory ImageState.fromImageEntity(
    ImageEntity? entity, {
    bool isLoading = false,
    String? error,
  }) {
    File? file;
    if (entity != null && entity.path.isNotEmpty) {
      file = File(entity.path);
    }
    return ImageState(selectedImage: file, isLoading: isLoading, error: error);
  }
}

class ImageNotifier extends StateNotifier<ImageState> {
  final Ref _ref;

  ImageNotifier(this._ref) : super(const ImageState()) {
    // Listen to the new Clean Architecture provider
    _ref.listen(imageSelectionProvider, (previous, next) {
      state = ImageState.fromImageEntity(
        next.selectedImage,
        isLoading: next.isLoading,
        error: next.error,
      );
    });
  }

  Future<void> pickImageFromCamera() async {
    await _ref.read(imageSelectionProvider.notifier).selectFromCamera();
  }

  Future<void> pickImageFromGallery() async {
    await _ref.read(imageSelectionProvider.notifier).selectFromGallery();
  }

  void clearImage() {
    _ref.read(imageSelectionProvider.notifier).clearImage();
  }

  void clearError() {
    _ref.read(imageSelectionProvider.notifier).clearError();
  }
}

final imageProvider = StateNotifierProvider<ImageNotifier, ImageState>((ref) {
  return ImageNotifier(ref);
});
