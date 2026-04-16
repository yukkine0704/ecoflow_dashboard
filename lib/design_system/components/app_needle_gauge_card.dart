import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';
import 'app_card.dart';
import 'app_status_badge.dart';

class AppNeedleGaugeCard extends StatefulWidget {
  const AppNeedleGaugeCard({
    super.key,
    required this.value,
    this.maxValue = 1300,
    this.lowPowerThreshold = 400,
    this.title = 'Potencia Solar',
    this.subtitle = 'Entrada fotovoltaica en tiempo real',
    this.unit = 'W',
    this.onLowPowerChanged,
  });

  final double value;
  final double maxValue;
  final double lowPowerThreshold;
  final String title;
  final String subtitle;
  final String unit;
  final ValueChanged<bool>? onLowPowerChanged;

  @override
  State<AppNeedleGaugeCard> createState() => _AppNeedleGaugeCardState();
}

class _AppNeedleGaugeCardState extends State<AppNeedleGaugeCard>
    with TickerProviderStateMixin {
  late final AnimationController _needleController;
  late final AnimationController _pulseController;
  bool _isLowPower = false;

  double get _safeMax => widget.maxValue <= 0 ? 1300 : widget.maxValue;
  double get _targetProgress =>
      (widget.value.clamp(0.0, _safeMax) / _safeMax).clamp(0.0, 1.0);
  bool get _nextLowPower => widget.value < widget.lowPowerThreshold;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController.unbounded(vsync: this);
    _needleController.value = _targetProgress;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _isLowPower = _nextLowPower;
    _syncLowPowerEffects(notify: false);
  }

  @override
  void didUpdateWidget(covariant AppNeedleGaugeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animateNeedleTo(_targetProgress);
    final next = _nextLowPower;
    if (next != _isLowPower) {
      _isLowPower = next;
      _syncLowPowerEffects(notify: true);
    }
  }

  void _animateNeedleTo(double target) {
    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.9, stiffness: 180, damping: 16),
      _needleController.value,
      target,
      0,
    );
    _needleController.animateWith(simulation);
  }

  void _syncLowPowerEffects({required bool notify}) {
    if (_isLowPower) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
    if (notify) {
      widget.onLowPowerChanged?.call(_isLowPower);
    }
  }

  @override
  void dispose() {
    _needleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      surfaceLevel: 1,
      child: AnimatedBuilder(
        animation: Listenable.merge([_needleController, _pulseController]),
        builder: (context, _) {
          final progress = _needleController.value.clamp(0.0, 1.0);
          final animatedValue = _safeMax * progress;
          final pulse = 1 + (_pulseController.value * 0.035);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_isLowPower)
                    Transform.scale(
                      scale: pulse,
                      child: const AppStatusBadge(
                        label: 'Baja < 400W',
                        tone: AppStatusTone.warning,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: SizedBox(
                  width: 260,
                  height: 162,
                  child: CustomPaint(
                    painter: _NeedleGaugePainter(
                      progress: progress,
                      trackColor: colors.gaugeTrack,
                      primary: colors.primaryContainer,
                      secondary: colors.secondary,
                      tertiary: colors.tertiaryContainer,
                      textColor: colors.onSurfaceVariant,
                      lowPowerProgress: (widget.lowPowerThreshold / _safeMax)
                          .clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                      widget.unit,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ALERTA ${widget.lowPowerThreshold.toStringAsFixed(0)}W',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _isLowPower
                          ? colors.error
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'MAX ${_safeMax.toStringAsFixed(0)}W',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NeedleGaugePainter extends CustomPainter {
  const _NeedleGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.textColor,
    required this.lowPowerProgress,
  });

  final double progress;
  final Color trackColor;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color textColor;
  final double lowPowerProgress;

  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = math.min(size.width * 0.42, size.height * 0.8);

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

    _drawZoneArc(
      canvas,
      center,
      radius,
      0.0,
      lowPowerProgress,
      const Color(0xFFFA7150).withValues(alpha: 0.65),
    );
    _drawZoneArc(
      canvas,
      center,
      radius,
      lowPowerProgress,
      0.8,
      tertiary.withValues(alpha: 0.55),
    );
    _drawZoneArc(
      canvas,
      center,
      radius,
      0.8,
      1.0,
      secondary.withValues(alpha: 0.6),
    );

    _drawTicks(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
  }

  void _drawZoneArc(
    Canvas canvas,
    Offset center,
    double radius,
    double from,
    double to,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle + (_sweepAngle * from),
      _sweepAngle * (to - from),
      false,
      paint,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = textColor.withValues(alpha: 0.62)
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 4; i++) {
      final t = i / 4;
      final angle = _startAngle + (_sweepAngle * t);
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 4),
        center.dy + math.sin(angle) * (radius + 4),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 8),
        center.dy + math.sin(angle) * (radius - 8),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final needleAngle = _startAngle + (_sweepAngle * progress);
    final tip = Offset(
      center.dx + math.cos(needleAngle) * (radius - 10),
      center.dy + math.sin(needleAngle) * (radius - 10),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final needleGlow = Paint()
      ..color = primary.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawLine(center, tip, needleGlow);
    canvas.drawLine(center, tip, needlePaint);

    final centerOuter = Paint()..color = primary;
    final centerInner = Paint()..color = Colors.white;
    canvas.drawCircle(center, 8, centerOuter);
    canvas.drawCircle(center, 4, centerInner);
  }

  @override
  bool shouldRepaint(covariant _NeedleGaugePainter other) {
    return progress != other.progress ||
        trackColor != other.trackColor ||
        primary != other.primary ||
        secondary != other.secondary ||
        tertiary != other.tertiary ||
        textColor != other.textColor ||
        lowPowerProgress != other.lowPowerProgress;
  }
}
