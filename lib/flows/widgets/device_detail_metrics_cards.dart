part of '../device_detail_screen.dart';

extension _DeviceDetailMetricsCards on _DeviceDetailScreenState {
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
    if (_snapshot.connectivity == EcoFlowConnectivity.offline) {
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
      EcoFlowConnectivity.online => AppStatusTone.active,
      EcoFlowConnectivity.assumeOffline => AppStatusTone.warning,
      EcoFlowConnectivity.offline => AppStatusTone.danger,
    };
  }

  String _connectivityLabel() {
    return switch (_snapshot.connectivity) {
      EcoFlowConnectivity.online => 'Online',
      EcoFlowConnectivity.assumeOffline => 'Assume offline',
      EcoFlowConnectivity.offline => 'Offline',
    };
  }

  Widget _buildKeyDataCard(BuildContext context) {
    final bmsTempInfo = _bmsTemperatureInfo();
    return AppCard(
      surfaceLevel: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos Clave', style: Theme.of(context).textTheme.titleMedium),
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
              _powerBadge('Other', _metricAsDouble('outputByType.otherW')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedFieldsCard(BuildContext context) {
    return AppCard(
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
            'Todos los campos recibidos de EcoFlow para este dispositivo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _sortedMetricEntries()
                .map(
                  (entry) => AppChip(
                    label: '${entry.key}: ${_formatMetricValue(entry.value)}',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMetricsCard(BuildContext context) {
    return AppCard(
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
    );
  }
}
