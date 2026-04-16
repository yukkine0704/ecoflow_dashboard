import 'dart:async';

import 'package:mqtt5_client/mqtt5_client.dart' as m5;
import 'package:mqtt5_client/mqtt5_server_client.dart' as m5;

import 'mqtt_models.dart';
import 'mqtt_telemetry_client.dart';

class MqttV5TelemetryClient implements MqttTelemetryClient {
  MqttV5TelemetryClient(this.config)
    : _client = m5.MqttServerClient(config.host, config.clientId) {
    _client.port = config.port;
    _client.autoReconnect = config.autoReconnect;
    _client.resubscribeOnAutoReconnect = true;
    _client.keepAlivePeriod = config.keepAliveSeconds;
    _client.logging(on: false);
    _client.connectionMessage = m5.MqttConnectMessage()
        .withClientIdentifier(config.clientId)
        .startClean();
  }

  final MqttClientConfig config;
  final m5.MqttServerClient _client;
  final StreamController<MqttIncomingMessage> _messagesController =
      StreamController<MqttIncomingMessage>.broadcast();
  StreamSubscription<List<m5.MqttReceivedMessage<m5.MqttMessage>>>?
  _updatesSubscription;

  @override
  Stream<MqttIncomingMessage> get messages => _messagesController.stream;

  @override
  bool get isConnected =>
      _client.connectionStatus?.state == m5.MqttConnectionState.connected;

  @override
  Future<void> connect() async {
    await _client.connect(config.username, config.password);
    _updatesSubscription = _client.updates.listen((events) {
      for (final event in events) {
        final publish = event.payload;
        if (publish is! m5.MqttPublishMessage) {
          continue;
        }
        final payload = m5.MqttUtilities.bytesToStringAsString(
          publish.payload.message!,
        );
        _messagesController.add(
          MqttIncomingMessage(topic: event.topic ?? '', payload: payload),
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
    _client.unsubscribeStringTopic(topic);
  }

  @override
  void publish(
    String topic,
    String payload, {
    MqttQosLevel qos = MqttQosLevel.atMostOnce,
    bool retain = false,
  }) {
    final builder = m5.MqttPayloadBuilder()..addString(payload);
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

  m5.MqttQos _toQos(MqttQosLevel qos) {
    switch (qos) {
      case MqttQosLevel.atMostOnce:
        return m5.MqttQos.atMostOnce;
      case MqttQosLevel.atLeastOnce:
        return m5.MqttQos.atLeastOnce;
      case MqttQosLevel.exactlyOnce:
        return m5.MqttQos.exactlyOnce;
    }
  }
}
