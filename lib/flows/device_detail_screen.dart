import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/bridge/bridge_models.dart';
import '../core/bridge/bridge_repository.dart';
import '../design_system/design_system.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    required this.repository,
    required this.deviceId,
    required this.initialSnapshot,
  });

  final BridgeRepository repository;
  final String deviceId;
  final BridgeDeviceSnapshot initialSnapshot;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _deviceImageAssetsById = <String, String>{
    'P351ZAHAPH2R2706': 'assets/Delta-3.png',
    'R651ZAB5XH111262': 'assets/River-3.png',
  };

  late BridgeDeviceSnapshot _snapshot;
  StreamSubscription<BridgeDeviceSnapshot>? _deviceSub;
  late final AnimationController _thermalController;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _thermalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _deviceSub = widget.repository.deviceUpdates.listen((updated) {
      if (!mounted || updated.deviceId != widget.deviceId) {
        return;
      }
      setState(() => _snapshot = updated);
    });
  }

  @override
  void dispose() {
    unawaited(_deviceSub?.cancel());
    _thermalController.dispose();
    super.dispose();
  }

  String _prettyMetrics(Map<String, dynamic> metrics) {
    try {
      return const JsonEncoder.withIndent('  ').convert(metrics);
    } catch (_) {
      return metrics.toString();
    }
  }

  void _printRawMetricsToConsole() {
    final pretty = _prettyMetrics(_snapshot.metrics);
    final header =
        '[RAW_METRICS][${_snapshot.deviceId}] updatedAt=${_snapshot.updatedAt.toIso8601String()}';
    debugPrint(header);
    const chunkSize = 900;
    for (var i = 0; i < pretty.length; i += chunkSize) {
      final end = (i + chunkSize < pretty.length)
          ? i + chunkSize
          : pretty.length;
      debugPrint(pretty.substring(i, end));
    }
    debugPrint('[RAW_METRICS_END][${_snapshot.deviceId}]');
    appGooeyToast.success(
      'Métricas enviadas a consola',
      config: const AppToastConfig(meta: 'RAW METRICS'),
    );
  }

  List<MapEntry<String, dynamic>> _sortedMetricEntries() {
    final entries = _snapshot.metrics.entries
        .where((entry) => entry.key.trim().isNotEmpty)
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  String _formatMetricValue(dynamic value) {
    if (value == null) {
      return 'null';
    }
    if (value is num) {
      final asDouble = value.toDouble();
      if (asDouble == asDouble.roundToDouble()) {
        return asDouble.toStringAsFixed(0);
      }
      return asDouble.toStringAsFixed(2);
    }
    return value.toString();
  }

  double? _metricAsDouble(String key) {
    final raw = _snapshot.metrics[key];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  double? _metricAsTemperatureC(String key) {
    final value = _metricAsDouble(key);
    if (value == null) {
      return null;
    }
    if (value < -50 || value > 120) {
      return null;
    }
    return value;
  }

  double? _firstTemperatureValue(List<String> keys) {
    for (final key in keys) {
      final value = _metricAsTemperatureC(key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  ({double? bmsTempC, double? maxCellTempC, double? deltaC, bool mismatch})
  _bmsTemperatureInfo() {
    final bmsTempC = _firstTemperatureValue(const ['bms.temp', 'pd.temp']);
    final maxCellTempC = _firstTemperatureValue(const [
      'battery.maxCellTempC',
      'bms.maxCellTemp',
      'pd.bmsMaxCellTemp',
    ]);
    if (bmsTempC == null || maxCellTempC == null) {
      return (
        bmsTempC: bmsTempC,
        maxCellTempC: maxCellTempC,
        deltaC: null,
        mismatch: false,
      );
    }
    final deltaC = (bmsTempC - maxCellTempC).abs();
    return (
      bmsTempC: bmsTempC,
      maxCellTempC: maxCellTempC,
      deltaC: deltaC,
      mismatch: deltaC > 5,
    );
  }

  AppStatusBadge _powerBadge(String label, double? watts) {
    return AppStatusBadge(
      label: watts == null
          ? '$label N/D'
          : '$label ${watts.toStringAsFixed(0)}W',
      tone: watts == null ? AppStatusTone.neutral : AppStatusTone.active,
    );
  }

  String _estimateLabel() {
    final battery = _snapshot.batteryPercent;
    if (_snapshot.connectivity == BridgeConnectivity.offline) {
      return 'Disconnected';
    }
    if (battery == null) {
      return 'Est. n/a';
    }
    if (battery < 30) {
      return battery < 15 ? 'May run out soon!' : 'Needs to charge soon';
    }
    final outputW = _snapshot.totalOutputW?.abs();
    if (outputW == null || outputW <= 0) {
      return 'Ready to charge';
    }
    final estimatedHours = (battery / 100) * 12;
    return 'Est. ${estimatedHours.toStringAsFixed(0)}h remaining';
  }

  AppStatusTone _connectivityTone() {
    return switch (_snapshot.connectivity) {
      BridgeConnectivity.online => AppStatusTone.active,
      BridgeConnectivity.assumeOffline => AppStatusTone.warning,
      BridgeConnectivity.offline => AppStatusTone.danger,
    };
  }

  String _connectivityLabel() {
    return switch (_snapshot.connectivity) {
      BridgeConnectivity.online => 'Online',
      BridgeConnectivity.assumeOffline => 'Assume offline',
      BridgeConnectivity.offline => 'Offline',
    };
  }

  List<_OutputChannelVm> _outputChannels() {
    const channelCandidates = <String, List<String>>{
      'AC Output': ['powgetacout', 'powgetac', 'acoutputwatts', 'outpower'],
      'Puerto 12V': ['powget12v', 'dc12v', '12vout'],
      'Puerto 24V': ['powget24v', '24vout'],
      'USB-C 1': ['powgettypec1', 'typec1', 'usbc1'],
      'USB-C 2': ['powgettypec2', 'typec2', 'usbc2'],
      'USB-A 1': ['powgetqcusb1', 'qcusb1', 'usba1', 'usb1'],
      'USB-A 2': ['powgetqcusb2', 'qcusb2', 'usba2', 'usb2'],
      'DC Port': ['powgetdcp', 'dcp', 'dcout'],
    };

    final normalizedEntries = _snapshot.metrics.entries.map((entry) {
      final normalized =
          entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return (original: entry.key, normalized: normalized, value: entry.value);
    }).toList();

    final channels = <_OutputChannelVm>[];
    final usedKeys = <String>{};

    for (final candidate in channelCandidates.entries) {
      double? watts;
      String? sourceKey;
      for (final entry in normalizedEntries) {
        final isMatch = candidate.value.any(entry.normalized.contains);
        if (!isMatch) continue;
        final asNum = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());
        if (asNum == null) continue;
        watts = asNum;
        sourceKey = entry.original;
        break;
      }
      channels.add(
        _OutputChannelVm(
          label: candidate.key,
          watts: watts,
          metricKey: sourceKey,
          category: candidate.key.toLowerCase().contains('usb')
              ? 'usb'
              : (candidate.key.toLowerCase().contains('ac') ? 'ac' : 'dc'),
          isDerivedFallback: false,
        ),
      );
      if (sourceKey != null) {
        usedKeys.add(sourceKey);
      }
    }

    for (final entry in normalizedEntries) {
      if (usedKeys.contains(entry.original)) continue;
      if (!entry.normalized.contains('powget')) continue;
      final asNum = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse(entry.value.toString());
      channels.add(
        _OutputChannelVm(
          label: entry.original,
          watts: asNum,
          metricKey: entry.original,
          category: entry.normalized.contains('usb') ||
                  entry.normalized.contains('typec')
              ? 'usb'
              : (entry.normalized.contains('ac') ? 'ac' : 'dc'),
          isDerivedFallback: true,
        ),
      );
    }

    final hasMeasured = channels.any((c) => c.watts != null);
    if (!hasMeasured) {
      channels.addAll([
        _OutputChannelVm(
          label: 'AC (resumen)',
          watts: _metricAsDouble('outputByType.acW'),
          metricKey: 'outputByType.acW',
          category: 'ac',
          isDerivedFallback: true,
        ),
        _OutputChannelVm(
          label: 'DC (resumen)',
          watts: _metricAsDouble('outputByType.dcW'),
          metricKey: 'outputByType.dcW',
          category: 'dc',
          isDerivedFallback: true,
        ),
      ]);
    }

    channels.sort((a, b) => a.label.compareTo(b.label));
    return channels;
  }

  _ThermalBand _thermalBandFor(double tempC) {
    if (tempC < 30) return _ThermalBand.cool;
    if (tempC < 40) return _ThermalBand.nominal;
    if (tempC < 48) return _ThermalBand.warm;
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
    final batteryTemp = _firstTemperatureValue(const [
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

  Color _bandColor(BuildContext context, _ThermalBand band, {bool chip = false}) {
    final cs = Theme.of(context).colorScheme;
    return switch (band) {
      _ThermalBand.cool => chip ? const Color(0xFF62C1A6) : cs.secondary,
      _ThermalBand.nominal => chip ? const Color(0xFF7FA892) : cs.tertiary,
      _ThermalBand.warm => chip ? const Color(0xFFF2A356) : cs.primary,
      _ThermalBand.critical => chip ? const Color(0xFFE45A4F) : cs.error,
    };
  }

  Widget _buildDeviceHeroCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final battery = _snapshot.batteryPercent;
    final batteryValue = battery == null ? 0.0 : battery.clamp(0, 100) / 100.0;
    final localAssetImagePath = _deviceImageAssetsById[_snapshot.deviceId];

    Widget imageBlock() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: isMobile ? double.infinity : 180,
          height: isMobile ? 220 : 180,
          child: localAssetImagePath != null
              ? Image.asset(
                  localAssetImagePath,
                  fit: isMobile ? BoxFit.cover : BoxFit.contain,
                )
              : (_snapshot.imageUrl == null
                    ? Container(
                        color: colors.primaryContainer.withValues(alpha: 0.32),
                        child: const Icon(
                          Icons.battery_charging_full_rounded,
                          size: 56,
                        ),
                      )
                    : Image.network(
                        _snapshot.imageUrl!,
                        fit: isMobile ? BoxFit.cover : BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.primaryContainer.withValues(alpha: 0.32),
                          child: const Icon(
                            Icons.battery_charging_full_rounded,
                            size: 56,
                          ),
                        ),
                      )),
        ),
      );
    }

    Widget detailsBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _snapshot.displayName,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _snapshot.model ?? 'Model unavailable',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Battery Level',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                battery == null ? 'n/a' : '$battery%',
                style: textTheme.displaySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 20,
              child: LinearProgressIndicator(
                value: battery == null ? null : batteryValue,
                minHeight: 20,
                backgroundColor: colors.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '0%',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _estimateLabel(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '100%',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AppCard(
      surfaceLevel: 1,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            imageBlock(),
            const SizedBox(height: 16),
            detailsBlock(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageBlock(),
                const SizedBox(width: 20),
                Expanded(child: detailsBlock()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOutputChannelsCard(BuildContext context) {
    final channels = _outputChannels();
    final usbChannels = channels.where((c) => c.category == 'usb').toList();
    final topChannels = channels.where((c) => c.category != 'usb').toList();
    final cs = Theme.of(context).colorScheme;

    Widget channelTile(_OutputChannelVm channel, {bool compact = false}) {
      final on = (channel.watts ?? 0) > 0;
      final bg = on
          ? cs.surfaceContainerHighest.withValues(alpha: 0.9)
          : cs.surfaceContainerLow;
      final color = on ? cs.primary : cs.onSurfaceVariant;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 18 : 22),
        ),
        child: Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              channel.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              channel.watts == null ? 'N/D' : '${channel.watts!.toStringAsFixed(0)}W',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      surfaceLevel: 1,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DC Channels', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (topChannels.isEmpty)
            Text(
              'No hay datos de salidas por puerto disponibles.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: topChannels
                  .map(
                    (channel) => SizedBox(
                      width: MediaQuery.sizeOf(context).width > 520
                          ? 220
                          : (MediaQuery.sizeOf(context).width - 72) / 2,
                      child: channelTile(channel),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Puertos USB', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (usbChannels.isEmpty)
            Text(
              'Sin telemetría USB en este momento.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: usbChannels.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.65,
              ),
              itemBuilder: (context, index) =>
                  channelTile(usbChannels[index], compact: true),
            ),
        ],
      ),
    );
  }

  Widget _buildThermalCard(BuildContext context) {
    final summary = _thermalSummary();
    final cs = Theme.of(context).colorScheme;
    final indicatorColor = _bandColor(context, summary.dominantBand, chip: true);

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
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                      ),
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
      final color = _bandColor(context, cell.band, chip: true);
      final isHot =
          cell.band == _ThermalBand.warm || cell.band == _ThermalBand.critical;
      return AnimatedBuilder(
        animation: _thermalController,
        builder: (context, child) {
          final phase = _thermalController.value;
          final pulse = isHot ? (0.96 + 0.08 * math.sin(phase * math.pi * 2)) : 1.0;
          return Transform.scale(scale: pulse, child: child);
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.23),
            boxShadow: isHot
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '${cell.tempC.toStringAsFixed(1)}°',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bmsTempInfo = _bmsTemperatureInfo();
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Dispositivo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildDeviceHeroCard(context),
          const SizedBox(height: AppSpacing.md),
          AppGaugeCard.energyBalance(
            inputW: _snapshot.totalInputW,
            outputW: _snapshot.totalOutputW,
            maxW: 2200,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildOutputChannelsCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildThermalCard(context),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos Clave',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppStatusBadge(
                      label: _connectivityLabel(),
                      tone: _connectivityTone(),
                    ),
                    AppStatusBadge(
                      label: _snapshot.batteryPercent == null
                          ? 'Batería N/D'
                          : 'Batería ${_snapshot.batteryPercent}%',
                      tone: _snapshot.batteryPercent == null
                          ? AppStatusTone.neutral
                          : ((_snapshot.batteryPercent ?? 100) < 25
                                ? AppStatusTone.warning
                                : AppStatusTone.active),
                    ),
                    AppStatusBadge(
                      label: _snapshot.temperatureC == null
                          ? 'Temperatura N/D'
                          : 'Temperatura ${_snapshot.temperatureC!.toStringAsFixed(1)}°C',
                      tone: _snapshot.temperatureC == null
                          ? AppStatusTone.neutral
                          : (_snapshot.temperatureC! >= 45
                                ? AppStatusTone.warning
                                : AppStatusTone.active),
                    ),
                    AppStatusBadge(
                      label: bmsTempInfo.bmsTempC == null
                          ? 'Temp BMS N/D'
                          : 'Temp BMS ${bmsTempInfo.bmsTempC!.toStringAsFixed(1)}°C',
                      tone: bmsTempInfo.bmsTempC == null
                          ? AppStatusTone.neutral
                          : (bmsTempInfo.mismatch
                                ? AppStatusTone.danger
                                : (bmsTempInfo.bmsTempC! >= 45
                                      ? AppStatusTone.warning
                                      : AppStatusTone.active)),
                      highlighted: bmsTempInfo.mismatch,
                      onTap: bmsTempInfo.mismatch
                          ? () {
                              appGooeyToast.warning(
                                'Revisa la temperatura del BMS',
                                config: AppToastConfig(
                                  meta: 'BMS TEMP ALERT',
                                  description:
                                      'Temp BMS ${bmsTempInfo.bmsTempC!.toStringAsFixed(1)}°C vs celda máx ${bmsTempInfo.maxCellTempC!.toStringAsFixed(1)}°C (Δ ${bmsTempInfo.deltaC!.toStringAsFixed(1)}°C).',
                                ),
                              );
                            }
                          : null,
                    ),
                    AppStatusBadge(
                      label: _metricAsDouble('battery.maxCellTempC') == null
                          ? 'Celda batería max N/D'
                          : 'Celda batería max ${_metricAsDouble('battery.maxCellTempC')!.toStringAsFixed(1)}°C',
                      tone: _metricAsDouble('battery.maxCellTempC') == null
                          ? AppStatusTone.neutral
                          : (_metricAsDouble('battery.maxCellTempC')! >= 45
                                ? AppStatusTone.warning
                                : AppStatusTone.active),
                    ),
                    AppStatusBadge(
                      label: _snapshot.totalInputW == null
                          ? 'Entrada total N/D'
                          : 'Entrada total ${_snapshot.totalInputW!.toStringAsFixed(0)}W',
                      tone: _snapshot.totalInputW == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    AppStatusBadge(
                      label: _snapshot.totalOutputW == null
                          ? 'Salida total N/D'
                          : 'Salida total ${_snapshot.totalOutputW!.abs().toStringAsFixed(0)}W',
                      tone: _snapshot.totalOutputW == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    if (_metricAsDouble('pd.powGet4p81') != null)
                      AppStatusBadge(
                        label:
                            'Extra battery 1 ${_metricAsDouble('pd.powGet4p81')!.toStringAsFixed(0)}W',
                        tone: AppStatusTone.active,
                      ),
                    if (_metricAsDouble('pd.powGet4p82') != null)
                      AppStatusBadge(
                        label:
                            'Extra battery 2 ${_metricAsDouble('pd.powGet4p82')!.toStringAsFixed(0)}W',
                        tone: AppStatusTone.active,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Entrada Por Tipo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _powerBadge('Solar', _metricAsDouble('inputByType.solarW')),
                    _powerBadge('AC', _metricAsDouble('inputByType.acW')),
                    _powerBadge('Car', _metricAsDouble('inputByType.carW')),
                    _powerBadge('DC', _metricAsDouble('inputByType.dcW')),
                    _powerBadge('Other', _metricAsDouble('inputByType.otherW')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Salida Por Tipo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _powerBadge('AC', _metricAsDouble('outputByType.acW')),
                    _powerBadge('DC', _metricAsDouble('outputByType.dcW')),
                    _powerBadge(
                      'Other',
                      _metricAsDouble('outputByType.otherW'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campos Extendidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Todos los campos recibidos del bridge para este dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _sortedMetricEntries()
                      .map(
                        (entry) => AppChip(
                          label:
                              '${entry.key}: ${_formatMetricValue(entry.value)}',
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            surfaceLevel: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Métricas raw',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    AppButton(
                      label: 'Copiar a consola',
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: _printRawMetricsToConsole,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _prettyMetrics(_snapshot.metrics),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
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

class _OutputChannelVm {
  const _OutputChannelVm({
    required this.label,
    required this.watts,
    required this.metricKey,
    required this.category,
    required this.isDerivedFallback,
  });

  final String label;
  final double? watts;
  final String? metricKey;
  final String category;
  final bool isDerivedFallback;
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ThermalOrbPainter(
            phase: controller.value,
            band: band,
            color: color,
          ),
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
  });

  final double phase;
  final _ThermalBand band;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.43;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: band.severity >= 2 ? 0.22 : 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 3, glowPaint);

    final base = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.18),
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
      final spikes = 8;
      for (var i = 0; i <= spikes; i++) {
        final t = i / spikes;
        final ang = t * math.pi * 2 + (phase * math.pi * 2);
        final r =
            radius * (0.45 + 0.1 * math.sin((phase * 4 + t * 7) * math.pi * 2));
        final point =
            Offset(center.dx + math.cos(ang) * r, center.dy + math.sin(ang) * r);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final core = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.35);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(covariant _ThermalOrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.band != band ||
        oldDelegate.color != color;
  }
}
