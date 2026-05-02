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

test('delta pro 3 decoder maps extra battery heartbeat metrics using battery num', () => {
  const params = decodeModelTelemetry({
    num: 2,
    soc: 74,
    temp: 31,
    max_cell_temp: 34,
    min_cell_temp: 28,
    f32_show_soc: 73.6,
    input_watts: 412,
    output_watts: 0,
    cycles: 98,
  }, {
    model: 'Delta Pro 3',
    envelope: { cmdFunc: 32, cmdId: 50 },
  });

  assert.equal(params['pd.extraBattery2.soc'], 74);
  assert.equal(params['pd.extraBattery2.temp'], 31);
  assert.equal(params['pd.extraBattery2.maxCellTemp'], 34);
  assert.equal(params['pd.extraBattery2.minCellTemp'], 28);
  assert.equal(params['pd.extraBattery2.f32ShowSoc'], 73.6);
  assert.equal(params['pd.extraBattery2.inputWatts'], 412);
  assert.equal(params['pd.extraBattery2.outputWatts'], 0);
  assert.equal(params['pd.extraBattery2.cycles'], 98);
});

test('delta pro 3 decoder supports compact heartbeat keys for extra battery mapping', () => {
  const params = decodeModelTelemetry({
    num: 1,
    maxcelltemp: 36,
    mincelltemp: 30,
    f32showsoc: 80.1,
    inputwatts: 505,
    outputwatts: 0,
  }, {
    model: 'delta_pro_3',
    envelope: { cmdFunc: 254, cmdId: 24 },
  });

  assert.equal(params['pd.extraBattery1.maxCellTemp'], 36);
  assert.equal(params['pd.extraBattery1.minCellTemp'], 30);
  assert.equal(params['pd.extraBattery1.f32ShowSoc'], 80.1);
  assert.equal(params['pd.extraBattery1.inputWatts'], 505);
  assert.equal(params['pd.extraBattery1.outputWatts'], 0);
});

test('delta pro 3 decoder maps extra battery metrics when battery index uses battery_num', () => {
  const params = decodeModelTelemetry({
    battery_num: 1,
    soc: 66,
    temp: 29,
    input_watts: 210,
  }, {
    model: 'Delta 3',
    envelope: { cmdFunc: 32, cmdId: 50 },
  });

  assert.equal(params['pd.extraBattery1.soc'], 66);
  assert.equal(params['pd.extraBattery1.temp'], 29);
  assert.equal(params['pd.extraBattery1.inputWatts'], 210);
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
