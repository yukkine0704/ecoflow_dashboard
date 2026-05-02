const BMS_HEARTBEAT_COMMANDS = new Set([
    '3:1', '3:2', '3:30', '3:50',
    '254:24', '254:25', '254:26', '254:27', '254:28', '254:29', '254:30',
    '32:1', '32:3', '32:50', '32:51', '32:52',
]);
function normalizeKeys(input) {
    const out = {};
    for (const [key, value] of Object.entries(input)) {
        out[key] = value;
        out[key.replace(/_/g, '')] = value;
    }
    return out;
}
function getNumber(out, keys) {
    for (const key of keys) {
        const value = out[key];
        if (typeof value === 'number' && Number.isFinite(value))
            return value;
    }
    return null;
}
function mapExtraBatteryMetrics(out) {
    const rawNum = getNumber(out, [
        'num',
        'battery_num',
        'batterynum',
        'bat_num',
        'batnum',
        'bp_num',
        'bpnum',
    ]);
    if (rawNum === null)
        return;
    const batteryIndex = Math.round(rawNum);
    if (!Number.isFinite(batteryIndex) || batteryIndex < 1 || batteryIndex > 8)
        return;
    const prefix = `pd.extraBattery${batteryIndex}`;
    const soc = getNumber(out, ['soc']);
    if (soc !== null)
        out[`${prefix}.soc`] = soc;
    const temp = getNumber(out, ['temp']);
    if (temp !== null)
        out[`${prefix}.temp`] = temp;
    const maxCellTemp = getNumber(out, ['max_cell_temp', 'maxcelltemp']);
    if (maxCellTemp !== null)
        out[`${prefix}.maxCellTemp`] = maxCellTemp;
    const minCellTemp = getNumber(out, ['min_cell_temp', 'mincelltemp']);
    if (minCellTemp !== null)
        out[`${prefix}.minCellTemp`] = minCellTemp;
    const f32ShowSoc = getNumber(out, ['f32_show_soc', 'f32showsoc']);
    if (f32ShowSoc !== null)
        out[`${prefix}.f32ShowSoc`] = f32ShowSoc;
    const inputWatts = getNumber(out, ['input_watts', 'inputwatts']);
    if (inputWatts !== null)
        out[`${prefix}.inputWatts`] = inputWatts;
    const outputWatts = getNumber(out, ['output_watts', 'outputwatts']);
    if (outputWatts !== null)
        out[`${prefix}.outputWatts`] = outputWatts;
    const cycles = getNumber(out, ['cycles']);
    if (cycles !== null)
        out[`${prefix}.cycles`] = cycles;
}
function routeByEnvelope(params, ctx) {
    const out = { ...params };
    if (!ctx.envelope)
        return out;
    const key = `${ctx.envelope.cmdFunc}:${ctx.envelope.cmdId}`;
    if (BMS_HEARTBEAT_COMMANDS.has(key)) {
        if (out.cycles !== undefined)
            out['bms.cycles'] = out.cycles;
        if (out.accu_chg_energy !== undefined)
            out['pd.accuChgEnergy'] = out.accu_chg_energy;
        if (out.accu_dsg_energy !== undefined)
            out['pd.accuDsgEnergy'] = out.accu_dsg_energy;
        mapExtraBatteryMetrics(out);
    }
    if (ctx.envelope.cmdFunc === 254 && ctx.envelope.cmdId === 21) {
        if (out.pow_get_4p8_1 !== undefined)
            out['pd.powGet4p81'] = out.pow_get_4p8_1;
        if (out.pow_get_4p8_2 !== undefined)
            out['pd.powGet4p82'] = out.pow_get_4p8_2;
    }
    return out;
}
export const deltaPro3Decoder = {
    supports(ctx) {
        const model = (ctx.model || '').toLowerCase();
        return model.includes('delta pro 3')
            || model.includes('delta_pro_3')
            || model.includes('delta 3 pro')
            || model.includes('delta 3')
            || model.includes('delta3');
    },
    decode(params, ctx) {
        const normalized = normalizeKeys(params);
        return {
            params: routeByEnvelope(normalized, ctx),
        };
    },
};
