import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/ecoflow/connection_diagnostics_state.dart';
import '../core/ecoflow/ecoflow_bootstrap_service.dart';
import '../core/ecoflow/ecoflow_credentials_storage.dart';
import '../core/ecoflow/ecoflow_models.dart';
import '../core/ecoflow/ecoflow_realtime_service.dart';
import '../core/mqtt/mqtt_models.dart';
import '../design_system/design_system.dart';

class DesignSystemTestView extends StatefulWidget {
  const DesignSystemTestView({super.key});

  @override
  State<DesignSystemTestView> createState() => _DesignSystemTestViewState();
}

class _DesignSystemTestViewState extends State<DesignSystemTestView> {
  static const double _solarMaxPower = 1300;
  static const double _solarLowThreshold = 400;

  ThemeMode _themeMode = ThemeMode.system;
  String _period = 'Hoy';
  double _solarPower = 840;
  bool _isSolarLow = false;
  int _stepSliderIndex = 5;
  final int _tabIndex = 0;
  final int _expandedMenuIndex = 2;

  final _nameController = TextEditingController();
  final _quotaController = TextEditingController(text: '80');

  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _baseUrlController = TextEditingController(
    text: 'https://api.ecoflow.com',
  );

  final EcoFlowCredentialsStorage _credentialsStorage =
      EcoFlowCredentialsStorage();
  final List<_DiagnosticLogEntry> _diagnosticLogs = <_DiagnosticLogEntry>[];

  late EcoFlowBootstrapService _bootstrapService;
  EcoFlowRealtimeService? _realtimeService;
  StreamSubscription<MqttIncomingMessage>? _realtimeMessagesSub;
  Timer? _firstMessageTimer;

  ConnectionDiagnosticsState _diagnosticsState =
      const ConnectionDiagnosticsState.idle();
  EcoFlowBootstrapBundle? _bootstrapBundle;
  DateTime? _connectionStartedAt;
  bool _loadingStoredCredentials = true;
  bool _connectInProgress = false;
  bool _deviceSwitchInProgress = false;
  bool _protocolRetryDone = false;
  String? _selectedDeviceSn;

  @override
  void initState() {
    super.initState();
    _refreshBootstrapService();
    unawaited(_loadStoredCredentials());
  }

  @override
  void dispose() {
    _firstMessageTimer?.cancel();
    unawaited(_realtimeMessagesSub?.cancel());
    unawaited(_realtimeService?.dispose() ?? Future<void>.value());

    _nameController.dispose();
    _quotaController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _refreshBootstrapService() {
    final baseUrl = _baseUrlController.text.trim().isEmpty
        ? 'https://api.ecoflow.com'
        : _baseUrlController.text.trim();

    _bootstrapService = EcoFlowBootstrapService(baseUrl: baseUrl);
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final stored = await _credentialsStorage.read();
      if (!mounted) {
        return;
      }

      if (stored != null) {
        _accessKeyController.text = stored.accessKey;
        _secretKeyController.text = stored.secretKey;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      appGooeyToast.warning(
        'No se pudieron cargar credenciales guardadas',
        config: const AppToastConfig(meta: 'ECOFLOW AUTH'),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingStoredCredentials = false);
      }
    }
  }

  Future<void> _saveCredentials() async {
    final credentials = EcoFlowCredentials(
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
    );

    if (!credentials.isValid) {
      appGooeyToast.error(
        'Credenciales incompletas',
        config: const AppToastConfig(
          description: 'Ingresa AccessKey y SecretKey',
          meta: 'ECOFLOW AUTH',
        ),
      );
      return;
    }

    await _credentialsStorage.write(credentials);
    if (!mounted) {
      return;
    }
    appGooeyToast.success(
      'Credenciales guardadas',
      config: const AppToastConfig(meta: 'ECOFLOW AUTH'),
    );
  }

  Future<void> _clearCredentials() async {
    await _credentialsStorage.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _accessKeyController.clear();
      _secretKeyController.clear();
    });

    appGooeyToast.info(
      'Credenciales eliminadas',
      config: const AppToastConfig(meta: 'ECOFLOW AUTH'),
    );
  }

  Future<void> _connectEcoFlow() async {
    if (_connectInProgress) {
      return;
    }

    final credentials = EcoFlowCredentials(
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
    );

    if (!credentials.isValid) {
      appGooeyToast.error(
        'Credenciales incompletas',
        config: const AppToastConfig(
          description: 'Ingresa AccessKey y SecretKey antes de conectar',
          meta: 'ECOFLOW AUTH',
        ),
      );
      return;
    }

    setState(() {
      _connectInProgress = true;
      _diagnosticsState = _diagnosticsState.copyWith(
        stage: ConnectionStage.authenticating,
        restHandshakeOk: false,
        mqttHandshakeOk: false,
        messagesReceived: 0,
        clearLastError: true,
        lastStatusMessage: 'Autenticando con EcoFlow...',
        clearAttemptedProtocol: true,
        clearActiveProtocol: true,
        clearLastMessageAt: true,
        clearFirstMessageWithinTarget: true,
      );
      _diagnosticLogs.clear();
      _bootstrapBundle = null;
      _selectedDeviceSn = null;
      _connectionStartedAt = DateTime.now();
      _protocolRetryDone = false;
    });

    try {
      await _credentialsStorage.write(credentials);
      await _disconnectEcoFlow(showToast: false, resetToIdle: false);
      _refreshBootstrapService();

      final bundle = await _bootstrapService.bootstrap(credentials);
      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapBundle = bundle;
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.mqttConnecting,
          restHandshakeOk: true,
          lastStatusMessage: 'Handshake REST OK. Conectando MQTT...',
          clearLastError: true,
        );
      });

      final realtimeService = EcoFlowRealtimeService(bootstrapBundle: bundle);
      _realtimeService = realtimeService;
      _attachRealtimeListener(realtimeService);

      await realtimeService.connectAndSubscribe(includeWildcardTopic: true);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDeviceSn = bundle.device.sn;
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.streaming,
          mqttHandshakeOk: true,
          attemptedProtocol: realtimeService.attemptedProtocol,
          activeProtocol: realtimeService.activeProtocol,
          lastStatusMessage: 'MQTT conectado y suscripciones activas.',
          clearLastError: true,
        );
      });

      _armFirstMessageTimer();

      appGooeyToast.success(
        'Conexión establecida',
        config: const AppToastConfig(
          description: 'Escuchando quota/status',
          meta: 'ECOFLOW MQTT',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.error,
          lastError: error.toString(),
          lastStatusMessage: 'Falló bootstrap o conexión MQTT.',
        );
      });

      appGooeyToast.error(
        'No se pudo conectar',
        config: AppToastConfig(
          description: '$error',
          meta: 'ECOFLOW CONNECT',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _connectInProgress = false);
      }
    }
  }

  Future<void> _disconnectEcoFlow({
    bool showToast = true,
    bool resetToIdle = true,
  }) async {
    _firstMessageTimer?.cancel();
    _firstMessageTimer = null;

    await _realtimeMessagesSub?.cancel();
    _realtimeMessagesSub = null;

    if (_realtimeService != null) {
      await _realtimeService!.disconnect();
      await _realtimeService!.dispose();
      _realtimeService = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (resetToIdle) {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.idle,
          mqttHandshakeOk: false,
          clearAttemptedProtocol: true,
          clearActiveProtocol: true,
          lastStatusMessage: 'Desconectado',
        );
        _selectedDeviceSn = null;
      }
    });

    if (showToast) {
      appGooeyToast.info(
        'Conexión MQTT cerrada',
        config: const AppToastConfig(meta: 'ECOFLOW MQTT'),
      );
    }
  }

  void _armFirstMessageTimer() {
    _firstMessageTimer?.cancel();
    _firstMessageTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) {
        return;
      }

      if (_diagnosticsState.stage == ConnectionStage.streaming &&
          _diagnosticsState.messagesReceived == 0) {
        if (_diagnosticsState.activeProtocol == 'v5' && !_protocolRetryDone) {
          unawaited(_retryWithV311());
          return;
        }

        setState(() {
          _diagnosticsState = _diagnosticsState.copyWith(
            firstMessageWithinTarget: false,
            lastStatusMessage: 'Conectado, pero no llegó telemetría en 20s.',
          );
        });
      }
    });
  }

  Future<void> _retryWithV311() async {
    final service = _realtimeService;
    if (service == null || !mounted) {
      return;
    }

    _protocolRetryDone = true;
    setState(() {
      _diagnosticsState = _diagnosticsState.copyWith(
        stage: ConnectionStage.retrying,
        lastStatusMessage: 'Sin tráfico en v5, reintentando con MQTT v3.1.1...',
        clearLastError: true,
      );
    });

    try {
      await service.connectAndSubscribe(
        preferredProtocol: MqttProtocolVersion.v311,
        includeWildcardTopic: true,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.streaming,
          mqttHandshakeOk: true,
          attemptedProtocol: service.attemptedProtocol,
          activeProtocol: service.activeProtocol,
          lastStatusMessage: 'MQTT reestablecido con v3.1.1.',
          clearLastError: true,
        );
      });
      _armFirstMessageTimer();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.error,
          lastError: 'Fallback a v3.1.1 falló: $error',
        );
      });
    }
  }

  void _attachRealtimeListener(EcoFlowRealtimeService realtimeService) {
    _realtimeMessagesSub = realtimeService.messages.listen(
      _onRealtimeMessage,
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _diagnosticsState = _diagnosticsState.copyWith(
            stage: ConnectionStage.error,
            lastError: 'Error de stream MQTT: $error',
          );
        });
      },
    );
  }

  EcoFlowBootstrapBundle _withActiveDevice(
    EcoFlowBootstrapBundle bundle,
    EcoFlowDeviceIdentity device,
  ) {
    return EcoFlowBootstrapBundle(
      mqtt: bundle.mqtt,
      device: device,
      devices: bundle.devices,
      certificateAccount: bundle.certificateAccount,
      mqttEndpointUsed: bundle.mqttEndpointUsed,
      deviceEndpointUsed: bundle.deviceEndpointUsed,
    );
  }

  Future<void> _selectActiveDevice(String? sn) async {
    final bundle = _bootstrapBundle;
    if (bundle == null || sn == null) {
      return;
    }
    if (_connectInProgress || _deviceSwitchInProgress || sn == bundle.device.sn) {
      return;
    }

    EcoFlowDeviceIdentity? targetDevice;
    for (final device in bundle.devices) {
      if (device.sn == sn) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice == null) {
      appGooeyToast.warning(
        'No se encontró ese dispositivo en la lista',
        config: const AppToastConfig(meta: 'ECOFLOW DEVICE'),
      );
      return;
    }

    final nextBundle = _withActiveDevice(bundle, targetDevice);
    final wasConnected = _realtimeService != null;

    setState(() {
      _bootstrapBundle = nextBundle;
      _selectedDeviceSn = targetDevice!.sn;
      _diagnosticsState = _diagnosticsState.copyWith(
        lastStatusMessage: wasConnected
            ? 'Cambiando dispositivo activo...'
            : 'Dispositivo activo actualizado (sin conexión MQTT).',
      );
    });

    if (!wasConnected) {
      appGooeyToast.info(
        'Dispositivo activo: ${targetDevice.displayName}',
        config: const AppToastConfig(meta: 'ECOFLOW DEVICE'),
      );
      return;
    }

    setState(() {
      _deviceSwitchInProgress = true;
      _diagnosticsState = _diagnosticsState.copyWith(
        stage: ConnectionStage.mqttConnecting,
        mqttHandshakeOk: false,
        clearLastError: true,
      );
    });

    try {
      _firstMessageTimer?.cancel();
      _firstMessageTimer = null;

      await _realtimeMessagesSub?.cancel();
      _realtimeMessagesSub = null;

      await _realtimeService?.disconnect();
      await _realtimeService?.dispose();

      final realtimeService = EcoFlowRealtimeService(bootstrapBundle: nextBundle);
      _realtimeService = realtimeService;
      _attachRealtimeListener(realtimeService);
      await realtimeService.connectAndSubscribe(includeWildcardTopic: true);

      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.streaming,
          mqttHandshakeOk: true,
          attemptedProtocol: realtimeService.attemptedProtocol,
          activeProtocol: realtimeService.activeProtocol,
          lastStatusMessage:
              'Dispositivo activo cambiado a ${targetDevice!.displayName}.',
          clearLastError: true,
        );
      });
      _armFirstMessageTimer();

      appGooeyToast.success(
        'Dispositivo activo actualizado',
        config: AppToastConfig(
          description: '${targetDevice.displayName} • ${targetDevice.sn}',
          meta: 'ECOFLOW DEVICE',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticsState = _diagnosticsState.copyWith(
          stage: ConnectionStage.error,
          lastError: 'No se pudo reconectar con el nuevo dispositivo: $error',
        );
      });
      appGooeyToast.error(
        'Falló cambio de dispositivo',
        config: AppToastConfig(
          description: '$error',
          meta: 'ECOFLOW DEVICE',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deviceSwitchInProgress = false);
      }
    }
  }

  void _onRealtimeMessage(MqttIncomingMessage message) {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final isFirstMessage = _diagnosticsState.messagesReceived == 0;
    bool? firstWithinTarget = _diagnosticsState.firstMessageWithinTarget;
    if (isFirstMessage && _connectionStartedAt != null) {
      firstWithinTarget =
          now.difference(_connectionStartedAt!) <= const Duration(seconds: 60);
      _firstMessageTimer?.cancel();
      _firstMessageTimer = null;
    }

    setState(() {
      _diagnosticLogs.insert(
        0,
        _DiagnosticLogEntry(
          receivedAt: now,
          topic: message.topic,
          payload: message.payload,
        ),
      );
      if (_diagnosticLogs.length > 24) {
        _diagnosticLogs.removeRange(24, _diagnosticLogs.length);
      }

      _diagnosticsState = _diagnosticsState.copyWith(
        stage: ConnectionStage.streaming,
        mqttHandshakeOk: true,
        messagesReceived: _diagnosticsState.messagesReceived + 1,
        lastMessageAt: now,
        firstMessageWithinTarget: firstWithinTarget,
        lastStatusMessage: 'Streaming activo',
        clearLastError: true,
      );
    });
  }

  void _updateSolarPower(double next, BuildContext context) {
    final clamped = next.clamp(0, _solarMaxPower).toDouble();
    final wasLow = _isSolarLow;
    final isLow = clamped < _solarLowThreshold;

    setState(() {
      _solarPower = clamped;
      _isSolarLow = isLow;
    });

    if (!wasLow && isLow) {
      appGooeyToast.warning(
        'Alerta solar: potencia baja',
        config: AppToastConfig(
          description:
              '${clamped.toStringAsFixed(0)}W por debajo de ${_solarLowThreshold.toInt()}W',
          position: AppToastPosition.topCenter,
          meta: 'ECOFLOW',
          showTimestamp: true,
        ),
      );
    } else if (wasLow && !isLow) {
      appGooeyToast.success(
        'Potencia solar recuperada',
        config: AppToastConfig(
          description: '${clamped.toStringAsFixed(0)}W estable',
          position: AppToastPosition.topCenter,
          meta: 'ECOFLOW',
          showTimestamp: true,
        ),
      );
    }
  }

  AppStatusTone _statusTone(ConnectionStage stage) {
    return switch (stage) {
      ConnectionStage.idle => AppStatusTone.neutral,
      ConnectionStage.authenticating => AppStatusTone.warning,
      ConnectionStage.mqttConnecting => AppStatusTone.warning,
      ConnectionStage.retrying => AppStatusTone.warning,
      ConnectionStage.streaming => AppStatusTone.active,
      ConnectionStage.error => AppStatusTone.danger,
    };
  }

  String _statusLabel(ConnectionStage stage) {
    return switch (stage) {
      ConnectionStage.idle => 'Idle',
      ConnectionStage.authenticating => 'Authenticating',
      ConnectionStage.mqttConnecting => 'MQTT connecting',
      ConnectionStage.retrying => 'Retrying',
      ConnectionStage.streaming => 'Streaming',
      ConnectionStage.error => 'Error',
    };
  }

  Widget _buildDiagnosticsCard(BuildContext context) {
    final hasBundle = _bootstrapBundle != null;

    return AppCard(
      surfaceLevel: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EcoFlow Connection Diagnostics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppStatusBadge(
                label: _statusLabel(_diagnosticsState.stage),
                tone: _statusTone(_diagnosticsState.stage),
              ),
              AppStatusBadge(
                label: _diagnosticsState.restHandshakeOk
                    ? 'REST OK'
                    : 'REST pending',
                tone: _diagnosticsState.restHandshakeOk
                    ? AppStatusTone.active
                    : AppStatusTone.neutral,
              ),
              AppStatusBadge(
                label: _diagnosticsState.mqttHandshakeOk
                    ? 'MQTT OK'
                    : 'MQTT pending',
                tone: _diagnosticsState.mqttHandshakeOk
                    ? AppStatusTone.active
                    : AppStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingStoredCredentials)
            Text(
              'Cargando credenciales guardadas...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          AppTextField(
            controller: _accessKeyController,
            label: 'AccessKey',
            hintText: 'Ingresa tu AccessKey',
            prefixIcon: Icons.key,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _secretKeyController,
            label: 'SecretKey',
            hintText: 'Ingresa tu SecretKey',
            obscureText: true,
            prefixIcon: Icons.security,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _baseUrlController,
            label: 'API Base URL',
            hintText: 'https://api.ecoflow.com',
            prefixIcon: Icons.public,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Guardar',
                variant: AppButtonVariant.secondary,
                onPressed: () => _saveCredentials(),
              ),
              AppButton(
                label: _connectInProgress ? 'Conectando...' : 'Conectar',
                loading: _connectInProgress,
                onPressed: _connectInProgress ? null : () => _connectEcoFlow(),
              ),
              AppButton(
                label: 'Desconectar',
                variant: AppButtonVariant.tertiary,
                onPressed: () => _disconnectEcoFlow(),
              ),
              AppButton(
                label: 'Limpiar credenciales',
                variant: AppButtonVariant.tertiary,
                onPressed: () => _clearCredentials(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Mensajes recibidos: ${_diagnosticsState.messagesReceived}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Protocolo: ${_diagnosticsState.activeProtocol ?? '-'} (intentado: ${_diagnosticsState.attemptedProtocol ?? '-'})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_diagnosticsState.lastStatusMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Estado: ${_diagnosticsState.lastStatusMessage}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_diagnosticsState.lastError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Error: ${_diagnosticsState.lastError}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_diagnosticsState.firstMessageWithinTarget != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _diagnosticsState.firstMessageWithinTarget!
                  ? 'Primer mensaje recibido antes de 60s.'
                  : 'No llegó primer mensaje dentro de 60s.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (hasBundle) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedDeviceSn ?? _bootstrapBundle!.device.sn,
              decoration: const InputDecoration(
                labelText: 'Dispositivo activo',
                border: OutlineInputBorder(),
              ),
              items: _bootstrapBundle!.devices.map((device) {
                return DropdownMenuItem<String>(
                  value: device.sn,
                  child: Text('${device.displayName} (${device.sn})'),
                );
              }).toList(),
              onChanged: (_connectInProgress || _deviceSwitchInProgress)
                  ? null
                  : (sn) => unawaited(_selectActiveDevice(sn)),
            ),
            if (_deviceSwitchInProgress) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cambiando dispositivo y reconectando MQTT...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'SN activo: ${_bootstrapBundle!.device.sn}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'certificateAccount: ${_bootstrapBundle!.certificateAccount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Broker: ${_bootstrapBundle!.mqtt.host}:${_bootstrapBundle!.mqtt.port}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Topic quota: ${_bootstrapBundle!.quotaTopic}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Topic status: ${_bootstrapBundle!.statusTopic}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Dispositivos detectados (prueba): ${_bootstrapBundle!.devices.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._bootstrapBundle!.devices.map((device) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre: ${device.displayName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        'ID: ${device.deviceId ?? 'N/D'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        'SN: ${device.sn}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Últimos mensajes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_diagnosticLogs.isEmpty)
            Text(
              'Aún no hay mensajes.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ..._diagnosticLogs.take(6).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.receivedAt.toIso8601String()} • ${entry.topic}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        entry.payload,
                        maxLines: 4,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      builder: (context, child) {
        return AppGooeyToasterHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('EcoFlow Design System')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
            children: [
              _buildDiagnosticsCard(context),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    AppSegmentedControl<ThemeMode>(
                      value: _themeMode,
                      onChanged: (next) => setState(() => _themeMode = next),
                      options: const [
                        SegmentOption(
                          value: ThemeMode.light,
                          label: 'Claro',
                          icon: Iconsax.sun_1_copy,
                        ),
                        SegmentOption(
                          value: ThemeMode.dark,
                          label: 'Oscuro',
                          icon: Iconsax.moon_copy,
                        ),
                        SegmentOption(
                          value: ThemeMode.system,
                          label: 'Auto',
                          icon: Iconsax.mobile_copy,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppGaugeCard(
                title: 'Entrada Solar',
                value: _solarPower,
                maxValue: _solarMaxPower,
                unit: 'W',
                subtitle: 'Producción estimada para las próximas 2 horas',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppNeedleGaugeCard(
                value: _solarPower,
                maxValue: _solarMaxPower,
                lowPowerThreshold: _solarLowThreshold,
                title: 'Gauge de Aguja',
                subtitle: 'Capacidad máxima EcoFlow Delta 3',
                onLowPowerChanged: (low) {
                  if (!mounted || low == _isSolarLow) {
                    return;
                  }
                  setState(() => _isSolarLow = low);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                surfaceLevel: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajuste de Potencia Solar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        AppStatusBadge(
                          label: _isSolarLow
                              ? 'Baja (< ${_solarLowThreshold.toInt()}W)'
                              : 'Normal',
                          tone: _isSolarLow
                              ? AppStatusTone.warning
                              : AppStatusTone.active,
                        ),
                      ],
                    ),
                    Slider(
                      min: 0,
                      max: _solarMaxPower,
                      value: _solarPower.clamp(0, _solarMaxPower),
                      onChanged: (next) => _updateSolarPower(next, context),
                    ),
                    Text(
                      '${_solarPower.toStringAsFixed(0)} / ${_solarMaxPower.toInt()} W',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StepSlider',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Índice seleccionado: $_stepSliderIndex',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppStepSlider(
                      stepCount: 11,
                      defaultIndex: _stepSliderIndex,
                      stepShape: StepSliderShape.diamond,
                      onValueChange: (index) {
                        setState(() => _stepSliderIndex = index);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gooey Toast',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton(
                          label: 'Success',
                          onPressed: () {
                            appGooeyToast.success(
                              'Configuración guardada',
                              config: const AppToastConfig(
                                description: 'Cambios aplicados en el inversor',
                                meta: 'SUCCESS',
                                showTimestamp: true,
                              ),
                            );
                          },
                        ),
                        AppButton(
                          label: 'Error',
                          variant: AppButtonVariant.danger,
                          onPressed: () {
                            appGooeyToast.error(
                              'No se pudo conectar',
                              config: AppToastConfig(
                                description: 'Revisa red y reintenta',
                                meta: 'NETWORK',
                                action: AppToastAction(
                                  label: 'Reintentar',
                                  onPressed: () {},
                                ),
                                bodyLayout: AppToastBodyLayout.spread,
                              ),
                            );
                          },
                        ),
                        AppButton(
                          label: 'Promise',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            appGooeyToast.promise(
                              Future<void>.delayed(const Duration(seconds: 2)),
                              loading: 'Actualizando cuota...',
                              success: 'Cuota actualizada',
                              error: 'No se pudo actualizar',
                              config: const AppToastConfig(
                                description: 'Esperando respuesta del equipo',
                                position: AppToastPosition.bottomCenter,
                              ),
                              successDescription: (_) => 'Respuesta confirmada',
                              errorDescription: (err) => '$err',
                            );
                          },
                        ),
                        AppButton(
                          label: 'Dismiss all',
                          variant: AppButtonVariant.tertiary,
                          onPressed: () => appGooeyToast.dismissAll(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linear Tabs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tab: $_tabIndex | Menú: $_expandedMenuIndex',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                surfaceLevel: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inputs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _nameController,
                      label: 'Nombre del dispositivo',
                      hintText: 'Ej: Delta Pro 3',
                      prefixIcon: Iconsax.battery_full_copy,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _quotaController,
                      label: 'Límite de carga',
                      hintText: '0-100',
                      keyboardType: TextInputType.number,
                      suffixIcon: Iconsax.percentage_square_copy,
                      errorText:
                          _quotaController.text.isEmpty ? 'Campo requerido' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSegmentedControl<String>(
                      value: _period,
                      onChanged: (next) => setState(() => _period = next),
                      options: const [
                        SegmentOption(value: 'Hoy', label: 'Hoy'),
                        SegmentOption(value: 'Semana', label: 'Semana'),
                        SegmentOption(value: 'Mes', label: 'Mes'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppChip(label: 'Modo Eco', tone: AppChipTone.primary),
                        AppChip(label: 'PV Online', tone: AppChipTone.success),
                        AppChip(label: 'Revisar Red', tone: AppChipTone.warning),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticLogEntry {
  const _DiagnosticLogEntry({
    required this.receivedAt,
    required this.topic,
    required this.payload,
  });

  final DateTime receivedAt;
  final String topic;
  final String payload;
}

