import 'package:flutter/material.dart';
import '../widgets/constellation_background_widget.dart';
import '../../shared/constants/app_colors.dart';
import '../../shared/constants/app_text_styles.dart';
import '../../shared/constants/app_dimensions.dart';

/// Splash screen shown during app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated constellation background
          const ConstellationBackgroundWidget(),

          // Main content
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App logo/icon
                        _buildAppLogo(),

                        const SizedBox(height: AppDimensions.spacingXxl),

                        // App title
                        _buildAppTitle(),

                        const SizedBox(height: AppDimensions.spacingL),

                        // Tagline
                        _buildTagline(),

                        const SizedBox(height: AppDimensions.spacingXxl * 2),

                        // Loading indicator
                        _buildLoadingIndicator(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Version info at bottom
          Positioned(
            bottom: AppDimensions.paddingXl,
            left: 0,
            right: 0,
            child: _buildVersionInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.starGold.withOpacity(0.8),
            AppColors.starGold.withOpacity(0.3),
            Colors.transparent,
          ],
          stops: const [0.3, 0.7, 1.0],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withOpacity(0.9),
          border: Border.all(color: AppColors.starGold, width: 2),
        ),
        child: const Icon(
          Icons.auto_awesome,
          size: 64,
          color: AppColors.starGold,
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        Text(
          'Seizani',
          style: AppTextStyles.h1.copyWith(
            color: AppColors.starGold,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          '星座に',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Text(
      '写真から美しい星座アートを作成',
      style: AppTextStyles.body1.copyWith(
        color: AppColors.textSecondary,
        fontSize: 16,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.starGold.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'アプリを準備しています...',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Text(
      'v1.0.0',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary.withOpacity(0.5),
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Simple splash screen without animations for faster loading
class SimpleSplashScreen extends StatelessWidget {
  const SimpleSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: AppColors.starGold),
            SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Seizani',
              style: TextStyle(
                color: AppColors.starGold,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppDimensions.spacingM),
            Text(
              '星座に',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: AppDimensions.spacingXxl),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.starGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
