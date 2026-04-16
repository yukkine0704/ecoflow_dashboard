enum MqttProtocolVersion { v311, v5 }

enum MqttQosLevel { atMostOnce, atLeastOnce, exactlyOnce }

class MqttClientConfig {
  const MqttClientConfig({
    required this.host,
    required this.clientId,
    this.port = 1883,
    this.username,
    this.password,
    this.keepAliveSeconds = 30,
    this.autoReconnect = true,
    this.protocol = MqttProtocolVersion.v5,
  });

  final String host;
  final String clientId;
  final int port;
  final String? username;
  final String? password;
  final int keepAliveSeconds;
  final bool autoReconnect;
  final MqttProtocolVersion protocol;
}

class MqttIncomingMessage {
  const MqttIncomingMessage({required this.topic, required this.payload});

  final String topic;
  final String payload;
}
