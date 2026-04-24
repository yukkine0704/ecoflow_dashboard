import 'dart:convert';
import 'dart:typed_data';

class EcoFlowTelemetryParseResult {
  const EcoFlowTelemetryParseResult({
    required this.payload,
    required this.params,
    required this.batteryPercent,
    required this.online,
  });

  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? params;
  final int? batteryPercent;
  final bool? online;
}

class EcoFlowTelemetryParser {
  const EcoFlowTelemetryParser._();

  static EcoFlowTelemetryParseResult parseMessagePayload(
    String payloadRaw, {
    List<int>? rawPayloadBytes,
  }) {
    final payload = decodePayload(payloadRaw, rawPayloadBytes: rawPayloadBytes);
    final params = extractPayloadParams(payload);
    final batteryPercent = params == null ? null : extractBatteryPercent(params);
    final online = params == null ? null : extractStatus(params);
    return EcoFlowTelemetryParseResult(
      payload: payload,
      params: params,
      batteryPercent: batteryPercent,
      online: online,
    );
  }

  static Map<String, dynamic>? decodePayload(
    String payloadRaw, {
    List<int>? rawPayloadBytes,
  }) {
    final fromText = _decodeJsonMap(payloadRaw);
    if (fromText != null) {
      return fromText;
    }

    if (rawPayloadBytes == null || rawPayloadBytes.isEmpty) {
      return null;
    }

    final fromRawJson = _tryDecodeJsonFromBytes(rawPayloadBytes);
    if (fromRawJson != null) {
      return fromRawJson;
    }

    final fromProtobuf = _decodeProtobufPayload(rawPayloadBytes);
    if (fromProtobuf != null && fromProtobuf.isNotEmpty) {
      return fromProtobuf;
    }
    return null;
  }

  static Map<String, dynamic>? _decodeJsonMap(String payloadRaw) {
    final trimmed = payloadRaw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryDecodeJsonFromBytes(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      return _decodeJsonMap(text);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeProtobufPayload(List<int> bytes) {
    final headers = _extractHeaderMessages(bytes);
    if (headers.isEmpty) {
      return null;
    }

    final merged = <String, dynamic>{};
    for (final headerBytes in headers) {
      final decoded = _decodeHeaderPdata(headerBytes);
      if (decoded == null || decoded.isEmpty) {
        continue;
      }
      merged.addAll(decoded);
    }

    if (merged.isNotEmpty) {
      return merged;
    }
    final numericFallback = _extractNumericTelemetryFromBytes(bytes);
    if (numericFallback.isNotEmpty) {
      return numericFallback;
    }
    return <String, dynamic>{
      '_format': 'protobuf_unparsed',
      '_headerCount': headers.length,
      '_rawHexPreview': _hexPreview(bytes),
    };
  }

  static List<List<int>> _extractHeaderMessages(List<int> bytes) {
    final headers = <List<int>>[];
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      if (tag == null) {
        break;
      }
      offset = tag.nextOffset;
      final field = tag.value >> 3;
      final wireType = tag.value & 0x07;
      if (field == 1 && wireType == 2) {
        final lengthValue = _readVarint(bytes, offset);
        if (lengthValue == null) {
          break;
        }
        offset = lengthValue.nextOffset;
        final length = lengthValue.value;
        if (length < 0 || offset + length > bytes.length) {
          break;
        }
        headers.add(bytes.sublist(offset, offset + length));
        offset += length;
        continue;
      }

      offset = _skipWire(bytes, offset, wireType);
      if (offset < 0) {
        break;
      }
    }
    return headers;
  }

  static Map<String, dynamic>? _decodeHeaderPdata(List<int> headerBytes) {
    final envelope = _parseHeaderEnvelope(headerBytes);
    if (envelope.pdata == null || envelope.pdata!.isEmpty) {
      return null;
    }

    return _decodePdataToMap(
      pdata: envelope.pdata!,
      encType: envelope.encType,
      seq: envelope.seq,
    );
  }

  static _HeaderEnvelope _parseHeaderEnvelope(List<int> headerBytes) {
    List<int>? pdata;
    var encType = 0;
    var seq = 0;

    var offset = 0;
    while (offset < headerBytes.length) {
      final tag = _readVarint(headerBytes, offset);
      if (tag == null) {
        break;
      }
      offset = tag.nextOffset;
      final field = tag.value >> 3;
      final wireType = tag.value & 0x07;

      if (field == 1 && wireType == 2) {
        final lengthValue = _readVarint(headerBytes, offset);
        if (lengthValue == null) {
          break;
        }
        offset = lengthValue.nextOffset;
        final length = lengthValue.value;
        if (length < 0 || offset + length > headerBytes.length) {
          break;
        }
        pdata = headerBytes.sublist(offset, offset + length);
        offset += length;
        continue;
      }

      if (wireType == 0 && (field == 6 || field == 14)) {
        final value = _readVarint(headerBytes, offset);
        if (value == null) {
          break;
        }
        offset = value.nextOffset;
        if (field == 6) {
          encType = value.value;
        } else if (field == 14) {
          seq = value.value;
        }
        continue;
      }

      offset = _skipWire(headerBytes, offset, wireType);
      if (offset < 0) {
        break;
      }
    }

    return _HeaderEnvelope(
      pdata: pdata,
      encType: encType,
      seq: seq,
    );
  }

  static List<int> _xorWithSeqByte(List<int> input, int seq) {
    final key = seq & 0xFF;
    return input.map((b) => b ^ key).toList();
  }

  static Map<String, dynamic>? _decodePdataToMap({
    required List<int> pdata,
    required int encType,
    required int seq,
  }) {
    final directJson = _tryDecodeJsonFromBytes(pdata);
    if (directJson != null) {
      return directJson;
    }

    if (encType == 1 && seq != 0) {
      final xorBySeq = _xorWithSeqByte(pdata, seq);
      final xorBySeqJson = _tryDecodeJsonFromBytes(xorBySeq);
      if (xorBySeqJson != null) {
        return xorBySeqJson;
      }
    }

    return null;
  }

  static String _hexPreview(List<int> bytes, {int limit = 64}) {
    final max = bytes.length < limit ? bytes.length : limit;
    return bytes
        .take(max)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Map<String, dynamic> _extractNumericTelemetryFromBytes(List<int> bytes) {
    final entries = <_NumericFieldEntry>[];
    _walkNumericFields(
      bytes,
      entries: entries,
      path: const <int>[],
      maxDepth: 6,
    );
    if (entries.isEmpty) {
      return const <String, dynamic>{};
    }

    final varints = entries.where((e) => e.kind == _NumericKind.varint).toList();
    final fixed32s = entries.where((e) => e.kind == _NumericKind.fixed32).toList();

    final batteryCandidate = _pickBatteryCandidate(varints, fixed32s);
    final onlineCandidate = _pickOnlineCandidate(varints);

    if (batteryCandidate == null && onlineCandidate == null) {
      return const <String, dynamic>{};
    }

    final out = <String, dynamic>{
      '_format': 'protobuf_numeric',
      '_numericCount': entries.length,
      '_rawHexPreview': _hexPreview(bytes),
    };
    if (batteryCandidate != null) {
      out['soc'] = batteryCandidate.value;
      out['_socField'] = batteryCandidate.field;
      out['_socConfidence'] = batteryCandidate.confidence;
    }
    if (onlineCandidate != null) {
      out['online'] = onlineCandidate ? 1 : 0;
    }
    return out;
  }

  static void _walkNumericFields(
    List<int> bytes, {
    required List<_NumericFieldEntry> entries,
    required List<int> path,
    required int maxDepth,
  }) {
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      if (tag == null) {
        break;
      }
      offset = tag.nextOffset;
      final field = tag.value >> 3;
      final wireType = tag.value & 0x07;
      final nextPath = <int>[...path, field];

      if (wireType == 0) {
        final value = _readVarint(bytes, offset);
        if (value == null) {
          break;
        }
        offset = value.nextOffset;
        entries.add(
          _NumericFieldEntry(
            path: nextPath,
            field: field,
            kind: _NumericKind.varint,
            value: value.value.toDouble(),
          ),
        );
        continue;
      }

      if (wireType == 5) {
        if (offset + 4 > bytes.length) {
          break;
        }
        final b0 = bytes[offset];
        final b1 = bytes[offset + 1];
        final b2 = bytes[offset + 2];
        final b3 = bytes[offset + 3];
        offset += 4;
        final value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        entries.add(
          _NumericFieldEntry(
            path: nextPath,
            field: field,
            kind: _NumericKind.fixed32,
            value: value.toDouble(),
          ),
        );
        continue;
      }

      if (wireType == 2) {
        final lengthValue = _readVarint(bytes, offset);
        if (lengthValue == null) {
          break;
        }
        offset = lengthValue.nextOffset;
        final length = lengthValue.value;
        if (length < 0 || offset + length > bytes.length) {
          break;
        }
        final payload = bytes.sublist(offset, offset + length);
        offset += length;
        if (maxDepth > 0) {
          _walkNumericFields(
            payload,
            entries: entries,
            path: nextPath,
            maxDepth: maxDepth - 1,
          );
        }
        continue;
      }

      offset = _skipWire(bytes, offset, wireType);
      if (offset < 0) {
        break;
      }
    }
  }

  static _BatteryCandidate? _pickBatteryCandidate(
    List<_NumericFieldEntry> varints,
    List<_NumericFieldEntry> fixed32s,
  ) {
    const preferredVarintFields = <int>[10, 9, 11, 12, 7, 6, 8];
    for (final field in preferredVarintFields) {
      final candidate = varints
          .where((e) => e.field == field && e.value >= 6 && e.value <= 100)
          .toList();
      if (candidate.isNotEmpty) {
        final picked = candidate.last.value.round();
        final confidence = field == 10
            ? 'high'
            : (field == 9 ? 'medium' : 'medium');
        return _BatteryCandidate(
          value: picked,
          field: field,
          confidence: confidence,
        );
      }
    }

    final anyVarint = varints.where((e) => e.value >= 6 && e.value <= 100).toList();
    if (anyVarint.isNotEmpty) {
      return _BatteryCandidate(
        value: anyVarint.last.value.round(),
        field: anyVarint.last.field,
        confidence: 'low',
      );
    }

    for (final entry in fixed32s) {
      final asFloat = _floatFromUint32(entry.value.toInt());
      if (asFloat != null && asFloat >= 0 && asFloat <= 100) {
        final value = asFloat.round();
        if (value <= 5) {
          continue;
        }
        return _BatteryCandidate(
          value: value,
          field: entry.field,
          confidence: 'low',
        );
      }
    }
    return null;
  }

  static bool? _pickOnlineCandidate(List<_NumericFieldEntry> varints) {
    const preferredFields = <int>[2, 3, 4, 6, 16, 17];
    for (final field in preferredFields) {
      final candidate = varints.where((e) => e.field == field).toList();
      if (candidate.isEmpty) {
        continue;
      }
      final value = candidate.last.value.round();
      if (value == 0) {
        return false;
      }
      if (value == 1 || value == 2) {
        return true;
      }
    }
    return null;
  }

  static double? _floatFromUint32(int raw) {
    try {
      final data = ByteData(4)..setUint32(0, raw, Endian.little);
      final value = data.getFloat32(0, Endian.little);
      if (value.isFinite) {
        return value;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static _VarintRead? _readVarint(List<int> bytes, int offset) {
    var result = 0;
    var shift = 0;
    var index = offset;
    while (index < bytes.length && shift <= 63) {
      final byte = bytes[index];
      result |= (byte & 0x7F) << shift;
      index += 1;
      if ((byte & 0x80) == 0) {
        return _VarintRead(value: result, nextOffset: index);
      }
      shift += 7;
    }
    return null;
  }

  static int _skipWire(List<int> bytes, int offset, int wireType) {
    switch (wireType) {
      case 0:
        final value = _readVarint(bytes, offset);
        return value?.nextOffset ?? -1;
      case 1:
        return offset + 8 <= bytes.length ? offset + 8 : -1;
      case 2:
        final lengthValue = _readVarint(bytes, offset);
        if (lengthValue == null) {
          return -1;
        }
        final next = lengthValue.nextOffset + lengthValue.value;
        return next <= bytes.length ? next : -1;
      case 5:
        return offset + 4 <= bytes.length ? offset + 4 : -1;
      default:
        return -1;
    }
  }

  static Map<String, dynamic>? extractPayloadParams(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final directParams = _toMap(payload['params']);
    if (directParams != null) {
      return directParams;
    }

    final data = _toMap(payload['data']);
    final dataParams = _toMap(data?['params']);
    if (dataParams != null) {
      return dataParams;
    }

    return payload;
  }

  static bool? extractStatus(Map<String, dynamic> params) {
    final raw = _pickFirst(
      params,
      const ['status', 'online', 'isOnline', 'deviceOnline', 'switchStatus'],
    );
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == '1' ||
          normalized == 'true' ||
          normalized == 'online' ||
          normalized == 'on') {
        return true;
      }
      if (normalized == '0' ||
          normalized == 'false' ||
          normalized == 'offline' ||
          normalized == 'off') {
        return false;
      }
    }
    return null;
  }

  static int? extractBatteryPercent(Map<String, dynamic> params) {
    final raw = _pickFirst(
      params,
      const ['soc', 'pd.soc', 'cmsBattSoc', 'bmsBattSoc', 'batterySoc'],
    );
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.round();
    }
    if (raw is String) {
      final cleaned = raw.replaceAll('%', '').trim();
      final parsed = int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
      return parsed;
    }
    return null;
  }

  static Map<String, dynamic>? redactPayload(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final redacted = <String, dynamic>{};
    payload.forEach((key, value) {
      final normalizedKey = key.toLowerCase();
      if (normalizedKey.contains('password') ||
          normalizedKey.contains('token') ||
          normalizedKey.contains('secret')) {
        redacted[key] = '***redacted***';
        return;
      }
      if (value is Map) {
        redacted[key] = redactPayload(_toMap(value));
        return;
      }
      if (value is List) {
        redacted[key] = value
            .map((item) => item is Map ? redactPayload(_toMap(item)) : item)
            .toList();
        return;
      }
      redacted[key] = value;
    });
    return redacted;
  }

  static Object? _pickFirst(Map<String, dynamic> params, List<String> keys) {
    for (final key in keys) {
      if (params.containsKey(key)) {
        final value = params[key];
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}

class _VarintRead {
  const _VarintRead({required this.value, required this.nextOffset});

  final int value;
  final int nextOffset;
}

enum _NumericKind { varint, fixed32 }

class _NumericFieldEntry {
  const _NumericFieldEntry({
    required this.path,
    required this.field,
    required this.kind,
    required this.value,
  });

  final List<int> path;
  final int field;
  final _NumericKind kind;
  final double value;
}

class _BatteryCandidate {
  const _BatteryCandidate({
    required this.value,
    required this.field,
    required this.confidence,
  });

  final int value;
  final int field;
  final String confidence;
}

class _HeaderEnvelope {
  const _HeaderEnvelope({
    required this.pdata,
    required this.encType,
    required this.seq,
  });

  final List<int>? pdata;
  final int encType;
  final int seq;
}
