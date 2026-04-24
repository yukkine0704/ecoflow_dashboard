import 'dart:convert';

import 'package:dio/dio.dart';

import 'ecoflow_models.dart';

class EcoFlowAppMqttAuthService {
  EcoFlowAppMqttAuthService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.ecoflow.com',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 12),
            ),
          );

  final Dio _dio;

  static const _loginEndpoint = '/auth/login';
  static const _certificationEndpoint = '/iot-auth/app/certification';

  Future<EcoFlowMqttCertification> fetchMqttCertification({
    required String email,
    required String password,
  }) async {
    final login = await _login(email: email, password: password);
    final certData = await _fetchCertification(
      userId: login.userId,
      token: login.token,
    );
    final host = _asString(
      certData,
      const ['url', 'host', 'mqttHost', 'broker', 'server'],
    );
    final account = _asString(
      certData,
      const ['certificateAccount', 'account', 'certAccount'],
    );
    final certPassword = _asString(
      certData,
      const ['certificatePassword', 'password', 'pwd'],
    );
    final protocol = _asString(certData, const ['protocol', 'schema']);
    final portRaw = _asString(certData, const ['port', 'mqttPort']);
    final port = int.tryParse((portRaw ?? '').trim()) ?? 8883;
    if (host == null || account == null || certPassword == null) {
      throw Exception('Respuesta de certificación MQTT app incompleta.');
    }

    return EcoFlowMqttCertification(
      host: host,
      port: port,
      username: account,
      password: certPassword,
      protocol: protocol,
      useTls: protocol?.toLowerCase() == 'mqtts' || port == 8883,
      certificateAccount: account,
      userId: login.userId,
      channel: EcoFlowMqttChannel.app,
      raw: certData,
    );
  }

  Future<_AppLoginResult> _login({
    required String email,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'password': base64Encode(utf8.encode(password)),
      'scene': 'IOT_APP',
      'userType': 'ECOFLOW',
    };
    final response = await _dio.post<dynamic>(
      _loginEndpoint,
      data: payload,
      options: Options(
        headers: const <String, dynamic>{
          'lang': 'en_US',
          'content-type': 'application/json',
        },
      ),
    );
    final map = _toMap(response.data);
    _ensureBusinessSuccess(map, endpoint: _loginEndpoint);
    final safeMap = map ?? const <String, dynamic>{};
    final data = _toMap(safeMap['data']) ?? const <String, dynamic>{};
    final token = _asString(data, const ['token']);
    final user = _toMap(data['user']) ?? const <String, dynamic>{};
    final userId = _asString(user, const ['userId', 'id']);
    if (token == null || userId == null) {
      throw Exception('No se recibió token/userId en login app.');
    }
    return _AppLoginResult(token: token, userId: userId);
  }

  Future<Map<String, dynamic>> _fetchCertification({
    required String userId,
    required String token,
  }) async {
    final response = await _dio.request<dynamic>(
      _certificationEndpoint,
      data: <String, dynamic>{'userId': userId},
      options: Options(
        method: 'GET',
        headers: <String, dynamic>{
          'Authorization': 'Bearer $token',
          'lang': 'en_US',
          'content-type': 'application/json',
        },
      ),
    );
    final map = _toMap(response.data);
    _ensureBusinessSuccess(map, endpoint: _certificationEndpoint);
    final safeMap = map ?? const <String, dynamic>{};
    return _toMap(safeMap['data']) ?? const <String, dynamic>{};
  }

  void _ensureBusinessSuccess(
    Map<String, dynamic>? envelope, {
    required String endpoint,
  }) {
    if (envelope == null || envelope.isEmpty) {
      throw Exception('Respuesta vacía en $endpoint');
    }
    final code = envelope['code']?.toString().trim();
    if (code == null || code.isEmpty || code == '0') {
      return;
    }
    final message = envelope['message']?.toString() ?? 'Error desconocido';
    throw Exception('EcoFlow $endpoint respondió code=$code message=$message');
  }

  Map<String, dynamic>? _toMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  String? _asString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return null;
    }
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}

class _AppLoginResult {
  const _AppLoginResult({required this.token, required this.userId});

  final String token;
  final String userId;
}
