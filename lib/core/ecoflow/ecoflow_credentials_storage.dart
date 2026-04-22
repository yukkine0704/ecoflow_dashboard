import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ecoflow_models.dart';

class EcoFlowCredentialsStorage {
  EcoFlowCredentialsStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKeyKey = 'ecoflow_access_key';
  static const _secretKeyKey = 'ecoflow_secret_key';

  final FlutterSecureStorage _storage;

  Future<EcoFlowCredentials?> read() async {
    final accessKey = await _storage.read(key: _accessKeyKey);
    final secretKey = await _storage.read(key: _secretKeyKey);

    if ((accessKey ?? '').trim().isEmpty || (secretKey ?? '').trim().isEmpty) {
      return null;
    }

    return EcoFlowCredentials(accessKey: accessKey!.trim(), secretKey: secretKey!.trim());
  }

  Future<void> write(EcoFlowCredentials credentials) async {
    await _storage.write(key: _accessKeyKey, value: credentials.accessKey.trim());
    await _storage.write(key: _secretKeyKey, value: credentials.secretKey.trim());
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKeyKey);
    await _storage.delete(key: _secretKeyKey);
  }
}
