import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/ecoflow/ecoflow_app_mqtt_auth_service.dart';
import '../core/ecoflow/ecoflow_bootstrap_service.dart';
import '../core/ecoflow/ecoflow_credentials_storage.dart';
import '../core/ecoflow/ecoflow_models.dart';
import '../core/ecoflow/ecoflow_realtime_service.dart';
import '../core/ecoflow/ecoflow_telemetry_parser.dart';
import '../core/mqtt/mqtt_models.dart';
import '../design_system/design_system.dart';
import 'device_detail_screen.dart';
import '../test_views/design_system_test_view.dart';

const _defaultBaseUrl = 'https://api.ecoflow.com';

class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen> {
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _appEmailController = TextEditingController();
  final _appPasswordController = TextEditingController();
  final _baseUrlController = TextEditingController(text: _defaultBaseUrl);
  final _credentialsStorage = EcoFlowCredentialsStorage();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _appEmailController.dispose();
    _appPasswordController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    try {
      final storedCredentials = await _credentialsStorage.read();
      final storedBaseUrl = await _credentialsStorage.readBaseUrl();
      if (!mounted) {
        return;
      }

      if (storedCredentials != null) {
        _accessKeyController.text = storedCredentials.accessKey;
        _secretKeyController.text = storedCredentials.secretKey;
        _appEmailController.text = storedCredentials.appEmail ?? '';
        _appPasswordController.text = storedCredentials.appPassword ?? '';
      }
      _baseUrlController.text = storedBaseUrl;
    } catch (_) {
      if (mounted) {
        appGooeyToast.warning(
          'No se pudieron cargar credenciales guardadas',
          config: const AppToastConfig(meta: 'ECOFLOW AUTH'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateBaseUrl() {
    final candidate = _baseUrlController.text.trim();
    if (candidate.isEmpty) {
      return 'Ingresa API Endpoint URL';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'La URL no es valida';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'La URL debe usar http o https';
    }
    return null;
  }

  Future<bool> _saveConfiguration() async {
    final credentials = EcoFlowCredentials(
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
      appEmail: _appEmailController.text.trim(),
      appPassword: _appPasswordController.text.trim(),
    );
    final baseUrlError = _validateBaseUrl();

    if (!credentials.isOpenApiValid) {
      appGooeyToast.error(
        'Credenciales incompletas',
        config: const AppToastConfig(
          description: 'Ingresa AccessKey y SecretKey para cargar dispositivos.',
          meta: 'ECOFLOW AUTH',
        ),
      );
      return false;
    }
    if (baseUrlError != null) {
      appGooeyToast.error(
        'Endpoint invalido',
        config: AppToastConfig(
          description: baseUrlError,
          meta: 'ECOFLOW AUTH',
        ),
      );
      return false;
    }

    if (_saving) {
      return false;
    }

    setState(() => _saving = true);
    try {
      await _credentialsStorage.write(credentials);
      await _credentialsStorage.writeBaseUrl(_baseUrlController.text.trim());

      if (!mounted) {
        return true;
      }
      appGooeyToast.success(
        'Configuracion guardada',
        config: const AppToastConfig(meta: 'ECOFLOW AUTH'),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      appGooeyToast.error(
        'No se pudo guardar',
        config: AppToastConfig(
          description: '$error',
          meta: 'ECOFLOW AUTH',
        ),
      );
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

    final credentials = EcoFlowCredentials(
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
      appEmail: _appEmailController.text.trim(),
      appPassword: _appPasswordController.text.trim(),
    );
    final baseUrl = _baseUrlController.text.trim();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceSelectorScreen(
          credentials: credentials,
          baseUrl: baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion de API'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignSystemTestView(),
                ),
              );
            },
            child: const Text('Test View'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Your System',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ingresa credenciales de desarrollador y opcionalmente credenciales de app para MQTT avanzado.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Cargando datos guardados...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                AppTextField(
                  controller: _accessKeyController,
                  label: 'Access Key',
                  hintText: 'e.g. AKIAIOSFODNN7EXAMPLE',
                  prefixIcon: Icons.key,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _secretKeyController,
                  label: 'Secret Key',
                  hintText: '••••••••••••••••',
                  prefixIcon: Icons.password,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'App MQTT (recomendado para River 3 / Delta 3)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _appEmailController,
                  label: 'EcoFlow Email',
                  hintText: 'tu-correo@dominio.com',
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _appPasswordController,
                  label: 'EcoFlow Password',
                  hintText: '••••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _baseUrlController,
                  label: 'API Endpoint URL',
                  hintText: _defaultBaseUrl,
                  prefixIcon: Icons.public,
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
                  label: 'Authorize & Sync',
                  fullWidth: true,
                  trailing: const Icon(Icons.sync),
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
  const DeviceSelectorScreen({
    super.key,
    required this.credentials,
    required this.baseUrl,
  });

  final EcoFlowCredentials credentials;
  final String baseUrl;

  @override
  State<DeviceSelectorScreen> createState() => _DeviceSelectorScreenState();
}

class _DeviceSelectorScreenState extends State<DeviceSelectorScreen> {
  EcoFlowBootstrapBundle? _bundle;
  EcoFlowBootstrapService? _bootstrapService;
  final EcoFlowAppMqttAuthService _appMqttAuthService = EcoFlowAppMqttAuthService();
  EcoFlowMqttCertification? _appMqttCertification;
  bool _loading = true;
  String? _error;
  String? _selectedSn;
  EcoFlowRealtimeService? _selectorRealtimeService;
  StreamSubscription<MqttIncomingMessage>? _selectorRealtimeSubscription;
  StreamSubscription<TelemetryHealthState>? _selectorRealtimeHealthSubscription;
  Timer? _fallbackRestTimer;
  Timer? _appMqttCommandTimer;
  Future<void> _hydrateQueue = Future<void>.value();
  int _mqttSessionToken = 0;
  int _fallbackRestAttempt = 0;
  bool _wildcardEscalated = false;
  DateTime? _lastTelemetryAt;
  bool _telemetryAvailable = false;
  bool _telemetryTimedOut = false;
  bool _fallbackRestActive = false;
  bool _telemetryRetrying = false;
  final Map<String, ValueNotifier<EcoFlowDeviceDetailState?>> _detailNotifiers =
      <String, ValueNotifier<EcoFlowDeviceDetailState?>>{};

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    unawaited(_disposeSelectorRealtime());
    _fallbackRestTimer?.cancel();
    for (final notifier in _detailNotifiers.values) {
      notifier.dispose();
    }
    _detailNotifiers.clear();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _log('load_devices.start', <String, dynamic>{'baseUrl': widget.baseUrl});
      final service = EcoFlowBootstrapService(baseUrl: widget.baseUrl);
      _bootstrapService = service;
      final bundle = await service.bootstrap(widget.credentials);
      List<EcoFlowDeviceIdentity> seededDevices = bundle.devices;
      try {
        seededDevices = await service.enrichDevicesWithQuota(
          credentials: widget.credentials,
          devices: bundle.devices,
        );
      } catch (error) {
        _log(
          'load_devices.quota_seed.error',
          <String, dynamic>{'error': '$error'},
        );
      }
      final activeDevice = seededDevices.firstWhere(
        (device) => device.sn == bundle.device.sn,
        orElse: () => seededDevices.first,
      );
      final hydratedBundle = EcoFlowBootstrapBundle(
        mqtt: bundle.mqtt,
        device: activeDevice,
        devices: seededDevices,
        certificateAccount: bundle.certificateAccount,
        mqttEndpointUsed: bundle.mqttEndpointUsed,
        deviceEndpointUsed: bundle.deviceEndpointUsed,
      );
      EcoFlowMqttCertification? appMqttCertification;
      if (widget.credentials.isAppAuthValid) {
        try {
          appMqttCertification = await _appMqttAuthService.fetchMqttCertification(
            email: widget.credentials.appEmail!.trim(),
            password: widget.credentials.appPassword!.trim(),
          );
          _log(
            'app_mqtt.auth.success',
            <String, dynamic>{
              'channel': appMqttCertification.channel.name,
              'host': appMqttCertification.host,
              'port': appMqttCertification.port,
            },
          );
        } catch (error) {
          _log('app_mqtt.auth.error', <String, dynamic>{'error': '$error'});
        }
      }
      if (!mounted) {
        return;
      }
      _log(
        'load_devices.bundle',
        <String, dynamic>{
          'deviceCount': hydratedBundle.devices.length,
          'activeSn': hydratedBundle.device.sn,
          'devices': hydratedBundle.devices
              .map(
                (d) => <String, dynamic>{
                  'sn': d.sn,
                  'name': d.name,
                  'model': d.model,
                  'batteryPercent': d.batteryPercent,
                  'isOnline': d.isOnline,
                  'imageUrl': d.imageUrl,
                  'raw': d.raw,
                },
              )
              .toList(),
        },
      );
      setState(() {
        _bundle = hydratedBundle;
        _appMqttCertification = appMqttCertification;
        _selectedSn = hydratedBundle.device.sn;
        _telemetryAvailable = false;
        _telemetryTimedOut = false;
        _fallbackRestActive = false;
        _wildcardEscalated = false;
        _lastTelemetryAt = null;
      });
      _seedDetailStates(hydratedBundle.devices);
      for (final device in hydratedBundle.devices) {
        unawaited(_refreshDeviceRawSnapshot(device.sn, silent: true));
      }
      unawaited(_hydrateDevicesFromMqtt(hydratedBundle));
      if (widget.credentials.isAppAuthValid && appMqttCertification == null) {
        appGooeyToast.warning(
          'No se pudo activar App MQTT',
          config: const AppToastConfig(
            description: 'Se usará canal Open MQTT como fallback.',
            meta: 'ECOFLOW MQTT',
          ),
        );
      }
      appGooeyToast.success(
        'Dispositivos cargados',
        config: AppToastConfig(
          description: '${hydratedBundle.devices.length} vinculados',
          meta: 'ECOFLOW DEVICES',
        ),
      );
    } catch (error) {
      _log('load_devices.error', <String, dynamic>{'error': '$error'});
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _hydrateDevicesFromMqtt(EcoFlowBootstrapBundle bundle) async {
    final sessionToken = ++_mqttSessionToken;
    _hydrateQueue = _hydrateQueue.then(
      (_) => _runHydrateDevicesFromMqtt(bundle, sessionToken),
    );
    await _hydrateQueue;
  }

  Future<void> _runHydrateDevicesFromMqtt(
    EcoFlowBootstrapBundle bundle,
    int sessionToken,
  ) async {
    await _disposeSelectorRealtime();
    _stopFallbackRestPolling(resetAttempt: true);

    final mqttCert = _appMqttCertification ?? bundle.mqtt;
    final connectionBundle = EcoFlowBootstrapBundle(
      mqtt: mqttCert,
      device: bundle.device,
      devices: bundle.devices,
      certificateAccount: bundle.certificateAccount,
      mqttEndpointUsed: bundle.mqttEndpointUsed,
      deviceEndpointUsed: bundle.deviceEndpointUsed,
    );
    final usingAppMqtt = mqttCert.channel == EcoFlowMqttChannel.app;

    final topics = <String>{};
    for (final device in connectionBundle.devices) {
      if (usingAppMqtt) {
        topics.add('/app/device/property/${device.sn}');
      } else {
        topics.addAll(
          connectionBundle.topicsForDeviceSn(
            device.sn,
            includeSetReply: true,
            includeWildcard: _wildcardEscalated,
          ),
        );
      }
    }
    final topicList = topics.toList();
    _log(
      'mqtt_snapshot.start',
      <String, dynamic>{
        'sessionToken': sessionToken,
        'channel': mqttCert.channel.name,
        'wildcardEscalated': _wildcardEscalated,
        'topics': topicList,
      },
    );

    final realtimeService = EcoFlowRealtimeService(bootstrapBundle: connectionBundle);
    _selectorRealtimeService = realtimeService;

    try {
      await realtimeService.connectAndSubscribe(
        preferredProtocol: MqttProtocolVersion.v311,
        includeDefaultTopics: !usingAppMqtt,
        includeSetReplyTopic: !usingAppMqtt,
        includeWildcardTopic: !usingAppMqtt && _wildcardEscalated,
        additionalTopics: topicList,
        firstMessageTimeout: const Duration(seconds: 18),
        staleTimeout: const Duration(seconds: 90),
        enableAutoReconnectBackoff: true,
        connectionSessionId: 'selector_$sessionToken',
      );
      if (usingAppMqtt) {
        _startAppMqttCommandLoop(
          realtimeService: realtimeService,
          bundle: connectionBundle,
          sessionToken: sessionToken,
        );
        _requestAppLatestQuotas(
          realtimeService: realtimeService,
          bundle: connectionBundle,
          sessionToken: sessionToken,
        );
      }
      if (!mounted || sessionToken != _mqttSessionToken) {
        return;
      }

      _selectorRealtimeHealthSubscription = realtimeService.health.listen(
        (state) => _onRealtimeHealthState(state, sessionToken),
      );

      _selectorRealtimeSubscription = realtimeService.messages.listen((message) {
        if (!mounted || sessionToken != _mqttSessionToken) {
          return;
        }
        final sn = _extractSnFromTopic(message.topic);
        if (sn == null) {
          return;
        }

        final parsed = EcoFlowTelemetryParser.parseMessagePayload(
          message.payload,
          rawPayloadBytes: message.rawPayloadBytes,
        );
        _log(
          'mqtt_snapshot.payload',
          <String, dynamic>{
            'sessionToken': sessionToken,
            'topic': message.topic,
            'rawPayloadLength': message.rawPayloadBytes?.length ?? 0,
            'raw': EcoFlowTelemetryParser.redactPayload(parsed.payload),
            'params': EcoFlowTelemetryParser.redactPayload(parsed.params),
            'batteryPercent': parsed.batteryPercent,
            'online': parsed.online,
          },
        );

        final trustedBattery = _selectTrustedBatteryPercent(
          sn: sn,
          parsed: parsed,
        );
        _mergeDetailFromMqtt(
          sn: sn,
          params: parsed.params,
        );

        if (trustedBattery != null || parsed.online != null) {
          _applyRealtimePatch(
            sn: sn,
            batteryPercent: trustedBattery,
            online: parsed.online,
          );
        }
      });
    } catch (error) {
      _log(
        'mqtt_snapshot.error',
        <String, dynamic>{'sessionToken': sessionToken, 'error': '$error'},
      );
      if (sessionToken == _mqttSessionToken) {
        await _startFallbackRestPolling(sessionToken);
      }
      await _disposeSelectorRealtime();
    }
  }

  ValueNotifier<EcoFlowDeviceDetailState?> _getOrCreateDetailNotifier(String sn) {
    return _detailNotifiers.putIfAbsent(
      sn,
      () => ValueNotifier<EcoFlowDeviceDetailState?>(null),
    );
  }

  void _seedDetailStates(List<EcoFlowDeviceIdentity> devices) {
    final activeSns = devices.map((device) => device.sn).toSet();
    final staleKeys = _detailNotifiers.keys
        .where((sn) => !activeSns.contains(sn))
        .toList();
    for (final sn in staleKeys) {
      _detailNotifiers.remove(sn)?.dispose();
    }

    for (final device in devices) {
      final notifier = _getOrCreateDetailNotifier(device.sn);
      final previous = notifier.value;
      final seededRaw = _mapFromAny(device.raw);
      final mergedRaw = <String, dynamic>{
        ...seededRaw,
        ...?previous?.mergedRaw,
      };
      notifier.value = EcoFlowDeviceDetailState(
        sn: device.sn,
        mergedRaw: mergedRaw,
        lastRestSnapshotAt: previous?.lastRestSnapshotAt,
        lastMqttUpdateAt: previous?.lastMqttUpdateAt,
        lastSource: previous?.lastSource ?? EcoFlowDetailUpdateSource.none,
      );
    }
  }

  Future<void> _refreshDeviceRawSnapshot(String sn, {bool silent = false}) async {
    final service = _bootstrapService;
    if (service == null) {
      return;
    }
    try {
      final raw = await service.fetchDeviceRawQuotaSnapshot(
        credentials: widget.credentials,
        sn: sn,
      );
      _mergeDetailFromRest(sn: sn, restRaw: raw);
    } catch (error) {
      _log(
        'detail.rest.error',
        <String, dynamic>{'sn': sn, 'error': '$error'},
      );
      if (!silent && mounted) {
        appGooeyToast.error(
          'No se pudo actualizar snapshot',
          config: AppToastConfig(description: '$error', meta: sn),
        );
      }
    }
  }

  void _mergeDetailFromRest({
    required String sn,
    required Map<String, dynamic> restRaw,
  }) {
    final notifier = _getOrCreateDetailNotifier(sn);
    final current = notifier.value;
    notifier.value = EcoFlowDeviceDetailState(
      sn: sn,
      mergedRaw: <String, dynamic>{
        ...?current?.mergedRaw,
        ...restRaw,
      },
      lastRestSnapshotAt: DateTime.now(),
      lastMqttUpdateAt: current?.lastMqttUpdateAt,
      lastSource: EcoFlowDetailUpdateSource.rest,
    );
  }

  void _mergeDetailFromMqtt({
    required String sn,
    required Map<String, dynamic>? params,
  }) {
    if (params == null || params.isEmpty) {
      return;
    }
    final notifier = _getOrCreateDetailNotifier(sn);
    final current = notifier.value;
    notifier.value = EcoFlowDeviceDetailState(
      sn: sn,
      mergedRaw: <String, dynamic>{
        ...?current?.mergedRaw,
        ...params,
      },
      lastRestSnapshotAt: current?.lastRestSnapshotAt,
      lastMqttUpdateAt: DateTime.now(),
      lastSource: EcoFlowDetailUpdateSource.mqtt,
    );
  }

  Map<String, dynamic> _mapFromAny(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  Future<void> _openDeviceDetail(EcoFlowDeviceIdentity device) async {
    setState(() => _selectedSn = device.sn);
    final notifier = _getOrCreateDetailNotifier(device.sn);
    unawaited(_refreshDeviceRawSnapshot(device.sn, silent: true));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceDetailScreen(
          device: device,
          detailStateListenable: notifier,
          onRefresh: () => _refreshDeviceRawSnapshot(device.sn),
        ),
      ),
    );
  }

  Future<void> _retryTelemetry() async {
    final bundle = _bundle;
    if (bundle == null || _telemetryRetrying) {
      return;
    }

    setState(() {
      _telemetryRetrying = true;
      _telemetryTimedOut = false;
      _telemetryAvailable = false;
      _fallbackRestActive = false;
      _wildcardEscalated = false;
      _lastTelemetryAt = null;
    });

    try {
      await _hydrateDevicesFromMqtt(bundle);
    } finally {
      if (mounted) {
        setState(() => _telemetryRetrying = false);
      }
    }
  }

  void _applyRealtimePatch({
    required String sn,
    int? batteryPercent,
    bool? online,
  }) {
    if (!mounted || _bundle == null) {
      return;
    }

    final current = _bundle!;
    final updatedDevices = current.devices.map((device) {
      if (device.sn != sn) {
        return device;
      }
      return device.copyWith(
        batteryPercent: batteryPercent ?? device.batteryPercent,
        isOnline: online ?? device.isOnline,
      );
    }).toList();

    final updatedActive = updatedDevices.firstWhere(
      (d) => d.sn == current.device.sn,
      orElse: () => updatedDevices.first,
    );

    _log(
      'mqtt_snapshot.patch',
      <String, dynamic>{
        'sn': sn,
        'batteryPercent': batteryPercent,
        'online': online,
      },
    );

    setState(() {
      _telemetryAvailable = true;
      _telemetryTimedOut = false;
      _fallbackRestActive = false;
      _lastTelemetryAt = DateTime.now();
      _bundle = EcoFlowBootstrapBundle(
        mqtt: current.mqtt,
        device: updatedActive,
        devices: updatedDevices,
        certificateAccount: current.certificateAccount,
        mqttEndpointUsed: current.mqttEndpointUsed,
        deviceEndpointUsed: current.deviceEndpointUsed,
      );
    });
  }

  int? _selectTrustedBatteryPercent({
    required String sn,
    required EcoFlowTelemetryParseResult parsed,
  }) {
    final candidate = parsed.batteryPercent;
    if (candidate == null) {
      return null;
    }

    final params = parsed.params;
    final socField = _asInt(params?['_socField']);
    final confidence = (params?['_socConfidence']?.toString() ?? 'low')
        .toLowerCase()
        .trim();

    final currentBattery = _bundle?.devices
        .firstWhere(
          (device) => device.sn == sn,
          orElse: () => _bundle!.device,
        )
        .batteryPercent;
    if (currentBattery == null) {
      return candidate;
    }

    final delta = (candidate - currentBattery).abs();
    final isLargeDrop = candidate <= 25 && currentBattery >= 40;
    final fieldLooksNoisy = socField == 9;
    final lowConfidence = confidence == 'low';
    final mediumConfidence = confidence == 'medium';

    // Keep a previously stable value when a noisy frame suddenly reports
    // a very low SOC (common in non-primary protobuf frames).
    if ((fieldLooksNoisy && delta >= 20 && isLargeDrop) ||
        (lowConfidence && delta >= 15) ||
        (mediumConfidence && delta >= 45 && isLargeDrop)) {
      _log(
        'mqtt_snapshot.battery.skip',
        <String, dynamic>{
          'sn': sn,
          'candidate': candidate,
          'current': currentBattery,
          'socField': socField,
          'confidence': confidence,
          'delta': delta,
        },
      );
      return null;
    }

    return candidate;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<void> _disposeSelectorRealtime() async {
    _stopAppMqttCommandLoop();
    _stopFallbackRestPolling(resetAttempt: true);
    await _selectorRealtimeHealthSubscription?.cancel();
    _selectorRealtimeHealthSubscription = null;
    await _selectorRealtimeSubscription?.cancel();
    _selectorRealtimeSubscription = null;
    if (_selectorRealtimeService != null) {
      await _selectorRealtimeService!.dispose();
      _selectorRealtimeService = null;
    }
  }

  String? _extractSnFromTopic(String topic) {
    final parts = topic.split('/');
    if (parts.length < 2) {
      return null;
    }
    final sn = parts.last.trim();
    if (sn.isEmpty) {
      return null;
    }
    return sn;
  }

  void _startAppMqttCommandLoop({
    required EcoFlowRealtimeService realtimeService,
    required EcoFlowBootstrapBundle bundle,
    required int sessionToken,
  }) {
    _stopAppMqttCommandLoop();
    var tick = 0;
    _appMqttCommandTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || sessionToken != _mqttSessionToken) {
        return;
      }
      tick += 1;
      _sendAppRtcTime(
        realtimeService: realtimeService,
        bundle: bundle,
        sessionToken: sessionToken,
      );
      if (tick % 3 == 0) {
        _requestAppLatestQuotas(
          realtimeService: realtimeService,
          bundle: bundle,
          sessionToken: sessionToken,
        );
      }
    });
  }

  void _stopAppMqttCommandLoop() {
    _appMqttCommandTimer?.cancel();
    _appMqttCommandTimer = null;
  }

  void _requestAppLatestQuotas({
    required EcoFlowRealtimeService realtimeService,
    required EcoFlowBootstrapBundle bundle,
    required int sessionToken,
  }) {
    if (!realtimeService.isConnected) {
      _log(
        'app_mqtt.latest_quotas.skip',
        <String, dynamic>{
          'reason': 'mqtt_disconnected',
          'sessionToken': sessionToken,
        },
      );
      return;
    }
    final userId = bundle.mqtt.userId?.trim();
    if (userId == null || userId.isEmpty) {
      _log(
        'app_mqtt.latest_quotas.skip',
        <String, dynamic>{'reason': 'missing_user_id', 'sessionToken': sessionToken},
      );
      return;
    }
    for (final device in bundle.devices) {
      final payload = jsonEncode(<String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'version': '1.1',
        'from': 'Android',
        'operateType': 'latestQuotas',
        'params': <String, dynamic>{},
      });
      final topic = '/app/$userId/${device.sn}/thing/property/get';
      try {
        realtimeService.publish(
          topic,
          payload,
          qos: MqttQosLevel.atLeastOnce,
          retain: false,
        );
        _log(
          'app_mqtt.latest_quotas.request',
          <String, dynamic>{'sessionToken': sessionToken, 'topic': topic},
        );
      } catch (error) {
        _log(
          'app_mqtt.latest_quotas.error',
          <String, dynamic>{
            'sessionToken': sessionToken,
            'topic': topic,
            'error': '$error',
          },
        );
      }
    }
  }

  void _sendAppRtcTime({
    required EcoFlowRealtimeService realtimeService,
    required EcoFlowBootstrapBundle bundle,
    required int sessionToken,
  }) {
    if (!realtimeService.isConnected) {
      _log(
        'app_mqtt.rtc_ping.skip',
        <String, dynamic>{
          'reason': 'mqtt_disconnected',
          'sessionToken': sessionToken,
        },
      );
      return;
    }
    final userId = bundle.mqtt.userId?.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final now = DateTime.now();
    for (final device in bundle.devices) {
      final payload = jsonEncode(<String, dynamic>{
        'from': 'Android',
        'id': now.millisecondsSinceEpoch.toString(),
        'moduleType': 2,
        'operateType': 'setRtcTime',
        'params': <String, dynamic>{
          'min': now.minute,
          'day': now.day,
          'week': now.weekday % 7,
          'sec': now.second,
          'month': now.month,
          'hour': now.hour,
          'year': now.year,
        },
        'version': '1.0',
      });
      final topic = '/app/$userId/${device.sn}/thing/property/set';
      try {
        realtimeService.publish(
          topic,
          payload,
          qos: MqttQosLevel.atLeastOnce,
          retain: false,
        );
        _log(
          'app_mqtt.rtc_ping.request',
          <String, dynamic>{'sessionToken': sessionToken, 'topic': topic},
        );
      } catch (error) {
        _log(
          'app_mqtt.rtc_ping.error',
          <String, dynamic>{
            'sessionToken': sessionToken,
            'topic': topic,
            'error': '$error',
          },
        );
      }
    }
  }

  void _onRealtimeHealthState(TelemetryHealthState state, int sessionToken) {
    if (!mounted || sessionToken != _mqttSessionToken) {
      return;
    }
    _log(
      'mqtt_snapshot.health',
      <String, dynamic>{
        'sessionToken': sessionToken,
        'status': state.status.name,
        'fallbackSuggested': state.fallbackSuggested,
        'message': state.message,
        'reconnectAttempt': state.reconnectAttempt,
      },
    );

    if (state.status == TelemetryHealthStatus.streaming) {
      _stopFallbackRestPolling();
      setState(() {
        _telemetryAvailable = _lastTelemetryAt != null;
        _telemetryTimedOut = false;
        _fallbackRestActive = false;
      });
      return;
    }

    if (state.fallbackSuggested ||
        state.status == TelemetryHealthStatus.stale ||
        state.status == TelemetryHealthStatus.error) {
      final usingAppMqtt = (_appMqttCertification?.channel ?? EcoFlowMqttChannel.open) ==
          EcoFlowMqttChannel.app;
      final realtimeService = _selectorRealtimeService;
      final bundle = _bundle;
      if (usingAppMqtt &&
          realtimeService != null &&
          realtimeService.isConnected &&
          bundle != null) {
        _requestAppLatestQuotas(
          realtimeService: realtimeService,
          bundle: EcoFlowBootstrapBundle(
            mqtt: _appMqttCertification ?? bundle.mqtt,
            device: bundle.device,
            devices: bundle.devices,
            certificateAccount: bundle.certificateAccount,
            mqttEndpointUsed: bundle.mqttEndpointUsed,
            deviceEndpointUsed: bundle.deviceEndpointUsed,
          ),
          sessionToken: sessionToken,
        );
      }
      if (!usingAppMqtt && !_wildcardEscalated && bundle != null) {
        _wildcardEscalated = true;
        _log(
          'mqtt_snapshot.wildcard_escalation',
          <String, dynamic>{'sessionToken': sessionToken},
        );
        unawaited(_hydrateDevicesFromMqtt(bundle));
        return;
      }
      setState(() {
        _telemetryAvailable = false;
        _telemetryTimedOut = true;
      });
      unawaited(_startFallbackRestPolling(sessionToken));
    }
  }

  Future<void> _startFallbackRestPolling(int sessionToken) async {
    if (!mounted || sessionToken != _mqttSessionToken || _fallbackRestActive) {
      return;
    }
    setState(() => _fallbackRestActive = true);
    _fallbackRestAttempt = 0;
    await _runFallbackRestPoll(sessionToken);
  }

  void _stopFallbackRestPolling({bool resetAttempt = false}) {
    _fallbackRestTimer?.cancel();
    _fallbackRestTimer = null;
    if (mounted && _fallbackRestActive) {
      setState(() => _fallbackRestActive = false);
    } else {
      _fallbackRestActive = false;
    }
    if (resetAttempt) {
      _fallbackRestAttempt = 0;
    }
  }

  void _scheduleFallbackRestPoll(int sessionToken) {
    if (!mounted || sessionToken != _mqttSessionToken || !_fallbackRestActive) {
      return;
    }
    _fallbackRestAttempt += 1;
    final exponent = _fallbackRestAttempt.clamp(0, 4).toInt();
    final delaySeconds = 3 * (1 << exponent);
    final boundedDelaySeconds = delaySeconds.clamp(3, 60).toInt();
    final delay = Duration(seconds: boundedDelaySeconds);
    _fallbackRestTimer?.cancel();
    _fallbackRestTimer = Timer(delay, () {
      unawaited(_runFallbackRestPoll(sessionToken));
    });
  }

  Future<void> _runFallbackRestPoll(int sessionToken) async {
    if (!mounted || sessionToken != _mqttSessionToken || !_fallbackRestActive) {
      return;
    }
    final service = _bootstrapService;
    final current = _bundle;
    if (service == null || current == null) {
      _scheduleFallbackRestPoll(sessionToken);
      return;
    }
    try {
      final enriched = await service.enrichDevicesWithQuota(
        credentials: widget.credentials,
        devices: current.devices,
      );
      if (!mounted || sessionToken != _mqttSessionToken) {
        return;
      }

      final updatedActive = enriched.firstWhere(
        (d) => d.sn == current.device.sn,
        orElse: () => enriched.first,
      );
      setState(() {
        _bundle = EcoFlowBootstrapBundle(
          mqtt: current.mqtt,
          device: updatedActive,
          devices: enriched,
          certificateAccount: current.certificateAccount,
          mqttEndpointUsed: current.mqttEndpointUsed,
          deviceEndpointUsed: current.deviceEndpointUsed,
        );
      });
      _seedDetailStates(enriched);
      unawaited(_refreshDeviceRawSnapshot(updatedActive.sn, silent: true));
      _log(
        'fallback_rest.success',
        <String, dynamic>{
          'sessionToken': sessionToken,
          'attempt': _fallbackRestAttempt,
          'devices': enriched.length,
        },
      );
    } catch (error) {
      _log(
        'fallback_rest.error',
        <String, dynamic>{
          'sessionToken': sessionToken,
          'attempt': _fallbackRestAttempt,
          'error': '$error',
        },
      );
    } finally {
      _scheduleFallbackRestPoll(sessionToken);
    }
  }

  void _log(String event, Map<String, dynamic> payload) {
    const mutedEvents = <String>{
      'mqtt_snapshot.health',
      'mqtt_snapshot.patch',
      'app_mqtt.latest_quotas.request',
      'app_mqtt.latest_quotas.skip',
      'app_mqtt.rtc_ping.request',
      'app_mqtt.rtc_ping.skip',
    };
    if (mutedEvents.contains(event)) {
      return;
    }
    String content;
    try {
      content = jsonEncode(payload);
    } catch (_) {
      content = payload.toString();
    }
    // ignore: avoid_print
    print('[DeviceSelectorScreen][$event] $content');
  }

  String _deviceTitle(EcoFlowDeviceIdentity device) {
    final name = device.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final model = device.model?.trim();
    if (model != null && model.isNotEmpty) {
      return model;
    }
    return 'Dispositivo ${device.sn}';
  }

  Widget _buildDeviceImage(EcoFlowDeviceIdentity device) {
    final imageUrl = device.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.battery_charging_full, size: 36),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.md,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.battery_charging_full, size: 36),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selector de Dispositivos'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignSystemTestView(),
                ),
              );
            },
            child: const Text('Test View'),
          ),
        ],
      ),
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
                  'Selecciona el dispositivo que quieres monitorear y controlar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
                    'No se pudieron cargar dispositivos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Reintentar',
                    onPressed: () {
                      _loadDevices();
                    },
                    variant: AppButtonVariant.secondary,
                  ),
                ],
              ),
            )
          else if (bundle == null)
            AppCard(
              child: Text(
                'No hay datos para mostrar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispositivos vinculados: ${bundle.devices.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_telemetryAvailable)
                    AppStatusBadge(
                      label: _lastTelemetryAt == null
                          ? 'Telemetria en vivo'
                          : 'Telemetria en vivo (${_lastTelemetryAt!.hour.toString().padLeft(2, '0')}:${_lastTelemetryAt!.minute.toString().padLeft(2, '0')}:${_lastTelemetryAt!.second.toString().padLeft(2, '0')})',
                      tone: AppStatusTone.active,
                    )
                  else if (_fallbackRestActive)
                    const AppStatusBadge(
                      label: 'Fallback REST activo',
                      tone: AppStatusTone.warning,
                    )
                  else if (_telemetryTimedOut)
                    const AppStatusBadge(
                      label: 'Sin telemetria',
                      tone: AppStatusTone.warning,
                    )
                  else
                    const AppStatusBadge(
                      label: 'Telemetria pendiente...',
                      tone: AppStatusTone.neutral,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppStatusBadge(
                    label: (_appMqttCertification?.channel ?? EcoFlowMqttChannel.open) ==
                            EcoFlowMqttChannel.app
                        ? 'Canal APP MQTT'
                        : 'Canal OPEN MQTT',
                    tone: (_appMqttCertification?.channel ?? EcoFlowMqttChannel.open) ==
                            EcoFlowMqttChannel.app
                        ? AppStatusTone.active
                        : AppStatusTone.neutral,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: _telemetryRetrying
                        ? 'Reintentando...'
                        : 'Reintentar telemetria',
                    variant: AppButtonVariant.tertiary,
                    size: AppButtonSize.small,
                    loading: _telemetryRetrying,
                    onPressed: _telemetryRetrying
                        ? null
                        : () {
                            _retryTelemetry();
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...bundle.devices.map((device) {
              final selected = _selectedSn == device.sn;
              final online = device.isOnline;
              final battery = device.batteryPercent;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  surfaceLevel: selected ? 2 : 1,
                  onTap: () {
                    unawaited(_openDeviceDetail(device));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          const Spacer(),
                          if (selected)
                            const AppStatusBadge(
                              label: 'Activo',
                              tone: AppStatusTone.active,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: _buildDeviceImage(device),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deviceTitle(device),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Modelo: ${device.model?.trim().isNotEmpty == true ? device.model : 'N/D'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SN: ${device.sn}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${(device.deviceId ?? '').trim().isNotEmpty ? device.deviceId : 'N/D'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
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
