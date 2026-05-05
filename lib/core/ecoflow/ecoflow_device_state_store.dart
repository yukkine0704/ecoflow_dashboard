import 'dart:math' as math;

import 'ecoflow_models.dart';
import 'ecoflow_normalize.dart';

typedef PrimitiveMetric = Object?;

const int _batteryJumpConfirmations = 3;
const int _batteryJumpThresholdPercent = 20;

class EcoFlowDeviceDelta {
  const EcoFlowDeviceDelta({
    required this.deviceId,
    required this.changed,
    required this.updatedAt,
  });

  final String deviceId;
  final Map<String, PrimitiveMetric> changed;
  final DateTime updatedAt;
}

class _DeviceRecord {
  _DeviceRecord({
    required this.snapshot,
    required this.inputComponents,
    required this.outputComponents,
    required this.batterySourceScore,
    required this.temperatureSourceScore,
  });

  EcoFlowDeviceSnapshot snapshot;
  final Map<String, double> inputComponents;
  final Map<String, double> outputComponents;
  int batterySourceScore;
  int temperatureSourceScore;
  int? pendingBatteryPercent;
  int pendingBatterySourceScore = 0;
  int pendingBatteryCount = 0;
}

class EcoFlowDeviceStateStore {
  final Map<String, _DeviceRecord> _devices = <String, _DeviceRecord>{};

  void setCatalog(
    List<
      ({String deviceId, String? displayName, String? model, String? imageUrl})
    >
    devices,
  ) {
    final now = DateTime.now();
    for (final device in devices) {
      final record = _getOrCreate(device.deviceId, now);
      record.snapshot = record.snapshot.copyWith(
        displayName:
            _nonEmpty(device.displayName) ?? record.snapshot.displayName,
        model: _nonEmpty(device.model) ?? record.snapshot.model,
        imageUrl: _nonEmpty(device.imageUrl) ?? record.snapshot.imageUrl,
        updatedAt: now,
      );
    }
  }

  EcoFlowDeviceDelta upsertRawMetric(
    String deviceId,
    String channel,
    String state,
    PrimitiveMetric rawPayload,
  ) {
    final now = DateTime.now();
    final record = _getOrCreate(deviceId, now);
    final metricKey = '$channel.$state';
    final numeric = _toNumber(rawPayload);
    if (numeric != null && !_isPlausibleNumericMetric(metricKey, numeric)) {
      return EcoFlowDeviceDelta(
        deviceId: deviceId,
        changed: const <String, PrimitiveMetric>{},
        updatedAt: now,
      );
    }
    final metrics = Map<String, dynamic>.from(record.snapshot.metrics);
    metrics[metricKey] = rawPayload;
    record.snapshot = record.snapshot.copyWith(
      metrics: metrics,
      updatedAt: now,
    );
    return EcoFlowDeviceDelta(
      deviceId: deviceId,
      changed: <String, PrimitiveMetric>{'metrics.$metricKey': rawPayload},
      updatedAt: now,
    );
  }

  EcoFlowDeviceDelta upsertConnectivity(
    String deviceId,
    EcoFlowConnectivity connectivity,
  ) {
    final now = DateTime.now();
    final record = _getOrCreate(deviceId, now);
    final online = switch (connectivity) {
      EcoFlowConnectivity.online => true,
      EcoFlowConnectivity.offline => false,
      EcoFlowConnectivity.assumeOffline => null,
    };
    record.snapshot = record.snapshot.copyWith(
      connectivity: connectivity,
      onlineLegacy: online,
      updatedAt: now,
    );
    return EcoFlowDeviceDelta(
      deviceId: deviceId,
      changed: <String, PrimitiveMetric>{
        'connectivity': connectivity.wireName,
        'online': online,
      },
      updatedAt: now,
    );
  }

  EcoFlowDeviceDelta upsertMetric(
    String deviceId,
    String channel,
    String state,
    PrimitiveMetric rawPayload,
  ) {
    final now = DateTime.now();
    final record = _getOrCreate(deviceId, now);
    final metricKey = '$channel.$state';
    PrimitiveMetric normalizedValue = rawPayload;
    final numeric = _toNumber(rawPayload);
    if (numeric != null) {
      if (!_isPlausibleNumericMetric(metricKey, numeric)) {
        return EcoFlowDeviceDelta(
          deviceId: deviceId,
          changed: const <String, PrimitiveMetric>{},
          updatedAt: now,
        );
      }
      normalizedValue = numeric;
    }

    final changed = <String, PrimitiveMetric>{
      'metrics.$metricKey': normalizedValue,
    };
    final metrics = Map<String, dynamic>.from(record.snapshot.metrics);
    metrics[metricKey] = normalizedValue;
    var batteryPercent = record.snapshot.batteryPercent;
    var temperatureC = record.snapshot.temperatureC;
    var totalInputW = record.snapshot.totalInputW;
    var totalOutputW = record.snapshot.totalOutputW;

    final rule = findRule(channel, state);
    if (rule != null) {
      switch (rule.field) {
        case MappingFieldKind.batteryPercent:
          final battery = _toNumber(normalizedValue);
          if (battery != null) {
            final rounded = battery.round();
            final sourceScore = _batterySourceScore(metricKey);
            final scoreOk =
                sourceScore >= record.batterySourceScore ||
                batteryPercent == null;
            final higherConfidenceSource =
                sourceScore > record.batterySourceScore;
            final suspiciousJump = _isBatteryJumpSuspicious(
              batteryPercent,
              rounded,
            );
            final confirmedJump = suspiciousJump
                ? _trackBatteryJumpCandidate(record, rounded, sourceScore)
                : false;
            if (scoreOk &&
                (!suspiciousJump || higherConfidenceSource || confirmedJump)) {
              batteryPercent = rounded;
              record.batterySourceScore = sourceScore;
              _clearBatteryJumpCandidate(record);
              changed['batteryPercent'] = batteryPercent;
            } else if (!suspiciousJump) {
              _clearBatteryJumpCandidate(record);
            }
          }
          break;
        case MappingFieldKind.temperatureC:
          var temp = _toNumber(normalizedValue);
          if (temp != null) {
            final reconciled = _reconcileBatteryTemperatureUnit(
              record,
              metricKey,
              temp,
            );
            if (reconciled != temp) {
              temp = reconciled;
              normalizedValue = reconciled;
              metrics[metricKey] = reconciled;
              changed['metrics.$metricKey'] = reconciled;
            }
          }
          if (temp != null) {
            final sourceScore = _temperatureSourceScore(metricKey);
            final scoreOk =
                sourceScore >= record.temperatureSourceScore ||
                temperatureC == null;
            if (scoreOk && !_isTemperatureJumpSuspicious(temperatureC, temp)) {
              temperatureC = temp;
              record.temperatureSourceScore = sourceScore;
              changed['temperatureC'] = temperatureC;
            }
          }
          if (state == 'maxCellTemp' || state == 'bmsMaxCellTemp') {
            metrics['battery.maxCellTempC'] = temp;
            changed['metrics.battery.maxCellTempC'] = temp;
          }
          break;
        case MappingFieldKind.totalInputW:
          final asNumber = _toNumber(normalizedValue);
          if (asNumber != null) {
            record.inputComponents[metricKey] = asNumber;
          } else {
            record.inputComponents.remove(metricKey);
          }
          final activeInput = _resolveActiveInputComponents(
            record.inputComponents,
          );
          if (activeInput['pd.powGetPvL'] != null &&
              metrics['pd.powGetPvL'] == null) {
            metrics['pd.powGetPvL'] = activeInput['pd.powGetPvL'];
            changed['metrics.pd.powGetPvL'] = activeInput['pd.powGetPvL'];
          }
          totalInputW = _sumValues(activeInput);
          changed['totalInputW'] = totalInputW;
          _refreshInputByType(activeInput, metrics, changed);
          break;
        case MappingFieldKind.totalOutputW:
          final asNumber = _toNumber(normalizedValue);
          if (asNumber != null) {
            record.outputComponents[metricKey] = asNumber;
          } else {
            record.outputComponents.remove(metricKey);
          }
          final activeOutput = _resolveActiveOutputComponents(
            record.outputComponents,
          );
          totalOutputW = _sumValues(activeOutput);
          changed['totalOutputW'] = totalOutputW;
          _refreshOutputByType(activeOutput, metrics, changed);
          break;
        case MappingFieldKind.metric:
          if (rule.metricKey != null) {
            changed['metrics.${rule.metricKey}'] = normalizedValue;
          }
          break;
      }
    }

    record.snapshot = record.snapshot.copyWith(
      batteryPercent: batteryPercent,
      temperatureC: temperatureC,
      totalInputW: totalInputW,
      totalOutputW: totalOutputW,
      metrics: metrics,
      updatedAt: now,
    );
    return EcoFlowDeviceDelta(
      deviceId: deviceId,
      changed: changed,
      updatedAt: now,
    );
  }

  EcoFlowDeviceSnapshot? getSnapshot(String deviceId) {
    return _devices[deviceId]?.snapshot;
  }

  List<EcoFlowDeviceSnapshot> getAllSnapshots() {
    return _devices.values.map((record) => record.snapshot).toList();
  }

  List<EcoFlowDeviceSnapshot> getFleetState() {
    final values = _devices.values.map((record) => record.snapshot).toList();
    values.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return values;
  }

  _DeviceRecord _getOrCreate(String deviceId, DateTime now) {
    final existing = _devices[deviceId];
    if (existing != null) return existing;
    final created = _DeviceRecord(
      snapshot: EcoFlowDeviceSnapshot(
        deviceId: deviceId,
        displayName: deviceId,
        model: null,
        imageUrl: null,
        onlineLegacy: null,
        connectivity: EcoFlowConnectivity.offline,
        batteryPercent: null,
        temperatureC: null,
        totalInputW: null,
        totalOutputW: null,
        metrics: const <String, dynamic>{},
        updatedAt: now,
      ),
      inputComponents: <String, double>{},
      outputComponents: <String, double>{},
      batterySourceScore: 0,
      temperatureSourceScore: 0,
    );
    _devices[deviceId] = created;
    return created;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  double? _toNumber(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? _sumValues(Map<String, double> values) {
    if (values.isEmpty) return null;
    return values.values.fold<double>(0, (acc, value) => acc + value);
  }

  bool _isPlausibleNumericMetric(String metricKey, double value) {
    if (!value.isFinite) return false;
    final key = metricKey.toLowerCase();
    final isPowerLike =
        key.contains('watts') ||
        key.contains('powget') ||
        key.contains('inpower') ||
        key.contains('outpower') ||
        key.contains('powinsumw') ||
        key.contains('powoutsumw');
    if (isPowerLike && value.abs() > 100000) return false;
    if (key.contains('soc') && (value < -1 || value > 1000)) return false;
    if (key.contains('temp') && value.abs() > 200) return false;
    return true;
  }

  bool _isBatteryJumpSuspicious(int? previous, int next) {
    if (previous == null) return false;
    return (previous - next).abs() > _batteryJumpThresholdPercent;
  }

  bool _trackBatteryJumpCandidate(
    _DeviceRecord record,
    int percent,
    int sourceScore,
  ) {
    if (record.pendingBatteryPercent == percent &&
        record.pendingBatterySourceScore == sourceScore) {
      record.pendingBatteryCount += 1;
    } else {
      record.pendingBatteryPercent = percent;
      record.pendingBatterySourceScore = sourceScore;
      record.pendingBatteryCount = 1;
    }
    return record.pendingBatteryCount >= _batteryJumpConfirmations;
  }

  void _clearBatteryJumpCandidate(_DeviceRecord record) {
    record.pendingBatteryPercent = null;
    record.pendingBatterySourceScore = 0;
    record.pendingBatteryCount = 0;
  }

  bool _isTemperatureJumpSuspicious(double? previous, double next) {
    if (previous == null) return false;
    return (previous - next).abs() > 12;
  }

  int _batterySourceScore(String metricKey) {
    final key = metricKey.toLowerCase();
    if (key.contains('cmsbattsoc') || key.contains('lcdshowsoc')) return 120;
    if (key.endsWith('.soc')) return 100;
    if (key.contains('f32showsoc') || key.contains('f32lcdshowsoc')) return 90;
    if (key.contains('bmsbattsoc')) return 80;
    return 50;
  }

  int _temperatureSourceScore(String metricKey) {
    final key = metricKey.toLowerCase();
    if (key.endsWith('.temp') && key.contains('bms')) return 100;
    if (key.endsWith('.temp') && key.contains('pd')) return 95;
    if (key.endsWith('.temp')) return 90;
    if (key.contains('maxcelltemp')) return 85;
    if (key.contains('mincelltemp')) return 80;
    if (key.contains('mos')) return 70;
    if (key.contains('env')) return 60;
    return 50;
  }

  double? _getMetricNumber(Map<String, dynamic> metrics, String key) {
    return _toNumber(metrics[key]);
  }

  double _fahrenheitToCelsius(double value) => (value - 32) * (5 / 9);

  double _reconcileBatteryTemperatureUnit(
    _DeviceRecord record,
    String metricKey,
    double tempCOrF,
  ) {
    final key = metricKey.toLowerCase();
    final isBmsTemp = key == 'bms.temp';
    final isMaxCellTemp =
        key.endsWith('.maxcelltemp') || key.endsWith('.bmsmaxcelltemp');
    if (!isBmsTemp && !isMaxCellTemp) return tempCOrF;
    final counterpart = isBmsTemp
        ? (_getMetricNumber(record.snapshot.metrics, 'battery.maxCellTempC') ??
              _getMetricNumber(record.snapshot.metrics, 'bms.maxCellTemp') ??
              _getMetricNumber(record.snapshot.metrics, 'pd.bmsMaxCellTemp'))
        : _getMetricNumber(record.snapshot.metrics, 'bms.temp');
    if (counterpart == null) return tempCOrF;
    final directDiff = (tempCOrF - counterpart).abs();
    if (directDiff <= 10) return tempCOrF;
    final converted = _fahrenheitToCelsius(tempCOrF);
    final convertedDiff = (converted - counterpart).abs();
    if (convertedDiff + 1e-6 < directDiff && convertedDiff <= 10) {
      return converted;
    }
    return tempCOrF;
  }

  String _normalizedPowerKey(String metricKey) {
    return metricKey.toLowerCase().replaceAll(RegExp(r'[._-]'), '');
  }

  String _detectInputType(String metricKey) {
    final key = _normalizedPowerKey(metricKey);
    if (key.contains('powgetpv') ||
        key.contains('pv') ||
        key.contains('solar')) {
      return 'solar';
    }
    if (key.contains('powgetacin') ||
        key.contains('acin') ||
        key.contains('acinput') ||
        key.contains('acin')) {
      return 'ac';
    }
    if (key.contains('powgetdcp2') ||
        key.contains('carin') ||
        key.contains('car')) {
      return 'car';
    }
    if (key.contains('powgetdcp') ||
        key.contains('dcin') ||
        key.contains('dcp')) {
      return 'dc';
    }
    if (key.endsWith('inputwatts') || key.contains('inputwatts')) return 'ac';
    return 'other';
  }

  bool _isSourceSpecificInputMetric(String metricKey) {
    final key = _normalizedPowerKey(metricKey);
    return key.contains('powgetacin') ||
        key.contains('powgetpv') ||
        key.contains('powgetdcp') ||
        key.contains('acinpower') ||
        key.contains('carinpower') ||
        key.contains('dcinpower') ||
        key.contains('pv1inputwatts') ||
        key.contains('pv2inputwatts');
  }

  Map<String, double> _resolveActiveInputComponents(
    Map<String, double> components,
  ) {
    final sourceSpecific = Map<String, double>.fromEntries(
      components.entries.where(
        (entry) => _isSourceSpecificInputMetric(entry.key),
      ),
    );
    if (sourceSpecific.isEmpty) return Map<String, double>.from(components);

    final keys = sourceSpecific.keys.map((key) => key.toLowerCase()).toList();
    final hasPvSplit = keys.any(
      (key) => key.contains('powgetpvh') || key.contains('powgetpvl'),
    );
    final hasOnlyPvGeneric =
        keys.any((key) => key.contains('powgetpv')) && !hasPvSplit;
    final hasOtherInputSources = sourceSpecific.entries.any((entry) {
      final key = entry.key.toLowerCase();
      final isOtherSource =
          key.contains('powgetacin') ||
          key.contains('powgetdcp') ||
          key.contains('carinpower') ||
          key.contains('dcinpower');
      return isOtherSource && entry.value > 0;
    });
    MapEntry<String, double>? genericInput;
    for (final entry in components.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'pd.inputwatts' || key.endsWith('.inputwatts')) {
        genericInput = entry;
        break;
      }
    }
    if (genericInput != null && !hasOtherInputSources) {
      final totalInput = genericInput.value;
      final solarKeys = sourceSpecific.keys
          .where((key) => key.toLowerCase().contains('powgetpv'))
          .toList();
      final solarSum = solarKeys.fold<double>(
        0,
        (acc, key) => acc + (sourceSpecific[key] ?? 0),
      );
      if (solarKeys.isNotEmpty && totalInput > solarSum + 0.5) {
        final delta = math.max(totalInput - solarSum, 0).toDouble();
        String? pvLKey;
        for (final key in solarKeys) {
          if (key.toLowerCase().contains('powgetpvl')) {
            pvLKey = key;
            break;
          }
        }
        if (pvLKey != null) {
          sourceSpecific[pvLKey] = (sourceSpecific[pvLKey] ?? 0) + delta;
        } else if (hasOnlyPvGeneric) {
          sourceSpecific['pd.powGetPvL'] = delta;
        } else {
          sourceSpecific['pd.powGetPvInferred'] = delta;
        }
      }
    }
    return sourceSpecific;
  }

  String _detectOutputType(String metricKey) {
    final key = _normalizedPowerKey(metricKey);
    if (key.contains('powgetacout') ||
        key.contains('powgetac') ||
        key.contains('acoutput') ||
        key.contains('acout')) {
      return 'ac';
    }
    if (key.contains('12v') ||
        key.contains('24v') ||
        key.contains('typec') ||
        key.contains('qcusb') ||
        key.contains('usb') ||
        key.contains('dcp') ||
        key.contains('dc')) {
      return 'dc';
    }
    return 'other';
  }

  bool _isSourceSpecificOutputMetric(String metricKey) {
    final key = _normalizedPowerKey(metricKey);
    return key.contains('powgetacout') ||
        key.contains('powgetac') ||
        key.contains('powget12v') ||
        key.contains('powget24v') ||
        key.contains('powgettypec') ||
        key.contains('powgetqcusb') ||
        key.contains('powgetdcp') ||
        key.contains('usb1watts') ||
        key.contains('usb2watts') ||
        key.contains('typec1watts') ||
        key.contains('typec2watts') ||
        key.contains('powget5p8') ||
        key.contains('powget4p8');
  }

  Map<String, double> _resolveActiveOutputComponents(
    Map<String, double> components,
  ) {
    final sourceSpecific = Map<String, double>.fromEntries(
      components.entries.where(
        (entry) => _isSourceSpecificOutputMetric(entry.key),
      ),
    );
    return sourceSpecific.isEmpty
        ? Map<String, double>.from(components)
        : sourceSpecific;
  }

  void _refreshInputByType(
    Map<String, double> components,
    Map<String, dynamic> metrics,
    Map<String, PrimitiveMetric> changed,
  ) {
    final bucketMap = <String, Map<String, double>>{
      'solar': <String, double>{},
      'ac': <String, double>{},
      'car': <String, double>{},
      'dc': <String, double>{},
      'other': <String, double>{},
    };
    for (final entry in components.entries) {
      bucketMap[_detectInputType(entry.key)]![entry.key] = entry.value;
    }
    for (final type in const <String>['solar', 'ac', 'car', 'dc', 'other']) {
      final total = _sumValues(bucketMap[type]!);
      final metricKey = 'inputByType.${type}W';
      if (total == null) {
        metrics.remove(metricKey);
        changed['metrics.$metricKey'] = null;
      } else {
        metrics[metricKey] = total;
        changed['metrics.$metricKey'] = total;
      }
    }
  }

  void _refreshOutputByType(
    Map<String, double> components,
    Map<String, dynamic> metrics,
    Map<String, PrimitiveMetric> changed,
  ) {
    final bucketMap = <String, Map<String, double>>{
      'ac': <String, double>{},
      'dc': <String, double>{},
      'other': <String, double>{},
    };
    for (final entry in components.entries) {
      bucketMap[_detectOutputType(entry.key)]![entry.key] = entry.value;
    }
    for (final type in const <String>['ac', 'dc', 'other']) {
      final total = _sumValues(bucketMap[type]!);
      final metricKey = 'outputByType.${type}W';
      if (total == null) {
        metrics.remove(metricKey);
        changed['metrics.$metricKey'] = null;
      } else {
        metrics[metricKey] = total;
        changed['metrics.$metricKey'] = total;
      }
    }
  }
}
