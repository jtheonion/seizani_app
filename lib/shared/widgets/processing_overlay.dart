import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../responsive/responsive_layout.dart';
import 'processing_feedback.dart';
import 'modern_card.dart';

/// Unified processing overlay that manages different processing states
class ProcessingOverlay extends StatefulWidget {
  final ProcessingState state;
  final double progress;
  final String? currentStep;
  final List<ProcessingStep>? steps;
  final int currentStepIndex;
  final String? errorTitle;
  final String? errorMessage;
  final String? errorDetails;
  final String? successTitle;
  final String? successSubtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onSuccess;
  final bool showTechnicalDetails;
  final bool dismissible;

  const ProcessingOverlay({
    super.key,
    required this.state,
    this.progress = 0.0,
    this.currentStep,
    this.steps,
    this.currentStepIndex = 0,
    this.errorTitle,
    this.errorMessage,
    this.errorDetails,
    this.successTitle,
    this.successSubtitle,
    this.onRetry,
    this.onCancel,
    this.onSuccess,
    this.showTechnicalDetails = false,
    this.dismissible = false,
  });

  @override
  State<ProcessingOverlay> createState() => _ProcessingOverlayState();

  /// Show processing overlay as a modal dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required ProcessingState state,
    double progress = 0.0,
    String? currentStep,
    List<ProcessingStep>? steps,
    int currentStepIndex = 0,
    String? errorTitle,
    String? errorMessage,
    String? errorDetails,
    String? successTitle,
    String? successSubtitle,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    VoidCallback? onSuccess,
    bool showTechnicalDetails = false,
    bool dismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => ProcessingOverlay(
        state: state,
        progress: progress,
        currentStep: currentStep,
        steps: steps,
        currentStepIndex: currentStepIndex,
        errorTitle: errorTitle,
        errorMessage: errorMessage,
        errorDetails: errorDetails,
        successTitle: successTitle,
        successSubtitle: successSubtitle,
        onRetry: onRetry,
        onCancel: onCancel,
        onSuccess: onSuccess,
        showTechnicalDetails: showTechnicalDetails,
        dismissible: dismissible,
      ),
    );
  }
}

class _ProcessingOverlayState extends State<ProcessingOverlay> {
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7)),
        child: Center(
          child: ResponsiveContainer(
            maxWidth: 500,
            padding: ResponsivePadding.fromContext(context),
            child: ModernCard.constellation(child: _buildContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.state) {
      case ProcessingState.idle:
        return _buildIdleState();
      case ProcessingState.loading:
        return _buildLoadingState();
      case ProcessingState.processing:
        return _buildProcessingState();
      case ProcessingState.success:
        return _buildSuccessState();
      case ProcessingState.error:
        return _buildErrorState();
    }
  }

  Widget _buildIdleState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 64,
            color: AppColors.starGold,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            '画像処理の準備ができました',
            style: AppTextStyles.h6.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            '画像を選択して星座アートの作成を開始してください',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstellationProgress(
            progress: 0.0,
            isIndeterminate: true,
            currentStep: widget.currentStep ?? '初期化中...',
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            '処理を開始しています',
            style: AppTextStyles.h6.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstellationProgress(
            progress: widget.progress,
            currentStep: widget.currentStep,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            '星座アートを作成中',
            style: AppTextStyles.h6.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
          if (widget.steps != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ResponsiveBuilder(
              builder: (context, deviceType, orientation) {
                return ProcessingSteps(
                  steps: widget.steps!,
                  currentStepIndex: widget.currentStepIndex,
                  isVertical: deviceType == DeviceType.mobile,
                );
              },
            ),
          ],
          if (widget.onCancel != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            TextButton(
              onPressed: widget.onCancel,
              child: Text(
                'キャンセル',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return ProcessingSuccess(
      title: widget.successTitle ?? '星座アートが完成しました！',
      subtitle: widget.successSubtitle,
      onContinue: widget.onSuccess ?? () => Navigator.of(context).pop(),
    );
  }

  Widget _buildErrorState() {
    return ProcessingError(
      title: widget.errorTitle ?? 'エラーが発生しました',
      message: widget.errorMessage ?? '処理中に問題が発生しました。再試行してください。',
      technicalDetails: widget.errorDetails,
      onRetry: widget.onRetry,
      onCancel: widget.onCancel ?? () => Navigator.of(context).pop(),
      showTechnicalDetails: widget.showTechnicalDetails,
    );
  }
}

/// Processing state enumeration
enum ProcessingState { idle, loading, processing, success, error }

/// Predefined processing steps for constellation generation
class ConstellationProcessingSteps {
  static const List<ProcessingStep> defaultSteps = [
    ProcessingStep(
      title: '画像解析',
      description: '画像の品質とサイズを確認',
      icon: Icons.image,
    ),
    ProcessingStep(
      title: 'エッジ検出',
      description: '重要な輪郭を特定',
      icon: Icons.find_in_page,
    ),
    ProcessingStep(
      title: '特徴抽出',
      description: '星座の候補点を検出',
      icon: Icons.scatter_plot,
    ),
    ProcessingStep(title: '星座生成', description: '星と線を配置', icon: Icons.star),
    ProcessingStep(title: '最終調整', description: '品質を最適化', icon: Icons.tune),
  ];

  static const List<ProcessingStep> advancedSteps = [
    ProcessingStep(
      title: '前処理',
      description: '画像の正規化とノイズ除去',
      icon: Icons.cleaning_services,
    ),
    ProcessingStep(
      title: 'エッジ検出',
      description: 'Cannyアルゴリズムによる輪郭抽出',
      icon: Icons.find_in_page,
    ),
    ProcessingStep(
      title: '特徴点抽出',
      description: 'Harris角点検出器による候補点抽出',
      icon: Icons.scatter_plot,
    ),
    ProcessingStep(
      title: '星座パターン生成',
      description: 'Delaunay三角分割による接続',
      icon: Icons.device_hub,
    ),
    ProcessingStep(
      title: 'フィルタリング',
      description: '不要な線の除去と最適化',
      icon: Icons.filter_alt,
    ),
    ProcessingStep(
      title: 'スタイル適用',
      description: '色調とエフェクトの調整',
      icon: Icons.palette,
    ),
    ProcessingStep(
      title: '品質検査',
      description: '結果の検証と最終調整',
      icon: Icons.verified,
    ),
  ];
}

/// Processing overlay manager for global state management
class ProcessingOverlayManager {
  static ProcessingOverlayManager? _instance;
  static ProcessingOverlayManager get instance =>
      _instance ??= ProcessingOverlayManager._();

  ProcessingOverlayManager._();

  OverlayEntry? _currentOverlay;
  BuildContext? _context;

  /// Initialize with context
  void initialize(BuildContext context) {
    _context = context;
  }

  /// Show processing overlay
  void show({
    required ProcessingState state,
    double progress = 0.0,
    String? currentStep,
    List<ProcessingStep>? steps,
    int currentStepIndex = 0,
    String? errorTitle,
    String? errorMessage,
    String? errorDetails,
    String? successTitle,
    String? successSubtitle,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    VoidCallback? onSuccess,
    bool showTechnicalDetails = false,
    bool dismissible = false,
  }) {
    if (_context == null) return;

    hide(); // Remove any existing overlay

    _currentOverlay = OverlayEntry(
      builder: (context) => ProcessingOverlay(
        state: state,
        progress: progress,
        currentStep: currentStep,
        steps: steps,
        currentStepIndex: currentStepIndex,
        errorTitle: errorTitle,
        errorMessage: errorMessage,
        errorDetails: errorDetails,
        successTitle: successTitle,
        successSubtitle: successSubtitle,
        onRetry: onRetry,
        onCancel: onCancel,
        onSuccess: onSuccess,
        showTechnicalDetails: showTechnicalDetails,
        dismissible: dismissible,
      ),
    );

    Overlay.of(_context!).insert(_currentOverlay!);
  }

  /// Update current overlay state
  void update({
    ProcessingState? state,
    double? progress,
    String? currentStep,
    int? currentStepIndex,
  }) {
    if (_currentOverlay != null) {
      _currentOverlay!.markNeedsBuild();
    }
  }

  /// Hide current overlay
  void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Clean up
  void dispose() {
    hide();
    _context = null;
  }
}
