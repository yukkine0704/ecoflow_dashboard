import 'dart:io';

import 'package:ecoflow_dashboard/core/bridge/bridge_history_store.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bridge_history_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  BridgeDeviceSnapshot buildSnapshot({
    required DateTime updatedAt,
    Map<String, dynamic> metrics = const <String, dynamic>{},
    int? batteryPercent,
    double? temperatureC,
  }) {
    return BridgeDeviceSnapshot(
      deviceId: 'D1',
      displayName: 'Device 1',
      model: 'River',
      imageUrl: null,
      connectivity: BridgeConnectivity.online,
      onlineLegacy: true,
      batteryPercent: batteryPercent,
      temperatureC: temperatureC,
      totalInputW: null,
      totalOutputW: null,
      metrics: metrics,
      updatedAt: updatedAt,
    );
  }

  test('stores and reads valid history point', () async {
    final store = BridgeHistoryStore(boxName: 'history_test_store_valid');
    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: DateTime.parse('2026-05-01T00:00:00.000Z'),
        metrics: const <String, dynamic>{
          'inputByType.acW': 100,
          'outputByType.dcW': 60,
          'battery.maxCellTempC': 34.5,
        },
        batteryPercent: 87,
      ),
    );

    final series = await store.readSeries('D1');
    expect(series.points, hasLength(1));
    expect(series.points.first.inputAcW, 100);
    expect(series.points.first.outputDcW, 60);
    expect(series.points.first.batteryTempC, 34.5);
    expect(series.points.first.batteryPercent, 87);
    await store.dispose();
  });

  test('keeps one point per 30 second bucket', () async {
    final store = BridgeHistoryStore(boxName: 'history_test_store_sampling');
    final t0 = DateTime.parse('2026-05-01T00:00:00.000Z');

    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: t0,
        metrics: const <String, dynamic>{'inputByType.acW': 100},
      ),
    );
    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: t0.add(const Duration(seconds: 20)),
        metrics: const <String, dynamic>{'inputByType.acW': 120},
      ),
    );
    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: t0.add(const Duration(seconds: 35)),
        metrics: const <String, dynamic>{'inputByType.acW': 130},
      ),
    );

    final series = await store.readSeries('D1');
    expect(series.points, hasLength(2));
    expect(series.points.first.inputAcW, 120);
    expect(series.points.last.inputAcW, 130);
    await store.dispose();
  });

  test('prunes points older than 7 days', () async {
    final store = BridgeHistoryStore(boxName: 'history_test_store_retention');
    final t0 = DateTime.parse('2026-05-01T00:00:00.000Z');
    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: t0.subtract(const Duration(days: 8)),
        metrics: const <String, dynamic>{'inputByType.acW': 50},
      ),
    );
    await store.recordSnapshot(
      buildSnapshot(
        updatedAt: t0,
        metrics: const <String, dynamic>{'inputByType.acW': 70},
      ),
    );

    final series = await store.readSeries('D1');
    expect(series.points, hasLength(1));
    expect(series.points.single.inputAcW, 70);
    await store.dispose();
  });

  test('supports partial null metrics without breaking series', () async {
    final store = BridgeHistoryStore(boxName: 'history_test_store_partial');
    final t0 = DateTime.parse('2026-05-01T00:00:00.000Z');
    await store.recordSnapshot(
      buildSnapshot(updatedAt: t0, batteryPercent: 70, temperatureC: 31.2),
    );

    final series = await store.readSeries('D1');
    expect(series.points, hasLength(1));
    expect(series.points.first.inputAcW, isNull);
    expect(series.points.first.outputAcW, isNull);
    expect(series.points.first.batteryPercent, 70);
    expect(series.points.first.batteryTempC, 31.2);
    await store.dispose();
  });
}
