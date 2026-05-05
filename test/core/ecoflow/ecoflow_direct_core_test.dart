import 'dart:math';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_device_state_store.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_model_decoders.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_normalize.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_payload_parser.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_signer.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_status_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signer sorts nested params and creates deterministic HMAC headers', () {
    final headers = createSignedHeaders(
      accessKey: 'access',
      secretKey: 'secret',
      params: <String, Object?>{
        'z': 2,
        'a': <String, Object?>{'b': true},
      },
      random: Random(1),
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(headers['accessKey'], 'access');
    expect(headers['timestamp'], '1000000000');
    expect(headers['nonce'], hasLength(6));
    expect(
      generateSignedQuery(<String, Object?>{
        'z': 2,
        'a': <String, Object?>{'b': true},
      }),
      'a.b=true&z=2',
    );
    expect(
      headers['sign'],
      'ef295574e131dfcab42da47a7490d50445fab6f33ca4b7bf98fa42f459e7d650',
    );
  });

  test('canonicalizeMetric normalizes EcoFlow raw keys', () {
    expect(
      canonicalizeMetric('RuntimePropertyUpload', 'pow_get_ac_in').channel,
      'pd',
    );
    expect(
      canonicalizeMetric('RuntimePropertyUpload', 'pow_get_ac_in').state,
      'powGetAcIn',
    );
    expect(
      canonicalizeMetric('BMSHeartBeatReport', 'Max_Cell_Temp').state,
      'maxCellTemp',
    );
  });

  test('battery resolver prefers display CMS SOC over raw pd.soc', () {
    final store = EcoFlowDeviceStateStore();

    store.upsertMetric('D1', 'pd', 'soc', 91);
    expect(store.getSnapshot('D1')?.batteryPercent, 91);

    store.upsertMetric('D1', 'pd', 'cmsBattSoc', 67.736328125);
    expect(store.getSnapshot('D1')?.batteryPercent, 68);

    store.upsertMetric('D1', 'pd', 'soc', 91);
    expect(store.getSnapshot('D1')?.batteryPercent, 68);
  });

  test('battery resolver accepts repeated suspicious jumps', () {
    final store = EcoFlowDeviceStateStore();

    store.upsertMetric('D1', 'pd', 'soc', 91);
    expect(store.getSnapshot('D1')?.batteryPercent, 91);

    store.upsertMetric('D1', 'pd', 'soc', 68);
    expect(store.getSnapshot('D1')?.batteryPercent, 91);

    store.upsertMetric('D1', 'pd', 'soc', 68);
    expect(store.getSnapshot('D1')?.batteryPercent, 91);

    store.upsertMetric('D1', 'pd', 'soc', 68);
    expect(store.getSnapshot('D1')?.batteryPercent, 68);
  });

  test('delta and river decoders port bridge model rules', () {
    final delta = decodeModelTelemetry(
      <String, dynamic>{
        'num': 2,
        'soc': 74,
        'temp': 31,
        'input_watts': 412,
        'pow_get_4p8_1': 120,
      },
      const DecoderContext(
        model: 'Delta Pro 3',
        envelope: EcoFlowPayloadEnvelope(
          cmdFunc: 254,
          cmdId: 21,
          encType: 0,
          src: 0,
        ),
      ),
    );
    expect(delta['pd.powGet4p81'], 120);

    final river = decodeModelTelemetry(
      <String, dynamic>{'output_power_off_memory': 1},
      const DecoderContext(
        model: 'RIVER 3',
        envelope: EcoFlowPayloadEnvelope(
          cmdFunc: 254,
          cmdId: 22,
          encType: 0,
          src: 0,
        ),
      ),
    );
    expect(river['cfg_ac_out_open'], 1);
  });

  test(
    'status tracker transitions from data to inferred offline states',
    () async {
      final tracker = EcoFlowStatusTracker(const Duration(milliseconds: 20), 2);
      tracker.onDataReceived('D1');
      expect(tracker.state('D1').name, 'online');

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(tracker.state('D1').name, 'assumeOffline');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(tracker.state('D1').name, 'offline');
    },
  );
}
