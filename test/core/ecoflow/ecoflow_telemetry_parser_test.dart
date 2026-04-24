import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_telemetry_parser.dart';

void main() {
  group('EcoFlowTelemetryParser', () {
    test('parses payload.params envelope', () {
      const raw = '{"params":{"soc":"83","status":1}}';
      final parsed = EcoFlowTelemetryParser.parseMessagePayload(raw);

      expect(parsed.batteryPercent, 83);
      expect(parsed.online, isTrue);
    });

    test('parses payload.data.params envelope', () {
      const raw = '{"data":{"params":{"pd.soc":52,"online":"false"}}}';
      final parsed = EcoFlowTelemetryParser.parseMessagePayload(raw);

      expect(parsed.batteryPercent, 52);
      expect(parsed.online, isFalse);
    });

    test('parses plain payload map', () {
      const raw = '{"cmsBattSoc":"72%","isOnline":"on"}';
      final parsed = EcoFlowTelemetryParser.parseMessagePayload(raw);

      expect(parsed.batteryPercent, 72);
      expect(parsed.online, isTrue);
    });

    test('parses protobuf payload from raw bytes', () {
      final jsonPayload = utf8.encode('{"soc":64,"online":1}');
      final protoBytes = _buildHeaderMessage(jsonPayload);

      final parsed = EcoFlowTelemetryParser.parseMessagePayload(
        '',
        rawPayloadBytes: protoBytes,
      );

      expect(parsed.batteryPercent, 64);
      expect(parsed.online, isTrue);
    });

    test('parses xor-encrypted protobuf payload from raw bytes', () {
      const seq = 37;
      final key = seq & 0xFF;
      final plain = utf8.encode('{"pd.soc":41,"status":"offline"}');
      final encrypted = plain.map((b) => b ^ key).toList();
      final protoBytes = _buildHeaderMessage(encrypted, encType: 1, seq: seq);

      final parsed = EcoFlowTelemetryParser.parseMessagePayload(
        '',
        rawPayloadBytes: protoBytes,
      );

      expect(parsed.batteryPercent, 41);
      expect(parsed.online, isFalse);
    });

    test('ignores protobuf payload when no json params are present', () {
      final bytes = _buildNestedNumericSample();
      final parsed = EcoFlowTelemetryParser.parseMessagePayload(
        '',
        rawPayloadBytes: bytes,
      );

      expect(parsed.payload, isNull);
      expect(parsed.params, isNull);
      expect(parsed.batteryPercent, isNull);
      expect(parsed.online, isNull);
    });
  });
}

List<int> _buildHeaderMessage(
  List<int> pdata, {
  int encType = 0,
  int seq = 0,
}) {
  final header = <int>[];

  header.addAll(_encodeVarint((1 << 3) | 2));
  header.addAll(_encodeVarint(pdata.length));
  header.addAll(pdata);

  header.addAll(_encodeVarint(6 << 3));
  header.addAll(_encodeVarint(encType));

  header.addAll(_encodeVarint(14 << 3));
  header.addAll(_encodeVarint(seq));

  final message = <int>[];
  message.addAll(_encodeVarint((1 << 3) | 2));
  message.addAll(_encodeVarint(header.length));
  message.addAll(header);
  return message;
}

List<int> _encodeVarint(int value) {
  var n = value;
  final out = <int>[];
  while (true) {
    if ((n & ~0x7F) == 0) {
      out.add(n);
      return out;
    }
    out.add((n & 0x7F) | 0x80);
    n >>= 7;
  }
}

List<int> _buildNestedNumericSample() {
  final telemetry = <int>[];
  telemetry.addAll(_fieldVarint(2, 1));
  telemetry.addAll(_fieldVarint(3, 1));
  telemetry.addAll(_fieldVarint(7, 95));
  telemetry.addAll(_fieldVarint(8, 3));

  final level2 = <int>[];
  level2.addAll(_fieldLength(1, telemetry));

  final level1 = <int>[];
  level1.addAll(_fieldLength(1, level2));

  final root = <int>[];
  root.addAll(_fieldLength(1, level1));
  return root;
}

List<int> _fieldVarint(int field, int value) {
  return <int>[
    ..._encodeVarint(field << 3),
    ..._encodeVarint(value),
  ];
}

List<int> _fieldLength(int field, List<int> payload) {
  return <int>[
    ..._encodeVarint((field << 3) | 2),
    ..._encodeVarint(payload.length),
    ...payload,
  ];
}
