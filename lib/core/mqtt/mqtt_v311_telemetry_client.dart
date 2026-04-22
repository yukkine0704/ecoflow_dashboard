import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart' as m3;
import 'package:mqtt_client/mqtt_server_client.dart' as m3;

import 'mqtt_models.dart';
import 'mqtt_telemetry_client.dart';

class MqttV311TelemetryClient implements MqttTelemetryClient {
  MqttV311TelemetryClient(this.config)
    : _client = m3.MqttServerClient(config.host, config.clientId) {
    _client.port = config.port;
    _setSecureIfSupported(config.useTls);
    _client.autoReconnect = config.autoReconnect;
    _client.resubscribeOnAutoReconnect = true;
    _client.keepAlivePeriod = config.keepAliveSeconds;
    _client.setProtocolV311();
    _client.logging(on: false);
    _client.connectionMessage = m3.MqttConnectMessage()
        .withClientIdentifier(config.clientId)
        .startClean();
  }

  final MqttClientConfig config;
  final m3.MqttServerClient _client;
  final StreamController<MqttIncomingMessage> _messagesController =
      StreamController<MqttIncomingMessage>.broadcast();
  StreamSubscription<List<m3.MqttReceivedMessage<m3.MqttMessage>>>?
  _updatesSubscription;

  @override
  Stream<MqttIncomingMessage> get messages => _messagesController.stream;

  @override
  bool get isConnected =>
      _client.connectionStatus?.state == m3.MqttConnectionState.connected;

  @override
  Future<void> connect() async {
    await _client.connect(config.username, config.password);
    _updatesSubscription = _client.updates?.listen((events) {
      for (final event in events) {
        final publish = event.payload;
        if (publish is! m3.MqttPublishMessage) {
          continue;
        }
        final payload = m3.MqttPublishPayload.bytesToStringAsString(
          publish.payload.message,
        );
        _messagesController.add(
          MqttIncomingMessage(topic: event.topic, payload: payload),
        );
      }
    });
  }

  @override
  void disconnect() {
    _client.disconnect();
  }

  @override
  void subscribe(String topic, {MqttQosLevel qos = MqttQosLevel.atMostOnce}) {
    _client.subscribe(topic, _toQos(qos));
  }

  @override
  void unsubscribe(String topic) {
    _client.unsubscribe(topic);
  }

  @override
  void publish(
    String topic,
    String payload, {
    MqttQosLevel qos = MqttQosLevel.atMostOnce,
    bool retain = false,
  }) {
    final builder = m3.MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(
      topic,
      _toQos(qos),
      builder.payload!,
      retain: retain,
    );
  }

  @override
  void dispose() {
    unawaited(_updatesSubscription?.cancel());
    disconnect();
    unawaited(_messagesController.close());
  }

  void _setSecureIfSupported(bool useTls) {
    try {
      final dynamic dynamicClient = _client;
      dynamicClient.secure = useTls;
    } catch (_) {
      // Some client builds may not expose `secure`; ignore gracefully.
    }
  }

  m3.MqttQos _toQos(MqttQosLevel qos) {
    switch (qos) {
      case MqttQosLevel.atMostOnce:
        return m3.MqttQos.atMostOnce;
      case MqttQosLevel.atLeastOnce:
        return m3.MqttQos.atLeastOnce;
      case MqttQosLevel.exactlyOnce:
        return m3.MqttQos.exactlyOnce;
    }
  }
}
