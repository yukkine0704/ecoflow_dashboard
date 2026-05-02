import { createSignedHeaders } from './signer.js';
import type { EcoflowDeviceIdentity } from './appAuth.js';

function asMap(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function asText(value: unknown): string | null {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed ? trimmed : null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  return null;
}

function pickText(source: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = asText(source[key]);
    if (value) {
      return value;
    }
  }
  return null;
}

function ensureSuccess(envelope: Record<string, unknown>, endpoint: string): void {
  const code = asText(envelope.code);
  if (!code || code === '0') {
    return;
  }
  const message = asText(envelope.message) ?? 'unknown error';
  throw new Error(`EcoFlow ${endpoint} failed: code=${code} message=${message}`);
}

export async function fetchOpenApiDeviceList(input: {
  baseUrl: string;
  accessKey: string;
  secretKey: string;
}): Promise<EcoflowDeviceIdentity[]> {
  const endpoint = '/iot-open/sign/device/list';
  const headers = createSignedHeaders({
    accessKey: input.accessKey,
    secretKey: input.secretKey,
  });

  const response = await fetch(`${input.baseUrl}${endpoint}`, {
    method: 'GET',
    headers,
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} ${response.statusText} for ${endpoint}`);
  }

  const raw = await response.json();
  const envelope = asMap(raw);
  if (!envelope) {
    throw new Error('Invalid Open API device list envelope');
  }
  ensureSuccess(envelope, endpoint);

  const dataRaw = envelope.data;
  let listRaw: unknown = null;
  if (Array.isArray(dataRaw)) {
    listRaw = dataRaw;
  } else {
    const data = asMap(dataRaw) ?? envelope;
    listRaw = data.list ?? data.devices ?? data.deviceList;
  }
  if (!Array.isArray(listRaw)) return [];

  const devices: EcoflowDeviceIdentity[] = [];
  for (const row of listRaw) {
    const map = asMap(row);
    if (!map) {
      continue;
    }
    const sn = pickText(map, ['sn', 'deviceSn', 'serialNumber', 'deviceSN']);
    if (!sn) {
      continue;
    }
    devices.push({
      sn,
      name: pickText(map, ['deviceName', 'name', 'nickName', 'snName', 'productName']) ?? undefined,
      model: pickText(map, ['productName', 'productModel', 'model', 'deviceModel', 'deviceType']) ?? undefined,
      imageUrl: pickText(map, ['imageUrl', 'imgUrl', 'picUrl', 'productPic', 'iconUrl']) ?? undefined,
    });
  }

  return devices;
}

export async function fetchOpenApiDeviceStatusMap(input: {
  baseUrl: string;
  accessKey: string;
  secretKey: string;
}): Promise<Map<string, boolean>> {
  const devices = await fetchOpenApiDeviceList(input);
  const endpoint = '/iot-open/sign/device/list';
  const headers = createSignedHeaders({
    accessKey: input.accessKey,
    secretKey: input.secretKey,
  });
  const response = await fetch(`${input.baseUrl}${endpoint}`, {
    method: 'GET',
    headers,
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} ${response.statusText} for ${endpoint}`);
  }
  const raw = await response.json();
  const envelope = asMap(raw);
  if (!envelope) return new Map();

  const data = asMap(envelope.data) ?? envelope;
  const listRaw = Array.isArray(data.list) ? data.list : (Array.isArray(envelope.data) ? envelope.data : []);
  const out = new Map<string, boolean>();
  for (const row of listRaw) {
    const map = asMap(row);
    if (!map) continue;
    const sn = pickText(map, ['sn', 'deviceSn', 'serialNumber', 'deviceSN']);
    if (!sn) continue;
    const statusRaw = map.status;
    const online = statusRaw === 1 || statusRaw === '1' || statusRaw === true;
    out.set(sn, online);
  }

  for (const d of devices) {
    if (!out.has(d.sn)) out.set(d.sn, false);
  }
  return out;
}
