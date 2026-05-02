import 'dart:async';

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

void main() {
  test('applies v2 connectivity over legacy online in mixed frames', () async {
    final fakeClient = _FakeBridgeWsClient();
    final repo = BridgeRepository(client: fakeClient);
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
        'changed': <String, dynamic>{
          'connectivity': 'offline',
          'online': true,
        },
      },
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fleetEvents.last.single.connectivity, BridgeConnectivity.offline);
    expect(fleetEvents.last.single.onlineLegacy, true);

    await fleetSub.cancel();
    await repo.dispose();
  });
}

