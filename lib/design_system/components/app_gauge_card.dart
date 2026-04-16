import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';
import 'app_card.dart';

class AppGaugeCard extends StatelessWidget {
  const AppGaugeCard({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.unit,
    this.accentColor,
    this.subtitle,
  });

  final String title;
  final double value;
  final double maxValue;
  final String unit;
  final Color? accentColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedAccent = accentColor ?? colors.primaryContainer;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final targetProgress = (value / safeMax).clamp(0.0, 1.0);

    return AppCard(
      surfaceLevel: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: targetProgress),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          final animatedValue = animatedProgress * safeMax;
          return Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _GaugePainter(
                    progress: animatedProgress,
                    accentColor: resolvedAccent,
                    trackColor: colors.gaugeTrack,
                  ),
                  child: Center(
                    child: Text(
                      '${(animatedProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          animatedValue.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unit,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = 8.0;
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..shader = SweepGradient(
        colors: [accentColor.withValues(alpha: 0.5), accentColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter other) {
    return progress != other.progress ||
        accentColor != other.accentColor ||
        trackColor != other.trackColor;
  }
}
