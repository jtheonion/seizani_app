import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/line_art_processing_provider.dart';
import '../widgets/processing_overlay_widget.dart';
import '../widgets/constellation_background_widget.dart';
import '../../shared/constants/app_colors.dart';
import '../../shared/constants/app_text_styles.dart';
import '../../shared/constants/app_dimensions.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/line_art_decoration_entity.dart';
import '../../domain/entities/line_art_entity.dart';

/// Screen for 2-stage image conversion: Image → Line Art → Constellation
class LineArtConversionScreen extends ConsumerStatefulWidget {
  final ImageEntity imageEntity;

  const LineArtConversionScreen({super.key, required this.imageEntity});

  @override
  ConsumerState<LineArtConversionScreen> createState() =>
      _LineArtConversionScreenState();
}

class _LineArtConversionScreenState
    extends ConsumerState<LineArtConversionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lineArtProcessingProvider.notifier).reset();
      ref.read(starDecorationParametersProvider.notifier).state =
          const StarDecorationParams();
    });
  }

  @override
  void didUpdateWidget(LineArtConversionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageEntity.id != widget.imageEntity.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(lineArtProcessingProvider.notifier).reset();
        ref.read(starDecorationParametersProvider.notifier).state =
            const StarDecorationParams();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final processingState = ref.watch(lineArtProcessingProvider);
    final presets = ref.watch(lineArtPresetsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('2段階変換'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (processingState.hasLineArt || processingState.hasCompletedResult)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _resetProcessing(ref),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background with constellation effect
          const ConstellationBackgroundWidget(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(processingState),

                // Main content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: _buildMainContent(
                      context,
                      ref,
                      processingState,
                      presets,
                    ),
                  ),
                ),

                // Action buttons
                _buildActionButtons(context, ref, processingState),

                const SizedBox(height: AppDimensions.spacingL),
              ],
            ),
          ),

          // Processing overlay
          if (processingState.isProcessing) const ProcessingOverlayWidget(),
        ],
      ),
    );
  }

  /// Build progress indicator showing current stage
  Widget _buildProgressIndicator(LineArtProcessingState state) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingL),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('変換進行状況', style: AppTextStyles.h4),
          const SizedBox(height: AppDimensions.spacingM),
          Row(
            children: [
              // Stage 1: Image to Line Art
              _buildStageIndicator(
                icon: Icons.image_outlined,
                label: '線画変換',
                isActive:
                    state.status == LineArtProcessingStatus.processingToLineArt,
                isCompleted: state.hasLineArt,
                isCurrent:
                    state.status == LineArtProcessingStatus.processingToLineArt,
              ),

              // Arrow
              Expanded(
                child: Container(
                  height: 2,
                  color: state.hasLineArt
                      ? AppColors.success
                      : AppColors.border,
                ),
              ),

              // Stage 2: Line Art to Constellation
              _buildStageIndicator(
                icon: Icons.auto_awesome,
                label: '星座変換',
                isActive:
                    state.status ==
                    LineArtProcessingStatus.processingToConstellation,
                isCompleted: state.hasCompletedResult,
                isCurrent:
                    state.status ==
                    LineArtProcessingStatus.processingToConstellation,
              ),
            ],
          ),

          // Progress bar
          if (state.isProcessing) ...[
            const SizedBox(height: AppDimensions.spacingM),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              state.currentStep,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Build individual stage indicator
  Widget _buildStageIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    Color color;
    if (isCompleted) {
      color = AppColors.success;
    } else if (isActive || isCurrent) {
      color = AppColors.accent;
    } else {
      color = AppColors.textSecondary;
    }

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(isCompleted ? Icons.check : icon, color: color, size: 24),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Build main content area
  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
    Map<String, LineArtParameters> presets,
  ) {
    if (processingState.hasError) {
      return _buildErrorView(context, ref, processingState);
    }

    if (processingState.hasDecoration) {
      return _buildStarDecorationResult(context, ref, processingState);
    }

    if (processingState.hasConstellation) {
      return _buildLegacyConstellationResult(context, processingState);
    }

    if (processingState.hasLineArt) {
      return _buildLineArtResult(context, ref, processingState);
    }

    // Initial state - show original image and parameters
    return _buildInitialView(context, ref, presets);
  }

  /// Build initial view with parameter selection
  Widget _buildInitialView(
    BuildContext context,
    WidgetRef ref,
    Map<String, LineArtParameters> presets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ステップ1: 線画変換', style: AppTextStyles.h3),
        const SizedBox(height: AppDimensions.spacingM),

        // Original image preview
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: widget.imageEntity.bytes != null
                  ? Image.memory(widget.imageEntity.bytes!, fit: BoxFit.contain)
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Parameter selection
        Expanded(
          flex: 2,
          child: _buildParameterSelection(context, ref, presets),
        ),
      ],
    );
  }

  /// Build parameter selection UI
  Widget _buildParameterSelection(
    BuildContext context,
    WidgetRef ref,
    Map<String, LineArtParameters> presets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('変換方法を選択:', style: AppTextStyles.h6),
        const SizedBox(height: AppDimensions.spacingM),

        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: AppDimensions.spacingM,
              mainAxisSpacing: AppDimensions.spacingM,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final entry = presets.entries.elementAt(index);
              return _buildPresetCard(context, ref, entry.key, entry.value);
            },
          ),
        ),
      ],
    );
  }

  /// Build preset selection card
  Widget _buildPresetCard(
    BuildContext context,
    WidgetRef ref,
    String name,
    LineArtParameters parameters,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: parameters.algorithm == LineArtAlgorithm.dexined
            ? () => _showDexiNedSettingsSheet(context, ref, parameters)
            : () => _startLineArtProcessing(ref, parameters),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getAlgorithmIcon(parameters.algorithm),
                size: AppDimensions.iconM,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppDimensions.spacingS),
              Text(
                name,
                style: AppTextStyles.body2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                parameters.algorithm.displayName,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build line art result view
  Widget _buildLineArtResult(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    final starParams = ref.watch(starDecorationParametersProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ステップ2: 星座変換', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.spacingM),

          SizedBox(
            height: 280,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: Image.memory(
                  processingState.lineArt!.lineArtImageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingL),
          _buildLineArtReadyInfo(processingState),
          const SizedBox(height: AppDimensions.spacingL),
          _buildStarDecorationAdjustmentPanel(
            context,
            ref,
            starParams,
            title: '星座変換の調整',
          ),
        ],
      ),
    );
  }

  Widget _buildLineArtReadyInfo(LineArtProcessingState processingState) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: AppDimensions.iconM,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '線画変換完了！',
                  style: AppTextStyles.h6.copyWith(color: AppColors.success),
                ),
                if (processingState.processingTime != null)
                  Text(
                    '処理時間: ${processingState.processingTime!.inMilliseconds}ms',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarDecorationResult(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    final currentParams = ref.watch(starDecorationParametersProvider);
    final decoration = processingState.decoration!;

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '星座アート完成！',
                  style: AppTextStyles.h3.copyWith(color: AppColors.starGold),
                ),
              ),
              IconButton(
                icon: Icon(
                  processingState.showParameterPanel
                      ? Icons.tune
                      : Icons.tune_outlined,
                  color: AppColors.accent,
                ),
                onPressed: () => ref
                    .read(lineArtProcessingProvider.notifier)
                    .toggleParameterPanel(),
                tooltip: 'パラメータ調整',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),

          if (processingState.showParameterPanel) ...[
            _buildStarDecorationAdjustmentPanel(
              context,
              ref,
              currentParams,
              title: '星座変換の再調整',
              showGenerateButton: true,
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],

          SizedBox(
            height: 360,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: AppColors.constellationLine,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: Image.memory(
                  decoration.decoratedImageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingL),

          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.starGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: AppColors.starGold.withOpacity(0.3)),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2段階変換完了！', style: AppTextStyles.starLabel),
                      Text(
                        '星: ${decoration.metadata.starCount}個',
                        style: AppTextStyles.caption,
                      ),
                      if (processingState.processingTime != null)
                        Text(
                          '総処理時間: ${processingState.processingTime!.inSeconds}秒',
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: Icon(
                    processingState.showParameterPanel
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                  ),
                  label: Text(
                    processingState.showParameterPanel ? '閉じる' : '調整',
                    style: AppTextStyles.caption,
                  ),
                  onPressed: () => ref
                      .read(lineArtProcessingProvider.notifier)
                      .toggleParameterPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyConstellationResult(
    BuildContext context,
    LineArtProcessingState processingState,
  ) {
    return Column(
      children: [
        Text(
          '星座アート完成！',
          style: AppTextStyles.h3.copyWith(color: AppColors.starGold),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(color: AppColors.constellationLine, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: Image.memory(
                processingState.constellation!.renderedImageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.starGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            border: Border.all(color: AppColors.starGold.withOpacity(0.3)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2段階変換完了！', style: AppTextStyles.starLabel),
                    if (processingState.processingTime != null)
                      Text(
                        '総処理時間: ${processingState.processingTime!.inSeconds}秒',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build error view
  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            'エラーが発生しました',
            style: AppTextStyles.h4.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            processingState.error ?? '不明なエラー',
            style: AppTextStyles.body2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          ElevatedButton(
            onPressed: () =>
                ref.read(lineArtProcessingProvider.notifier).clearError(),
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    if (processingState.isProcessing) {
      return const SizedBox.shrink();
    }

    if (processingState.hasCompletedResult) {
      return _buildResultActions(context, ref, processingState);
    }

    if (processingState.hasLineArt) {
      return _buildLineArtActions(context, ref, processingState);
    }

    return const SizedBox.shrink();
  }

  /// Build actions for line art stage
  Widget _buildLineArtActions(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _resetProcessing(ref),
              icon: const Icon(Icons.refresh),
              label: const Text('やり直し'),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _startConstellationProcessing(ref),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('星座に変換'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build actions for completed result
  Widget _buildResultActions(
    BuildContext context,
    WidgetRef ref,
    LineArtProcessingState processingState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareResult(context, processingState),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('共有'),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              if (!kIsWeb)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveResult(context, processingState),
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
            onPressed: () => ref
                .read(lineArtProcessingProvider.notifier)
                .toggleParameterPanel(),
            icon: const Icon(Icons.tune),
            label: const Text('別の設定で試す'),
          ),
        ],
      ),
    );
  }

  // Action methods
  Future<void> _showDexiNedSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    LineArtParameters initialParameters,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        var draftParameters = initialParameters;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppDimensions.paddingL,
                  right: AppDimensions.paddingL,
                  top: AppDimensions.paddingL,
                  bottom: bottomInset + AppDimensions.paddingL,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_motion,
                            color: AppColors.accent,
                            size: AppDimensions.iconM,
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                          Expanded(
                            child: Text('DexiNed線画調整', style: AppTextStyles.h4),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingL),
                      _buildDexiNedSlider(
                        label: '線の量',
                        value: draftParameters.dexinedPercentile,
                        min: 85.0,
                        max: 98.0,
                        divisions: 26,
                        displayValue:
                            '${draftParameters.dexinedPercentile.toStringAsFixed(1)}%',
                        icon: Icons.tune,
                        onChanged: (value) {
                          setSheetState(() {
                            draftParameters = draftParameters.copyWith(
                              dexinedPercentile: value,
                            );
                          });
                        },
                      ),
                      _buildDexiNedSlider(
                        label: 'ノイズ抑制',
                        value: draftParameters.dexinedMinThreshold.toDouble(),
                        min: 0.0,
                        max: 80.0,
                        divisions: 80,
                        displayValue: draftParameters.dexinedMinThreshold
                            .toString(),
                        icon: Icons.filter_alt_outlined,
                        onChanged: (value) {
                          setSheetState(() {
                            draftParameters = draftParameters.copyWith(
                              dexinedMinThreshold: value.round(),
                            );
                          });
                        },
                      ),
                      _buildDexiNedSlider(
                        label: '線の太さ',
                        value: draftParameters.lineThickness,
                        min: 1.0,
                        max: 3.0,
                        divisions: 2,
                        displayValue: draftParameters.lineThickness
                            .toStringAsFixed(0),
                        icon: Icons.line_weight,
                        onChanged: (value) {
                          setSheetState(() {
                            draftParameters = draftParameters.copyWith(
                              lineThickness: value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('デフォルトに戻す'),
                              onPressed: () {
                                setSheetState(() {
                                  draftParameters =
                                      LineArtParameters.dexinedDefaults;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome_motion),
                              label: const Text('DexiNed線画を生成'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                              ),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                if (!mounted) return;
                                _startLineArtProcessing(ref, draftParameters);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDexiNedSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(child: Text(label, style: AppTextStyles.body2)),
              Text(displayValue, style: AppTextStyles.caption),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _startLineArtProcessing(WidgetRef ref, LineArtParameters parameters) {
    ref
        .read(lineArtProcessingProvider.notifier)
        .startImageToLineArtProcessing(
          widget.imageEntity,
          customParameters: parameters,
        );
  }

  void _startConstellationProcessing(WidgetRef ref) {
    final params = ref.read(starDecorationParametersProvider);
    ref
        .read(lineArtProcessingProvider.notifier)
        .startLineArtToConstellationProcessing(
          starDecorationParameters: params,
        );
  }

  void _resetProcessing(WidgetRef ref) {
    ref.read(lineArtProcessingProvider.notifier).reset();
    ref.read(starDecorationParametersProvider.notifier).state =
        const StarDecorationParams();
  }

  Future<void> _shareResult(
    BuildContext context,
    LineArtProcessingState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final imageBytes =
          state.decoration?.decoratedImageBytes ??
          state.constellation?.renderedImageBytes;

      if (imageBytes != null) {
        final xfile = XFile.fromData(
          imageBytes,
          name:
              'seizani_constellation_${DateTime.now().millisecondsSinceEpoch}.png',
          mimeType: 'image/png',
        );
        await Share.shareXFiles([xfile], text: '2段階変換で作った星座アート');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('共有に失敗しました: $e')));
    }
  }

  Future<void> _saveResult(
    BuildContext context,
    LineArtProcessingState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final imageBytes =
          state.decoration?.decoratedImageBytes ??
          state.constellation?.renderedImageBytes;

      if (imageBytes != null) {
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

        final fileNameWithExt =
            'seizani_constellation_${DateTime.now().millisecondsSinceEpoch}.png';
        final filePath = path.join(picturesDir.path, fileNameWithExt);

        final imageFile = File(filePath);
        await imageFile.writeAsBytes(imageBytes);

        messenger.showSnackBar(const SnackBar(content: Text('保存しました')));
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('保存できる画像データが見つかりません')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    }
  }

  IconData _getAlgorithmIcon(LineArtAlgorithm algorithm) {
    switch (algorithm) {
      case LineArtAlgorithm.sobel:
        return Icons.grain;
      case LineArtAlgorithm.canny:
        return Icons.linear_scale;
      case LineArtAlgorithm.xdog:
        return Icons.blur_on;
      case LineArtAlgorithm.pencilSketch:
        return Icons.edit;
      case LineArtAlgorithm.adaptiveEdge:
        return Icons.auto_fix_high;
      case LineArtAlgorithm.dexined:
        return Icons.auto_awesome_motion;
      case LineArtAlgorithm.pidinet:
        return Icons.filter_center_focus;
    }
  }

  Widget _buildStarDecorationAdjustmentPanel(
    BuildContext context,
    WidgetRef ref,
    StarDecorationParams currentParams, {
    required String title,
    bool showGenerateButton = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h6.copyWith(color: AppColors.starGold),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildStarDecorationSlider(
            label: '線の太さ閾値',
            value: currentParams.lineWidthThreshold,
            min: 0.5,
            max: 8.0,
            divisions: 75,
            displayValue: currentParams.lineWidthThreshold.toStringAsFixed(1),
            icon: Icons.line_weight,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(lineWidthThreshold: value),
            ),
          ),
          _buildStarDecorationSlider(
            label: '星密度',
            value: currentParams.starDensity,
            min: 0.2,
            max: 2.0,
            divisions: 18,
            displayValue: currentParams.starDensity.toStringAsFixed(1),
            icon: Icons.scatter_plot,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(starDensity: value),
            ),
          ),
          _buildStarDecorationSlider(
            label: '星サイズ最小',
            value: currentParams.starMinSize,
            min: 0.5,
            max: 6.0,
            divisions: 55,
            displayValue: currentParams.starMinSize.toStringAsFixed(1),
            icon: Icons.star_border,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(starMinSize: value),
            ),
          ),
          _buildStarDecorationSlider(
            label: '星サイズ最大',
            value: currentParams.starMaxSize,
            min: 0.5,
            max: 8.0,
            divisions: 75,
            displayValue: currentParams.starMaxSize.toStringAsFixed(1),
            icon: Icons.star,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(starMaxSize: value),
            ),
          ),
          _buildStarDecorationSlider(
            label: '明るさ',
            value: currentParams.starBrightness,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            displayValue: currentParams.starBrightness.toStringAsFixed(2),
            icon: Icons.brightness_6,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(starBrightness: value),
            ),
          ),
          _buildStarDecorationSlider(
            label: 'グロー',
            value: currentParams.starGlow,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            displayValue: currentParams.starGlow.toStringAsFixed(2),
            icon: Icons.blur_on,
            onChanged: (value) => _updateStarDecorationParameter(
              ref,
              currentParams.copyWith(starGlow: value),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('デフォルトに戻す'),
                  onPressed: () => _updateStarDecorationParameter(
                    ref,
                    const StarDecorationParams(),
                  ),
                ),
              ),
              if (showGenerateButton) ...[
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('この設定で再生成'),
                    onPressed: () =>
                        _applyStarDecorationParameters(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starGold,
                      foregroundColor: AppColors.onStarGold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarDecorationSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(child: Text(label, style: AppTextStyles.body2)),
              Text(displayValue, style: AppTextStyles.caption),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: AppColors.starGold,
            inactiveColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  void _updateStarDecorationParameter(
    WidgetRef ref,
    StarDecorationParams newParams,
  ) {
    ref.read(starDecorationParametersProvider.notifier).state = newParams;
    ref
        .read(lineArtProcessingProvider.notifier)
        .updateStarDecorationParameters(newParams);
  }

  Future<void> _applyStarDecorationParameters(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(const SnackBar(content: Text('星座変換を再生成中...')));
      final processingState = ref.read(lineArtProcessingProvider);
      if (processingState.lineArt != null) {
        final params = ref.read(starDecorationParametersProvider);
        await ref
            .read(lineArtProcessingProvider.notifier)
            .startLineArtToConstellationProcessing(
              starDecorationParameters: params,
            );
      }

      messenger.showSnackBar(const SnackBar(content: Text('星座変換を更新しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('再生成に失敗しました: $e')));
    }
  }
}
