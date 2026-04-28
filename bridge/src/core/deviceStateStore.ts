import { findRule } from '../mapping/rules.js';
import type { DeviceDeltaPayload, DeviceSnapshot, FleetStatePayload } from './types.js';

type PrimitiveMetric = number | boolean | string | null;

interface DeviceRecord {
  snapshot: DeviceSnapshot;
  inputComponents: Record<string, number>;
  outputComponents: Record<string, number>;
}

function toNumber(value: PrimitiveMetric): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function sumValues(values: Record<string, number>): number | null {
  const items = Object.values(values);
  if (items.length === 0) {
    return null;
  }
  return items.reduce((acc, value) => acc + value, 0);
}

export class DeviceStateStore {
  private readonly devices = new Map<string, DeviceRecord>();

  private isBatteryJumpSuspicious(previous: number | null, next: number): boolean {
    if (previous === null) return false;
    return Math.abs(previous - next) > 20;
  }

  private isTemperatureJumpSuspicious(previous: number | null, next: number): boolean {
    if (previous === null) return false;
    return Math.abs(previous - next) > 12;
  }

  private detectInputType(metricKey: string): 'solar' | 'ac' | 'car' | 'dc' | 'other' {
    const key = metricKey.toLowerCase();
    if (key.includes('powgetpv') || key.includes('pv') || key.includes('solar')) return 'solar';
    if (key.includes('powgetacin') || key.includes('acin') || key.includes('acinput') || key.includes('ac.in')) return 'ac';
    if (key.includes('powgetdcp2') || key.includes('carin') || key.includes('car')) return 'car';
    if (key.includes('powgetdcp') || key.includes('dcin') || key.includes('dc.in') || key.includes('dcp')) return 'dc';
    if (key.includes('pv') || key.includes('solar')) return 'solar';
    if (key.includes('acin') || key.includes('acinput') || key.includes('ac.in')) return 'ac';
    // When direct protobuf heuristic provides generic `pd.inputWatts`, treat it as AC by default.
    if (key.endsWith('.inputwatts') || key.includes('inputwatts')) return 'ac';
    if (key.includes('carin') || key.includes('car')) return 'car';
    if (key.includes('dcin') || key.includes('dc.in') || key.includes('dcp')) return 'dc';
    return 'other';
  }

  private isSourceSpecificInputMetric(metricKey: string): boolean {
    const key = metricKey.toLowerCase();
    return (
      key.includes('powgetacin')
      || key.includes('powgetpv')
      || key.includes('powgetdcp')
      || key.includes('acinpower')
      || key.includes('carinpower')
      || key.includes('dcinpower')
      || key.includes('pv1inputwatts')
      || key.includes('pv2inputwatts')
    );
  }

  private resolveActiveInputComponents(components: Record<string, number>): Record<string, number> {
    const sourceSpecific = Object.entries(components).filter(([metricKey]) => this.isSourceSpecificInputMetric(metricKey));
    if (sourceSpecific.length > 0) {
      return Object.fromEntries(sourceSpecific);
    }
    return components;
  }

  private refreshInputByType(
    components: Record<string, number>,
    record: DeviceRecord,
    changed: Record<string, PrimitiveMetric>,
  ): void {
    const bucketMap: Record<string, Record<string, number>> = {
      solar: {},
      ac: {},
      car: {},
      dc: {},
      other: {},
    };

    for (const [metricKey, value] of Object.entries(components)) {
      const bucket = this.detectInputType(metricKey);
      bucketMap[bucket][metricKey] = value;
    }

    for (const type of ['solar', 'ac', 'car', 'dc', 'other']) {
      const bucket = bucketMap[type] ?? {};
      const total = sumValues(bucket);
      const metricKey = `inputByType.${type}W`;
      if (total === null) {
        delete record.snapshot.metrics[metricKey];
        changed[`metrics.${metricKey}`] = null;
      } else {
        record.snapshot.metrics[metricKey] = total;
        changed[`metrics.${metricKey}`] = total;
      }
    }
  }

  setCatalog(devices: Array<{ deviceId: string; displayName?: string; model?: string; imageUrl?: string }>): void {
    const now = new Date().toISOString();
    for (const device of devices) {
      const record = this.getOrCreate(device.deviceId, now);
      record.snapshot.displayName = device.displayName?.trim() || record.snapshot.displayName;
      record.snapshot.model = device.model?.trim() || record.snapshot.model;
      record.snapshot.imageUrl = device.imageUrl?.trim() || record.snapshot.imageUrl;
      record.snapshot.updatedAt = now;
    }
  }

  upsertStatus(deviceId: string, rawPayload: string): DeviceDeltaPayload {
    const now = new Date().toISOString();
    const record = this.getOrCreate(deviceId, now);

    const normalized = rawPayload.trim().toLowerCase();
    let online: boolean | null = null;
    if (normalized === 'online' || normalized === '1' || normalized === 'true' || normalized === 'on') {
      online = true;
    }
    if (normalized === 'offline' || normalized === '0' || normalized === 'false' || normalized === 'off') {
      online = false;
    }

    record.snapshot.online = online;
    record.snapshot.updatedAt = now;

    return {
      deviceId,
      changed: { online },
      updatedAt: now,
    };
  }

  upsertMetric(deviceId: string, channel: string, state: string, rawPayload: PrimitiveMetric): DeviceDeltaPayload {
    const now = new Date().toISOString();
    const record = this.getOrCreate(deviceId, now);
    const metricKey = `${channel}.${state}`;

    let normalizedValue: PrimitiveMetric = rawPayload;
    const numeric = toNumber(rawPayload);
    if (numeric !== null) {
      normalizedValue = numeric;
    }

    const changed: Record<string, PrimitiveMetric> = {
      [`metrics.${metricKey}`]: normalizedValue,
    };

    record.snapshot.metrics[metricKey] = normalizedValue;

    const rule = findRule(channel, state);
    if (rule) {
      switch (rule.field) {
        case 'batteryPercent': {
          const battery = toNumber(normalizedValue);
          if (battery !== null) {
            const rounded = Math.round(battery);
            if (!this.isBatteryJumpSuspicious(record.snapshot.batteryPercent, rounded)) {
              record.snapshot.batteryPercent = rounded;
              changed.batteryPercent = record.snapshot.batteryPercent;
            }
          }
          break;
        }
        case 'temperatureC': {
          const temp = toNumber(normalizedValue);
          if (temp !== null) {
            if (!this.isTemperatureJumpSuspicious(record.snapshot.temperatureC, temp)) {
              record.snapshot.temperatureC = temp;
              changed.temperatureC = record.snapshot.temperatureC;
            }
          }
          break;
        }
        case 'totalInputW': {
          const asNumber = toNumber(normalizedValue);
          if (asNumber !== null) {
            record.inputComponents[metricKey] = asNumber;
          } else {
            delete record.inputComponents[metricKey];
          }
          const activeInput = this.resolveActiveInputComponents(record.inputComponents);
          record.snapshot.totalInputW = sumValues(activeInput);
          changed.totalInputW = record.snapshot.totalInputW;
          this.refreshInputByType(activeInput, record, changed);
          break;
        }
        case 'totalOutputW': {
          const asNumber = toNumber(normalizedValue);
          if (asNumber !== null) {
            record.outputComponents[metricKey] = asNumber;
          } else {
            delete record.outputComponents[metricKey];
          }
          record.snapshot.totalOutputW = sumValues(record.outputComponents);
          changed.totalOutputW = record.snapshot.totalOutputW;
          break;
        }
        case 'metric': {
          if (rule.metricKey) {
            changed[`metrics.${rule.metricKey}`] = normalizedValue;
          }
          break;
        }
      }
    }

    record.snapshot.updatedAt = now;
    return {
      deviceId,
      changed,
      updatedAt: now,
    };
  }

  getSnapshot(deviceId: string): DeviceSnapshot | null {
    return this.devices.get(deviceId)?.snapshot ?? null;
  }

  getFleetState(): FleetStatePayload {
    return {
      devices: [...this.devices.values()]
        .map((record) => record.snapshot)
        .sort((a, b) => a.deviceId.localeCompare(b.deviceId))
        .map((snapshot) => ({
          deviceId: snapshot.deviceId,
          displayName: snapshot.displayName,
          model: snapshot.model,
          online: snapshot.online,
          batteryPercent: snapshot.batteryPercent,
          updatedAt: snapshot.updatedAt,
        })),
    };
  }

  getAllSnapshots(): DeviceSnapshot[] {
    return [...this.devices.values()].map((record) => record.snapshot);
  }

  private getOrCreate(deviceId: string, nowIso: string): DeviceRecord {
    const existing = this.devices.get(deviceId);
    if (existing) {
      return existing;
    }

    const created: DeviceRecord = {
      snapshot: {
        deviceId,
        displayName: deviceId,
        model: null,
        imageUrl: null,
        online: null,
        batteryPercent: null,
        temperatureC: null,
        totalInputW: null,
        totalOutputW: null,
        metrics: {},
        updatedAt: nowIso,
      },
      inputComponents: {},
      outputComponents: {},
    };

    this.devices.set(deviceId, created);
    return created;
  }
}
