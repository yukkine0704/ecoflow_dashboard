interface VarintRead {
  value: number;
  nextOffset: number;
}

function toMap(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function readVarint(bytes: Uint8Array, offset: number): VarintRead | null {
  let result = 0;
  let shift = 0;
  let index = offset;
  while (index < bytes.length && shift <= 63) {
    const byte = bytes[index]!;
    result |= (byte & 0x7f) << shift;
    index += 1;
    if ((byte & 0x80) === 0) {
      return { value: result, nextOffset: index };
    }
    shift += 7;
  }
  return null;
}

function skipWire(bytes: Uint8Array, offset: number, wireType: number): number {
  switch (wireType) {
    case 0: {
      const r = readVarint(bytes, offset);
      return r?.nextOffset ?? -1;
    }
    case 1:
      return offset + 8 <= bytes.length ? offset + 8 : -1;
    case 2: {
      const len = readVarint(bytes, offset);
      if (!len) return -1;
      const next = len.nextOffset + len.value;
      return next <= bytes.length ? next : -1;
    }
    case 5:
      return offset + 4 <= bytes.length ? offset + 4 : -1;
    default:
      return -1;
  }
}

function toUtf8(bytes: Uint8Array): string {
  try {
    return new TextDecoder().decode(bytes);
  } catch {
    return '';
  }
}

function decodeJsonMap(raw: string): Record<string, unknown> | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  try {
    const decoded = JSON.parse(trimmed) as unknown;
    if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
      return decoded as Record<string, unknown>;
    }
  } catch {
    return null;
  }
  return null;
}

function decodeJsonFromBytes(bytes: Uint8Array): Record<string, unknown> | null {
  return decodeJsonMap(toUtf8(bytes));
}

function decodeJsonSubstringFromBytes(bytes: Uint8Array): Record<string, unknown> | null {
  const text = toUtf8(bytes);
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end < 0 || end <= start) return null;
  return decodeJsonMap(text.slice(start, end + 1));
}

function xorWithSeqByte(bytes: Uint8Array, seq: number): Uint8Array {
  const key = seq & 0xff;
  const out = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i += 1) out[i] = bytes[i]! ^ key;
  return out;
}

function extractHeaderMessages(bytes: Uint8Array): Uint8Array[] {
  const headers: Uint8Array[] = [];
  let offset = 0;
  while (offset < bytes.length) {
    const tag = readVarint(bytes, offset);
    if (!tag) break;
    offset = tag.nextOffset;
    const field = tag.value >> 3;
    const wireType = tag.value & 0x07;

    if (field === 1 && wireType === 2) {
      const len = readVarint(bytes, offset);
      if (!len) break;
      offset = len.nextOffset;
      const end = offset + len.value;
      if (len.value < 0 || end > bytes.length) break;
      headers.push(bytes.slice(offset, end));
      offset = end;
      continue;
    }

    offset = skipWire(bytes, offset, wireType);
    if (offset < 0) break;
  }
  return headers;
}

function parseHeaderEnvelope(header: Uint8Array): {
  pdata: Uint8Array | null;
  encType: number;
  seq: number;
  cmdId: number;
  cmdFunc: number;
} {
  let pdata: Uint8Array | null = null;
  let encType = 0;
  let seq = 0;
  let cmdId = 0;
  let cmdFunc = 0;
  let offset = 0;

  while (offset < header.length) {
    const tag = readVarint(header, offset);
    if (!tag) break;
    offset = tag.nextOffset;
    const field = tag.value >> 3;
    const wireType = tag.value & 0x07;

    if (field === 1 && wireType === 2) {
      const len = readVarint(header, offset);
      if (!len) break;
      offset = len.nextOffset;
      const end = offset + len.value;
      if (len.value < 0 || end > header.length) break;
      pdata = header.slice(offset, end);
      offset = end;
      continue;
    }

    if (wireType === 0 && (field === 6 || field === 8 || field === 9 || field === 14)) {
      const val = readVarint(header, offset);
      if (!val) break;
      offset = val.nextOffset;
      if (field === 6) encType = val.value;
      if (field === 8) cmdFunc = val.value;
      if (field === 9) cmdId = val.value;
      if (field === 14) seq = val.value;
      continue;
    }

    offset = skipWire(header, offset, wireType);
    if (offset < 0) break;
  }

  return { pdata, encType, seq, cmdId, cmdFunc };
}

type Numeric = { field: number; value: number; kind: 'varint' | 'fixed32' };

function walkNumeric(bytes: Uint8Array, out: Numeric[], maxDepth: number): void {
  let offset = 0;
  while (offset < bytes.length) {
    const tag = readVarint(bytes, offset);
    if (!tag) break;
    offset = tag.nextOffset;
    const field = tag.value >> 3;
    const wireType = tag.value & 0x07;

    if (wireType === 0) {
      const val = readVarint(bytes, offset);
      if (!val) break;
      offset = val.nextOffset;
      out.push({ field, value: val.value, kind: 'varint' });
      continue;
    }

    if (wireType === 5) {
      if (offset + 4 > bytes.length) break;
      const v = bytes[offset]! | (bytes[offset + 1]! << 8) | (bytes[offset + 2]! << 16) | (bytes[offset + 3]! << 24);
      offset += 4;
      out.push({ field, value: v, kind: 'fixed32' });
      continue;
    }

    if (wireType === 2) {
      const len = readVarint(bytes, offset);
      if (!len) break;
      offset = len.nextOffset;
      const end = offset + len.value;
      if (len.value < 0 || end > bytes.length) break;
      const payload = bytes.slice(offset, end);
      offset = end;
      if (maxDepth > 0) walkNumeric(payload, out, maxDepth - 1);
      continue;
    }

    offset = skipWire(bytes, offset, wireType);
    if (offset < 0) break;
  }
}

function extractNumericTelemetry(
  bytes: Uint8Array,
  options: { allowAdvanced: boolean },
): Record<string, unknown> | null {
  const items: Numeric[] = [];
  walkNumeric(bytes, items, 5);
  if (items.length === 0) return null;

  const out: Record<string, unknown> = {};

  const battery = items.find((e) => e.kind === 'varint' && e.value >= 6 && e.value <= 100);
  if (battery) out.soc = Math.round(battery.value);

  if (options.allowAdvanced) {
    const onlineCandidate = items.find(
      (e) => e.kind === 'varint' && [2, 3, 4, 6, 16, 17].includes(e.field),
    );
    if (onlineCandidate) {
      if (onlineCandidate.value === 0) out.online = 0;
      if (onlineCandidate.value === 1 || onlineCandidate.value === 2) out.online = 1;
    }
  }

  const mw = items
    .filter((e) => e.kind === 'varint' && e.value >= 1000 && e.value <= 200000)
    .map((e) => e.value)
    .sort((a, b) => a - b);
  if (options.allowAdvanced) {
    if (mw.length > 0) out.outPower = mw[mw.length - 1]! / 1000.0;
    if (mw.length > 1) out.inPower = mw[mw.length - 2]! / 1000.0;
  }

  if (options.allowAdvanced) {
    const temp = items.find(
      (e) => e.kind === 'varint' && e.value >= 15 && e.value <= 80,
    );
    if (temp) out.temp = temp.value;
  }

  return Object.keys(out).length ? out : null;
}

export function parseEcoflowPayload(rawBuffer: Buffer): {
  payload: Record<string, unknown> | null;
  params: Record<string, unknown> | null;
  debug: { mode: string; preview: string; hex: string };
} {
  const bytes = new Uint8Array(rawBuffer);
  const text = toUtf8(bytes);
  const hex = rawBuffer.subarray(0, Math.min(48, rawBuffer.length)).toString('hex');

  const directJson = decodeJsonMap(text) ?? decodeJsonFromBytes(bytes);
  if (directJson) {
    return {
      payload: directJson,
      params: extractParamsFromPayload(directJson),
      debug: { mode: 'json', preview: text.slice(0, 120), hex },
    };
  }

  const headers = extractHeaderMessages(bytes);
  if (headers.length > 0) {
    for (const h of headers) {
      const envelope = parseHeaderEnvelope(h);
      if (!envelope.pdata || envelope.pdata.length === 0) continue;

      const tries: Uint8Array[] = [envelope.pdata];
      if (envelope.encType === 1 && envelope.seq !== 0) {
        tries.push(xorWithSeqByte(envelope.pdata, envelope.seq));
      }

      for (const pdata of tries) {
        const decoded = decodeJsonFromBytes(pdata) ?? decodeJsonSubstringFromBytes(pdata);
        if (decoded) {
          return {
            payload: decoded,
            params: extractParamsFromPayload(decoded),
            debug: { mode: 'protobuf-json', preview: toUtf8(pdata).slice(0, 120), hex },
          };
        }

        // cmdId=50 packets are fuller snapshots; non-50 frames are often partial/noisy.
        const numeric = extractNumericTelemetry(pdata, {
          allowAdvanced: envelope.cmdId === 50,
        });
        if (numeric) {
          return {
            payload: numeric,
            params: numeric,
            debug: {
              mode: `protobuf-numeric(cmdId=${envelope.cmdId})`,
              preview: JSON.stringify(numeric).slice(0, 120),
              hex,
            },
          };
        }
      }
    }
  }

  return {
    payload: null,
    params: null,
    debug: { mode: 'unknown', preview: text.slice(0, 120), hex },
  };
}

function extractParamsFromPayload(payload: Record<string, unknown>): Record<string, unknown> | null {
  const params = toMap(payload.params);
  if (params) return params;
  const data = toMap(payload.data);
  if (data) {
    const quotaMap = toMap(data.quotaMap);
    if (quotaMap) return quotaMap;
    const dataParams = toMap(data.params);
    if (dataParams) return dataParams;
    return data;
  }
  return payload;
}
