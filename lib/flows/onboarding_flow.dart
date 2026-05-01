import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge/bridge_models.dart';
import '../core/bridge/bridge_repository.dart';
import '../core/bridge/bridge_settings_storage.dart';
import '../design_system/design_system.dart';
import 'device_detail_screen.dart';
import 'settings_screen.dart';
import 'widgets/device_selection_card.dart';

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
        'We could not load your connection settings',
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
      return 'Enter your bridge WebSocket URL.';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'This URL format does not look valid.';
    }
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      return 'Use a URL that starts with ws:// or wss://.';
    }
    return null;
  }

  Future<bool> _saveConfiguration() async {
    final error = _validateWsUrl();
    if (error != null) {
      appGooeyToast.error(
        'Connection URL needed',
        config: AppToastConfig(description: error, meta: 'BRIDGE WS'),
      );
      return false;
    }
    if (_saving) {
      return false;
    }

    setState(() => _saving = true);
    try {
      await _settingsStorage.writeWsUrl(_wsUrlController.text.trim());
      if (!mounted) {
        return true;
      }
      appGooeyToast.success(
        'Connection saved',
        config: const AppToastConfig(meta: 'BRIDGE WS'),
      );
      return true;
    } catch (error) {
      if (mounted) {
        appGooeyToast.error(
          'Could not save settings',
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
        builder: (_) => DeviceSelectorScreen(wsUrl: _wsUrlController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Started')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bring your EcoFlow devices to life',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Connect once, then monitor your devices in real time from one place.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppStatusBadge(
                  label: 'Step 1 of 2: Bridge connection',
                  tone: AppStatusTone.neutral,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Loading your saved connection...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                AppTextField(
                  controller: _wsUrlController,
                  label: 'Connection URL',
                  hintText: 'ws://127.0.0.1:8787/ws',
                  prefixIcon: Icons.wifi_tethering,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tip: keep your local bridge running before you continue.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'Advanced settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    'Technical details and protocol requirements',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    AppCard(
                      surfaceLevel: 2,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accepted protocol: ws:// or wss://',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Default local endpoint: ws://127.0.0.1:8787/ws',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'If connection fails, verify bridge availability and firewall permissions.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Connect and continue',
                  fullWidth: true,
                  trailing: const Icon(Icons.arrow_forward),
                  loading: _saving,
                  onPressed: _saving ? null : _continueToSelector,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Save for later',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _saving ? null : _saveConfiguration,
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
  const DeviceSelectorScreen({
    super.key,
    required this.wsUrl,
    this.themeMode,
    this.onThemeModeChanged,
  });

  final String wsUrl;
  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

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
    message: 'Disconnected',
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
        _selectedDeviceId ??= filtered.isNotEmpty ? filtered.first.deviceId : null;
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
      await _repository.connect(_wsUrl);
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

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsScreenResult>(
      MaterialPageRoute<SettingsScreenResult>(
        builder: (_) => SettingsScreen(
          initialWsUrl: _wsUrl,
          initialThemeMode: widget.themeMode,
          allowReconnect: true,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
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

  List<BridgeDeviceSnapshot> _filteredDevices(List<BridgeDeviceSnapshot> source) {
    if (_visibleDeviceIds.isEmpty) {
      return source;
    }
    return source.where((device) => _visibleDeviceIds.contains(device.deviceId)).toList();
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
        'Your device catalog is not ready yet',
        config: const AppToastConfig(meta: 'DEVICE PICKER'),
      );
      return;
    }

    final workingSet = Set<String>.from(
      _visibleDeviceIds.isEmpty ? source.map((item) => item.deviceId) : _visibleDeviceIds,
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
                                    !_visibleDeviceIds.contains(_selectedDeviceId)) {
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
        return 'Connected to bridge';
      case BridgeConnectionStatus.connecting:
        return 'Connecting to bridge...';
      case BridgeConnectionStatus.error:
        return 'Connection issue';
      case BridgeConnectionStatus.disconnected:
        return 'Bridge disconnected';
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
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
                    'We could not reach your bridge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Check your bridge and network, then try reconnecting.',
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
