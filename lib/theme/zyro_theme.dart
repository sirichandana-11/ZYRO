import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZyroTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFFF2542D); // Vibrant Coral Orange
  static const Color primaryDark = Color(0xFFD63E17);
  static const Color primaryLight = Color(0xFFFF7A59);
  static const Color primarySurface = Color(0xFFFFF4F0);
  static const Color primarySurfaceDark = Color(0xFF2C1E1A);
  
  // Accent & Status Colors
  static const Color accentYellow = Color(0xFFFFB703);
  static const Color successGreen = Color(0xFF2EC4B6);
  static const Color errorRed = Color(0xFFE63946);

  // Neutral Palette - Light
  static const Color darkCharcoal = Color(0xFF191C21);
  static const Color bodyText = Color(0xFF495057);
  static const Color mutedText = Color(0xFF8D99AE);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardSurface = Colors.white;

  // Neutral Palette - Dark
  static const Color backgroundDark = Color(0xFF101216);
  static const Color surfaceDark = Color(0xFF1A1E24);
  static const Color surfaceDarkElevated = Color(0xFF222831);
  static const Color borderDark = Color(0xFF2D343F);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFF6B4A), Color(0xFFF2542D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFFF2542D), Color(0xFFE73E13)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF1E2228), Color(0xFF121418)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic Theme Helpers for dynamic widget adapting
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color scaffoldBg(BuildContext context) {
    return isDarkMode(context) ? backgroundDark : backgroundLight;
  }

  static Color cardBg(BuildContext context) {
    return isDarkMode(context) ? surfaceDark : Colors.white;
  }

  static Color elevatedCardBg(BuildContext context) {
    return isDarkMode(context) ? surfaceDarkElevated : Colors.white;
  }

  static Color borderColor(BuildContext context) {
    return isDarkMode(context) ? borderDark : borderLight;
  }

  static Color textPrimary(BuildContext context) {
    return isDarkMode(context) ? textPrimaryDark : darkCharcoal;
  }

  static Color textSecondary(BuildContext context) {
    return isDarkMode(context) ? textSecondaryDark : mutedText;
  }

  static Color primarySurfaceAdaptive(BuildContext context) {
    return isDarkMode(context) ? primarySurfaceDark : primarySurface;
  }

  static List<BoxShadow> cardShadow(BuildContext context) {
    return isDarkMode(context) ? softCardShadowDark : softCardShadow;
  }

  // Box Shadows
  static List<BoxShadow> get softCardShadow => [
        BoxShadow(
          color: const Color(0xFF191C21).withValues(alpha: 0.06),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFF191C21).withValues(alpha: 0.03),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get softCardShadowDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(0, 6),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonGlowShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.35),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  // Light Theme Data
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      cardColor: cardSurface,
      dividerColor: borderLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: darkCharcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: darkCharcoal),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: darkCharcoal,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: mutedText,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: accentYellow,
        surface: cardSurface,
        error: errorRed,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: darkCharcoal,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: darkCharcoal,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkCharcoal,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkCharcoal,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: darkCharcoal,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: bodyText,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: mutedText,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: mutedText.withValues(alpha: 0.8),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: bodyText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.8),
        ),
      ),
    );
  }

  // Dark Theme Data
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dividerColor: borderDark,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimaryDark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMutedDark,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: accentYellow,
        surface: surfaceDark,
        error: errorRed,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textSecondaryDark,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: textMutedDark,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: textPrimaryDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textMutedDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textSecondaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.8),
        ),
      ),
    );
  }
}
