import 'package:flutter/material.dart';

import '../core/bridge/bridge_settings_storage.dart';
import '../design_system/design_system.dart';

class SettingsScreenResult {
  const SettingsScreenResult({
    required this.wsUrl,
    required this.saved,
    required this.reconnectRequested,
  });

  final String wsUrl;
  final bool saved;
  final bool reconnectRequested;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialWsUrl,
    this.initialThemeMode,
    this.allowReconnect = false,
    this.onThemeModeChanged,
    this.onSaved,
  });

  final String? initialWsUrl;
  final ThemeMode? initialThemeMode;
  final bool allowReconnect;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<SettingsScreenResult>? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _wsUrlController = TextEditingController();
  final _settingsStorage = BridgeSettingsStorage();

  bool _loading = true;
  bool _saving = false;
  ThemeMode _themeMode = ThemeMode.system;
  static const List<SegmentOption<ThemeMode>> _themeOptions = [
    SegmentOption<ThemeMode>(value: ThemeMode.light, label: 'Light', icon: Icons.light_mode),
    SegmentOption<ThemeMode>(value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode),
    SegmentOption<ThemeMode>(value: ThemeMode.system, label: 'System', icon: Icons.settings_suggest),
  ];

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
      final wsUrlFuture = widget.initialWsUrl == null
          ? _settingsStorage.readWsUrl()
          : Future<String>.value(widget.initialWsUrl!);
      final themeModeFuture = widget.initialThemeMode == null
          ? _settingsStorage.readThemeMode()
          : Future<ThemeMode>.value(widget.initialThemeMode!);
      final results = await Future.wait<dynamic>([wsUrlFuture, themeModeFuture]);
      if (!mounted) {
        return;
      }
      _wsUrlController.text = results[0] as String;
      _themeMode = results[1] as ThemeMode;
    } catch (_) {
      if (!mounted) {
        return;
      }
      _wsUrlController.text = 'ws://127.0.0.1:8787/ws';
      _themeMode = ThemeMode.system;
      appGooeyToast.warning(
        'We could not load your saved settings',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    setState(() => _themeMode = mode);
    await _settingsStorage.writeThemeMode(mode);
    widget.onThemeModeChanged?.call(mode);
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
        config: AppToastConfig(description: error, meta: 'SETTINGS'),
      );
      return false;
    }
    if (_saving) {
      return false;
    }

    setState(() => _saving = true);
    try {
      final wsUrl = _wsUrlController.text.trim();
      await _settingsStorage.writeWsUrl(wsUrl);
      if (!mounted) {
        return true;
      }
      appGooeyToast.success(
        'Connection saved',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
      return true;
    } catch (error) {
      if (mounted) {
        appGooeyToast.error(
          'Could not save settings',
          config: AppToastConfig(description: '$error', meta: 'SETTINGS'),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAndClose({required bool reconnectRequested}) async {
    final ok = await _saveConfiguration();
    if (!ok || !mounted) {
      return;
    }
    final result = SettingsScreenResult(
      wsUrl: _wsUrlController.text.trim(),
      saved: true,
      reconnectRequested: reconnectRequested,
    );
    if (widget.onSaved != null) {
      widget.onSaved!(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage bridge connection',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Update where the app connects for live device data.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                  'You can keep this default URL if your bridge runs locally.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  surfaceLevel: 2,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Choose between light, dark, or system theme mode.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSegmentedControl<ThemeMode>(
                        options: _themeOptions,
                        value: _themeMode,
                        onChanged: _setThemeMode,
                      ),
                    ],
                  ),
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
                    'Protocol and troubleshooting details',
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save connection',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  loading: _saving,
                  onPressed: _saving ? null : _saveConfiguration,
                ),
                if (widget.allowReconnect) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Save and reconnect',
                    fullWidth: true,
                    trailing: const Icon(Icons.refresh),
                    onPressed: _saving ? null : () => _saveAndClose(reconnectRequested: true),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Save and continue',
                    fullWidth: true,
                    onPressed: _saving ? null : () => _saveAndClose(reconnectRequested: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
