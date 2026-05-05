import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.width = 64,
    this.height = 34,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.activeTrackGradient,
    this.inactiveTrackGradient,
    this.activeThumbColor,
    this.inactiveThumbColor,
    this.activeIcon,
    this.inactiveIcon,
    this.activeThumbIcon,
    this.inactiveThumbIcon,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final double width;
  final double height;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Gradient? activeTrackGradient;
  final Gradient? inactiveTrackGradient;
  final Color? activeThumbColor;
  final Color? inactiveThumbColor;
  final Widget? activeIcon;
  final Widget? inactiveIcon;
  final Widget? activeThumbIcon;
  final Widget? inactiveThumbIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onColor = activeTrackColor ??
        Color.lerp(
          colors.surfaceHigh,
          isDark ? colors.secondary : colors.primaryContainer,
          isDark ? 0.52 : 0.46,
        )!;
    final offColor = inactiveTrackColor ??
        Color.lerp(
          colors.surfaceLow,
          colors.surfaceHighest,
          isDark ? 0.5 : 0.72,
        )!;
    final thumbOn = activeThumbColor ??
        Color.lerp(onColor, colors.onPrimaryContainer, 0.34)!;
    final thumbOff = inactiveThumbColor ??
        Color.lerp(offColor, colors.onSurfaceVariant, 0.25)!;
    final radius = height / 2;
    final thumbSize = height - 8;
    final lightShadow = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.84);
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : colors.onSurface.withValues(alpha: 0.2);
    final borderColor = Color.lerp(
      value ? onColor : offColor,
      colors.onSurface,
      isDark ? 0.14 : 0.08,
    )!;

    final trackGradient = value
        ? activeTrackGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                onColor.withValues(alpha: isDark ? 0.86 : 0.98),
                onColor.withValues(alpha: isDark ? 0.96 : 0.88),
              ],
            )
        : inactiveTrackGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                offColor.withValues(alpha: isDark ? 0.86 : 0.98),
                offColor.withValues(alpha: isDark ? 0.94 : 0.92),
              ],
            );
    final trackNudge = value ? -0.5 : 0.5;

    Widget statusIcon({required Widget? child}) {
      if (child == null) return const SizedBox.shrink();
      return IconTheme(
        data: IconThemeData(
          size: thumbSize * 0.54,
          color: colors.onSurface.withValues(alpha: 0.75),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.75),
            fontSize: thumbSize * 0.44,
            fontWeight: FontWeight.w700,
          ),
          child: child,
        ),
      );
    }

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: 'Switch',
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.5,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value ? 1 : 0),
            duration: const Duration(milliseconds: 600),
            curve: const Cubic(0.75, 0.0, 0.25, 1.25),
            builder: (context, t, _) {
              final thumbAlignment = Alignment.lerp(
                Alignment.centerLeft,
                Alignment.centerRight,
                t,
              )!;
              final liquidX = lerpDouble(-width * 0.25, -width * 0.75, t)!;
              final thumbColor = Color.lerp(thumbOff, thumbOn, t)!;
              final thumbIcon =
                  t > 0.5 ? activeThumbIcon ?? activeIcon : inactiveThumbIcon ?? inactiveIcon;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: width,
                height: height,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: trackGradient,
                  border: Border.all(
                    color: borderColor.withValues(alpha: isDark ? 0.78 : 0.58),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: darkShadow,
                      blurRadius: 12,
                      offset: const Offset(4, 4),
                    ),
                    BoxShadow(
                      color: lightShadow,
                      blurRadius: 12,
                      offset: const Offset(-4, -4),
                    ),
                  ],
                ),
                child: Transform.translate(
                  offset: Offset(trackNudge, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Stack(
                            children: [
                              Align(
                                alignment: const Alignment(0.55, 0),
                                child: statusIcon(child: activeIcon),
                              ),
                              Align(
                                alignment: const Alignment(-0.55, 0),
                                child: statusIcon(child: inactiveIcon),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: liquidX,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                1.4, 0, 0, 0, 0,
                                0, 1.4, 0, 0, 0,
                                0, 0, 1.4, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: SizedBox(
                                  width: width * 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.surface.withValues(
                                        alpha: isDark ? 0.14 : 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(radius),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              width: height,
                                              height: height,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.surface.withValues(
                                                  alpha: isDark ? 0.82 : 0.9,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              width: height,
                                              height: height,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.surface.withValues(
                                                  alpha: isDark ? 0.82 : 0.9,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: thumbAlignment,
                          child: Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: thumbColor,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: darkShadow.withValues(
                                    alpha: isDark ? 0.34 : 0.2,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(2, 2),
                                ),
                                BoxShadow(
                                  color: lightShadow.withValues(
                                    alpha: isDark ? 0.07 : 0.75,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(-1, -1),
                                ),
                              ],
                            ),
                            child: Center(child: statusIcon(child: thumbIcon)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
