import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/ecoflow/device_telemetry_repository.dart';
import '../core/ecoflow/ecoflow_history_store.dart';
import '../core/ecoflow/ecoflow_models.dart';
import '../design_system/design_system.dart';

part 'widgets/device_detail_history_section.dart';
part 'widgets/device_detail_metrics_cards.dart';
part 'widgets/device_detail_power_cards.dart';
part 'widgets/device_detail_thermal_widgets.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    required this.repository,
    required this.deviceId,
    required this.initialSnapshot,
  });

  final DeviceTelemetryRepository repository;
  final String deviceId;
  final EcoFlowDeviceSnapshot initialSnapshot;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _deviceImageAssetsById = <String, String>{
    'P351ZAHAPH2R2706': 'assets/Delta-3.png',
    'R651ZAB5XH111262': 'assets/River-3.png',
  };

  late EcoFlowDeviceSnapshot _snapshot;
  StreamSubscription<EcoFlowDeviceSnapshot>? _deviceSub;
  StreamSubscription<DeviceHistorySeries>? _historySub;
  Timer? _thermalGateTicker;
  late final AnimationController _thermalController;
  DeviceHistorySeries? _historySeries;
  final Map<String, DateTime> _cellAboveWarmSince = <String, DateTime>{};
  static const Duration _cellAnimationActivationDelay = Duration(seconds: 10);
  static const double _cellWarmThresholdC = 37;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _thermalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _thermalGateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _deviceSub = widget.repository.deviceUpdates.listen((updated) {
      if (!mounted || updated.deviceId != widget.deviceId) {
        return;
      }
      setState(() => _snapshot = updated);
    });
    _historySub = widget.repository.watchHistory(widget.deviceId).listen((
      series,
    ) {
      if (!mounted) {
        return;
      }
      setState(() => _historySeries = series);
    });
  }

  @override
  void dispose() {
    unawaited(_deviceSub?.cancel());
    unawaited(_historySub?.cancel());
    _thermalGateTicker?.cancel();
    _thermalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Dispositivo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildDeviceHeroCard(context),
          const SizedBox(height: AppSpacing.md),
          AppGaugeCard.energyBalance(
            inputW: _snapshot.totalInputW,
            outputW: _snapshot.totalOutputW,
            maxW: 2200,
          ),
          if (_hasExtraBatteryData()) ...[
            const SizedBox(height: AppSpacing.md),
            _buildExtraBatteriesCard(context),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildOutputChannelsCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildThermalCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildHistorySection(context),
          const SizedBox(height: AppSpacing.md),
          _buildKeyDataCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildExtendedFieldsCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildRawMetricsCard(context),
        ],
      ),
    );
  }
}
