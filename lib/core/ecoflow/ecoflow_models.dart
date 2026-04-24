enum EcoFlowMqttChannel { open, app }

enum EcoFlowDetailUpdateSource { none, rest, mqtt }

class EcoFlowCredentials {
  const EcoFlowCredentials({
    required this.accessKey,
    required this.secretKey,
    this.appEmail,
    this.appPassword,
  });

  final String accessKey;
  final String secretKey;
  final String? appEmail;
  final String? appPassword;

  bool get isOpenApiValid =>
      accessKey.trim().isNotEmpty && secretKey.trim().isNotEmpty;

  bool get isAppAuthValid =>
      (appEmail ?? '').trim().isNotEmpty && (appPassword ?? '').trim().isNotEmpty;

  bool get isValid => isOpenApiValid || isAppAuthValid;
}

class EcoFlowMqttCertification {
  const EcoFlowMqttCertification({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.protocol,
    this.useTls = false,
    this.certificateAccount,
    this.userId,
    this.channel = EcoFlowMqttChannel.open,
    this.raw,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String? protocol;
  final bool useTls;
  final String? certificateAccount;
  final String? userId;
  final EcoFlowMqttChannel channel;
  final Map<String, dynamic>? raw;
}

class EcoFlowDeviceIdentity {
  const EcoFlowDeviceIdentity({
    required this.sn,
    this.name,
    this.deviceId,
    this.certificateAccount,
    this.model,
    this.imageUrl,
    this.batteryPercent,
    this.isOnline,
    this.raw,
  });

  final String sn;
  final String? name;
  final String? deviceId;
  final String? certificateAccount;
  final String? model;
  final String? imageUrl;
  final int? batteryPercent;
  final bool? isOnline;
  final Map<String, dynamic>? raw;

  EcoFlowDeviceIdentity copyWith({
    String? sn,
    String? name,
    String? deviceId,
    String? certificateAccount,
    String? model,
    String? imageUrl,
    int? batteryPercent,
    bool? isOnline,
    Map<String, dynamic>? raw,
  }) {
    return EcoFlowDeviceIdentity(
      sn: sn ?? this.sn,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      certificateAccount: certificateAccount ?? this.certificateAccount,
      model: model ?? this.model,
      imageUrl: imageUrl ?? this.imageUrl,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isOnline: isOnline ?? this.isOnline,
      raw: raw ?? this.raw,
    );
  }

  String get displayName {
    final candidate = name?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    final candidateModel = model?.trim();
    if (candidateModel != null && candidateModel.isNotEmpty) {
      return candidateModel;
    }
    return 'Sin nombre';
  }
}

class EcoFlowBootstrapBundle {
  const EcoFlowBootstrapBundle({
    required this.mqtt,
    required this.device,
    required this.devices,
    required this.certificateAccount,
    required this.mqttEndpointUsed,
    required this.deviceEndpointUsed,
  });

  final EcoFlowMqttCertification mqtt;
  final EcoFlowDeviceIdentity device;
  final List<EcoFlowDeviceIdentity> devices;
  final String certificateAccount;
  final String mqttEndpointUsed;
  final String deviceEndpointUsed;

  String topicQuotaForSn(String sn) => '/open/$certificateAccount/$sn/quota';

  String topicStatusForSn(String sn) => '/open/$certificateAccount/$sn/status';

  String topicSetReplyForSn(String sn) => '/open/$certificateAccount/$sn/set_reply';

  String topicWildcardForSn(String sn) => '/open/$certificateAccount/$sn/#';

  List<String> topicsForDeviceSn(
    String sn, {
    bool includeSetReply = true,
    bool includeWildcard = false,
  }) {
    final topics = <String>[
      topicQuotaForSn(sn),
      topicStatusForSn(sn),
      if (includeSetReply) topicSetReplyForSn(sn),
      if (includeWildcard) topicWildcardForSn(sn),
    ];
    return topics.toSet().toList();
  }

  String get quotaTopic => topicQuotaForSn(device.sn);

  String get statusTopic => topicStatusForSn(device.sn);

  String get setReplyTopic => topicSetReplyForSn(device.sn);

  String get wildcardTopic => topicWildcardForSn(device.sn);

  List<String> get defaultRealtimeTopics => topicsForDeviceSn(device.sn);
}

class EcoFlowSignedHeaders {
  const EcoFlowSignedHeaders({
    required this.headers,
    required this.nonce,
    required this.timestamp,
    required this.signature,
    required this.signBaseString,
  });

  final Map<String, String> headers;
  final String nonce;
  final String timestamp;
  final String signature;
  final String signBaseString;
}

class EcoFlowDeviceDetailState {
  const EcoFlowDeviceDetailState({
    required this.sn,
    required this.mergedRaw,
    this.lastRestSnapshotAt,
    this.lastMqttUpdateAt,
    this.lastSource = EcoFlowDetailUpdateSource.none,
  });

  final String sn;
  final Map<String, dynamic> mergedRaw;
  final DateTime? lastRestSnapshotAt;
  final DateTime? lastMqttUpdateAt;
  final EcoFlowDetailUpdateSource lastSource;

  EcoFlowDeviceDetailState copyWith({
    String? sn,
    Map<String, dynamic>? mergedRaw,
    DateTime? lastRestSnapshotAt,
    DateTime? lastMqttUpdateAt,
    EcoFlowDetailUpdateSource? lastSource,
  }) {
    return EcoFlowDeviceDetailState(
      sn: sn ?? this.sn,
      mergedRaw: mergedRaw ?? this.mergedRaw,
      lastRestSnapshotAt: lastRestSnapshotAt ?? this.lastRestSnapshotAt,
      lastMqttUpdateAt: lastMqttUpdateAt ?? this.lastMqttUpdateAt,
      lastSource: lastSource ?? this.lastSource,
    );
  }
}
