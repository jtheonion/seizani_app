import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/constants/app_colors.dart';

class ConstellationBackgroundWidget extends StatefulWidget {
  const ConstellationBackgroundWidget({super.key});

  @override
  State<ConstellationBackgroundWidget> createState() =>
      _ConstellationBackgroundWidgetState();
}

class _ConstellationBackgroundWidgetState
    extends State<ConstellationBackgroundWidget>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late Animation<double> _twinkleAnimation;

  @override
  void initState() {
    super.initState();

    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _twinkleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _twinkleController, curve: Curves.easeInOut),
    );

    _twinkleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.nebulaPrimary,
        ),
      ),
      child: AnimatedBuilder(
        animation: _twinkleAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: ConstellationPainter(opacity: _twinkleAnimation.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class ConstellationPainter extends CustomPainter {
  final double opacity;
  final Random _random = Random(42); // Fixed seed for consistent pattern

  ConstellationPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    _drawStars(canvas, size);

    // Draw constellation lines
    _drawConstellationLines(canvas, size);
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.starSilver.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.fill;

    // Generate star positions
    const starCount = 50;
    for (int i = 0; i < starCount; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 2 + 1;

      // Vary opacity for twinkling effect
      final starOpacity = opacity * (0.3 + _random.nextDouble() * 0.7);
      paint.color = AppColors.starSilver.withOpacity(starOpacity);

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Draw star glow effect
      if (radius > 1.5) {
        final glowPaint = Paint()
          ..color = AppColors.starGold.withOpacity(starOpacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawCircle(Offset(x, y), radius * 2, glowPaint);
      }
    }
  }

  void _drawConstellationLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.constellationLine.withOpacity(opacity * 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Create some constellation patterns
    _drawBigDipper(canvas, size, paint);
    _drawOrion(canvas, size, paint);
    _drawCassiopeia(canvas, size, paint);
  }

  void _drawBigDipper(Canvas canvas, Size size, Paint paint) {
    if (size.width < 200 || size.height < 200) return;

    final points = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.15, size.height * 0.25),
      Offset(size.width * 0.2, size.height * 0.22),
      Offset(size.width * 0.25, size.height * 0.18),
      Offset(size.width * 0.28, size.height * 0.15),
      Offset(size.width * 0.32, size.height * 0.12),
      Offset(size.width * 0.35, size.height * 0.1),
    ];

    _drawConstellation(canvas, points, paint);
  }

  void _drawOrion(Canvas canvas, Size size, Paint paint) {
    if (size.width < 200 || size.height < 200) return;

    final points = [
      Offset(size.width * 0.7, size.height * 0.6),
      Offset(size.width * 0.72, size.height * 0.65),
      Offset(size.width * 0.75, size.height * 0.7),
      Offset(size.width * 0.78, size.height * 0.75),
      Offset(size.width * 0.8, size.height * 0.8),
    ];

    _drawConstellation(canvas, points, paint);
  }

  void _drawCassiopeia(Canvas canvas, Size size, Paint paint) {
    if (size.width < 200 || size.height < 200) return;

    final points = [
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.65, size.height * 0.25),
      Offset(size.width * 0.7, size.height * 0.28),
      Offset(size.width * 0.75, size.height * 0.22),
      Offset(size.width * 0.8, size.height * 0.27),
    ];

    _drawConstellation(canvas, points, paint);
  }

  void _drawConstellation(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;

    // Draw lines connecting the stars
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw stars at constellation points
    final starPaint = Paint()
      ..color = AppColors.starGold.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 2.5, starPaint);

      // Add glow effect
      final glowPaint = Paint()
        ..color = AppColors.starGold.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(point, 5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
