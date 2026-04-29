import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../responsive/responsive_layout.dart';

/// Modern button component with constellation theme
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ModernButtonStyle style;
  final ModernButtonSize size;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isExpanded;
  final EdgeInsets? customPadding;
  final double? customWidth;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = ModernButtonStyle.primary,
    this.size = ModernButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.customPadding,
    this.customWidth,
  });

  const ModernButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.customPadding,
    this.customWidth,
  }) : style = ModernButtonStyle.primary,
       size = ModernButtonSize.medium;

  const ModernButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.customPadding,
    this.customWidth,
  }) : style = ModernButtonStyle.secondary,
       size = ModernButtonSize.medium;

  const ModernButton.outlined({
    super.key,
    required this.text,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.customPadding,
    this.customWidth,
  }) : style = ModernButtonStyle.outlined,
       size = ModernButtonSize.medium;

  const ModernButton.constellation({
    super.key,
    required this.text,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.customPadding,
    this.customWidth,
  }) : style = ModernButtonStyle.constellation,
       size = ModernButtonSize.medium;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
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
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.style == ModernButtonStyle.constellation) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed ? _scaleAnimation.value : 1.0,
              child: _buildButton(context),
            );
          },
        );
      },
    );
  }

  Widget _buildButton(BuildContext context) {
    final buttonConfig = _getButtonConfig();
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Widget button = Container(
      width: widget.isExpanded ? double.infinity : widget.customWidth,
      height: buttonConfig.height,
      padding: widget.customPadding ?? buttonConfig.padding,
      decoration: _buildDecoration(buttonConfig, isEnabled),
      child: _buildButtonContent(buttonConfig, isEnabled),
    );

    if (isEnabled) {
      button = GestureDetector(
        onTapDown: (_) => _handleTapDown(),
        onTapUp: (_) => _handleTapUp(),
        onTapCancel: () => _handleTapUp(),
        onTap: widget.onPressed,
        child: button,
      );
    }

    return button;
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

  BoxDecoration _buildDecoration(ButtonConfig config, bool isEnabled) {
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return BoxDecoration(
          gradient: isEnabled ? config.gradient : null,
          color: isEnabled ? null : AppColors.disabled,
          borderRadius: BorderRadius.circular(config.borderRadius),
          boxShadow: isEnabled ? config.shadow : null,
        );

      case ModernButtonStyle.secondary:
        return BoxDecoration(
          color: isEnabled ? config.backgroundColor : AppColors.disabled,
          borderRadius: BorderRadius.circular(config.borderRadius),
          boxShadow: isEnabled ? config.shadow : null,
        );

      case ModernButtonStyle.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: isEnabled ? config.borderColor! : AppColors.disabled,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(config.borderRadius),
        );

      case ModernButtonStyle.constellation:
        return BoxDecoration(
          gradient: isEnabled ? _buildConstellationGradient() : null,
          color: isEnabled ? null : AppColors.disabled,
          borderRadius: BorderRadius.circular(config.borderRadius),
          boxShadow: isEnabled ? _buildConstellationShadow() : null,
        );
    }
  }

  LinearGradient _buildConstellationGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.starGold.withOpacity(0.8),
        AppColors.constellationLine.withOpacity(0.6),
        AppColors.accent.withOpacity(0.8),
      ],
      stops: [0.0, _shimmerAnimation.value, 1.0],
    );
  }

  List<BoxShadow> _buildConstellationShadow() {
    return [
      BoxShadow(
        color: AppColors.starGold.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: AppColors.constellationLine.withOpacity(0.2),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Widget _buildButtonContent(ButtonConfig config, bool isEnabled) {
    final textColor = isEnabled ? config.textColor : AppColors.textSecondary;

    if (widget.isLoading) {
      return _buildLoadingContent(config, textColor);
    }

    final children = <Widget>[];

    if (widget.leadingIcon != null) {
      children.add(_buildIcon(widget.leadingIcon!, textColor));
      children.add(SizedBox(width: config.iconSpacing));
    }

    children.add(_buildText(config, textColor));

    if (widget.trailingIcon != null) {
      children.add(SizedBox(width: config.iconSpacing));
      children.add(_buildIcon(widget.trailingIcon!, textColor));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildLoadingContent(ButtonConfig config, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: config.iconSize,
          height: config.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
        SizedBox(width: config.iconSpacing),
        Text(
          'Processing...',
          style: config.textStyle.copyWith(color: textColor),
        ),
      ],
    );
  }

  Widget _buildIcon(Widget icon, Color color) {
    return IconTheme(
      data: IconThemeData(color: color, size: _getButtonConfig().iconSize),
      child: icon,
    );
  }

  Widget _buildText(ButtonConfig config, Color textColor) {
    return Text(
      widget.text,
      style: config.textStyle.copyWith(color: textColor),
      textAlign: TextAlign.center,
    );
  }

  ButtonConfig _getButtonConfig() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return ButtonConfig.small(widget.style);
      case ModernButtonSize.medium:
        return ButtonConfig.medium(widget.style);
      case ModernButtonSize.large:
        return ButtonConfig.large(widget.style);
    }
  }
}

/// Button style enumeration
enum ModernButtonStyle { primary, secondary, outlined, constellation }

/// Button size enumeration
enum ModernButtonSize { small, medium, large }

/// Button configuration class
class ButtonConfig {
  final double height;
  final EdgeInsets padding;
  final double borderRadius;
  final TextStyle textStyle;
  final Color textColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final double iconSize;
  final double iconSpacing;

  const ButtonConfig({
    required this.height,
    required this.padding,
    required this.borderRadius,
    required this.textStyle,
    required this.textColor,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.shadow,
    required this.iconSize,
    required this.iconSpacing,
  });

  factory ButtonConfig.small(ModernButtonStyle style) {
    return ButtonConfig(
      height: AppDimensions.buttonHeightS,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      borderRadius: AppDimensions.radiusM,
      textStyle: AppTextStyles.buttonMedium.copyWith(fontSize: 14),
      textColor: _getTextColor(style),
      backgroundColor: _getBackgroundColor(style),
      gradient: _getGradient(style),
      borderColor: _getBorderColor(style),
      shadow: _getShadow(style),
      iconSize: AppDimensions.iconS,
      iconSpacing: AppDimensions.spacingS,
    );
  }

  factory ButtonConfig.medium(ModernButtonStyle style) {
    return ButtonConfig(
      height: AppDimensions.buttonHeightM,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      borderRadius: AppDimensions.radiusL,
      textStyle: AppTextStyles.buttonMedium,
      textColor: _getTextColor(style),
      backgroundColor: _getBackgroundColor(style),
      gradient: _getGradient(style),
      borderColor: _getBorderColor(style),
      shadow: _getShadow(style),
      iconSize: AppDimensions.iconM,
      iconSpacing: AppDimensions.spacingM,
    );
  }

  factory ButtonConfig.large(ModernButtonStyle style) {
    return ButtonConfig(
      height: AppDimensions.buttonHeightL,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingXl,
        vertical: AppDimensions.paddingL,
      ),
      borderRadius: AppDimensions.radiusXl,
      textStyle: AppTextStyles.buttonLarge.copyWith(fontSize: 18),
      textColor: _getTextColor(style),
      backgroundColor: _getBackgroundColor(style),
      gradient: _getGradient(style),
      borderColor: _getBorderColor(style),
      shadow: _getShadow(style),
      iconSize: AppDimensions.iconL,
      iconSpacing: AppDimensions.spacingM,
    );
  }

  static Color _getTextColor(ModernButtonStyle style) {
    switch (style) {
      case ModernButtonStyle.primary:
      case ModernButtonStyle.constellation:
        return AppColors.onPrimary;
      case ModernButtonStyle.secondary:
        return AppColors.onSurface;
      case ModernButtonStyle.outlined:
        return AppColors.accent;
    }
  }

  static Color? _getBackgroundColor(ModernButtonStyle style) {
    switch (style) {
      case ModernButtonStyle.primary:
      case ModernButtonStyle.constellation:
        return null; // Uses gradient
      case ModernButtonStyle.secondary:
        return AppColors.surface;
      case ModernButtonStyle.outlined:
        return null;
    }
  }

  static Gradient? _getGradient(ModernButtonStyle style) {
    switch (style) {
      case ModernButtonStyle.primary:
        return const LinearGradient(
          colors: [AppColors.accent, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ModernButtonStyle.constellation:
        return const LinearGradient(
          colors: AppColors.starGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ModernButtonStyle.secondary:
      case ModernButtonStyle.outlined:
        return null;
    }
  }

  static Color? _getBorderColor(ModernButtonStyle style) {
    switch (style) {
      case ModernButtonStyle.outlined:
        return AppColors.accent;
      default:
        return null;
    }
  }

  static List<BoxShadow>? _getShadow(ModernButtonStyle style) {
    switch (style) {
      case ModernButtonStyle.primary:
        return [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case ModernButtonStyle.secondary:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      default:
        return null;
    }
  }
}
