import assert from 'node:assert/strict';
import test from 'node:test';

import { decodeModelTelemetry } from '../src/parser/decoders/index.js';

test('delta pro 3 decoder maps extra battery outputs from protobuf-style keys', () => {
  const params = decodeModelTelemetry({
    pow_get_4p8_1: 120,
    pow_get_4p8_2: 80,
  }, {
    model: 'Delta Pro 3',
    envelope: { cmdFunc: 254, cmdId: 21 },
  });

  assert.equal(params['pd.powGet4p81'], 120);
  assert.equal(params['pd.powGet4p82'], 80);
});

test('river3 decoder infers cfg_ac_out_open when firmware omits it', () => {
  const params = decodeModelTelemetry({
    output_power_off_memory: 1,
  }, {
    model: 'RIVER 3',
    envelope: { cmdFunc: 254, cmdId: 22 },
  });

  assert.equal(params.cfg_ac_out_open, 1);
});

