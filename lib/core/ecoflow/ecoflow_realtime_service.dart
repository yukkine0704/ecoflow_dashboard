import 'dart:async';

import '../mqtt/mqtt_client_factory.dart';
import '../mqtt/mqtt_models.dart';
import '../mqtt/mqtt_telemetry_client.dart';
import 'ecoflow_models.dart';

class EcoFlowRealtimeService {
  EcoFlowRealtimeService({required EcoFlowBootstrapBundle bootstrapBundle})
      : _bootstrapBundle = bootstrapBundle;

  final EcoFlowBootstrapBundle _bootstrapBundle;
  final StreamController<MqttIncomingMessage> _messagesController =
      StreamController<MqttIncomingMessage>.broadcast();

  MqttTelemetryClient? _client;
  StreamSubscription<MqttIncomingMessage>? _messagesSubscription;

  String? _activeProtocol;
  String? _attemptedProtocol;

  Stream<MqttIncomingMessage> get messages => _messagesController.stream;

  String? get activeProtocol => _activeProtocol;

  String? get attemptedProtocol => _attemptedProtocol;

  bool get isConnected => _client?.isConnected ?? false;

  Future<void> connectAndSubscribe({
    MqttProtocolVersion? preferredProtocol,
    bool includeWildcardTopic = true,
  }) async {
    await _disposeClient();

    final topics = [
      _bootstrapBundle.quotaTopic,
      _bootstrapBundle.statusTopic,
      if (includeWildcardTopic) _bootstrapBundle.wildcardTopic,
    ];
    final uniqueTopics = topics.toSet().toList();

    final protocols = preferredProtocol == null
        ? const [MqttProtocolVersion.v5, MqttProtocolVersion.v311]
        : [preferredProtocol];

    Object? lastError;
    for (final protocol in protocols) {
      try {
        _attemptedProtocol =
            protocol == MqttProtocolVersion.v5 ? 'v5' : 'v3.1.1';
        await _connectWithProtocol(
          protocol: protocol,
          topics: uniqueTopics,
        );
        _activeProtocol = _attemptedProtocol;
        return;
      } catch (error) {
        lastError = error;
        await _disposeClient();
      }
    }

    throw Exception(
      'No se logró conectar MQTT (${protocols.map((e) => e.name).join(', ')}). '
      'Último error: $lastError',
    );
  }

  Future<void> _connectWithProtocol({
    required MqttProtocolVersion protocol,
    required List<String> topics,
  }) async {
    final client = MqttClientFactory.create(
      MqttClientConfig(
        host: _bootstrapBundle.mqtt.host,
        port: _bootstrapBundle.mqtt.port,
        clientId:
            'ecoflow_diag_${DateTime.now().millisecondsSinceEpoch}_${protocol.name}',
        username: _bootstrapBundle.mqtt.username,
        password: _bootstrapBundle.mqtt.password,
        useTls: _bootstrapBundle.mqtt.useTls,
        protocol: protocol,
      ),
    );

    await client.connect();
    if (!client.isConnected) {
      client.dispose();
      throw Exception('Broker rechazó conexión MQTT (${protocol.name}).');
    }

    for (final topic in topics) {
      client.subscribe(topic, qos: MqttQosLevel.atLeastOnce);
    }

    _client = client;
    _messagesSubscription = client.messages.listen(_messagesController.add);
  }

  Future<void> disconnect() async {
    await _disposeClient();
    _activeProtocol = null;
  }

  Future<void> _disposeClient() async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _client?.dispose();
    _client = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
  }
}
