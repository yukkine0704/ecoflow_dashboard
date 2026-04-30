import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/bridge/bridge_models.dart';
import '../core/bridge/bridge_repository.dart';
import '../design_system/design_system.dart';
import 'settings_screen.dart';

class DeviceDashboardScreen extends StatefulWidget {
  const DeviceDashboardScreen({super.key, required this.wsUrl});

  final String wsUrl;

  @override
  State<DeviceDashboardScreen> createState() => _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState extends State<DeviceDashboardScreen> {
  final BridgeRepository _repository = BridgeRepository();
  StreamSubscription<List<BridgeDeviceSnapshot>>? _fleetSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;

  List<BridgeDeviceSnapshot> _devices = const <BridgeDeviceSnapshot>[];
  BridgeDeviceSnapshot? _selected;
  bool _loading = true;
  String? _error;
  BridgeConnectionState _connectionState = const BridgeConnectionState(
    status: BridgeConnectionStatus.disconnected,
    message: 'Desconectado',
  );
  late String _wsUrl;

  @override
  void initState() {
    super.initState();
    _wsUrl = widget.wsUrl;
    _connect();
  }

  @override
  void dispose() {
    unawaited(_fleetSub?.cancel());
    unawaited(_connectionSub?.cancel());
    unawaited(_repository.dispose());
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    _fleetSub = _repository.fleet.listen((fleet) {
      if (!mounted) return;
      setState(() {
        _devices = fleet;
        if (_selected == null && fleet.isNotEmpty) {
          _selected = fleet.first;
        } else if (_selected != null) {
          _selected = fleet
              .where((d) => d.deviceId == _selected!.deviceId)
              .firstOrNull;
        }
        _loading = false;
      });
    });

    _connectionSub = _repository.connection.listen((state) {
      if (!mounted) return;
      setState(() {
        _connectionState = state;
        if (state.status == BridgeConnectionStatus.error) {
          _error = state.message;
          _loading = false;
        }
      });
    });

    try {
      await _repository.connect(_wsUrl);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _reconnect() async {
    await _repository.disconnect();
    await _connect();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsScreenResult>(
      MaterialPageRoute<SettingsScreenResult>(
        builder: (_) =>
            SettingsScreen(initialWsUrl: _wsUrl, allowReconnect: true),
      ),
    );
    if (!mounted || result == null || !result.saved) {
      return;
    }
    setState(() {
      _wsUrl = result.wsUrl;
    });
    if (result.reconnectRequested) {
      await _reconnect();
    }
  }

  double? _metricAsDouble(String key) {
    final raw = _selected?.metrics[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  String _prettyMetrics(Map<String, dynamic> metrics) {
    try {
      return const JsonEncoder.withIndent('  ').convert(metrics);
    } catch (_) {
      return metrics.toString();
    }
  }

  AppStatusTone _statusTone() {
    final online = _selected?.online;
    if (online == null) return AppStatusTone.neutral;
    return online ? AppStatusTone.active : AppStatusTone.warning;
  }

  String _statusLabel() {
    final online = _selected?.online;
    if (online == null) return 'Estado N/D';
    return online ? 'Online' : 'Offline';
  }

  AppStatusBadge _powerBadge(String label, double? watts) {
    return AppStatusBadge(
      label: watts == null
          ? '$label N/D'
          : '$label ${watts.toStringAsFixed(0)}W',
      tone: watts == null ? AppStatusTone.neutral : AppStatusTone.active,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Dispositivo'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge: $_wsUrl',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppStatusBadge(
                  label: _connectionState.message ?? 'Sin estado',
                  tone: switch (_connectionState.status) {
                    BridgeConnectionStatus.connected => AppStatusTone.active,
                    BridgeConnectionStatus.connecting => AppStatusTone.neutral,
                    BridgeConnectionStatus.disconnected =>
                      AppStatusTone.warning,
                    BridgeConnectionStatus.error => AppStatusTone.warning,
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: snapshot?.deviceId,
                        decoration: const InputDecoration(
                          labelText: 'Dispositivo',
                        ),
                        items: _devices
                            .map(
                              (device) => DropdownMenuItem<String>(
                                value: device.deviceId,
                                child: Text(device.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selected = _devices
                                .where((d) => d.deviceId == value)
                                .firstOrNull;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: 'Reconectar',
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: _reconnect,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            AppCard(
              surfaceLevel: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No se pudo conectar al bridge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          else if (snapshot == null)
            AppCard(
              child: Text(
                'Esperando snapshots del bridge para mostrar métricas del dispositivo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            AppCard(
              surfaceLevel: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.displayName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('ID: ${snapshot.deviceId}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Modelo: ${snapshot.model ?? 'N/D'}'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppStatusBadge(
                        label: _statusLabel(),
                        tone: _statusTone(),
                      ),
                      AppStatusBadge(
                        label: snapshot.batteryPercent == null
                            ? 'Batería N/D'
                            : 'Batería ${snapshot.batteryPercent}%',
                        tone: snapshot.batteryPercent == null
                            ? AppStatusTone.neutral
                            : ((snapshot.batteryPercent ?? 100) < 25
                                  ? AppStatusTone.warning
                                  : AppStatusTone.active),
                      ),
                      _powerBadge('Entrada', snapshot.totalInputW),
                      _powerBadge('Salida', snapshot.totalOutputW?.abs()),
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
                    'Métricas Clave',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _powerBadge(
                        'In Solar',
                        _metricAsDouble('inputByType.solarW'),
                      ),
                      _powerBadge('In AC', _metricAsDouble('inputByType.acW')),
                      _powerBadge(
                        'In Car',
                        _metricAsDouble('inputByType.carW'),
                      ),
                      _powerBadge(
                        'Out AC',
                        _metricAsDouble('outputByType.acW'),
                      ),
                      _powerBadge(
                        'Out DC',
                        _metricAsDouble('outputByType.dcW'),
                      ),
                      AppStatusBadge(
                        label: _metricAsDouble('battery.maxCellTempC') == null
                            ? 'Temp Celda N/D'
                            : 'Temp Celda ${_metricAsDouble('battery.maxCellTempC')!.toStringAsFixed(1)}°C',
                        tone: _metricAsDouble('battery.maxCellTempC') == null
                            ? AppStatusTone.neutral
                            : (_metricAsDouble('battery.maxCellTempC')! >= 45
                                  ? AppStatusTone.warning
                                  : AppStatusTone.active),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppGaugeCard.energyBalance(
              inputW: snapshot.totalInputW,
              outputW: snapshot.totalOutputW,
              maxW: 2200,
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              surfaceLevel: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campos del Bridge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: (() {
                      final entries = snapshot.metrics.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));
                      return entries
                          .map(
                            (entry) =>
                                AppChip(label: '${entry.key}: ${entry.value}'),
                          )
                          .toList();
                    })(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              surfaceLevel: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  _prettyMetrics(snapshot.metrics),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
