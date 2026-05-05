part of '../device_detail_screen.dart';

extension _DeviceDetailThermalCard on _DeviceDetailScreenState {
  double _cellPhaseOffset(_ThermalCellVm cell) {
    final normalizedFromId = (cell.id.hashCode.abs() % 1000) / 1000;
    final normalizedFromIndex = (cell.index % 17) / 17;
    return (normalizedFromId + normalizedFromIndex) % 1.0;
  }

  double _bandHeatLevel(_ThermalBand band) {
    return switch (band) {
      _ThermalBand.cool => 0.08,
      _ThermalBand.nominal => 0.24,
      _ThermalBand.warm => 0.68,
      _ThermalBand.critical => 1.0,
    };
  }

  bool _isCellAnimationActivated(_ThermalCellVm cell, DateTime now) {
    if (cell.tempC < _DeviceDetailScreenState._cellWarmThresholdC) {
      _cellAboveWarmSince.remove(cell.id);
      return false;
    }
    final since = _cellAboveWarmSince.putIfAbsent(cell.id, () => now);
    return now.difference(since) >=
        _DeviceDetailScreenState._cellAnimationActivationDelay;
  }

  _ThermalBand _thermalBandFor(double tempC) {
    if (tempC < 30) return _ThermalBand.cool;
    if (tempC < 37) return _ThermalBand.nominal;
    if (tempC < 40) return _ThermalBand.warm;
    return _ThermalBand.critical;
  }

  List<_ThermalCellVm> _thermalCells() {
    final entries = <_ThermalCellVm>[];
    final regexIndexed = RegExp(
      r'(?:cell|batterycell|battcell)(?:temp)?[._-]?(\d+)$',
      caseSensitive: false,
    );
    final regexGeneric = RegExp(r'cell.*temp', caseSensitive: false);

    for (final entry in _snapshot.metrics.entries) {
      final value = entry.value;
      final temp = value is num
          ? value.toDouble()
          : (value is String ? double.tryParse(value) : null);
      if (temp == null || temp < -50 || temp > 120) continue;

      final key = entry.key;
      final lower = key.toLowerCase();
      final indexed = regexIndexed.firstMatch(lower);
      if (indexed != null) {
        final index = int.tryParse(indexed.group(1) ?? '');
        if (index == null) continue;
        entries.add(
          _ThermalCellVm(
            id: key,
            label: 'C$index',
            index: index,
            tempC: temp,
            band: _thermalBandFor(temp),
          ),
        );
        continue;
      }

      if (regexGeneric.hasMatch(lower)) {
        entries.add(
          _ThermalCellVm(
            id: key,
            label: 'Cell',
            index: 9999 + entries.length,
            tempC: temp,
            band: _thermalBandFor(temp),
          ),
        );
      }
    }

    entries.sort((a, b) => a.index.compareTo(b.index));
    final dedup = <String, _ThermalCellVm>{};
    for (final cell in entries) {
      dedup[cell.id] = cell;
    }
    return dedup.values.toList();
  }

  _ThermalSummaryVm _thermalSummary() {
    final cells = _thermalCells();
    final bmsTemp = _firstTemperatureValue(const ['bms.temp', 'pd.temp']);
    final batteryTemp =
        _firstTemperatureValue(const [
          'battery.maxCellTempC',
          'pd.bmsMaxCellTemp',
          'bms.maxCellTemp',
          'temperatureC',
        ]) ??
        _snapshot.temperatureC;

    final sourceTemps = <double>[...cells.map((e) => e.tempC)];
    if (bmsTemp != null) sourceTemps.add(bmsTemp);
    if (batteryTemp != null) sourceTemps.add(batteryTemp);

    final dominantBand = sourceTemps.isEmpty
        ? _ThermalBand.nominal
        : sourceTemps
              .map(_thermalBandFor)
              .reduce((a, b) => a.severity >= b.severity ? a : b);

    final min = sourceTemps.isEmpty ? null : sourceTemps.reduce(math.min);
    final max = sourceTemps.isEmpty ? null : sourceTemps.reduce(math.max);

    return _ThermalSummaryVm(
      cells: cells,
      bmsTempC: bmsTemp,
      batteryTempC: batteryTemp,
      minTempC: min,
      maxTempC: max,
      dominantBand: dominantBand,
    );
  }

  Color _bandColor(
    BuildContext context,
    _ThermalBand band, {
    bool chip = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return switch (band) {
      _ThermalBand.cool => chip ? const Color(0xFF62C1A6) : cs.secondary,
      _ThermalBand.nominal => chip ? const Color(0xFF7FA892) : cs.tertiary,
      _ThermalBand.warm => chip ? const Color(0xFFF2A356) : cs.primary,
      _ThermalBand.critical => chip ? const Color(0xFFE45A4F) : cs.error,
    };
  }

  Widget _buildThermalCard(BuildContext context) {
    final summary = _thermalSummary();
    final validIds = summary.cells.map((c) => c.id).toSet();
    _cellAboveWarmSince.removeWhere((id, _) => !validIds.contains(id));
    final cs = Theme.of(context).colorScheme;
    final indicatorColor = _bandColor(
      context,
      summary.dominantBand,
      chip: true,
    );

    Widget thermalHeader() {
      final label = switch (summary.dominantBand) {
        _ThermalBand.cool => 'Cool',
        _ThermalBand.nominal => 'Nominal',
        _ThermalBand.warm => 'Warm',
        _ThermalBand.critical => 'Critical',
      };

      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THERMAL MONITORING',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cell Array Map',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: indicatorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          RepaintBoundary(
            child: SizedBox(
              width: 52,
              height: 52,
              child: _ThermalOrb(
                controller: _thermalController,
                band: summary.dominantBand,
                color: indicatorColor,
              ),
            ),
          ),
        ],
      );
    }

    Widget cellBubble(_ThermalCellVm cell) {
      final targetColor = _bandColor(context, cell.band, chip: true);
      final now = DateTime.now();
      final isActivated = _isCellAnimationActivated(cell, now);
      final isAnimBand =
          cell.band == _ThermalBand.warm || cell.band == _ThermalBand.critical;
      final targetHeat = (isActivated && isAnimBand)
          ? _bandHeatLevel(cell.band)
          : 0.0;
      final phaseOffset = _cellPhaseOffset(cell);
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(end: targetHeat),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, heat, _) {
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: targetColor),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, animatedColor, unusedChild) {
              final color = animatedColor ?? targetColor;
              final showShadow = heat >= 0.55;
              return AnimatedBuilder(
                animation: _thermalController,
                builder: (context, child) {
                  final phase = heat > 0
                      ? (_thermalController.value + phaseOffset) % 1.0
                      : 0.0;
                  final amplitude = 0.06 * heat;
                  final pulse = 1.0 + amplitude * math.sin(phase * math.pi * 2);
                  return Transform.scale(scale: pulse, child: child);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    boxShadow: showShadow
                        ? [
                            BoxShadow(
                              color: color.withValues(
                                alpha: 0.16 + 0.12 * heat,
                              ),
                              blurRadius: 10 + (10 * heat),
                              spreadRadius: 0.4 + (1.2 * heat),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _thermalController,
                          builder: (context, _) {
                            final phase = heat > 0
                                ? (_thermalController.value + phaseOffset) % 1.0
                                : 0.0;
                            return CustomPaint(
                              painter: _ThermalOrbPainter(
                                phase: phase,
                                band: cell.band,
                                color: color,
                                intensity: heat,
                              ),
                            );
                          },
                        ),
                      ),
                      Center(
                        child: Text(
                          '${cell.tempC.toStringAsFixed(1)}°',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return AppCard(
      surfaceLevel: 2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thermalHeader(),
          const SizedBox(height: AppSpacing.md),
          if (summary.cells.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sin temperaturas de celdas disponibles por ahora. Mostramos sensores generales cuando estén presentes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) => cellBubble(summary.cells[index]),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppStatusBadge(
                label: summary.bmsTempC == null
                    ? 'BMS N/D'
                    : 'BMS ${summary.bmsTempC!.toStringAsFixed(1)}°C',
                tone: summary.bmsTempC == null
                    ? AppStatusTone.neutral
                    : (summary.bmsTempC! >= 48
                          ? AppStatusTone.danger
                          : (summary.bmsTempC! >= 40
                                ? AppStatusTone.warning
                                : AppStatusTone.active)),
              ),
              AppStatusBadge(
                label: summary.batteryTempC == null
                    ? 'Battery N/D'
                    : 'Battery ${summary.batteryTempC!.toStringAsFixed(1)}°C',
                tone: summary.batteryTempC == null
                    ? AppStatusTone.neutral
                    : (summary.batteryTempC! >= 48
                          ? AppStatusTone.danger
                          : (summary.batteryTempC! >= 40
                                ? AppStatusTone.warning
                                : AppStatusTone.active)),
              ),
              AppStatusBadge(
                label: summary.maxTempC == null
                    ? 'Peak N/D'
                    : 'Peak ${summary.maxTempC!.toStringAsFixed(1)}°C',
                tone: summary.maxTempC == null
                    ? AppStatusTone.neutral
                    : (summary.maxTempC! >= 48
                          ? AppStatusTone.danger
                          : (summary.maxTempC! >= 40
                                ? AppStatusTone.warning
                                : AppStatusTone.active)),
              ),
              AppStatusBadge(
                label: summary.minTempC == null
                    ? 'Min N/D'
                    : 'Min ${summary.minTempC!.toStringAsFixed(1)}°C',
                tone: AppStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Active cells: ${summary.cells.length}${summary.cells.isNotEmpty ? '/${summary.cells.length}' : ''}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

enum _ThermalBand {
  cool(0),
  nominal(1),
  warm(2),
  critical(3);

  const _ThermalBand(this.severity);
  final int severity;
}

class _ThermalCellVm {
  const _ThermalCellVm({
    required this.id,
    required this.label,
    required this.index,
    required this.tempC,
    required this.band,
  });

  final String id;
  final String label;
  final int index;
  final double tempC;
  final _ThermalBand band;
}

class _ThermalSummaryVm {
  const _ThermalSummaryVm({
    required this.cells,
    required this.bmsTempC,
    required this.batteryTempC,
    required this.minTempC,
    required this.maxTempC,
    required this.dominantBand,
  });

  final List<_ThermalCellVm> cells;
  final double? bmsTempC;
  final double? batteryTempC;
  final double? minTempC;
  final double? maxTempC;
  final _ThermalBand dominantBand;
}

class _ThermalOrb extends StatelessWidget {
  const _ThermalOrb({
    required this.controller,
    required this.band,
    required this.color,
  });

  final Animation<double> controller;
  final _ThermalBand band;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final targetIntensity = switch (band) {
      _ThermalBand.cool => 0.08,
      _ThermalBand.nominal => 0.24,
      _ThermalBand.warm => 0.68,
      _ThermalBand.critical => 1.0,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetIntensity),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, intensity, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, animatedColor, unusedChild) {
            final resolvedColor = animatedColor ?? color;
            return AnimatedBuilder(
              animation: controller,
              builder: (context, animatedChild) {
                return CustomPaint(
                  painter: _ThermalOrbPainter(
                    phase: controller.value,
                    band: band,
                    color: resolvedColor,
                    intensity: intensity,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ThermalOrbPainter extends CustomPainter {
  const _ThermalOrbPainter({
    required this.phase,
    required this.band,
    required this.color,
    this.intensity = 1.0,
  });

  final double phase;
  final _ThermalBand band;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.1 + 0.16 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 3, glowPaint);

    final base = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.38 + 0.22 * intensity),
          color.withValues(alpha: 0.14 + 0.08 * intensity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, base);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.8);
    canvas.drawCircle(
      center,
      radius * (0.85 + 0.05 * math.sin(phase * math.pi * 2)),
      ringPaint,
    );

    if (band.severity >= 2) {
      final path = Path();
      final spikes = 18;
      for (var i = 0; i <= spikes; i++) {
        final t = i / spikes;
        final ang = t * math.pi * 2 + (phase * math.pi * 2);
        final r =
            radius *
            (0.34 +
                (0.04 * intensity) *
                    math.sin((phase * 4 + t * 7) * math.pi * 2));
        final point = Offset(
          center.dx + math.cos(ang) * r,
          center.dy + math.sin(ang) * r,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final core = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.24 + 0.14 * intensity);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(covariant _ThermalOrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.band != band ||
        oldDelegate.color != color ||
        oldDelegate.intensity != intensity;
  }
}
