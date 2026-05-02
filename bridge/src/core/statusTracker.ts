import type { DeviceConnectivityState } from './types.js';

interface TrackerState {
  lastDataAtMs: number;
  explicitOffline: boolean;
}

export class StatusTracker {
  private readonly byDevice = new Map<string, TrackerState>();

  constructor(
    private readonly assumeOfflineSec: number,
    private readonly forceOfflineMultiplier: number,
  ) {}

  onDataReceived(deviceId: string): void {
    const item = this.getOrCreate(deviceId);
    item.lastDataAtMs = Date.now();
    item.explicitOffline = false;
  }

  onExplicitStatus(deviceId: string, online: boolean): void {
    const item = this.getOrCreate(deviceId);
    if (online) {
      item.lastDataAtMs = Date.now();
      item.explicitOffline = false;
      return;
    }
    item.explicitOffline = true;
  }

  state(deviceId: string): DeviceConnectivityState {
    const item = this.getOrCreate(deviceId);
    if (item.explicitOffline) return 'offline';

    const ageSec = (Date.now() - item.lastDataAtMs) / 1000;
    if (ageSec < this.assumeOfflineSec) return 'online';
    if (ageSec < this.assumeOfflineSec * this.forceOfflineMultiplier) return 'assume_offline';
    return 'offline';
  }

  wantsStatusPoll(deviceId: string): boolean {
    return this.state(deviceId) === 'assume_offline';
  }

  private getOrCreate(deviceId: string): TrackerState {
    const existing = this.byDevice.get(deviceId);
    if (existing) return existing;
    const created: TrackerState = {
      lastDataAtMs: 0,
      explicitOffline: false,
    };
    this.byDevice.set(deviceId, created);
    return created;
  }
}

