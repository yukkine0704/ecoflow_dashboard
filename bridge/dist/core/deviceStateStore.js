import { findRule } from '../mapping/rules.js';
function toNumber(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
        return value;
    }
    if (typeof value === 'string') {
        const parsed = Number.parseFloat(value);
        return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
}
function sumValues(values) {
    const items = Object.values(values);
    if (items.length === 0) {
        return null;
    }
    return items.reduce((acc, value) => acc + value, 0);
}
export class DeviceStateStore {
    devices = new Map();
    isBatteryJumpSuspicious(previous, next) {
        if (previous === null)
            return false;
        return Math.abs(previous - next) > 20;
    }
    isTemperatureJumpSuspicious(previous, next) {
        if (previous === null)
            return false;
        return Math.abs(previous - next) > 12;
    }
    batterySourceScore(metricKey) {
        const key = metricKey.toLowerCase();
        if (key.endsWith('.soc'))
            return 100;
        if (key.includes('f32showsoc') || key.includes('f32lcdshowsoc'))
            return 90;
        if (key.includes('bmsbattsoc'))
            return 80;
        if (key.includes('cmsbattsoc') || key.includes('lcdshowsoc'))
            return 70;
        return 50;
    }
    temperatureSourceScore(metricKey) {
        const key = metricKey.toLowerCase();
        if (key.endsWith('.temp') && key.includes('bms'))
            return 100;
        if (key.endsWith('.temp') && key.includes('pd'))
            return 95;
        if (key.endsWith('.temp'))
            return 90;
        if (key.includes('maxcelltemp'))
            return 85;
        if (key.includes('mincelltemp'))
            return 80;
        if (key.includes('mos'))
            return 70;
        if (key.includes('env'))
            return 60;
        return 50;
    }
    detectInputType(metricKey) {
        const key = metricKey.toLowerCase().replace(/[._-]/g, '');
        if (key.includes('powgetpv') || key.includes('pv') || key.includes('solar'))
            return 'solar';
        if (key.includes('powgetacin') || key.includes('acin') || key.includes('acinput') || key.includes('ac.in'))
            return 'ac';
        if (key.includes('powgetdcp2') || key.includes('carin') || key.includes('car'))
            return 'car';
        if (key.includes('powgetdcp') || key.includes('dcin') || key.includes('dc.in') || key.includes('dcp'))
            return 'dc';
        if (key.includes('pv') || key.includes('solar'))
            return 'solar';
        if (key.includes('acin') || key.includes('acinput') || key.includes('ac.in'))
            return 'ac';
        // When direct protobuf heuristic provides generic `pd.inputWatts`, treat it as AC by default.
        if (key.endsWith('.inputwatts') || key.includes('inputwatts'))
            return 'ac';
        if (key.includes('carin') || key.includes('car'))
            return 'car';
        if (key.includes('dcin') || key.includes('dc.in') || key.includes('dcp'))
            return 'dc';
        return 'other';
    }
    isSourceSpecificInputMetric(metricKey) {
        const key = metricKey.toLowerCase().replace(/[._-]/g, '');
        return (key.includes('powgetacin')
            || key.includes('powgetpv')
            || key.includes('powgetdcp')
            || key.includes('acinpower')
            || key.includes('carinpower')
            || key.includes('dcinpower')
            || key.includes('pv1inputwatts')
            || key.includes('pv2inputwatts'));
    }
    resolveActiveInputComponents(components) {
        const sourceSpecific = Object.entries(components).filter(([metricKey]) => this.isSourceSpecificInputMetric(metricKey));
        if (sourceSpecific.length > 0) {
            const specificMap = Object.fromEntries(sourceSpecific);
            const keys = Object.keys(specificMap).map((k) => k.toLowerCase());
            const hasPvSplit = keys.some((k) => k.includes('powgetpvh') || k.includes('powgetpvl'));
            const hasOnlyPvGeneric = keys.some((k) => k.includes('powgetpv')) && !hasPvSplit;
            const hasOtherInputSources = Object.entries(specificMap).some(([metricKey, value]) => {
                const k = metricKey.toLowerCase();
                const isOtherSource = (k.includes('powgetacin')
                    || k.includes('powgetdcp')
                    || k.includes('carinpower')
                    || k.includes('dcinpower'));
                return isOtherSource && value > 0;
            });
            // Delta 3/Gen3 solar fallback:
            // If only solar is active and total input is higher than reported solar
            // channels, complete missing solar power by inference.
            const genericInput = Object.entries(components).find(([metricKey]) => metricKey.toLowerCase().endsWith('.inputwatts'));
            if (genericInput && Number.isFinite(genericInput[1]) && !hasOtherInputSources) {
                const totalInput = genericInput[1];
                const solarKeys = Object.keys(specificMap).filter((k) => k.toLowerCase().includes('powgetpv'));
                const solarSum = solarKeys.reduce((acc, key) => acc + (specificMap[key] ?? 0), 0);
                if (solarKeys.length > 0 && totalInput > solarSum + 0.5) {
                    const delta = Math.max(totalInput - solarSum, 0);
                    const pvLKey = solarKeys.find((k) => k.toLowerCase().includes('powgetpvl'));
                    if (pvLKey) {
                        specificMap[pvLKey] = (specificMap[pvLKey] ?? 0) + delta;
                    }
                    else if (hasOnlyPvGeneric) {
                        specificMap['pd.powGetPvL'] = delta;
                    }
                    else {
                        specificMap['pd.powGetPvInferred'] = delta;
                    }
                }
            }
            return specificMap;
        }
        return components;
    }
    detectOutputType(metricKey) {
        const key = metricKey.toLowerCase().replace(/[._-]/g, '');
        if (key.includes('powgetacout') || key.includes('powgetac') || key.includes('acoutput') || key.includes('acout'))
            return 'ac';
        if (key.includes('12v') || key.includes('24v') || key.includes('typec') || key.includes('qcusb') || key.includes('dcp') || key.includes('dc'))
            return 'dc';
        return 'other';
    }
    isSourceSpecificOutputMetric(metricKey) {
        const key = metricKey.toLowerCase().replace(/[._-]/g, '');
        return (key.includes('powgetacout')
            || key.includes('powgetac')
            || key.includes('powget12v')
            || key.includes('powget24v')
            || key.includes('powgettypec')
            || key.includes('powgetqcusb')
            || key.includes('powgetdcp'));
    }
    resolveActiveOutputComponents(components) {
        const sourceSpecific = Object.entries(components).filter(([metricKey]) => this.isSourceSpecificOutputMetric(metricKey));
        if (sourceSpecific.length > 0) {
            return Object.fromEntries(sourceSpecific);
        }
        return components;
    }
    refreshInputByType(components, record, changed) {
        const bucketMap = {
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
            }
            else {
                record.snapshot.metrics[metricKey] = total;
                changed[`metrics.${metricKey}`] = total;
            }
        }
    }
    refreshOutputByType(components, record, changed) {
        const bucketMap = {
            ac: {},
            dc: {},
            other: {},
        };
        for (const [metricKey, value] of Object.entries(components)) {
            const bucket = this.detectOutputType(metricKey);
            bucketMap[bucket][metricKey] = value;
        }
        for (const type of ['ac', 'dc', 'other']) {
            const bucket = bucketMap[type] ?? {};
            const total = sumValues(bucket);
            const metricKey = `outputByType.${type}W`;
            if (total === null) {
                delete record.snapshot.metrics[metricKey];
                changed[`metrics.${metricKey}`] = null;
            }
            else {
                record.snapshot.metrics[metricKey] = total;
                changed[`metrics.${metricKey}`] = total;
            }
        }
    }
    upsertRawMetric(deviceId, channel, state, rawPayload) {
        const now = new Date().toISOString();
        const record = this.getOrCreate(deviceId, now);
        const metricKey = `${channel}.${state}`;
        record.snapshot.metrics[metricKey] = rawPayload;
        record.snapshot.updatedAt = now;
        return {
            deviceId,
            changed: { [`metrics.${metricKey}`]: rawPayload },
            updatedAt: now,
        };
    }
    setCatalog(devices) {
        const now = new Date().toISOString();
        for (const device of devices) {
            const record = this.getOrCreate(device.deviceId, now);
            record.snapshot.displayName = device.displayName?.trim() || record.snapshot.displayName;
            record.snapshot.model = device.model?.trim() || record.snapshot.model;
            record.snapshot.imageUrl = device.imageUrl?.trim() || record.snapshot.imageUrl;
            record.snapshot.updatedAt = now;
        }
    }
    upsertStatus(deviceId, rawPayload) {
        const now = new Date().toISOString();
        const record = this.getOrCreate(deviceId, now);
        const normalized = rawPayload.trim().toLowerCase();
        let online = null;
        if (normalized === 'online' || normalized === '1' || normalized === 'true' || normalized === 'on') {
            online = true;
        }
        if (normalized === 'offline' || normalized === '0' || normalized === 'false' || normalized === 'off') {
            online = false;
        }
        record.snapshot.online = online;
        record.snapshot.connectivity = online === true ? 'online' : 'offline';
        record.snapshot.updatedAt = now;
        return {
            deviceId,
            changed: { online },
            updatedAt: now,
        };
    }
    upsertConnectivity(deviceId, connectivity) {
        const now = new Date().toISOString();
        const record = this.getOrCreate(deviceId, now);
        record.snapshot.connectivity = connectivity;
        record.snapshot.online = connectivity === 'online' ? true : (connectivity === 'offline' ? false : null);
        record.snapshot.updatedAt = now;
        return {
            deviceId,
            changed: {
                connectivity,
                online: record.snapshot.online,
            },
            updatedAt: now,
        };
    }
    upsertMetric(deviceId, channel, state, rawPayload) {
        const now = new Date().toISOString();
        const record = this.getOrCreate(deviceId, now);
        const metricKey = `${channel}.${state}`;
        let normalizedValue = rawPayload;
        const numeric = toNumber(rawPayload);
        if (numeric !== null) {
            normalizedValue = numeric;
        }
        const changed = {
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
                        const sourceScore = this.batterySourceScore(metricKey);
                        const scoreOk = sourceScore >= record.batterySourceScore || record.snapshot.batteryPercent === null;
                        if (scoreOk && !this.isBatteryJumpSuspicious(record.snapshot.batteryPercent, rounded)) {
                            record.snapshot.batteryPercent = rounded;
                            record.batterySourceScore = sourceScore;
                            changed.batteryPercent = record.snapshot.batteryPercent;
                        }
                    }
                    break;
                }
                case 'temperatureC': {
                    const temp = toNumber(normalizedValue);
                    if (temp !== null) {
                        const sourceScore = this.temperatureSourceScore(metricKey);
                        const scoreOk = sourceScore >= record.temperatureSourceScore || record.snapshot.temperatureC === null;
                        if (scoreOk && !this.isTemperatureJumpSuspicious(record.snapshot.temperatureC, temp)) {
                            record.snapshot.temperatureC = temp;
                            record.temperatureSourceScore = sourceScore;
                            changed.temperatureC = record.snapshot.temperatureC;
                        }
                    }
                    if (state === 'maxCellTemp' || state === 'bmsMaxCellTemp') {
                        record.snapshot.metrics['battery.maxCellTempC'] = temp;
                        changed['metrics.battery.maxCellTempC'] = temp;
                    }
                    break;
                }
                case 'totalInputW': {
                    const asNumber = toNumber(normalizedValue);
                    if (asNumber !== null) {
                        record.inputComponents[metricKey] = asNumber;
                    }
                    else {
                        delete record.inputComponents[metricKey];
                    }
                    const activeInput = this.resolveActiveInputComponents(record.inputComponents);
                    if (activeInput['pd.powGetPvL'] !== undefined && record.snapshot.metrics['pd.powGetPvL'] === undefined) {
                        record.snapshot.metrics['pd.powGetPvL'] = activeInput['pd.powGetPvL'];
                        changed['metrics.pd.powGetPvL'] = activeInput['pd.powGetPvL'];
                    }
                    record.snapshot.totalInputW = sumValues(activeInput);
                    changed.totalInputW = record.snapshot.totalInputW;
                    this.refreshInputByType(activeInput, record, changed);
                    break;
                }
                case 'totalOutputW': {
                    const asNumber = toNumber(normalizedValue);
                    if (asNumber !== null) {
                        record.outputComponents[metricKey] = asNumber;
                    }
                    else {
                        delete record.outputComponents[metricKey];
                    }
                    const activeOutput = this.resolveActiveOutputComponents(record.outputComponents);
                    record.snapshot.totalOutputW = sumValues(activeOutput);
                    changed.totalOutputW = record.snapshot.totalOutputW;
                    this.refreshOutputByType(activeOutput, record, changed);
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
    getSnapshot(deviceId) {
        return this.devices.get(deviceId)?.snapshot ?? null;
    }
    getFleetState() {
        return {
            devices: [...this.devices.values()]
                .map((record) => record.snapshot)
                .sort((a, b) => a.deviceId.localeCompare(b.deviceId))
                .map((snapshot) => ({
                deviceId: snapshot.deviceId,
                displayName: snapshot.displayName,
                model: snapshot.model,
                online: snapshot.online,
                connectivity: snapshot.connectivity,
                batteryPercent: snapshot.batteryPercent,
                updatedAt: snapshot.updatedAt,
            })),
        };
    }
    getAllSnapshots() {
        return [...this.devices.values()].map((record) => record.snapshot);
    }
    getOrCreate(deviceId, nowIso) {
        const existing = this.devices.get(deviceId);
        if (existing) {
            return existing;
        }
        const created = {
            snapshot: {
                deviceId,
                displayName: deviceId,
                model: null,
                imageUrl: null,
                online: null,
                connectivity: 'offline',
                batteryPercent: null,
                temperatureC: null,
                totalInputW: null,
                totalOutputW: null,
                metrics: {},
                updatedAt: nowIso,
            },
            inputComponents: {},
            outputComponents: {},
            batterySourceScore: 0,
            temperatureSourceScore: 0,
        };
        this.devices.set(deviceId, created);
        return created;
    }
}
