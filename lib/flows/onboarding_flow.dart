import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge/bridge_repository.dart';
import '../core/bridge/bridge_settings_storage.dart';
import '../core/bridge/bridge_models.dart';
import '../design_system/design_system.dart';
import 'device_detail_screen.dart';

class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen> {
  final _wsUrlController = TextEditingController();
  final _settingsStorage = BridgeSettingsStorage();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  @override
  void dispose() {
    _wsUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    try {
      final wsUrl = await _settingsStorage.readWsUrl();
      if (!mounted) {
        return;
      }
      _wsUrlController.text = wsUrl;
    } catch (_) {
      if (!mounted) {
        return;
      }
      appGooeyToast.warning(
        'No se pudo cargar la configuración',
        config: const AppToastConfig(meta: 'BRIDGE WS'),
      );
      _wsUrlController.text = 'ws://127.0.0.1:8787/ws';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateWsUrl() {
    final candidate = _wsUrlController.text.trim();
    if (candidate.isEmpty) {
      return 'Ingresa la URL WebSocket del bridge';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'La URL no es valida';
    }
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      return 'La URL debe usar ws o wss';
    }
    return null;
  }

  Future<bool> _saveConfiguration() async {
    final error = _validateWsUrl();
    if (error != null) {
      appGooeyToast.error(
        'URL invalida',
        config: AppToastConfig(description: error, meta: 'BRIDGE WS'),
      );
      return false;
    }
    if (_saving) {
      return false;
    }

    setState(() => _saving = true);
    try {
      await _settingsStorage.writeWsUrl(_wsUrlController.text);
      if (!mounted) {
        return true;
      }
      appGooeyToast.success(
        'Configuración guardada',
        config: const AppToastConfig(meta: 'BRIDGE WS'),
      );
      return true;
    } catch (error) {
      if (mounted) {
        appGooeyToast.error(
          'No se pudo guardar',
          config: AppToastConfig(description: '$error', meta: 'BRIDGE WS'),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _continueToSelector() async {
    final ok = await _saveConfiguration();
    if (!ok || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DeviceSelectorScreen(wsUrl: _wsUrlController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Bridge WS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Your Local Bridge',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Conecta la app al bridge directo de EcoFlow para leer telemetría en tiempo real.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Cargando configuración...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                AppTextField(
                  controller: _wsUrlController,
                  label: 'Bridge WebSocket URL',
                  hintText: 'ws://127.0.0.1:8787/ws',
                  prefixIcon: Icons.link,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Guardar',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  loading: _saving,
                  onPressed: _saving
                      ? null
                      : () {
                          _saveConfiguration();
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Conectar y abrir dashboard',
                  fullWidth: true,
                  trailing: const Icon(Icons.wifi_tethering),
                  onPressed: _saving ? null : _continueToSelector,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceSelectorScreen extends StatefulWidget {
  const DeviceSelectorScreen({super.key, required this.wsUrl});

  final String wsUrl;

  @override
  State<DeviceSelectorScreen> createState() => _DeviceSelectorScreenState();
}

class _DeviceSelectorScreenState extends State<DeviceSelectorScreen> {
  final BridgeRepository _repository = BridgeRepository();
  StreamSubscription<List<BridgeDeviceSnapshot>>? _fleetSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;
  StreamSubscription<List<BridgeCatalogItem>>? _catalogSub;

  List<BridgeDeviceSnapshot> _devices = const <BridgeDeviceSnapshot>[];
  List<BridgeCatalogItem> _catalog = const <BridgeCatalogItem>[];
  final Set<String> _visibleDeviceIds = <String>{};
  bool _loading = true;
  String? _error;
  String? _selectedDeviceId;
  BridgeConnectionState _connectionState = const BridgeConnectionState(
    status: BridgeConnectionStatus.disconnected,
    message: 'Desconectado',
  );

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    unawaited(_fleetSub?.cancel());
    unawaited(_connectionSub?.cancel());
    unawaited(_catalogSub?.cancel());
    unawaited(_repository.dispose());
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    _fleetSub = _repository.fleet.listen((fleet) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = fleet;
        if (_visibleDeviceIds.isEmpty) {
          _visibleDeviceIds.addAll(fleet.map((device) => device.deviceId));
        }
        final filtered = _filteredDevices(fleet);
        _selectedDeviceId ??= filtered.isNotEmpty
            ? filtered.first.deviceId
            : null;
        _loading = false;
      });
    });

    _catalogSub = _repository.catalog.listen((catalog) {
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
        if (_visibleDeviceIds.isEmpty) {
          _visibleDeviceIds.addAll(catalog.map((item) => item.deviceId));
        }
      });
    });

    _connectionSub = _repository.connection.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = state;
        if (state.status == BridgeConnectionStatus.error) {
          _error = state.message;
          _loading = false;
        }
      });
    });

    try {
      await _repository.connect(widget.wsUrl);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openDeviceDetail(BridgeDeviceSnapshot device) async {
    setState(() => _selectedDeviceId = device.deviceId);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceDetailScreen(
          repository: _repository,
          deviceId: device.deviceId,
          initialSnapshot: device,
        ),
      ),
    );
  }

  Future<void> _reconnect() async {
    await _repository.disconnect();
    await _connect();
  }

  List<BridgeDeviceSnapshot> _filteredDevices(
    List<BridgeDeviceSnapshot> source,
  ) {
    if (_visibleDeviceIds.isEmpty) {
      return source;
    }
    return source
        .where((device) => _visibleDeviceIds.contains(device.deviceId))
        .toList();
  }

  Future<void> _openDevicePicker() async {
    final source = _catalog.isNotEmpty
        ? _catalog
        : _devices
              .map(
                (device) => BridgeCatalogItem(
                  deviceId: device.deviceId,
                  displayName: device.displayName,
                  model: device.model,
                  imageUrl: device.imageUrl,
                ),
              )
              .toList();

    if (source.isEmpty) {
      appGooeyToast.warning(
        'No hay catálogo disponible todavía',
        config: const AppToastConfig(meta: 'DEVICE PICKER'),
      );
      return;
    }

    final workingSet = Set<String>.from(
      _visibleDeviceIds.isEmpty
          ? source.map((item) => item.deviceId)
          : _visibleDeviceIds,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selecciona dispositivos',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              workingSet
                                ..clear()
                                ..addAll(source.map((item) => item.deviceId));
                            });
                          },
                          child: const Text('Todos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: source.map((item) {
                          final checked = workingSet.contains(item.deviceId);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  workingSet.add(item.deviceId);
                                } else {
                                  workingSet.remove(item.deviceId);
                                }
                              });
                            },
                            title: Text(item.displayName),
                            subtitle: Text(
                              '${item.model ?? 'Modelo N/D'} • ${item.deviceId}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Cancelar',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Aplicar',
                            onPressed: () {
                              if (workingSet.isEmpty) {
                                return;
                              }
                              setState(() {
                                _visibleDeviceIds
                                  ..clear()
                                  ..addAll(workingSet);
                                final filtered = _filteredDevices(_devices);
                                if (filtered.isNotEmpty &&
                                    !_visibleDeviceIds.contains(
                                      _selectedDeviceId,
                                    )) {
                                  _selectedDeviceId = filtered.first.deviceId;
                                }
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
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

  AppStatusTone _toneFromConnection(BridgeConnectionStatus status) {
    switch (status) {
      case BridgeConnectionStatus.connected:
        return AppStatusTone.active;
      case BridgeConnectionStatus.connecting:
        return AppStatusTone.neutral;
      case BridgeConnectionStatus.error:
        return AppStatusTone.warning;
      case BridgeConnectionStatus.disconnected:
        return AppStatusTone.warning;
    }
  }

  String _labelFromConnection(BridgeConnectionStatus status) {
    switch (status) {
      case BridgeConnectionStatus.connected:
        return 'Bridge conectado';
      case BridgeConnectionStatus.connecting:
        return 'Conectando bridge...';
      case BridgeConnectionStatus.error:
        return 'Error de conexión';
      case BridgeConnectionStatus.disconnected:
        return 'Bridge desconectado';
    }
  }

  double? _metricAsDouble(BridgeDeviceSnapshot device, String key) {
    final raw = device.metrics[key];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  AppStatusBadge _typedPowerBadge({
    required String label,
    required double? watts,
    AppStatusTone tone = AppStatusTone.active,
  }) {
    return AppStatusBadge(
      label: watts == null ? '$label N/D' : '$label ${watts.toStringAsFixed(0)}W',
      tone: watts == null ? AppStatusTone.neutral : tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDevices = _filteredDevices(_devices);
    return Scaffold(
      appBar: AppBar(title: const Text('Selector de dispositivos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Ecosystem',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Selecciona el dispositivo que quieres monitorear en tiempo real desde el bridge local.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppStatusBadge(
                  label: _labelFromConnection(_connectionState.status),
                  tone: _toneFromConnection(_connectionState.status),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'WS: ${widget.wsUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Reconectar',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    _reconnect();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Elegir dispositivos',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.tertiary,
                  onPressed: _openDevicePicker,
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
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Reintentar',
                    onPressed: _reconnect,
                    variant: AppButtonVariant.secondary,
                  ),
                ],
              ),
            )
          else if (visibleDevices.isEmpty)
            AppCard(
              child: Text(
                'Aún no hay dispositivos visibles. Abre "Elegir dispositivos" o espera catálogo del bridge.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            AppCard(
              child: Text(
                'Dispositivos visibles: ${visibleDevices.length} / ${_devices.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...visibleDevices.map((device) {
              final selected = _selectedDeviceId == device.deviceId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  surfaceLevel: selected ? 2 : 1,
                  onTap: () {
                    _openDeviceDetail(device);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('ID: ${device.deviceId}'),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Modelo: ${device.model ?? 'N/D'}'),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppStatusBadge(
                            label: device.online == null
                                ? 'Estado N/D'
                                : (device.online! ? 'Online' : 'Offline'),
                            tone: device.online == null
                                ? AppStatusTone.neutral
                                : (device.online!
                                      ? AppStatusTone.active
                                      : AppStatusTone.warning),
                          ),
                          AppStatusBadge(
                            label: device.batteryPercent == null
                                ? 'Batería N/D'
                                : 'Batería ${device.batteryPercent}%',
                            tone: device.batteryPercent == null
                                ? AppStatusTone.neutral
                                : ((device.batteryPercent ?? 100) < 25
                                      ? AppStatusTone.warning
                                      : AppStatusTone.active),
                          ),
                          AppStatusBadge(
                            label: device.totalInputW == null
                                ? 'Entrada N/D'
                                : 'Entrada ${device.totalInputW!.toStringAsFixed(0)}W',
                            tone: device.totalInputW == null
                                ? AppStatusTone.neutral
                                : AppStatusTone.active,
                          ),
                          AppStatusBadge(
                            label: device.totalOutputW == null
                                ? 'Salida N/D'
                                : 'Salida ${device.totalOutputW!.toStringAsFixed(0)}W',
                            tone: device.totalOutputW == null
                                ? AppStatusTone.neutral
                                : AppStatusTone.active,
                          ),
                          _typedPowerBadge(
                            label: 'In Solar',
                            watts: _metricAsDouble(device, 'inputByType.solarW'),
                          ),
                          _typedPowerBadge(
                            label: 'In AC',
                            watts: _metricAsDouble(device, 'inputByType.acW'),
                          ),
                          _typedPowerBadge(
                            label: 'Out AC',
                            watts: _metricAsDouble(device, 'outputByType.acW'),
                          ),
                          _typedPowerBadge(
                            label: 'Out DC',
                            watts: _metricAsDouble(device, 'outputByType.dcW'),
                          ),
                          AppStatusBadge(
                            label: _metricAsDouble(device, 'battery.maxCellTempC') == null
                                ? 'Celda Max N/D'
                                : 'Celda Max ${_metricAsDouble(device, 'battery.maxCellTempC')!.toStringAsFixed(1)}°C',
                            tone: _metricAsDouble(device, 'battery.maxCellTempC') == null
                                ? AppStatusTone.neutral
                                : (_metricAsDouble(device, 'battery.maxCellTempC')! >= 45
                                      ? AppStatusTone.warning
                                      : AppStatusTone.active),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
