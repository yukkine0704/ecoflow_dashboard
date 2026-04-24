import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_models.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_realtime_service.dart';
import 'package:ecoflow_dashboard/core/mqtt/mqtt_models.dart';
import 'package:ecoflow_dashboard/core/mqtt/mqtt_telemetry_client.dart';

void main() {
  group('EcoFlowRealtimeService resilience', () {
    test('first-message timeout emits stale health with fallback suggestion', () async {
      final clients = <_FakeMqttTelemetryClient>[];
      final service = EcoFlowRealtimeService(
        bootstrapBundle: _bundle(),
        clientFactory: (_) {
          final client = _FakeMqttTelemetryClient();
          clients.add(client);
          return client;
        },
      );
      final emitted = <TelemetryHealthState>[];
      final sub = service.health.listen(emitted.add);

      await service.connectAndSubscribe(
        preferredProtocol: MqttProtocolVersion.v311,
        firstMessageTimeout: const Duration(milliseconds: 40),
        staleTimeout: const Duration(seconds: 10),
        enableAutoReconnectBackoff: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(clients, isNotEmpty);
      expect(
        emitted.any(
          (state) =>
              state.status == TelemetryHealthStatus.stale &&
              state.fallbackSuggested,
        ),
        isTrue,
      );

      await sub.cancel();
      await service.dispose();
    });

    test('incoming message moves health state to streaming', () async {
      late _FakeMqttTelemetryClient latestClient;
      final service = EcoFlowRealtimeService(
        bootstrapBundle: _bundle(),
        clientFactory: (_) {
          latestClient = _FakeMqttTelemetryClient();
          return latestClient;
        },
      );
      final emitted = <TelemetryHealthState>[];
      final sub = service.health.listen(emitted.add);

      await service.connectAndSubscribe(
        preferredProtocol: MqttProtocolVersion.v311,
        firstMessageTimeout: const Duration(seconds: 5),
        staleTimeout: const Duration(seconds: 5),
        enableAutoReconnectBackoff: false,
      );
      latestClient.emit(
        const MqttIncomingMessage(
          topic: '/open/open-test/SN1/quota',
          payload: '{"params":{"soc":80}}',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        emitted.any((state) => state.status == TelemetryHealthStatus.streaming),
        isTrue,
      );
      await sub.cancel();
      await service.dispose();
    });
  });
}

EcoFlowBootstrapBundle _bundle() {
  const device = EcoFlowDeviceIdentity(sn: 'SN1');
  return const EcoFlowBootstrapBundle(
    mqtt: EcoFlowMqttCertification(
      host: 'mqtt.ecoflow.com',
      port: 8883,
      username: 'open-test',
      password: 'pwd',
      protocol: 'mqtts',
      useTls: true,
      certificateAccount: 'open-test',
    ),
    device: device,
    devices: <EcoFlowDeviceIdentity>[device],
    certificateAccount: 'open-test',
    mqttEndpointUsed: '/iot-open/sign/certification',
    deviceEndpointUsed: '/iot-open/sign/device/list',
  );
}

class _FakeMqttTelemetryClient implements MqttTelemetryClient {
  final StreamController<MqttIncomingMessage> _controller =
      StreamController<MqttIncomingMessage>.broadcast();
  final List<String> subscribedTopics = <String>[];
  bool _connected = false;

  @override
  Stream<MqttIncomingMessage> get messages => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  void dispose() {
    _connected = false;
    unawaited(_controller.close());
  }

  @override
  void publish(
    String topic,
    String payload, {
    MqttQosLevel qos = MqttQosLevel.atMostOnce,
    bool retain = false,
  }) {}

  @override
  void subscribe(String topic, {MqttQosLevel qos = MqttQosLevel.atMostOnce}) {
    subscribedTopics.add(topic);
  }

  @override
  void unsubscribe(String topic) {
    subscribedTopics.remove(topic);
  }

  void emit(MqttIncomingMessage message) {
    _controller.add(message);
  }
}
