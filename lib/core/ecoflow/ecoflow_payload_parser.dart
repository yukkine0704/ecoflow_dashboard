import 'dart:convert';
import 'dart:typed_data';

class EcoFlowPayloadParseResult {
  const EcoFlowPayloadParseResult({
    required this.payload,
    required this.params,
    required this.envelope,
    required this.debug,
  });

  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? params;
  final EcoFlowPayloadEnvelope? envelope;
  final EcoFlowPayloadDebug debug;
}

class EcoFlowPayloadEnvelope {
  const EcoFlowPayloadEnvelope({
    required this.cmdFunc,
    required this.cmdId,
    required this.encType,
    required this.src,
  });

  final int cmdFunc;
  final int cmdId;
  final int encType;
  final int src;
}

class EcoFlowPayloadDebug {
  const EcoFlowPayloadDebug({
    required this.mode,
    required this.preview,
    required this.hex,
  });

  final String mode;
  final String preview;
  final String hex;
}

class _VarintRead {
  const _VarintRead(this.value, this.nextOffset);

  final int value;
  final int nextOffset;
}

_VarintRead? _readVarint(Uint8List bytes, int offset) {
  var result = 0;
  var factor = 1;
  var index = offset;
  while (index < bytes.length) {
    final byte = bytes[index];
    result += (byte & 0x7f) * factor;
    index += 1;
    if ((byte & 0x80) == 0) return _VarintRead(result, index);
    factor *= 128;
  }
  return null;
}

int _skipWire(Uint8List bytes, int offset, int wireType) {
  switch (wireType) {
    case 0:
      return _readVarint(bytes, offset)?.nextOffset ?? -1;
    case 1:
      return offset + 8 <= bytes.length ? offset + 8 : -1;
    case 2:
      final len = _readVarint(bytes, offset);
      if (len == null) return -1;
      final next = len.nextOffset + len.value;
      return next <= bytes.length ? next : -1;
    case 5:
      return offset + 4 <= bytes.length ? offset + 4 : -1;
    default:
      return -1;
  }
}

String _toUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return '';
  }
}

Map<String, dynamic>? _decodeJsonMap(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, dynamic>? _decodeJsonFromBytes(Uint8List bytes) {
  return _decodeJsonMap(_toUtf8(bytes));
}

Map<String, dynamic>? _decodeJsonSubstringFromBytes(Uint8List bytes) {
  final text = _toUtf8(bytes);
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end < 0 || end <= start) return null;
  return _decodeJsonMap(text.substring(start, end + 1));
}

Uint8List _xorWithKey(Uint8List bytes, int key) {
  final out = Uint8List(bytes.length);
  final k = key & 0xff;
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ k;
  }
  return out;
}

Uint8List _xorWithRollingKey(Uint8List bytes, List<int> keys) {
  if (keys.isEmpty) return Uint8List.fromList(bytes);
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ (keys[i % keys.length] & 0xff);
  }
  return out;
}

List<Uint8List> _buildEncCandidates(
  Uint8List pdata,
  int seq,
  int encType,
  int src,
) {
  final candidates = <Uint8List>[pdata];
  if (encType != 1 || seq == 0) return candidates;
  final seen = <String>{_toHex(pdata)};
  void pushUnique(Uint8List candidate) {
    final key = _toHex(candidate);
    if (seen.add(key)) candidates.add(candidate);
  }

  if (src != 32) pushUnique(_xorWithKey(pdata, seq));
  final seqBytes = <int>[
    seq & 0xff,
    (seq >> 8) & 0xff,
    (seq >> 16) & 0xff,
    (seq >> 24) & 0xff,
  ];
  for (final key in seqBytes) {
    pushUnique(_xorWithKey(pdata, key));
  }
  pushUnique(_xorWithRollingKey(pdata, seqBytes));
  pushUnique(_xorWithRollingKey(pdata, seqBytes.take(2).toList()));
  if (src != 32) {
    for (var key = 0; key <= 0xff; key++) {
      pushUnique(_xorWithKey(pdata, key));
    }
  }
  return candidates;
}

String _toHex(Uint8List bytes, [int? maxLength]) {
  final len = maxLength == null
      ? bytes.length
      : (bytes.length < maxLength ? bytes.length : maxLength);
  final buffer = StringBuffer();
  for (var i = 0; i < len; i++) {
    buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

double? _readFixed32Float(Uint8List bytes, int offset) {
  if (offset + 4 > bytes.length) return null;
  final view = ByteData.sublistView(bytes, offset, offset + 4);
  return view.getFloat32(0, Endian.little);
}

Map<int, List<Object>> _extractTopLevelFields(Uint8List bytes) {
  final out = <int, List<Object>>{};
  var offset = 0;
  while (offset < bytes.length) {
    final tag = _readVarint(bytes, offset);
    if (tag == null) break;
    offset = tag.nextOffset;
    final field = tag.value >> 3;
    final wireType = tag.value & 0x07;
    if (wireType == 0) {
      final val = _readVarint(bytes, offset);
      if (val == null) break;
      offset = val.nextOffset;
      (out[field] ??= <Object>[]).add(val.value);
      continue;
    }
    if (wireType == 5) {
      final floatValue = _readFixed32Float(bytes, offset);
      if (floatValue == null) break;
      offset += 4;
      (out[field] ??= <Object>[]).add(floatValue);
      continue;
    }
    if (wireType == 2) {
      final len = _readVarint(bytes, offset);
      if (len == null) break;
      offset = len.nextOffset;
      final end = offset + len.value;
      if (len.value < 0 || end > bytes.length) break;
      final chunk = Uint8List.sublistView(bytes, offset, end);
      offset = end;
      final text = _toUtf8(chunk).trim();
      if (text.isNotEmpty && RegExp(r'^[\x20-\x7E]+$').hasMatch(text)) {
        (out[field] ??= <Object>[]).add(text);
      }
      continue;
    }
    offset = _skipWire(bytes, offset, wireType);
    if (offset < 0) break;
  }
  return out;
}

num? _getNumber(Map<int, List<Object>> fields, int field) {
  final values = fields[field];
  if (values == null || values.isEmpty) return null;
  final last = values.last;
  if (last is num && last.isFinite) return last;
  return null;
}

Map<String, dynamic>? _extractKnownTelemetryFromProto(
  Uint8List pdata,
  ({int cmdId, int cmdFunc}) envelope,
) {
  final fields = _extractTopLevelFields(pdata);
  if (fields.isEmpty) return null;
  final out = <String, dynamic>{};
  if (envelope.cmdFunc == 32 && envelope.cmdId == 50) {
    final map = <int, String>{
      6: 'bms.soc',
      9: 'bms.temp',
      18: 'bms.maxCellTemp',
      25: 'bms.f32ShowSoc',
      26: 'bms.inputWatts',
      27: 'bms.outputWatts',
    };
    for (final entry in map.entries) {
      final value = _getNumber(fields, entry.key);
      if (value != null) out[entry.value] = value;
    }
  }
  if (envelope.cmdFunc == 254 && envelope.cmdId == 22) {
    final map = <int, String>{
      26: 'pd.tempPcsDc',
      27: 'pd.tempPcsAc',
      379: 'pd.tempPv',
    };
    for (final entry in map.entries) {
      final value = _getNumber(fields, entry.key);
      if (value != null) out[entry.value] = value;
    }
  }
  if (envelope.cmdFunc == 254 && envelope.cmdId == 21) {
    final map = <int, String>{
      3: 'pd.inputWatts',
      4: 'pd.outputWatts',
      35: 'pd.powGetPvH',
      36: 'pd.powGetPvL',
      37: 'pd.powGet12v',
      53: 'pd.powGetAc',
      54: 'pd.powGetAcIn',
      77: 'pd.powGetDcp2',
      158: 'pd.powGetBms',
      242: 'pd.bmsBattSoc',
      258: 'pd.bmsMinCellTemp',
      259: 'pd.bmsMaxCellTemp',
      262: 'pd.cmsBattSoc',
      361: 'pd.powGetPv',
      368: 'pd.powGetAcOut',
      425: 'pd.powGetDcp',
    };
    for (final entry in map.entries) {
      final value = _getNumber(fields, entry.key);
      if (value != null) out[entry.value] = value;
    }
  }
  return out.isEmpty ? null : out;
}

List<Uint8List> _extractHeaderMessages(Uint8List bytes) {
  final headers = <Uint8List>[];
  var offset = 0;
  while (offset < bytes.length) {
    final tag = _readVarint(bytes, offset);
    if (tag == null) break;
    offset = tag.nextOffset;
    final field = tag.value >> 3;
    final wireType = tag.value & 0x07;
    if (field == 1 && wireType == 2) {
      final len = _readVarint(bytes, offset);
      if (len == null) break;
      offset = len.nextOffset;
      final end = offset + len.value;
      if (len.value < 0 || end > bytes.length) break;
      headers.add(Uint8List.sublistView(bytes, offset, end));
      offset = end;
      continue;
    }
    offset = _skipWire(bytes, offset, wireType);
    if (offset < 0) break;
  }
  return headers;
}

({Uint8List? pdata, int encType, int seq, int cmdId, int cmdFunc, int src})
_parseHeaderEnvelope(Uint8List header) {
  Uint8List? pdata;
  final chunks = <({int field, Uint8List bytes})>[];
  var encType = 0;
  var seq = 0;
  var cmdId = 0;
  var cmdFunc = 0;
  var src = 0;
  var offset = 0;
  while (offset < header.length) {
    final tag = _readVarint(header, offset);
    if (tag == null) break;
    offset = tag.nextOffset;
    final field = tag.value >> 3;
    final wireType = tag.value & 0x07;
    if (wireType == 2) {
      final len = _readVarint(header, offset);
      if (len == null) break;
      offset = len.nextOffset;
      final end = offset + len.value;
      if (len.value < 0 || end > header.length) break;
      final chunk = Uint8List.sublistView(header, offset, end);
      if (field == 1) pdata = chunk;
      chunks.add((field: field, bytes: chunk));
      offset = end;
      continue;
    }
    if (wireType == 0 && const <int>{4, 6, 8, 9, 14}.contains(field)) {
      final val = _readVarint(header, offset);
      if (val == null) break;
      offset = val.nextOffset;
      if (field == 4) src = val.value;
      if (field == 6) encType = val.value;
      if (field == 8) cmdFunc = val.value;
      if (field == 9) cmdId = val.value;
      if (field == 14) seq = val.value;
      continue;
    }
    offset = _skipWire(header, offset, wireType);
    if (offset < 0) break;
  }
  if (pdata == null && chunks.isNotEmpty) {
    chunks.sort((a, b) => b.bytes.length.compareTo(a.bytes.length));
    pdata = chunks.first.bytes;
  }
  return (
    pdata: pdata,
    encType: encType,
    seq: seq,
    cmdId: cmdId,
    cmdFunc: cmdFunc,
    src: src,
  );
}

class _Numeric {
  const _Numeric(this.field, this.value, this.kind);

  final int field;
  final num value;
  final String kind;
}

void _walkNumeric(Uint8List bytes, List<_Numeric> out, int maxDepth) {
  var offset = 0;
  while (offset < bytes.length) {
    final tag = _readVarint(bytes, offset);
    if (tag == null) break;
    offset = tag.nextOffset;
    final field = tag.value >> 3;
    final wireType = tag.value & 0x07;
    if (wireType == 0) {
      final val = _readVarint(bytes, offset);
      if (val == null) break;
      offset = val.nextOffset;
      out.add(_Numeric(field, val.value, 'varint'));
      continue;
    }
    if (wireType == 5) {
      if (offset + 4 > bytes.length) break;
      final view = ByteData.sublistView(bytes, offset, offset + 4);
      offset += 4;
      out.add(_Numeric(field, view.getUint32(0, Endian.little), 'fixed32'));
      continue;
    }
    if (wireType == 2) {
      final len = _readVarint(bytes, offset);
      if (len == null) break;
      offset = len.nextOffset;
      final end = offset + len.value;
      if (len.value < 0 || end > bytes.length) break;
      final payload = Uint8List.sublistView(bytes, offset, end);
      offset = end;
      if (maxDepth > 0) _walkNumeric(payload, out, maxDepth - 1);
      continue;
    }
    offset = _skipWire(bytes, offset, wireType);
    if (offset < 0) break;
  }
}

Map<String, dynamic>? _extractNumericTelemetry(
  Uint8List bytes, {
  required bool allowAdvanced,
}) {
  final items = <_Numeric>[];
  _walkNumeric(bytes, items, 5);
  if (items.isEmpty) return null;
  final out = <String, dynamic>{};
  for (final item in items) {
    if (item.kind == 'varint' && item.value >= 6 && item.value <= 100) {
      out['soc'] = item.value.round();
      break;
    }
  }
  if (allowAdvanced) {
    for (final item in items) {
      if (item.kind == 'varint' &&
          const <int>{2, 3, 4, 6, 16, 17}.contains(item.field)) {
        if (item.value == 0) out['online'] = 0;
        if (item.value == 1 || item.value == 2) out['online'] = 1;
        break;
      }
    }
    for (final item in items) {
      if (item.kind == 'varint' && item.value >= 15 && item.value <= 80) {
        out['temp'] = item.value;
        break;
      }
    }
  }
  return out.isEmpty ? null : out;
}

EcoFlowPayloadParseResult parseEcoFlowPayload(Uint8List rawBuffer) {
  final text = _toUtf8(rawBuffer);
  final hex = _toHex(rawBuffer, 48);
  final directJson = _decodeJsonMap(text) ?? _decodeJsonFromBytes(rawBuffer);
  if (directJson != null) {
    return EcoFlowPayloadParseResult(
      payload: directJson,
      params: _extractParamsFromPayload(directJson),
      envelope: null,
      debug: EcoFlowPayloadDebug(
        mode: 'json',
        preview: text.substring(0, text.length < 120 ? text.length : 120),
        hex: hex,
      ),
    );
  }

  final headers = _extractHeaderMessages(rawBuffer);
  for (final header in headers) {
    final envelope = _parseHeaderEnvelope(header);
    final pdataRaw = envelope.pdata;
    if (pdataRaw == null || pdataRaw.isEmpty) continue;
    final tries = _buildEncCandidates(
      pdataRaw,
      envelope.seq,
      envelope.encType,
      envelope.src,
    );
    for (final pdata in tries) {
      final known = _extractKnownTelemetryFromProto(pdata, (
        cmdFunc: envelope.cmdFunc,
        cmdId: envelope.cmdId,
      ));
      if (known != null) {
        return EcoFlowPayloadParseResult(
          payload: known,
          params: known,
          envelope: EcoFlowPayloadEnvelope(
            cmdFunc: envelope.cmdFunc,
            cmdId: envelope.cmdId,
            encType: envelope.encType,
            src: envelope.src,
          ),
          debug: EcoFlowPayloadDebug(
            mode:
                'protobuf-known(cmdFunc=${envelope.cmdFunc},cmdId=${envelope.cmdId})',
            preview: jsonEncode(known).substring(
              0,
              jsonEncode(known).length < 120 ? jsonEncode(known).length : 120,
            ),
            hex: hex,
          ),
        );
      }
      final decoded =
          _decodeJsonFromBytes(pdata) ?? _decodeJsonSubstringFromBytes(pdata);
      if (decoded != null) {
        return EcoFlowPayloadParseResult(
          payload: decoded,
          params: _extractParamsFromPayload(decoded),
          envelope: EcoFlowPayloadEnvelope(
            cmdFunc: envelope.cmdFunc,
            cmdId: envelope.cmdId,
            encType: envelope.encType,
            src: envelope.src,
          ),
          debug: EcoFlowPayloadDebug(
            mode: 'protobuf-json',
            preview: _toUtf8(pdata).substring(
              0,
              _toUtf8(pdata).length < 120 ? _toUtf8(pdata).length : 120,
            ),
            hex: hex,
          ),
        );
      }
      final numeric = _extractNumericTelemetry(
        pdata,
        allowAdvanced: envelope.cmdId == 50,
      );
      if (numeric != null) {
        return EcoFlowPayloadParseResult(
          payload: numeric,
          params: numeric,
          envelope: EcoFlowPayloadEnvelope(
            cmdFunc: envelope.cmdFunc,
            cmdId: envelope.cmdId,
            encType: envelope.encType,
            src: envelope.src,
          ),
          debug: EcoFlowPayloadDebug(
            mode: 'protobuf-numeric(cmdId=${envelope.cmdId})',
            preview: jsonEncode(numeric).substring(
              0,
              jsonEncode(numeric).length < 120
                  ? jsonEncode(numeric).length
                  : 120,
            ),
            hex: hex,
          ),
        );
      }
    }
    if (envelope.encType == 1) {
      return EcoFlowPayloadParseResult(
        payload: null,
        params: null,
        envelope: EcoFlowPayloadEnvelope(
          cmdFunc: envelope.cmdFunc,
          cmdId: envelope.cmdId,
          encType: envelope.encType,
          src: envelope.src,
        ),
        debug: EcoFlowPayloadDebug(
          mode:
              'encrypted-unknown(cmdFunc=${envelope.cmdFunc},cmdId=${envelope.cmdId},src=${envelope.src})',
          preview: _toUtf8(pdataRaw).substring(
            0,
            _toUtf8(pdataRaw).length < 120 ? _toUtf8(pdataRaw).length : 120,
          ),
          hex: hex,
        ),
      );
    }
  }
  return EcoFlowPayloadParseResult(
    payload: null,
    params: null,
    envelope: null,
    debug: EcoFlowPayloadDebug(
      mode: 'unknown',
      preview: text.substring(0, text.length < 120 ? text.length : 120),
      hex: hex,
    ),
  );
}

Map<String, dynamic>? _extractParamsFromPayload(Map<String, dynamic> payload) {
  final params = _asMap(payload['params']);
  if (params != null) return params;
  final data = _asMap(payload['data']);
  if (data != null) {
    final quotaMap = _asMap(data['quotaMap']);
    if (quotaMap != null) return quotaMap;
    final dataParams = _asMap(data['params']);
    if (dataParams != null) return dataParams;
    return data;
  }
  return payload;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return null;
}
