export interface EcoflowMqttCertification {
  host: string;
  port: number;
  username: string;
  password: string;
  userId: string;
  certificateAccount?: string;
  useTls: boolean;
}

export interface EcoflowDeviceIdentity {
  sn: string;
  name?: string;
  model?: string;
  imageUrl?: string;
}

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

function normalizeHost(hostRaw: string): { host: string; port?: number } {
  try {
    const uri = new URL(hostRaw.includes('://') ? hostRaw : `mqtt://${hostRaw}`);
    const host = uri.hostname;
    const port = uri.port ? Number.parseInt(uri.port, 10) : undefined;
    return { host, port: Number.isFinite(port ?? NaN) ? port : undefined };
  } catch {
    const parts = hostRaw.split(':');
    if (parts.length === 2) {
      const maybePort = Number.parseInt(parts[1]!, 10);
      return { host: parts[0]!, port: Number.isFinite(maybePort) ? maybePort : undefined };
    }
    return { host: hostRaw };
  }
}

async function postJson(url: string, body: Record<string, unknown>, headers: Record<string, string> = {}): Promise<Record<string, unknown>> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} ${response.statusText} for ${url}`);
  }
  const data = await response.json();
  const mapped = asMap(data);
  if (!mapped) {
    throw new Error(`Invalid JSON envelope for ${url}`);
  }
  return mapped;
}

export async function fetchAppMqttCertification(input: {
  baseUrl: string;
  email: string;
  password: string;
}): Promise<EcoflowMqttCertification> {
  const loginEnvelope = await postJson(`${input.baseUrl}/auth/login`, {
    email: input.email,
    password: Buffer.from(input.password).toString('base64'),
    scene: 'IOT_APP',
    userType: 'ECOFLOW',
  }, {
    lang: 'en_US',
  });
  ensureSuccess(loginEnvelope, '/auth/login');

  const loginData = asMap(loginEnvelope.data) ?? {};
  const token = pickText(loginData, ['token']);
  const user = asMap(loginData.user) ?? {};
  const userId = pickText(user, ['userId', 'id']);
  if (!token || !userId) {
    throw new Error('Missing token/userId in EcoFlow app login');
  }

  const certUrl = new URL(`${input.baseUrl}/iot-auth/app/certification`);
  certUrl.searchParams.set('userId', userId);
  const certResponse = await fetch(certUrl.toString(), {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      lang: 'en_US',
      'content-type': 'application/json',
    },
  });
  if (!certResponse.ok) {
    throw new Error(`HTTP ${certResponse.status} ${certResponse.statusText} for /iot-auth/app/certification`);
  }
  const certEnvelopeRaw = await certResponse.json();
  const certEnvelope = asMap(certEnvelopeRaw);
  if (!certEnvelope) {
    throw new Error('Invalid certification envelope');
  }
  ensureSuccess(certEnvelope, '/iot-auth/app/certification');
  const certData = asMap(certEnvelope.data) ?? {};

  const hostRaw = pickText(certData, ['url', 'host', 'mqttHost', 'broker', 'server']);
  const account = pickText(certData, ['certificateAccount', 'account', 'certAccount']);
  const certPassword = pickText(certData, ['certificatePassword', 'password', 'pwd']);
  const protocol = pickText(certData, ['protocol', 'schema']);
  const portText = pickText(certData, ['port', 'mqttPort']);
  const normalized = normalizeHost(hostRaw ?? '');

  if (!hostRaw || !account || !certPassword) {
    throw new Error('Incomplete MQTT certification response');
  }

  const parsedPort = portText ? Number.parseInt(portText, 10) : undefined;
  const port = Number.isFinite(parsedPort ?? NaN) ? (parsedPort as number) : normalized.port ?? 8883;
  const useTls = (protocol ?? '').toLowerCase() === 'mqtts' || port === 8883;

  return {
    host: normalized.host,
    port,
    username: account,
    password: certPassword,
    userId,
    certificateAccount: account,
    useTls,
  };
}
