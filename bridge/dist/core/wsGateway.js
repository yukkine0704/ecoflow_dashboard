import { createServer } from 'node:http';
import { WebSocketServer } from 'ws';
export class WsGateway {
    config;
    store;
    server;
    wss;
    catalog = { devices: [] };
    constructor(config, store) {
        this.config = config;
        this.store = store;
        this.server = createServer();
        this.wss = new WebSocketServer({ noServer: true });
        this.server.on('upgrade', (request, socket, head) => {
            const url = new URL(request.url || '/', `http://${request.headers.host || 'localhost'}`);
            if (url.pathname !== '/ws') {
                socket.destroy();
                return;
            }
            this.wss.handleUpgrade(request, socket, head, (ws) => {
                this.wss.emit('connection', ws, request);
            });
        });
        this.wss.on('connection', (ws, request) => {
            this.onConnection(ws, request);
        });
    }
    start() {
        this.server.listen(this.config.wsPort, this.config.wsHost, () => {
            console.log(`[bridge][ws] listening on ws://${this.config.wsHost}:${this.config.wsPort}/ws`);
        });
    }
    stop() {
        for (const client of this.wss.clients) {
            client.close();
        }
        this.wss.close();
        this.server.close();
    }
    broadcastFleetState() {
        const payload = this.store.getFleetState();
        if (this.config.wsEmitV1) {
            const envelope = {
                version: 'v1',
                event: 'fleet_state',
                payload,
            };
            this.broadcast(envelope);
        }
        if (this.config.wsEmitV2) {
            const envelopeV2 = {
                version: 'v2',
                event: 'fleet_state',
                payload,
            };
            this.broadcast(envelopeV2);
        }
    }
    broadcastDeviceSnapshot(deviceId) {
        const snapshot = this.store.getSnapshot(deviceId);
        if (!snapshot) {
            return;
        }
        const payload = { snapshot };
        if (this.config.wsEmitV1) {
            const envelope = {
                version: 'v1',
                event: 'device_snapshot',
                payload,
            };
            this.broadcast(envelope);
        }
        if (this.config.wsEmitV2) {
            const envelopeV2 = {
                version: 'v2',
                event: 'device_snapshot',
                payload,
            };
            this.broadcast(envelopeV2);
        }
    }
    broadcastDeviceDelta(delta) {
        if (this.config.wsEmitV1) {
            const envelope = {
                version: 'v1',
                event: 'device_delta',
                payload: delta,
            };
            this.broadcast(envelope);
        }
        if (this.config.wsEmitV2) {
            const envelopeV2 = {
                version: 'v2',
                event: 'device_delta',
                payload: delta,
            };
            this.broadcast(envelopeV2);
        }
    }
    broadcastCatalog(payload) {
        this.catalog = payload;
        if (this.config.wsEmitV1) {
            const envelope = {
                version: 'v1',
                event: 'device_catalog',
                payload,
            };
            this.broadcast(envelope);
        }
        if (this.config.wsEmitV2) {
            const envelopeV2 = {
                version: 'v2',
                event: 'device_catalog',
                payload,
            };
            this.broadcast(envelopeV2);
        }
    }
    onConnection(ws, _request) {
        if (this.config.wsEmitV1) {
            const fleetEnvelope = {
                version: 'v1',
                event: 'fleet_state',
                payload: this.store.getFleetState(),
            };
            ws.send(JSON.stringify(fleetEnvelope));
        }
        if (this.config.wsEmitV2) {
            const fleetEnvelopeV2 = {
                version: 'v2',
                event: 'fleet_state',
                payload: this.store.getFleetState(),
            };
            ws.send(JSON.stringify(fleetEnvelopeV2));
        }
        if (this.config.wsEmitV1) {
            const catalogEnvelope = {
                version: 'v1',
                event: 'device_catalog',
                payload: this.catalog,
            };
            ws.send(JSON.stringify(catalogEnvelope));
        }
        if (this.config.wsEmitV2) {
            const catalogEnvelopeV2 = {
                version: 'v2',
                event: 'device_catalog',
                payload: this.catalog,
            };
            ws.send(JSON.stringify(catalogEnvelopeV2));
        }
        for (const snapshot of this.store.getAllSnapshots()) {
            if (this.config.wsEmitV1) {
                const snapshotEnvelope = {
                    version: 'v1',
                    event: 'device_snapshot',
                    payload: { snapshot },
                };
                ws.send(JSON.stringify(snapshotEnvelope));
            }
            if (this.config.wsEmitV2) {
                const snapshotEnvelopeV2 = {
                    version: 'v2',
                    event: 'device_snapshot',
                    payload: { snapshot },
                };
                ws.send(JSON.stringify(snapshotEnvelopeV2));
            }
        }
    }
    broadcast(envelope) {
        const payload = JSON.stringify(envelope);
        for (const client of this.wss.clients) {
            if (client.readyState === client.OPEN) {
                client.send(payload);
            }
        }
    }
}
