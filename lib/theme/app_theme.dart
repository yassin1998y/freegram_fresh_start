import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SonarPulseTheme {
  // --- PRIMARY COLORS ---
  static const Color primaryAccent = Color(0xFF00BFA5); // A vibrant Teal/Cyan
  static const Color primaryAccentLight = Color(0xFF5DF2D6);
  static const Color primaryAccentDark = Color(0xFF008E76);

  // --- LIGHT THEME COLORS ---
  static const Color lightBackground = Color(0xFFF5F5F7); // Slightly off-white
  static const Color lightSurface = Colors.white; // For cards, dialogs
  static const Color lightTextPrimary = Color(0xFF1D1D1F); // Almost black
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightIcon = Color(0xFF8A8A8E);
  static const Color lightDivider = Color(0xFFE5E5EA);
  static const Color lightError = Color(0xFFD32F2F);

  // --- DARK THEME COLORS ---
  static const Color darkBackground = Color(0xFF121212); // A very dark charcoal
  static const Color darkSurface = Color(0xFF1E1E1E); // For cards, dialogs
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
  static final TextTheme _textTheme = TextTheme(
    displayLarge: GoogleFonts.openSans(fontSize: 34, fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.openSans(fontSize: 28, fontWeight: FontWeight.bold),
    headlineSmall: GoogleFonts.openSans(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.openSans(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.openSans(fontSize: 17, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.w500),
    bodyLarge: GoogleFonts.openSans(fontSize: 17, fontWeight: FontWeight.normal),
    bodyMedium: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.normal),
    bodySmall: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.normal),
    labelLarge: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.bold),
  );

  // --- SHARED COMPONENT STYLES ---
  // *** FIX APPLIED: Changed to CardThemeData ***
  static final _cardTheme = CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      textStyle: _textTheme.labelLarge,
    ),
  );

  // --- LIGHT THEME DATA ---
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: _textTheme.bodyMedium?.fontFamily,
      textTheme: _textTheme.apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
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
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: _textTheme.titleLarge?.copyWith(color: lightTextPrimary),
      ),
      // *** FIX APPLIED: Changed to BottomAppBarThemeData ***
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: lightSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
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
      fontFamily: _textTheme.bodyMedium?.fontFamily,
      textTheme: _textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
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
        shadowColor: Colors.black.withOpacity(0.3),
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: _textTheme.titleLarge?.copyWith(color: darkTextPrimary),
      ),
      // *** FIX APPLIED: Changed to BottomAppBarThemeData ***
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
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