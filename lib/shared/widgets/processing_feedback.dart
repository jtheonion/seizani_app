import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../responsive/responsive_layout.dart';

/// Processing progress indicator with constellation theme
class ConstellationProgress extends StatefulWidget {
  final double progress;
  final String? currentStep;
  final bool isIndeterminate;
  final Color? accentColor;
  final double size;

  const ConstellationProgress({
    super.key,
    required this.progress,
    this.currentStep,
    this.isIndeterminate = false,
    this.accentColor,
    this.size = 120.0,
  });

  @override
  State<ConstellationProgress> createState() => _ConstellationProgressState();
}

class _ConstellationProgressState extends State<ConstellationProgress>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isIndeterminate) {
      _rotationController.repeat();
    }
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _rotationController,
                  _pulseController,
                ]),
                builder: (context, child) {
                  return Transform.rotate(
                    angle: widget.isIndeterminate
                        ? _rotationController.value * 2 * math.pi
                        : 0,
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: CustomPaint(
                        painter: ConstellationProgressPainter(
                          progress: widget.progress,
                          accentColor: widget.accentColor ?? AppColors.starGold,
                          isIndeterminate: widget.isIndeterminate,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.currentStep != null) ...[
              const SizedBox(height: AppDimensions.spacingM),
              Text(
                widget.currentStep!,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (!widget.isIndeterminate) ...[
              const SizedBox(height: AppDimensions.spacingS),
              Text(
                '${(widget.progress * 100).toInt()}%',
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.starGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Custom painter for constellation-themed progress indicator
class ConstellationProgressPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isIndeterminate;

  ConstellationProgressPainter({
    required this.progress,
    required this.accentColor,
    required this.isIndeterminate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, radius - 10, backgroundPaint);

    // Draw constellation points around the circle
    _drawConstellationPoints(canvas, center, radius - 10);

    // Draw progress arc
    if (!isIndeterminate) {
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius - 10);
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
    }

    // Draw center star
    _drawCenterStar(canvas, center, radius * 0.3);
  }

  void _drawConstellationPoints(Canvas canvas, Offset center, double radius) {
    final pointPaint = Paint()
      ..color = accentColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final numPoints = 8;
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      final pointRadius = isIndeterminate || (i / numPoints) <= progress
          ? 3.0
          : 1.5;

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.drawCircle(Offset(x, y), pointRadius, pointPaint);
    }
  }

  void _drawCenterStar(Canvas canvas, Offset center, double radius) {
    final starPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final path = Path();
    const numPoints = 5;
    final outerRadius = radius;
    final innerRadius = radius * 0.4;

    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi) / numPoints;
      final currentRadius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(ConstellationProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isIndeterminate != isIndeterminate;
  }
}

/// Processing steps indicator
class ProcessingSteps extends StatelessWidget {
  final List<ProcessingStep> steps;
  final int currentStepIndex;
  final bool isVertical;

  const ProcessingSteps({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        final isVerticalLayout = isVertical || deviceType == DeviceType.mobile;

        return isVerticalLayout
            ? _buildVerticalSteps(context)
            : _buildHorizontalSteps(context);
      },
    );
  }

  Widget _buildVerticalSteps(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildStepItem(context, steps[i], i),
          if (i < steps.length - 1)
            _buildVerticalConnector(i < currentStepIndex),
        ],
      ],
    );
  }

  Widget _buildHorizontalSteps(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(child: _buildStepItem(context, steps[i], i)),
          if (i < steps.length - 1)
            _buildHorizontalConnector(i < currentStepIndex),
        ],
      ],
    );
  }

  Widget _buildStepItem(BuildContext context, ProcessingStep step, int index) {
    final isCompleted = index < currentStepIndex;
    final isCurrent = index == currentStepIndex;

    Color statusColor;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (isCurrent) {
      statusColor = AppColors.starGold;
      statusIcon = Icons.radio_button_checked;
    } else {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: AppDimensions.iconM),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTextStyles.body2.copyWith(
                    color: isCurrent
                        ? AppColors.onSurface
                        : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (step.description != null) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    step.description!,
                    style: AppTextStyles.body3.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalConnector(bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(left: AppDimensions.iconM / 2),
      child: Container(
        width: 2,
        height: AppDimensions.spacingL,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.success : AppColors.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildHorizontalConnector(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingS),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.success : AppColors.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Processing step data model
class ProcessingStep {
  final String title;
  final String? description;
  final IconData? icon;

  const ProcessingStep({required this.title, this.description, this.icon});
}

/// Error state widget for processing failures
class ProcessingError extends StatefulWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final bool showTechnicalDetails;

  const ProcessingError({
    super.key,
    required this.title,
    required this.message,
    this.technicalDetails,
    this.onRetry,
    this.onCancel,
    this.showTechnicalDetails = false,
  });

  @override
  State<ProcessingError> createState() => _ProcessingErrorState();
}

class _ProcessingErrorState extends State<ProcessingError>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final shake = math.sin(_shakeAnimation.value * math.pi * 3) * 3;
            return Transform.translate(
              offset: Offset(shake, 0),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      widget.title,
                      style: AppTextStyles.h6.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      widget.message,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.technicalDetails != null &&
                        widget.showTechnicalDetails) ...[
                      const SizedBox(height: AppDimensions.spacingM),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showDetails = !_showDetails),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showDetails
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textSecondary,
                            ),
                            Text(
                              _showDetails ? '技術的詳細を非表示' : '技術的詳細を表示',
                              style: AppTextStyles.body3.copyWith(
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showDetails) ...[
                        const SizedBox(height: AppDimensions.spacingS),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusM,
                            ),
                          ),
                          child: Text(
                            widget.technicalDetails!,
                            style: AppTextStyles.body3.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppDimensions.spacingL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.onCancel != null) ...[
                          TextButton(
                            onPressed: widget.onCancel,
                            child: Text(
                              'キャンセル',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                        ],
                        if (widget.onRetry != null)
                          ElevatedButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.onPrimary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Success animation widget for completed processing
class ProcessingSuccess extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onContinue;
  final Duration animationDuration;

  const ProcessingSuccess({
    super.key,
    required this.title,
    this.subtitle,
    this.onContinue,
    this.animationDuration = const Duration(milliseconds: 2000),
  });

  @override
  State<ProcessingSuccess> createState() => _ProcessingSuccessState();
}

class _ProcessingSuccessState extends State<ProcessingSuccess>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _sparkleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimation();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _sparkleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_sparkleController);
  }

  void _startAnimation() async {
    await _scaleController.forward();
    _sparkleController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        return AnimatedBuilder(
          animation: Listenable.merge([_scaleController, _sparkleController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(80, 80),
                          painter: SparklesPainter(
                            animation: _sparkleAnimation,
                            color: AppColors.starGold,
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingL),
                    Text(
                      widget.title,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: AppDimensions.spacingM),
                      Text(
                        widget.subtitle!,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (widget.onContinue != null) ...[
                      const SizedBox(height: AppDimensions.spacingL),
                      ElevatedButton(
                        onPressed: widget.onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('続行'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Custom painter for sparkles animation
class SparklesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  SparklesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Draw sparkles around the success icon
    const numSparkles = 8;
    for (int i = 0; i < numSparkles; i++) {
      final angle = (i / numSparkles) * 2 * math.pi;
      final sparkleRadius =
          radius + 10 + math.sin(animation.value * 2 * math.pi) * 5;

      final x = center.dx + sparkleRadius * math.cos(angle);
      final y = center.dy + sparkleRadius * math.sin(angle);

      _drawSparkle(canvas, Offset(x, y), paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, Paint paint) {
    const size = 4.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + 1, center.dy - 1)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx + 1, center.dy + 1)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - 1, center.dy + 1)
      ..lineTo(center.dx - size, center.dy)
      ..lineTo(center.dx - 1, center.dy - 1)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
