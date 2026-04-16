import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum AppChipTone { neutral, primary, success, warning }

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = AppChipTone.neutral,
    this.leading,
    this.onTap,
  });

  final String label;
  final AppChipTone tone;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = switch (tone) {
      AppChipTone.neutral => (
        bg: colors.surfaceHigh,
        fg: colors.onSurfaceVariant,
      ),
      AppChipTone.primary => (
        bg: colors.primaryContainer.withValues(alpha: 0.22),
        fg: colors.onPrimaryContainer,
      ),
      AppChipTone.success => (
        bg: colors.secondaryContainer.withValues(alpha: 0.25),
        fg: colors.onSecondaryContainer,
      ),
      AppChipTone.warning => (
        bg: colors.tertiaryContainer.withValues(alpha: 0.3),
        fg: colors.tertiary,
      ),
    };

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.full,
        color: palette.bg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: palette.fg, size: 14),
              child: leading!,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}
