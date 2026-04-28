import assert from 'node:assert/strict';
import test from 'node:test';

import { canonicalizeMetric } from '../src/mapping/normalize.js';

test('canonicalizeMetric normalizes snake_case/camelCase/PascalCase', () => {
  assert.deepEqual(canonicalizeMetric('RuntimePropertyUpload', 'pow_get_ac_in'), {
    channel: 'pd',
    state: 'powGetAcIn',
  });

  assert.deepEqual(canonicalizeMetric('bms_heart_beat_report', 'f32_show_soc'), {
    channel: 'bms',
    state: 'f32ShowSoc',
  });

  assert.deepEqual(canonicalizeMetric('BMSHeartBeatReport', 'Max_Cell_Temp'), {
    channel: 'bms',
    state: 'maxCellTemp',
  });
});

