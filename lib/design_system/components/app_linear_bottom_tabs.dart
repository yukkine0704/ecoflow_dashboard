import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class AppLinearTabItem {
  const AppLinearTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppExpandedMenuItem {
  const AppExpandedMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppLinearBottomTabs extends StatefulWidget {
  const AppLinearBottomTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.expandedItems,
    required this.onExpandedItemSelected,
    this.onExpandChanged,
  }) : assert(items.length >= 2);

  final List<AppLinearTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<AppExpandedMenuItem> expandedItems;
  final ValueChanged<int> onExpandedItemSelected;
  final ValueChanged<bool>? onExpandChanged;

  @override
  State<AppLinearBottomTabs> createState() => _AppLinearBottomTabsState();
}

class _AppLinearBottomTabsState extends State<AppLinearBottomTabs>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 400);
  static const _minBarHeight = 54.0;
  static const _expandedHeight = 380.0;

  late final AnimationController _expandController;
  int _hoveredExpandedIndex = 0;

  bool get _isExpanded => _expandController.value > 0.8;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _setExpanded(bool next) {
    if (next) {
      _expandController.forward();
      HapticFeedback.mediumImpact();
    } else {
      _expandController.reverse();
      HapticFeedback.lightImpact();
    }
    widget.onExpandChanged?.call(next);
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    final delta = -details.primaryDelta! / (_expandedHeight - _minBarHeight);
    _expandController.value = (_expandController.value + delta).clamp(0.0, 1.0);

    if (_isExpanded && widget.expandedItems.isNotEmpty) {
      final localY = details.localPosition.dy.clamp(0, _expandedHeight);
      final itemHeight = _expandedHeight / widget.expandedItems.length;
      final idx = (localY / itemHeight).floor().clamp(
        0,
        widget.expandedItems.length - 1,
      );
      if (_hoveredExpandedIndex != idx) {
        _hoveredExpandedIndex = idx;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -500) {
      _setExpanded(true);
      return;
    }
    if (velocity > 500) {
      if (_isExpanded) {
        widget.onExpandedItemSelected(_hoveredExpandedIndex);
      }
      _setExpanded(false);
      return;
    }
    if (_expandController.value > 0.65) {
      _setExpanded(true);
    } else {
      _setExpanded(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 480.0);
        return Center(
          child: GestureDetector(
            onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, constraints),
            onVerticalDragEnd: _onVerticalDragEnd,
            child: AnimatedBuilder(
              animation: _expandController,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(
                  _expandController.value,
                );
                final height = lerpDouble(_minBarHeight, _expandedHeight, t)!;
                final radius = lerpDouble(25, 40, t)!;
                final tabOpacity = (1 - (t * 2)).clamp(0.0, 1.0);
                final expandedOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(0, lerpDouble(0, -18, t)!),
                  child: Transform.scale(
                    scale: lerpDouble(1, 0.94, (t * 0.45).clamp(0.0, 1.0))!,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          color: colors.surfaceLow,
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.28,
                            ),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: expandedOpacity,
                              child: _ExpandedMenu(
                                items: widget.expandedItems,
                                selectedIndex: _hoveredExpandedIndex,
                                onPressed: (index) {
                                  widget.onExpandedItemSelected(index);
                                  _setExpanded(false);
                                },
                                progress: t,
                              ),
                            ),
                            Opacity(
                              opacity: tabOpacity,
                              child: IgnorePointer(
                                ignoring: tabOpacity < 0.2,
                                child: _BaseTabs(
                                  items: widget.items,
                                  selectedIndex: widget.selectedIndex,
                                  onPressed: (index) {
                                    HapticFeedback.selectionClick();
                                    widget.onTabSelected(index);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BaseTabs extends StatelessWidget {
  const _BaseTabs({
    required this.items,
    required this.selectedIndex,
    required this.onPressed,
  });

  final List<AppLinearTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPressed(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.full,
                      color: i == selectedIndex
                          ? colors.surface.withValues(alpha: 0.94)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 18,
                          color: i == selectedIndex
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                        if (i == selectedIndex) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            items[i].label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandedMenu extends StatelessWidget {
  const _ExpandedMenu({
    required this.items,
    required this.selectedIndex,
    required this.onPressed,
    required this.progress,
  });

  final List<AppExpandedMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onPressed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final start = 0.4 + (i * 0.05);
              final itemT = ((t - start) / 0.3).clamp(0.0, 1.0);
              return Opacity(
                opacity: itemT,
                child: Transform.translate(
                  offset: Offset(0, lerpDouble(40, 0, itemT)!),
                  child: Transform.scale(
                    scale: lerpDouble(0.7, 1.0, itemT)!,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: GestureDetector(
                onTap: () => onPressed(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.full,
                    color: selectedIndex == i
                        ? colors.surface.withValues(alpha: 0.16)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        size: 20,
                        color: selectedIndex == i
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          items[i].label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: selectedIndex == i
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                                fontWeight: selectedIndex == i
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
