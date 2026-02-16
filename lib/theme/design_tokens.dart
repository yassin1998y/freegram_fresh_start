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
  // ===== BORDER RADIUS SCALE =====
  static const double radiusXS = 4.0; // Small elements
  static const double radiusSM = 8.0; // Buttons, chips
  static const double radiusMD = 16.0; // Cards, inputs
  static const double radiusLG = 16.0; // Large cards
  static const double radiusXL = 20.0; // Modals, sheets
  static const double radiusXXL = 24.0; // Large modals

  // ===== SEMANTIC SPACING TOKENS =====
  // Screen-level spacing
  static const double screenPadding = spaceMD; // 16px - Standard screen padding
  static const double screenPaddingHorizontal = spaceMD; // 16px
  static const double screenPaddingVertical = spaceMD; // 16px

  // List & Card spacing
  static const double listItemPadding =
      spaceMD; // 16px - List item internal padding
  static const double listItemSpacing = spaceSM; // 8px - Between list items
  static const double cardPadding = spaceMD; // 16px - Card internal padding
  static const double cardMargin = spaceSM; // 8px - Card external margin

  // Section spacing
  static const double sectionSpacing = spaceLG; // 24px - Between major sections
  static const double sectionHeaderSpacing =
      spaceSM; // 8px - Below section headers
  static const double sectionPadding =
      spaceMD; // 16px - Section internal padding

  // Component sizing
  // buttonHeight is already defined (48.0)
  static const double buttonHeightSmall = 36.0; // Small button height
  static const double buttonPaddingHorizontal = spaceLG; // 24px
  static const double buttonPaddingVertical = 14.0; // Specific to buttons

  static const double inputHeight = 48.0; // Standard input field height
  static const double inputPadding = spaceMD; // 16px - Input internal padding
  static const double inputBorderRadius =
      radiusMD; // 16px - Input border radius

  // Avatar sizing
  static const double avatarSizeXS = 24.0; // Extra small avatar
  static const double avatarSizeSmall = 32.0; // Small avatar (lists)
  static const double avatarSizeMedium = 48.0; // Medium avatar (posts)
  // avatarSizeLarge is already defined (64.0)
  static const double avatarSizeXL =
      96.0; // Extra large avatar (profile header)

  // Dialog & Modal spacing
  static const double dialogPadding = spaceLG; // 24px - Dialog internal padding
  static const double dialogButtonSpacing =
      spaceSM; // 8px - Between dialog buttons
  static const double modalPadding = spaceMD; // 16px - Modal internal padding

  // Bottom sheet spacing
  static const double bottomSheetPadding =
      spaceMD; // 16px - Bottom sheet padding
  static const double bottomSheetHandleWidth = 40.0; // Handle width
  static const double bottomSheetHandleHeight = 4.0; // Handle height
  static const double bottomNavBarHeight = 65.0; // Navigation bar height

  // Post Card Spacing
  static const double postHeaderPadding = spaceSM;
  static const double postCaptionPadding = spaceMD;
  static const double postActionsPadding = spaceSM;

  // Borders
  static const double borderWidthHairline = 0.5;
  static const double borderWidthThin = 1.0;
  static const double borderWidthThick = 2.0;

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
  static const double fontSizeHero = 48.0; // Hero text (e.g. Profile emoji)

  // ===== LINE HEIGHTS =====
  static const double lineHeightTight = 1.2; // Headings
  static const double lineHeightNormal = 1.5; // Body text
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

  // ===== SHADOW DEFINITIONS (DEPRECATED: Use Borders.standard instead) =====
  @Deprecated('Use Borders.standard instead for the 1px border rule')
  static List<BoxShadow> get shadowLight => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: elevation1,
          offset: const Offset(0, 1),
        ),
      ];

  @Deprecated('Use Borders.standard instead for the 1px border rule')
  static List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: elevation2,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowFloating => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
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
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.05),
        ],
      );

  static LinearGradient glassmorphicGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        (isDark ? Colors.black : Colors.white).withValues(alpha: 0.25),
        (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
      ],
    );
  }
}

// ===== BORDERS & CONTAINERS =====
class Borders {
  /// The 1px Border Rule: 1.0px width, dividerColor, 16.0px radius
  static BorderSide standard(BuildContext context) => BorderSide(
        color: Theme.of(context).dividerColor,
        width: 1.0,
      );

  static BorderRadius radius16 = BorderRadius.circular(16.0);

  @Deprecated('Use standard(context) instead')
  static BorderSide get subtle => BorderSide(
        color: Colors.grey.withValues(alpha: 0.2),
        width: 1,
      );

  static BorderSide focused(BuildContext context) => const BorderSide(
        color: SonarPulseTheme.primaryAccent,
        width: 1.0,
      );
}

class Containers {
  /// Standard interactive container decoration (1px Border Rule)
  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Borders.radius16,
        border: Border.fromBorderSide(Borders.standard(context)),
      );

  static BoxDecoration iconBox(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      );

  // Unified 1px Border Rule Implementation
  static BoxDecoration glassCard(BuildContext context) => BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: DesignTokens.borderWidthThin, // 1px border
        ),
      );

  // Added for VideoCallOverlay
  static BoxDecoration glassDecoration(BuildContext context) =>
      glassCard(context);
}

/// Animation Tokens
class AnimationTokens {
  // ===== DURATIONS =====
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration snappy = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // ===== CURVES =====
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve snappyCurve = Curves.easeOutQuart;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeInBack = Curves.easeInBack;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve easeInQuad = Curves.easeInQuad;
}

/// Avatar Size Tokens
enum AvatarSize {
  small(32.0),
  medium(40.0),
  large(64.0);

  final double size;
  const AvatarSize(this.size);

  double get radius => size / 2;
  int get memCacheWidth => (size * 2).round();
  int get memCacheHeight => (size * 2).round();
}

/// Semantic Colors
/// Theme-aware semantic colors that adapt to light/dark mode
class SemanticColors {
  SemanticColors._();

  // ===== DYNAMIC TOKENS =====
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color divider(BuildContext context) => Theme.of(context).dividerColor;
  static Color surfaceDivider(BuildContext context) =>
      Theme.of(context).dividerColor;

  // ===== STATUS COLORS =====
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color neutral = Color(0xFF6B7280);

  static Color get reactionLiked => SonarPulseTheme.primaryAccent;

  // ===== TEXT COLORS (Theme-aware) =====
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ??
      (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE8E8E8)
          : const Color(0xFF1D1D1F));
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.color ??
      (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8A8A8E)
          : const Color(0xFF6E6E73));

  // ===== ICON COLORS (Theme-aware) =====
  static Color iconDefault(BuildContext context) =>
      Theme.of(context).iconTheme.color ??
      (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF9E9E9E)
          : const Color(0xFF8A8A8E));

  static Color gray800(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[200]!
          : Colors.grey[800]!;
  static Color gray600(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[400]!
          : Colors.grey[600]!;
  static Color gray400(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[600]!
          : Colors.grey[400]!;
  static Color gray300(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[700]!
          : Colors.grey[300]!;
  static Color gray200(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]!
          : Colors.grey[200]!;
}
