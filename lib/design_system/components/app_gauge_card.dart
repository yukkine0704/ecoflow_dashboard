import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';
import 'app_card.dart';
import 'app_status_badge.dart';

class AppGaugeCard extends StatelessWidget {
  const AppGaugeCard({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.unit,
    this.accentColor,
    this.subtitle,
    this.outputValue,
    this.showBalanceStatus = false,
  });

  AppGaugeCard.energyBalance({
    super.key,
    required double? inputW,
    required double? outputW,
    double maxW = 2200,
    this.title = 'Energy Balance',
    this.subtitle = 'Entrada total vs salida total',
  }) : value = inputW == null ? 0 : inputW.clamp(0.0, double.infinity),
       outputValue = outputW?.abs(),
       maxValue = maxW,
       unit = 'W',
       accentColor = null,
       showBalanceStatus = true;

  final String title;
  final double value;
  final double maxValue;
  final String unit;
  final Color? accentColor;
  final String? subtitle;
  final double? outputValue;
  final bool showBalanceStatus;

  bool get _isDualNeedle => outputValue != null || showBalanceStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedAccent = accentColor ?? colors.primaryContainer;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final inputProgress = (value / safeMax).clamp(0.0, 1.0);
    final outputProgress = ((outputValue ?? 0) / safeMax).clamp(0.0, 1.0);
    final hasBalanceData = outputValue != null;
    final isSurplus = hasBalanceData && value > (outputValue ?? 0);
    final areaColor = isSurplus
        ? colors.secondary.withValues(alpha: 0.20)
        : colors.error.withValues(alpha: 0.18);

    final statusBadge = !showBalanceStatus
        ? null
        : (!hasBalanceData
              ? const AppStatusBadge(
                  label: 'Balance N/D',
                  tone: AppStatusTone.neutral,
                )
              : (isSurplus
                    ? const AppStatusBadge(
                        label: 'Surplus',
                        tone: AppStatusTone.active,
                      )
                    : const AppStatusBadge(
                        label: 'Deficit',
                        tone: AppStatusTone.warning,
                      )));

    return AppCard(
      surfaceLevel: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: inputProgress),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, animatedInputProgress, _) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: outputProgress),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, animatedOutputProgress, _) {
              final animatedInputValue = animatedInputProgress * safeMax;
              if (_isDualNeedle) {
                final animatedOutputValue = animatedOutputProgress * safeMax;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        statusBadge ?? const SizedBox.shrink(),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 178,
                        child: CustomPaint(
                          painter: _EnergyBalanceGaugePainter(
                            inputProgress: animatedInputProgress,
                            outputProgress: animatedOutputProgress,
                            trackColor: colors.gaugeTrack,
                            inputColor: colors.primary,
                            outputColor: colors.outline,
                            fillColor: areaColor,
                            tickColor: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppStatusBadge(
                          label:
                              'Entrada ${animatedInputValue.toStringAsFixed(0)}W',
                          tone: AppStatusTone.active,
                        ),
                        AppStatusBadge(
                          label: outputValue == null
                              ? 'Salida N/D'
                              : 'Salida ${animatedOutputValue.toStringAsFixed(0)}W',
                          tone: outputValue == null
                              ? AppStatusTone.neutral
                              : AppStatusTone.warning,
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        progress: animatedInputProgress,
                        accentColor: resolvedAccent,
                        trackColor: colors.gaugeTrack,
                      ),
                      child: Center(
                        child: Text(
                          '${(animatedInputProgress * 100).round()}%',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              animatedInputValue.toStringAsFixed(0),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
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

class _EnergyBalanceGaugePainter extends CustomPainter {
  const _EnergyBalanceGaugePainter({
    required this.inputProgress,
    required this.outputProgress,
    required this.trackColor,
    required this.inputColor,
    required this.outputColor,
    required this.fillColor,
    required this.tickColor,
  });

  final double inputProgress;
  final double outputProgress;
  final Color trackColor;
  final Color inputColor;
  final Color outputColor;
  final Color fillColor;
  final Color tickColor;

  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = math.min(size.width * 0.40, size.height * 0.80);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      trackPaint,
    );

    final inputAngle =
        _startAngle + (_sweepAngle * inputProgress.clamp(0.0, 1.0));
    final outputAngle =
        _startAngle + (_sweepAngle * outputProgress.clamp(0.0, 1.0));
    final inputTip = Offset(
      center.dx + math.cos(inputAngle) * (radius - 12),
      center.dy + math.sin(inputAngle) * (radius - 12),
    );
    final outputTip = Offset(
      center.dx + math.cos(outputAngle) * (radius - 12),
      center.dy + math.sin(outputAngle) * (radius - 12),
    );

    final areaPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(outputTip.dx, outputTip.dy)
      ..lineTo(inputTip.dx, inputTip.dy)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = fillColor);

    _drawTicks(canvas, center, radius);
    _drawNeedle(canvas, center, outputTip, outputColor, 3, 6);
    _drawNeedle(canvas, center, inputTip, inputColor, 4, 7);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 4; i++) {
      final t = i / 4;
      final angle = _startAngle + (_sweepAngle * t);
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 3),
        center.dy + math.sin(angle) * (radius + 3),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 9),
        center.dy + math.sin(angle) * (radius - 9),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _drawNeedle(
    Canvas canvas,
    Offset center,
    Offset tip,
    Color color,
    double width,
    double hubRadius,
  ) {
    final line = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, line);
    canvas.drawCircle(center, hubRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EnergyBalanceGaugePainter oldDelegate) {
    return inputProgress != oldDelegate.inputProgress ||
        outputProgress != oldDelegate.outputProgress ||
        trackColor != oldDelegate.trackColor ||
        inputColor != oldDelegate.inputColor ||
        outputColor != oldDelegate.outputColor ||
        fillColor != oldDelegate.fillColor ||
        tickColor != oldDelegate.tickColor;
  }
}
