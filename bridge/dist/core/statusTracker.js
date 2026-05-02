export class StatusTracker {
    assumeOfflineSec;
    forceOfflineMultiplier;
    byDevice = new Map();
    constructor(assumeOfflineSec, forceOfflineMultiplier) {
        this.assumeOfflineSec = assumeOfflineSec;
        this.forceOfflineMultiplier = forceOfflineMultiplier;
    }
    onDataReceived(deviceId) {
        const item = this.getOrCreate(deviceId);
        item.lastDataAtMs = Date.now();
        item.explicitOffline = false;
    }
    onExplicitStatus(deviceId, online) {
        const item = this.getOrCreate(deviceId);
        if (online) {
            item.lastDataAtMs = Date.now();
            item.explicitOffline = false;
            return;
        }
        item.explicitOffline = true;
    }
    state(deviceId) {
        const item = this.getOrCreate(deviceId);
        if (item.explicitOffline)
            return 'offline';
        const ageSec = (Date.now() - item.lastDataAtMs) / 1000;
        if (ageSec < this.assumeOfflineSec)
            return 'online';
        if (ageSec < this.assumeOfflineSec * this.forceOfflineMultiplier)
            return 'assume_offline';
        return 'offline';
    }
    wantsStatusPoll(deviceId) {
        return this.state(deviceId) === 'assume_offline';
    }
    getOrCreate(deviceId) {
        const existing = this.byDevice.get(deviceId);
        if (existing)
            return existing;
        const created = {
            lastDataAtMs: 0,
            explicitOffline: false,
        };
        this.byDevice.set(deviceId, created);
        return created;
    }
}
