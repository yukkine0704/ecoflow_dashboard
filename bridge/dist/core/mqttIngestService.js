import mqtt from 'mqtt';
import { randomUUID } from 'node:crypto';
import { parseEcoflowPayload } from '../parser/ecoflowPayloadParser.js';
function toBool(value) {
    if (typeof value === 'boolean') {
        return value;
    }
    if (typeof value === 'number') {
        return value !== 0;
    }
    if (typeof value === 'string') {
        const normalized = value.trim().toLowerCase();
        if (['1', 'true', 'online', 'on'].includes(normalized)) {
            return true;
        }
        if (['0', 'false', 'offline', 'off'].includes(normalized)) {
            return false;
        }
    }
    return null;
}
function extractSnFromTopic(topic, userId) {
    const parts = topic.split('/').filter(Boolean);
    if (parts.length >= 4 && parts[0] === 'app' && parts[1] === 'device' && parts[2] === 'property') {
        return parts[3] ?? null;
    }
    if (parts.length >= 5 && parts[0] === 'app' && parts[1] === userId) {
        return parts[2] ?? null;
    }
    return null;
}
export class MqttIngestService {
    _config;
    store;
    events;
    cert;
    deviceIds;
    client = null;
    commandTimer = null;
    unknownParseCount = 0;
    constructor(_config, store, events, cert, deviceIds) {
        this._config = _config;
        this.store = store;
        this.events = events;
        this.cert = cert;
        this.deviceIds = deviceIds;
    }
    start() {
        const protocol = this.cert.useTls ? 'mqtts' : 'mqtt';
        const url = `${protocol}://${this.cert.host}:${this.cert.port}`;
        const options = {
            reconnectPeriod: 2000,
            username: this.cert.username,
            password: this.cert.password,
            clientId: `ANDROID_${randomUUID()}_${this.cert.userId}`,
            protocolVersion: 4,
        };
        this.client = mqtt.connect(url, options);
        this.client.on('connect', () => {
            const topics = new Set();
            for (const sn of this.deviceIds) {
                topics.add(`/app/device/property/${sn}`);
                topics.add(`/app/${this.cert.userId}/${sn}/thing/property/get_reply`);
                topics.add(`/app/${this.cert.userId}/${sn}/thing/property/set_reply`);
            }
            this.client?.subscribe([...topics], { qos: 1 }, (error) => {
                if (error) {
                    console.error(`[bridge][mqtt] subscribe error: ${error.message}`);
                    return;
                }
                console.log(`[bridge][mqtt] subscribed ${topics.size} topics`);
            });
            this.requestLatestQuotas();
            this.startCommandLoop();
        });
        this.client.on('message', (topic, payloadBuffer) => {
            const sn = extractSnFromTopic(topic, this.cert.userId);
            if (!sn) {
                return;
            }
            const parsed = parseEcoflowPayload(payloadBuffer);
            const params = parsed.params;
            if (!params || Object.keys(params).length === 0) {
                this.unknownParseCount += 1;
                if (this.unknownParseCount <= 20 || this.unknownParseCount % 50 === 0) {
                    console.warn(`[bridge][mqtt] unparsed(${this.unknownParseCount}) topic=${topic} mode=${parsed.debug.mode} preview=${parsed.debug.preview} hex=${parsed.debug.hex}`);
                }
                return;
            }
            const changed = {};
            for (const [rawKey, rawValue] of Object.entries(params)) {
                const key = rawKey.trim();
                if (!key) {
                    continue;
                }
                let channel = 'raw';
                let state = key;
                if (key.includes('.')) {
                    const [first, ...rest] = key.split('.');
                    channel = first || 'raw';
                    state = rest.join('.') || key;
                }
                else if (key === 'soc' || key === 'batterySoc') {
                    channel = 'pd';
                    state = 'soc';
                }
                else if (key === 'inPower') {
                    channel = 'pd';
                    state = 'inputWatts';
                }
                else if (key === 'outPower') {
                    channel = 'pd';
                    state = 'outputWatts';
                }
                else if (key === 'temp') {
                    channel = 'pd';
                    state = 'temp';
                }
                const delta = this.store.upsertMetric(sn, channel, state, rawValue);
                Object.assign(changed, delta.changed);
            }
            const online = toBool((params.status ?? params.online ?? params.isOnline));
            if (online !== null) {
                const statusDelta = this.store.upsertStatus(sn, online ? 'online' : 'offline');
                Object.assign(changed, statusDelta.changed);
            }
            this.events.onDeviceDelta(sn, {
                deviceId: sn,
                changed,
                updatedAt: new Date().toISOString(),
            });
        });
        this.client.on('error', (error) => {
            console.error(`[bridge][mqtt] error: ${error.message}`);
        });
        this.client.on('reconnect', () => {
            console.log('[bridge][mqtt] reconnecting...');
        });
    }
    stop() {
        if (this.commandTimer) {
            clearInterval(this.commandTimer);
            this.commandTimer = null;
        }
        if (!this.client) {
            return;
        }
        this.client.end(true);
        this.client = null;
    }
    startCommandLoop() {
        if (this.commandTimer) {
            clearInterval(this.commandTimer);
        }
        this.commandTimer = setInterval(() => {
            this.requestLatestQuotas();
        }, 25000);
    }
    requestLatestQuotas() {
        if (!this.client || !this.client.connected) {
            return;
        }
        for (const sn of this.deviceIds) {
            const payload = JSON.stringify({
                id: Date.now().toString(),
                version: '1.1',
                from: 'Android',
                operateType: 'latestQuotas',
                params: {},
            });
            this.client.publish(`/app/${this.cert.userId}/${sn}/thing/property/get`, payload, { qos: 1, retain: false });
        }
    }
}
