import 'package:flutter/material.dart';

/// Professional Design System Tokens
/// Provides consistent spacing, colors, typography, and animation values
class DesignTokens {
  // ===== SPACING SCALE (8px grid system) =====
  static const double spaceXS = 4.0;   // 4px
  static const double spaceSM = 8.0;  // 8px
  static const double spaceMD = 16.0; // 16px
  static const double spaceLG = 24.0; // 24px
  static const double spaceXL = 32.0; // 32px
  static const double spaceXXL = 48.0; // 48px
  static const double spaceXXXL = 64.0; // 64px

  // ===== BORDER RADIUS SCALE =====
  static const double radiusXS = 4.0;  // Small elements
  static const double radiusSM = 8.0;  // Buttons, chips
  static const double radiusMD = 12.0; // Cards, inputs
  static const double radiusLG = 16.0; // Large cards
  static const double radiusXL = 20.0; // Modals, sheets
  static const double radiusXXL = 24.0; // Large modals

  // ===== ELEVATION/SHADOWS =====
  static const double elevation1 = 2.0;  // Subtle
  static const double elevation2 = 4.0;  // Standard
  static const double elevation3 = 8.0;  // Prominent
  static const double elevation4 = 16.0; // Floating

  // ===== ANIMATION DURATIONS =====
  static const Duration durationFast = Duration(milliseconds: 150);   // Micro interactions
  static const Duration durationNormal = Duration(milliseconds: 300); // Standard transitions
  static const Duration durationSlow = Duration(milliseconds: 500);   // Macro animations
  static const Duration durationVerySlow = Duration(milliseconds: 800); // Complex animations

  // ===== ANIMATION CURVES =====
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveEaseInOut = Curves.easeInOut;
  static const Curve curveFastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve curveElasticOut = Curves.elasticOut;

  // ===== ICON SIZES =====
  static const double iconXS = 12.0;  // Small indicators
  static const double iconSM = 16.0;  // Small icons
  static const double iconMD = 20.0;  // Standard icons
  static const double iconLG = 24.0;  // Large icons
  static const double iconXL = 32.0;  // Extra large icons
  static const double iconXXL = 40.0; // Hero icons

  // ===== TYPOGRAPHY SCALE =====
  static const double fontSizeXS = 10.0;  // Captions
  static const double fontSizeSM = 12.0; // Small text
  static const double fontSizeMD = 14.0; // Body text
  static const double fontSizeLG = 16.0; // Large body
  static const double fontSizeXL = 18.0; // Subheadings
  static const double fontSizeXXL = 20.0; // Headings
  static const double fontSizeXXXL = 24.0; // Large headings
  static const double fontSizeDisplay = 32.0; // Display text

  // ===== LINE HEIGHTS =====
  static const double lineHeightTight = 1.2;   // Headings
  static const double lineHeightNormal = 1.4;  // Body text
  static const double lineHeightRelaxed = 1.6; // Large text

  // ===== LETTER SPACING =====
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;

  // ===== SEMANTIC COLORS =====
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color warningColor = Color(0xFFF59E0B); // Orange
  static const Color errorColor = Color(0xFFEF4444);   // Red
  static const Color infoColor = Color(0xFF3B82F6);    // Blue
  static const Color neutralColor = Color(0xFF6B7280); // Gray

  // ===== OPACITY VALUES =====
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.6;
  static const double opacityHigh = 0.87;
  static const double opacityFull = 1.0;

  // ===== BREAKPOINTS =====
  static const double breakpointMobile = 320.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointDesktop = 1024.0;

  // ===== COMPONENT SIZES =====
  static const double buttonHeight = 48.0;
  static const double chipHeight = 32.0;
  static const double avatarSize = 40.0;
  static const double avatarSizeLarge = 64.0;
  static const double cardMinHeight = 200.0;

  // ===== BLUR VALUES =====
  static const double blurLight = 10.0;
  static const double blurMedium = 15.0;
  static const double blurHeavy = 20.0;

  // ===== SHADOW DEFINITIONS =====
  static List<BoxShadow> get shadowLight => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: elevation1,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: elevation2,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowHeavy => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: elevation3,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowFloating => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: elevation4,
      offset: const Offset(0, 8),
    ),
  ];

  // ===== GRADIENT DEFINITIONS =====
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00BFA5),
      Color(0xFF5DF2D6),
    ],
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.white.withOpacity(0.1),
      Colors.white.withOpacity(0.05),
    ],
  );

  static LinearGradient get glassmorphicGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.25),
      Colors.white.withOpacity(0.1),
    ],
  );
}
