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
    final theme = Theme.of(context);
    final resolvedAccent = accentColor ?? colors.primaryContainer;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final inputProgress = (value / safeMax).clamp(0.0, 1.0);
    final outputProgress = ((outputValue ?? 0) / safeMax).clamp(0.0, 1.0);
    final hasBalanceData = outputValue != null;
    final isSurplus = hasBalanceData && value > (outputValue ?? 0);
    final balanceDelta = hasBalanceData ? (value - (outputValue ?? 0)) : 0.0;
    final balanceAbs = balanceDelta.abs();
    final balanceDenominator = hasBalanceData
        ? math.max(math.max(value, outputValue ?? 0), 1.0)
        : safeMax;
    final balanceProgress = (balanceAbs / balanceDenominator).clamp(0.0, 1.0);
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
                        animation: AppStatusBadgeAnimation.surplus,
                        scale: 1.25,
                      )
                    : const AppStatusBadge(
                        label: 'Deficit',
                        tone: AppStatusTone.warning,
                        animation: AppStatusBadgeAnimation.deficit,
                        scale: 1.25,
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
                          child: Center(
                            child: Text(
                              title.toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: SizedBox(
                        width: 172,
                        height: 32,
                        child: CustomPaint(
                          painter: _EnergyBalanceTopArcPainter(
                            progress: balanceProgress,
                            color: isSurplus
                                ? colors.secondary.withValues(alpha: 0.55)
                                : colors.error.withValues(alpha: 0.50),
                            trackColor: colors.gaugeTrack.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        hasBalanceData
                            ? '${balanceAbs.toStringAsFixed(0)}$unit'
                            : 'N/D',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 156,
                        child: CustomPaint(
                          painter: _EnergyBalanceGaugePainter(
                            inputProgress: animatedInputProgress,
                            outputProgress: animatedOutputProgress,
                            trackColor: colors.gaugeTrack.withValues(
                              alpha: 0.85,
                            ),
                            inputColor: colors.primary,
                            outputColor: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            fillColor: areaColor,
                            inputFillColor: colors.primary.withValues(
                              alpha: 0.16,
                            ),
                            outputFillColor: colors.onSurfaceVariant.withValues(
                              alpha: 0.14,
                            ),
                            tickColor: colors.onSurfaceVariant.withValues(
                              alpha: 0.42,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricReadout(
                            label: 'Solar Input',
                            value: animatedInputValue,
                            unit: unit,
                            color: colors.primary,
                          ),
                        ),
                        Expanded(
                          child: _MetricReadout(
                            label: 'Consumption',
                            value: outputValue == null
                                ? null
                                : animatedOutputValue,
                            unit: unit,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            ),
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    if (statusBadge != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(child: statusBadge),
                    ],
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

class _MetricReadout extends StatelessWidget {
  const _MetricReadout({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final double? value;
  final String unit;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value == null ? 'N/D' : value!.toStringAsFixed(0),
              style: textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit.toLowerCase(),
                  style: textTheme.titleMedium?.copyWith(
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EnergyBalanceTopArcPainter extends CustomPainter {
  const _EnergyBalanceTopArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.08);
    final stroke = 12.0;
    const start = math.pi * 1.14;
    const sweep = math.pi * 0.72;
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.86,
      height: size.height * 0.86,
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      start,
      sweep * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyBalanceTopArcPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
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
    required this.inputFillColor,
    required this.outputFillColor,
    required this.tickColor,
  });

  final double inputProgress;
  final double outputProgress;
  final Color trackColor;
  final Color inputColor;
  final Color outputColor;
  final Color fillColor;
  final Color inputFillColor;
  final Color outputFillColor;
  final Color tickColor;

  static const double _startAngle = math.pi;
  static const double _sweepAngle = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.94);
    final radius = math.min(size.width * 0.38, size.height * 0.78);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
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

    _drawBodyBands(canvas, center, radius, inputAngle, outputAngle);

    final inputTip = Offset(
      center.dx + math.cos(inputAngle) * (radius - 11),
      center.dy + math.sin(inputAngle) * (radius - 11),
    );
    final outputTip = Offset(
      center.dx + math.cos(outputAngle) * (radius - 11),
      center.dy + math.sin(outputAngle) * (radius - 11),
    );

    _drawTicks(canvas, center, radius);
    _drawNeedle(canvas, center, outputTip, outputColor, 4, 7, 0.58);
    _drawNeedle(canvas, center, inputTip, inputColor, 5, 7, 0.72);
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawBodyBands(
    Canvas canvas,
    Offset center,
    double radius,
    double inputAngle,
    double outputAngle,
  ) {
    final bodyOuter = radius - 18;
    final bodyInner = radius - 52;
    final bodyStroke = bodyOuter - bodyInner;
    final bodyRadius = (bodyOuter + bodyInner) / 2;
    final baseRect = Rect.fromCircle(center: center, radius: bodyRadius);

    final inputSweep = inputAngle - _startAngle;
    final outputSweep = outputAngle - _startAngle;
    canvas.drawArc(
      baseRect,
      _startAngle,
      inputSweep,
      false,
      Paint()
        ..color = inputFillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyStroke
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawArc(
      baseRect,
      _startAngle,
      outputSweep,
      false,
      Paint()
        ..color = outputFillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyStroke
        ..strokeCap = StrokeCap.butt,
    );

    final diffStart = math.min(inputAngle, outputAngle);
    final diffSweep = (inputAngle - outputAngle).abs();
    if (diffSweep > 0.001) {
      canvas.drawArc(
        baseRect,
        diffStart,
        diffSweep,
        false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = bodyStroke
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 2; i++) {
      if (i == 1) continue;
      final t = i / 2;
      final angle = _startAngle + (_sweepAngle * t);
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 6),
        center.dy + math.sin(angle) * (radius + 6),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 3),
        center.dy + math.sin(angle) * (radius - 3),
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
    double lengthFactor,
  ) {
    final tipAdjusted = Offset.lerp(center, tip, lengthFactor) ?? tip;
    final line = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tipAdjusted, line);
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
        inputFillColor != oldDelegate.inputFillColor ||
        outputFillColor != oldDelegate.outputFillColor ||
        tickColor != oldDelegate.tickColor;
  }
}
