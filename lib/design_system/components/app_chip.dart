import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum AppChipTone { neutral, primary, success, warning }

class AppChip extends StatefulWidget {
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
  State<AppChip> createState() => _AppChipState();
}

class _AppChipState extends State<AppChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = switch (widget.tone) {
      AppChipTone.neutral => (
        bg: colors.surfaceHigh,
        fg: colors.onSurfaceVariant,
      ),
      AppChipTone.primary => (
        bg: Color.lerp(
              colors.surfaceHigh,
              colors.primaryContainer,
              isDark ? 0.3 : 0.38,
            ) ??
            colors.primaryContainer.withValues(alpha: isDark ? 0.32 : 0.22),
        fg: colors.primary,
      ),
      AppChipTone.success => (
        bg: Color.lerp(colors.surfaceHigh, colors.secondaryContainer, 0.38) ??
            colors.secondaryContainer.withValues(alpha: 0.25),
        fg: colors.onSecondaryContainer,
      ),
      AppChipTone.warning => (
        bg: Color.lerp(colors.surfaceHigh, colors.tertiaryContainer, 0.4) ??
            colors.tertiaryContainer.withValues(alpha: 0.3),
        fg: colors.tertiary,
      ),
    };

    final lightShadow = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : colors.onSurface.withValues(alpha: 0.16);
    final borderColor = Color.lerp(
          palette.bg,
          palette.fg,
          isDark ? 0.2 : 0.14,
        ) ??
        palette.bg;

    final outerShadow = <BoxShadow>[
      BoxShadow(
        color: lightShadow,
        offset: const Offset(-3, -2),
        blurRadius: 8,
      ),
      BoxShadow(
        color: darkShadow,
        offset: const Offset(3, 2),
        blurRadius: 8,
      ),
    ];

    final pressedShadow = <BoxShadow>[
      BoxShadow(
        color: darkShadow.withValues(alpha: isDark ? 0.28 : 0.12),
        offset: const Offset(1, 1),
        blurRadius: 3,
      ),
      BoxShadow(
        color: lightShadow.withValues(alpha: isDark ? 0.05 : 0.42),
        offset: const Offset(-1, -1),
        blurRadius: 3,
      ),
    ];
    final pressedGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        palette.bg.withValues(alpha: isDark ? 0.7 : 0.92),
        palette.bg,
        palette.bg.withValues(alpha: isDark ? 0.92 : 0.78),
      ],
    );

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.full,
        color: palette.bg,
        gradient: _isPressed ? pressedGradient : null,
        border: Border.all(
          color: _isPressed
              ? borderColor.withValues(alpha: isDark ? 0.18 : 0.84)
              : borderColor,
          width: 1,
        ),
        boxShadow: _isPressed ? pressedShadow : outerShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            IconTheme(
              data: IconThemeData(color: palette.fg, size: 14),
              child: widget.leading!,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            widget.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
      ),
    );
  }
}
