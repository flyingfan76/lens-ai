import 'package:flutter/material.dart';

/// Apple-inspired Typography System
/// Uses system fonts with proper iOS sizing and weights
class AppTypography {
  // Base font family - System font for best iOS/macOS appearance
  static const String fontFamily = '.AppleSystemUIFont'; // iOS/macOS system font
  
  // iOS Typography Scale - Official Apple sizes
  
  // Large Titles
  static TextStyle get largeTitleBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.12,
  );
  
  static TextStyle get largeTitleRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.12,
  );
  
  // Titles
  static TextStyle get title1Bold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
  );
  
  static TextStyle get title1Regular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.15,
  );
  
  static TextStyle get title2Bold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.18,
  );
  
  static TextStyle get title2Regular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.18,
  );
  
  static TextStyle get title3Bold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.2,
  );
  
  static TextStyle get title3Regular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.2,
  );
  
  // Headlines
  static TextStyle get headlineBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
    height: 1.24,
  );
  
  static TextStyle get headlineRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    height: 1.24,
  );
  
  // Body Text
  static TextStyle get bodyBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  );
  
  static TextStyle get bodyRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.29,
  );
  
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.29,
  );
  
  // Callout
  static TextStyle get calloutBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    height: 1.31,
  );
  
  static TextStyle get calloutRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.01,
    height: 1.31,
  );
  
  // Subheadline
  static TextStyle get subheadlineBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.02,
    height: 1.33,
  );
  
  static TextStyle get subheadlineRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.02,
    height: 1.33,
  );
  
  // Footnote
  static TextStyle get footnoteBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.03,
    height: 1.38,
  );
  
  static TextStyle get footnoteRegular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.03,
    height: 1.38,
  );
  
  // Caption
  static TextStyle get caption1Bold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.01,
    height: 1.33,
  );
  
  static TextStyle get caption1Regular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.01,
    height: 1.33,
  );
  
  static TextStyle get caption2Bold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.06,
    height: 1.27,
  );
  
  static TextStyle get caption2Regular => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.06,
    height: 1.27,
  );
  
  // Special UI Elements
  static TextStyle get buttonLabel => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
    height: 1.24,
  );
  
  static TextStyle get tabLabel => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.12,
    height: 1.2,
  );
  
  static TextStyle get navigationTitle => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
    height: 1.24,
  );
  
  // Camera-specific styles
  static TextStyle get cameraValue => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()], // Monospace numbers
  );
  
  static TextStyle get cameraLabel => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );
  
  static TextStyle get cameraStatus => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.27,
  );
  
  // Utility methods for colored text
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
  
  static TextStyle withOpacity(TextStyle style, double opacity) {
    return style.copyWith(color: style.color?.withOpacity(opacity));
  }
}

/// Spacing system based on iOS Human Interface Guidelines
class AppSpacing {
  // Base unit - 4pt
  static const double unit = 4.0;
  
  // Standard spacing values
  static const double xxs = unit;        // 4pt
  static const double xs = unit * 2;     // 8pt
  static const double sm = unit * 3;     // 12pt
  static const double md = unit * 4;     // 16pt
  static const double lg = unit * 5;     // 20pt
  static const double xl = unit * 6;     // 24pt
  static const double xxl = unit * 8;    // 32pt
  static const double xxxl = unit * 12;  // 48pt
  
  // Semantic spacing
  static const double cardPadding = md;
  static const double sectionSpacing = xl;
  static const double itemSpacing = sm;
  static const double tightSpacing = xs;
  static const double looseSpacing = xxl;
  
  // Layout margins
  static const double screenMargin = md;
  static const double contentMargin = lg;
  
  // Button dimensions
  static const double buttonHeight = 44.0;      // iOS standard
  static const double buttonRadius = 10.0;      // iOS standard
  static const double smallButtonHeight = 32.0;
  static const double largeButtonHeight = 56.0;
  
  // Card and surface dimensions
  static const double cardRadius = 12.0;        // iOS card radius
  static const double surfaceRadius = 16.0;     // iOS surface radius
  static const double smallRadius = 8.0;
  static const double largeRadius = 20.0;
  
  // Shadow and elevation
  static const double shadowBlur = 16.0;
  static const double shadowOffset = 4.0;
  static const double lightShadowBlur = 8.0;
  static const double strongShadowBlur = 24.0;
}

/// Animation durations and curves matching iOS
class AppAnimations {
  // Standard iOS durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
  
  // iOS spring animation curves
  static const Curve spring = Curves.easeInOutCubic;
  static const Curve springFast = Curves.easeOutCubic;
  static const Curve springEnter = Curves.easeOut;
  static const Curve springExit = Curves.easeIn;
  
  // Special effects
  static const Curve bounce = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOutQuart;
}