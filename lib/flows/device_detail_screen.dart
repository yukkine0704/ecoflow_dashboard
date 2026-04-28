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

  String _formatTimestamp(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hh:$mm:$ss';
  }

  String _prettyMetrics(Map<String, dynamic> metrics) {
    try {
      return const JsonEncoder.withIndent('  ').convert(metrics);
    } catch (_) {
      return metrics.toString();
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Dispositivo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _snapshot.displayName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('ID: ${_snapshot.deviceId}'),
                const SizedBox(height: AppSpacing.sm),
                Text('Modelo: ${_snapshot.model ?? 'N/D'}'),
                const SizedBox(height: AppSpacing.sm),
                AppStatusBadge(
                  label: _snapshot.online == null
                      ? 'Estado N/D'
                      : (_snapshot.online! ? 'Online' : 'Offline'),
                  tone: _snapshot.online == null
                      ? AppStatusTone.neutral
                      : (_snapshot.online!
                            ? AppStatusTone.active
                            : AppStatusTone.warning),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Actualizado: ${_formatTimestamp(_snapshot.updatedAt)}'),
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
                          : 'Salida total ${_snapshot.totalOutputW!.toStringAsFixed(0)}W',
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
                    AppStatusBadge(
                      label: _metricAsDouble('inputByType.solarW') == null
                          ? 'Solar N/D'
                          : 'Solar ${_metricAsDouble('inputByType.solarW')!.toStringAsFixed(0)}W',
                      tone: _metricAsDouble('inputByType.solarW') == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    AppStatusBadge(
                      label: _metricAsDouble('inputByType.acW') == null
                          ? 'AC N/D'
                          : 'AC ${_metricAsDouble('inputByType.acW')!.toStringAsFixed(0)}W',
                      tone: _metricAsDouble('inputByType.acW') == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    AppStatusBadge(
                      label: _metricAsDouble('inputByType.carW') == null
                          ? 'Car N/D'
                          : 'Car ${_metricAsDouble('inputByType.carW')!.toStringAsFixed(0)}W',
                      tone: _metricAsDouble('inputByType.carW') == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    AppStatusBadge(
                      label: _metricAsDouble('inputByType.dcW') == null
                          ? 'DC N/D'
                          : 'DC ${_metricAsDouble('inputByType.dcW')!.toStringAsFixed(0)}W',
                      tone: _metricAsDouble('inputByType.dcW') == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
                    ),
                    AppStatusBadge(
                      label: _metricAsDouble('inputByType.otherW') == null
                          ? 'Other N/D'
                          : 'Other ${_metricAsDouble('inputByType.otherW')!.toStringAsFixed(0)}W',
                      tone: _metricAsDouble('inputByType.otherW') == null
                          ? AppStatusTone.neutral
                          : AppStatusTone.active,
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
                Text(
                  'Métricas raw',
                  style: Theme.of(context).textTheme.titleMedium,
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
