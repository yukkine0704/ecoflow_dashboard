import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum AppStatusTone { neutral, active, warning, danger }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.onTap,
    this.highlighted = false,
  });

  final String label;
  final AppStatusTone tone;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = switch (tone) {
      AppStatusTone.neutral => (
        bg: colors.surfaceHigh,
        fg: colors.onSurfaceVariant,
      ),
      AppStatusTone.active => (
        bg: colors.secondaryContainer.withValues(alpha: 0.22),
        fg: colors.onSecondaryContainer,
      ),
      AppStatusTone.warning => (
        bg: colors.tertiaryContainer.withValues(alpha: 0.3),
        fg: colors.tertiary,
      ),
      AppStatusTone.danger => (
        bg: colors.error.withValues(alpha: 0.2),
        fg: colors.error,
      ),
    };
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: AppRadius.full,
        border: highlighted ? Border.all(color: palette.fg, width: 1.3) : null,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: palette.fg.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0.6,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return InkWell(
      borderRadius: AppRadius.full,
      onTap: onTap,
      child: badge,
    );
  }
}
