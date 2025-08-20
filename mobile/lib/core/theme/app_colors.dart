import 'package:flutter/material.dart';

class AppColors {
  // Apple-inspired Primary Colors - Dynamic Blue system
  static const Color primary = Color(0xFF007AFF);  // iOS System Blue
  static const Color primaryLight = Color(0xFF40A2FF);
  static const Color primaryDark = Color(0xFF0051D0);
  
  // Secondary Colors - Modern iOS palette
  static const Color accent = Color(0xFFFF9F0A);  // iOS System Orange
  static const Color success = Color(0xFF30D158);  // iOS System Green
  static const Color warning = Color(0xFFFFCC02);  // iOS System Yellow
  static const Color error = Color(0xFFFF453A);   // iOS System Red
  static const Color purple = Color(0xFFAF52DE);  // iOS System Purple
  static const Color pink = Color(0xFFFF2D92);    // iOS System Pink
  static const Color teal = Color(0xFF40E0D0);    // Custom Teal
  
  // Sophisticated Dark Theme Colors - iOS-like
  static const Color backgroundDark = Color(0xFF000000);     // Pure black for OLED
  static const Color surfaceDark = Color(0xFF1C1C1E);       // iOS secondary background
  static const Color surfaceElevated = Color(0xFF2C2C2E);   // iOS tertiary background
  static const Color surfaceCard = Color(0xFF3A3A3C);       // iOS quaternary background
  
  // Light Theme Colors - Clean iOS style
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF2F2F7);      // iOS grouped background
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);
  
  // Text Colors - iOS Dynamic
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFEBEBF5);  // iOS secondary label
  static const Color textTertiaryDark = Color(0xFFEBEBF5);   // iOS tertiary label
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF3C3C43);
  
  // Elegant borders and shadows
  static const Color border = Color(0x17EBEBF5);            // iOS separator
  static const Color borderDark = Color(0x29EBEBF5);        // iOS separator in dark
  static const Color disabled = Color(0xFF8E8E93);          // iOS quaternary label
  
  // Sophisticated shadows and glows
  static const Color shadow = Color(0x1A000000);
  static const Color shadowStrong = Color(0x33000000);
  static const Color glow = Color(0x40007AFF);             // Primary glow
  static const Color accentGlow = Color(0x40FF9F0A);       // Accent glow
  
  // Glass morphism effects
  static const Color glass = Color(0x1AFFFFFF);
  static const Color glassDark = Color(0x1A000000);
  
  // Status and feedback colors
  static const Color online = Color(0xFF30D158);
  static const Color offline = Color(0xFF8E8E93);
  static const Color recording = Color(0xFFFF453A);
  static const Color liveIndicator = Color(0xFFFF453A);
  
  // Camera-specific colors
  static const Color cameraOverlay = Color(0x80000000);
  static const Color focusRing = Color(0xFFFFCC02);
  static const Color exposureIndicator = Color(0xFF007AFF);
  
  // Gradient definitions for Apple-style effects
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x40FFFFFF),
      Color(0x10FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF1C1C1E),
      Color(0xFF2C2C2E),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Dynamic color getters for context-aware theming
  static Color dynamicBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : backgroundLight;
  }
  
  static Color dynamicSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDark
        : surfaceLight;
  }
  
  static Color dynamicText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimaryLight;
  }
  
  static Color dynamicSecondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondaryLight;
  }
}