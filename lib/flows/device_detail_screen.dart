import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ecoflow/ecoflow_models.dart';
import '../design_system/design_system.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.detailStateListenable,
    required this.onRefresh,
  });

  final EcoFlowDeviceIdentity device;
  final ValueListenable<EcoFlowDeviceDetailState?> detailStateListenable;
  final Future<void> Function() onRefresh;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
      if (!mounted) {
        return;
      }
      appGooeyToast.success(
        'Raw snapshot actualizado',
        config: AppToastConfig(meta: widget.device.sn),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      appGooeyToast.error(
        'No se pudo refrescar',
        config: AppToastConfig(description: '$error', meta: widget.device.sn),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _handleCopy(String jsonText) async {
    try {
      await Clipboard.setData(ClipboardData(text: jsonText));
      if (!mounted) {
        return;
      }
      appGooeyToast.success(
        'JSON copiado',
        config: AppToastConfig(meta: widget.device.sn),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      appGooeyToast.error(
        'No se pudo copiar',
        config: AppToastConfig(description: '$error', meta: widget.device.sn),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Dispositivo')),
      body: ValueListenableBuilder<EcoFlowDeviceDetailState?>(
        valueListenable: widget.detailStateListenable,
        builder: (context, detailState, _) {
          final mergedRaw = detailState?.mergedRaw ?? const <String, dynamic>{};
          final prettyJson = _safePrettyJson(mergedRaw);
          final status = detailState?.lastSource ?? EcoFlowDetailUpdateSource.none;
          final online = widget.device.isOnline;
          final battery = widget.device.batteryPercent;
          final summary = _buildTelemetrySummary(
            mergedRaw,
            fallbackBattery: battery,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              AppCard(
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.device.displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('SN: ${widget.device.sn}'),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        AppStatusBadge(
                          label: online == null
                              ? 'Estado N/D'
                              : (online ? 'Online' : 'Offline'),
                          tone: online == null
                              ? AppStatusTone.neutral
                              : (online ? AppStatusTone.active : AppStatusTone.warning),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppStatusBadge(
                          label: battery == null ? 'Bateria N/D' : 'Bateria $battery%',
                          tone: battery == null
                              ? AppStatusTone.neutral
                              : (battery < 25
                                    ? AppStatusTone.warning
                                    : AppStatusTone.active),
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
                    Row(
                      children: [
                        Expanded(
                          child: AppStatusBadge(
                            label: 'Ultima fuente: ${_sourceLabel(status)}',
                            tone: status == EcoFlowDetailUpdateSource.mqtt
                                ? AppStatusTone.active
                                : (status == EcoFlowDetailUpdateSource.rest
                                      ? AppStatusTone.neutral
                                      : AppStatusTone.warning),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'REST: ${_formatTimestamp(detailState?.lastRestSnapshotAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MQTT: ${_formatTimestamp(detailState?.lastMqttUpdateAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        AppButton(
                          label: _refreshing ? 'Actualizando...' : 'Refresh',
                          size: AppButtonSize.small,
                          loading: _refreshing,
                          onPressed: _refreshing
                              ? null
                              : () {
                                  unawaited(_handleRefresh());
                                },
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Copiar JSON',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () {
                            unawaited(_handleCopy(prettyJson));
                          },
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
                      'Datos Clave',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppStatusBadge(
                          label: summary.batteryPercent == null
                              ? 'Bateria N/D'
                              : 'Bateria ${summary.batteryPercent}%',
                          tone: summary.batteryPercent == null
                              ? AppStatusTone.neutral
                              : (summary.batteryPercent! < 25
                                    ? AppStatusTone.warning
                                    : AppStatusTone.active),
                        ),
                        AppStatusBadge(
                          label: summary.temperature == null
                              ? 'Temperatura N/D'
                              : 'Temperatura ${summary.temperature!.celsius.toStringAsFixed(1)}°C'
                                    ' (${summary.temperature!.fahrenheit.toStringAsFixed(1)}°F)',
                          tone: summary.temperature == null
                              ? AppStatusTone.neutral
                              : (summary.temperature!.celsius >= 45
                                    ? AppStatusTone.warning
                                    : AppStatusTone.active),
                        ),
                        AppStatusBadge(
                          label: summary.totalInputW == null
                              ? 'Entrada total N/D'
                              : 'Entrada total ${summary.totalInputW!.toStringAsFixed(0)}W',
                          tone: summary.totalInputW == null
                              ? AppStatusTone.neutral
                              : AppStatusTone.active,
                        ),
                        AppStatusBadge(
                          label: summary.totalOutputW == null
                              ? 'Salida total N/D'
                              : 'Salida total ${summary.totalOutputW!.toStringAsFixed(0)}W',
                          tone: summary.totalOutputW == null
                              ? AppStatusTone.neutral
                              : AppStatusTone.active,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PowerByPortTable(
                      title: 'Entrada Por Puerto',
                      entries: summary.inputByPort,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PowerByPortTable(
                      title: 'Salida Por Puerto',
                      entries: summary.outputByPort,
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
                      'Raw payload fusionado',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        prettyJson,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _sourceLabel(EcoFlowDetailUpdateSource source) {
    switch (source) {
      case EcoFlowDetailUpdateSource.rest:
        return 'REST snapshot';
      case EcoFlowDetailUpdateSource.mqtt:
        return 'MQTT realtime';
      case EcoFlowDetailUpdateSource.none:
        return 'Sin datos';
    }
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'N/D';
    }
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hh:$mm:$ss';
  }

  String _safePrettyJson(Map<String, dynamic> map) {
    try {
      return const JsonEncoder.withIndent('  ').convert(map);
    } catch (_) {
      return map.toString();
    }
  }

  _DeviceTelemetrySummary _buildTelemetrySummary(
    Map<String, dynamic> raw, {
    int? fallbackBattery,
  }) {
    final flat = _flattenMap(raw);
    final battery = _pickFirstInt(flat, const [
      'soc',
      'pd.soc',
      'cmsBattSoc',
      'bmsBattSoc',
      'batterySoc',
      'batteryPercent',
      'batteryLevel',
    ]);
    final temperatureRaw = _pickFirstDouble(flat, const [
      'inv.temp',
      'invTemp',
      'bms.temp',
      'bmsTemp',
      'ambientTemp',
      'batteryTemp',
      'batTemp',
      'temp',
    ]);
    final temperature = _normalizeTemperature(temperatureRaw);
    final socField = _asInt(flat['_socField']);
    final trustedBattery = _preferStableBattery(
      parsedBattery: battery,
      fallbackBattery: fallbackBattery,
      socField: socField,
    );
    final inputByPort = _extractPortPowers(
      flat,
      const {
        'AC In': ['acInPower', 'gridInPower', 'acInputWatts', 'acInWatts'],
        'Solar/PV': ['pvInPower', 'solarInputPower', 'mpptInputWatts', 'dcInPower'],
        'Car In': ['carInPower', 'carInputPower'],
      },
    );
    final outputByPort = _extractPortPowers(
      flat,
      const {
        'AC Out': ['acOutPower', 'acOutputWatts', 'inv.outputWatts', 'outputWatts'],
        'DC Out': ['dcOutPower', 'dcOutputWatts'],
        'USB-A': ['usbOutPower', 'usbAOutPower'],
        'USB-C': ['typecOutPower', 'usbCOutPower', 'usbcOutPower'],
        'Car Out': ['carOutPower', 'carOutputPower'],
      },
    );

    final totalInput = _pickFirstDouble(flat, const [
      'inputWatts',
      'inPower',
      'totalInputPower',
      'powInSumW',
    ]);
    final totalOutput = _pickFirstDouble(flat, const [
      'outputWatts',
      'outPower',
      'totalOutputPower',
      'powOutSumW',
    ]);

    return _DeviceTelemetrySummary(
      batteryPercent: trustedBattery,
      temperature: temperature,
      totalInputW: totalInput ?? _sumPortPowers(inputByPort),
      totalOutputW: totalOutput ?? _sumPortPowers(outputByPort),
      inputByPort: inputByPort,
      outputByPort: outputByPort,
    );
  }

  int? _preferStableBattery({
    required int? parsedBattery,
    required int? fallbackBattery,
    required int? socField,
  }) {
    if (parsedBattery == null) {
      return fallbackBattery;
    }
    if (fallbackBattery == null) {
      return parsedBattery;
    }
    final delta = (parsedBattery - fallbackBattery).abs();
    if (socField == 10 && delta >= 20) {
      return fallbackBattery;
    }
    if (parsedBattery <= 25 && fallbackBattery >= 40 && delta >= 15) {
      return fallbackBattery;
    }
    return parsedBattery;
  }

  Map<String, dynamic> _flattenMap(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    void walk(String prefix, Map<String, dynamic> node) {
      node.forEach((key, value) {
        final k = prefix.isEmpty ? key : '$prefix.$key';
        if (value is Map<String, dynamic>) {
          walk(k, value);
          return;
        }
        if (value is Map) {
          walk(k, value.map((a, b) => MapEntry(a.toString(), b)));
          return;
        }
        out[k] = value;
      });
    }

    walk('', map);
    return out;
  }

  int? _pickFirstInt(Map<String, dynamic> flat, List<String> keys) {
    for (final key in keys) {
      final value = flat[key];
      final parsed = _asDouble(value)?.round();
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _pickFirstDouble(Map<String, dynamic> flat, List<String> keys) {
    for (final key in keys) {
      final parsed = _asDouble(flat[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  Map<String, double> _extractPortPowers(
    Map<String, dynamic> flat,
    Map<String, List<String>> rules,
  ) {
    final out = <String, double>{};
    rules.forEach((portLabel, candidates) {
      for (final key in candidates) {
        final value = _asDouble(flat[key]);
        if (value != null) {
          out[portLabel] = value;
          return;
        }
      }
    });
    return out;
  }

  double? _sumPortPowers(Map<String, double> values) {
    if (values.isEmpty) {
      return null;
    }
    var sum = 0.0;
    values.forEach((_, value) => sum += value);
    return sum;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.replaceAll('%', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  _TemperatureValue? _normalizeTemperature(double? rawValue) {
    if (rawValue == null || !rawValue.isFinite) {
      return null;
    }
    var celsius = rawValue;
    // Many EcoFlow frames expose temp around 90-100 which maps to F.
    if (rawValue > 70 && rawValue <= 140) {
      celsius = (rawValue - 32) * (5.0 / 9.0);
    }
    if (celsius < -40 || celsius > 120) {
      return null;
    }
    final fahrenheit = (celsius * 9.0 / 5.0) + 32.0;
    return _TemperatureValue(celsius: celsius, fahrenheit: fahrenheit);
  }
}

class _DeviceTelemetrySummary {
  const _DeviceTelemetrySummary({
    required this.batteryPercent,
    required this.temperature,
    required this.totalInputW,
    required this.totalOutputW,
    required this.inputByPort,
    required this.outputByPort,
  });

  final int? batteryPercent;
  final _TemperatureValue? temperature;
  final double? totalInputW;
  final double? totalOutputW;
  final Map<String, double> inputByPort;
  final Map<String, double> outputByPort;
}

class _TemperatureValue {
  const _TemperatureValue({required this.celsius, required this.fahrenheit});

  final double celsius;
  final double fahrenheit;
}

class _PowerByPortTable extends StatelessWidget {
  const _PowerByPortTable({
    required this.title,
    required this.entries,
  });

  final String title;
  final Map<String, double> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (entries.isEmpty)
          Text('N/D', style: textTheme.bodySmall)
        else
          ...entries.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key, style: textTheme.bodyMedium)),
                  Text(
                    '${entry.value.toStringAsFixed(0)} W',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
