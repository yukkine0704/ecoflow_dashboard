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
    final enabled = widget.onTap != null;
    final bg = switch (widget.surfaceLevel) {
      1 => colors.surfaceLow,
      2 => colors.surfaceHigh,
      _ => colors.surface,
    };

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
            boxShadow: [
              BoxShadow(
                color: colors.shadowTint.withValues(alpha: 0.05),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
