import 'dart:async';

import 'package:ecoflow_dashboard/core/bridge/bridge_history_store.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_models.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_repository.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_ws_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBridgeWsClient extends BridgeWsClient {
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Object> _errorsController =
      StreamController<Object>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  @override
  Stream<Object> get errors => _errorsController.stream;

  @override
  Future<void> connect(String wsUrl) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _messagesController.close();
    await _errorsController.close();
  }

  void emit(Map<String, dynamic> message) {
    _messagesController.add(message);
  }
}

class _FakeHistoryStore extends BridgeHistoryStore {
  _FakeHistoryStore() : super(boxName: 'unused_for_fake');

  final List<BridgeDeviceSnapshot> recorded = <BridgeDeviceSnapshot>[];
  bool disposed = false;
  final StreamController<DeviceHistorySeries> _controller =
      StreamController<DeviceHistorySeries>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> recordSnapshot(BridgeDeviceSnapshot snapshot) async {
    recorded.add(snapshot);
    _controller.add(
      DeviceHistorySeries(
        deviceId: snapshot.deviceId,
        points: <DeviceHistoryPoint>[
          DeviceHistoryPoint(
            timestamp: snapshot.updatedAt,
            inputSolarW: null,
            inputAcW: null,
            inputCarW: null,
            inputDcW: null,
            inputOtherW: null,
            outputAcW: null,
            outputDcW: null,
            outputOtherW: null,
            batteryPercent: snapshot.batteryPercent,
            batteryTempC: snapshot.temperatureC,
          ),
        ],
      ),
    );
  }

  @override
  Future<DeviceHistorySeries> readSeries(String deviceId) async {
    return DeviceHistorySeries(
      deviceId: deviceId,
      points: const <DeviceHistoryPoint>[],
    );
  }

  @override
  Stream<DeviceHistorySeries> watchSeries(String deviceId) =>
      _controller.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

void main() {
  test('applies v2 connectivity over legacy online in mixed frames', () async {
    final fakeClient = _FakeBridgeWsClient();
    final historyStore = _FakeHistoryStore();
    final repo = BridgeRepository(
      client: fakeClient,
      historyStore: historyStore,
    );
    final fleetEvents = <List<BridgeDeviceSnapshot>>[];
    final fleetSub = repo.fleet.listen(fleetEvents.add);

    await repo.connect('ws://localhost:8787/ws');

    fakeClient.emit(<String, dynamic>{
      'version': 'v1',
      'event': 'fleet_state',
      'payload': <String, dynamic>{
        'devices': <Map<String, dynamic>>[
          <String, dynamic>{
            'deviceId': 'D1',
            'displayName': 'Device 1',
            'online': true,
          },
        ],
      },
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fleetEvents.last.single.connectivity, BridgeConnectivity.online);

    fakeClient.emit(<String, dynamic>{
      'version': 'v2',
      'event': 'device_delta',
      'payload': <String, dynamic>{
        'deviceId': 'D1',
        'changed': <String, dynamic>{'connectivity': 'offline', 'online': true},
      },
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fleetEvents.last.single.connectivity, BridgeConnectivity.offline);
    expect(fleetEvents.last.single.onlineLegacy, true);

    await fleetSub.cancel();
    await repo.dispose();
    expect(historyStore.disposed, isTrue);
  });

  test('records history from snapshot and delta frames', () async {
    final fakeClient = _FakeBridgeWsClient();
    final historyStore = _FakeHistoryStore();
    final repo = BridgeRepository(
      client: fakeClient,
      historyStore: historyStore,
    );

    await repo.connect('ws://localhost:8787/ws');

    fakeClient.emit(<String, dynamic>{
      'version': 'v1',
      'event': 'device_snapshot',
      'payload': <String, dynamic>{
        'snapshot': <String, dynamic>{
          'deviceId': 'D2',
          'displayName': 'Device 2',
          'online': true,
          'batteryPercent': 55,
          'updatedAt': '2026-05-01T00:00:00.000Z',
          'metrics': <String, dynamic>{'inputByType.acW': 123},
        },
      },
    });
    fakeClient.emit(<String, dynamic>{
      'version': 'v2',
      'event': 'device_delta',
      'payload': <String, dynamic>{
        'deviceId': 'D2',
        'updatedAt': '2026-05-01T00:00:35.000Z',
        'changed': <String, dynamic>{
          'batteryPercent': 57,
          'metrics.inputByType.acW': 140,
        },
      },
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(historyStore.recorded.length, 2);
    expect(historyStore.recorded.first.deviceId, 'D2');
    expect(historyStore.recorded.last.batteryPercent, 57);
    await repo.dispose();
  });
}
