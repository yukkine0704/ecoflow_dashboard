import 'dart:convert';

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

  static const List<String> mqttCertificationEndpoints = [
    '/iot-open/sign/certification',
  ];

  static const List<String> deviceListEndpoints = [
    '/iot-open/sign/device/list',
  ];

  final String _baseUrl;
  final Dio _dio;
  final EcoFlowSignedHeadersFactory _signer;

  static const _quotaAllEndpoint = '/iot-open/sign/device/quota/all';
  static const _quotaEndpoint = '/iot-open/sign/device/quota';
  static const List<String> _quotaKeysForSummary = [
    'cmsBattSoc',
    'bmsBattSoc',
    'pd.soc',
    'soc',
    'batterySoc',
    'status',
    'online',
  ];

  Future<EcoFlowBootstrapBundle> bootstrap(EcoFlowCredentials credentials) async {
    _logInfo('bootstrap.start', <String, dynamic>{'baseUrl': _baseUrl});
    final mqttAttempt = await _firstSuccessfulMap(
      endpoints: mqttCertificationEndpoints,
      credentials: credentials,
    );
    final mqttCertification = _parseMqttCertification(mqttAttempt.dataMap);

    final deviceAttempt = await _firstSuccessfulMap(
      endpoints: deviceListEndpoints,
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

  Future<List<EcoFlowDeviceIdentity>> enrichDevicesWithQuota({
    required EcoFlowCredentials credentials,
    required List<EcoFlowDeviceIdentity> devices,
  }) async {
    final futures = devices.map(
      (device) => _enrichSingleDeviceWithQuota(
        credentials: credentials,
        device: device,
      ),
    );
    return Future.wait(futures);
  }

  Future<Map<String, dynamic>> fetchDeviceRawQuotaSnapshot({
    required EcoFlowCredentials credentials,
    required String sn,
  }) async {
    final quota = await _fetchQuotaDataWithFallback(
      credentials: credentials,
      sn: sn,
    );
    if (quota == null) {
      throw Exception('No se pudo obtener quota snapshot para SN=$sn');
    }
    return Map<String, dynamic>.from(quota);
  }

  Future<_EndpointAttempt> _firstSuccessfulMap({
    required List<String> endpoints,
    required EcoFlowCredentials credentials,
  }) async {
    final failures = <String>[];

    for (final endpoint in endpoints) {
      try {
        _logInfo('endpoint.try', <String, dynamic>{'endpoint': endpoint});
        final response = await _signedGet(
          endpoint: endpoint,
          credentials: credentials,
        );
        if (response.data is! Map) {
          failures.add('$endpoint -> payload no es objeto JSON');
          continue;
        }

        final map = Map<String, dynamic>.from(response.data as Map);
        _logInfo(
          'endpoint.success',
          <String, dynamic>{
            'endpoint': endpoint,
            'response': _sanitizeMap(map),
          },
        );
        return _EndpointAttempt(endpoint: endpoint, dataMap: map);
      } catch (error) {
        _logWarn(
          'endpoint.error',
          <String, dynamic>{'endpoint': endpoint, 'error': '$error'},
        );
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
    Map<String, dynamic>? signParams,
  }) async {
    final resolvedSignParams = signParams ?? params;
    final signedHeaders = _signer.create(
      accessKey: credentials.accessKey,
      secretKey: credentials.secretKey,
      params: resolvedSignParams,
    );
    final url = '$_baseUrl$endpoint';
    _logInfo(
      'http.request',
      <String, dynamic>{
        'method': 'GET',
        'url': url,
        'params': params ?? <String, dynamic>{},
        'headerKeys': signedHeaders.headers.keys.toList(),
      },
    );

    final response = await _dio.get(
      endpoint,
      queryParameters: params,
      options: Options(headers: signedHeaders.headers),
    );
    _logInfo(
      'http.response',
      <String, dynamic>{
        'method': 'GET',
        'url': url,
        'statusCode': response.statusCode,
        'data': _sanitizeAny(response.data),
      },
    );
    return response;
  }

  Future<Response<dynamic>> _signedPost({
    required String endpoint,
    required EcoFlowCredentials credentials,
    required Map<String, dynamic> signParams,
    Map<String, dynamic>? body,
  }) async {
    final signedHeaders = _signer.create(
      accessKey: credentials.accessKey,
      secretKey: credentials.secretKey,
      params: signParams,
    );
    final url = '$_baseUrl$endpoint';
    _logInfo(
      'http.request',
      <String, dynamic>{
        'method': 'POST',
        'url': url,
        'body': _sanitizeAny(body),
        'headerKeys': signedHeaders.headers.keys.toList(),
      },
    );

    final response = await _dio.post(
      endpoint,
      data: body,
      options: Options(headers: signedHeaders.headers),
    );
    _logInfo(
      'http.response',
      <String, dynamic>{
        'method': 'POST',
        'url': url,
        'statusCode': response.statusCode,
        'data': _sanitizeAny(response.data),
      },
    );
    return response;
  }

  Future<EcoFlowDeviceIdentity> _enrichSingleDeviceWithQuota({
    required EcoFlowCredentials credentials,
    required EcoFlowDeviceIdentity device,
  }) async {
    try {
      final quota = await _fetchQuotaDataWithFallback(
        credentials: credentials,
        sn: device.sn,
      );
      if (quota == null) {
        return device;
      }

      final batteryPercent = _intFromAny(
        quota,
        keys: const ['pd.soc', 'cmsBattSoc', 'bmsBattSoc', 'soc', 'batterySoc'],
      );
      final online = _boolFromAny(
        quota,
        keys: const ['status', 'online', 'isOnline', 'deviceOnline'],
      );

      return device.copyWith(
        batteryPercent: batteryPercent ?? device.batteryPercent,
        isOnline: online ?? device.isOnline,
      );
    } catch (error) {
      _logWarn(
        'quota_all.error',
        <String, dynamic>{'sn': device.sn, 'error': '$error'},
      );
      return device;
    }
  }

  Future<Map<String, dynamic>?> _fetchQuotaDataWithFallback({
    required EcoFlowCredentials credentials,
    required String sn,
  }) async {
    final selectivePayload = <String, dynamic>{
      'sn': sn,
      'params': <String, dynamic>{'quotas': _quotaKeysForSummary},
    };
    final selectiveParamsOnly = <String, dynamic>{
      'params': <String, dynamic>{'quotas': _quotaKeysForSummary},
    };
    final snOnly = <String, dynamic>{'sn': sn};

    final attempts = <_QuotaAttempt>[
      _QuotaAttempt(
        name: 'quota_all_get_query_sign_sn',
        method: 'GET',
        endpoint: _quotaAllEndpoint,
        query: snOnly,
        signParams: snOnly,
      ),
      _QuotaAttempt(
        name: 'quota_all_get_query_sign_none',
        method: 'GET',
        endpoint: _quotaAllEndpoint,
        query: snOnly,
        signParams: const <String, dynamic>{},
      ),
      _QuotaAttempt(
        name: 'quota_get_query_sign_full',
        method: 'GET',
        endpoint: _quotaEndpoint,
        query: selectivePayload,
        signParams: selectivePayload,
      ),
      _QuotaAttempt(
        name: 'quota_get_query_sign_full_raw_json',
        method: 'GET',
        endpoint: _quotaEndpoint,
        query: selectivePayload,
        signParams: selectivePayload,
      ),
      _QuotaAttempt(
        name: 'quota_get_query_sign_sn',
        method: 'GET',
        endpoint: _quotaEndpoint,
        query: selectivePayload,
        signParams: snOnly,
      ),
      _QuotaAttempt(
        name: 'quota_get_query_sign_params_only',
        method: 'GET',
        endpoint: _quotaEndpoint,
        query: selectivePayload,
        signParams: selectiveParamsOnly,
      ),
      _QuotaAttempt(
        name: 'quota_get_query_sign_none',
        method: 'GET',
        endpoint: _quotaEndpoint,
        query: selectivePayload,
        signParams: const <String, dynamic>{},
      ),
      _QuotaAttempt(
        name: 'quota_post_body_sign_full',
        method: 'POST',
        endpoint: _quotaEndpoint,
        body: selectivePayload,
        signParams: selectivePayload,
      ),
      _QuotaAttempt(
        name: 'quota_post_body_sign_full_raw_json',
        method: 'POST',
        endpoint: _quotaEndpoint,
        body: selectivePayload,
        signParams: selectivePayload,
      ),
      _QuotaAttempt(
        name: 'quota_post_body_sign_sn',
        method: 'POST',
        endpoint: _quotaEndpoint,
        body: selectivePayload,
        signParams: snOnly,
      ),
      _QuotaAttempt(
        name: 'quota_post_body_sign_params_only',
        method: 'POST',
        endpoint: _quotaEndpoint,
        body: selectivePayload,
        signParams: selectiveParamsOnly,
      ),
      _QuotaAttempt(
        name: 'quota_post_body_sign_none',
        method: 'POST',
        endpoint: _quotaEndpoint,
        body: selectivePayload,
        signParams: const <String, dynamic>{},
      ),
    ];

    for (final attempt in attempts) {
      try {
        _logInfo(
          'quota.try',
          <String, dynamic>{
            'name': attempt.name,
            'method': attempt.method,
            'endpoint': attempt.endpoint,
            'sn': sn,
          },
        );

        final response = attempt.method == 'POST'
            ? await _signedPost(
                endpoint: attempt.endpoint,
                credentials: credentials,
                signParams: attempt.signParams,
                body: attempt.body,
              )
            : await _signedGet(
                endpoint: attempt.endpoint,
                credentials: credentials,
                params: attempt.query,
                signParams: attempt.signParams,
              );

        if (response.data is! Map) {
          _logWarn(
            'quota.skip.non_map',
            <String, dynamic>{'name': attempt.name, 'sn': sn},
          );
          continue;
        }

        final envelope = Map<String, dynamic>.from(response.data as Map);
        if (!_isBusinessSuccess(envelope)) {
          final code = envelope['code']?.toString().trim();
          _logWarn(
            'quota.skip.business_error',
            <String, dynamic>{
              'name': attempt.name,
              'sn': sn,
              'code': code,
              'message': envelope['message'],
            },
          );
          if (_isTerminalQuotaBusinessCode(code)) {
            _logWarn(
              'quota.abort.terminal_business_error',
              <String, dynamic>{
                'name': attempt.name,
                'sn': sn,
                'code': code,
              },
            );
            return null;
          }
          continue;
        }

        final data = _extractData(envelope);
        if (data is! Map) {
          _logWarn(
            'quota.skip.data_not_map',
            <String, dynamic>{'name': attempt.name, 'sn': sn},
          );
          continue;
        }

        final result = data.cast<String, dynamic>();
        _logInfo(
          'quota.success',
          <String, dynamic>{
            'name': attempt.name,
            'sn': sn,
            'data': _sanitizeMap(result),
          },
        );
        return result;
      } catch (error) {
        _logWarn(
          'quota.error',
          <String, dynamic>{'name': attempt.name, 'sn': sn, 'error': '$error'},
        );
      }
    }

    return null;
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
      _logInfo('device.raw', <String, dynamic>{'raw': _sanitizeMap(raw)});
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
      final model = _stringFromAny(
        raw,
        keys: const [
          'productName',
          'productModel',
          'model',
          'deviceModel',
          'productType',
          'deviceType',
          'series',
        ],
      );
      final resolvedModel = model ?? _deriveModelFromName(name);
      final imageUrl = _stringFromAny(
        raw,
        keys: const [
          'imageUrl',
          'imgUrl',
          'picUrl',
          'productPic',
          'iconUrl',
          'coverUrl',
          'image',
          'img',
          'pic',
          'icon',
        ],
      );
      final batteryPercent = _intFromAny(
        raw,
        keys: const [
          'batteryPercent',
          'batteryLevel',
          'soc',
          'batterySoc',
          'powerPercent',
          'remainPower',
          'capacityPercent',
        ],
      );
      final isOnline = _boolFromAny(
        raw,
        keys: const [
          'online',
          'isOnline',
          'deviceOnline',
          'connectionStatus',
          'connectState',
          'status',
        ],
      );

      devices.add(
        EcoFlowDeviceIdentity(
          sn: sn,
          name: name,
          deviceId: deviceId,
          certificateAccount: certificateAccount,
          model: resolvedModel,
          imageUrl: imageUrl,
          batteryPercent: batteryPercent,
          isOnline: isOnline,
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
      if (value is double) {
        return value.round();
      }
      if (value is String) {
        final cleaned = value.replaceAll('%', '').trim();
        final parsed = int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  bool? _boolFromAny(Map<String, dynamic> source, {required List<String> keys}) {
    for (final key in keys) {
      final value = source[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        if (value == 0) {
          return false;
        }
        if (value == 1 || value == 2) {
          return true;
        }
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        if (normalized == '1' ||
            normalized == '2' ||
            normalized == 'true' ||
            normalized == 'online' ||
            normalized == 'connected' ||
            normalized == 'active') {
          return true;
        }
        if (normalized == '0' ||
            normalized == 'false' ||
            normalized == 'offline' ||
            normalized == 'disconnected' ||
            normalized == 'inactive') {
          return false;
        }
      }
    }
    return null;
  }

  bool _isBusinessSuccess(Map<String, dynamic> envelope) {
    if (!envelope.containsKey('code')) {
      return true;
    }
    final code = envelope['code'];
    if (code == null) {
      return true;
    }
    final normalized = code.toString().trim();
    return normalized == '0';
  }

  bool _isTerminalQuotaBusinessCode(String? code) {
    if (code == null || code.isEmpty) {
      return false;
    }
    return code == '1006' || code == '403';
  }

  String? _deriveModelFromName(String? name) {
    if (name == null) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final sanitized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    final cut = sanitized.split(RegExp(r'[-_]')).first.trim();
    if (cut.isEmpty) {
      return sanitized;
    }
    return cut;
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

  void _logInfo(String event, Map<String, dynamic> payload) {
    const mutedEvents = <String>{
      'http.request',
      'http.response',
      'endpoint.try',
      'quota.try',
      'device.raw',
    };
    if (mutedEvents.contains(event)) {
      return;
    }
    // ignore: avoid_print
    print('[EcoFlowBootstrapService][$event] ${_safeJsonEncode(payload)}');
  }

  void _logWarn(String event, Map<String, dynamic> payload) {
    // ignore: avoid_print
    print('[EcoFlowBootstrapService][$event] ${_safeJsonEncode(payload)}');
  }

  Object? _sanitizeAny(Object? value) {
    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, val) {
        normalized[key.toString()] = val;
      });
      return _sanitizeMap(normalized);
    }
    if (value is List) {
      return value.map(_sanitizeAny).toList();
    }
    return value;
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    for (final entry in input.entries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower.contains('secret') ||
          keyLower.contains('password') ||
          keyLower.contains('sign') ||
          keyLower.contains('authorization')) {
        output[entry.key] = '***redacted***';
        continue;
      }
      output[entry.key] = _sanitizeAny(entry.value);
    }
    return output;
  }

  String _safeJsonEncode(Map<String, dynamic> payload) {
    try {
      return jsonEncode(payload);
    } catch (_) {
      return payload.toString();
    }
  }
}

class _EndpointAttempt {
  const _EndpointAttempt({required this.endpoint, required this.dataMap});

  final String endpoint;
  final Map<String, dynamic> dataMap;
}

class _QuotaAttempt {
  const _QuotaAttempt({
    required this.name,
    required this.method,
    required this.endpoint,
    required this.signParams,
    this.query,
    this.body,
  });

  final String name;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? query;
  final Map<String, dynamic>? body;
  final Map<String, dynamic> signParams;
}
