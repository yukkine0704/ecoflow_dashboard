import { createHmac, randomInt } from 'node:crypto';

function stringifyValue(value: unknown): string | null {
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value.toString();
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  return null;
}

function processValue(prefix: string, value: unknown): string[] {
  if (value === null || value === undefined) {
    return [];
  }
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => processValue(`${prefix}[${index}]`, item));
  }
  if (typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>).flatMap(([key, nested]) =>
      processValue(`${prefix}.${key}`, nested),
    );
  }

  const raw = stringifyValue(value);
  if (raw === null) {
    return [];
  }
  return [`${prefix}=${raw}`];
}

function generateQuery(params?: Record<string, unknown>): string {
  if (!params || Object.keys(params).length === 0) {
    return '';
  }
  const parts = Object.entries(params).flatMap(([key, value]) => processValue(key, value));
  parts.sort();
  return parts.join('&');
}

export function createSignedHeaders(input: {
  accessKey: string;
  secretKey: string;
  params?: Record<string, unknown>;
}): Record<string, string> {
  const nonce = randomInt(100000, 999999).toString();
  const timestamp = `${Date.now() * 1000000}`;

  const query = generateQuery(input.params);
  const suffix = `accessKey=${input.accessKey}&nonce=${nonce}&timestamp=${timestamp}`;
  const base = query ? `${query}&${suffix}` : suffix;
  const sign = createHmac('sha256', input.secretKey).update(base).digest('hex');

  return {
    accessKey: input.accessKey,
    nonce,
    timestamp,
    sign,
    'Content-Type': 'application/json',
  };
}
