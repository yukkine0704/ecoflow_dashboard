import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'ecoflow_models.dart';

class EcoFlowSignedHeadersFactory {
  EcoFlowSignedHeadersFactory({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  EcoFlowSignedHeaders create({
    required String accessKey,
    required String secretKey,
    Map<String, dynamic>? params,
    int? timestampMillis,
    String? nonce,
  }) {
    final safeAccessKey = accessKey.trim();
    final safeSecretKey = secretKey.trim();
    final safeNonce = nonce ?? _createNonce();
    final safeTimestamp = (timestampMillis ?? DateTime.now().millisecondsSinceEpoch).toString();

    final signingMap = <String, String>{
      'accessKey': safeAccessKey,
      'nonce': safeNonce,
      'timestamp': safeTimestamp,
    };

    if (params != null && params.isNotEmpty) {
      signingMap['params'] = jsonEncode(_canonicalize(params));
    }

    final baseString = _buildSignBaseString(signingMap);
    final signature = Hmac(sha256, utf8.encode(safeSecretKey))
        .convert(utf8.encode(baseString))
        .toString();

    return EcoFlowSignedHeaders(
      headers: <String, String>{
        'accessKey': safeAccessKey,
        'nonce': safeNonce,
        'timestamp': safeTimestamp,
        'sign': signature,
        'Content-Type': 'application/json',
      },
      nonce: safeNonce,
      timestamp: safeTimestamp,
      signature: signature,
      signBaseString: baseString,
    );
  }

  String _createNonce() {
    return (_random.nextInt(900000) + 100000).toString();
  }

  String _buildSignBaseString(Map<String, String> input) {
    final sortedKeys = input.keys.toList()..sort();
    return sortedKeys.map((key) => '$key=${input[key]}').join('&');
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final sortedEntries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, dynamic>{
        for (final entry in sortedEntries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }

    if (value is List) {
      return value.map(_canonicalize).toList();
    }

    return value;
  }
}
