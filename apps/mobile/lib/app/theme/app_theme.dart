import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppRadius {
  const AppRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildAppTheme() {
  final scheme = const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
    outline: AppColors.border,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.title,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryTintStrong,
      labelTextStyle: WidgetStatePropertyAll(AppText.caption.copyWith(fontWeight: FontWeight.w600)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.border,
      ),
    ),
  );
}
