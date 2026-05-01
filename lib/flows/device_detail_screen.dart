import 'dart:async';
import 'dart:convert';

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

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  static const Map<String, String> _deviceImageAssetsById = <String, String>{
    'P351ZAHAPH2R2706': 'assets/Delta-3.png',
    'R651ZAB5XH111262': 'assets/River-3.png',
  };

  late BridgeDeviceSnapshot _snapshot;
  StreamSubscription<BridgeDeviceSnapshot>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
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
    if (_snapshot.online == false) {
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
                  child: const Icon(Icons.battery_charging_full_rounded, size: 56),
                )
              : Image.network(
                  _snapshot.imageUrl!,
                  fit: isMobile ? BoxFit.cover : BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colors.primaryContainer.withValues(alpha: 0.32),
                    child: const Icon(Icons.battery_charging_full_rounded, size: 56),
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
                style: textTheme.titleLarge?.copyWith(color: colors.onSurfaceVariant),
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
              Text('0%', style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              const Spacer(),
              Text(
                _estimateLabel(),
                style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const Spacer(),
              Text('100%', style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
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
