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
        const envelope = {
            version: 'v1',
            event: 'fleet_state',
            payload,
        };
        this.broadcast(envelope);
    }
    broadcastDeviceSnapshot(deviceId) {
        const snapshot = this.store.getSnapshot(deviceId);
        if (!snapshot) {
            return;
        }
        const payload = { snapshot };
        const envelope = {
            version: 'v1',
            event: 'device_snapshot',
            payload,
        };
        this.broadcast(envelope);
    }
    broadcastDeviceDelta(delta) {
        const envelope = {
            version: 'v1',
            event: 'device_delta',
            payload: delta,
        };
        this.broadcast(envelope);
    }
    broadcastCatalog(payload) {
        this.catalog = payload;
        const envelope = {
            version: 'v1',
            event: 'device_catalog',
            payload,
        };
        this.broadcast(envelope);
    }
    onConnection(ws, _request) {
        const fleetEnvelope = {
            version: 'v1',
            event: 'fleet_state',
            payload: this.store.getFleetState(),
        };
        ws.send(JSON.stringify(fleetEnvelope));
        const catalogEnvelope = {
            version: 'v1',
            event: 'device_catalog',
            payload: this.catalog,
        };
        ws.send(JSON.stringify(catalogEnvelope));
        for (const snapshot of this.store.getAllSnapshots()) {
            const snapshotEnvelope = {
                version: 'v1',
                event: 'device_snapshot',
                payload: { snapshot },
            };
            ws.send(JSON.stringify(snapshotEnvelope));
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
