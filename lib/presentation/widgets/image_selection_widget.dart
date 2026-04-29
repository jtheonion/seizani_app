import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/image_provider.dart';
import '../providers/image_selection_provider.dart';
import '../../shared/constants/app_colors.dart';
import '../../shared/constants/app_text_styles.dart';
import '../../shared/constants/app_dimensions.dart';

const List<_SampleAsset> _sampleAssets = [
  _SampleAsset(label: '未加工犬', assetPath: 'assets/images/sample_dog_photo.jpg'),
];

class ImageSelectionWidget extends ConsumerWidget {
  const ImageSelectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageState = ref.watch(imageProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingXl),
              decoration: BoxDecoration(
                color: AppColors.primaryVariant.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.starGold.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: AppDimensions.iconXxl,
                color: AppColors.starGold,
              ),
            ),

            const SizedBox(height: AppDimensions.spacingXl),

            // Title
            Text(
              '画像を選択してください',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.spacingM),

            // Subtitle
            Text(
              'カメラで撮影するか、\nギャラリーから写真を選んでください',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.spacingXxl),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingXl,
              ),
              child: Column(
                children: [
                  // Camera button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: imageState.isLoading
                          ? null
                          : () => ref
                                .read(imageProvider.notifier)
                                .pickImageFromCamera(),
                      icon: imageState.isLoading
                          ? const SizedBox(
                              width: AppDimensions.iconS,
                              height: AppDimensions.iconS,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: const Text('カメラで撮影'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size(
                          double.infinity,
                          AppDimensions.buttonHeightL,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingM),

                  // Gallery button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: imageState.isLoading
                          ? null
                          : () => ref
                                .read(imageProvider.notifier)
                                .pickImageFromGallery(),
                      icon: imageState.isLoading
                          ? const SizedBox(
                              width: AppDimensions.iconS,
                              height: AppDimensions.iconS,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: const Text('ギャラリーから選択'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppDimensions.buttonHeightL,
                        ),
                        side: const BorderSide(color: AppColors.accent),
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingL),

                  Text(
                    '検証用サンプル',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Wrap(
                    spacing: AppDimensions.spacingM,
                    runSpacing: AppDimensions.spacingM,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final sample in _sampleAssets)
                        _SampleAssetTile(
                          sample: sample,
                          isLoading: imageState.isLoading,
                          onTap: imageState.isLoading
                              ? null
                              : () => ImageSelectionActions.loadFromAsset(
                                  ref,
                                  sample.assetPath,
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacingXl),

            // Error message
            if (imageState.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingXl,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: AppDimensions.iconS,
                      ),
                      const SizedBox(width: AppDimensions.spacingS),
                      Expanded(
                        child: Text(
                          imageState.error!,
                          style: AppTextStyles.errorText,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.read(imageProvider.notifier).clearError(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.error,
                          size: AppDimensions.iconS,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SampleAsset {
  const _SampleAsset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _SampleAssetTile extends StatelessWidget {
  const _SampleAssetTile({
    required this.sample,
    required this.isLoading,
    required this.onTap,
  });

  final _SampleAsset sample;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLoading ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          child: Container(
            width: 116,
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  child: Image.asset(
                    sample.assetPath,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingS),
                Text(
                  sample.label,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
