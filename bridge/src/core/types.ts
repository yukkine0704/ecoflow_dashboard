export type BridgeMetricValue = number | boolean | string | null;
export type DeviceConnectivityState = 'online' | 'assume_offline' | 'offline';

export interface DeviceSnapshot {
  deviceId: string;
  displayName: string;
  model: string | null;
  imageUrl: string | null;
  online: boolean | null;
  connectivity: DeviceConnectivityState;
  batteryPercent: number | null;
  temperatureC: number | null;
  totalInputW: number | null;
  totalOutputW: number | null;
  metrics: Record<string, BridgeMetricValue>;
  updatedAt: string;
}

export interface FleetItem {
  deviceId: string;
  displayName: string;
  model: string | null;
  online: boolean | null;
  connectivity: DeviceConnectivityState;
  batteryPercent: number | null;
  updatedAt: string;
}

export interface FleetStatePayload {
  devices: FleetItem[];
}

export interface DeviceSnapshotPayload {
  snapshot: DeviceSnapshot;
}

export interface DeviceDeltaPayload {
  deviceId: string;
  changed: Record<string, BridgeMetricValue>;
  updatedAt: string;
}

export interface DeviceCatalogItem {
  deviceId: string;
  displayName: string;
  model: string | null;
  imageUrl: string | null;
}

export interface DeviceCatalogPayload {
  devices: DeviceCatalogItem[];
}

export interface BridgeEnvelope<TPayload> {
  version: 'v1';
  event: 'fleet_state' | 'device_snapshot' | 'device_delta' | 'device_catalog';
  payload: TPayload;
}

export interface BridgeEnvelopeV2<TPayload> {
  version: 'v2';
  event: 'fleet_state' | 'device_snapshot' | 'device_delta' | 'device_catalog';
  payload: TPayload;
}
