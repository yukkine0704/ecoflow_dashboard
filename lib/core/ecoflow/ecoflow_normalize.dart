class CanonicalMetric {
  const CanonicalMetric({required this.channel, required this.state});

  final String channel;
  final String state;
}

String _toCamelCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  final withWordBreaks = trimmed
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toLowerCase();
  final parts = withWordBreaks
      .split('_')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  return parts.first +
      parts
          .skip(1)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join();
}

String _normalizeChannel(String raw) {
  final camel = _toCamelCase(raw);
  if (camel.isEmpty) return 'raw';
  if (camel == 'runtimePropertyUpload') return 'pd';
  if (camel.toLowerCase().startsWith('bmsheartbeatreport')) return 'bms';
  return camel;
}

String _normalizeState(String raw) {
  final camel = _toCamelCase(raw);
  if (camel.isEmpty) return raw;
  const aliases = <String, String>{
    'f32ShowSoc': 'f32ShowSoc',
    'f32LcdShowSoc': 'f32LcdShowSoc',
    'lcdShowSoc': 'lcdShowSoc',
    'bmsBattSoc': 'bmsBattSoc',
    'cmsBattSoc': 'cmsBattSoc',
    'maxCellTemp': 'maxCellTemp',
    'minCellTemp': 'minCellTemp',
    'maxMosTemp': 'maxMosTemp',
    'minMosTemp': 'minMosTemp',
    'tempPcsDc': 'tempPcsDc',
    'tempPcsAc': 'tempPcsAc',
    'tempPv': 'tempPv',
    'tempPv2': 'tempPv2',
    'temp': 'temp',
    'soc': 'soc',
    'inputWatts': 'inputWatts',
    'outputWatts': 'outputWatts',
    'inPower': 'inPower',
    'outPower': 'outPower',
    'powGetAcIn': 'powGetAcIn',
    'powGetPv': 'powGetPv',
    'powGetPvH': 'powGetPvH',
    'powGetPvL': 'powGetPvL',
    'powGetDcp': 'powGetDcp',
    'powGetDcp2': 'powGetDcp2',
    'powGetAcOut': 'powGetAcOut',
    'powGetAc': 'powGetAcOut',
    'powGet12v': 'powGet12v',
    'powGet24v': 'powGet24v',
    'powGetTypec1': 'powGetTypec1',
    'powGetTypec2': 'powGetTypec2',
    'powGetQcusb1': 'powGetQcusb1',
    'powGetQcusb2': 'powGetQcusb2',
    'usb1Watts': 'usb1Watts',
    'usb2Watts': 'usb2Watts',
    'typec1Watts': 'typec1Watts',
    'typec2Watts': 'typec2Watts',
    'powGet5p8': 'powGet5p8',
    'powGet4p81': 'powGet4p81',
    'powGet4p82': 'powGet4p82',
    'powGet4P81': 'powGet4p81',
    'powGet4P82': 'powGet4p82',
    'plugInInfoPvWatts': 'plugInInfoPvWatts',
    'plugInInfoPv2Watts': 'plugInInfoPv2Watts',
    'acInPower': 'acInPower',
    'carInPower': 'carInPower',
    'dcInPower': 'dcInPower',
  };
  return aliases[camel] ?? camel;
}

CanonicalMetric canonicalizeMetric(String channel, String state) {
  return CanonicalMetric(
    channel: _normalizeChannel(channel),
    state: _normalizeState(state),
  );
}

enum MappingFieldKind {
  batteryPercent,
  temperatureC,
  totalInputW,
  totalOutputW,
  metric,
}

class MappingRule {
  const MappingRule({
    required this.channel,
    required this.state,
    required this.field,
    this.metricKey,
  });

  final String channel;
  final String state;
  final MappingFieldKind field;
  final String? metricKey;
}

const mappingRules = <MappingRule>[
  MappingRule(
    channel: 'pd',
    state: 'soc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: '*',
    state: 'soc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: '*',
    state: 'f32ShowSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: '*',
    state: 'f32LcdShowSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: '*',
    state: 'bmsBattSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: '*',
    state: 'lcdShowSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: 'ems',
    state: 'cmsBattSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: 'pd',
    state: 'cmsBattSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: 'bmsMaster',
    state: 'bmsBattSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: 'bms',
    state: 'bmsBattSoc',
    field: MappingFieldKind.batteryPercent,
  ),
  MappingRule(
    channel: 'pd',
    state: 'temp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: 'inv',
    state: 'temp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'temp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'tempPcsAc',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'tempPcsDc',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'tempPv',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'tempPv2',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'mpptTemp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'outTemp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'maxCellTemp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: '*',
    state: 'bmsMaxCellTemp',
    field: MappingFieldKind.temperatureC,
  ),
  MappingRule(
    channel: 'pd',
    state: 'inputWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'inPower',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'inputWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'wattsInSum',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'inWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'plugInInfoPvWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'plugInInfoPv2Watts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'pd',
    state: 'acInPower',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'pd',
    state: 'carInPower',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'pd',
    state: 'dcInPower',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'mppt',
    state: 'pv1InputWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'mppt',
    state: 'pv2InputWatts',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetAcIn',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetPv',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetPvH',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetPvL',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetDcp',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetDcp2',
    field: MappingFieldKind.totalInputW,
  ),
  MappingRule(
    channel: 'pd',
    state: 'outputWatts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'outPower',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'outputWatts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'wattsOutSum',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'outWatts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: 'inv',
    state: 'outPower',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: 'inv',
    state: 'outputWatts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: 'acOut',
    state: 'acOutputWatts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetAcOut',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetAc',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGet12v',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGet24v',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetTypec1',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetTypec2',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetQcusb1',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGetQcusb2',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'usb1Watts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'usb2Watts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'typec1Watts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'typec2Watts',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGet5p8',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGet4p81',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: '*',
    state: 'powGet4p82',
    field: MappingFieldKind.totalOutputW,
  ),
  MappingRule(
    channel: 'pd',
    state: 'remainTime',
    field: MappingFieldKind.metric,
    metricKey: 'pd.remainTime',
  ),
  MappingRule(
    channel: 'pd',
    state: 'batteryType',
    field: MappingFieldKind.metric,
    metricKey: 'pd.batteryType',
  ),
];

MappingRule? findRule(String channel, String state) {
  for (final rule in mappingRules) {
    if (rule.channel == channel && rule.state == state) return rule;
  }
  for (final rule in mappingRules) {
    if (rule.channel == '*' && rule.state == state) return rule;
  }
  return null;
}
