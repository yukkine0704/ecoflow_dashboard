import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum AppStatusTone { neutral, active, warning, danger }

enum AppStatusBadgeAnimation { none, surplus, deficit }

class AppStatusBadge extends StatefulWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.onTap,
    this.highlighted = false,
    this.animation = AppStatusBadgeAnimation.none,
    this.scale = 1.0,
  });

  final String label;
  final AppStatusTone tone;
  final VoidCallback? onTap;
  final bool highlighted;
  final AppStatusBadgeAnimation animation;
  final double scale;

  @override
  State<AppStatusBadge> createState() => _AppStatusBadgeState();
}

class _AppStatusBadgeState extends State<AppStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    if (widget.animation != AppStatusBadgeAnimation.none) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AppStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    if (widget.animation == AppStatusBadgeAnimation.none) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = switch (widget.tone) {
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md * widget.scale,
        vertical: AppSpacing.sm * widget.scale,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: AppRadius.full,
        border: widget.highlighted
            ? Border.all(color: palette.fg, width: 1.3)
            : null,
        boxShadow: widget.highlighted
            ? [
                BoxShadow(
                  color: palette.fg.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0.6,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.animation != AppStatusBadgeAnimation.none) ...[
            SizedBox(
              width: 12 * widget.scale,
              height: 12 * widget.scale,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BadgeFxPainter(
                      t: _controller.value,
                      color: palette.fg,
                      mode: widget.animation,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 8 * widget.scale),
          ],
          Text(
            widget.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.fg,
              fontWeight: FontWeight.w800,
              fontSize:
                  (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) *
                  widget.scale,
            ),
          ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return badge;
    }
    return InkWell(
      borderRadius: AppRadius.full,
      onTap: widget.onTap,
      child: badge,
    );
  }
}

class _BadgeFxPainter extends CustomPainter {
  const _BadgeFxPainter({
    required this.t,
    required this.color,
    required this.mode,
  });

  final double t;
  final Color color;
  final AppStatusBadgeAnimation mode;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case AppStatusBadgeAnimation.surplus:
        _paintSurplus(canvas, size);
      case AppStatusBadgeAnimation.deficit:
        _paintDeficit(canvas, size);
      case AppStatusBadgeAnimation.none:
        break;
    }
  }

  void _paintSurplus(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawCircle(center, 2.0, base);

    final ringProgress = Curves.easeOut.transform((t + 0.1) % 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: (1 - ringProgress) * 0.6);
    canvas.drawCircle(center, 2.5 + (ringProgress * 3.5), ring);
  }

  void _paintDeficit(Canvas canvas, Size size) {
    final x = size.width / 2;
    final travel = size.height * 0.65;

    for (var i = 0; i < 2; i++) {
      final phase = (t + (i * 0.5)) % 1.0;
      final y = size.height - (phase * travel);
      final scale = 1 - phase;
      final p = Paint()..color = color.withValues(alpha: (1 - phase) * 0.65);
      canvas.drawCircle(Offset(x, y), 1.2 + scale * 1.4, p);
    }

    canvas.drawCircle(
      Offset(x, size.height - 1.6),
      1.8,
      Paint()..color = color.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _BadgeFxPainter oldDelegate) {
    return t != oldDelegate.t ||
        color != oldDelegate.color ||
        mode != oldDelegate.mode;
  }
}
