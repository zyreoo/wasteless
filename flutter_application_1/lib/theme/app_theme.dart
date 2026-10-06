import 'package:flutter/material.dart';

/// Wasteless colour tokens. One brand green, one lime accent, warm neutrals
/// and three semantic colours; every screen draws from this list only.
class AppColors {
  // Brand
  static const Color brand = Color(0xFF2E5E3B);
  static const Color brandHover = Color(0xFF27512F);
  static const Color brandPressed = Color(0xFF1F4227);
  static const Color brandSoft = Color(0xFFE8F0E3);
  static const Color accent = Color(0xFFDDF2B0);
  static const Color onAccent = Color(0xFF24461F);

  // Surfaces
  static const Color background = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F3EF);
  static const Color border = Color(0xFFE7E6E1);
  static const Color borderStrong = Color(0xFFD4D3CC);

  // Text
  static const Color text = Color(0xFF1A1D19);
  static const Color textSecondary = Color(0xFF5B6058);
  static const Color textMuted = Color(0xFF8B9087);

  // Semantic
  static const Color success = Color(0xFF2F7A47);
  static const Color successSoft = Color(0xFFE6F2EA);
  static const Color warning = Color(0xFF9A5A06);
  static const Color warningSoft = Color(0xFFFDF1DC);
  static const Color error = Color(0xFFB42318);
  static const Color errorSoft = Color(0xFFFDECEA);
  static const Color favorite = Color(0xFFD64545);

  // Legacy names kept for the Figma preview screens.
  static const Color darkGreen = brand;
  static const Color mediumGreen = brand;
  static const Color primaryGreen = brand;
  static const Color lightGreen = brand;
  static const Color accentGreen = Color(0xFF90A955);
  static const Color splashBg = brand;
  static const Color scaffoldBg = background;
  static const Color cardBg = surface;
  static const Color headerBg = brand;
  static const Color limeYellow = accent;
  static const Color danger = error;
  static const Color textPrimary = text;
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color divider = border;
  static const Color inputBg = surfaceMuted;
  static const Color tagGreen = successSoft;
  static const Color tagGreenText = success;
  static const Color tagYellow = warningSoft;
  static const Color tagYellowText = warning;
  static const Color tagRed = errorSoft;
  static const Color tagRedText = error;
}

/// Spacing scale. Layouts use these steps only.
class Space {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
  static const double x3 = 48, x4 = 64;
}

/// Corner radii: controls, media/cards, pills.
class Radii {
  static const double s = 8, m = 12, l = 16, pill = 999;
}

/// Layout breakpoints.
class Breakpoints {
  /// From here the app shows the desktop sidebar instead of bottom tabs.
  static const double sidebar = 1000;
}

class AppTheme {
  static const _font = 'PlusJakartaSans';

  static const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.text,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.text,
    ),
    headlineSmall: TextStyle(
      fontSize: 21,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.text,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.text,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.text,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.textSecondary,
    ),
  );

  static ThemeData get theme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.brand,
          onPrimary: Colors.white,
          primaryContainer: AppColors.brandSoft,
          onPrimaryContainer: AppColors.brandPressed,
          secondary: AppColors.accent,
          onSecondary: AppColors.onAccent,
          secondaryContainer: AppColors.brandSoft,
          onSecondaryContainer: AppColors.brandPressed,
          surface: AppColors.background,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.surfaceMuted,
          surfaceContainer: AppColors.surfaceMuted,
          surfaceContainerHigh: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.border,
          outline: AppColors.borderStrong,
          outlineVariant: AppColors.border,
          error: AppColors.error,
          errorContainer: AppColors.errorSoft,
          surfaceTint: Colors.transparent,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.m),
    );
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
      hoverColor: AppColors.text.withValues(alpha: 0.04),
      focusColor: AppColors.brand.withValues(alpha: 0.12),
      highlightColor: AppColors.text.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: Space.l,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: AppColors.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: shape,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: shape,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: AppColors.brand,
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: outline(AppColors.borderStrong),
        enabledBorder: outline(AppColors.borderStrong),
        focusedBorder: outline(AppColors.brand, 1.5),
        errorBorder: outline(AppColors.error),
        focusedErrorBorder: outline(AppColors.error, 1.5),
        disabledBorder: outline(AppColors.border),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        helperStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandSoft,
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.border,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        labelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: Space.l),
        minVerticalPadding: Space.m,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
        width: 420,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.brandSoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(Radii.s),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
