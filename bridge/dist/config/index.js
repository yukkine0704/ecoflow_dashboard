function parseCsv(value) {
    if (!value) {
        return [];
    }
    return value
        .split(',')
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
}
function parseBool(value, fallback) {
    if (!value)
        return fallback;
    const normalized = value.trim().toLowerCase();
    if (['1', 'true', 'yes', 'on'].includes(normalized))
        return true;
    if (['0', 'false', 'no', 'off'].includes(normalized))
        return false;
    return fallback;
}
function parsePositiveInt(value, fallback) {
    const parsed = Number.parseInt(value?.trim() || '', 10);
    if (!Number.isFinite(parsed) || parsed <= 0)
        return fallback;
    return parsed;
}
export function loadConfig(env) {
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
        statusAssumeOfflineSec: parsePositiveInt(env.ECOFLOW_STATUS_ASSUME_OFFLINE_SEC, 90),
        statusForceOfflineMultiplier: parsePositiveInt(env.ECOFLOW_STATUS_FORCE_OFFLINE_MULTIPLIER, 3),
        statusPollIntervalSec: parsePositiveInt(env.ECOFLOW_STATUS_POLL_INTERVAL_SEC, 60),
        wsEmitV1: parseBool(env.BRIDGE_WS_EMIT_V1, true),
        wsEmitV2: parseBool(env.BRIDGE_WS_EMIT_V2, true),
    };
}
