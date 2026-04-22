enum ConnectionStage {
  idle,
  authenticating,
  mqttConnecting,
  retrying,
  streaming,
  error,
}

class ConnectionDiagnosticsState {
  const ConnectionDiagnosticsState({
    required this.stage,
    required this.restHandshakeOk,
    required this.mqttHandshakeOk,
    required this.messagesReceived,
    this.lastError,
    this.lastStatusMessage,
    this.attemptedProtocol,
    this.activeProtocol,
    this.lastMessageAt,
    this.firstMessageWithinTarget,
  });

  const ConnectionDiagnosticsState.idle()
      : stage = ConnectionStage.idle,
        restHandshakeOk = false,
        mqttHandshakeOk = false,
        messagesReceived = 0,
        lastError = null,
        lastStatusMessage = null,
        attemptedProtocol = null,
        activeProtocol = null,
        lastMessageAt = null,
        firstMessageWithinTarget = null;

  final ConnectionStage stage;
  final bool restHandshakeOk;
  final bool mqttHandshakeOk;
  final int messagesReceived;
  final String? lastError;
  final String? lastStatusMessage;
  final String? attemptedProtocol;
  final String? activeProtocol;
  final DateTime? lastMessageAt;
  final bool? firstMessageWithinTarget;

  ConnectionDiagnosticsState copyWith({
    ConnectionStage? stage,
    bool? restHandshakeOk,
    bool? mqttHandshakeOk,
    int? messagesReceived,
    String? lastError,
    bool clearLastError = false,
    String? lastStatusMessage,
    bool clearLastStatusMessage = false,
    String? attemptedProtocol,
    bool clearAttemptedProtocol = false,
    String? activeProtocol,
    bool clearActiveProtocol = false,
    DateTime? lastMessageAt,
    bool clearLastMessageAt = false,
    bool? firstMessageWithinTarget,
    bool clearFirstMessageWithinTarget = false,
  }) {
    return ConnectionDiagnosticsState(
      stage: stage ?? this.stage,
      restHandshakeOk: restHandshakeOk ?? this.restHandshakeOk,
      mqttHandshakeOk: mqttHandshakeOk ?? this.mqttHandshakeOk,
      messagesReceived: messagesReceived ?? this.messagesReceived,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastStatusMessage: clearLastStatusMessage
          ? null
          : (lastStatusMessage ?? this.lastStatusMessage),
      attemptedProtocol: clearAttemptedProtocol
          ? null
          : (attemptedProtocol ?? this.attemptedProtocol),
      activeProtocol:
          clearActiveProtocol ? null : (activeProtocol ?? this.activeProtocol),
      lastMessageAt:
          clearLastMessageAt ? null : (lastMessageAt ?? this.lastMessageAt),
      firstMessageWithinTarget: clearFirstMessageWithinTarget
          ? null
          : (firstMessageWithinTarget ?? this.firstMessageWithinTarget),
    );
  }
}
