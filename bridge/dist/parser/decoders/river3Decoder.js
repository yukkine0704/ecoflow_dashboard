const BMS_HEARTBEAT_COMMANDS = new Set([
    '3:1', '3:2', '3:30', '3:50',
    '32:1', '32:3', '32:50', '32:51', '32:52',
    '254:24', '254:25', '254:26', '254:27', '254:28', '254:29', '254:30',
]);
function routeByEnvelope(params, ctx) {
    const out = { ...params };
    if (!ctx.envelope)
        return out;
    const key = `${ctx.envelope.cmdFunc}:${ctx.envelope.cmdId}`;
    if (ctx.envelope.cmdFunc === 254 && ctx.envelope.cmdId === 21) {
        const stats = out.display_statistics_sum;
        if (stats && typeof stats === 'object') {
            out['river3.displayStatistics'] = stats;
        }
    }
    if (BMS_HEARTBEAT_COMMANDS.has(key)) {
        if (out.accu_chg_energy !== undefined)
            out['pd.accuChgEnergy'] = out.accu_chg_energy;
        if (out.accu_dsg_energy !== undefined)
            out['pd.accuDsgEnergy'] = out.accu_dsg_energy;
    }
    // River 3 firmware may omit cfg_ac_out_open; infer from output_power_off_memory.
    if (out.cfg_ac_out_open === undefined && out.output_power_off_memory !== undefined) {
        out.cfg_ac_out_open = out.output_power_off_memory ? 1 : 0;
    }
    return out;
}
export const river3Decoder = {
    supports(ctx) {
        const model = (ctx.model || '').toLowerCase();
        return model.includes('river 3') || model.includes('river_3');
    },
    decode(params, ctx) {
        return { params: routeByEnvelope(params, ctx) };
    },
};
