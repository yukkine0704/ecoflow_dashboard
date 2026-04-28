import 'dotenv/config';
import { loadConfig } from './config/index.js';
import { fetchAppMqttCertification } from './ecoflow/appAuth.js';
import { fetchOpenApiDeviceList } from './ecoflow/openApi.js';
import { DeviceStateStore } from './core/deviceStateStore.js';
import { MqttIngestService } from './core/mqttIngestService.js';
import { WsGateway } from './core/wsGateway.js';
const TARGET_MIGRATION_SNS = new Set([
    'P351ZAHAPH2R2706',
    'R651ZAB5XH111262',
]);
function buildCatalogPayload(devices) {
    return {
        devices: devices
            .map((device) => ({
            deviceId: device.sn,
            displayName: device.name || device.model || device.sn,
            model: device.model ?? null,
            imageUrl: device.imageUrl ?? null,
        }))
            .sort((a, b) => a.deviceId.localeCompare(b.deviceId)),
    };
}
async function resolveCatalog(config) {
    let devices = [];
    if (config.openApiAccessKey && config.openApiSecretKey) {
        try {
            devices = await fetchOpenApiDeviceList({
                baseUrl: config.openApiBaseUrl,
                accessKey: config.openApiAccessKey,
                secretKey: config.openApiSecretKey,
            });
            console.log(`[bridge] Open API catalog loaded: ${devices.length} device(s)`);
        }
        catch (error) {
            console.warn(`[bridge] Open API catalog failed: ${String(error)}`);
        }
    }
    if (config.deviceSnAllowlist.length > 0) {
        const bySn = new Map(devices.map((d) => [d.sn, d]));
        const resolved = config.deviceSnAllowlist.map((sn) => bySn.get(sn) ?? { sn, name: sn });
        return resolved;
    }
    if (devices.length > 0) {
        return devices;
    }
    throw new Error('No devices resolved. Set ECOFLOW_DEVICE_SNS or provide Open API keys to fetch catalog.');
}
async function main() {
    const config = loadConfig(process.env);
    const certification = await fetchAppMqttCertification({
        baseUrl: config.ecoflowBaseUrl,
        email: config.appEmail,
        password: config.appPassword,
    });
    const catalog = await resolveCatalog(config);
    const deviceIds = catalog.map((device) => device.sn);
    const missingTargets = [...TARGET_MIGRATION_SNS].filter((sn) => !deviceIds.includes(sn));
    if (missingTargets.length > 0) {
        console.warn(`[bridge] migration targets missing from resolved catalog: ${missingTargets.join(', ')}. `
            + 'Set ECOFLOW_DEVICE_SNS or verify Open API visibility.');
    }
    const store = new DeviceStateStore();
    store.setCatalog(catalog.map((device) => ({
        deviceId: device.sn,
        displayName: device.name || device.model || device.sn,
        model: device.model,
        imageUrl: device.imageUrl,
    })));
    const ws = new WsGateway(config, store);
    const ingest = new MqttIngestService(config, store, {
        onDeviceDelta: (_deviceId, delta) => {
            ws.broadcastDeviceDelta(delta);
            ws.broadcastFleetState();
            ws.broadcastDeviceSnapshot(delta.deviceId);
        },
    }, certification, deviceIds);
    ws.start();
    ws.broadcastCatalog(buildCatalogPayload(catalog));
    ws.broadcastFleetState();
    ingest.start();
    console.log(`[bridge] EcoFlow direct mode enabled for ${deviceIds.length} device(s): ${deviceIds.join(', ')}`);
    const shutdown = () => {
        console.log('[bridge] shutting down...');
        ingest.stop();
        ws.stop();
        process.exit(0);
    };
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
}
main().catch((error) => {
    console.error(`[bridge] startup failed: ${String(error)}`);
    process.exit(1);
});
