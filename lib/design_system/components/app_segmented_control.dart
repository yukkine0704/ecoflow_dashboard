import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = Color.lerp(
          isDark ? colors.surfaceLow : colors.surface,
          colors.surfaceHigh,
          isDark ? 0.34 : 0.46,
        ) ??
        (isDark ? colors.surfaceLow : colors.surface);
    final shellLight = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.82);
    final shellDark = isDark
        ? Colors.black.withValues(alpha: 0.38)
        : colors.onSurface.withValues(alpha: 0.14);
    final shellBorder = Color.lerp(
          shellColor,
          colors.onSurface,
          isDark ? 0.12 : 0.08,
        ) ??
        shellColor;
    final selectedBg = isDark
        ? Color.lerp(colors.surfaceHighest, colors.primaryContainer, 0.2) ??
            colors.surfaceHighest
        : Color.alphaBlend(
            colors.primaryContainer.withValues(alpha: 0.45),
            colors.surface,
          );
    final selectedBorder = Color.lerp(
          selectedBg,
          colors.onSurface,
          isDark ? 0.16 : 0.1,
        ) ??
        selectedBg;
    final selectedFg = isDark ? colors.onSurface : colors.onPrimaryContainer;
    final idleFg = isDark
        ? colors.onSurfaceVariant.withValues(alpha: 0.9)
        : colors.onSurfaceVariant;

    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: AppRadius.full,
        border: Border.all(
          color: shellBorder.withValues(alpha: isDark ? 0.66 : 0.56),
        ),
        boxShadow: [
          BoxShadow(
            color: shellDark,
            blurRadius: 18,
            offset: const Offset(7, 7),
          ),
          BoxShadow(
            color: shellLight,
            blurRadius: 18,
            offset: const Offset(-7, -7),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite;

          Widget segmentChip(SegmentOption<T> segment) {
            final selected = segment.value == value;
            return GestureDetector(
              onTap: () => onChanged(segment.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected ? selectedBg : Colors.transparent,
                  borderRadius: AppRadius.full,
                  border: selected
                      ? Border.all(
                          color: selectedBorder.withValues(
                            alpha: isDark ? 0.74 : 0.62,
                          ),
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: shellDark.withValues(
                              alpha: isDark ? 0.3 : 0.13,
                            ),
                            blurRadius: 8,
                            offset: const Offset(3, 3),
                          ),
                          BoxShadow(
                            color: shellLight.withValues(
                              alpha: isDark ? 0.05 : 0.72,
                            ),
                            blurRadius: 8,
                            offset: const Offset(-3, -3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (segment.icon != null) ...[
                      Icon(
                        segment.icon,
                        size: 17,
                        color: selected ? selectedFg : idleFg,
                      ),
                      if (selected || segment.label.isNotEmpty)
                        const SizedBox(width: AppSpacing.xs),
                    ],
                    if (segment.label.isNotEmpty)
                      Text(
                        segment.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? selectedFg : idleFg,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return Row(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: options.map((segment) {
              final child = segmentChip(segment);
              if (bounded) {
                return Expanded(child: child);
              }
              return child;
            }).toList(),
          );
        },
      ),
    );
  }
}
