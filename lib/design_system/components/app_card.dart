import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.surfaceLevel = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final int surfaceLevel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onTap != null;
    final level = widget.surfaceLevel.clamp(0, 2);
    final base = switch (level) {
      1 => colors.surfaceLow,
      2 => colors.surfaceHigh,
      _ => colors.surface,
    };
    final toneMix = switch (level) {
      2 => isDark ? 0.065 : 0.03,
      1 => isDark ? 0.05 : 0.022,
      _ => isDark ? 0.04 : 0.015,
    };
    final shadowDistance = switch (level) {
      2 => 14.0,
      1 => 10.0,
      _ => 8.0,
    };
    final shadowBlur = switch (level) {
      2 => 28.0,
      1 => 22.0,
      _ => 18.0,
    };
    final bg = Color.lerp(
          base,
          colors.onSurface,
          toneMix,
        ) ??
        base;
    final lightShadow = isDark
        ? Colors.white.withValues(alpha: level == 2 ? 0.06 : 0.05)
        : Colors.white.withValues(alpha: level == 2 ? 0.92 : 0.88);
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: level == 2 ? 0.46 : 0.4)
        : colors.onSurface.withValues(alpha: level == 2 ? 0.16 : 0.12);
    final borderColor = Color.lerp(
          bg,
          colors.onSurface,
          switch (level) {
            2 => isDark ? 0.18 : 0.12,
            1 => isDark ? 0.17 : 0.11,
            _ => isDark ? 0.16 : 0.1,
          },
        ) ??
        bg;
    final normalShadows = <BoxShadow>[
      BoxShadow(
        color: darkShadow,
        blurRadius: shadowBlur,
        offset: Offset(shadowDistance, shadowDistance),
      ),
      BoxShadow(
        color: lightShadow,
        blurRadius: shadowBlur,
        offset: Offset(-shadowDistance, -shadowDistance),
      ),
    ];
    final pressedShadows = <BoxShadow>[
      BoxShadow(
        color: darkShadow.withValues(alpha: isDark ? 0.28 : 0.09),
        blurRadius: 12,
        offset: const Offset(4, 4),
      ),
      BoxShadow(
        color: lightShadow.withValues(alpha: isDark ? 0.04 : 0.7),
        blurRadius: 12,
        offset: const Offset(-4, -4),
      ),
    ];

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: Transform.scale(
        scale: _pressed ? 0.99 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.xl,
            border: Border.all(
              color: borderColor.withValues(alpha: isDark ? 0.75 : 0.6),
              width: 1,
            ),
            boxShadow: _pressed ? pressedShadows : normalShadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
