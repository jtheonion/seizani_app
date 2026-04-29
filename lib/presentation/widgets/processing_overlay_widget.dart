import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/processing_provider.dart';
import '../../shared/constants/app_colors.dart';
import '../../shared/constants/app_text_styles.dart';
import '../../shared/constants/app_dimensions.dart';

class ProcessingOverlayWidget extends ConsumerWidget {
  const ProcessingOverlayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processingState = ref.watch(processingProvider);

    return Container(
      color: AppColors.background.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.marginXl),
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: AppColors.starGold.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.starGold.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated processing indicator
              _buildProcessingIndicator(processingState),

              const SizedBox(height: AppDimensions.spacingXl),

              // Status text
              Text(
                processingState.statusText,
                style: AppTextStyles.h6.copyWith(color: AppColors.starGold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacingM),

              // Progress bar
              _buildProgressBar(processingState),

              const SizedBox(height: AppDimensions.spacingM),

              // Status message
              if (processingState.statusMessage != null)
                Text(
                  processingState.statusMessage!,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: AppDimensions.spacingL),

              // Processing steps indicator
              _buildStepsIndicator(processingState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(ProcessingState state) {
    return SizedBox(
      width: AppDimensions.processingIndicatorSize,
      height: AppDimensions.processingIndicatorSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          SizedBox(
            width: AppDimensions.processingIndicatorSize,
            height: AppDimensions.processingIndicatorSize,
            child: CircularProgressIndicator(
              value: state.progress,
              strokeWidth: 4,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(state.status),
              ),
            ),
          ),

          // Inner constellation icon with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: Icon(
                  _getStatusIcon(state.status),
                  size: AppDimensions.iconXl,
                  color: AppColors.starGold,
                ),
              );
            },
          ),

          // Progress percentage
          Text(
            '${(state.progress * 100).toInt()}%',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ProcessingState state) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        child: LinearProgressIndicator(
          value: state.progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(state.status),
          ),
        ),
      ),
    );
  }

  Widget _buildStepsIndicator(ProcessingState state) {
    final steps = ['前処理', 'エッジ検出', '特徴点抽出', '星座生成', 'レンダリング'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: steps.map((step) {
          final isActive = _isStepActive(step, state.status);
          final isCompleted = _isStepCompleted(step, state.status);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : isActive
                        ? AppColors.starGold
                        : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive || isCompleted
                          ? (isCompleted
                                ? AppColors.success
                                : AppColors.starGold)
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : isActive
                        ? Icons.more_horiz
                        : Icons.circle,
                    size: 12,
                    color: isCompleted || isActive
                        ? AppColors.onPrimary
                        : AppColors.disabled,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  step,
                  style: AppTextStyles.caption.copyWith(
                    color: isActive || isCompleted
                        ? AppColors.onSurface
                        : AppColors.disabled,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getProgressColor(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.preprocessing:
        return AppColors.info;
      case ProcessingStatus.edgeDetection:
        return AppColors.secondary;
      case ProcessingStatus.featureExtraction:
        return AppColors.accent;
      case ProcessingStatus.constellationGeneration:
        return AppColors.constellationLine;
      case ProcessingStatus.rendering:
        return AppColors.starGold;
      default:
        return AppColors.starGold;
    }
  }

  IconData _getStatusIcon(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.preprocessing:
        return Icons.tune;
      case ProcessingStatus.edgeDetection:
        return Icons.border_outer;
      case ProcessingStatus.featureExtraction:
        return Icons.scatter_plot;
      case ProcessingStatus.constellationGeneration:
        return Icons.stars;
      case ProcessingStatus.rendering:
        return Icons.palette;
      default:
        return Icons.auto_awesome;
    }
  }

  bool _isStepActive(String step, ProcessingStatus status) {
    final stepMap = {
      '前処理': ProcessingStatus.preprocessing,
      'エッジ検出': ProcessingStatus.edgeDetection,
      '特徴点抽出': ProcessingStatus.featureExtraction,
      '星座生成': ProcessingStatus.constellationGeneration,
      'レンダリング': ProcessingStatus.rendering,
    };

    return stepMap[step] == status;
  }

  bool _isStepCompleted(String step, ProcessingStatus status) {
    final stepOrder = [
      ProcessingStatus.preprocessing,
      ProcessingStatus.edgeDetection,
      ProcessingStatus.featureExtraction,
      ProcessingStatus.constellationGeneration,
      ProcessingStatus.rendering,
    ];

    final stepMap = {
      '前処理': ProcessingStatus.preprocessing,
      'エッジ検出': ProcessingStatus.edgeDetection,
      '特徴点抽出': ProcessingStatus.featureExtraction,
      '星座生成': ProcessingStatus.constellationGeneration,
      'レンダリング': ProcessingStatus.rendering,
    };

    final currentIndex = stepOrder.indexOf(status);
    final stepIndex = stepOrder.indexOf(stepMap[step]!);

    return currentIndex > stepIndex || status == ProcessingStatus.completed;
  }
}
