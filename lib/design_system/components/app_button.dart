import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_metrics.dart';

enum AppButtonVariant { primary, secondary, tertiary, danger }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.trailing,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final bool loading;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool fullWidth;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final height = switch (widget.size) {
      AppButtonSize.small => 44.0,
      AppButtonSize.medium => 50.0,
      AppButtonSize.large => 56.0,
    };
    final horizontalPadding = switch (widget.size) {
      AppButtonSize.small => 16.0,
      AppButtonSize.medium => 20.0,
      AppButtonSize.large => 24.0,
    };

    final ({Color bg, Color fg, Gradient? gradient}) palette = _palette(colors);
    final bgColor = _enabled
        ? palette.bg
        : Color.alphaBlend(
            colors.onSurface.withValues(alpha: 0.08),
            palette.bg,
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: _enabled ? 1 : 0.6,
        child: GestureDetector(
          onTap: _enabled ? widget.onPressed : null,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height,
              minWidth: widget.fullWidth ? double.infinity : 0,
            ),
            child: Transform.scale(
              scale: _pressed ? 0.985 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.full,
                  gradient: palette.gradient,
                  color: palette.gradient == null ? bgColor : null,
                  boxShadow: _pressed
                      ? null
                      : [
                          BoxShadow(
                            color: colors.shadowTint.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                ),
                child: Center(
                  child: _buildChild(
                    context: context,
                    fg: palette.fg,
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild({
    required BuildContext context,
    required Color fg,
    TextStyle? style,
  }) {
    if (widget.loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leading != null) ...[
          IconTheme(
            data: IconThemeData(color: fg, size: 18),
            child: widget.leading!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(widget.label, style: style),
        if (widget.trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          IconTheme(
            data: IconThemeData(color: fg, size: 18),
            child: widget.trailing!,
          ),
        ],
      ],
    );
  }

  ({Color bg, Color fg, Gradient? gradient}) _palette(AppColors colors) {
    return switch (widget.variant) {
      AppButtonVariant.primary => (
        bg: colors.primaryContainer,
        fg: colors.onPrimaryContainer,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.86),
          ],
        ),
      ),
      AppButtonVariant.secondary => (
        bg: colors.surfaceHigh,
        fg: colors.onSurface,
        gradient: null,
      ),
      AppButtonVariant.tertiary => (
        bg: colors.surfaceLow.withValues(alpha: 0.3),
        fg: colors.onSurface,
        gradient: null,
      ),
      AppButtonVariant.danger => (
        bg: colors.error,
        fg: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.error, colors.error.withValues(alpha: 0.75)],
        ),
      ),
    };
  }
}
