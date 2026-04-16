import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum AppStatusTone { neutral, active, warning, danger }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final AppStatusTone tone;

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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
