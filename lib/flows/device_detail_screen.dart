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
}
