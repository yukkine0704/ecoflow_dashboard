import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.error,
    required this.outline,
    required this.outlineVariant,
    required this.shadowTint,
    required this.gaugeTrack,
  });

  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color error;
  final Color outline;
  final Color outlineVariant;
  final Color shadowTint;
  final Color gaugeTrack;

  static const AppColors light = AppColors(
    background: Color(0xFFFEF9EF),
    surface: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF8F3E8),
    surfaceHigh: Color(0xFFEDE8DA),
    surfaceHighest: Color(0xFFE7E2D3),
    onSurface: Color(0xFF353328),
    onSurfaceVariant: Color(0xFF625F53),
    primary: Color(0xFF974A00),
    primaryContainer: Color(0xFFFFAF78),
    onPrimaryContainer: Color(0xFF622E00),
    secondary: Color(0xFF006F1D),
    secondaryContainer: Color(0xFF94F990),
    onSecondaryContainer: Color(0xFF006017),
    tertiary: Color(0xFF7A5A00),
    tertiaryContainer: Color(0xFFFEC330),
    error: Color(0xFFAA371C),
    outline: Color(0xFF7E7B6E),
    outlineVariant: Color(0xFFB6B2A3),
    shadowTint: Color(0xFF353328),
    gaugeTrack: Color(0xFFF3EEE1),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0D0F0F),
    surface: Color(0xFF171A1A),
    surfaceLow: Color(0xFF111414),
    surfaceHigh: Color(0xFF1D2020),
    surfaceHighest: Color(0xFF232626),
    onSurface: Color(0xFFF3F6F5),
    onSurfaceVariant: Color(0xFFD2D8D7),
    primary: Color(0xFFFFAA85),
    primaryContainer: Color(0xFFFE9568),
    onPrimaryContainer: Color(0xFF591D00),
    secondary: Color(0xFF87D5BD),
    secondaryContainer: Color(0xFF002C22),
    onSecondaryContainer: Color(0xFF64B29B),
    tertiary: Color(0xFFFFE9B0),
    tertiaryContainer: Color(0xFFFFDA65),
    error: Color(0xFFFF716C),
    outline: Color(0xFF727676),
    outlineVariant: Color(0xFF454949),
    shadowTint: Color(0xFFAA8573),
    gaugeTrack: Color(0xFF232626),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? primary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? tertiaryContainer,
    Color? error,
    Color? outline,
    Color? outlineVariant,
    Color? shadowTint,
    Color? gaugeTrack,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      error: error ?? this.error,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      shadowTint: shadowTint ?? this.shadowTint,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(
    covariant ThemeExtension<AppColors>? other,
    double t,
  ) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryContainer: Color.lerp(
        tertiaryContainer,
        other.tertiaryContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      shadowTint: Color.lerp(shadowTint, other.shadowTint, t)!,
      gaugeTrack: Color.lerp(gaugeTrack, other.gaugeTrack, t)!,
    );
  }
}
