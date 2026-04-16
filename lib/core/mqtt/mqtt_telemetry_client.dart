import 'mqtt_models.dart';

abstract class MqttTelemetryClient {
  Stream<MqttIncomingMessage> get messages;

  bool get isConnected;

  Future<void> connect();

  void disconnect();

  void subscribe(String topic, {MqttQosLevel qos = MqttQosLevel.atMostOnce});

  void unsubscribe(String topic);

  void publish(
    String topic,
    String payload, {
    MqttQosLevel qos = MqttQosLevel.atMostOnce,
    bool retain = false,
  });

  void dispose();
}
