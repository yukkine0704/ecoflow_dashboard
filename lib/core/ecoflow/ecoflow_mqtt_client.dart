import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'ecoflow_auth_api.dart';

class EcoFlowMqttMessage {
  const EcoFlowMqttMessage({required this.topic, required this.payload});

  final String topic;
  final Uint8List payload;
}

abstract class EcoFlowMqttClient {
  Stream<EcoFlowMqttMessage> get messages;
  Stream<Object> get errors;
  bool get isConnected;

  Future<void> connect({
    required EcoFlowMqttCertification certification,
    required String clientId,
  });

  Future<void> subscribe(String topic);
  Future<void> publishJson(String topic, Map<String, Object?> payload);
  Future<void> disconnect();
  Future<void> dispose();
}

class MqttClientEcoFlowClient implements EcoFlowMqttClient {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;
  final StreamController<EcoFlowMqttMessage> _messagesController =
      StreamController<EcoFlowMqttMessage>.broadcast();
  final StreamController<Object> _errorsController =
      StreamController<Object>.broadcast();

  @override
  Stream<EcoFlowMqttMessage> get messages => _messagesController.stream;

  @override
  Stream<Object> get errors => _errorsController.stream;

  @override
  bool get isConnected {
    return _client?.connectionStatus?.state == MqttConnectionState.connected;
  }

  @override
  Future<void> connect({
    required EcoFlowMqttCertification certification,
    required String clientId,
  }) async {
    await disconnect();
    final client = MqttServerClient.withPort(
      certification.host,
      clientId,
      certification.port,
    );
    client.secure = certification.useTls;
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);
    client.setProtocolV311();
    client.onDisconnected = () {};
    client.onAutoReconnect = () {};
    client.onAutoReconnected = () {};
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(certification.username, certification.password)
        .startClean();
    _client = client;

    try {
      await client.connect();
    } catch (error) {
      _errorsController.add(
        StateError(
          'MQTT connect error host=${certification.host} '
          'port=${certification.port} tls=${certification.useTls}: $error',
        ),
      );
      client.disconnect();
      rethrow;
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      final status = client.connectionStatus;
      throw StateError('MQTT connect failed: ${status?.returnCode}');
    }

    _updatesSub = client.updates?.listen(
      (messages) {
        for (final received in messages) {
          final payload = received.payload;
          if (payload is! MqttPublishMessage) continue;
          final bytes = Uint8List.fromList(payload.payload.message);
          _messagesController.add(
            EcoFlowMqttMessage(topic: received.topic, payload: bytes),
          );
        }
      },
      onError: _errorsController.add,
      cancelOnError: false,
    );
  }

  @override
  Future<void> subscribe(String topic) async {
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  @override
  Future<void> publishJson(String topic, Map<String, Object?> payload) async {
    final client = _client;
    if (client == null || !isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    final built = builder.payload;
    if (built == null) return;
    client.publishMessage(topic, MqttQos.atLeastOnce, built, retain: false);
  }

  @override
  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    _client?.disconnect();
    _client = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
    await _errorsController.close();
  }
}
