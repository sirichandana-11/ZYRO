import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZyroTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFFF2542D); // Vibrant Coral Orange
  static const Color primaryDark = Color(0xFFD63E17);
  static const Color primaryLight = Color(0xFFFF7A59);
  static const Color primarySurface = Color(0xFFFFF4F0);
  
  // Accent & Status Colors
  static const Color accentYellow = Color(0xFFFFB703);
  static const Color successGreen = Color(0xFF2EC4B6);
  static const Color errorRed = Color(0xFFE63946);

  // Neutral Palette
  static const Color darkCharcoal = Color(0xFF191C21);
  static const Color bodyText = Color(0xFF495057);
  static const Color mutedText = Color(0xFF8D99AE);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardSurface = Colors.white;

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

  static List<BoxShadow> get buttonGlowShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.35),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  // Theme Data
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
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
          fontWeight: FontWeight.w600,
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
}
