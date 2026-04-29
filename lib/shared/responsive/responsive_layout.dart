import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

/// Responsive layout system for handling different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final EdgeInsets? padding;
  final bool enableSafeArea;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.padding,
    this.enableSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    Widget content;
    if (screenWidth >= AppDimensions.desktopBreakpoint && desktop != null) {
      content = desktop!;
    } else if (screenWidth >= AppDimensions.tabletBreakpoint &&
        tablet != null) {
      content = tablet!;
    } else {
      content = mobile;
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (enableSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// Responsive builder for conditional UI elements
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    DeviceType deviceType,
    Orientation orientation,
  )
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final deviceType = _getDeviceType(mediaQuery.size.width);

    return builder(context, deviceType, mediaQuery.orientation);
  }

  DeviceType _getDeviceType(double width) {
    if (width >= AppDimensions.desktopBreakpoint) {
      return DeviceType.desktop;
    } else if (width >= AppDimensions.tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }
}

/// Device type enumeration
enum DeviceType { mobile, tablet, desktop }

/// Responsive padding utility
class ResponsivePadding {
  static EdgeInsets symmetric({
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return EdgeInsets.symmetric(horizontal: mobile, vertical: mobile * 0.5);
  }

  static EdgeInsets all({
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return EdgeInsets.all(mobile);
  }

  static EdgeInsets fromContext(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= AppDimensions.desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl);
    } else if (width >= AppDimensions.tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL);
    } else {
      return const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM);
    }
  }
}

/// Responsive spacing utility
class ResponsiveSpacing {
  static double getSpacing(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= AppDimensions.desktopBreakpoint && desktop != null) {
      return desktop;
    } else if (width >= AppDimensions.tabletBreakpoint && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  static SizedBox vertical(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return SizedBox(
      height: getSpacing(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      ),
    );
  }

  static SizedBox horizontal(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return SizedBox(
      width: getSpacing(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      ),
    );
  }
}

/// Responsive font size utility
class ResponsiveText {
  static TextStyle getTextStyle(
    BuildContext context, {
    required TextStyle baseStyle,
    double? tabletScale,
    double? desktopScale,
  }) {
    final width = MediaQuery.of(context).size.width;
    final baseFontSize = baseStyle.fontSize ?? 14.0;

    double fontSize = baseFontSize;
    if (width >= AppDimensions.desktopBreakpoint && desktopScale != null) {
      fontSize = baseFontSize * desktopScale;
    } else if (width >= AppDimensions.tabletBreakpoint && tabletScale != null) {
      fontSize = baseFontSize * tabletScale;
    }

    return baseStyle.copyWith(fontSize: fontSize);
  }
}

/// Responsive container with max width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = maxWidth ?? _getDefaultMaxWidth(screenWidth);

    return Container(
      width: double.infinity,
      margin: margin,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }

  double _getDefaultMaxWidth(double screenWidth) {
    if (screenWidth >= AppDimensions.desktopBreakpoint) {
      return AppDimensions.desktopBreakpoint * 0.8;
    } else if (screenWidth >= AppDimensions.tabletBreakpoint) {
      return AppDimensions.tabletBreakpoint * 0.9;
    } else {
      return double.infinity;
    }
  }
}

/// Responsive grid layout
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppDimensions.spacingM,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, orientation) {
        int columns;
        switch (deviceType) {
          case DeviceType.desktop:
            columns = desktopColumns;
            break;
          case DeviceType.tablet:
            columns = tabletColumns;
            break;
          case DeviceType.mobile:
            columns = mobileColumns;
            break;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Extension methods for MediaQuery
extension ResponsiveExtensions on BuildContext {
  /// Check if current device is mobile
  bool get isMobile =>
      MediaQuery.of(this).size.width < AppDimensions.tabletBreakpoint;

  /// Check if current device is tablet
  bool get isTablet {
    final width = MediaQuery.of(this).size.width;
    return width >= AppDimensions.tabletBreakpoint &&
        width < AppDimensions.desktopBreakpoint;
  }

  /// Check if current device is desktop
  bool get isDesktop =>
      MediaQuery.of(this).size.width >= AppDimensions.desktopBreakpoint;

  /// Get device type
  DeviceType get deviceType {
    final width = MediaQuery.of(this).size.width;
    if (width >= AppDimensions.desktopBreakpoint) {
      return DeviceType.desktop;
    } else if (width >= AppDimensions.tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }

  /// Get responsive padding
  EdgeInsets get responsivePadding => ResponsivePadding.fromContext(this);

  /// Get screen size percentage
  double widthPercentage(double percentage) =>
      MediaQuery.of(this).size.width * percentage;
  double heightPercentage(double percentage) =>
      MediaQuery.of(this).size.height * percentage;
}
