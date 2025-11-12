import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';

/// Professional Design System Tokens
/// Provides consistent spacing, colors, typography, and animation values
class DesignTokens {
  // ===== SPACING SCALE (8px grid system) =====
  static const double spaceXS = 4.0; // 4px
  static const double spaceSM = 8.0; // 8px
  static const double spaceMD = 16.0; // 16px
  static const double spaceLG = 24.0; // 24px
  static const double spaceXL = 32.0; // 32px
  static const double spaceXXL = 48.0; // 48px
  static const double spaceXXXL = 64.0; // 64px

  // ===== BORDER RADIUS SCALE =====
  static const double radiusXS = 4.0; // Small elements
  static const double radiusSM = 8.0; // Buttons, chips
  static const double radiusMD = 12.0; // Cards, inputs
  static const double radiusLG = 16.0; // Large cards
  static const double radiusXL = 20.0; // Modals, sheets
  static const double radiusXXL = 24.0; // Large modals

  // ===== ELEVATION/SHADOWS =====
  static const double elevation1 = 2.0; // Subtle
  static const double elevation2 = 4.0; // Standard
  static const double elevation3 = 8.0; // Prominent
  static const double elevation4 = 16.0; // Floating

  // ===== ICON SIZES =====
  static const double iconXS = 12.0; // Small indicators
  static const double iconSM = 16.0; // Small icons
  static const double iconMD = 20.0; // Standard icons
  static const double iconLG = 24.0; // Large icons
  static const double iconXL = 32.0; // Extra large icons
  static const double iconXXL = 40.0; // Hero icons

  // ===== TYPOGRAPHY SCALE =====
  static const double fontSizeXS = 10.0; // Captions
  static const double fontSize11 = 11.0; // Small captions (between XS and SM)
  static const double fontSizeSM = 12.0; // Small text
  static const double fontSizeMD = 14.0; // Body text
  static const double fontSizeLG = 16.0; // Large body
  static const double fontSizeXL = 18.0; // Subheadings
  static const double fontSizeXXL = 20.0; // Headings
  static const double fontSize22 =
      22.0; // Large headings (between XXL and XXXL)
  static const double fontSizeXXXL = 24.0; // Large headings
  static const double fontSizeDisplay = 32.0; // Display text

  // ===== LINE HEIGHTS =====
  static const double lineHeightTight = 1.2; // Headings
  static const double lineHeightNormal = 1.4; // Body text
  static const double lineHeightRelaxed = 1.6; // Large text

  // ===== LETTER SPACING =====
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;

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
  static const double cardMinHeight = 200.0;

  // ===== LEGACY AVATAR SIZES (Deprecated - Use AvatarSizes instead) =====
  @Deprecated('Use AvatarSizes.medium instead')
  static const double avatarSize = 40.0;
  @Deprecated('Use AvatarSizes.large instead')
  static const double avatarSizeLarge = 64.0;

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

/// Animation Tokens
/// Standardized animation durations and curves for consistent motion
class AnimationTokens {
  // ===== DURATIONS =====
  static const Duration fast =
      Duration(milliseconds: 200); // Quick interactions
  static const Duration normal =
      Duration(milliseconds: 300); // Standard transitions
  static const Duration slow = Duration(milliseconds: 500); // Macro animations
  static const Duration verySlow =
      Duration(milliseconds: 800); // Complex animations

  // Legacy durations (kept for backward compatibility)
  @Deprecated('Use AnimationTokens.fast instead')
  static const Duration durationFast = Duration(milliseconds: 150);
  @Deprecated('Use AnimationTokens.normal instead')
  static const Duration durationNormal = Duration(milliseconds: 300);
  @Deprecated('Use AnimationTokens.slow instead')
  static const Duration durationSlow = Duration(milliseconds: 500);
  @Deprecated('Use AnimationTokens.verySlow instead')
  static const Duration durationVerySlow = Duration(milliseconds: 800);

  // ===== CURVES =====
  // Basic curves
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;

  // Cubic curves (smoother, more natural)
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;

  // Back curves (overshoot effect)
  static const Curve easeInBack = Curves.easeInBack;
  static const Curve easeOutBack = Curves.easeOutBack;

  // Other curves
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve easeInQuad = Curves.easeInQuad;

  // Legacy curves (kept for backward compatibility)
  @Deprecated('Use AnimationTokens.easeIn instead')
  static const Curve curveEaseIn = Curves.easeIn;
  @Deprecated('Use AnimationTokens.easeOut instead')
  static const Curve curveEaseOut = Curves.easeOut;
  @Deprecated('Use AnimationTokens.easeInOut instead')
  static const Curve curveEaseInOut = Curves.easeInOut;
  @Deprecated('Use AnimationTokens.fastOutSlowIn instead')
  static const Curve curveFastOutSlowIn = Curves.fastOutSlowIn;
  @Deprecated('Use AnimationTokens.elasticOut instead')
  static const Curve curveElasticOut = Curves.elasticOut;
}

/// Avatar Size Tokens
/// Standardized avatar sizes with radius calculations
enum AvatarSize {
  small(32.0),
  medium(40.0),
  large(64.0);

  final double size;
  const AvatarSize(this.size);

  /// Get the radius (half of size)
  double get radius => size / 2;

  /// Get memory cache dimensions (2x for retina displays)
  int get memCacheWidth => (size * 2).round();
  int get memCacheHeight => (size * 2).round();
}

/// Semantic Colors
/// Theme-aware semantic colors that adapt to light/dark mode
class SemanticColors {
  // Prevent instantiation
  SemanticColors._();

  // ===== STATUS COLORS =====
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color neutral = Color(0xFF6B7280); // Gray

  // ===== REACTION COLORS =====
  /// Like/Reaction color - matches primary accent for consistency
  /// Used for liked posts, comments, and reaction buttons throughout the app
  static Color get reactionLiked => SonarPulseTheme.primaryAccent;

  // ===== TEXT COLORS (Theme-aware) =====
  /// Primary text color (adapts to theme)
  static Color textPrimary(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFFE8E8E8) // darkTextPrimary
        : const Color(0xFF1D1D1F); // lightTextPrimary
  }

  /// Secondary text color (adapts to theme)
  static Color textSecondary(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF8A8A8E) // darkTextSecondary
        : const Color(0xFF6E6E73); // lightTextSecondary
  }

  /// Tertiary text color (adapts to theme)
  static Color textTertiary(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF8A8A8E).withOpacity(0.6)
        : const Color(0xFF6E6E73).withOpacity(0.6);
  }

  // ===== SURFACE COLORS (Theme-aware) =====
  /// Background color (adapts to theme)
  static Color surfaceBackground(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF121212) // darkBackground
        : const Color(0xFFF5F5F7); // lightBackground
  }

  /// Surface color for cards/dialogs (adapts to theme)
  static Color surfaceCard(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E) // darkSurface
        : Colors.white; // lightSurface
  }

  /// Divider color (adapts to theme)
  static Color surfaceDivider(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF2C2C2E) // darkDivider
        : const Color(0xFFE5E5EA); // lightDivider
  }

  // ===== ICON COLORS (Theme-aware) =====
  /// Icon color (adapts to theme)
  static Color iconDefault(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? const Color(0xFF9E9E9E) // darkIcon
        : const Color(0xFF8A8A8E); // lightIcon
  }

  // ===== GRAY SCALE (Theme-aware) =====
  /// Gray 200 (light) / Gray 800 (dark)
  static Color gray200(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[200]!;
  }

  /// Gray 300 (light) / Gray 700 (dark)
  static Color gray300(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[300]!;
  }

  /// Gray 400 (light) / Gray 600 (dark)
  static Color gray400(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Colors.grey[600]!
        : Colors.grey[400]!;
  }

  /// Gray 600 (light) / Gray 400 (dark)
  static Color gray600(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
  }

  /// Gray 800 (light) / Gray 200 (dark)
  static Color gray800(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Colors.grey[200]!
        : Colors.grey[800]!;
  }
}
