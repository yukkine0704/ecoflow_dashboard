import assert from 'node:assert/strict';
import test from 'node:test';

import { DeviceStateStore } from '../src/core/deviceStateStore.js';

test('battery/temperature mapping prefers stable BMS and exposes maxCellTemp metric', () => {
  const store = new DeviceStateStore();
  const deviceId = 'R651ZAB5XH111262';

  store.upsertMetric(deviceId, 'pd', 'soc', 80);
  store.upsertMetric(deviceId, 'bms', 'f32ShowSoc', 81.4);
  store.upsertMetric(deviceId, 'bms', 'temp', 23);
  store.upsertMetric(deviceId, 'bms', 'maxCellTemp', 27);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.batteryPercent, 80);
  assert.equal(snapshot.temperatureC, 23);
  assert.equal(snapshot.metrics['battery.maxCellTempC'], 27);
});

test('input/output by type aggregate without double counting when component metrics exist', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'pd', 'inputWatts', 500);
  store.upsertMetric(deviceId, 'pd', 'powGetAcIn', 300);
  store.upsertMetric(deviceId, 'pd', 'powGetPv', 200);

  store.upsertMetric(deviceId, 'pd', 'outputWatts', 400);
  store.upsertMetric(deviceId, 'pd', 'powGetAcOut', 250);
  store.upsertMetric(deviceId, 'pd', 'powGet12v', 50);
  store.upsertMetric(deviceId, 'pd', 'powGetTypec1', 100);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.totalInputW, 500);
  assert.equal(snapshot.metrics['inputByType.acW'], 300);
  assert.equal(snapshot.metrics['inputByType.solarW'], 200);

  assert.equal(snapshot.totalOutputW, 400);
  assert.equal(snapshot.metrics['outputByType.acW'], 250);
  assert.equal(snapshot.metrics['outputByType.dcW'], 150);
});

test('delta3 pro keeps usb/typec watts in dc output bucket', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'pd', 'powGetAcOut', -458);
  store.upsertMetric(deviceId, 'pd', 'usb1Watts', 6);
  store.upsertMetric(deviceId, 'pd', 'typec1Watts', 4);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.metrics['outputByType.acW'], -458);
  assert.equal(snapshot.metrics['outputByType.dcW'], 10);
});

test('delta3 fallback uses total input as solar when only powGetPv is present', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'pd', 'inputWatts', 54);
  store.upsertMetric(deviceId, 'pd', 'powGetPv', 20.7);
  store.upsertMetric(deviceId, 'pd', 'powGetAcIn', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp2', 0);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.metrics['inputByType.solarW'], 54);
  assert.equal(snapshot.metrics['pd.powGetPvL'], 33.3);
});

test('delta3 fallback corrects pvL=0 when total input indicates second panel', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'pd', 'inputWatts', 62);
  store.upsertMetric(deviceId, 'pd', 'powGetPv', 23.5);
  store.upsertMetric(deviceId, 'pd', 'powGetPvL', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetAcIn', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp2', 0);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.metrics['inputByType.solarW'], 62);
});

test('delta3 fallback prefers pd.inputWatts over bms.inputWatts for dual-solar inference', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'bms', 'inputWatts', 200);
  store.upsertMetric(deviceId, 'pd', 'inputWatts', 1007);
  store.upsertMetric(deviceId, 'pd', 'powGetPv', 505.27899169921875);
  store.upsertMetric(deviceId, 'pd', 'powGetAcIn', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp2', 0);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.metrics['inputByType.solarW'], 1007);
  assert.equal(snapshot.metrics['pd.powGetPvL'], 501.72100830078125);
});

test('ignores implausible pd.inputWatts outlier to avoid solar overflow', () => {
  const store = new DeviceStateStore();
  const deviceId = 'P351ZAHAPH2R2706';

  store.upsertMetric(deviceId, 'pd', 'inputWatts', 1007);
  store.upsertMetric(deviceId, 'pd', 'powGetPv', 505.27899169921875);
  store.upsertMetric(deviceId, 'pd', 'powGetAcIn', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp', 0);
  store.upsertMetric(deviceId, 'pd', 'powGetDcp2', 0);

  // Corrupted value observed in the wild.
  store.upsertMetric(deviceId, 'pd', 'inputWatts', 2.749712204023792e+23);

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.totalInputW, 1007);
  assert.equal(snapshot.metrics['inputByType.solarW'], 1007);
});

test('connectivity is exposed in snapshot and fleet payload', () => {
  const store = new DeviceStateStore();
  const deviceId = 'RIVER3SN';
  store.upsertConnectivity(deviceId, 'assume_offline');

  const snapshot = store.getSnapshot(deviceId);
  assert.ok(snapshot);
  assert.equal(snapshot.connectivity, 'assume_offline');
  assert.equal(snapshot.online, null);

  const fleet = store.getFleetState();
  assert.equal(fleet.devices[0]?.connectivity, 'assume_offline');
});
