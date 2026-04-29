import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/image_provider.dart';
import '../providers/processing_provider.dart';
import '../providers/constellation_processing_provider.dart';
import '../widgets/image_selection_widget.dart';
import '../widgets/processing_overlay_widget.dart';
import '../widgets/constellation_background_widget.dart';
import '../../shared/constants/app_colors.dart';
import '../../shared/constants/app_text_styles.dart';
import '../../shared/constants/app_dimensions.dart';
import 'line_art_conversion_screen.dart';
import '../../domain/entities/image_entity.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageState = ref.watch(imageProvider);
    final processingState = ref.watch(processingProvider);
    final lastConstellation = ref.watch(lastConstellationProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Seizani'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background with constellation effect
          const ConstellationBackgroundWidget(),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Welcome section
                  _buildWelcomeSection(),

                  const SizedBox(height: AppDimensions.spacingXxl),

                  // Image selection or preview
                  Expanded(
                    child: _buildMainContent(
                      context,
                      ref,
                      imageState,
                      processingState,
                      lastConstellation?.renderedImageBytes,
                    ),
                  ),

                  // Action buttons
                  _buildActionButtons(
                    context,
                    ref,
                    imageState,
                    processingState,
                  ),

                  const SizedBox(height: AppDimensions.spacingL),
                ],
              ),
            ),
          ),

          // Processing overlay
          if (processingState.isProcessing) const ProcessingOverlayWidget(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        Text(
          '✨ 写真を星座アートに変換 ✨',
          style: AppTextStyles.h3.copyWith(color: AppColors.starGold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'あなたの写真から美しい星座パターンを作成します',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    ImageState imageState,
    ProcessingState processingState,
    Uint8List? renderedBytes,
  ) {
    if (processingState.processedImage != null || renderedBytes != null) {
      // Show processed result (prefer memory bytes when available)
      return _buildProcessedImageView(
        bytes: renderedBytes,
        file: processingState.processedImage,
      );
    }

    if (imageState.selectedImage != null) {
      // Show selected image preview
      return _buildImagePreview(imageState.selectedImage!);
    }

    // Show image selection widget
    return const ImageSelectionWidget();
  }

  Widget _buildImagePreview(File imageFile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildProcessedImageView({Uint8List? bytes, File? file}) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(color: AppColors.constellationLine, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: (bytes != null)
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : Image.file(
                      file!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            border: Border.all(
              color: AppColors.starGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.starGold,
                size: AppDimensions.iconM,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Text('星座アートが完成しました！', style: AppTextStyles.starLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    ImageState imageState,
    ProcessingState processingState,
  ) {
    final lastConstellation = ref.watch(lastConstellationProvider);
    if (processingState.processedImage != null || lastConstellation != null) {
      return _buildResultActions(context, ref, processingState);
    }

    if (imageState.selectedImage != null) {
      return _buildProcessingActions(context, ref, imageState);
    }

    return const SizedBox.shrink();
  }

  Widget _buildProcessingActions(
    BuildContext context,
    WidgetRef ref,
    ImageState imageState,
  ) {
    return Column(
      children: [
        // Conversion options
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  debugPrint('🌟 [UI] 星座に変換ボタンがタップされました');
                  print('🌟 [CONSOLE] 星座に変換ボタンがタップされました - ${DateTime.now()}');
                  print(
                    '🖼️ [CONSOLE] 選択画像パス: ${imageState.selectedImage?.path}',
                  );
                  ref
                      .read(processingProvider.notifier)
                      .startProcessing(imageState.selectedImage!);
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('直接変換'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToTwoStageConversion(
                    context,
                    imageState.selectedImage!,
                  );
                },
                icon: const Icon(Icons.layers_outlined),
                label: const Text('2段階変換'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starGold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Additional options
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(imageProvider.notifier).clearImage();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('別の画像'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  _showConversionInfo(context);
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('変換方法について'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultActions(
    BuildContext context,
    WidgetRef ref,
    ProcessingState processingState,
  ) {
    final lastConstellation = ref.watch(lastConstellationProvider);
    final Uint8List? bytes = lastConstellation?.renderedImageBytes;
    final File? file = processingState.processedImage;

    final messenger = ScaffoldMessenger.of(context);

    Future<void> doShare() async {
      try {
        if (bytes != null) {
          final xfile = XFile.fromData(
            bytes,
            name: 'seizani_${DateTime.now().millisecondsSinceEpoch}.png',
            mimeType: 'image/png',
          );
          await Share.shareXFiles([xfile], text: '星座アートを共有');
          return;
        }
        if (file != null) {
          final xfile = XFile(file.path, mimeType: 'image/png');
          await Share.shareXFiles([xfile], text: '星座アートを共有');
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('共有に失敗しました: $e')));
      }
    }

    Future<void> doSave() async {
      try {
        if (kIsWeb) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Webでは保存は共有からダウンロードをご利用ください')),
          );
          return;
        }

        Uint8List? data = bytes;
        if (data == null && file != null) {
          data = await file.readAsBytes();
        }
        if (data == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('保存できる画像データが見つかりません')),
          );
          return;
        }

        final name = 'seizani_${DateTime.now().millisecondsSinceEpoch}';

        // Save to pictures directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('外部ストレージにアクセスできません')),
          );
          return;
        }

        final picturesDir = Directory('${directory.path}/Pictures');
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }

        final fileNameWithExt = '$name.png';
        final filePath = path.join(picturesDir.path, fileNameWithExt);

        final imageFile = File(filePath);
        await imageFile.writeAsBytes(data);

        messenger.showSnackBar(const SnackBar(content: Text('保存しました')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: doShare,
                icon: const Icon(Icons.share_outlined),
                label: const Text('共有'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            if (!kIsWeb)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: doSave,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('保存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        TextButton.icon(
          onPressed: () {
            ref.read(imageProvider.notifier).clearImage();
            ref.read(processingProvider.notifier).reset();
          },
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('新しい画像で試す'),
        ),
      ],
    );
  }

  /// Navigate to 2-stage conversion screen
  void _navigateToTwoStageConversion(
    BuildContext context,
    File imageFile,
  ) async {
    try {
      // Create ImageEntity from selected file
      final bytes = await imageFile.readAsBytes();
      final imageEntity = ImageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: imageFile.path,
        bytes: bytes,
        width: 0, // Will be determined during processing
        height: 0, // Will be determined during processing
        createdAt: DateTime.now(),
      );

      // Navigate to 2-stage conversion screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              LineArtConversionScreen(imageEntity: imageEntity),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('画像の読み込みに失敗しました: $e')));
    }
  }

  /// Show conversion method information dialog
  void _showConversionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変換方法について'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              Icons.auto_awesome,
              '直接変換',
              '画像から直接星座パターンを生成します。\n高速で手軽な変換が可能です。',
              AppColors.accent,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildInfoItem(
              Icons.layers_outlined,
              '2段階変換',
              '画像を線画に変換してから星座パターンを生成します。\nより詳細な調整が可能で、線画を確認してから星座に変換できます。',
              AppColors.starGold,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// Build info item for conversion method dialog
  Widget _buildInfoItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h6.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingS),
              Text(description, style: AppTextStyles.body2),
            ],
          ),
        ),
      ],
    );
  }
}
