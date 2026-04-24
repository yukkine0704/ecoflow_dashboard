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

  static Map<String, dynamic>? inspectProtobufFrame(List<int>? rawPayloadBytes) {
    if (rawPayloadBytes == null || rawPayloadBytes.isEmpty) {
      return null;
    }
    final bytes = rawPayloadBytes;
    final headers = _extractHeaderMessages(bytes);
    if (headers.isEmpty) {
      return null;
    }
    final out = <String, dynamic>{
      'headerCount': headers.length,
      'headers': <Map<String, dynamic>>[],
    };
    final headerOut = out['headers'] as List<Map<String, dynamic>>;
    for (final headerBytes in headers) {
      final envelope = _parseHeaderEnvelope(headerBytes);
      final pdata = envelope.pdata ?? const <int>[];
      final info = <String, dynamic>{
        'cmdFunc': envelope.cmdFunc,
        'cmdId': envelope.cmdId,
        'encType': envelope.encType,
        'seq': envelope.seq,
        'dataLen': envelope.dataLen,
        'pdataLen': pdata.length,
        'pdataHexPreview': _hexPreview(pdata, limit: 64),
        'pdataAsciiPreview': _asciiPreview(pdata, limit: 64),
      };
      if (envelope.encType == 1 && envelope.seq != 0 && pdata.isNotEmpty) {
        final xor = _xorWithSeqByte(pdata, envelope.seq);
        info['xorHexPreview'] = _hexPreview(xor, limit: 64);
        info['xorAsciiPreview'] = _asciiPreview(xor, limit: 64);
      }
      headerOut.add(info);
    }
    return out;
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
    var headers = _extractHeaderMessages(bytes);
    if (headers.isEmpty) {
      headers = _scanLikelyHeaderMessages(bytes);
    }
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

    final embeddedJson = _tryDecodeJsonSubstringFromBytes(bytes);
    if (embeddedJson != null) {
      return embeddedJson;
    }

    return null;
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

    final decoded = _decodePdataToMap(
      pdata: envelope.pdata!,
      encType: envelope.encType,
      seq: envelope.seq,
    );
    if (decoded != null && decoded.isNotEmpty) {
      return decoded;
    }

    // These frames are frequent control/ack packets in app MQTT and tend to
    // produce noisy numeric candidates rather than stable telemetry.
    if (envelope.cmdFunc == 254 && envelope.cmdId == 21) {
      return null;
    }

    final numeric = _extractNumericTelemetryFromBytes(envelope.pdata!);
    if (numeric.isEmpty) {
      return null;
    }

    // cmdId=50 tends to be fuller state snapshots; cmdId=2 is often partial.
    // Keep SOC from partial packets but avoid unstable online flips.
    if (envelope.cmdId != 50) {
      numeric.remove('online');
    }

    numeric['_cmdFunc'] = envelope.cmdFunc;
    numeric['_cmdId'] = envelope.cmdId;
    numeric['_encType'] = envelope.encType;
    numeric['_seq'] = envelope.seq;
    return numeric;
  }

  static _HeaderEnvelope _parseHeaderEnvelope(List<int> headerBytes) {
    List<int>? pdata;
    var encType = 0;
    var seq = 0;
    var cmdFunc = 0;
    var cmdId = 0;
    var dataLen = 0;

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

      if (wireType == 0 &&
          (field == 6 || field == 8 || field == 9 || field == 10 || field == 14)) {
        final value = _readVarint(headerBytes, offset);
        if (value == null) {
          break;
        }
        offset = value.nextOffset;
        if (field == 6) {
          encType = value.value;
        } else if (field == 8) {
          cmdFunc = value.value;
        } else if (field == 9) {
          cmdId = value.value;
        } else if (field == 10) {
          dataLen = value.value;
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
      cmdFunc: cmdFunc,
      cmdId: cmdId,
      dataLen: dataLen,
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
    final directEmbeddedJson = _tryDecodeJsonSubstringFromBytes(pdata);
    if (directEmbeddedJson != null) {
      return directEmbeddedJson;
    }

    if (encType == 1 && seq != 0) {
      final xorBySeq = _xorWithSeqByte(pdata, seq);
      final xorBySeqJson = _tryDecodeJsonFromBytes(xorBySeq);
      if (xorBySeqJson != null) {
        return xorBySeqJson;
      }
      final xorEmbeddedJson = _tryDecodeJsonSubstringFromBytes(xorBySeq);
      if (xorEmbeddedJson != null) {
        return xorEmbeddedJson;
      }

      final seqBytes = <int>[
        seq & 0xFF,
        (seq >> 8) & 0xFF,
        (seq >> 16) & 0xFF,
        (seq >> 24) & 0xFF,
      ];
      final xorBySeqBytes = _xorWithRepeatingKey(pdata, seqBytes);
      final xorBySeqBytesJson = _tryDecodeJsonFromBytes(xorBySeqBytes);
      if (xorBySeqBytesJson != null) {
        return xorBySeqBytesJson;
      }
      final xorBySeqBytesEmbedded =
          _tryDecodeJsonSubstringFromBytes(xorBySeqBytes);
      if (xorBySeqBytesEmbedded != null) {
        return xorBySeqBytesEmbedded;
      }
    }

    return null;
  }

  static List<int> _xorWithRepeatingKey(List<int> input, List<int> keyBytes) {
    if (input.isEmpty || keyBytes.isEmpty) {
      return input;
    }
    final out = List<int>.filled(input.length, 0);
    for (var i = 0; i < input.length; i++) {
      out[i] = input[i] ^ keyBytes[i % keyBytes.length];
    }
    return out;
  }

  static List<List<int>> _scanLikelyHeaderMessages(List<int> bytes) {
    final headers = <List<int>>[];
    for (var i = 0; i < bytes.length - 2; i++) {
      if (bytes[i] != 0x0A) {
        continue;
      }
      final lengthValue = _readVarint(bytes, i + 1);
      if (lengthValue == null) {
        continue;
      }
      final length = lengthValue.value;
      if (length <= 0) {
        continue;
      }
      final start = lengthValue.nextOffset;
      final end = start + length;
      if (end > bytes.length) {
        continue;
      }
      headers.add(bytes.sublist(start, end));
    }
    return headers;
  }

  static Map<String, dynamic>? _tryDecodeJsonSubstringFromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final start = bytes.indexOf(0x7B); // {
    final end = bytes.lastIndexOf(0x7D); // }
    if (start < 0 || end < 0 || end <= start) {
      return null;
    }
    try {
      final text = utf8.decode(bytes.sublist(start, end + 1));
      return _decodeJsonMap(text);
    } catch (_) {
      return null;
    }
  }

  static String _hexPreview(List<int> bytes, {int limit = 64}) {
    final max = bytes.length < limit ? bytes.length : limit;
    return bytes
        .take(max)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _asciiPreview(List<int> bytes, {int limit = 64}) {
    final max = bytes.length < limit ? bytes.length : limit;
    final buffer = StringBuffer();
    for (var i = 0; i < max; i++) {
      final b = bytes[i];
      if (b >= 32 && b <= 126) {
        buffer.writeCharCode(b);
      } else {
        buffer.write('.');
      }
    }
    return buffer.toString();
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
    final estimatedPower = _pickEstimatedPowers(varints);
    final estimatedTemp = _pickEstimatedTemperature(varints, fixed32s);

    if (batteryCandidate == null &&
        onlineCandidate == null &&
        estimatedPower == null &&
        estimatedTemp == null) {
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
    if (estimatedPower != null) {
      if (estimatedPower.inputW != null) {
        out['inPower'] = estimatedPower.inputW;
      }
      if (estimatedPower.outputW != null) {
        out['outPower'] = estimatedPower.outputW;
      }
    }
    if (estimatedTemp != null) {
      out['temp'] = estimatedTemp;
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
    final nestedPriority = _pickNestedBatteryCandidate(varints);
    if (nestedPriority != null) {
      return nestedPriority;
    }

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

  static _BatteryCandidate? _pickNestedBatteryCandidate(
    List<_NumericFieldEntry> varints,
  ) {
    bool inPrimaryNested(_NumericFieldEntry e) =>
        e.path.length >= 2 && e.path[e.path.length - 2] == 1;

    final orderedFields = <int>[9, 7, 10, 11];
    for (final field in orderedFields) {
      final match = varints.where((e) {
        if (!inPrimaryNested(e)) {
          return false;
        }
        if (e.field != field) {
          return false;
        }
        return e.value >= 6 && e.value <= 100;
      }).toList();
      if (match.isNotEmpty) {
        final picked = match.last.value.round();
        return _BatteryCandidate(
          value: picked,
          field: field,
          confidence: field == 9 ? 'high' : 'medium',
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

  static _EstimatedPower? _pickEstimatedPowers(List<_NumericFieldEntry> varints) {
    final milliWatts = varints
        .where((e) => e.value >= 1000 && e.value <= 200000)
        .map((e) => e.value)
        .toList()
      ..sort();

    if (milliWatts.isEmpty) {
      return null;
    }

    final outputW = milliWatts.last / 1000.0;
    final inputW = milliWatts.length >= 2 ? milliWatts[milliWatts.length - 2] / 1000.0 : null;
    return _EstimatedPower(inputW: inputW, outputW: outputW);
  }

  static double? _pickEstimatedTemperature(
    List<_NumericFieldEntry> varints,
    List<_NumericFieldEntry> fixed32s,
  ) {
    for (final entry in fixed32s) {
      final asFloat = _floatFromUint32(entry.value.toInt());
      if (asFloat != null && asFloat >= -30 && asFloat <= 100) {
        return asFloat;
      }
    }

    for (final entry in varints) {
      final value = entry.value;
      if (value >= 15 && value <= 80) {
        return value;
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
    required this.cmdFunc,
    required this.cmdId,
    required this.dataLen,
  });

  final List<int>? pdata;
  final int encType;
  final int seq;
  final int cmdFunc;
  final int cmdId;
  final int dataLen;
}

class _EstimatedPower {
  const _EstimatedPower({required this.inputW, required this.outputW});

  final double? inputW;
  final double? outputW;
}
