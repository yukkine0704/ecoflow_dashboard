import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String? _stringifyValue(Object? value) {
  if (value is String) return value;
  if (value is num && value.isFinite) return value.toString();
  if (value is bool) return value ? 'true' : 'false';
  return null;
}

List<String> _processValue(String prefix, Object? value) {
  if (value == null) return const <String>[];
  if (value is List) {
    return <String>[
      for (var i = 0; i < value.length; i++)
        ..._processValue('$prefix[$i]', value[i]),
    ];
  }
  if (value is Map) {
    return <String>[
      for (final entry in value.entries)
        ..._processValue('$prefix.${entry.key}', entry.value),
    ];
  }
  final raw = _stringifyValue(value);
  if (raw == null) return const <String>[];
  return <String>['$prefix=$raw'];
}

String generateSignedQuery([Map<String, Object?>? params]) {
  if (params == null || params.isEmpty) return '';
  final parts = <String>[];
  for (final entry in params.entries) {
    parts.addAll(_processValue(entry.key, entry.value));
  }
  parts.sort();
  return parts.join('&');
}

Map<String, String> createSignedHeaders({
  required String accessKey,
  required String secretKey,
  Map<String, Object?>? params,
  Random? random,
  DateTime? now,
}) {
  final generator = random ?? Random.secure();
  final nonce = (100000 + generator.nextInt(900000)).toString();
  // Keep parity with the working Node bridge: EcoFlow Open API accepted the
  // bridge's nanosecond-style timestamp for `/iot-open/sign/*` requests.
  final timestamp =
      '${(now ?? DateTime.now()).millisecondsSinceEpoch * 1000000}';
  final query = generateSignedQuery(params);
  final suffix = 'accessKey=$accessKey&nonce=$nonce&timestamp=$timestamp';
  final base = query.isEmpty ? suffix : '$query&$suffix';
  final sign = Hmac(
    sha256,
    utf8.encode(secretKey),
  ).convert(utf8.encode(base)).toString();
  return <String, String>{
    'accessKey': accessKey,
    'nonce': nonce,
    'timestamp': timestamp,
    'sign': sign,
    'Content-Type': 'application/json',
  };
}
