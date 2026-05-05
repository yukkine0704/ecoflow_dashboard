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

class _ToastLifetime {
  _ToastLifetime({required this.remaining});

  Duration remaining;
  DateTime? startedAt;
  Timer? timer;
  bool dismissed = false;

  void cancel() {
    timer?.cancel();
    timer = null;
    startedAt = null;
  }
}

class AppGooeyToasterHostState extends State<AppGooeyToasterHost>
    implements AppGooeyToastHostController {
  final List<AppToastData> _toasts = [];
  final Map<String, _ToastLifetime> _lifetimes = {};
  final Set<String> _interactionPaused = <String>{};

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
    for (final lifetime in _lifetimes.values) {
      lifetime.cancel();
    }
    super.dispose();
  }

  @override
  void showToast(AppToastData toast) {
    _lifetimes[toast.id]?.cancel();
    _lifetimes[toast.id] = _ToastLifetime(remaining: toast.duration);
    setState(() {
      _toasts.insert(0, toast);
      _syncExpanded();
    });
    _evaluateTimerState(toast.id);
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

    final life = _lifetimes[id];
    if (duration != null) {
      if (life != null) {
        life.cancel();
        life.remaining = duration;
      } else {
        _lifetimes[id] = _ToastLifetime(remaining: duration);
      }
    }

    setState(() {
      _toasts[index] = updated;
    });
    _evaluateTimerState(id);
  }

  @override
  void dismissToast(String id) {
    _lifetimes[id]?.cancel();
    _lifetimes.remove(id);
    _interactionPaused.remove(id);

    setState(() {
      _toasts.removeWhere((t) => t.id == id);
      _syncExpanded();
    });
  }

  @override
  void dismissAllToasts() {
    for (final lifetime in _lifetimes.values) {
      lifetime.cancel();
    }
    _lifetimes.clear();
    _interactionPaused.clear();
    setState(() {
      _toasts.clear();
      _expandedTop = false;
      _expandedBottom = false;
    });
  }

  bool _isPersistent(Duration duration) {
    return duration == Duration.zero || duration.inDays > 300;
  }

  bool _hasPauseReason(AppToastData toast) {
    if (!toast.pauseOnInteraction) {
      return false;
    }
    final expandedByPosition = toast.position == AppToastPosition.topCenter
        ? _expandedTop
        : _expandedBottom;
    return expandedByPosition || _interactionPaused.contains(toast.id);
  }

  void _evaluateTimerState(String id) {
    final toast = _toasts.cast<AppToastData?>().firstWhere(
      (candidate) => candidate?.id == id,
      orElse: () => null,
    );
    if (toast == null) {
      return;
    }

    final life = _lifetimes[id] ??= _ToastLifetime(remaining: toast.duration);
    if (_isPersistent(toast.duration) || life.dismissed) {
      life.cancel();
      return;
    }

    if (_hasPauseReason(toast)) {
      _pauseLifetime(id);
      return;
    }
    _resumeLifetime(id);
  }

  void _pauseLifetime(String id) {
    final life = _lifetimes[id];
    if (life == null || life.startedAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(life.startedAt!);
    final remainingMs = math.max(
      0,
      life.remaining.inMilliseconds - elapsed.inMilliseconds,
    );
    life.remaining = Duration(milliseconds: remainingMs);
    life.cancel();
  }

  void _resumeLifetime(String id) {
    final life = _lifetimes[id];
    final toast = _toasts.cast<AppToastData?>().firstWhere(
      (candidate) => candidate?.id == id,
      orElse: () => null,
    );
    if (life == null || toast == null) {
      return;
    }
    if (_isPersistent(toast.duration)) {
      life.cancel();
      return;
    }
    if (life.startedAt != null || life.timer != null) {
      return;
    }
    if (life.remaining <= Duration.zero) {
      dismissToast(id);
      return;
    }

    life.startedAt = DateTime.now();
    life.timer = Timer(life.remaining, () {
      life.dismissed = true;
      dismissToast(id);
    });
  }

  void _setExpandedForPosition(AppToastPosition position, bool expanded) {
    setState(() {
      if (position == AppToastPosition.topCenter) {
        _expandedTop = expanded;
      } else {
        _expandedBottom = expanded;
      }
    });

    for (final toast in _toasts.where((t) => t.position == position)) {
      _evaluateTimerState(toast.id);
    }
  }

  void _setInteractionPause(String id, bool isInteracting) {
    if (isInteracting) {
      _interactionPaused.add(id);
    } else {
      _interactionPaused.remove(id);
    }
    _evaluateTimerState(id);
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
              _setExpandedForPosition(
                AppToastPosition.topCenter,
                !_expandedTop,
              );
            }
          },
          onDismiss: dismissToast,
          onInteractionChanged: _setInteractionPause,
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
              _setExpandedForPosition(
                AppToastPosition.bottomCenter,
                !_expandedBottom,
              );
            }
          },
          onDismiss: dismissToast,
          onInteractionChanged: _setInteractionPause,
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
    required this.onInteractionChanged,
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
  final void Function(String id, bool isInteracting) onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) {
      return const SizedBox.shrink();
    }

    final insets = MediaQuery.paddingOf(context);
    final edgeOffset = (verticalTop ? insets.top : insets.bottom) + offset;
    final visibleCount = expanded
        ? toasts.length
        : math.min(toasts.length, visibleToasts);

    return Positioned(
      top: verticalTop ? edgeOffset : null,
      bottom: verticalTop ? null : edgeOffset,
      left: horizontalInset,
      right: horizontalInset,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < visibleCount; i++) ...[
                      _StackedToastItem(
                        toast: toasts[i],
                        index: i,
                        expanded: true,
                        visibleToasts: visibleToasts,
                        verticalTop: verticalTop,
                        onDismiss: () => onDismiss(toasts[i].id),
                        onTapLeader: i == 0 ? onToggleExpanded : null,
                        onInteractionChanged: (value) =>
                            onInteractionChanged(toasts[i].id, value),
                      ),
                      if (i != visibleCount - 1) SizedBox(height: gap),
                    ],
                  ],
                )
              : SizedBox(
                  height: 96,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int i = 0; i < visibleCount; i++)
                        _StackedToastItem(
                          toast: toasts[i],
                          index: i,
                          expanded: false,
                          visibleToasts: visibleToasts,
                          verticalTop: verticalTop,
                          onDismiss: () => onDismiss(toasts[i].id),
                          onTapLeader: i == 0 ? onToggleExpanded : null,
                          onInteractionChanged: (value) =>
                              onInteractionChanged(toasts[i].id, value),
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
    required this.verticalTop,
    required this.onDismiss,
    required this.onTapLeader,
    required this.onInteractionChanged,
  });

  final AppToastData toast;
  final int index;
  final bool expanded;
  final int visibleToasts;
  final bool verticalTop;
  final VoidCallback onDismiss;
  final VoidCallback? onTapLeader;
  final ValueChanged<bool> onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    final collapsedDepth = math.min(index, visibleToasts - 1);
    final collapsedOffset = collapsedDepth * 10.0;
    final scale = (1 - (collapsedDepth * 0.04)).clamp(0.86, 1.0);
    final opacity = (1 - (collapsedDepth * 0.18)).clamp(0.35, 1.0);

    final card = _GooeyToastCard(
      toast: toast,
      expanded: expanded,
      onDismiss: onDismiss,
      onTapLeader: onTapLeader,
      onInteractionChanged: onInteractionChanged,
    );

    if (expanded) {
      return card;
    }

    return Positioned(
      top: verticalTop ? collapsedOffset : null,
      bottom: verticalTop ? null : collapsedOffset,
      left: 0,
      right: 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        scale: scale,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: opacity,
          child: IgnorePointer(ignoring: index != 0, child: card),
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
    required this.onTapLeader,
    required this.onInteractionChanged,
  });

  final AppToastData toast;
  final bool expanded;
  final VoidCallback onDismiss;
  final VoidCallback? onTapLeader;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<_GooeyToastCard> createState() => _GooeyToastCardState();
}

class _GooeyToastCardState extends State<_GooeyToastCard> {
  double _dragX = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = _palette(
      colors,
      widget.toast.type,
      Theme.of(context).brightness,
    );
    final hasBody =
        (widget.toast.description?.isNotEmpty ?? false) ||
        widget.toast.action != null ||
        widget.toast.meta != null;
    final showExpandedBody = widget.expanded && hasBody;
    final morph = showExpandedBody ? 1.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()..translateByDouble(_dragX, 0.0, 0.0, 1.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapLeader,
        onHorizontalDragStart: (_) => widget.onInteractionChanged(true),
        onHorizontalDragUpdate: (details) =>
            setState(() => _dragX += details.delta.dx),
        onHorizontalDragEnd: (_) {
          final width = context.size?.width ?? 320;
          final threshold = math.max(52.0, width * 0.22);
          if (_dragX.abs() > threshold && widget.toast.dismissible) {
            widget.onDismiss();
          } else {
            setState(() => _dragX = 0);
          }
          widget.onInteractionChanged(false);
        },
        onHorizontalDragCancel: () {
          setState(() => _dragX = 0);
          widget.onInteractionChanged(false);
        },
        child: CustomPaint(
          painter: _GooeySurfacePainter(
            color: palette.surface,
            stroke: palette.stroke,
            morph: morph,
            isDark: Theme.of(context).brightness == Brightness.dark,
            glow: palette.glow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeDot(type: widget.toast.type, color: palette.icon),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.toast.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (widget.toast.showTimestamp)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Text(
                            _formatTimestamp(widget.toast.createdAt),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: palette.meta),
                          ),
                        ),
                    ],
                  ),
                  if (showExpandedBody) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ToastBody(toast: widget.toast, metaColor: palette.meta),
                    if (widget.toast.action != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTapDown: (_) => widget.onInteractionChanged(true),
                          onTapCancel: () => widget.onInteractionChanged(false),
                          onTap: () {
                            widget.toast.action?.onPressed();
                            widget.onInteractionChanged(false);
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
                              style: Theme.of(context).textTheme.labelSmall
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
            ),
          ),
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

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.toast, required this.metaColor});

  final AppToastData toast;
  final Color metaColor;

  @override
  Widget build(BuildContext context) {
    final description = toast.description ?? '';
    final hasMeta = toast.meta?.isNotEmpty ?? false;

    switch (toast.bodyLayout) {
      case AppToastBodyLayout.left:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: metaColor),
              ),
            if (hasMeta) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                toast.meta!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: metaColor),
              ),
            ],
          ],
        );
      case AppToastBodyLayout.center:
        return Center(
          child: Text(
            hasMeta ? '$description  ${toast.meta!}' : description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: metaColor),
          ),
        );
      case AppToastBodyLayout.right:
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            hasMeta ? '$description  ${toast.meta!}' : description,
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: metaColor),
          ),
        );
      case AppToastBodyLayout.spread:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: metaColor),
              ),
            ),
            if (hasMeta) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                toast.meta!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: metaColor),
              ),
            ],
          ],
        );
    }
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
    required this.actionBg,
    required this.actionText,
    required this.glow,
  });

  final Color surface;
  final Color stroke;
  final Color text;
  final Color meta;
  final Color icon;
  final Color actionBg;
  final Color actionText;
  final Color glow;
}

_GooeyPalette _palette(
  AppColors colors,
  AppToastType type,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;

  switch (type) {
    case AppToastType.success:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF111414).withValues(alpha: 0.88)
            : const Color(0xFFF3EEE1).withValues(alpha: 0.95),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: const Color(0xFF87D5BD),
        actionBg: const Color(0xFF87D5BD),
        actionText: dark ? const Color(0xFF0D0F0F) : const Color(0xFF353328),
        glow: const Color(0xFF87D5BD).withValues(alpha: 0.18),
      );
    case AppToastType.error:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF171A1A).withValues(alpha: 0.9)
            : const Color(0xFFF3EEE1).withValues(alpha: 0.97),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.error,
        actionBg: colors.error,
        actionText: colors.surface,
        glow: colors.error.withValues(alpha: 0.14),
      );
    case AppToastType.warning:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF171A1A).withValues(alpha: 0.9)
            : const Color(0xFFF8F3E8).withValues(alpha: 0.96),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: const Color(0xFFFFE9B0),
        actionBg: const Color(0xFFFFE9B0),
        actionText: dark ? const Color(0xFF0D0F0F) : const Color(0xFF353328),
        glow: const Color(0xFFFFE9B0).withValues(alpha: 0.14),
      );
    case AppToastType.info:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF171A1A).withValues(alpha: 0.88)
            : const Color(0xFFF3EEE1).withValues(alpha: 0.95),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: const Color(0xFFFFAA85),
        actionBg: const Color(0xFFFFAA85),
        actionText: dark ? const Color(0xFF0D0F0F) : const Color(0xFF353328),
        glow: const Color(0xFFFFAA85).withValues(alpha: 0.14),
      );
    case AppToastType.loading:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF171A1A).withValues(alpha: 0.84)
            : const Color(0xFFF8F3E8).withValues(alpha: 0.95),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.onSurface,
        actionBg: colors.surfaceHighest,
        actionText: colors.onSurface,
        glow: const Color(0xFFFFAA85).withValues(alpha: 0.12),
      );
    case AppToastType.normal:
      return _GooeyPalette(
        surface: dark
            ? const Color(0xFF171A1A).withValues(alpha: 0.86)
            : const Color(0xFFF3EEE1).withValues(alpha: 0.95),
        stroke: Colors.transparent,
        text: colors.onSurface,
        meta: colors.onSurfaceVariant,
        icon: colors.onSurface,
        actionBg: dark ? const Color(0xFF232626) : const Color(0xFFEDE8DA),
        actionText: colors.onSurface,
        glow: const Color(0xFFFFAA85).withValues(alpha: 0.1),
      );
  }
}

class _GooeySurfacePainter extends CustomPainter {
  const _GooeySurfacePainter({
    required this.color,
    required this.stroke,
    required this.morph,
    required this.isDark,
    required this.glow,
  });

  final Color color;
  final Color stroke;
  final double morph;
  final bool isDark;
  final Color glow;

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

    canvas.drawShadow(path, glow, isDark ? 18 : 12, false);
    canvas.drawPath(path, fillPaint);
    if (stroke.a > 0) {
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GooeySurfacePainter other) {
    return color != other.color ||
        stroke != other.stroke ||
        morph != other.morph ||
        isDark != other.isDark ||
        glow != other.glow;
  }
}
