import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Central place for the app's [ThemeData].
///
/// Usage: `MaterialApp(theme: AppTheme.lightTheme, ...)`.
class AppTheme {
  /// Not instantiable: this class only exposes static members.
  const AppTheme._();

  /// Built once and cached, so reading [lightTheme] on every rebuild does not
  /// construct a new [ThemeData] each time.
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    // Derive a complete, consistent color scheme from the brand color so that
    // buttons, inputs, switches, etc. match the primary color instead of the
    // framework's default seed.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        // Material 3 tints the app bar when content scrolls under it; keep the
        // original flat look.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.background,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}