import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ecoflow_signer.dart';

class EcoFlowMqttCertification {
  const EcoFlowMqttCertification({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.userId,
    required this.useTls,
    this.certificateAccount,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String userId;
  final bool useTls;
  final String? certificateAccount;
}

class EcoFlowDeviceIdentity {
  const EcoFlowDeviceIdentity({
    required this.sn,
    this.name,
    this.model,
    this.imageUrl,
  });

  final String sn;
  final String? name;
  final String? model;
  final String? imageUrl;
}

class EcoFlowAuthApi {
  EcoFlowAuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<EcoFlowMqttCertification> fetchAppMqttCertification({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final loginEnvelope = await _postJson(
      Uri.parse('$baseUrl/auth/login'),
      <String, Object?>{
        'email': email,
        'password': base64Encode(utf8.encode(password)),
        'scene': 'IOT_APP',
        'userType': 'ECOFLOW',
      },
      headers: const <String, String>{'lang': 'en_US'},
    );
    _ensureSuccess(loginEnvelope, '/auth/login');

    final loginData =
        _asMap(loginEnvelope['data']) ?? const <String, Object?>{};
    final token = _pickText(loginData, const <String>['token']);
    final user = _asMap(loginData['user']) ?? const <String, Object?>{};
    final userId = _pickText(user, const <String>['userId', 'id']);
    if (token == null || userId == null) {
      throw StateError('Missing token/userId in EcoFlow app login');
    }

    final certUri = Uri.parse(
      '$baseUrl/iot-auth/app/certification',
    ).replace(queryParameters: <String, String>{'userId': userId});
    final certResponse = await _client.get(
      certUri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'lang': 'en_US',
        'content-type': 'application/json',
      },
    );
    final certEnvelope = _decodeEnvelope(
      certResponse,
      '/iot-auth/app/certification',
    );
    _ensureSuccess(certEnvelope, '/iot-auth/app/certification');
    final certData = _asMap(certEnvelope['data']) ?? const <String, Object?>{};
    final hostRaw = _pickText(certData, const <String>[
      'url',
      'host',
      'mqttHost',
      'broker',
      'server',
    ]);
    final account = _pickText(certData, const <String>[
      'certificateAccount',
      'account',
      'certAccount',
    ]);
    final certPassword = _pickText(certData, const <String>[
      'certificatePassword',
      'password',
      'pwd',
    ]);
    final protocol = _pickText(certData, const <String>['protocol', 'schema']);
    final portText = _pickText(certData, const <String>['port', 'mqttPort']);
    final normalized = _normalizeHost(hostRaw ?? '');
    if (hostRaw == null || account == null || certPassword == null) {
      throw StateError('Incomplete MQTT certification response');
    }
    final parsedPort = int.tryParse(portText ?? '');
    final port = parsedPort ?? normalized.port ?? 8883;
    final useTls = (protocol ?? '').toLowerCase() == 'mqtts' || port == 8883;
    return EcoFlowMqttCertification(
      host: normalized.host,
      port: port,
      username: account,
      password: certPassword,
      userId: userId,
      certificateAccount: account,
      useTls: useTls,
    );
  }

  Future<List<EcoFlowDeviceIdentity>> fetchOpenApiDeviceList({
    required String baseUrl,
    required String accessKey,
    required String secretKey,
  }) async {
    final endpoint = '/iot-open/sign/device/list';
    final headers = createSignedHeaders(
      accessKey: accessKey,
      secretKey: secretKey,
    );
    final response = await _client.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    final envelope = _decodeEnvelope(response, endpoint);
    _ensureSuccess(envelope, endpoint);
    final dataRaw = envelope['data'];
    Object? listRaw;
    if (dataRaw is List) {
      listRaw = dataRaw;
    } else {
      final data = _asMap(dataRaw) ?? envelope;
      listRaw = data['list'] ?? data['devices'] ?? data['deviceList'];
    }
    if (listRaw is! List) return const <EcoFlowDeviceIdentity>[];

    final devices = <EcoFlowDeviceIdentity>[];
    for (final row in listRaw) {
      final map = _asMap(row);
      if (map == null) continue;
      final sn = _pickText(map, const <String>[
        'sn',
        'deviceSn',
        'serialNumber',
        'deviceSN',
      ]);
      if (sn == null) continue;
      devices.add(
        EcoFlowDeviceIdentity(
          sn: sn,
          name: _pickText(map, const <String>[
            'deviceName',
            'name',
            'nickName',
            'snName',
            'productName',
          ]),
          model: _pickText(map, const <String>[
            'productName',
            'productModel',
            'model',
            'deviceModel',
            'deviceType',
          ]),
          imageUrl: _pickText(map, const <String>[
            'imageUrl',
            'imgUrl',
            'picUrl',
            'productPic',
            'iconUrl',
          ]),
        ),
      );
    }
    return devices;
  }

  Future<Map<String, bool>> fetchOpenApiDeviceStatusMap({
    required String baseUrl,
    required String accessKey,
    required String secretKey,
  }) async {
    final endpoint = '/iot-open/sign/device/list';
    final headers = createSignedHeaders(
      accessKey: accessKey,
      secretKey: secretKey,
    );
    final response = await _client.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    final envelope = _decodeEnvelope(response, endpoint);
    final data = _asMap(envelope['data']) ?? envelope;
    final listRaw = data['list'] is List
        ? data['list']
        : (envelope['data'] is List ? envelope['data'] : const <Object?>[]);
    final out = <String, bool>{};
    if (listRaw is List) {
      for (final row in listRaw) {
        final map = _asMap(row);
        if (map == null) continue;
        final sn = _pickText(map, const <String>[
          'sn',
          'deviceSn',
          'serialNumber',
          'deviceSN',
        ]);
        if (sn == null) continue;
        final statusRaw = map['status'];
        out[sn] = statusRaw == 1 || statusRaw == '1' || statusRaw == true;
      }
    }
    return out;
  }

  Future<void> dispose() async {
    _client.close();
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _client.post(
      uri,
      headers: <String, String>{'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
    return _decodeEnvelope(response, uri.path);
  }

  Map<String, dynamic> _decodeEnvelope(
    http.Response response,
    String endpoint,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''} for $endpoint',
      );
    }
    final decoded = jsonDecode(response.body);
    final mapped = _asMap(decoded);
    if (mapped == null) {
      throw StateError('Invalid JSON envelope for $endpoint');
    }
    return mapped;
  }

  void _ensureSuccess(Map<String, dynamic> envelope, String endpoint) {
    final code = _asText(envelope['code']);
    if (code == null || code == '0') return;
    final message = _asText(envelope['message']) ?? 'unknown error';
    throw StateError('EcoFlow $endpoint failed: code=$code message=$message');
  }

  ({String host, int? port}) _normalizeHost(String hostRaw) {
    try {
      final uri = Uri.parse(
        hostRaw.contains('://') ? hostRaw : 'mqtt://$hostRaw',
      );
      final port = uri.hasPort ? uri.port : null;
      return (host: uri.host, port: port);
    } catch (_) {
      final parts = hostRaw.split(':');
      if (parts.length == 2) {
        return (host: parts.first, port: int.tryParse(parts.last));
      }
      return (host: hostRaw, port: null);
    }
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return null;
}

String? _asText(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num && value.isFinite) return value.toString();
  return null;
}

String? _pickText(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = _asText(source[key]);
    if (value != null) return value;
  }
  return null;
}
