import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'ecoflow_models.dart';

class DeviceHistoryPoint {
  const DeviceHistoryPoint({
    required this.timestamp,
    required this.inputSolarW,
    required this.inputAcW,
    required this.inputCarW,
    required this.inputDcW,
    required this.inputOtherW,
    required this.outputAcW,
    required this.outputDcW,
    required this.outputOtherW,
    required this.batteryPercent,
    required this.batteryTempC,
  });

  final DateTime timestamp;
  final double? inputSolarW;
  final double? inputAcW;
  final double? inputCarW;
  final double? inputDcW;
  final double? inputOtherW;
  final double? outputAcW;
  final double? outputDcW;
  final double? outputOtherW;
  final int? batteryPercent;
  final double? batteryTempC;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'inputSolarW': inputSolarW,
      'inputAcW': inputAcW,
      'inputCarW': inputCarW,
      'inputDcW': inputDcW,
      'inputOtherW': inputOtherW,
      'outputAcW': outputAcW,
      'outputDcW': outputDcW,
      'outputOtherW': outputOtherW,
      'batteryPercent': batteryPercent,
      'batteryTempC': batteryTempC,
    };
  }

  factory DeviceHistoryPoint.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(Object? value) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    double? parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(Object? value) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        return int.tryParse(value) ?? double.tryParse(value)?.round();
      }
      return null;
    }

    return DeviceHistoryPoint(
      timestamp: parseTimestamp(json['timestamp']),
      inputSolarW: parseDouble(json['inputSolarW']),
      inputAcW: parseDouble(json['inputAcW']),
      inputCarW: parseDouble(json['inputCarW']),
      inputDcW: parseDouble(json['inputDcW']),
      inputOtherW: parseDouble(json['inputOtherW']),
      outputAcW: parseDouble(json['outputAcW']),
      outputDcW: parseDouble(json['outputDcW']),
      outputOtherW: parseDouble(json['outputOtherW']),
      batteryPercent: parseInt(json['batteryPercent']),
      batteryTempC: parseDouble(json['batteryTempC']),
    );
  }
}

class DeviceHistorySeries {
  const DeviceHistorySeries({required this.deviceId, required this.points});

  final String deviceId;
  final List<DeviceHistoryPoint> points;
}

class EcoFlowHistoryStore {
  EcoFlowHistoryStore({
    Duration retention = const Duration(days: 7),
    Duration sampleWindow = const Duration(seconds: 30),
    String boxName = 'ecoflow_device_history_v1',
  }) : _retention = retention,
       _sampleWindow = sampleWindow,
       _boxName = boxName;

  final Duration _retention;
  final Duration _sampleWindow;
  final String _boxName;
  final Map<String, StreamController<DeviceHistorySeries>> _controllers =
      <String, StreamController<DeviceHistorySeries>>{};
  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box?.isOpen == true) return;
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    await _box?.close();
    _box = null;
  }

  Future<DeviceHistorySeries> readSeries(String deviceId) async {
    await init();
    final points = _readPoints(deviceId);
    return DeviceHistorySeries(deviceId: deviceId, points: points);
  }

  Stream<DeviceHistorySeries> watchSeries(String deviceId) {
    final controller = _controllers.putIfAbsent(
      deviceId,
      () => StreamController<DeviceHistorySeries>.broadcast(),
    );
    unawaited(() async {
      controller.add(await readSeries(deviceId));
    }());
    return controller.stream;
  }

  Future<void> recordSnapshot(EcoFlowDeviceSnapshot snapshot) async {
    await init();
    final now = snapshot.updatedAt;
    final cutoff = now.subtract(_retention);
    final nextPoint = _pointFromSnapshot(snapshot);
    final points =
        _readPoints(
            snapshot.deviceId,
          ).where((point) => !point.timestamp.isBefore(cutoff)).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final bucketSizeMs = _sampleWindow.inMilliseconds;
    final nextBucket =
        nextPoint.timestamp.millisecondsSinceEpoch ~/ bucketSizeMs;
    if (points.isNotEmpty) {
      final last = points.last;
      final lastBucket = last.timestamp.millisecondsSinceEpoch ~/ bucketSizeMs;
      if (lastBucket == nextBucket) {
        points[points.length - 1] = nextPoint;
      } else {
        points.add(nextPoint);
      }
    } else {
      points.add(nextPoint);
    }
    await _box!.put(
      snapshot.deviceId,
      points.map((point) => point.toJson()).toList(growable: false),
    );
    _emit(snapshot.deviceId, points);
  }

  DeviceHistoryPoint _pointFromSnapshot(EcoFlowDeviceSnapshot snapshot) {
    double? metricAsDouble(String key) {
      final raw = snapshot.metrics[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw);
      return null;
    }

    return DeviceHistoryPoint(
      timestamp: snapshot.updatedAt,
      inputSolarW: metricAsDouble('inputByType.solarW'),
      inputAcW: metricAsDouble('inputByType.acW'),
      inputCarW: metricAsDouble('inputByType.carW'),
      inputDcW: metricAsDouble('inputByType.dcW'),
      inputOtherW: metricAsDouble('inputByType.otherW'),
      outputAcW: metricAsDouble('outputByType.acW'),
      outputDcW: metricAsDouble('outputByType.dcW'),
      outputOtherW: metricAsDouble('outputByType.otherW'),
      batteryPercent: snapshot.batteryPercent,
      batteryTempC:
          metricAsDouble('battery.maxCellTempC') ?? snapshot.temperatureC,
    );
  }

  List<DeviceHistoryPoint> _readPoints(String deviceId) {
    final raw = _box?.get(deviceId);
    if (raw is! List) return const <DeviceHistoryPoint>[];
    final points = <DeviceHistoryPoint>[];
    for (final item in raw) {
      if (item is Map) {
        final mapped = item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        points.add(DeviceHistoryPoint.fromJson(mapped));
      }
    }
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return points;
  }

  void _emit(String deviceId, List<DeviceHistoryPoint> points) {
    final controller = _controllers[deviceId];
    if (controller == null || controller.isClosed) return;
    controller.add(DeviceHistorySeries(deviceId: deviceId, points: points));
  }
}
