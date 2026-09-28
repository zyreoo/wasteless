import 'package:flutter/material.dart';

class AppColors {
  // Primary greens
  static const Color darkGreen = Color(0xFF31572C);
  static const Color mediumGreen = Color(0xFF31572C);
  static const Color primaryGreen = Color(0xFF40916C);
  static const Color lightGreen = Color(0xFF40916C);
  static const Color accentGreen = Color(0xFF90A955);

  // Surface & Background
  static const Color splashBg = Color(0xFF31572C);
  static const Color scaffoldBg = Color(0xFFFAF9F6);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color headerBg = Color(0xFF31572C);

  // Accent / Highlights
  static const Color limeYellow = Color(0xFFECF39E);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE74C3C);
  static const Color success = Color(0xFF4CAF50);

  // Neutral
  static const Color textPrimary = Color(0xFF31572C);
  static const Color textSecondary = Color(0xFF6B6A63);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0DFD9);
  static const Color inputBg = Color(0xFFE8EDE5);

  // Category tag colors
  static const Color tagGreen = Color(0xFFD1FAE5);
  static const Color tagGreenText = Color(0xFF065F46);
  static const Color tagYellow = Color(0xFFFEF3C7);
  static const Color tagYellowText = Color(0xFF92400E);
  static const Color tagRed = Color(0xFFFEE2E2);
  static const Color tagRedText = Color(0xFF991B1B);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
      secondary: AppColors.limeYellow,
      surface: AppColors.scaffoldBg,
    ),
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.headerBg,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.limeYellow,
        foregroundColor: AppColors.darkGreen,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBg,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
      ),
    ),
  );
}
