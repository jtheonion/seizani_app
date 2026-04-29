import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary colors - 星座テーマの深い宇宙カラー
  static const Color primary = Color(0xFF1A1B2E);
  static const Color primaryVariant = Color(0xFF16213E);
  static const Color secondary = Color(0xFF0F4C75);
  static const Color secondaryVariant = Color(0xFF3282B8);

  // Accent colors - 星と星座線のカラー
  static const Color starGold = Color(0xFFFFE66D);
  static const Color onStarGold = Color(0xFF1A1B2E); // Dark text on star gold
  static const Color starSilver = Color(0xFFE8F4FD);
  static const Color constellationLine = Color(0xFF4ECDC4);
  static const Color accent = Color(0xFF6C5CE7);

  // Background colors
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF21262D);

  // Text colors
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onBackground = Color(0xFFE6EDF3);
  static const Color onSurface = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);

  // Status colors
  static const Color success = Color(0xFF238636);
  static const Color error = Color(0xFFDA3633);
  static const Color warning = Color(0xFFBF8700);
  static const Color info = Color(0xFF0969DA);

  // Interactive colors
  static const Color disabled = Color(0xFF6E7681);
  static const Color border = Color(0xFF30363D);
  static const Color divider = Color(0xFF21262D);

  // Gradient colors for celestial effects
  static const List<Color> nebulaPrimary = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
    Color(0xFF1A1B2E),
  ];

  static const List<Color> nebulaSecondary = [
    Color(0xFF4ECDC4),
    Color(0xFF44A08D),
    Color(0xFF0F4C75),
  ];

  static const List<Color> starGradient = [
    Color(0xFFFFE66D),
    Color(0xFFFF6B6B),
    Color(0xFFE8F4FD),
  ];
}
