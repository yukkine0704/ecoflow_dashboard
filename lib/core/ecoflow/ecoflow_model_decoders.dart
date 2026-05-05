import 'ecoflow_payload_parser.dart';

class DecoderContext {
  const DecoderContext({required this.model, required this.envelope});

  final String? model;
  final EcoFlowPayloadEnvelope? envelope;
}

Map<String, dynamic> decodeModelTelemetry(
  Map<String, dynamic> params,
  DecoderContext ctx,
) {
  if (_supportsDeltaPro3(ctx)) return _decodeDeltaPro3(params, ctx);
  if (_supportsRiver3(ctx)) return _decodeRiver3(params, ctx);
  return params;
}

bool _supportsDeltaPro3(DecoderContext ctx) {
  final model = (ctx.model ?? '').toLowerCase();
  return model.contains('delta pro 3') ||
      model.contains('delta_pro_3') ||
      model.contains('delta 3 pro') ||
      model.contains('delta 3') ||
      model.contains('delta3');
}

bool _supportsRiver3(DecoderContext ctx) {
  final model = (ctx.model ?? '').toLowerCase();
  return model.contains('river 3') || model.contains('river_3');
}

Map<String, dynamic> _normalizeKeys(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  for (final entry in input.entries) {
    out[entry.key] = entry.value;
    out[entry.key.replaceAll('_', '')] = entry.value;
  }
  return out;
}

num? _getNumber(Map<String, dynamic> out, List<String> keys) {
  for (final key in keys) {
    final value = out[key];
    if (value is num && value.isFinite) return value;
  }
  return null;
}

void _mapExtraBatteryMetrics(Map<String, dynamic> out) {
  final rawNum = _getNumber(out, const <String>[
    'num',
    'battery_num',
    'batterynum',
    'bat_num',
    'batnum',
    'bp_num',
    'bpnum',
  ]);
  if (rawNum == null) return;
  final batteryIndex = rawNum.round();
  if (batteryIndex < 1 || batteryIndex > 8) return;
  final prefix = 'pd.extraBattery$batteryIndex';
  final soc = _getNumber(out, const <String>['soc']);
  if (soc != null) out['$prefix.soc'] = soc;
  final temp = _getNumber(out, const <String>['temp']);
  if (temp != null) out['$prefix.temp'] = temp;
  final maxCellTemp = _getNumber(out, const <String>[
    'max_cell_temp',
    'maxcelltemp',
  ]);
  if (maxCellTemp != null) out['$prefix.maxCellTemp'] = maxCellTemp;
  final minCellTemp = _getNumber(out, const <String>[
    'min_cell_temp',
    'mincelltemp',
  ]);
  if (minCellTemp != null) out['$prefix.minCellTemp'] = minCellTemp;
  final f32ShowSoc = _getNumber(out, const <String>[
    'f32_show_soc',
    'f32showsoc',
  ]);
  if (f32ShowSoc != null) out['$prefix.f32ShowSoc'] = f32ShowSoc;
  final inputWatts = _getNumber(out, const <String>[
    'input_watts',
    'inputwatts',
  ]);
  if (inputWatts != null) out['$prefix.inputWatts'] = inputWatts;
  final outputWatts = _getNumber(out, const <String>[
    'output_watts',
    'outputwatts',
  ]);
  if (outputWatts != null) out['$prefix.outputWatts'] = outputWatts;
  final cycles = _getNumber(out, const <String>['cycles']);
  if (cycles != null) out['$prefix.cycles'] = cycles;
}

Map<String, dynamic> _decodeDeltaPro3(
  Map<String, dynamic> params,
  DecoderContext ctx,
) {
  final out = _normalizeKeys(params);
  final envelope = ctx.envelope;
  if (envelope == null) return out;
  final key = '${envelope.cmdFunc}:${envelope.cmdId}';
  const bmsHeartbeatCommands = <String>{
    '3:1',
    '3:2',
    '3:30',
    '3:50',
    '254:24',
    '254:25',
    '254:26',
    '254:27',
    '254:28',
    '254:29',
    '254:30',
    '32:1',
    '32:3',
    '32:50',
    '32:51',
    '32:52',
  };
  if (bmsHeartbeatCommands.contains(key)) {
    if (out['cycles'] != null) out['bms.cycles'] = out['cycles'];
    if (out['accu_chg_energy'] != null) {
      out['pd.accuChgEnergy'] = out['accu_chg_energy'];
    }
    if (out['accu_dsg_energy'] != null) {
      out['pd.accuDsgEnergy'] = out['accu_dsg_energy'];
    }
    _mapExtraBatteryMetrics(out);
  }
  if (envelope.cmdFunc == 254 && envelope.cmdId == 21) {
    if (out['pow_get_4p8_1'] != null) {
      out['pd.powGet4p81'] = out['pow_get_4p8_1'];
    }
    if (out['pow_get_4p8_2'] != null) {
      out['pd.powGet4p82'] = out['pow_get_4p8_2'];
    }
  }
  return out;
}

Map<String, dynamic> _decodeRiver3(
  Map<String, dynamic> params,
  DecoderContext ctx,
) {
  final out = <String, dynamic>{...params};
  final envelope = ctx.envelope;
  if (envelope == null) return out;
  final key = '${envelope.cmdFunc}:${envelope.cmdId}';
  const bmsHeartbeatCommands = <String>{
    '3:1',
    '3:2',
    '3:30',
    '3:50',
    '32:1',
    '32:3',
    '32:50',
    '32:51',
    '32:52',
    '254:24',
    '254:25',
    '254:26',
    '254:27',
    '254:28',
    '254:29',
    '254:30',
  };
  if (envelope.cmdFunc == 254 && envelope.cmdId == 21) {
    final stats = out['display_statistics_sum'];
    if (stats is Map) out['river3.displayStatistics'] = stats;
  }
  if (bmsHeartbeatCommands.contains(key)) {
    if (out['accu_chg_energy'] != null) {
      out['pd.accuChgEnergy'] = out['accu_chg_energy'];
    }
    if (out['accu_dsg_energy'] != null) {
      out['pd.accuDsgEnergy'] = out['accu_dsg_energy'];
    }
  }
  if (out['cfg_ac_out_open'] == null &&
      out['output_power_off_memory'] != null) {
    out['cfg_ac_out_open'] = _truthy(out['output_power_off_memory']) ? 1 : 0;
  }
  return out;
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'on';
  }
  return false;
}
