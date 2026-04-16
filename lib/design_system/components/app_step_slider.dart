import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

enum StepSliderShape { circle, square, diamond, tick }

class StepSliderTheme {
  const StepSliderTheme({
    this.track,
    this.fill,
    this.stepActive,
    this.stepInactive,
    this.thumb,
    this.thumbShadow,
  });

  final Color? track;
  final Color? fill;
  final Color? stepActive;
  final Color? stepInactive;
  final Color? thumb;
  final Color? thumbShadow;
}

class AppStepSlider extends StatefulWidget {
  const AppStepSlider({
    super.key,
    this.stepCount = 11,
    this.defaultIndex,
    this.width,
    this.trackHeight = 56,
    this.trackRadius,
    this.stepRadius = 3.5,
    this.stepShape = StepSliderShape.circle,
    this.thumbWidth = 10,
    this.thumbHeight,
    this.stepPaddingStart,
    this.stepPaddingEnd,
    this.theme,
    this.onValueChange,
  }) : assert(stepCount >= 2, 'stepCount must be >= 2');

  final int stepCount;
  final int? defaultIndex;
  final double? width;
  final double trackHeight;
  final double? trackRadius;
  final double stepRadius;
  final StepSliderShape stepShape;
  final double thumbWidth;
  final double? thumbHeight;
  final double? stepPaddingStart;
  final double? stepPaddingEnd;
  final StepSliderTheme? theme;
  final ValueChanged<int>? onValueChange;

  @override
  State<AppStepSlider> createState() => _AppStepSliderState();
}

class _AppStepSliderState extends State<AppStepSlider>
    with TickerProviderStateMixin {
  late final AnimationController _thumbController;
  late final AnimationController _dragController;

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _thumbController = AnimationController.unbounded(vsync: this);
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _selectedIndex = _clampIndex(widget.defaultIndex ?? (widget.stepCount ~/ 2));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final initial = _positionForIndex(_selectedIndex);
      _thumbController.value = initial;
    });
  }

  @override
  void didUpdateWidget(covariant AppStepSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stepCount != oldWidget.stepCount && _selectedIndex >= widget.stepCount) {
      _selectedIndex = widget.stepCount - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = _thumbController.value;
      if (!current.isFinite || current == 0) {
        _thumbController.value = _positionForIndex(_selectedIndex);
      } else {
        _thumbController.value = current.clamp(_minX, _maxX);
      }
    });
  }

  @override
  void dispose() {
    _thumbController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  int _clampIndex(int index) => index.clamp(0, widget.stepCount - 1);

  double get _trackWidth =>
      widget.width ?? (MediaQuery.sizeOf(context).width - (AppSpacing.xxl * 2));
  double get _trackHeight => widget.trackHeight;
  double get _trackRadius => widget.trackRadius ?? _trackHeight / 2;
  double get _thumbHeight => widget.thumbHeight ?? (_trackHeight * 0.62);
  double get _paddingStart => widget.stepPaddingStart ?? _trackRadius;
  double get _paddingEnd => widget.stepPaddingEnd ?? _trackRadius;
  double get _dotStep => (_trackWidth - _paddingStart - _paddingEnd) / (widget.stepCount - 1);
  double get _minX => _paddingStart;
  double get _maxX => _trackWidth - _paddingEnd;

  double _positionForIndex(int index) => _paddingStart + (_dotStep * index);

  int _nearestIndexForPosition(double x) {
    final normalized = ((x - _paddingStart) / _dotStep).round();
    return _clampIndex(normalized);
  }

  void _animateThumbToIndex(int nextIndex) {
    final target = _positionForIndex(nextIndex);
    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.5, stiffness: 320, damping: 28),
      _thumbController.value,
      target,
      0,
    );
    _thumbController.animateWith(simulation);
    if (_selectedIndex != nextIndex) {
      _selectedIndex = nextIndex;
      widget.onValueChange?.call(nextIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = _StepSliderPalette(
      track: widget.theme?.track ?? colors.secondaryContainer.withValues(alpha: 0.28),
      fill: widget.theme?.fill ?? colors.secondaryContainer.withValues(alpha: 0.6),
      stepActive: widget.theme?.stepActive ?? colors.primary,
      stepInactive: widget.theme?.stepInactive ?? colors.secondary.withValues(alpha: 0.55),
      thumb: widget.theme?.thumb ?? colors.primary,
      thumbShadow: widget.theme?.thumbShadow ?? colors.primary.withValues(alpha: 0.45),
    );

    return SizedBox(
      width: _trackWidth,
      height: _trackHeight + 32,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragController.forward();
        },
        onHorizontalDragUpdate: (details) {
          final current = (_thumbController.value + details.delta.dx).clamp(_minX, _maxX);
          _thumbController.value = current;
        },
        onHorizontalDragEnd: (_) {
          _dragController.reverse();
          _animateThumbToIndex(_nearestIndexForPosition(_thumbController.value));
        },
        onTapDown: (details) {
          final localX = details.localPosition.dx.clamp(_minX, _maxX);
          _thumbController.value = localX;
          _animateThumbToIndex(_nearestIndexForPosition(localX));
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_thumbController, _dragController]),
          builder: (context, _) {
            final thumbX = _thumbController.value.isFinite
                ? _thumbController.value.clamp(_minX, _maxX)
                : _positionForIndex(_selectedIndex);
            final dragT = _dragController.value;
            final progressW = (thumbX >= _maxX - (_dotStep / 2)
                ? _trackWidth
                : (thumbX + (_dotStep / 2)).clamp(0, _trackWidth))
                .toDouble();

            return CustomPaint(
              painter: _StepSliderPainter(
                trackWidth: _trackWidth,
                trackHeight: _trackHeight,
                centerY: (_trackHeight + 32) / 2,
                trackRadius: _trackRadius,
                thumbX: thumbX,
                thumbWidth: widget.thumbWidth,
                thumbHeight: _thumbHeight,
                progressW: progressW,
                stepCount: widget.stepCount,
                stepRadius: widget.stepRadius,
                stepShape: widget.stepShape,
                stepStart: _paddingStart,
                stepGap: _dotStep,
                dragT: dragT,
                palette: palette,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StepSliderPalette {
  const _StepSliderPalette({
    required this.track,
    required this.fill,
    required this.stepActive,
    required this.stepInactive,
    required this.thumb,
    required this.thumbShadow,
  });

  final Color track;
  final Color fill;
  final Color stepActive;
  final Color stepInactive;
  final Color thumb;
  final Color thumbShadow;
}

class _StepSliderPainter extends CustomPainter {
  const _StepSliderPainter({
    required this.trackWidth,
    required this.trackHeight,
    required this.centerY,
    required this.trackRadius,
    required this.thumbX,
    required this.thumbWidth,
    required this.thumbHeight,
    required this.progressW,
    required this.stepCount,
    required this.stepRadius,
    required this.stepShape,
    required this.stepStart,
    required this.stepGap,
    required this.dragT,
    required this.palette,
  });

  final double trackWidth;
  final double trackHeight;
  final double centerY;
  final double trackRadius;
  final double thumbX;
  final double thumbWidth;
  final double thumbHeight;
  final double progressW;
  final int stepCount;
  final double stepRadius;
  final StepSliderShape stepShape;
  final double stepStart;
  final double stepGap;
  final double dragT;
  final _StepSliderPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - (trackHeight / 2), trackWidth, trackHeight),
      Radius.circular(trackRadius),
    );
    final trackPaint = Paint()..color = palette.track;
    canvas.drawRRect(trackRect, trackPaint);

    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - (trackHeight / 2), progressW, trackHeight),
      Radius.circular(trackRadius),
    );
    final fillPaint = Paint()..color = palette.fill;
    canvas.drawRRect(fillRect, fillPaint);

    for (int i = 0; i < stepCount; i++) {
      final cx = stepStart + (stepGap * i);
      final dist = (cx - thumbX).abs();
      final pulse = (1.3 - ((dist / stepGap).clamp(0.0, 1.0) * 0.3)).clamp(1.0, 1.3);
      final r = stepRadius * pulse;
      final active = cx <= thumbX;
      final stepPaint = Paint()..color = active ? palette.stepActive : palette.stepInactive;
      _drawStep(canvas, Offset(cx, centerY), r, stepPaint);
    }

    final thumbScaleX = lerpDouble(1.0, 0.88, dragT)!;
    final thumbScaleY = lerpDouble(1.0, 1.08, dragT)!;
    final thumbRect = Rect.fromCenter(
      center: Offset(thumbX, centerY),
      width: thumbWidth * thumbScaleX,
      height: thumbHeight * thumbScaleY,
    );
    final thumbRRect = RRect.fromRectAndRadius(
      thumbRect,
      Radius.circular((thumbWidth * thumbScaleX) / 2),
    );

    final shadowPaint = Paint()
      ..color = palette.thumbShadow.withValues(alpha: lerpDouble(0.35, 0.55, dragT)!)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, lerpDouble(2, 10, dragT)!);
    canvas.drawRRect(thumbRRect.shift(const Offset(0, 1)), shadowPaint);

    final thumbPaint = Paint()..color = palette.thumb;
    canvas.drawRRect(thumbRRect, thumbPaint);

    final glossPaint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final glossRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        thumbRect.left,
        thumbRect.top,
        thumbRect.width,
        thumbRect.height * 0.28,
      ),
      Radius.circular((thumbWidth * thumbScaleX) / 2),
    );
    canvas.drawRRect(glossRect, glossPaint);
  }

  void _drawStep(Canvas canvas, Offset center, double r, Paint paint) {
    switch (stepShape) {
      case StepSliderShape.circle:
        canvas.drawCircle(center, r, paint);
        return;
      case StepSliderShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 2, height: r * 2),
            Radius.circular(r * 0.35),
          ),
          paint,
        );
        return;
      case StepSliderShape.diamond:
        final path = Path()
          ..moveTo(center.dx, center.dy - r)
          ..lineTo(center.dx + r, center.dy)
          ..lineTo(center.dx, center.dy + r)
          ..lineTo(center.dx - r, center.dy)
          ..close();
        canvas.drawPath(path, paint);
        return;
      case StepSliderShape.tick:
        final tickPaint = Paint()
          ..color = paint.color
          ..strokeWidth = r * 0.75
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(center.dx, center.dy - (r * 1.3)),
          Offset(center.dx, center.dy + (r * 1.3)),
          tickPaint,
        );
        return;
    }
  }

  @override
  bool shouldRepaint(covariant _StepSliderPainter other) {
    return trackWidth != other.trackWidth ||
        trackHeight != other.trackHeight ||
        centerY != other.centerY ||
        trackRadius != other.trackRadius ||
        thumbX != other.thumbX ||
        thumbWidth != other.thumbWidth ||
        thumbHeight != other.thumbHeight ||
        progressW != other.progressW ||
        stepCount != other.stepCount ||
        stepRadius != other.stepRadius ||
        stepShape != other.stepShape ||
        stepStart != other.stepStart ||
        stepGap != other.stepGap ||
        dragT != other.dragT ||
        palette.track != other.palette.track ||
        palette.fill != other.palette.fill ||
        palette.stepActive != other.palette.stepActive ||
        palette.stepInactive != other.palette.stepInactive ||
        palette.thumb != other.palette.thumb ||
        palette.thumbShadow != other.palette.thumbShadow;
  }
}
