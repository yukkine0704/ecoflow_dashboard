import { createServer, type IncomingMessage } from 'node:http';
import { WebSocketServer, type WebSocket } from 'ws';

import type { BridgeConfig } from '../config/index.js';
import type { DeviceStateStore } from './deviceStateStore.js';
import type {
  BridgeEnvelope,
  BridgeEnvelopeV2,
  DeviceCatalogPayload,
  DeviceDeltaPayload,
  DeviceSnapshotPayload,
  FleetStatePayload,
} from './types.js';

export class WsGateway {
  private readonly server;
  private readonly wss;
  private catalog: DeviceCatalogPayload = { devices: [] };

  constructor(
    private readonly config: BridgeConfig,
    private readonly store: DeviceStateStore,
  ) {
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

  start(): void {
    this.server.listen(this.config.wsPort, this.config.wsHost, () => {
      console.log(`[bridge][ws] listening on ws://${this.config.wsHost}:${this.config.wsPort}/ws`);
    });
  }

  stop(): void {
    for (const client of this.wss.clients) {
      client.close();
    }
    this.wss.close();
    this.server.close();
  }

  broadcastFleetState(): void {
    const payload: FleetStatePayload = this.store.getFleetState();
    if (this.config.wsEmitV1) {
      const envelope: BridgeEnvelope<FleetStatePayload> = {
        version: 'v1',
        event: 'fleet_state',
        payload,
      };
      this.broadcast(envelope);
    }
    if (this.config.wsEmitV2) {
      const envelopeV2: BridgeEnvelopeV2<FleetStatePayload> = {
        version: 'v2',
        event: 'fleet_state',
        payload,
      };
      this.broadcast(envelopeV2);
    }
  }

  broadcastDeviceSnapshot(deviceId: string): void {
    const snapshot = this.store.getSnapshot(deviceId);
    if (!snapshot) {
      return;
    }

    const payload: DeviceSnapshotPayload = { snapshot };
    if (this.config.wsEmitV1) {
      const envelope: BridgeEnvelope<DeviceSnapshotPayload> = {
        version: 'v1',
        event: 'device_snapshot',
        payload,
      };
      this.broadcast(envelope);
    }
    if (this.config.wsEmitV2) {
      const envelopeV2: BridgeEnvelopeV2<DeviceSnapshotPayload> = {
        version: 'v2',
        event: 'device_snapshot',
        payload,
      };
      this.broadcast(envelopeV2);
    }
  }

  broadcastDeviceDelta(delta: DeviceDeltaPayload): void {
    if (this.config.wsEmitV1) {
      const envelope: BridgeEnvelope<DeviceDeltaPayload> = {
        version: 'v1',
        event: 'device_delta',
        payload: delta,
      };
      this.broadcast(envelope);
    }
    if (this.config.wsEmitV2) {
      const envelopeV2: BridgeEnvelopeV2<DeviceDeltaPayload> = {
        version: 'v2',
        event: 'device_delta',
        payload: delta,
      };
      this.broadcast(envelopeV2);
    }
  }

  broadcastCatalog(payload: DeviceCatalogPayload): void {
    this.catalog = payload;
    if (this.config.wsEmitV1) {
      const envelope: BridgeEnvelope<DeviceCatalogPayload> = {
        version: 'v1',
        event: 'device_catalog',
        payload,
      };
      this.broadcast(envelope);
    }
    if (this.config.wsEmitV2) {
      const envelopeV2: BridgeEnvelopeV2<DeviceCatalogPayload> = {
        version: 'v2',
        event: 'device_catalog',
        payload,
      };
      this.broadcast(envelopeV2);
    }
  }

  private onConnection(ws: WebSocket, _request: IncomingMessage): void {
    if (this.config.wsEmitV1) {
      const fleetEnvelope: BridgeEnvelope<FleetStatePayload> = {
        version: 'v1',
        event: 'fleet_state',
        payload: this.store.getFleetState(),
      };
      ws.send(JSON.stringify(fleetEnvelope));
    }
    if (this.config.wsEmitV2) {
      const fleetEnvelopeV2: BridgeEnvelopeV2<FleetStatePayload> = {
        version: 'v2',
        event: 'fleet_state',
        payload: this.store.getFleetState(),
      };
      ws.send(JSON.stringify(fleetEnvelopeV2));
    }

    if (this.config.wsEmitV1) {
      const catalogEnvelope: BridgeEnvelope<DeviceCatalogPayload> = {
        version: 'v1',
        event: 'device_catalog',
        payload: this.catalog,
      };
      ws.send(JSON.stringify(catalogEnvelope));
    }
    if (this.config.wsEmitV2) {
      const catalogEnvelopeV2: BridgeEnvelopeV2<DeviceCatalogPayload> = {
        version: 'v2',
        event: 'device_catalog',
        payload: this.catalog,
      };
      ws.send(JSON.stringify(catalogEnvelopeV2));
    }

    for (const snapshot of this.store.getAllSnapshots()) {
      if (this.config.wsEmitV1) {
        const snapshotEnvelope: BridgeEnvelope<DeviceSnapshotPayload> = {
          version: 'v1',
          event: 'device_snapshot',
          payload: { snapshot },
        };
        ws.send(JSON.stringify(snapshotEnvelope));
      }
      if (this.config.wsEmitV2) {
        const snapshotEnvelopeV2: BridgeEnvelopeV2<DeviceSnapshotPayload> = {
          version: 'v2',
          event: 'device_snapshot',
          payload: { snapshot },
        };
        ws.send(JSON.stringify(snapshotEnvelopeV2));
      }
    }
  }

  private broadcast(envelope: unknown): void {
    const payload = JSON.stringify(envelope);
    for (const client of this.wss.clients) {
      if (client.readyState === client.OPEN) {
        client.send(payload);
      }
    }
  }
}
