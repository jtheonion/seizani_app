import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../responsive/responsive_layout.dart';

/// Modern card component with constellation theme
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final ModernCardStyle style;
  final VoidCallback? onTap;
  final bool isInteractive;
  final bool showBorder;
  final double? borderRadius;
  final List<BoxShadow>? customShadow;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.style = ModernCardStyle.surface,
    this.onTap,
    this.isInteractive = false,
    this.showBorder = false,
    this.borderRadius,
    this.customShadow,
  });

  const ModernCard.surface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isInteractive = false,
    this.showBorder = false,
    this.borderRadius,
    this.customShadow,
  }) : style = ModernCardStyle.surface;

  const ModernCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isInteractive = false,
    this.showBorder = false,
    this.borderRadius,
    this.customShadow,
  }) : style = ModernCardStyle.elevated;

  const ModernCard.constellation({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isInteractive = false,
    this.showBorder = true,
    this.borderRadius,
    this.customShadow,
  }) : style = ModernCardStyle.constellation;

  const ModernCard.glass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isInteractive = false,
    this.showBorder = true,
    this.borderRadius,
    this.customShadow,
  }) : style = ModernCardStyle.glass;

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

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
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isInteractive && _isPressed
                  ? _scaleAnimation.value
                  : 1.0,
              child: _buildCard(context),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final cardConfig = _getCardConfig(widget.style);

    Widget card = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding ?? cardConfig.padding,
      decoration: _buildDecoration(cardConfig),
      child: widget.child,
    );

    if (widget.onTap != null || widget.isInteractive) {
      card = GestureDetector(
        onTapDown: widget.isInteractive ? (_) => _handleTapDown() : null,
        onTapUp: widget.isInteractive ? (_) => _handleTapUp() : null,
        onTapCancel: widget.isInteractive ? () => _handleTapUp() : null,
        onTap: widget.onTap,
        child: card,
      );
    }

    return card;
  }

  void _handleTapDown() {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _handleTapUp() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  BoxDecoration _buildDecoration(CardConfig config) {
    List<BoxShadow>? shadows = widget.customShadow ?? config.shadows;

    // Enhance shadows when card is interactive and pressed
    if (widget.isInteractive && _isPressed && shadows != null) {
      shadows = shadows.map((shadow) {
        return BoxShadow(
          color: shadow.color.withOpacity(shadow.color.opacity * 0.5),
          blurRadius: shadow.blurRadius * 0.8,
          offset: shadow.offset * 0.8,
          spreadRadius: shadow.spreadRadius,
        );
      }).toList();
    }

    return BoxDecoration(
      color: config.backgroundColor,
      gradient: config.gradient,
      borderRadius: BorderRadius.circular(
        widget.borderRadius ?? config.borderRadius,
      ),
      border: widget.showBorder || config.hasBorder
          ? Border.all(
              color: config.borderColor ?? AppColors.border,
              width: config.borderWidth,
            )
          : null,
      boxShadow: shadows,
    );
  }

  CardConfig _getCardConfig(ModernCardStyle style) {
    switch (style) {
      case ModernCardStyle.surface:
        return CardConfig.surface();
      case ModernCardStyle.elevated:
        return CardConfig.elevated();
      case ModernCardStyle.constellation:
        return CardConfig.constellation();
      case ModernCardStyle.glass:
        return CardConfig.glass();
    }
  }
}

/// Card style enumeration
enum ModernCardStyle { surface, elevated, constellation, glass }

/// Card configuration class
class CardConfig {
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final bool hasBorder;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final List<BoxShadow>? shadows;

  const CardConfig({
    this.backgroundColor,
    this.gradient,
    required this.borderRadius,
    this.hasBorder = false,
    this.borderColor,
    this.borderWidth = 1.0,
    required this.padding,
    this.shadows,
  });

  factory CardConfig.surface() {
    return const CardConfig(
      backgroundColor: AppColors.surface,
      borderRadius: AppDimensions.radiusL,
      padding: EdgeInsets.all(AppDimensions.paddingM),
      shadows: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  factory CardConfig.elevated() {
    return const CardConfig(
      backgroundColor: AppColors.surfaceVariant,
      borderRadius: AppDimensions.radiusXl,
      padding: EdgeInsets.all(AppDimensions.paddingL),
      shadows: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  factory CardConfig.constellation() {
    return CardConfig(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surface, Color(0xFF1A1D2E), AppColors.surface],
        stops: [0.0, 0.5, 1.0],
      ),
      borderRadius: AppDimensions.radiusXl,
      hasBorder: true,
      borderColor: AppColors.starGold.withOpacity(0.3),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      shadows: [
        BoxShadow(
          color: AppColors.starGold.withOpacity(0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.constellationLine.withOpacity(0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  factory CardConfig.glass() {
    return CardConfig(
      backgroundColor: AppColors.surface.withOpacity(0.1),
      borderRadius: AppDimensions.radiusXl,
      hasBorder: true,
      borderColor: Colors.white.withOpacity(0.1),
      borderWidth: 1.0,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      shadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

/// Specialized image card for photo display
class ImageCard extends StatelessWidget {
  final Widget image;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final double? aspectRatio;
  final bool showOverlay;

  const ImageCard({
    super.key,
    required this.image,
    this.title,
    this.subtitle,
    this.actions,
    this.onTap,
    this.aspectRatio,
    this.showOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.surface(
      isInteractive: onTap != null,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          _buildImageSection(),

          // Content section
          if (title != null || subtitle != null || actions != null)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: _buildContentSection(context),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    Widget imageWidget = ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusL),
      ),
      child: AspectRatio(aspectRatio: aspectRatio ?? 16 / 9, child: image),
    );

    if (showOverlay) {
      imageWidget = Stack(
        children: [
          imageWidget,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return imageWidget;
  }

  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        if (title != null && subtitle != null)
          const SizedBox(height: AppDimensions.spacingS),

        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

        if (actions != null) ...[
          const SizedBox(height: AppDimensions.spacingM),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
        ],
      ],
    );
  }
}

/// Stats card for displaying metrics
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? AppColors.accent;

    return ModernCard.surface(
      isInteractive: onTap != null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: effectiveAccentColor,
                    size: AppDimensions.iconM,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: AppDimensions.spacingM),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
