import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_metrics.dart';
import 'app_gooey_toast.dart';
import 'app_gooey_toast_models.dart';

class AppGooeyToasterHost extends StatefulWidget {
  const AppGooeyToasterHost({
    super.key,
    required this.child,
    this.visibleToasts = 3,
    this.gap = 14,
    this.offset = 8,
    this.horizontalInset = 16,
  });

  final Widget child;
  final int visibleToasts;
  final double gap;
  final double offset;
  final double horizontalInset;

  @override
  State<AppGooeyToasterHost> createState() => AppGooeyToasterHostState();
}

class AppGooeyToasterHostState extends State<AppGooeyToasterHost>
    implements AppGooeyToastHostController {
  final List<AppToastData> _toasts = [];
  final Map<String, Timer> _timers = {};

  bool _expandedTop = false;
  bool _expandedBottom = false;

  @override
  void initState() {
    super.initState();
    appGooeyToast.bindHost(this);
  }

  @override
  void dispose() {
    appGooeyToast.unbindHost(this);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void showToast(AppToastData toast) {
    _timers[toast.id]?.cancel();
    _scheduleDismiss(toast.id, toast.duration);
    setState(() {
      _toasts.insert(0, toast);
    });
  }

  @override
  void updateToast(
    String id, {
    String? title,
    AppToastType? type,
    String? description,
    bool? dismissible,
    Duration? duration,
  }) {
    final index = _toasts.indexWhere((t) => t.id == id);
    if (index < 0) {
      return;
    }
    final updated = _toasts[index].copyWith(
      title: title,
      type: type,
      description: description,
      dismissible: dismissible,
      duration: duration,
    );
    _timers[id]?.cancel();
    _scheduleDismiss(id, updated.duration);
    setState(() {
      _toasts[index] = updated;
    });
  }

  @override
  void dismissToast(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    setState(() {
      _toasts.removeWhere((t) => t.id == id);
      _syncExpanded();
    });
  }

  @override
  void dismissAllToasts() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    setState(() {
      _toasts.clear();
      _expandedTop = false;
      _expandedBottom = false;
    });
  }

  void _scheduleDismiss(String id, Duration duration) {
    if (duration == Duration.zero || duration.inDays > 300) {
      return;
    }
    _timers[id] = Timer(duration, () => dismissToast(id));
  }

  void _syncExpanded() {
    final topCount = _toasts
        .where((t) => t.position == AppToastPosition.topCenter)
        .length;
    final bottomCount = _toasts
        .where((t) => t.position == AppToastPosition.bottomCenter)
        .length;
    if (topCount <= 1) {
      _expandedTop = false;
    }
    if (bottomCount <= 1) {
      _expandedBottom = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topToasts = _toasts
        .where((t) => t.position == AppToastPosition.topCenter)
        .toList();
    final bottomToasts = _toasts
        .where((t) => t.position == AppToastPosition.bottomCenter)
        .toList();

    return Stack(
      children: [
        widget.child,
        _ToastStack(
          toasts: topToasts,
          visibleToasts: widget.visibleToasts,
          gap: widget.gap,
          offset: widget.offset,
          horizontalInset: widget.horizontalInset,
          expanded: _expandedTop,
          verticalTop: true,
          onToggleExpanded: () {
            if (topToasts.length > 1) {
              setState(() => _expandedTop = !_expandedTop);
            }
          },
          onDismiss: dismissToast,
        ),
        _ToastStack(
          toasts: bottomToasts,
          visibleToasts: widget.visibleToasts,
          gap: widget.gap,
          offset: widget.offset,
          horizontalInset: widget.horizontalInset,
          expanded: _expandedBottom,
          verticalTop: false,
          onToggleExpanded: () {
            if (bottomToasts.length > 1) {
              setState(() => _expandedBottom = !_expandedBottom);
            }
          },
          onDismiss: dismissToast,
        ),
      ],
    );
  }
}

class _ToastStack extends StatelessWidget {
  const _ToastStack({
    required this.toasts,
    required this.visibleToasts,
    required this.gap,
    required this.offset,
    required this.horizontalInset,
    required this.expanded,
    required this.verticalTop,
    required this.onToggleExpanded,
    required this.onDismiss,
  });

  final List<AppToastData> toasts;
  final int visibleToasts;
  final double gap;
  final double offset;
  final double horizontalInset;
  final bool expanded;
  final bool verticalTop;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) {
      return const SizedBox.shrink();
    }
    final insets = MediaQuery.paddingOf(context);
    final edgeOffset = (verticalTop ? insets.top : insets.bottom) + offset;

    return Positioned(
      top: verticalTop ? edgeOffset : null,
      bottom: verticalTop ? null : edgeOffset,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onToggleExpanded,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: SizedBox(
            height: expanded ? (toasts.length * 108) + 32 : 124,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < toasts.length; i++)
                  _StackedToastItem(
                    toast: toasts[i],
                    index: i,
                    expanded: expanded,
                    visibleToasts: visibleToasts,
                    gap: gap,
                    verticalTop: verticalTop,
                    onDismiss: () => onDismiss(toasts[i].id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedToastItem extends StatelessWidget {
  const _StackedToastItem({
    required this.toast,
    required this.index,
    required this.expanded,
    required this.visibleToasts,
    required this.gap,
    required this.verticalTop,
    required this.onDismiss,
  });

  final AppToastData toast;
  final int index;
  final bool expanded;
  final int visibleToasts;
  final double gap;
  final bool verticalTop;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hidden = !expanded && index >= visibleToasts;
    if (hidden) {
      return const SizedBox.shrink();
    }

    final collapsedDepth = math.min(index, visibleToasts - 1);
    final collapsedOffset = collapsedDepth * 10.0;
    final expandedOffset = index * (72 + gap);
    final y = expanded ? expandedOffset : collapsedOffset;
    final scale = expanded
        ? 1.0
        : (1 - (collapsedDepth * 0.04)).clamp(0.86, 1.0);
    final opacity = expanded
        ? 1.0
        : (1 - (collapsedDepth * 0.2)).clamp(0.35, 1.0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      top: verticalTop ? y : null,
      bottom: verticalTop ? null : y,
      left: 0,
      right: 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: _GooeyToastCard(
            toast: toast,
            expanded: expanded,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }
}

class _GooeyToastCard extends StatefulWidget {
  const _GooeyToastCard({
    required this.toast,
    required this.expanded,
    required this.onDismiss,
  });

  final AppToastData toast;
  final bool expanded;
  final VoidCallback onDismiss;

  @override
  State<_GooeyToastCard> createState() => _GooeyToastCardState();
}

class _GooeyToastCardState extends State<_GooeyToastCard> {
  double _dragX = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = _palette(colors, widget.toast.type);
    final hasBody =
        (widget.toast.description?.isNotEmpty ?? false) ||
        widget.toast.action != null;
    final showExpandedBody = widget.expanded && hasBody;
    final morph = showExpandedBody ? 1.0 : 0.0;
    final height = showExpandedBody ? 116.0 : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()..translate(_dragX, 0.0),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) =>
            setState(() => _dragX += details.delta.dx),
        onHorizontalDragEnd: (_) {
          if (_dragX.abs() > 46 && widget.toast.dismissible) {
            widget.onDismiss();
          } else {
            setState(() => _dragX = 0);
          }
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: _GooeySurfacePainter(
                color: palette.surface,
                stroke: palette.stroke,
                morph: morph,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 58;
                      if (compact) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                _TypeDot(
                                  type: widget.toast.type,
                                  color: palette.icon,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    widget.toast.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: palette.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _TypeDot(
                                  type: widget.toast.type,
                                  color: palette.icon,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    widget.toast.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: palette.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (widget.toast.showTimestamp)
                                  Text(
                                    _formatTimestamp(widget.toast.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.meta),
                                  ),
                              ],
                            ),
                            if (showExpandedBody) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.toast.description ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: palette.meta),
                                    ),
                                  ),
                                  if (widget.toast.meta != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      widget.toast.meta!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: palette.meta),
                                    ),
                                  ],
                                ],
                              ),
                              if (widget.toast.action != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      widget.toast.action?.onPressed();
                                      if (widget.toast.dismissible) {
                                        widget.onDismiss();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.actionBg,
                                        borderRadius: AppRadius.full,
                                      ),
                                      child: Text(
                                        widget.toast.action!.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: palette.actionText,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.type, required this.color});

  final AppToastType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (type == AppToastType.loading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _GooeyPalette {
  const _GooeyPalette({
    required this.surface,
    required this.stroke,
    required this.text,
    required this.meta,
    required this.icon,
    required this.progress,
    required this.track,
    required this.actionBg,
    required this.actionText,
  });

  final Color surface;
  final Color stroke;
  final Color text;
  final Color meta;
  final Color icon;
  final Color progress;
  final Color track;
  final Color actionBg;
  final Color actionText;
}

_GooeyPalette _palette(AppColors colors, AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return _GooeyPalette(
        surface: colors.secondaryContainer.withValues(alpha: 0.35),
        stroke: colors.secondary.withValues(alpha: 0.4),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.secondary,
        progress: colors.secondary,
        track: colors.surfaceHighest,
        actionBg: colors.secondary,
        actionText: colors.surface,
      );
    case AppToastType.error:
      return _GooeyPalette(
        surface: colors.error.withValues(alpha: 0.24),
        stroke: colors.error.withValues(alpha: 0.4),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.error,
        progress: colors.error,
        track: colors.surfaceHighest,
        actionBg: colors.error,
        actionText: colors.surface,
      );
    case AppToastType.warning:
      return _GooeyPalette(
        surface: colors.tertiaryContainer.withValues(alpha: 0.34),
        stroke: colors.tertiary.withValues(alpha: 0.4),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.tertiary,
        progress: colors.tertiary,
        track: colors.surfaceHighest,
        actionBg: colors.tertiary,
        actionText: colors.surface,
      );
    case AppToastType.info:
      return _GooeyPalette(
        surface: colors.primaryContainer.withValues(alpha: 0.3),
        stroke: colors.primary.withValues(alpha: 0.4),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.primary,
        progress: colors.primary,
        track: colors.surfaceHighest,
        actionBg: colors.primary,
        actionText: colors.surface,
      );
    case AppToastType.loading:
      return _GooeyPalette(
        surface: colors.surfaceLow.withValues(alpha: 0.66),
        stroke: colors.outlineVariant.withValues(alpha: 0.4),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.onSurface,
        progress: colors.primary,
        track: colors.surfaceHighest,
        actionBg: colors.surfaceHighest,
        actionText: colors.onSurface,
      );
    case AppToastType.normal:
      return _GooeyPalette(
        surface: colors.surfaceLow.withValues(alpha: 0.7),
        stroke: colors.outlineVariant.withValues(alpha: 0.35),
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.onSurface,
        progress: colors.primary,
        track: colors.surfaceHighest,
        actionBg: colors.primaryContainer,
        actionText: colors.onPrimaryContainer,
      );
  }
}

class _GooeySurfacePainter extends CustomPainter {
  const _GooeySurfacePainter({
    required this.color,
    required this.stroke,
    required this.morph,
  });

  final Color color;
  final Color stroke;
  final double morph;

  @override
  void paint(Canvas canvas, Size size) {
    final r = lerpDouble(26, 22, morph)!;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );

    final path = Path()..addRRect(rect);
    if (morph > 0) {
      final bumpW = lerpDouble(0, size.width * 0.2, morph)!;
      final bumpH = lerpDouble(0, 8, morph)!;
      final bumpStart = size.width - bumpW - 24;
      path.moveTo(bumpStart, 0);
      path.quadraticBezierTo(
        bumpStart + (bumpW / 2),
        -bumpH,
        bumpStart + bumpW,
        0,
      );
    }

    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.1), 12, false);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GooeySurfacePainter other) {
    return color != other.color ||
        stroke != other.stroke ||
        morph != other.morph;
  }
}
