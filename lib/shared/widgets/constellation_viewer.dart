import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/entities/constellation_entity.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../responsive/responsive_layout.dart';

/// Interactive constellation viewer component
class ConstellationViewer extends StatefulWidget {
  final ConstellationEntity constellation;
  final bool isInteractive;
  final bool showAnimations;
  final VoidCallback? onTap;
  final Function(ConstellationPoint)? onPointTap;
  final Function(ConstellationLine)? onLineTap;
  final double? aspectRatio;
  final ConstellationTheme theme;

  const ConstellationViewer({
    super.key,
    required this.constellation,
    this.isInteractive = false,
    this.showAnimations = true,
    this.onTap,
    this.onPointTap,
    this.onLineTap,
    this.aspectRatio,
    this.theme = ConstellationTheme.cosmic,
  });

  @override
  State<ConstellationViewer> createState() => _ConstellationViewerState();
}

class _ConstellationViewerState extends State<ConstellationViewer>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _pulseController;
  late Animation<double> _twinkleAnimation;
  late Animation<double> _pulseAnimation;

  TransformationController? _transformationController;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    if (widget.isInteractive) {
      _transformationController = TransformationController();
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _pulseController.dispose();
    _transformationController?.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _twinkleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _twinkleController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticInOut),
    );

    if (widget.showAnimations) {
      _twinkleController.repeat(reverse: true);
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        Widget viewer = AspectRatio(
          aspectRatio: widget.aspectRatio ?? _getDefaultAspectRatio(),
          child: Container(
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(
                color: AppColors.border.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              child: _buildConstellationCanvas(),
            ),
          ),
        );

        if (widget.isInteractive && _transformationController != null) {
          viewer = InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            onInteractionStart: (details) {
              _scale = _transformationController!.value.getMaxScaleOnAxis();
            },
            onInteractionUpdate: (details) {
              _scale = _transformationController!.value.getMaxScaleOnAxis();
            },
            child: viewer,
          );
        }

        return GestureDetector(onTap: widget.onTap, child: viewer);
      },
    );
  }

  Widget _buildConstellationCanvas() {
    return AnimatedBuilder(
      animation: Listenable.merge([_twinkleController, _pulseController]),
      builder: (context, child) {
        return CustomPaint(
          painter: ConstellationPainter(
            constellation: widget.constellation,
            theme: widget.theme,
            twinkleValue: _twinkleAnimation.value,
            pulseValue: _pulseAnimation.value,
            scale: _scale,
            showAnimations: widget.showAnimations,
          ),
          child: Container(),
        );
      },
    );
  }

  double _getDefaultAspectRatio() {
    final width = widget.constellation.width.toDouble();
    final height = widget.constellation.height.toDouble();
    if (width > 0 && height > 0) {
      return width / height;
    }
    return 16 / 9; // Default aspect ratio
  }

  Color _getBackgroundColor() {
    switch (widget.theme) {
      case ConstellationTheme.cosmic:
        return const Color(0xFF0A0A1A);
      case ConstellationTheme.nebula:
        return const Color(0xFF1A1B2E);
      case ConstellationTheme.aurora:
        return const Color(0xFF0D1117);
      case ConstellationTheme.classic:
        return AppColors.background;
    }
  }
}

/// Custom painter for constellation rendering
class ConstellationPainter extends CustomPainter {
  final ConstellationEntity constellation;
  final ConstellationTheme theme;
  final double twinkleValue;
  final double pulseValue;
  final double scale;
  final bool showAnimations;

  ConstellationPainter({
    required this.constellation,
    required this.theme,
    required this.twinkleValue,
    required this.pulseValue,
    required this.scale,
    required this.showAnimations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factor to fit constellation in canvas
    final scaleX = size.width / constellation.width;
    final scaleY = size.height / constellation.height;
    final paintScale = math.min(scaleX, scaleY);

    // Create transformation matrix
    canvas.save();
    canvas.scale(paintScale);

    // Paint background effects
    _paintBackground(canvas, size, paintScale);

    // Paint constellation lines first (behind stars)
    _paintConstellationLines(canvas);

    // Paint constellation points (stars)
    _paintConstellationPoints(canvas);

    // Paint glow effects
    if (showAnimations) {
      _paintGlowEffects(canvas);
    }

    canvas.restore();
  }

  void _paintBackground(Canvas canvas, Size size, double paintScale) {
    // Create starfield background
    final random = math.Random(42); // Fixed seed for consistent stars
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * (size.width / paintScale);
      final y = random.nextDouble() * (size.height / paintScale);
      final radius = random.nextDouble() * 1.5 + 0.5;

      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _paintConstellationLines(Canvas canvas) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final line in constellation.lines) {
      final startPoint = constellation.points.firstWhere(
        (p) => p.id == line.startPointId,
      );
      final endPoint = constellation.points.firstWhere(
        (p) => p.id == line.endPointId,
      );

      // Get theme colors
      linePaint.color = _getLineColor(line.opacity);
      linePaint.strokeWidth =
          line.thickness * (showAnimations ? pulseValue : 1.0);

      // Add glow effect
      if (showAnimations && theme != ConstellationTheme.classic) {
        final glowPaint = Paint()
          ..color = _getLineColor(line.opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = line.thickness * 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawLine(
          Offset(startPoint.x, startPoint.y),
          Offset(endPoint.x, endPoint.y),
          glowPaint,
        );
      }

      // Draw main line
      canvas.drawLine(
        Offset(startPoint.x, startPoint.y),
        Offset(endPoint.x, endPoint.y),
        linePaint,
      );
    }
  }

  void _paintConstellationPoints(Canvas canvas) {
    for (final point in constellation.points) {
      _paintStar(canvas, point);
    }
  }

  void _paintStar(Canvas canvas, ConstellationPoint point) {
    final center = Offset(point.x, point.y);
    final baseRadius = 3.0 * point.intensity;
    final animatedRadius = baseRadius * (showAnimations ? twinkleValue : 1.0);

    // Outer glow
    if (showAnimations && theme != ConstellationTheme.classic) {
      final glowPaint = Paint()
        ..color = _getStarColor(point.intensity * 0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, animatedRadius * 3, glowPaint);
    }

    // Main star
    final starPaint = Paint()
      ..color = _getStarColor(point.intensity * twinkleValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, animatedRadius, starPaint);

    // Inner bright core
    final corePaint = Paint()
      ..color = _getStarCoreColor()
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, animatedRadius * 0.6, corePaint);

    // Star spikes for brighter stars
    if (point.intensity > 0.7) {
      _paintStarSpikes(canvas, center, animatedRadius, point.intensity);
    }
  }

  void _paintStarSpikes(
    Canvas canvas,
    Offset center,
    double radius,
    double intensity,
  ) {
    final spikePaint = Paint()
      ..color = _getStarColor(intensity * 0.8)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final spikeLength = radius * 2.5;

    // Draw 4 spikes
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + (math.pi / 4);
      final start =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final end =
          center +
          Offset(math.cos(angle) * spikeLength, math.sin(angle) * spikeLength);

      canvas.drawLine(start, end, spikePaint);
    }
  }

  void _paintGlowEffects(Canvas canvas) {
    // Add overall constellation glow
    final bounds = _getConstellationBounds();
    final glowPaint = Paint()
      ..color = _getThemeAccentColor().withOpacity(0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawRect(bounds, glowPaint);
  }

  Rect _getConstellationBounds() {
    if (constellation.points.isEmpty) return Rect.zero;

    double minX = constellation.points.first.x;
    double maxX = constellation.points.first.x;
    double minY = constellation.points.first.y;
    double maxY = constellation.points.first.y;

    for (final point in constellation.points) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }

    return Rect.fromLTRB(minX - 20, minY - 20, maxX + 20, maxY + 20);
  }

  Color _getStarColor(double intensity) {
    switch (theme) {
      case ConstellationTheme.cosmic:
        return Color.lerp(AppColors.starSilver, AppColors.starGold, intensity)!;
      case ConstellationTheme.nebula:
        return Color.lerp(
          const Color(0xFF4ECDC4),
          const Color(0xFFFFE66D),
          intensity,
        )!;
      case ConstellationTheme.aurora:
        return Color.lerp(
          const Color(0xFF00F5FF),
          const Color(0xFF00FF7F),
          intensity,
        )!;
      case ConstellationTheme.classic:
        return Colors.white.withOpacity(intensity);
    }
  }

  Color _getStarCoreColor() {
    switch (theme) {
      case ConstellationTheme.cosmic:
        return AppColors.starGold;
      case ConstellationTheme.nebula:
        return const Color(0xFFFFE66D);
      case ConstellationTheme.aurora:
        return const Color(0xFF00FFFF);
      case ConstellationTheme.classic:
        return Colors.white;
    }
  }

  Color _getLineColor(double opacity) {
    Color baseColor;
    switch (theme) {
      case ConstellationTheme.cosmic:
        baseColor = AppColors.constellationLine;
        break;
      case ConstellationTheme.nebula:
        baseColor = const Color(0xFF667EEA);
        break;
      case ConstellationTheme.aurora:
        baseColor = const Color(0xFF00FF7F);
        break;
      case ConstellationTheme.classic:
        baseColor = Colors.white70;
        break;
    }
    return baseColor.withOpacity(opacity);
  }

  Color _getThemeAccentColor() {
    switch (theme) {
      case ConstellationTheme.cosmic:
        return AppColors.starGold;
      case ConstellationTheme.nebula:
        return const Color(0xFF667EEA);
      case ConstellationTheme.aurora:
        return const Color(0xFF00FF7F);
      case ConstellationTheme.classic:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) {
    return oldDelegate.constellation != constellation ||
        oldDelegate.theme != theme ||
        oldDelegate.twinkleValue != twinkleValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.scale != scale;
  }
}

/// Constellation theme enumeration
enum ConstellationTheme {
  cosmic, // Gold and teal space theme
  nebula, // Purple and blue nebula theme
  aurora, // Green and cyan aurora theme
  classic, // Simple white on black
}

/// Constellation preview component for thumbnails
class ConstellationPreview extends StatelessWidget {
  final ConstellationEntity constellation;
  final double size;
  final ConstellationTheme theme;
  final VoidCallback? onTap;

  const ConstellationPreview({
    super.key,
    required this.constellation,
    this.size = 120,
    this.theme = ConstellationTheme.cosmic,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: AppColors.border.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: CustomPaint(
            painter: ConstellationPainter(
              constellation: constellation,
              theme: theme,
              twinkleValue: 1.0,
              pulseValue: 1.0,
              scale: 1.0,
              showAnimations: false,
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (theme) {
      case ConstellationTheme.cosmic:
        return const Color(0xFF0A0A1A);
      case ConstellationTheme.nebula:
        return const Color(0xFF1A1B2E);
      case ConstellationTheme.aurora:
        return const Color(0xFF0D1117);
      case ConstellationTheme.classic:
        return AppColors.background;
    }
  }
}

/// Constellation comparison widget
class ConstellationComparison extends StatelessWidget {
  final ConstellationEntity original;
  final ConstellationEntity? processed;
  final bool showLabels;

  const ConstellationComparison({
    super.key,
    required this.original,
    this.processed,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  if (showLabels) ...[
                    Text(
                      'オリジナル',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                  ],
                  ConstellationViewer(
                    constellation: original,
                    theme: ConstellationTheme.classic,
                    showAnimations: false,
                  ),
                ],
              ),
            ),

            if (processed != null) ...[
              const SizedBox(width: AppDimensions.spacingM),

              Expanded(
                child: Column(
                  children: [
                    if (showLabels) ...[
                      Text(
                        '星座アート',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                    ],
                    ConstellationViewer(
                      constellation: processed!,
                      theme: ConstellationTheme.cosmic,
                      showAnimations: true,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
