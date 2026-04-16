import 'mqtt_models.dart';
import 'mqtt_telemetry_client.dart';
import 'mqtt_v311_telemetry_client.dart';
import 'mqtt_v5_telemetry_client.dart';

class MqttClientFactory {
  const MqttClientFactory._();

  static MqttTelemetryClient create(MqttClientConfig config) {
    switch (config.protocol) {
      case MqttProtocolVersion.v311:
        return MqttV311TelemetryClient(config);
      case MqttProtocolVersion.v5:
        return MqttV5TelemetryClient(config);
    }
  }
}
