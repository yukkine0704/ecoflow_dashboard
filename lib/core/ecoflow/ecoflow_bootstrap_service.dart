import 'package:dio/dio.dart';

import 'ecoflow_auth_signer.dart';
import 'ecoflow_models.dart';

class EcoFlowBootstrapService {
  EcoFlowBootstrapService({
    required String baseUrl,
    Dio? dio,
    EcoFlowSignedHeadersFactory? signer,
  })  : _baseUrl = baseUrl,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
              ),
            ),
        _signer = signer ?? EcoFlowSignedHeadersFactory();

  static const List<String> _mqttCertificationEndpoints = [
    '/open/v1/user/mqtt/certification',
    '/iot-open/sign/certification',
    '/iot-open/sign/user/mqtt/certification',
  ];

  static const List<String> _deviceListEndpoints = [
    '/open/v1/device/list',
    '/open/v1/user/device/list',
    '/iot-open/sign/device/list',
    '/open/v1/device/queryDeviceList',
  ];

  final String _baseUrl;
  final Dio _dio;
  final EcoFlowSignedHeadersFactory _signer;

  Future<EcoFlowBootstrapBundle> bootstrap(EcoFlowCredentials credentials) async {
    final mqttAttempt = await _firstSuccessfulMap(
      endpoints: _mqttCertificationEndpoints,
      credentials: credentials,
    );
    final mqttCertification = _parseMqttCertification(mqttAttempt.dataMap);

    final deviceAttempt = await _firstSuccessfulMap(
      endpoints: _deviceListEndpoints,
      credentials: credentials,
    );
    final deviceIdentities = _parseDeviceIdentities(deviceAttempt.dataMap);
    final deviceIdentity = deviceIdentities.first;
    final accountFromDevices = _firstDeviceCertificateAccount(deviceIdentities);

    final certificateAccount = mqttCertification.certificateAccount ??
        accountFromDevices ??
        _extractAccountFromUsername(mqttCertification.username);

    if (certificateAccount == null || certificateAccount.trim().isEmpty) {
      throw Exception(
        'No se pudo resolver certificateAccount desde MQTT ni desde listado de dispositivos.',
      );
    }

    return EcoFlowBootstrapBundle(
      mqtt: mqttCertification,
      device: deviceIdentity,
      devices: deviceIdentities,
      certificateAccount: _compactWhitespace(certificateAccount),
      mqttEndpointUsed: mqttAttempt.endpoint,
      deviceEndpointUsed: deviceAttempt.endpoint,
    );
  }

  Future<_EndpointAttempt> _firstSuccessfulMap({
    required List<String> endpoints,
    required EcoFlowCredentials credentials,
  }) async {
    final failures = <String>[];

    for (final endpoint in endpoints) {
      try {
        final response = await _signedGet(
          endpoint: endpoint,
          credentials: credentials,
        );
        if (response.data is! Map) {
          failures.add('$endpoint -> payload no es objeto JSON');
          continue;
        }

        final map = Map<String, dynamic>.from(response.data as Map);
        return _EndpointAttempt(endpoint: endpoint, dataMap: map);
      } catch (error) {
        failures.add('$endpoint -> $error');
      }
    }

    throw Exception(
      'No hubo respuesta válida en $_baseUrl. Intentos: ${failures.join(' | ')}',
    );
  }

  Future<Response<dynamic>> _signedGet({
    required String endpoint,
    required EcoFlowCredentials credentials,
    Map<String, dynamic>? params,
  }) async {
    final signedHeaders = _signer.create(
      accessKey: credentials.accessKey,
      secretKey: credentials.secretKey,
      params: params,
    );

    return _dio.get(
      endpoint,
      queryParameters: params,
      options: Options(headers: signedHeaders.headers),
    );
  }

  EcoFlowMqttCertification _parseMqttCertification(Map<String, dynamic> envelope) {
    final data = _extractDataMap(envelope);

    final hostValue = _stringFromAny(
      data,
      keys: const ['host', 'url', 'mqttHost', 'broker', 'server'],
    );
    final certificateAccountRaw = _stringFromAny(
      data,
      keys: const ['certificateAccount', 'certAccount', 'account', 'accountId'],
    );
    final certificateAccount = certificateAccountRaw == null
        ? null
        : _compactWhitespace(certificateAccountRaw);
    final username = _stringFromAny(
      data,
      keys: const ['username', 'user', 'mqttUsername', 'certificateUsername'],
    );
    final password = _stringFromAny(
      data,
      keys: const ['password', 'pwd', 'mqttPassword', 'certificatePassword'],
    );
    final protocol = _stringFromAny(data, keys: const ['protocol', 'schema']);

    final resolvedUsername = (username ?? certificateAccount)?.trim();

    if (hostValue == null || resolvedUsername == null || password == null) {
      throw Exception('Respuesta MQTT incompleta: $data');
    }

    final normalizedHost = _normalizeHost(hostValue);
    final derivedPort = _intFromAny(data, keys: const ['port', 'mqttPort']);
    final port = derivedPort ?? normalizedHost.$2 ?? 1883;
    final useTls = protocol?.toLowerCase() == 'mqtts' || port == 8883;

    return EcoFlowMqttCertification(
      host: normalizedHost.$1,
      port: port,
      username: resolvedUsername,
      password: password,
      protocol: protocol,
      useTls: useTls,
      certificateAccount: certificateAccount,
      raw: data,
    );
  }

  List<EcoFlowDeviceIdentity> _parseDeviceIdentities(
    Map<String, dynamic> envelope,
  ) {
    final data = _extractData(envelope);
    final rawDevices = _extractDeviceList(data);
    if (rawDevices.isEmpty) {
      throw Exception('No se encontraron dispositivos en la respuesta: $data');
    }

    final devices = <EcoFlowDeviceIdentity>[];
    for (final raw in rawDevices) {
      final snRaw = _stringFromAny(
        raw,
        keys: const ['sn', 'deviceSn', 'serialNumber', 'deviceSN'],
      );
      final sn = snRaw == null ? null : _compactWhitespace(snRaw);
      if (sn == null || sn.trim().isEmpty) {
        continue;
      }

      final certificateAccountRaw = _stringFromAny(
        raw,
        keys: const ['certificateAccount', 'certAccount', 'account', 'accountId'],
      );
      final certificateAccount = certificateAccountRaw == null
          ? null
          : _compactWhitespace(certificateAccountRaw);

      final name = _stringFromAny(
        raw,
        keys: const [
          'deviceName',
          'name',
          'nickName',
          'snName',
          'productName',
          'devName',
        ],
      );
      final deviceId = _stringFromAny(
        raw,
        keys: const ['deviceId', 'id', 'device_id', 'thingName', 'imei', 'mac'],
      );

      devices.add(
        EcoFlowDeviceIdentity(
          sn: sn,
          name: name,
          deviceId: deviceId,
          certificateAccount: certificateAccount,
          raw: raw,
        ),
      );
    }

    if (devices.isEmpty) {
      throw Exception(
        'No se pudo extraer SN de los dispositivos reportados: $rawDevices',
      );
    }
    return devices;
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> envelope) {
    final data = _extractData(envelope);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Campo data no es objeto: $data');
  }

  dynamic _extractData(Map<String, dynamic> envelope) {
    if (envelope.containsKey('data')) {
      return envelope['data'];
    }
    return envelope;
  }

  List<Map<String, dynamic>> _extractDeviceList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    if (data is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['list', 'devices', 'deviceList', 'rows']) {
      final candidate = data[key];
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    if (_stringFromAny(data, keys: const ['sn', 'deviceSn']) != null) {
      return [data];
    }

    return const [];
  }

  String? _stringFromAny(Map<String, dynamic> source, {required List<String> keys}) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  int? _intFromAny(Map<String, dynamic> source, {required List<String> keys}) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  (String, int?) _normalizeHost(String rawHost) {
    final trimmed = rawHost.trim();

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      uri = null;
    }

    if (uri != null && uri.host.isNotEmpty) {
      final explicitPort = uri.hasPort ? uri.port : null;
      return (uri.host, explicitPort);
    }

    final parts = trimmed.split(':');
    if (parts.length == 2) {
      final maybePort = int.tryParse(parts.last);
      if (maybePort != null) {
        return (parts.first, maybePort);
      }
    }

    return (trimmed, null);
  }

  String? _extractAccountFromUsername(String username) {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('@')) {
      return normalized.split('@').first;
    }

    if (normalized.contains(':')) {
      return normalized.split(':').first;
    }

    return null;
  }

  String _compactWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  String? _firstDeviceCertificateAccount(List<EcoFlowDeviceIdentity> devices) {
    for (final device in devices) {
      final account = device.certificateAccount?.trim();
      if (account != null && account.isNotEmpty) {
        return account;
      }
    }
    return null;
  }
}

class _EndpointAttempt {
  const _EndpointAttempt({required this.endpoint, required this.dataMap});

  final String endpoint;
  final Map<String, dynamic> dataMap;
}
