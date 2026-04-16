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
    final shellColor = isDark ? colors.surfaceLow : colors.surface;
    final shellShadow = isDark
        ? colors.shadowTint.withValues(alpha: 0.16)
        : colors.shadowTint.withValues(alpha: 0.08);
    final selectedBg = isDark
        ? colors.surfaceHighest
        : Color.alphaBlend(
            colors.primaryContainer.withValues(alpha: 0.45),
            colors.surface,
          );
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
        boxShadow: [
          BoxShadow(
            color: shellShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: shellShadow,
                            blurRadius: 14,
                            offset: const Offset(0, 5),
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
