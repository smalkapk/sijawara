import 'package:flutter/material.dart';

class AppTheme {
  // Primary Palette
  static const Color primaryGreen = Color(0xFF1B8A4A);
  static const Color deepGreen = Color(0xFF0D6E3B);
  static const Color emerald = Color(0xFF34D399);
  static const Color mint = Color(0xFFA7F3D0);
  static const Color darkGreen = Color(0xFF064E3B);
  static const Color lightGreen = Color(0xFF6EE7B7);
  static const Color teal = Color(0xFF0D9488);

  // Backward compat aliases
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF0F5F2);
  static const Color darkGrey = Color(0xFF2D3830);

  // Neutral Palette
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAF9);
  static const Color bgColor = Color(0xFFF0F5F2);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFFE8EDE9);
  static const Color grey200 = Color(0xFFD1D8D3);
  static const Color grey400 = Color(0xFF94A39A);
  static const Color grey600 = Color(0xFF5C6B62);
  static const Color grey800 = Color(0xFF2D3830);
  static const Color textPrimary = Color(0xFF1A2E22);
  static const Color textSecondary = Color(0xFF5C6B62);

  // Accent
  static const Color gold = Color(0xFFF59E0B);
  static const Color softGold = Color(0xFFFDE68A);
  static const Color warmOrange = Color(0xFFFB923C);
  static const Color softPurple = Color(0xFF8B5CF6);
  static const Color softBlue = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient mainGradient = LinearGradient(
    colors: [deepGreen, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient1 = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient2 = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient3 = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border Radii
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> greenGlow = [
    BoxShadow(
      color: primaryGreen.withOpacity(0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 32,
      offset: const Offset(0, 12),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'Segoe UI',
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: emerald,
        surface: white,
        error: const Color(0xFFEF4444),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: grey400,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
