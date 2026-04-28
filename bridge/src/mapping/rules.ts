export type FieldKind =
  | 'batteryPercent'
  | 'temperatureC'
  | 'totalInputW'
  | 'totalOutputW'
  | 'metric';

export interface MappingRule {
  channel: string;
  state: string;
  field: FieldKind;
  metricKey?: string;
}

// Explicit topic-to-field map for v1 devices (expand safely as needed)
export const MAPPING_RULES: MappingRule[] = [
  { channel: 'pd', state: 'soc', field: 'batteryPercent' },
  { channel: 'ems', state: 'cmsBattSoc', field: 'batteryPercent' },
  { channel: 'bmsMaster', state: 'bmsBattSoc', field: 'batteryPercent' },
  { channel: 'bms', state: 'bmsBattSoc', field: 'batteryPercent' },
  { channel: 'pd', state: 'temp', field: 'temperatureC' },
  { channel: 'inv', state: 'temp', field: 'temperatureC' },

  { channel: 'pd', state: 'inputWatts', field: 'totalInputW' },
  { channel: 'pd', state: 'acInPower', field: 'totalInputW' },
  { channel: 'pd', state: 'carInPower', field: 'totalInputW' },
  { channel: 'pd', state: 'dcInPower', field: 'totalInputW' },
  { channel: 'mppt', state: 'pv1InputWatts', field: 'totalInputW' },
  { channel: 'mppt', state: 'pv2InputWatts', field: 'totalInputW' },
  { channel: '*', state: 'powGetAcIn', field: 'totalInputW' },
  { channel: '*', state: 'powGetPv', field: 'totalInputW' },
  { channel: '*', state: 'powGetDcp', field: 'totalInputW' },
  { channel: '*', state: 'powGetDcp2', field: 'totalInputW' },

  { channel: 'pd', state: 'outputWatts', field: 'totalOutputW' },
  { channel: 'inv', state: 'outPower', field: 'totalOutputW' },
  { channel: 'inv', state: 'outputWatts', field: 'totalOutputW' },
  { channel: 'acOut', state: 'acOutputWatts', field: 'totalOutputW' },

  { channel: 'pd', state: 'remainTime', field: 'metric', metricKey: 'pd.remainTime' },
  { channel: 'pd', state: 'batteryType', field: 'metric', metricKey: 'pd.batteryType' },
];

export function findRule(channel: string, state: string): MappingRule | undefined {
  return MAPPING_RULES.find((rule) => rule.channel === channel && rule.state === state)
    ?? MAPPING_RULES.find((rule) => rule.channel === '*' && rule.state === state);
}
