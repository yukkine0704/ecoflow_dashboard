class EcoFlowCredentials {
  const EcoFlowCredentials({required this.accessKey, required this.secretKey});

  final String accessKey;
  final String secretKey;

  bool get isValid => accessKey.trim().isNotEmpty && secretKey.trim().isNotEmpty;
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
    this.raw,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String? protocol;
  final bool useTls;
  final String? certificateAccount;
  final Map<String, dynamic>? raw;
}

class EcoFlowDeviceIdentity {
  const EcoFlowDeviceIdentity({
    required this.sn,
    this.name,
    this.deviceId,
    this.certificateAccount,
    this.raw,
  });

  final String sn;
  final String? name;
  final String? deviceId;
  final String? certificateAccount;
  final Map<String, dynamic>? raw;

  String get displayName {
    final candidate = name?.trim();
    if (candidate == null || candidate.isEmpty) {
      return 'Sin nombre';
    }
    return candidate;
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

  String get quotaTopic => '/open/$certificateAccount/${device.sn}/quota';

  String get statusTopic => '/open/$certificateAccount/${device.sn}/status';

  String get wildcardTopic => '/open/$certificateAccount/${device.sn}/#';
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
