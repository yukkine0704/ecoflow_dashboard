import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ecoflow_models.dart';

class EcoFlowCredentialsStorage {
  EcoFlowCredentialsStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKeyKey = 'ecoflow_access_key';
  static const _secretKeyKey = 'ecoflow_secret_key';
  static const _appEmailKey = 'ecoflow_app_email';
  static const _appPasswordKey = 'ecoflow_app_password';
  static const _baseUrlKey = 'ecoflow_base_url';
  static const _defaultBaseUrl = 'https://api.ecoflow.com';

  final FlutterSecureStorage _storage;

  Future<EcoFlowCredentials?> read() async {
    final accessKey = await _storage.read(key: _accessKeyKey);
    final secretKey = await _storage.read(key: _secretKeyKey);
    final appEmail = await _storage.read(key: _appEmailKey);
    final appPassword = await _storage.read(key: _appPasswordKey);

    final hasOpen = (accessKey ?? '').trim().isNotEmpty && (secretKey ?? '').trim().isNotEmpty;
    final hasApp = (appEmail ?? '').trim().isNotEmpty && (appPassword ?? '').trim().isNotEmpty;
    if (!hasOpen && !hasApp) {
      return null;
    }

    return EcoFlowCredentials(
      accessKey: (accessKey ?? '').trim(),
      secretKey: (secretKey ?? '').trim(),
      appEmail: (appEmail ?? '').trim(),
      appPassword: (appPassword ?? '').trim(),
    );
  }

  Future<void> write(EcoFlowCredentials credentials) async {
    await _storage.write(key: _accessKeyKey, value: credentials.accessKey.trim());
    await _storage.write(key: _secretKeyKey, value: credentials.secretKey.trim());
    await _storage.write(key: _appEmailKey, value: (credentials.appEmail ?? '').trim());
    await _storage.write(key: _appPasswordKey, value: (credentials.appPassword ?? '').trim());
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKeyKey);
    await _storage.delete(key: _secretKeyKey);
    await _storage.delete(key: _appEmailKey);
    await _storage.delete(key: _appPasswordKey);
    await _storage.delete(key: _baseUrlKey);
  }

  Future<void> writeBaseUrl(String baseUrl) async {
    await _storage.write(key: _baseUrlKey, value: baseUrl.trim());
  }

  Future<String> readBaseUrl() async {
    final stored = await _storage.read(key: _baseUrlKey);
    final value = (stored ?? '').trim();
    if (value.isEmpty) {
      return _defaultBaseUrl;
    }
    return value;
  }
}
