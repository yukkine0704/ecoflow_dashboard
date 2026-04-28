import 'dart:async';

import 'bridge_models.dart';
import 'bridge_ws_client.dart';

enum BridgeConnectionStatus { disconnected, connecting, connected, error }

class BridgeConnectionState {
  const BridgeConnectionState({required this.status, this.message});

  final BridgeConnectionStatus status;
  final String? message;
}

class BridgeRepository {
  BridgeRepository({BridgeWsClient? client})
    : _client = client ?? BridgeWsClient();

  final BridgeWsClient _client;
  final Map<String, BridgeDeviceSnapshot> _devices =
      <String, BridgeDeviceSnapshot>{};

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

  List<BridgeDeviceSnapshot> get currentFleet => _sortedFleet();

  Future<void> connect(String wsUrl) async {
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
    await _client.dispose();
    await _fleetController.close();
    await _deviceController.close();
    await _connectionController.close();
    await _catalogController.close();
  }

  void _onMessage(Map<String, dynamic> rawEnvelope) {
    final envelope = BridgeEventEnvelope.fromJson(rawEnvelope);
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
      _catalogById[catalogItem.deviceId] = catalogItem;
      final current = _devices[catalogItem.deviceId];
      if (current != null) {
        _devices[catalogItem.deviceId] = current.copyWith(
          displayName: catalogItem.displayName,
          model: catalogItem.model,
          imageUrl: catalogItem.imageUrl,
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
      final current = _devices[fleetItem.deviceId];
      if (current == null) {
        _devices[fleetItem.deviceId] = BridgeDeviceSnapshot(
          deviceId: fleetItem.deviceId,
          displayName: fleetItem.displayName,
          model: fleetItem.model,
          imageUrl: null,
          online: fleetItem.online,
          batteryPercent: fleetItem.batteryPercent,
          temperatureC: null,
          totalInputW: null,
          totalOutputW: null,
          metrics: const <String, dynamic>{},
          updatedAt: fleetItem.updatedAt,
        );
      } else {
        _devices[fleetItem.deviceId] = current.copyWith(
          displayName: fleetItem.displayName,
          model: fleetItem.model,
          online: fleetItem.online,
          batteryPercent: fleetItem.batteryPercent,
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
    final snapshot = BridgeDeviceSnapshot.fromJson(normalized);
    _devices[snapshot.deviceId] = snapshot;
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
      bool? online = current.online;
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
          if (value is bool) {
            online = value;
          }
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

      final updatedAt =
          DateTime.tryParse((payload['updatedAt'] ?? '').toString()) ??
          DateTime.now();
      final next = current.copyWith(
        batteryPercent: battery,
        online: online,
        temperatureC: temperature,
        totalInputW: totalIn,
        totalOutputW: totalOut,
        metrics: nextMetrics,
        updatedAt: updatedAt,
      );
      _devices[deviceId] = next;
      _deviceController.add(next);
      _fleetController.add(_sortedFleet());
    }
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
}
