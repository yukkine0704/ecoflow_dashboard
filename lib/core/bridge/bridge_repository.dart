import 'dart:async';
import 'package:flutter/foundation.dart';

import 'bridge_history_store.dart';
import 'bridge_models.dart';
import 'bridge_ws_client.dart';

enum BridgeConnectionStatus { disconnected, connecting, connected, error }

class BridgeConnectionState {
  const BridgeConnectionState({required this.status, this.message});

  final BridgeConnectionStatus status;
  final String? message;
}

class BridgeRepository {
  BridgeRepository({BridgeWsClient? client, BridgeHistoryStore? historyStore})
    : _client = client ?? BridgeWsClient(),
      _historyStore = historyStore ?? BridgeHistoryStore();

  static const Map<String, ({String displayName, String model})>
  _directModeDeviceAliases = <String, ({String displayName, String model})>{
    'P351ZAHAPH2R2706': (displayName: 'Delta 3 Pro', model: 'Delta 3'),
    'R651ZAB5XH111262': (displayName: 'River 3', model: 'River'),
  };
  static const Set<String> _preferSocBatteryDeviceIds = <String>{
    'R651ZAB5XH111262',
  };

  final BridgeWsClient _client;
  final BridgeHistoryStore _historyStore;
  final Map<String, BridgeDeviceSnapshot> _devices =
      <String, BridgeDeviceSnapshot>{};
  final Map<String, int> _messageVersionCounters = <String, int>{};

  StreamSubscription<Map<String, dynamic>>? _messagesSub;
  StreamSubscription<Object>? _errorsSub;

  final StreamController<List<BridgeDeviceSnapshot>> _fleetController =
      StreamController<List<BridgeDeviceSnapshot>>.broadcast();
  final StreamController<BridgeDeviceSnapshot> _deviceController =
      StreamController<BridgeDeviceSnapshot>.broadcast();
  final StreamController<BridgeConnectionState> _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final StreamController<List<BridgeCatalogItem>> _catalogController =
      StreamController<List<BridgeCatalogItem>>.broadcast();
  final Map<String, BridgeCatalogItem> _catalogById =
      <String, BridgeCatalogItem>{};

  Stream<List<BridgeDeviceSnapshot>> get fleet => _fleetController.stream;
  Stream<BridgeDeviceSnapshot> get deviceUpdates => _deviceController.stream;
  Stream<BridgeConnectionState> get connection => _connectionController.stream;
  Stream<List<BridgeCatalogItem>> get catalog => _catalogController.stream;
  Stream<DeviceHistorySeries> watchHistory(String deviceId) =>
      _historyStore.watchSeries(deviceId);
  Future<DeviceHistorySeries> readHistory(String deviceId) =>
      _historyStore.readSeries(deviceId);

  List<BridgeDeviceSnapshot> get currentFleet => _sortedFleet();

  Future<void> connect(String wsUrl) async {
    await _historyStore.init();
    _connectionController.add(
      const BridgeConnectionState(
        status: BridgeConnectionStatus.connecting,
        message: 'Conectando al bridge...',
      ),
    );

    await _disposeSubscriptions();
    await _client.connect(wsUrl);

    _messagesSub = _client.messages.listen(_onMessage);
    _errorsSub = _client.errors.listen((error) {
      _connectionController.add(
        BridgeConnectionState(
          status: BridgeConnectionStatus.error,
          message: '$error',
        ),
      );
    });

    _connectionController.add(
      const BridgeConnectionState(
        status: BridgeConnectionStatus.connected,
        message: 'Bridge conectado',
      ),
    );
  }

  Future<void> disconnect() async {
    await _disposeSubscriptions();
    await _client.disconnect();
    _devices.clear();
    _catalogById.clear();
    _fleetController.add(const <BridgeDeviceSnapshot>[]);
    _catalogController.add(const <BridgeCatalogItem>[]);
    _connectionController.add(
      const BridgeConnectionState(
        status: BridgeConnectionStatus.disconnected,
        message: 'Desconectado',
      ),
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _historyStore.dispose();
    await _client.dispose();
    await _fleetController.close();
    await _deviceController.close();
    await _connectionController.close();
    await _catalogController.close();
  }

  void _onMessage(Map<String, dynamic> rawEnvelope) {
    final envelope = BridgeEventEnvelope.fromJson(rawEnvelope);
    _trackEnvelopeVersion(envelope.version);
    switch (envelope.type) {
      case BridgeEventType.fleetState:
        _handleFleetState(envelope.payload);
        break;
      case BridgeEventType.deviceSnapshot:
        _handleDeviceSnapshot(envelope.payload);
        break;
      case BridgeEventType.deviceDelta:
        _handleDeviceDelta(envelope.payload);
        break;
      case BridgeEventType.deviceCatalog:
        _handleDeviceCatalog(envelope.payload);
        break;
      case BridgeEventType.unknown:
        break;
    }
  }

  void _handleDeviceCatalog(Map<String, dynamic> payload) {
    final devicesRaw = payload['devices'];
    if (devicesRaw is! List) {
      return;
    }
    _catalogById.clear();
    for (final item in devicesRaw) {
      if (item is! Map) {
        continue;
      }
      final normalized = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final catalogItem = BridgeCatalogItem.fromJson(normalized);
      if (catalogItem.deviceId.trim().isEmpty) {
        continue;
      }
      final aliasedCatalogItem = _applyCatalogAlias(catalogItem);
      _catalogById[aliasedCatalogItem.deviceId] = aliasedCatalogItem;
      final current = _devices[catalogItem.deviceId];
      if (current != null) {
        _devices[catalogItem.deviceId] = current.copyWith(
          displayName: aliasedCatalogItem.displayName,
          model: aliasedCatalogItem.model,
          imageUrl: aliasedCatalogItem.imageUrl,
        );
      }
    }
    _catalogController.add(_sortedCatalog());
    _fleetController.add(_sortedFleet());
  }

  void _handleFleetState(Map<String, dynamic> payload) {
    final devicesRaw = payload['devices'];
    if (devicesRaw is! List) {
      return;
    }

    for (final item in devicesRaw) {
      if (item is! Map) {
        continue;
      }
      final normalized = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final fleetItem = BridgeFleetItem.fromJson(normalized);
      final alias = _directModeDeviceAliases[fleetItem.deviceId];
      final nextDisplayName = alias?.displayName ?? fleetItem.displayName;
      final nextModel = alias?.model ?? fleetItem.model;
      final nextBattery = _resolveBatteryPercent(
        deviceId: fleetItem.deviceId,
        rawBatteryPercent: fleetItem.batteryPercent,
        metrics: _devices[fleetItem.deviceId]?.metrics,
      );
      final current = _devices[fleetItem.deviceId];
      if (current == null) {
        _devices[fleetItem.deviceId] = BridgeDeviceSnapshot(
          deviceId: fleetItem.deviceId,
          displayName: nextDisplayName,
          model: nextModel,
          imageUrl: null,
          connectivity: fleetItem.connectivity,
          onlineLegacy: fleetItem.onlineLegacy,
          batteryPercent: nextBattery,
          temperatureC: null,
          totalInputW: null,
          totalOutputW: null,
          metrics: const <String, dynamic>{},
          updatedAt: fleetItem.updatedAt,
        );
      } else {
        _logConnectivityTransitionIfNeeded(
          fleetItem.deviceId,
          current.connectivity,
          fleetItem.connectivity,
          'fleet_state',
        );
        _devices[fleetItem.deviceId] = current.copyWith(
          displayName: nextDisplayName,
          model: nextModel,
          connectivity: fleetItem.connectivity,
          onlineLegacy: fleetItem.onlineLegacy,
          batteryPercent: nextBattery,
          updatedAt: fleetItem.updatedAt,
        );
      }
    }
    _fleetController.add(_sortedFleet());
  }

  void _handleDeviceSnapshot(Map<String, dynamic> payload) {
    final snapshotRaw = payload['snapshot'];
    if (snapshotRaw is! Map) {
      return;
    }

    final normalized = snapshotRaw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final parsedSnapshot = BridgeDeviceSnapshot.fromJson(normalized);
    final snapshot = _applySnapshotAlias(
      parsedSnapshot.copyWith(
        batteryPercent: _resolveBatteryPercent(
          deviceId: parsedSnapshot.deviceId,
          rawBatteryPercent: parsedSnapshot.batteryPercent,
          metrics: parsedSnapshot.metrics,
        ),
      ),
    );
    final previous = _devices[snapshot.deviceId];
    if (previous != null) {
      _logConnectivityTransitionIfNeeded(
        snapshot.deviceId,
        previous.connectivity,
        snapshot.connectivity,
        'device_snapshot',
      );
    }
    _devices[snapshot.deviceId] = snapshot;
    unawaited(_historyStore.recordSnapshot(snapshot));
    _deviceController.add(snapshot);
    _fleetController.add(_sortedFleet());
  }

  void _handleDeviceDelta(Map<String, dynamic> payload) {
    final deviceId = (payload['deviceId'] ?? '').toString();
    if (deviceId.trim().isEmpty) {
      return;
    }
    final current = _devices[deviceId];
    if (current == null) {
      return;
    }

    final changed = payload['changed'];
    if (changed is Map) {
      final nextMetrics = Map<String, dynamic>.from(current.metrics);
      int? battery = current.batteryPercent;
      bool? onlineLegacy = current.onlineLegacy;
      BridgeConnectivity? connectivity;
      double? temperature = current.temperatureC;
      double? totalIn = current.totalInputW;
      double? totalOut = current.totalOutputW;

      for (final entry in changed.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (key == 'batteryPercent') {
          battery = value is num
              ? value.round()
              : int.tryParse(value.toString());
        } else if (key == 'online') {
          onlineLegacy = _asBool(value);
        } else if (key == 'connectivity') {
          connectivity = BridgeConnectivityX.fromWire(value);
        } else if (key == 'temperatureC') {
          temperature = value is num
              ? value.toDouble()
              : double.tryParse(value.toString());
        } else if (key == 'totalInputW') {
          totalIn = value is num
              ? value.toDouble()
              : double.tryParse(value.toString());
        } else if (key == 'totalOutputW') {
          totalOut = value is num
              ? value.toDouble()
              : double.tryParse(value.toString());
        } else if (key.startsWith('metrics.')) {
          final metricKey = key.substring('metrics.'.length);
          nextMetrics[metricKey] = value;
        }
      }

      battery = _resolveBatteryPercent(
        deviceId: deviceId,
        rawBatteryPercent: battery,
        metrics: nextMetrics,
      );
      final resolvedConnectivity =
          connectivity ?? BridgeConnectivityX.fromLegacyOnline(onlineLegacy);

      final updatedAt =
          DateTime.tryParse((payload['updatedAt'] ?? '').toString()) ??
          DateTime.now();
      _logConnectivityTransitionIfNeeded(
        deviceId,
        current.connectivity,
        resolvedConnectivity,
        'device_delta',
      );
      final next = current.copyWith(
        batteryPercent: battery,
        connectivity: resolvedConnectivity,
        onlineLegacy: onlineLegacy,
        temperatureC: temperature,
        totalInputW: totalIn,
        totalOutputW: totalOut,
        metrics: nextMetrics,
        updatedAt: updatedAt,
      );
      _devices[deviceId] = next;
      unawaited(_historyStore.recordSnapshot(next));
      _deviceController.add(next);
      _fleetController.add(_sortedFleet());
    }
  }

  void _trackEnvelopeVersion(String version) {
    final nextCount = (_messageVersionCounters[version] ?? 0) + 1;
    _messageVersionCounters[version] = nextCount;
    if (nextCount == 1 || nextCount % 100 == 0) {
      debugPrint('[BridgeRepository] ws version=$version count=$nextCount');
    }
  }

  void _logConnectivityTransitionIfNeeded(
    String deviceId,
    BridgeConnectivity previous,
    BridgeConnectivity next,
    String source,
  ) {
    if (previous == next) {
      return;
    }
    debugPrint(
      '[BridgeRepository] connectivity device=$deviceId $previous -> $next source=$source',
    );
  }

  List<BridgeDeviceSnapshot> _sortedFleet() {
    final values = _devices.values.toList();
    values.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return values;
  }

  List<BridgeCatalogItem> _sortedCatalog() {
    final values = _catalogById.values.toList();
    values.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return values;
  }

  Future<void> _disposeSubscriptions() async {
    await _messagesSub?.cancel();
    await _errorsSub?.cancel();
    _messagesSub = null;
    _errorsSub = null;
  }

  BridgeDeviceSnapshot _applySnapshotAlias(BridgeDeviceSnapshot snapshot) {
    final alias = _directModeDeviceAliases[snapshot.deviceId];
    if (alias == null) {
      return snapshot;
    }
    return snapshot.copyWith(
      displayName: alias.displayName,
      model: alias.model,
    );
  }

  BridgeCatalogItem _applyCatalogAlias(BridgeCatalogItem item) {
    final alias = _directModeDeviceAliases[item.deviceId];
    if (alias == null) {
      return item;
    }
    return BridgeCatalogItem(
      deviceId: item.deviceId,
      displayName: alias.displayName,
      model: alias.model,
      imageUrl: item.imageUrl,
    );
  }

  int? _resolveBatteryPercent({
    required String deviceId,
    required int? rawBatteryPercent,
    required Map<String, dynamic>? metrics,
  }) {
    final soc = _extractSocFromMetrics(metrics);
    if (_preferSocBatteryDeviceIds.contains(deviceId) && soc != null) {
      return soc;
    }
    return rawBatteryPercent ?? soc;
  }

  int? _extractSocFromMetrics(Map<String, dynamic>? metrics) {
    if (metrics == null || metrics.isEmpty) {
      return null;
    }
    const socKeys = <String>[
      'pd.soc',
      'bms.soc',
      'pd.bmsBattSoc',
      'pd.cmsBattSoc',
    ];
    for (final key in socKeys) {
      final raw = metrics[key];
      final parsed = _asRoundedInt(raw);
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }
    return null;
  }

  int? _asRoundedInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round();
    }
    return null;
  }

  bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == 'online' ||
          normalized == 'on' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'offline' ||
          normalized == 'off' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
