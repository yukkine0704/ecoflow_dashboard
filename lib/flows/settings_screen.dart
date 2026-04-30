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
    this.allowReconnect = false,
    this.onSaved,
  });

  final String? initialWsUrl;
  final bool allowReconnect;
  final ValueChanged<SettingsScreenResult>? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      final wsUrl = widget.initialWsUrl ?? await _settingsStorage.readWsUrl();
      if (!mounted) {
        return;
      }
      _wsUrlController.text = wsUrl;
    } catch (_) {
      if (!mounted) {
        return;
      }
      _wsUrlController.text = 'ws://127.0.0.1:8787/ws';
      appGooeyToast.warning(
        'No se pudo cargar la configuración',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
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
      return 'La URL no es válida';
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
        'URL inválida',
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
        'Configuración guardada',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
      return true;
    } catch (error) {
      if (mounted) {
        appGooeyToast.error(
          'No se pudo guardar',
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
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge WebSocket',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Configura la URL del bridge local para recibir telemetría en tiempo real.',
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
                if (widget.allowReconnect) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Guardar y reconectar',
                    fullWidth: true,
                    trailing: const Icon(Icons.wifi_tethering),
                    onPressed: _saving
                        ? null
                        : () {
                            _saveAndClose(reconnectRequested: true);
                          },
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Guardar y continuar',
                    fullWidth: true,
                    onPressed: _saving
                        ? null
                        : () {
                            _saveAndClose(reconnectRequested: false);
                          },
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
