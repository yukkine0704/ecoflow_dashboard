import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.filled = false,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final double size;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = widget.onPressed != null;
    final bg = widget.filled ? colors.primaryContainer : colors.surfaceHigh;
    final fg = widget.filled ? colors.onPrimaryContainer : colors.onSurface;

    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: Transform.scale(
          scale: _pressed ? 0.96 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.size.clamp(44, 64),
            height: widget.size.clamp(44, 64),
            decoration: BoxDecoration(
              borderRadius: AppRadius.full,
              color: bg,
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: colors.shadowTint.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Icon(widget.icon, size: 20, color: fg),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip ?? 'Icon button',
      child: widget.tooltip == null
          ? child
          : Tooltip(message: widget.tooltip!, child: child),
    );
  }
}
