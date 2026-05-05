part of '../device_detail_screen.dart';

extension _DeviceDetailHistorySection on _DeviceDetailScreenState {
  String _peakDeltaLabel(List<double> values) {
    if (values.isEmpty) return 'Sin datos';
    final sortedDesc = List<double>.from(values)
      ..sort((a, b) => b.compareTo(a));
    final top1 = sortedDesc.first;
    final top2 = sortedDesc.length > 1 ? sortedDesc[1] : 0.0;
    final peakPct = top1 > 0 ? ((top1 - top2) / top1) * 100 : 0.0;
    return '${peakPct >= 0 ? '+' : ''}${peakPct.toStringAsFixed(0)}% Peak';
  }

  Widget _buildHistoryInsightCard(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String valueText,
    required String trendText,
    required Widget chart,
    required bool hasData,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ds = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardTone = Color.lerp(
          ds.surface,
          ds.surfaceHigh,
          isDark ? 0.5 : 0.72,
        ) ??
        ds.surfaceHigh;
    final cardBorder = Color.lerp(
          cardTone,
          ds.onSurface,
          isDark ? 0.14 : 0.08,
        ) ??
        cardTone;
    final lightShadow = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.84);
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: 0.44)
        : ds.onSurface.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: cardTone,
        border: Border.all(
          color: cardBorder.withValues(alpha: isDark ? 0.68 : 0.54),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: darkShadow,
            blurRadius: 22,
            offset: const Offset(10, 10),
          ),
          BoxShadow(
            color: lightShadow,
            blurRadius: 22,
            offset: const Offset(-10, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: isDark ? 0.24 : 0.22),
                      accent.withValues(alpha: isDark ? 0.34 : 0.3),
                    ],
                  ),
                  border: Border.all(
                    color: Color.lerp(accent, ds.onSurface, 0.22)!.withValues(
                      alpha: isDark ? 0.76 : 0.62,
                    ),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: darkShadow.withValues(alpha: isDark ? 0.28 : 0.12),
                      blurRadius: 8,
                      offset: const Offset(3, 3),
                    ),
                    BoxShadow(
                      color: lightShadow.withValues(alpha: isDark ? 0.05 : 0.72),
                      blurRadius: 8,
                      offset: const Offset(-3, -3),
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    trendText,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accent.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: hasData
                ? chart
                : Center(
                    child: Text(
                      'Sin datos suficientes todavía.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveBarChart({
    required List<double> values,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    const barWidth = 18.0;
    const groupSpace = 6.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBars = math.max(
          1,
          (constraints.maxWidth / (barWidth + groupSpace)).floor(),
        );
        final visible = values.length > maxBars
            ? values.sublist(values.length - maxBars)
            : values;
        final visiblePeak = visible.reduce(math.max);
        final visibleMaxY = (visiblePeak * 1.15).clamp(1.0, double.infinity);
        final visibleMaxIndex = visible.indexOf(visiblePeak);
        final visibleBars = <BarChartGroupData>[];
        for (var i = 0; i < visible.length; i++) {
          visibleBars.add(
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: visible[i],
                  width: barWidth,
                  borderRadius: BorderRadius.circular(4),
                  color: i == visibleMaxIndex ? activeColor : inactiveColor,
                ),
              ],
            ),
          );
        }
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: visibleMaxY,
            alignment: BarChartAlignment.spaceBetween,
            groupsSpace: groupSpace,
            barGroups: visibleBars,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
          ),
        );
      },
    );
  }

  LineChartBarData _historyLine({
    required List<DeviceHistoryPoint> points,
    required double? Function(DeviceHistoryPoint) selector,
    required Color color,
  }) {
    final spots = <FlSpot>[];
    for (final point in points) {
      final value = selector(point);
      if (value == null) {
        continue;
      }
      spots.add(
        FlSpot(point.timestamp.millisecondsSinceEpoch.toDouble(), value),
      );
    }
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2.0,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: spots,
    );
  }

  List<double> _energyWhByInterval({
    required List<DeviceHistoryPoint> points,
    required double? Function(DeviceHistoryPoint) selectorWatts,
  }) {
    if (points.length < 2) {
      return const <double>[];
    }
    final values = <double>[];
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final previousW = selectorWatts(previous);
      final currentW = selectorWatts(current);
      if (previousW == null || currentW == null) {
        continue;
      }
      final deltaMs = current.timestamp
          .difference(previous.timestamp)
          .inMilliseconds;
      if (deltaMs <= 0) {
        continue;
      }
      final deltaHours = deltaMs / Duration.millisecondsPerHour;
      final avgPowerW = (previousW + currentW) / 2;
      values.add(avgPowerW * deltaHours);
    }
    return values;
  }

  Widget _buildHistorySection(BuildContext context) {
    final series = _historySeries;
    if (series == null || series.points.isEmpty) {
      return AppCard(
        surfaceLevel: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historico', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aun no hay puntos historicos. Se iran guardando cada 30 segundos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final points = series.points;
    final colors = Theme.of(context).colorScheme;

    final solarEnergyWh = _energyWhByInterval(
      points: points,
      selectorWatts: (p) => p.inputSolarW,
    );
    final latestTs = points.isNotEmpty ? points.last.timestamp : null;
    final outputLivePoints = latestTs == null
        ? const <DeviceHistoryPoint>[]
        : points
              .where(
                (p) => !p.timestamp.isBefore(
                  latestTs.subtract(const Duration(minutes: 1)),
                ),
              )
              .toList(growable: false);
    final outputValues = outputLivePoints
        .map((p) => p.outputAcW)
        .whereType<double>()
        .toList();
    final tempValues = points
        .map((p) => p.batteryTempC)
        .whereType<double>()
        .toList();
    final batteryValues = points
        .map((p) => p.batteryPercent?.toDouble())
        .whereType<double>()
        .toList();

    final outputLines = <LineChartBarData>[
      _historyLine(
        points: outputLivePoints,
        selector: (p) => p.outputAcW,
        color: colors.primary,
      ),
      _historyLine(
        points: outputLivePoints,
        selector: (p) => p.outputDcW,
        color: colors.secondary,
      ),
      _historyLine(
        points: outputLivePoints,
        selector: (p) => p.outputOtherW,
        color: colors.tertiary,
      ),
    ];
    final tempLine = _historyLine(
      points: points,
      selector: (p) => p.batteryTempC,
      color: colors.error,
    );

    final hasOutput = outputLines.any((b) => b.spots.isNotEmpty);
    final hasTemp = tempLine.spots.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historico', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        _buildHistoryInsightCard(
          context,
          icon: Icons.wb_sunny_rounded,
          accent: colors.primary,
          title: 'Solar Input',
          valueText: solarEnergyWh.isEmpty
              ? '0 Wh'
              : '${solarEnergyWh.last.toStringAsFixed(1)} Wh',
          trendText: _peakDeltaLabel(solarEnergyWh),
          hasData: solarEnergyWh.isNotEmpty,
          chart: _buildAdaptiveBarChart(
            values: solarEnergyWh,
            activeColor: colors.primary,
            inactiveColor: colors.primary.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildHistoryInsightCard(
          context,
          icon: Icons.output_rounded,
          accent: colors.secondary,
          title: 'Salida por tipo',
          valueText: outputValues.isEmpty
              ? '0W'
              : '${outputValues.last.toStringAsFixed(0)}W',
          trendText: _peakDeltaLabel(outputValues),
          hasData: hasOutput,
          chart: LineChart(
            LineChartData(
              lineBarsData: outputLines,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: null,
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildHistoryInsightCard(
          context,
          icon: Icons.device_thermostat_rounded,
          accent: colors.error,
          title: 'Temperatura bateria',
          valueText: tempValues.isEmpty
              ? '0.0C'
              : '${tempValues.last.toStringAsFixed(1)}C',
          trendText: _peakDeltaLabel(tempValues),
          hasData: hasTemp,
          chart: LineChart(
            LineChartData(
              lineBarsData: <LineChartBarData>[tempLine],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: null,
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildHistoryInsightCard(
          context,
          icon: Icons.battery_charging_full_rounded,
          accent: colors.tertiary,
          title: 'Bateria %',
          valueText: batteryValues.isEmpty
              ? '0%'
              : '${batteryValues.last.toStringAsFixed(0)}%',
          trendText: _peakDeltaLabel(batteryValues),
          hasData: batteryValues.isNotEmpty,
          chart: _buildAdaptiveBarChart(
            values: batteryValues,
            activeColor: colors.tertiary,
            inactiveColor: colors.tertiary.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}
