import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0F0F12);
  static const surface = Color(0xFF17171B);
  static const card = Color(0xFF1E1E23);
  static const border = Color(0xFF2B2B32);
  static const accent = Color(0xFFD99AAE);
  static const onAccent = Color(0xFF2A1319);

  /// Muted pinks used as flat artwork swatches.
  static const artPalette = [
    Color(0xFFE8B4BC),
    Color(0xFFD9A0AE),
    Color(0xFFC98B9C),
    Color(0xFFE3A9A5),
    Color(0xFFCFA0B8),
    Color(0xFFD8B0C0),
  ];
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFF9A9AA6);
  static const error = Color(0xFFFF5C5C);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadii {
  static const double card = 20;
  static const double control = 14;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    outline: AppColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );

  final text = base.textTheme.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyMedium: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
      thumbColor: AppColors.textPrimary,
      overlayColor: AppColors.accent.withValues(alpha: 0.16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.card,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    dividerColor: AppColors.border,
  );
}
