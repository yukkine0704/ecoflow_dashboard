function toMap(value) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
        return value;
    }
    return null;
}
function readVarint(bytes, offset) {
    let result = 0;
    let factor = 1;
    let index = offset;
    while (index < bytes.length) {
        const byte = bytes[index];
        result += (byte & 0x7f) * factor;
        index += 1;
        if ((byte & 0x80) === 0) {
            if (!Number.isSafeInteger(result))
                return null;
            return { value: result, nextOffset: index };
        }
        factor *= 128;
        if (!Number.isSafeInteger(factor))
            return null;
    }
    return null;
}
function skipWire(bytes, offset, wireType) {
    switch (wireType) {
        case 0: {
            const r = readVarint(bytes, offset);
            return r?.nextOffset ?? -1;
        }
        case 1:
            return offset + 8 <= bytes.length ? offset + 8 : -1;
        case 2: {
            const len = readVarint(bytes, offset);
            if (!len)
                return -1;
            const next = len.nextOffset + len.value;
            return next <= bytes.length ? next : -1;
        }
        case 5:
            return offset + 4 <= bytes.length ? offset + 4 : -1;
        default:
            return -1;
    }
}
function toUtf8(bytes) {
    try {
        return new TextDecoder().decode(bytes);
    }
    catch {
        return '';
    }
}
function decodeJsonMap(raw) {
    const trimmed = raw.trim();
    if (!trimmed)
        return null;
    try {
        const decoded = JSON.parse(trimmed);
        if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
            return decoded;
        }
    }
    catch {
        return null;
    }
    return null;
}
function decodeJsonFromBytes(bytes) {
    return decodeJsonMap(toUtf8(bytes));
}
function decodeJsonSubstringFromBytes(bytes) {
    const text = toUtf8(bytes);
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start)
        return null;
    return decodeJsonMap(text.slice(start, end + 1));
}
function xorWithSeqByte(bytes, seq) {
    const key = seq & 0xff;
    const out = new Uint8Array(bytes.length);
    for (let i = 0; i < bytes.length; i += 1)
        out[i] = bytes[i] ^ key;
    return out;
}
function readFixed32Float(bytes, offset) {
    if (offset + 4 > bytes.length)
        return null;
    const view = new DataView(bytes.buffer, bytes.byteOffset + offset, 4);
    return view.getFloat32(0, true);
}
function extractTopLevelFields(bytes) {
    const out = new Map();
    let offset = 0;
    while (offset < bytes.length) {
        const tag = readVarint(bytes, offset);
        if (!tag)
            break;
        offset = tag.nextOffset;
        const field = tag.value >> 3;
        const wireType = tag.value & 0x07;
        if (wireType === 0) {
            const val = readVarint(bytes, offset);
            if (!val)
                break;
            offset = val.nextOffset;
            const list = out.get(field) ?? [];
            list.push(val.value);
            out.set(field, list);
            continue;
        }
        if (wireType === 5) {
            const floatValue = readFixed32Float(bytes, offset);
            if (floatValue === null)
                break;
            offset += 4;
            const list = out.get(field) ?? [];
            list.push(floatValue);
            out.set(field, list);
            continue;
        }
        if (wireType === 2) {
            const len = readVarint(bytes, offset);
            if (!len)
                break;
            offset = len.nextOffset;
            const end = offset + len.value;
            if (len.value < 0 || end > bytes.length)
                break;
            const chunk = bytes.slice(offset, end);
            offset = end;
            // Best effort for string fields.
            const text = toUtf8(chunk).trim();
            if (text && /^[\x20-\x7E]+$/.test(text)) {
                const list = out.get(field) ?? [];
                list.push(text);
                out.set(field, list);
            }
            continue;
        }
        offset = skipWire(bytes, offset, wireType);
        if (offset < 0)
            break;
    }
    return out;
}
function getNumber(fields, field) {
    const values = fields.get(field);
    if (!values || values.length === 0)
        return null;
    const last = values[values.length - 1];
    return typeof last === 'number' && Number.isFinite(last) ? last : null;
}
function extractKnownTelemetryFromProto(pdata, envelope) {
    const fields = extractTopLevelFields(pdata);
    if (fields.size === 0)
        return null;
    const out = {};
    // BMSHeartBeatReport
    if (envelope.cmdFunc === 32 && envelope.cmdId === 50) {
        const soc = getNumber(fields, 6);
        const temp = getNumber(fields, 9);
        const maxCellTemp = getNumber(fields, 18);
        const f32ShowSoc = getNumber(fields, 25);
        const inputWatts = getNumber(fields, 26);
        const outputWatts = getNumber(fields, 27);
        if (soc !== null)
            out['bms.soc'] = soc;
        if (temp !== null)
            out['bms.temp'] = temp;
        if (maxCellTemp !== null)
            out['bms.maxCellTemp'] = maxCellTemp;
        if (f32ShowSoc !== null)
            out['bms.f32ShowSoc'] = f32ShowSoc;
        if (inputWatts !== null)
            out['bms.inputWatts'] = inputWatts;
        if (outputWatts !== null)
            out['bms.outputWatts'] = outputWatts;
    }
    // RuntimePropertyUpload
    if (envelope.cmdFunc === 254 && envelope.cmdId === 22) {
        const tempPcsDc = getNumber(fields, 26);
        const tempPcsAc = getNumber(fields, 27);
        const tempPv = getNumber(fields, 379);
        if (tempPcsDc !== null)
            out['pd.tempPcsDc'] = tempPcsDc;
        if (tempPcsAc !== null)
            out['pd.tempPcsAc'] = tempPcsAc;
        if (tempPv !== null)
            out['pd.tempPv'] = tempPv;
    }
    // DisplayPropertyUpload
    if (envelope.cmdFunc === 254 && envelope.cmdId === 21) {
        const map = [
            [3, 'pd.inputWatts'],
            [4, 'pd.outputWatts'],
            [35, 'pd.powGetPvH'],
            [36, 'pd.powGetPvL'],
            [37, 'pd.powGet12v'],
            [53, 'pd.powGetAc'],
            [54, 'pd.powGetAcIn'],
            [77, 'pd.powGetDcp2'],
            [158, 'pd.powGetBms'],
            [242, 'pd.bmsBattSoc'],
            [258, 'pd.bmsMinCellTemp'],
            [259, 'pd.bmsMaxCellTemp'],
            [262, 'pd.cmsBattSoc'],
            [361, 'pd.powGetPv'],
            [368, 'pd.powGetAcOut'],
            [425, 'pd.powGetDcp'],
        ];
        for (const [field, key] of map) {
            const value = getNumber(fields, field);
            if (value !== null)
                out[key] = value;
        }
    }
    return Object.keys(out).length > 0 ? out : null;
}
function extractHeaderMessages(bytes) {
    const headers = [];
    let offset = 0;
    while (offset < bytes.length) {
        const tag = readVarint(bytes, offset);
        if (!tag)
            break;
        offset = tag.nextOffset;
        const field = tag.value >> 3;
        const wireType = tag.value & 0x07;
        if (field === 1 && wireType === 2) {
            const len = readVarint(bytes, offset);
            if (!len)
                break;
            offset = len.nextOffset;
            const end = offset + len.value;
            if (len.value < 0 || end > bytes.length)
                break;
            headers.push(bytes.slice(offset, end));
            offset = end;
            continue;
        }
        offset = skipWire(bytes, offset, wireType);
        if (offset < 0)
            break;
    }
    return headers;
}
function parseHeaderEnvelope(header) {
    let pdata = null;
    let encType = 0;
    let seq = 0;
    let cmdId = 0;
    let cmdFunc = 0;
    let src = 0;
    let offset = 0;
    while (offset < header.length) {
        const tag = readVarint(header, offset);
        if (!tag)
            break;
        offset = tag.nextOffset;
        const field = tag.value >> 3;
        const wireType = tag.value & 0x07;
        if (field === 1 && wireType === 2) {
            const len = readVarint(header, offset);
            if (!len)
                break;
            offset = len.nextOffset;
            const end = offset + len.value;
            if (len.value < 0 || end > header.length)
                break;
            pdata = header.slice(offset, end);
            offset = end;
            continue;
        }
        if (wireType === 0 && (field === 4 || field === 6 || field === 8 || field === 9 || field === 14)) {
            const val = readVarint(header, offset);
            if (!val)
                break;
            offset = val.nextOffset;
            if (field === 4)
                src = val.value;
            if (field === 6)
                encType = val.value;
            if (field === 8)
                cmdFunc = val.value;
            if (field === 9)
                cmdId = val.value;
            if (field === 14)
                seq = val.value;
            continue;
        }
        offset = skipWire(header, offset, wireType);
        if (offset < 0)
            break;
    }
    return { pdata, encType, seq, cmdId, cmdFunc, src };
}
function walkNumeric(bytes, out, maxDepth) {
    let offset = 0;
    while (offset < bytes.length) {
        const tag = readVarint(bytes, offset);
        if (!tag)
            break;
        offset = tag.nextOffset;
        const field = tag.value >> 3;
        const wireType = tag.value & 0x07;
        if (wireType === 0) {
            const val = readVarint(bytes, offset);
            if (!val)
                break;
            offset = val.nextOffset;
            out.push({ field, value: val.value, kind: 'varint' });
            continue;
        }
        if (wireType === 5) {
            if (offset + 4 > bytes.length)
                break;
            const v = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
            offset += 4;
            out.push({ field, value: v, kind: 'fixed32' });
            continue;
        }
        if (wireType === 2) {
            const len = readVarint(bytes, offset);
            if (!len)
                break;
            offset = len.nextOffset;
            const end = offset + len.value;
            if (len.value < 0 || end > bytes.length)
                break;
            const payload = bytes.slice(offset, end);
            offset = end;
            if (maxDepth > 0)
                walkNumeric(payload, out, maxDepth - 1);
            continue;
        }
        offset = skipWire(bytes, offset, wireType);
        if (offset < 0)
            break;
    }
}
function extractNumericTelemetry(bytes, options) {
    const items = [];
    walkNumeric(bytes, items, 5);
    if (items.length === 0)
        return null;
    const out = {};
    const battery = items.find((e) => e.kind === 'varint' && e.value >= 6 && e.value <= 100);
    if (battery)
        out.soc = Math.round(battery.value);
    if (options.allowAdvanced) {
        const onlineCandidate = items.find((e) => e.kind === 'varint' && [2, 3, 4, 6, 16, 17].includes(e.field));
        if (onlineCandidate) {
            if (onlineCandidate.value === 0)
                out.online = 0;
            if (onlineCandidate.value === 1 || onlineCandidate.value === 2)
                out.online = 1;
        }
    }
    // Power-by-varint inference is too noisy on newer devices (e.g. DELTA 3):
    // unrelated counters can be interpreted as watts and produce ghost values.
    // Keep this disabled unless we have a vetted per-model protobuf mapping.
    if (options.allowAdvanced && options.allowPowerHeuristics) {
        const mw = items
            .filter((e) => e.kind === 'varint' && e.value >= 1000 && e.value <= 200000)
            .map((e) => e.value)
            .sort((a, b) => a - b);
        if (mw.length > 0)
            out.outPower = mw[mw.length - 1] / 1000.0;
        if (mw.length > 1)
            out.inPower = mw[mw.length - 2] / 1000.0;
    }
    if (options.allowAdvanced) {
        const temp = items.find((e) => e.kind === 'varint' && e.value >= 15 && e.value <= 80);
        if (temp)
            out.temp = temp.value;
    }
    return Object.keys(out).length ? out : null;
}
export function parseEcoflowPayload(rawBuffer) {
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
            if (!envelope.pdata || envelope.pdata.length === 0)
                continue;
            const tries = [envelope.pdata];
            if (envelope.encType === 1 && envelope.seq !== 0 && envelope.src !== 32) {
                tries.push(xorWithSeqByte(envelope.pdata, envelope.seq));
            }
            for (const pdata of tries) {
                const known = extractKnownTelemetryFromProto(pdata, {
                    cmdFunc: envelope.cmdFunc,
                    cmdId: envelope.cmdId,
                });
                if (known) {
                    return {
                        payload: known,
                        params: known,
                        debug: {
                            mode: `protobuf-known(cmdFunc=${envelope.cmdFunc},cmdId=${envelope.cmdId})`,
                            preview: JSON.stringify(known).slice(0, 120),
                            hex,
                        },
                    };
                }
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
                    allowPowerHeuristics: false,
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
function extractParamsFromPayload(payload) {
    const params = toMap(payload.params);
    if (params)
        return params;
    const data = toMap(payload.data);
    if (data) {
        const quotaMap = toMap(data.quotaMap);
        if (quotaMap)
            return quotaMap;
        const dataParams = toMap(data.params);
        if (dataParams)
            return dataParams;
        return data;
    }
    return payload;
}
