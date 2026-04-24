import 'dart:async';
import 'dart:convert';

import 'package:mqtt5_client/mqtt5_client.dart' as m5;
import 'package:mqtt5_client/mqtt5_server_client.dart' as m5;

import 'mqtt_models.dart';
import 'mqtt_telemetry_client.dart';

class MqttV5TelemetryClient implements MqttTelemetryClient {
  MqttV5TelemetryClient(this.config)
    : _client = m5.MqttServerClient(config.host, config.clientId) {
    _client.port = config.port;
    _setSecureIfSupported(config.useTls);
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
    _log('connect.request', <String, dynamic>{
      'host': config.host,
      'port': config.port,
      'clientId': config.clientId,
      'useTls': config.useTls,
    });
    await _client.connect(config.username, config.password);
    _log('connect.result', <String, dynamic>{'isConnected': isConnected});
    _updatesSubscription = _client.updates.listen(
      (events) {
        for (final event in events) {
          final publish = event.payload;
          if (publish is! m5.MqttPublishMessage) {
            continue;
          }
          final rawBytes = List<int>.from(publish.payload.message ?? const <int>[]);
          final payload = _safeUtf8(rawBytes);
          _messagesController.add(
            MqttIncomingMessage(
              topic: event.topic ?? '',
              payload: payload,
              rawPayloadBytes: rawBytes,
            ),
          );
          _log(
            'message.in',
            <String, dynamic>{
              'topic': event.topic ?? '',
              'payloadLength': rawBytes.length,
              'payloadPreviewHex': _hexPreview(rawBytes),
              'payload': payload,
            },
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _log('updates.error', <String, dynamic>{'error': '$error'});
      },
      onDone: () {
        _log('updates.done', <String, dynamic>{'clientId': config.clientId});
      },
      cancelOnError: false,
    );
  }

  @override
  void disconnect() {
    _log('disconnect', <String, dynamic>{'clientId': config.clientId});
    _client.disconnect();
  }

  @override
  void subscribe(String topic, {MqttQosLevel qos = MqttQosLevel.atMostOnce}) {
    _log('subscribe', <String, dynamic>{'topic': topic, 'qos': qos.name});
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
    _log(
      'publish',
      <String, dynamic>{
        'topic': topic,
        'payload': payload,
        'qos': qos.name,
        'retain': retain,
      },
    );
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

  void _setSecureIfSupported(bool useTls) {
    try {
      final dynamic dynamicClient = _client;
      dynamicClient.secure = useTls;
    } catch (_) {
      // Some client builds may not expose `secure`; ignore gracefully.
    }
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

  void _log(String event, Map<String, dynamic> payload) {
    const mutedEvents = <String>{'message.in', 'publish'};
    if (mutedEvents.contains(event)) {
      return;
    }
    // ignore: avoid_print
    print('[MqttV5TelemetryClient][$event] $payload');
  }

  String _safeUtf8(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }

  String _hexPreview(List<int> bytes, {int limit = 32}) {
    final max = bytes.length < limit ? bytes.length : limit;
    final view = bytes.take(max);
    return view
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
