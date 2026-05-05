import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EcoFlowCredentials {
  const EcoFlowCredentials({
    required this.email,
    required this.password,
    required this.openApiAccessKey,
    required this.openApiSecretKey,
    this.ecoflowBaseUrl = EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
    this.openApiBaseUrl = EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
  });

  final String email;
  final String password;
  final String openApiAccessKey;
  final String openApiSecretKey;
  final String ecoflowBaseUrl;
  final String openApiBaseUrl;

  bool get isComplete {
    return email.trim().isNotEmpty &&
        password.trim().isNotEmpty &&
        openApiAccessKey.trim().isNotEmpty &&
        openApiSecretKey.trim().isNotEmpty;
  }
}

class EcoFlowSettingsStorage {
  EcoFlowSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const defaultEcoFlowBaseUrl = 'https://api.ecoflow.com';

  static const _emailKey = 'ecoflow_email';
  static const _passwordKey = 'ecoflow_password';
  static const _openApiAccessKeyKey = 'ecoflow_open_api_access_key';
  static const _openApiSecretKeyKey = 'ecoflow_open_api_secret_key';
  static const _ecoflowBaseUrlKey = 'ecoflow_base_url';
  static const _openApiBaseUrlKey = 'ecoflow_open_api_base_url';
  static const _themeModeKey = 'app_theme_mode';

  final FlutterSecureStorage _storage;

  Future<EcoFlowCredentials?> readCredentialsOrNull() async {
    final email = (await _storage.read(key: _emailKey))?.trim() ?? '';
    final password = (await _storage.read(key: _passwordKey))?.trim() ?? '';
    final accessKey =
        (await _storage.read(key: _openApiAccessKeyKey))?.trim() ?? '';
    final secretKey =
        (await _storage.read(key: _openApiSecretKeyKey))?.trim() ?? '';
    final ecoflowBaseUrl = (await _storage.read(
      key: _ecoflowBaseUrlKey,
    ))?.trim();
    final openApiBaseUrl = (await _storage.read(
      key: _openApiBaseUrlKey,
    ))?.trim();
    final credentials = EcoFlowCredentials(
      email: email,
      password: password,
      openApiAccessKey: accessKey,
      openApiSecretKey: secretKey,
      ecoflowBaseUrl: ecoflowBaseUrl == null || ecoflowBaseUrl.isEmpty
          ? defaultEcoFlowBaseUrl
          : ecoflowBaseUrl,
      openApiBaseUrl: openApiBaseUrl == null || openApiBaseUrl.isEmpty
          ? defaultEcoFlowBaseUrl
          : openApiBaseUrl,
    );
    return credentials.isComplete ? credentials : null;
  }

  Future<EcoFlowCredentials> readCredentials() async {
    return await readCredentialsOrNull() ??
        const EcoFlowCredentials(
          email: '',
          password: '',
          openApiAccessKey: '',
          openApiSecretKey: '',
        );
  }

  Future<void> writeCredentials(EcoFlowCredentials credentials) async {
    await Future.wait(<Future<void>>[
      _storage.write(key: _emailKey, value: credentials.email.trim()),
      _storage.write(key: _passwordKey, value: credentials.password.trim()),
      _storage.write(
        key: _openApiAccessKeyKey,
        value: credentials.openApiAccessKey.trim(),
      ),
      _storage.write(
        key: _openApiSecretKeyKey,
        value: credentials.openApiSecretKey.trim(),
      ),
      _storage.write(
        key: _ecoflowBaseUrlKey,
        value: credentials.ecoflowBaseUrl.trim().isEmpty
            ? defaultEcoFlowBaseUrl
            : credentials.ecoflowBaseUrl.trim(),
      ),
      _storage.write(
        key: _openApiBaseUrlKey,
        value: credentials.openApiBaseUrl.trim().isEmpty
            ? defaultEcoFlowBaseUrl
            : credentials.openApiBaseUrl.trim(),
      ),
    ]);
  }

  Future<ThemeMode> readThemeMode() async {
    final raw = (await _storage.read(key: _themeModeKey))?.trim();
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> writeThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _storage.write(key: _themeModeKey, value: value);
  }
}
