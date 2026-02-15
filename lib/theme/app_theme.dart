import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

class SonarPulseTheme {
  // --- PRIMARY COLORS ---
  static const Color primaryAccent = Color(0xFF00BFA5); // A vibrant Teal/Cyan
  static const Color primaryAccentLight = Color(0xFF5DF2D6);
  static const Color primaryAccentDark = Color(0xFF008E76);
  static const Color socialAccent = Color(0xFF8B5CF6); // Cyber Violet

  // --- LIGHT THEME COLORS ---
  static const Color lightBackground = Color(0xFFF5F5F7); // Slightly off-white
  static const Color lightSurface = Colors.white; // For cards, dialogs
  static const Color lightTextPrimary = Color(0xFF1D1D1F); // Almost black
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightIcon = Color(0xFF8A8A8E);
  static const Color lightDivider = Color(0xFFE5E5EA);
  static const Color lightError = Color(0xFFD32F2F);

  // --- DARK THEME COLORS ---
  static const Color darkBackground = Color(0xFF0A0A0B); // Deep Obsidian
  static const Color darkSurface = Color(0xFF161618); // Cool Slate
  static const Color darkTextPrimary = Color(0xFFE8E8E8); // Off-white
  static const Color darkTextSecondary = Color(0xFF8A8A8E);
  static const Color darkIcon = Color(0xFF9E9E9E);
  static const Color darkDivider = Color(0xFF2C2C2E);
  static const Color darkError = Color(0xFFEF9A9A);

  // --- GRADIENTS ---
  static const LinearGradient appLinearGradient = LinearGradient(
    colors: [primaryAccent, primaryAccentLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const RadialGradient appRadialGradient = RadialGradient(
    colors: [primaryAccentLight, primaryAccent],
  );

  // --- TYPOGRAPHY ---
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: DesignTokens.letterSpacingTight),
    displayMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: DesignTokens.letterSpacingTight),
    headlineSmall: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: DesignTokens.letterSpacingTight),
    titleLarge: TextStyle(
        fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(
        fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(
        fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(
        fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.normal),
    bodyMedium: TextStyle(
        fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.normal),
    bodySmall: TextStyle(
        fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.normal),
    labelLarge: TextStyle(
        fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.bold),
  );

  // --- SHARED COMPONENT STYLES ---
  static final _cardTheme = CardThemeData(
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
    ),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      minimumSize: const Size.fromHeight(52), // Fixed height 52.0
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      textStyle: _textTheme.labelLarge,
    ),
  );

  // --- LIGHT THEME DATA ---
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: 'Roboto',
      textTheme: _textTheme.apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
        fontFamily: 'Roboto',
      ),
      cardTheme: _cardTheme.copyWith(color: lightSurface),
      elevatedButtonTheme: _elevatedButtonTheme,
      dividerColor: lightDivider,
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: lightIcon),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle:
            _textTheme.titleLarge?.copyWith(color: lightTextPrimary),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: lightSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: SonarPulseTheme.primaryAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        onPrimary: Colors.white,
        secondary: primaryAccentLight,
        onSecondary: Colors.black,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        error: lightError,
        onError: Colors.white,
      ),
    );
  }

  // --- DARK THEME DATA ---
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Roboto',
      textTheme: _textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
        fontFamily: 'Roboto',
      ),
      cardTheme: _cardTheme.copyWith(color: darkSurface),
      elevatedButtonTheme: _elevatedButtonTheme,
      dividerColor: darkDivider,
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: darkIcon),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: _textTheme.titleLarge?.copyWith(color: darkTextPrimary),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.black,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: SonarPulseTheme.primaryAccent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        onPrimary: Colors.black,
        secondary: primaryAccentDark,
        onSecondary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: darkError,
        onError: Colors.black,
      ),
    );
  }
}

class CyberScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
