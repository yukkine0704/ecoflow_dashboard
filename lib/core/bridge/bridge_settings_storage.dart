import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BridgeSettingsStorage {
  BridgeSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _wsUrlKey = 'bridge_ws_url';
  static const _defaultWsUrl = 'ws://127.0.0.1:8787/ws';

  final FlutterSecureStorage _storage;

  Future<String> readWsUrl() async {
    final raw = await _storage.read(key: _wsUrlKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return _defaultWsUrl;
    }
    return value;
  }

  Future<String?> readStoredWsUrlOrNull() async {
    final raw = await _storage.read(key: _wsUrlKey);
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> writeWsUrl(String wsUrl) {
    return _storage.write(key: _wsUrlKey, value: wsUrl.trim());
  }
}
