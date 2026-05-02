enum BridgeConnectivity { online, assumeOffline, offline }

extension BridgeConnectivityX on BridgeConnectivity {
  static BridgeConnectivity fromWire(Object? raw) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'online') return BridgeConnectivity.online;
      if (normalized == 'assume_offline') return BridgeConnectivity.assumeOffline;
      if (normalized == 'offline') return BridgeConnectivity.offline;
    }
    return BridgeConnectivity.assumeOffline;
  }

  static BridgeConnectivity fromLegacyOnline(bool? online) {
    if (online == true) return BridgeConnectivity.online;
    if (online == false) return BridgeConnectivity.offline;
    return BridgeConnectivity.assumeOffline;
  }
}

class BridgeDeviceSnapshot {
  const BridgeDeviceSnapshot({
    required this.deviceId,
    required this.displayName,
    required this.model,
    required this.imageUrl,
    required this.connectivity,
    required this.onlineLegacy,
    required this.batteryPercent,
    required this.temperatureC,
    required this.totalInputW,
    required this.totalOutputW,
    required this.metrics,
    required this.updatedAt,
  });

  final String deviceId;
  final String displayName;
  final String? model;
  final String? imageUrl;
  final BridgeConnectivity connectivity;
  final bool? onlineLegacy;
  final int? batteryPercent;
  final double? temperatureC;
  final double? totalInputW;
  final double? totalOutputW;
  final Map<String, dynamic> metrics;
  final DateTime updatedAt;

  @Deprecated('Use connectivity instead. This will be removed when v1 is retired.')
  bool? get online => onlineLegacy;

  factory BridgeDeviceSnapshot.fromJson(Map<String, dynamic> json) {
    final onlineLegacy = _asBool(json['online']);
    final parsedConnectivity = json.containsKey('connectivity')
        ? BridgeConnectivityX.fromWire(json['connectivity'])
        : BridgeConnectivityX.fromLegacyOnline(onlineLegacy);
    return BridgeDeviceSnapshot(
      deviceId: (json['deviceId'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['deviceId'] ?? 'Unknown')
          .toString(),
      model: _asString(json['model']),
      imageUrl: _asString(json['imageUrl']),
      connectivity: parsedConnectivity,
      onlineLegacy: onlineLegacy,
      batteryPercent: _asInt(json['batteryPercent']),
      temperatureC: _asDouble(json['temperatureC']),
      totalInputW: _asDouble(json['totalInputW']),
      totalOutputW: _asDouble(json['totalOutputW']),
      metrics: _asMap(json['metrics']),
      updatedAt: _asDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  BridgeDeviceSnapshot copyWith({
    String? deviceId,
    String? displayName,
    String? model,
    String? imageUrl,
    BridgeConnectivity? connectivity,
    bool? onlineLegacy,
    int? batteryPercent,
    double? temperatureC,
    double? totalInputW,
    double? totalOutputW,
    Map<String, dynamic>? metrics,
    DateTime? updatedAt,
  }) {
    return BridgeDeviceSnapshot(
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      model: model ?? this.model,
      imageUrl: imageUrl ?? this.imageUrl,
      connectivity: connectivity ?? this.connectivity,
      onlineLegacy: onlineLegacy ?? this.onlineLegacy,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      temperatureC: temperatureC ?? this.temperatureC,
      totalInputW: totalInputW ?? this.totalInputW,
      totalOutputW: totalOutputW ?? this.totalOutputW,
      metrics: metrics ?? this.metrics,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round();
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == 'online' ||
          normalized == 'on' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'offline' ||
          normalized == 'off' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
    return const <String, dynamic>{};
  }

  static String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}

class BridgeFleetItem {
  const BridgeFleetItem({
    required this.deviceId,
    required this.displayName,
    required this.model,
    required this.connectivity,
    required this.onlineLegacy,
    required this.batteryPercent,
    required this.updatedAt,
  });

  final String deviceId;
  final String displayName;
  final String? model;
  final BridgeConnectivity connectivity;
  final bool? onlineLegacy;
  final int? batteryPercent;
  final DateTime updatedAt;

  factory BridgeFleetItem.fromJson(Map<String, dynamic> json) {
    final onlineLegacy = BridgeDeviceSnapshot._asBool(json['online']);
    final parsedConnectivity = json.containsKey('connectivity')
        ? BridgeConnectivityX.fromWire(json['connectivity'])
        : BridgeConnectivityX.fromLegacyOnline(onlineLegacy);
    return BridgeFleetItem(
      deviceId: (json['deviceId'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['deviceId'] ?? 'Unknown')
          .toString(),
      model: BridgeDeviceSnapshot._asString(json['model']),
      connectivity: parsedConnectivity,
      onlineLegacy: onlineLegacy,
      batteryPercent: BridgeDeviceSnapshot._asInt(json['batteryPercent']),
      updatedAt:
          BridgeDeviceSnapshot._asDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class BridgeCatalogItem {
  const BridgeCatalogItem({
    required this.deviceId,
    required this.displayName,
    required this.model,
    required this.imageUrl,
  });

  final String deviceId;
  final String displayName;
  final String? model;
  final String? imageUrl;

  factory BridgeCatalogItem.fromJson(Map<String, dynamic> json) {
    return BridgeCatalogItem(
      deviceId: (json['deviceId'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['deviceId'] ?? 'Unknown')
          .toString(),
      model: BridgeDeviceSnapshot._asString(json['model']),
      imageUrl: BridgeDeviceSnapshot._asString(json['imageUrl']),
    );
  }
}

enum BridgeEventType {
  fleetState,
  deviceSnapshot,
  deviceDelta,
  deviceCatalog,
  unknown,
}

class BridgeEventEnvelope {
  const BridgeEventEnvelope({
    required this.version,
    required this.type,
    required this.payload,
  });

  final String version;
  final BridgeEventType type;
  final Map<String, dynamic> payload;

  factory BridgeEventEnvelope.fromJson(Map<String, dynamic> json) {
    final eventName = (json['event'] ?? '').toString();
    return BridgeEventEnvelope(
      version: (json['version'] ?? 'v1').toString(),
      type: switch (eventName) {
        'fleet_state' => BridgeEventType.fleetState,
        'device_snapshot' => BridgeEventType.deviceSnapshot,
        'device_delta' => BridgeEventType.deviceDelta,
        'device_catalog' => BridgeEventType.deviceCatalog,
        _ => BridgeEventType.unknown,
      },
      payload: BridgeDeviceSnapshot._asMap(json['payload']),
    );
  }
}
