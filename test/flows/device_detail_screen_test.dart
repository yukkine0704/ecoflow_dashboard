import 'dart:async';

import 'package:ecoflow_dashboard/core/ecoflow/device_telemetry_repository.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_history_store.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_models.dart';
import 'package:ecoflow_dashboard/design_system/design_system.dart';
import 'package:ecoflow_dashboard/flows/device_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestTelemetryRepository implements DeviceTelemetryRepository {
  final StreamController<DeviceHistorySeries> controller =
      StreamController<DeviceHistorySeries>.broadcast();
  final StreamController<EcoFlowDeviceSnapshot> deviceController =
      StreamController<EcoFlowDeviceSnapshot>.broadcast();
  DeviceHistorySeries current = const DeviceHistorySeries(
    deviceId: 'D1',
    points: <DeviceHistoryPoint>[],
  );

  @override
  Stream<List<EcoFlowDeviceSnapshot>> get fleet =>
      const Stream<List<EcoFlowDeviceSnapshot>>.empty();

  @override
  Stream<EcoFlowDeviceSnapshot> get deviceUpdates => deviceController.stream;

  @override
  Stream<EcoFlowConnectionState> get connection =>
      const Stream<EcoFlowConnectionState>.empty();

  @override
  Stream<List<EcoFlowCatalogItem>> get catalog =>
      const Stream<List<EcoFlowCatalogItem>>.empty();

  @override
  List<EcoFlowDeviceSnapshot> get currentFleet =>
      const <EcoFlowDeviceSnapshot>[];

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<DeviceHistorySeries> readHistory(String deviceId) async => current;

  @override
  Stream<DeviceHistorySeries> watchHistory(String deviceId) =>
      controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
    await deviceController.close();
  }
}

void main() {
  EcoFlowDeviceSnapshot snapshot() {
    return EcoFlowDeviceSnapshot(
      deviceId: 'D1',
      displayName: 'Device 1',
      model: 'River',
      imageUrl: null,
      connectivity: EcoFlowConnectivity.online,
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
    final repo = _TestTelemetryRepository();

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
      find.text(
        'Aun no hay puntos historicos. Se iran guardando cada 30 segundos.',
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(
        'Aun no hay puntos historicos. Se iran guardando cada 30 segundos.',
      ),
      findsOneWidget,
    );
    await repo.dispose();
  });

  testWidgets('renders charts with partial historical data', (tester) async {
    final repo = _TestTelemetryRepository();

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

    repo.current = DeviceHistorySeries(
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
    repo.controller.add(repo.current);
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
    expect(find.byType(BarChart), findsAtLeastNWidgets(1));
    await repo.dispose();
  });
}
