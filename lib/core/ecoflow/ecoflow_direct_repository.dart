import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'device_telemetry_repository.dart';
import 'ecoflow_auth_api.dart';
import 'ecoflow_device_state_store.dart';
import 'ecoflow_history_store.dart';
import 'ecoflow_model_decoders.dart';
import 'ecoflow_models.dart';
import 'ecoflow_mqtt_client.dart';
import 'ecoflow_normalize.dart';
import 'ecoflow_payload_parser.dart';
import 'ecoflow_settings_storage.dart';
import 'ecoflow_status_tracker.dart';

class EcoFlowDirectRepository implements DeviceTelemetryRepository {
  EcoFlowDirectRepository({
    EcoFlowSettingsStorage? settingsStorage,
    EcoFlowAuthApi? api,
    EcoFlowMqttClient? mqttClient,
    EcoFlowHistoryStore? historyStore,
    EcoFlowDeviceStateStore? stateStore,
    Duration commandInterval = const Duration(seconds: 25),
    Duration statusPollInterval = const Duration(seconds: 60),
    Duration assumeOffline = const Duration(seconds: 90),
    int forceOfflineMultiplier = 3,
  }) : _settingsStorage = settingsStorage ?? EcoFlowSettingsStorage(),
       _api = api ?? EcoFlowAuthApi(),
       _mqttClient = mqttClient ?? MqttClientEcoFlowClient(),
       _historyStore = historyStore ?? EcoFlowHistoryStore(),
       _store = stateStore ?? EcoFlowDeviceStateStore(),
       _commandInterval = commandInterval,
       _statusPollInterval = statusPollInterval,
       _statusTracker = EcoFlowStatusTracker(
         assumeOffline,
         forceOfflineMultiplier,
       );

  final EcoFlowSettingsStorage _settingsStorage;
  final EcoFlowAuthApi _api;
  final EcoFlowMqttClient _mqttClient;
  final EcoFlowHistoryStore _historyStore;
  final EcoFlowDeviceStateStore _store;
  final Duration _commandInterval;
  final Duration _statusPollInterval;
  final EcoFlowStatusTracker _statusTracker;

  final StreamController<List<EcoFlowDeviceSnapshot>> _fleetController =
      StreamController<List<EcoFlowDeviceSnapshot>>.broadcast();
  final StreamController<EcoFlowDeviceSnapshot> _deviceController =
      StreamController<EcoFlowDeviceSnapshot>.broadcast();
  final StreamController<EcoFlowConnectionState> _connectionController =
      StreamController<EcoFlowConnectionState>.broadcast();
  final StreamController<List<EcoFlowCatalogItem>> _catalogController =
      StreamController<List<EcoFlowCatalogItem>>.broadcast();

  final Map<String, EcoFlowCatalogItem> _catalogById =
      <String, EcoFlowCatalogItem>{};
  final Map<String, String?> _deviceModels = <String, String?>{};

  StreamSubscription<EcoFlowMqttMessage>? _messageSub;
  StreamSubscription<Object>? _errorSub;
  Timer? _commandTimer;
  Timer? _statusPollTimer;
  EcoFlowMqttCertification? _certification;
  EcoFlowCredentials? _credentials;
  int _unknownParseCount = 0;

  @override
  Stream<List<EcoFlowDeviceSnapshot>> get fleet => _fleetController.stream;

  @override
  Stream<EcoFlowDeviceSnapshot> get deviceUpdates => _deviceController.stream;

  @override
  Stream<EcoFlowConnectionState> get connection => _connectionController.stream;

  @override
  Stream<List<EcoFlowCatalogItem>> get catalog => _catalogController.stream;

  @override
  List<EcoFlowDeviceSnapshot> get currentFleet => _sortedFleet();

  @override
  Stream<DeviceHistorySeries> watchHistory(String deviceId) {
    return _historyStore.watchSeries(deviceId);
  }

  @override
  Future<DeviceHistorySeries> readHistory(String deviceId) {
    return _historyStore.readSeries(deviceId);
  }

  @override
  Future<void> connect() async {
    await _historyStore.init();
    _connectionController.add(
      const EcoFlowConnectionState(
        status: EcoFlowConnectionStatus.connecting,
        message: 'Connecting to EcoFlow cloud...',
      ),
    );
    await _disposeSubscriptions();

    final credentials = await _settingsStorage.readCredentialsOrNull();
    if (credentials == null) {
      const state = EcoFlowConnectionState(
        status: EcoFlowConnectionStatus.error,
        message: 'EcoFlow credentials are missing.',
      );
      _connectionController.add(state);
      throw StateError(state.message ?? 'EcoFlow credentials are missing.');
    }
    _credentials = credentials;

    final certification = await _api.fetchAppMqttCertification(
      baseUrl: credentials.ecoflowBaseUrl,
      email: credentials.email,
      password: credentials.password,
    );
    _certification = certification;

    final devices = await _api.fetchOpenApiDeviceList(
      baseUrl: credentials.openApiBaseUrl,
      accessKey: credentials.openApiAccessKey,
      secretKey: credentials.openApiSecretKey,
    );
    if (devices.isEmpty) {
      throw StateError('Open API returned no EcoFlow devices.');
    }
    _setCatalog(devices);

    _messageSub = _mqttClient.messages.listen(_onMqttMessage);
    _errorSub = _mqttClient.errors.listen((error) {
      _connectionController.add(
        EcoFlowConnectionState(
          status: EcoFlowConnectionStatus.error,
          message: '$error',
        ),
      );
    });

    await _mqttClient.connect(
      certification: certification,
      clientId: 'ANDROID_${_randomId()}_${certification.userId}',
    );
    await _subscribeDeviceTopics(devices.map((device) => device.sn).toList());
    await _requestLatestQuotas();
    _startCommandLoop();
    _startStatusPollLoop();

    _connectionController.add(
      const EcoFlowConnectionState(
        status: EcoFlowConnectionStatus.connected,
        message: 'EcoFlow direct connected',
      ),
    );
    _emitFleet();
  }

  @override
  Future<void> disconnect() async {
    _commandTimer?.cancel();
    _commandTimer = null;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    await _disposeSubscriptions();
    await _mqttClient.disconnect();
    _connectionController.add(
      const EcoFlowConnectionState(
        status: EcoFlowConnectionStatus.disconnected,
        message: 'Disconnected',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _historyStore.dispose();
    await _mqttClient.dispose();
    await _api.dispose();
    await _fleetController.close();
    await _deviceController.close();
    await _connectionController.close();
    await _catalogController.close();
  }

  void _setCatalog(List<EcoFlowDeviceIdentity> devices) {
    _catalogById.clear();
    _deviceModels.clear();
    final catalog =
        devices
            .map(
              (device) => EcoFlowCatalogItem(
                deviceId: device.sn,
                displayName: device.name ?? device.model ?? device.sn,
                model: device.model,
                imageUrl: device.imageUrl,
              ),
            )
            .toList()
          ..sort((a, b) => a.deviceId.compareTo(b.deviceId));
    for (final item in catalog) {
      _catalogById[item.deviceId] = item;
      _deviceModels[item.deviceId] = item.model;
    }
    _store.setCatalog(
      catalog
          .map(
            (item) => (
              deviceId: item.deviceId,
              displayName: item.displayName,
              model: item.model,
              imageUrl: item.imageUrl,
            ),
          )
          .toList(),
    );
    _catalogController.add(_sortedCatalog());
    _emitFleet();
  }

  Future<void> _subscribeDeviceTopics(List<String> deviceIds) async {
    final userId = _certification?.userId;
    if (userId == null) return;
    final topics = <String>{};
    for (final sn in deviceIds) {
      topics.add('/app/device/property/$sn');
      topics.add('/app/$userId/$sn/thing/property/get_reply');
      topics.add('/app/$userId/$sn/thing/property/set_reply');
    }
    for (final topic in topics) {
      await _mqttClient.subscribe(topic);
    }
  }

  void _startCommandLoop() {
    _commandTimer?.cancel();
    _commandTimer = Timer.periodic(_commandInterval, (_) {
      unawaited(_requestLatestQuotas());
    });
  }

  void _startStatusPollLoop() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) {
      unawaited(_pollUncertainStatuses());
    });
  }

  Future<void> _requestLatestQuotas() async {
    final userId = _certification?.userId;
    if (userId == null) return;
    for (final sn in _catalogById.keys) {
      await _mqttClient
          .publishJson('/app/$userId/$sn/thing/property/get', <String, Object?>{
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'version': '1.1',
            'from': 'Android',
            'operateType': 'latestQuotas',
            'params': <String, Object?>{},
          });
    }
  }

  Future<void> _pollUncertainStatuses() async {
    final credentials = _credentials;
    if (credentials == null) return;
    final needsPoll = _catalogById.keys
        .where((sn) => _statusTracker.wantsStatusPoll(sn))
        .toList();
    if (needsPoll.isEmpty) return;
    try {
      final map = await _api.fetchOpenApiDeviceStatusMap(
        baseUrl: credentials.openApiBaseUrl,
        accessKey: credentials.openApiAccessKey,
        secretKey: credentials.openApiSecretKey,
      );
      for (final sn in needsPoll) {
        final online = map[sn];
        if (online == null) continue;
        _statusTracker.onExplicitStatus(sn, online);
        final delta = _store.upsertConnectivity(sn, _statusTracker.state(sn));
        _emitSnapshotFromDelta(sn, delta.changed);
      }
    } catch (error) {
      debugPrint('[EcoFlowDirectRepository][status-poll] $error');
      _connectionController.add(
        EcoFlowConnectionState(
          status: EcoFlowConnectionStatus.connected,
          message: 'Status poll failed; using MQTT inferred state.',
        ),
      );
    }
  }

  void _onMqttMessage(EcoFlowMqttMessage message) {
    final sn = _extractSnFromTopic(message.topic, _certification?.userId ?? '');
    if (sn == null) return;
    if (_isPresenceTopic(message.topic)) {
      _statusTracker.onDataReceived(sn);
    }
    final parsed = parseEcoFlowPayload(message.payload);
    final params = parsed.params == null
        ? null
        : decodeModelTelemetry(
            parsed.params!,
            DecoderContext(model: _deviceModels[sn], envelope: parsed.envelope),
          );
    if (params == null || params.isEmpty) {
      final previous = _store.getSnapshot(sn)?.connectivity;
      final next = _statusTracker.state(sn);
      if (previous != next) {
        final delta = _store.upsertConnectivity(sn, next);
        _emitSnapshotFromDelta(sn, delta.changed);
      }
      _unknownParseCount += 1;
      if (!_isBenignUnknownFrame(message.topic, parsed.debug) &&
          (_unknownParseCount <= 20 || _unknownParseCount % 50 == 0)) {
        debugPrint(
          '[EcoFlowDirectRepository][mqtt] unparsed($_unknownParseCount) '
          'topic=${message.topic} mode=${parsed.debug.mode} '
          'preview=${parsed.debug.preview} hex=${parsed.debug.hex}',
        );
      }
      return;
    }

    final changed = <String, Object?>{};
    final connectivityDelta = _store.upsertConnectivity(
      sn,
      _statusTracker.state(sn),
    );
    changed.addAll(connectivityDelta.changed);
    final flatParams = _flattenParams(params);
    for (final entry in flatParams.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      var channel = 'raw';
      var state = key;
      if (key.contains('.')) {
        final parts = key.split('.');
        channel = parts.first.isEmpty ? 'raw' : parts.first;
        state = parts.skip(1).join('.');
        if (state.isEmpty) state = key;
      } else if (key == 'soc' || key == 'batterySoc') {
        channel = 'pd';
        state = 'soc';
      } else if (key == 'inPower') {
        channel = 'pd';
        state = 'inputWatts';
      } else if (key == 'outPower') {
        channel = 'pd';
        state = 'outputWatts';
      } else if (key == 'temp') {
        channel = 'pd';
        state = 'temp';
      }

      final rawDelta = _store.upsertRawMetric(sn, channel, state, entry.value);
      changed.addAll(rawDelta.changed);
      final canonical = canonicalizeMetric(channel, state);
      final delta = _store.upsertMetric(
        sn,
        canonical.channel,
        canonical.state,
        entry.value,
      );
      changed.addAll(delta.changed);
    }

    final online = _toBool(
      params['status'] ?? params['online'] ?? params['isOnline'],
    );
    if (online != null) {
      _statusTracker.onExplicitStatus(sn, online);
      final statusDelta = _store.upsertConnectivity(
        sn,
        _statusTracker.state(sn),
      );
      changed.addAll(statusDelta.changed);
    } else {
      final statusDelta = _store.upsertConnectivity(
        sn,
        _statusTracker.state(sn),
      );
      changed.addAll(statusDelta.changed);
    }
    _emitSnapshotFromDelta(sn, changed);
  }

  void _emitSnapshotFromDelta(String deviceId, Map<String, Object?> changed) {
    if (changed.isEmpty) return;
    final snapshot = _store.getSnapshot(deviceId);
    if (snapshot == null) return;
    unawaited(_historyStore.recordSnapshot(snapshot));
    _deviceController.add(snapshot);
    _emitFleet();
  }

  Map<String, Object?> _flattenParams(Map<String, dynamic> input) {
    final out = <String, Object?>{};
    void push(String key, Object? value) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) return;
      if (value == null || value is num || value is bool || value is String) {
        out[normalizedKey] = value;
        return;
      }
      if (value is List) {
        out[normalizedKey] = value.toString();
        return;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          push('$normalizedKey.${entry.key}', entry.value);
        }
      }
    }

    for (final entry in input.entries) {
      push(entry.key, entry.value);
    }
    return out;
  }

  bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (const <String>['1', 'true', 'online', 'on'].contains(normalized)) {
        return true;
      }
      if (const <String>['0', 'false', 'offline', 'off'].contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  String? _extractSnFromTopic(String topic, String userId) {
    final parts = topic.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 4 &&
        parts[0] == 'app' &&
        parts[1] == 'device' &&
        parts[2] == 'property') {
      return parts[3];
    }
    if (parts.length >= 5 && parts[0] == 'app' && parts[1] == userId) {
      return parts[2];
    }
    return null;
  }

  bool _isPresenceTopic(String topic) {
    return topic.startsWith('/app/device/property/') ||
        topic.endsWith('/thing/property/get_reply') ||
        topic.endsWith('/thing/property/set_reply');
  }

  bool _isBenignUnknownFrame(String topic, EcoFlowPayloadDebug debug) {
    return topic.endsWith('/thing/property/get_reply') &&
            debug.hex == '0a05b201022d32' ||
        debug.mode.startsWith('encrypted-unknown(cmdFunc=254,cmdId=22');
  }

  List<EcoFlowDeviceSnapshot> _sortedFleet() {
    final values = _store.getFleetState();
    values.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return values;
  }

  List<EcoFlowCatalogItem> _sortedCatalog() {
    final values = _catalogById.values.toList();
    values.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return values;
  }

  void _emitFleet() {
    _fleetController.add(_sortedFleet());
  }

  Future<void> _disposeSubscriptions() async {
    await _messageSub?.cancel();
    await _errorSub?.cancel();
    _messageSub = null;
    _errorSub = null;
  }

  String _randomId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
