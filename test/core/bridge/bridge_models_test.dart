import 'package:ecoflow_dashboard/core/bridge/bridge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses fleet state envelope', () {
    final envelope = BridgeEventEnvelope.fromJson(<String, dynamic>{
      'version': 'v1',
      'event': 'fleet_state',
      'payload': <String, dynamic>{
        'devices': <Map<String, dynamic>>[
          <String, dynamic>{
            'deviceId': 'HW51TEST',
            'displayName': 'River',
            'online': true,
            'batteryPercent': 84,
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      },
    });

    expect(envelope.version, 'v1');
    expect(envelope.type, BridgeEventType.fleetState);
    expect((envelope.payload['devices'] as List).length, 1);
  });

  test('parses device snapshot payload', () {
    final snapshot = BridgeDeviceSnapshot.fromJson(<String, dynamic>{
      'deviceId': 'HW51TEST',
      'displayName': 'River 3',
      'online': 'online',
      'batteryPercent': '67',
      'temperatureC': '24.5',
      'totalInputW': 120,
      'totalOutputW': 45.5,
      'metrics': <String, dynamic>{'pd.soc': 67},
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });

    expect(snapshot.deviceId, 'HW51TEST');
    expect(snapshot.online, true);
    expect(snapshot.batteryPercent, 67);
    expect(snapshot.temperatureC, 24.5);
    expect(snapshot.totalInputW, 120);
    expect(snapshot.totalOutputW, 45.5);
    expect(snapshot.metrics['pd.soc'], 67);
  });
}
