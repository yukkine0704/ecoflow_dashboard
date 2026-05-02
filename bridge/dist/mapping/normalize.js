function toCamelCase(input) {
    const trimmed = input.trim();
    if (!trimmed)
        return trimmed;
    const withWordBreaks = trimmed
        .replace(/[\s-]+/g, '_')
        .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
        .toLowerCase();
    const parts = withWordBreaks.split('_').filter(Boolean);
    if (parts.length === 0)
        return '';
    return parts[0] + parts.slice(1).map((p) => p[0].toUpperCase() + p.slice(1)).join('');
}
function normalizeChannel(raw) {
    const camel = toCamelCase(raw);
    if (!camel)
        return 'raw';
    if (camel === 'runtimePropertyUpload')
        return 'pd';
    if (camel.toLowerCase().startsWith('bmsheartbeatreport'))
        return 'bms';
    return camel;
}
function normalizeState(raw) {
    const camel = toCamelCase(raw);
    if (!camel)
        return raw;
    const aliases = {
        f32ShowSoc: 'f32ShowSoc',
        f32LcdShowSoc: 'f32LcdShowSoc',
        lcdShowSoc: 'lcdShowSoc',
        bmsBattSoc: 'bmsBattSoc',
        cmsBattSoc: 'cmsBattSoc',
        maxCellTemp: 'maxCellTemp',
        minCellTemp: 'minCellTemp',
        maxMosTemp: 'maxMosTemp',
        minMosTemp: 'minMosTemp',
        tempPcsDc: 'tempPcsDc',
        tempPcsAc: 'tempPcsAc',
        tempPv: 'tempPv',
        tempPv2: 'tempPv2',
        temp: 'temp',
        soc: 'soc',
        inputWatts: 'inputWatts',
        outputWatts: 'outputWatts',
        inPower: 'inPower',
        outPower: 'outPower',
        powGetAcIn: 'powGetAcIn',
        powGetPv: 'powGetPv',
        powGetPvH: 'powGetPvH',
        powGetPvL: 'powGetPvL',
        powGetDcp: 'powGetDcp',
        powGetDcp2: 'powGetDcp2',
        powGetAcOut: 'powGetAcOut',
        powGetAc: 'powGetAcOut',
        powGet12v: 'powGet12v',
        powGet24v: 'powGet24v',
        powGetTypec1: 'powGetTypec1',
        powGetTypec2: 'powGetTypec2',
        powGetQcusb1: 'powGetQcusb1',
        powGetQcusb2: 'powGetQcusb2',
        usb1Watts: 'usb1Watts',
        usb2Watts: 'usb2Watts',
        typec1Watts: 'typec1Watts',
        typec2Watts: 'typec2Watts',
        powGet5p8: 'powGet5p8',
        powGet4p81: 'powGet4p81',
        powGet4p82: 'powGet4p82',
        powGet4P81: 'powGet4p81',
        powGet4P82: 'powGet4p82',
        plugInInfoPvWatts: 'plugInInfoPvWatts',
        plugInInfoPv2Watts: 'plugInInfoPv2Watts',
        acInPower: 'acInPower',
        carInPower: 'carInPower',
        dcInPower: 'dcInPower',
    };
    return aliases[camel] ?? camel;
}
export function canonicalizeMetric(channel, state) {
    return {
        channel: normalizeChannel(channel),
        state: normalizeState(state),
    };
}
