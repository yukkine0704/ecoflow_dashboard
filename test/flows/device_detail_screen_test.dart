import 'dart:async';

import 'package:ecoflow_dashboard/core/bridge/bridge_history_store.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_models.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_repository.dart';
import 'package:ecoflow_dashboard/core/bridge/bridge_ws_client.dart';
import 'package:ecoflow_dashboard/design_system/design_system.dart';
import 'package:ecoflow_dashboard/flows/device_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopBridgeWsClient extends BridgeWsClient {
  @override
  Stream<Map<String, dynamic>> get messages =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Stream<Object> get errors => const Stream<Object>.empty();

  @override
  Future<void> connect(String wsUrl) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}

class _TestHistoryStore extends BridgeHistoryStore {
  _TestHistoryStore() : super(boxName: 'unused_test_store');

  final StreamController<DeviceHistorySeries> controller =
      StreamController<DeviceHistorySeries>.broadcast();
  DeviceHistorySeries current = const DeviceHistorySeries(
    deviceId: 'D1',
    points: <DeviceHistoryPoint>[],
  );

  @override
  Future<void> init() async {}

  @override
  Future<DeviceHistorySeries> readSeries(String deviceId) async => current;

  @override
  Stream<DeviceHistorySeries> watchSeries(String deviceId) => controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

void main() {
  BridgeDeviceSnapshot snapshot() {
    return BridgeDeviceSnapshot(
      deviceId: 'D1',
      displayName: 'Device 1',
      model: 'River',
      imageUrl: null,
      connectivity: BridgeConnectivity.online,
      onlineLegacy: true,
      batteryPercent: 80,
      temperatureC: 30,
      totalInputW: 120,
      totalOutputW: 90,
      metrics: const <String, dynamic>{},
      updatedAt: DateTime.parse('2026-05-01T00:00:00.000Z'),
    );
  }

  testWidgets('shows empty historical state when no points', (tester) async {
    final historyStore = _TestHistoryStore();
    final repo = BridgeRepository(
      client: _NoopBridgeWsClient(),
      historyStore: historyStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DeviceDetailScreen(
          repository: repo,
          deviceId: 'D1',
          initialSnapshot: snapshot(),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Aun no hay puntos historicos. Se iran guardando cada 30 segundos.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Aun no hay puntos historicos. Se iran guardando cada 30 segundos.'),
      findsOneWidget,
    );
    await repo.dispose();
  });

  testWidgets('renders charts with partial historical data', (tester) async {
    final historyStore = _TestHistoryStore();
    final repo = BridgeRepository(
      client: _NoopBridgeWsClient(),
      historyStore: historyStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DeviceDetailScreen(
          repository: repo,
          deviceId: 'D1',
          initialSnapshot: snapshot(),
        ),
      ),
    );

    historyStore.current = DeviceHistorySeries(
      deviceId: 'D1',
      points: <DeviceHistoryPoint>[
        DeviceHistoryPoint(
          timestamp: DateTime.parse('2026-05-01T00:00:00.000Z'),
          inputSolarW: 200,
          inputAcW: null,
          inputCarW: null,
          inputDcW: 40,
          inputOtherW: null,
          outputAcW: 140,
          outputDcW: null,
          outputOtherW: null,
          batteryPercent: 75,
          batteryTempC: 33,
        ),
      ],
    );
    historyStore.controller.add(historyStore.current);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Solar Input'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Solar Input'), findsOneWidget);
    expect(find.text('Salida por tipo'), findsOneWidget);
    expect(find.text('Temperatura bateria'), findsOneWidget);
    expect(find.text('Bateria %'), findsOneWidget);
    expect(find.byType(LineChart), findsNWidgets(2));
    expect(find.byType(BarChart), findsNWidgets(2));
    await repo.dispose();
  });
}
