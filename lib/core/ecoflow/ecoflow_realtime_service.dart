import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../mqtt/mqtt_client_factory.dart';
import '../mqtt/mqtt_models.dart';
import '../mqtt/mqtt_telemetry_client.dart';
import 'ecoflow_models.dart';

typedef MqttTelemetryClientFactoryFn = MqttTelemetryClient Function(
  MqttClientConfig config,
);

enum TelemetryHealthStatus {
  idle,
  connecting,
  streaming,
  stale,
  reconnecting,
  disconnected,
  error,
}

class TelemetryHealthState {
  const TelemetryHealthState({
    required this.status,
    required this.connectionSessionId,
    this.message,
    this.lastMessageAt,
    this.reconnectAttempt = 0,
    this.fallbackSuggested = false,
  });

  final TelemetryHealthStatus status;
  final String? connectionSessionId;
  final String? message;
  final DateTime? lastMessageAt;
  final int reconnectAttempt;
  final bool fallbackSuggested;

  TelemetryHealthState copyWith({
    TelemetryHealthStatus? status,
    String? connectionSessionId,
    String? message,
    DateTime? lastMessageAt,
    int? reconnectAttempt,
    bool? fallbackSuggested,
  }) {
    return TelemetryHealthState(
      status: status ?? this.status,
      connectionSessionId: connectionSessionId ?? this.connectionSessionId,
      message: message ?? this.message,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      fallbackSuggested: fallbackSuggested ?? this.fallbackSuggested,
    );
  }
}

class EcoFlowRealtimeService {
  EcoFlowRealtimeService({
    required EcoFlowBootstrapBundle bootstrapBundle,
    MqttTelemetryClientFactoryFn? clientFactory,
  }) : _bootstrapBundle = bootstrapBundle,
       _clientFactory = clientFactory ?? MqttClientFactory.create;

  final EcoFlowBootstrapBundle _bootstrapBundle;
  final MqttTelemetryClientFactoryFn _clientFactory;
  final StreamController<MqttIncomingMessage> _messagesController =
      StreamController<MqttIncomingMessage>.broadcast();
  final StreamController<TelemetryHealthState> _healthController =
      StreamController<TelemetryHealthState>.broadcast();
  final Random _random = Random();

  MqttTelemetryClient? _client;
  StreamSubscription<MqttIncomingMessage>? _messagesSubscription;

  String? _activeProtocol;
  String? _attemptedProtocol;
  String? _connectionSessionId;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;

  Timer? _firstMessageTimer;
  Timer? _staleTimer;
  Timer? _reconnectTimer;
  DateTime? _lastMessageAt;

  MqttProtocolVersion? _preferredProtocol;
  bool _includeSetReplyTopic = true;
  bool _includeWildcardTopic = false;
  bool _includeDefaultTopics = true;
  List<String> _additionalTopics = const [];
  Duration _firstMessageTimeout = const Duration(seconds: 18);
  Duration _staleTimeout = const Duration(seconds: 90);
  bool _enableAutoReconnectBackoff = true;

  TelemetryHealthState _healthState = const TelemetryHealthState(
    status: TelemetryHealthStatus.idle,
    connectionSessionId: null,
  );

  Stream<MqttIncomingMessage> get messages => _messagesController.stream;

  Stream<TelemetryHealthState> get health => _healthController.stream;

  TelemetryHealthState get currentHealth => _healthState;

  String? get activeProtocol => _activeProtocol;

  String? get attemptedProtocol => _attemptedProtocol;

  bool get isConnected => _client?.isConnected ?? false;

  Future<void> connectAndSubscribe({
    MqttProtocolVersion? preferredProtocol,
    bool includeDefaultTopics = true,
    bool includeSetReplyTopic = true,
    bool includeWildcardTopic = false,
    List<String> additionalTopics = const [],
    Duration firstMessageTimeout = const Duration(seconds: 18),
    Duration staleTimeout = const Duration(seconds: 90),
    bool enableAutoReconnectBackoff = true,
    String? connectionSessionId,
  }) async {
    _preferredProtocol = preferredProtocol;
    _includeDefaultTopics = includeDefaultTopics;
    _includeSetReplyTopic = includeSetReplyTopic;
    _includeWildcardTopic = includeWildcardTopic;
    _additionalTopics = List<String>.from(additionalTopics);
    _firstMessageTimeout = firstMessageTimeout;
    _staleTimeout = staleTimeout;
    _enableAutoReconnectBackoff = enableAutoReconnectBackoff;
    _connectionSessionId =
        connectionSessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}';
    _connectionGeneration += 1;
    final generation = _connectionGeneration;
    _reconnectAttempt = 0;

    await _cancelTimers();
    await _disposeClient();
    _emitHealth(
      TelemetryHealthStatus.connecting,
      message: 'Conectando a MQTT...',
      fallbackSuggested: false,
      reconnectAttempt: _reconnectAttempt,
    );

    final topics = _resolveTopics();
    _log(
      'connect_and_subscribe.start',
      <String, dynamic>{
        'topics': topics,
        'preferredProtocol': preferredProtocol?.name,
        'firstMessageTimeoutMs': firstMessageTimeout.inMilliseconds,
        'staleTimeoutMs': staleTimeout.inMilliseconds,
        'enableAutoReconnectBackoff': enableAutoReconnectBackoff,
        'connectionSessionId': _connectionSessionId,
      },
    );

    await _connectWithFallbackProtocols(generation: generation, topics: topics);
  }

  Future<void> disconnect() async {
    _log('disconnect', <String, dynamic>{'activeProtocol': _activeProtocol});
    _connectionGeneration += 1;
    await _cancelTimers();
    await _disposeClient();
    _activeProtocol = null;
    _emitHealth(
      TelemetryHealthStatus.disconnected,
      message: 'Conexión MQTT cerrada.',
      fallbackSuggested: false,
      reconnectAttempt: _reconnectAttempt,
    );
  }

  void publish(
    String topic,
    String payload, {
    MqttQosLevel qos = MqttQosLevel.atLeastOnce,
    bool retain = false,
  }) {
    final client = _client;
    if (client == null || !client.isConnected) {
      throw Exception('MQTT no está conectado para publicar.');
    }
    client.publish(topic, payload, qos: qos, retain: retain);
    _log(
      'mqtt.publish',
      <String, dynamic>{
        'topic': topic,
        'qos': qos.name,
        'retain': retain,
      },
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _healthController.close();
    await _messagesController.close();
  }

  List<String> _resolveTopics() {
    final topics = <String>[
      if (_includeDefaultTopics)
        ..._bootstrapBundle.topicsForDeviceSn(
          _bootstrapBundle.device.sn,
          includeSetReply: _includeSetReplyTopic,
          includeWildcard: _includeWildcardTopic,
        ),
      ..._additionalTopics,
    ];
    return topics.toSet().toList();
  }

  Future<void> _connectWithFallbackProtocols({
    required int generation,
    required List<String> topics,
  }) async {
    if (generation != _connectionGeneration) {
      return;
    }
    final protocols = _preferredProtocol == null
        ? const [MqttProtocolVersion.v5, MqttProtocolVersion.v311]
        : [_preferredProtocol!];

    Object? lastError;
    for (final protocol in protocols) {
      try {
        _attemptedProtocol =
            protocol == MqttProtocolVersion.v5 ? 'v5' : 'v3.1.1';
        _log(
          'connect.protocol.try',
          <String, dynamic>{'protocol': _attemptedProtocol},
        );
        await _connectWithProtocol(
          generation: generation,
          protocol: protocol,
          topics: topics,
        );
        if (generation != _connectionGeneration) {
          return;
        }
        _activeProtocol = _attemptedProtocol;
        _emitHealth(
          TelemetryHealthStatus.connecting,
          message: 'MQTT conectado, esperando primera telemetría.',
          fallbackSuggested: false,
          reconnectAttempt: _reconnectAttempt,
        );
        _armFirstMessageTimer(generation);
        _log(
          'connect.protocol.success',
          <String, dynamic>{'protocol': _activeProtocol},
        );
        return;
      } catch (error) {
        _log(
          'connect.protocol.error',
          <String, dynamic>{
            'protocol': _attemptedProtocol,
            'error': '$error',
            'connectionSessionId': _connectionSessionId,
          },
        );
        lastError = error;
        await _disposeClient();
      }
    }

    _emitHealth(
      TelemetryHealthStatus.error,
      message: 'No se pudo conectar MQTT: $lastError',
      fallbackSuggested: true,
      reconnectAttempt: _reconnectAttempt,
    );
    if (_enableAutoReconnectBackoff) {
      _scheduleReconnect(generation, reason: 'connection_failed');
    } else {
      throw Exception(
        'No se logró conectar MQTT (${protocols.map((e) => e.name).join(', ')}). '
        'Último error: $lastError',
      );
    }
  }

  Future<void> _connectWithProtocol({
    required int generation,
    required MqttProtocolVersion protocol,
    required List<String> topics,
  }) async {
    final client = _clientFactory(
      MqttClientConfig(
        host: _bootstrapBundle.mqtt.host,
        port: _bootstrapBundle.mqtt.port,
        clientId: _buildClientId(protocol),
        username: _bootstrapBundle.mqtt.username,
        password: _bootstrapBundle.mqtt.password,
        useTls: _bootstrapBundle.mqtt.useTls,
        protocol: protocol,
      ),
    );

    await client.connect();
    if (generation != _connectionGeneration) {
      client.dispose();
      return;
    }
    _log(
      'mqtt.connect.result',
      <String, dynamic>{
        'protocol': protocol.name,
        'isConnected': client.isConnected,
        'host': _bootstrapBundle.mqtt.host,
        'port': _bootstrapBundle.mqtt.port,
      },
    );
    if (!client.isConnected) {
      client.dispose();
      throw Exception('Broker rechazó conexión MQTT (${protocol.name}).');
    }

    for (final topic in topics) {
      client.subscribe(topic, qos: MqttQosLevel.atLeastOnce);
      _log(
        'mqtt.subscribe',
        <String, dynamic>{'protocol': protocol.name, 'topic': topic},
      );
    }

    _client = client;
    await _messagesSubscription?.cancel();
    _messagesSubscription = client.messages.listen((message) {
      if (generation != _connectionGeneration) {
        return;
      }
      final hasUsefulPayload =
          (message.rawPayloadBytes?.isNotEmpty ?? false) ||
          message.payload.trim().isNotEmpty;
      if (hasUsefulPayload) {
        _lastMessageAt = DateTime.now();
        _cancelFirstMessageTimer();
        _armStaleTimer(generation);
        _emitHealth(
          TelemetryHealthStatus.streaming,
          message: 'Streaming MQTT activo.',
          lastMessageAt: _lastMessageAt,
          fallbackSuggested: false,
          reconnectAttempt: _reconnectAttempt,
        );
      }
      _log(
        'mqtt.message',
        <String, dynamic>{
          'topic': message.topic,
          'rawPayloadLength': message.rawPayloadBytes?.length ?? 0,
          'payload': _toPayloadObject(message.payload),
        },
      );
      _messagesController.add(message);
    });
  }

  void _armFirstMessageTimer(int generation) {
    _cancelFirstMessageTimer();
    _firstMessageTimer = Timer(_firstMessageTimeout, () {
      if (generation != _connectionGeneration) {
        return;
      }
      _emitHealth(
        TelemetryHealthStatus.stale,
        message: 'Timeout esperando primera telemetría MQTT.',
        fallbackSuggested: true,
        reconnectAttempt: _reconnectAttempt,
      );
      if (_enableAutoReconnectBackoff) {
        _scheduleReconnect(generation, reason: 'first_message_timeout');
      }
    });
  }

  void _armStaleTimer(int generation) {
    _staleTimer?.cancel();
    _staleTimer = Timer(_staleTimeout, () {
      if (generation != _connectionGeneration) {
        return;
      }
      _emitHealth(
        TelemetryHealthStatus.stale,
        message: 'Flujo MQTT inactivo (stale).',
        lastMessageAt: _lastMessageAt,
        fallbackSuggested: true,
        reconnectAttempt: _reconnectAttempt,
      );
      if (_enableAutoReconnectBackoff) {
        _scheduleReconnect(generation, reason: 'stale_timeout');
      }
    });
  }

  void _scheduleReconnect(int generation, {required String reason}) {
    if (generation != _connectionGeneration) {
      return;
    }
    _reconnectAttempt += 1;
    final exponent = min(_reconnectAttempt, 5);
    final backoffSeconds = min(60, 2 << exponent);
    final jitterMs = _random.nextInt(750);
    final delay = Duration(seconds: backoffSeconds) + Duration(milliseconds: jitterMs);
    _reconnectTimer?.cancel();
    _emitHealth(
      TelemetryHealthStatus.reconnecting,
      message: 'Reintentando conexión MQTT ($reason)...',
      fallbackSuggested: true,
      reconnectAttempt: _reconnectAttempt,
      lastMessageAt: _lastMessageAt,
    );
    _log(
      'reconnect.schedule',
      <String, dynamic>{
        'reason': reason,
        'attempt': _reconnectAttempt,
        'delayMs': delay.inMilliseconds,
      },
    );
    _reconnectTimer = Timer(delay, () async {
      if (generation != _connectionGeneration) {
        return;
      }
      await _disposeClient();
      await _connectWithFallbackProtocols(
        generation: generation,
        topics: _resolveTopics(),
      );
    });
  }

  void _emitHealth(
    TelemetryHealthStatus status, {
    String? message,
    DateTime? lastMessageAt,
    required bool fallbackSuggested,
    required int reconnectAttempt,
  }) {
    _healthState = TelemetryHealthState(
      status: status,
      connectionSessionId: _connectionSessionId,
      message: message,
      lastMessageAt: lastMessageAt ?? _healthState.lastMessageAt,
      fallbackSuggested: fallbackSuggested,
      reconnectAttempt: reconnectAttempt,
    );
    _healthController.add(_healthState);
    _log(
      'health',
      <String, dynamic>{
        'status': status.name,
        'sessionId': _connectionSessionId,
        'message': message,
        'lastMessageAt': _healthState.lastMessageAt?.toIso8601String(),
        'reconnectAttempt': reconnectAttempt,
        'fallbackSuggested': fallbackSuggested,
      },
    );
  }

  Future<void> _cancelTimers() async {
    _cancelFirstMessageTimer();
    _staleTimer?.cancel();
    _staleTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelFirstMessageTimer() {
    _firstMessageTimer?.cancel();
    _firstMessageTimer = null;
  }

  Future<void> _disposeClient() async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _client?.dispose();
    _client = null;
  }

  String _buildClientId(MqttProtocolVersion protocol) {
    if (_bootstrapBundle.mqtt.channel == EcoFlowMqttChannel.app) {
      final userId = _bootstrapBundle.mqtt.userId?.trim();
      if (userId != null && userId.isNotEmpty) {
        final part1 = _randomHex(8);
        final part2 = _randomHex(4);
        final part3 = _randomHex(4);
        final part4 = _randomHex(4);
        final part5 = _randomHex(12);
        final appLikeUuid = '$part1-$part2-$part3-$part4-$part5';
        return 'ANDROID_${appLikeUuid}_$userId';
      }
    }
    return 'ecoflow_diag_${DateTime.now().millisecondsSinceEpoch}_${protocol.name}';
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Object? _toPayloadObject(String payload) {
    try {
      return jsonDecode(payload);
    } catch (_) {
      return payload;
    }
  }

  void _log(String event, Map<String, dynamic> payload) {
    const mutedEvents = <String>{
      'health',
      'mqtt.message',
      'mqtt.publish',
      'mqtt.subscribe',
    };
    if (mutedEvents.contains(event)) {
      return;
    }
    // ignore: avoid_print
    print('[EcoFlowRealtimeService][$event] ${jsonEncode(payload)}');
  }
}
