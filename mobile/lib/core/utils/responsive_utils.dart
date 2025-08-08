import 'package:flutter/material.dart';

/// Utility class for responsive design across different screen orientations and sizes
class ResponsiveUtils {
  /// Check if the device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if the device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get responsive width based on orientation
  static double getResponsiveWidth(BuildContext context, {
    double portraitFactor = 1.0,
    double landscapeFactor = 0.6,
  }) {
    final size = MediaQuery.of(context).size;
    return isLandscape(context)
        ? size.width * landscapeFactor
        : size.width * portraitFactor;
  }

  /// Get responsive height based on orientation
  static double getResponsiveHeight(BuildContext context, {
    double portraitFactor = 1.0,
    double landscapeFactor = 1.0,
  }) {
    final size = MediaQuery.of(context).size;
    return isLandscape(context)
        ? size.height * landscapeFactor
        : size.height * portraitFactor;
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final size = MediaQuery.of(context).size;
    final minDimension = size.width < size.height ? size.width : size.height;
    
    // Scale font size based on screen size
    double scaleFactor = minDimension / 375.0; // 375 is iPhone 8 width as baseline
    return baseFontSize * scaleFactor.clamp(0.8, 1.2);
  }

  /// Get responsive padding based on orientation
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double portraitPadding = 16.0,
    double landscapePadding = 24.0,
  }) {
    final padding = isLandscape(context) ? landscapePadding : portraitPadding;
    return EdgeInsets.all(padding);
  }

  /// Get responsive spacing based on orientation
  static double getResponsiveSpacing(BuildContext context, {
    double portraitSpacing = 16.0,
    double landscapeSpacing = 24.0,
  }) {
    return isLandscape(context) ? landscapeSpacing : portraitSpacing;
  }

  /// Get the smaller dimension (for calculating square elements)
  static double getMinDimension(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < size.height ? size.width : size.height;
  }

  /// Get the larger dimension
  static double getMaxDimension(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height ? size.width : size.height;
  }

  /// Check if screen is considered tablet size
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diagonal = (size.width * size.width + size.height * size.height) / (160 * 160);
    return diagonal >= 7.0; // 7 inch diagonal
  }

  /// Get responsive layout based on orientation and device type
  static ResponsiveLayoutConfig getLayoutConfig(BuildContext context) {
    final isLandscapeMode = isLandscape(context);
    final isTabletDevice = isTablet(context);
    
    return ResponsiveLayoutConfig(
      isLandscape: isLandscapeMode,
      isTablet: isTabletDevice,
      showSideNavigation: isLandscapeMode && isTabletDevice,
      showBottomNavigation: !isLandscapeMode || !isTabletDevice,
      columnCount: isLandscapeMode ? (isTabletDevice ? 3 : 2) : 1,
      maxWidth: isLandscapeMode ? 1200.0 : 600.0,
    );
  }
}

/// Configuration class for responsive layouts
class ResponsiveLayoutConfig {
  final bool isLandscape;
  final bool isTablet;
  final bool showSideNavigation;
  final bool showBottomNavigation;
  final int columnCount;
  final double maxWidth;

  const ResponsiveLayoutConfig({
    required this.isLandscape,
    required this.isTablet,
    required this.showSideNavigation,
    required this.showBottomNavigation,
    required this.columnCount,
    required this.maxWidth,
  });
}

/// Widget that adapts layout based on orientation
class OrientationLayout extends StatelessWidget {
  final Widget portraitLayout;
  final Widget? landscapeLayout;

  const OrientationLayout({
    super.key,
    required this.portraitLayout,
    this.landscapeLayout,
  });

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape && landscapeLayout != null) {
          return landscapeLayout!;
        }
        return portraitLayout;
      },
    );
  }
}