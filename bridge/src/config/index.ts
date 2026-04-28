export interface BridgeConfig {
  wsHost: string;
  wsPort: number;

  ecoflowBaseUrl: string;
  appEmail: string;
  appPassword: string;

  openApiAccessKey?: string;
  openApiSecretKey?: string;
  openApiBaseUrl: string;

  deviceSnAllowlist: string[];
}

function parseCsv(value: string | undefined): string[] {
  if (!value) {
    return [];
  }
  return value
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

export function loadConfig(env: NodeJS.ProcessEnv): BridgeConfig {
  const wsHost = env.WS_HOST?.trim() || '0.0.0.0';
  const wsPort = Number.parseInt(env.WS_PORT?.trim() || '8787', 10);
  if (!Number.isFinite(wsPort) || wsPort <= 0) {
    throw new Error(`Invalid WS_PORT: ${env.WS_PORT}`);
  }

  const appEmail = env.ECOFLOW_APP_EMAIL?.trim() || '';
  const appPassword = env.ECOFLOW_APP_PASSWORD?.trim() || '';
  if (!appEmail || !appPassword) {
    throw new Error('Missing ECOFLOW_APP_EMAIL/ECOFLOW_APP_PASSWORD in environment');
  }

  const openApiAccessKey = env.ECOFLOW_OPEN_ACCESS_KEY?.trim() || undefined;
  const openApiSecretKey = env.ECOFLOW_OPEN_SECRET_KEY?.trim() || undefined;
  if ((openApiAccessKey && !openApiSecretKey) || (!openApiAccessKey && openApiSecretKey)) {
    throw new Error('ECOFLOW_OPEN_ACCESS_KEY and ECOFLOW_OPEN_SECRET_KEY must be both set or both empty');
  }

  return {
    wsHost,
    wsPort,
    ecoflowBaseUrl: env.ECOFLOW_BASE_URL?.trim() || 'https://api.ecoflow.com',
    appEmail,
    appPassword,
    openApiAccessKey,
    openApiSecretKey,
    openApiBaseUrl: env.ECOFLOW_OPEN_BASE_URL?.trim() || 'https://api.ecoflow.com',
    deviceSnAllowlist: parseCsv(env.ECOFLOW_DEVICE_SNS),
  };
}
