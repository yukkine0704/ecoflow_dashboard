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
    final safeTimestamp =
        (timestampMillis ??
                (DateTime.now().microsecondsSinceEpoch * 1000))
            .toString();

    final queryString = _generateQueryParams(params);
    final baseString = _buildSignBaseString(
      queryString: queryString,
      accessKey: safeAccessKey,
      nonce: safeNonce,
      timestamp: safeTimestamp,
    );
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

  String _buildSignBaseString({
    required String queryString,
    required String accessKey,
    required String nonce,
    required String timestamp,
  }) {
    final suffix = 'accessKey=$accessKey&nonce=$nonce&timestamp=$timestamp';
    if (queryString.isEmpty) {
      return suffix;
    }
    return '$queryString&$suffix';
  }

  String _generateQueryParams(Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) {
      return '';
    }

    final result = <String>[];
    params.forEach((key, value) {
      result.addAll(_processValue(key, value));
    });
    result.sort();
    return result.join('&');
  }

  List<String> _processValue(String prefix, Object? value) {
    final result = <String>[];
    if (value is Map) {
      value.forEach((k, nested) {
        final nestedPrefix = '$prefix.${k.toString()}';
        result.addAll(_processValue(nestedPrefix, nested));
      });
      return result;
    }

    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final nestedPrefix = '$prefix[$i]';
        result.addAll(_processValue(nestedPrefix, value[i]));
      }
      return result;
    }

    if (value == null) {
      return result;
    }

    result.add('$prefix=${_stringifyValue(value)}');
    return result;
  }

  String _stringifyValue(Object value) {
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    if (value is double) {
      if (value.isFinite && value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return value.toString();
  }
}
