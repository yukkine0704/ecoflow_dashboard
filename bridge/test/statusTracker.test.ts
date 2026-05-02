import assert from 'node:assert/strict';
import test from 'node:test';

import { StatusTracker } from '../src/core/statusTracker.js';

test('status tracker transitions online -> assume_offline -> offline', async () => {
  const tracker = new StatusTracker(1, 2);
  const sn = 'TEST123';

  tracker.onDataReceived(sn);
  assert.equal(tracker.state(sn), 'online');

  await new Promise((resolve) => setTimeout(resolve, 1100));
  assert.equal(tracker.state(sn), 'assume_offline');

  await new Promise((resolve) => setTimeout(resolve, 1200));
  assert.equal(tracker.state(sn), 'offline');
});

test('explicit offline overrides implicit status until data arrives', () => {
  const tracker = new StatusTracker(60, 3);
  const sn = 'TEST123';

  tracker.onDataReceived(sn);
  tracker.onExplicitStatus(sn, false);
  assert.equal(tracker.state(sn), 'offline');

  tracker.onDataReceived(sn);
  assert.equal(tracker.state(sn), 'online');
});

