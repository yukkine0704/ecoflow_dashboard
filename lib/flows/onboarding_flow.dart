import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ecoflow/ecoflow_direct_repository.dart';
import '../core/ecoflow/ecoflow_models.dart';
import '../design_system/design_system.dart';
import 'device_detail_screen.dart';
import 'settings_screen.dart';
import 'widgets/device_selection_card.dart';

class ApiConfigurationScreen extends StatelessWidget {
  const ApiConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      onSaved: (result) {
        if (!result.saved) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DeviceSelectorScreen()),
        );
      },
    );
  }
}

class DeviceSelectorScreen extends StatefulWidget {
  const DeviceSelectorScreen({
    super.key,
    this.themeMode,
    this.onThemeModeChanged,
  });

  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<DeviceSelectorScreen> createState() => _DeviceSelectorScreenState();
}

class _DeviceSelectorScreenState extends State<DeviceSelectorScreen> {
  final EcoFlowDirectRepository _repository = EcoFlowDirectRepository();
  StreamSubscription<List<EcoFlowDeviceSnapshot>>? _fleetSub;
  StreamSubscription<EcoFlowConnectionState>? _connectionSub;
  StreamSubscription<List<EcoFlowCatalogItem>>? _catalogSub;

  List<EcoFlowDeviceSnapshot> _devices = const <EcoFlowDeviceSnapshot>[];
  List<EcoFlowCatalogItem> _catalog = const <EcoFlowCatalogItem>[];
  final Set<String> _visibleDeviceIds = <String>{};
  bool _loading = true;
  String? _error;
  String? _selectedDeviceId;
  EcoFlowConnectionState _connectionState = const EcoFlowConnectionState(
    status: EcoFlowConnectionStatus.disconnected,
    message: 'Disconnected',
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
        if (state.status == EcoFlowConnectionStatus.error) {
          _error = state.message;
          _loading = false;
        }
      });
    });

    try {
      await _repository.connect();
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

  Future<void> _openDeviceDetail(EcoFlowDeviceSnapshot device) async {
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

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsScreenResult>(
      MaterialPageRoute<SettingsScreenResult>(
        builder: (_) => SettingsScreen(
          initialThemeMode: widget.themeMode,
          allowReconnect: true,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
    if (!mounted || result == null || !result.saved) {
      return;
    }
    if (result.reconnectRequested) {
      await _reconnect();
    }
  }

  List<EcoFlowDeviceSnapshot> _filteredDevices(
    List<EcoFlowDeviceSnapshot> source,
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
                (device) => EcoFlowCatalogItem(
                  deviceId: device.deviceId,
                  displayName: device.displayName,
                  model: device.model,
                  imageUrl: device.imageUrl,
                ),
              )
              .toList();

    if (source.isEmpty) {
      appGooeyToast.warning(
        'Your device catalog is not ready yet',
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
                            'Choose devices to show',
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
                          child: const Text('Select all'),
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
                            subtitle: Text(item.model ?? 'Model unavailable'),
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
                            label: 'Cancel',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Apply',
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

  AppStatusTone _toneFromConnection(EcoFlowConnectionStatus status) {
    switch (status) {
      case EcoFlowConnectionStatus.connected:
        return AppStatusTone.active;
      case EcoFlowConnectionStatus.connecting:
        return AppStatusTone.neutral;
      case EcoFlowConnectionStatus.error:
        return AppStatusTone.warning;
      case EcoFlowConnectionStatus.disconnected:
        return AppStatusTone.warning;
    }
  }

  String _labelFromConnection(EcoFlowConnectionStatus status) {
    switch (status) {
      case EcoFlowConnectionStatus.connected:
        return 'Connected to EcoFlow';
      case EcoFlowConnectionStatus.connecting:
        return 'Connecting to EcoFlow...';
      case EcoFlowConnectionStatus.error:
        return 'Connection issue';
      case EcoFlowConnectionStatus.disconnected:
        return 'EcoFlow disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDevices = _filteredDevices(_devices);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: _openSettings,
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
        ),
        title: Text(
          'Your devices',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.primary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _reconnect,
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy Hub',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ),
              ),
            ],
          ),
          Text(
            'Manage and monitor your power grid.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Reconnect system',
            size: AppButtonSize.small,
            variant: AppButtonVariant.tertiary,
            leading: const Icon(Icons.cable_rounded),
            onPressed: _reconnect,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStatusBadge(
                  label: _labelFromConnection(_connectionState.status),
                  tone: _toneFromConnection(_connectionState.status),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Choose devices',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  onPressed: _openDevicePicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            AppCard(
              surfaceLevel: 1,
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Syncing your devices...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else if (_error != null)
            AppCard(
              surfaceLevel: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We could not reach EcoFlow',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Check your credentials and network, then try reconnecting.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Try again',
                    onPressed: _reconnect,
                    variant: AppButtonVariant.secondary,
                  ),
                ],
              ),
            )
          else if (visibleDevices.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No devices visible yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Open "Choose devices" or wait a moment while your catalog loads.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else ...[
            AppCard(
              child: Text(
                'Showing ${visibleDevices.length} of ${_devices.length} devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...visibleDevices.map((device) {
              final selected = _selectedDeviceId == device.deviceId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DeviceSelectionCard(
                  device: device,
                  selected: selected,
                  onTap: () => _openDeviceDetail(device),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
