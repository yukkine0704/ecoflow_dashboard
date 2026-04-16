import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() =>
      _buildTheme(brightness: Brightness.light, colors: AppColors.light);

  static ThemeData dark() =>
      _buildTheme(brightness: Brightness.dark, colors: AppColors.dark);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = buildAppTextTheme(brightness);
    return ThemeData(
      brightness: brightness,
      useMaterial3: false,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primaryContainer,
        onPrimary: colors.onPrimaryContainer,
        secondary: colors.secondary,
        onSecondary: colors.onSecondaryContainer,
        error: colors.error,
        onError: isDark ? const Color(0xFF490006) : const Color(0xFFFFF7F6),
        surface: colors.surface,
        onSurface: colors.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardColor: colors.surface,
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}
