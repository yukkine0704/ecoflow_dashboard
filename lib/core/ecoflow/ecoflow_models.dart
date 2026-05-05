enum EcoFlowConnectivity { online, assumeOffline, offline }

extension EcoFlowConnectivityX on EcoFlowConnectivity {
  static EcoFlowConnectivity fromWire(Object? raw) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'online') return EcoFlowConnectivity.online;
      if (normalized == 'assume_offline') {
        return EcoFlowConnectivity.assumeOffline;
      }
      if (normalized == 'offline') return EcoFlowConnectivity.offline;
    }
    return EcoFlowConnectivity.assumeOffline;
  }

  static EcoFlowConnectivity fromLegacyOnline(bool? online) {
    if (online == true) return EcoFlowConnectivity.online;
    if (online == false) return EcoFlowConnectivity.offline;
    return EcoFlowConnectivity.assumeOffline;
  }

  String get wireName {
    return switch (this) {
      EcoFlowConnectivity.online => 'online',
      EcoFlowConnectivity.assumeOffline => 'assume_offline',
      EcoFlowConnectivity.offline => 'offline',
    };
  }
}

class EcoFlowDeviceSnapshot {
  const EcoFlowDeviceSnapshot({
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
  final EcoFlowConnectivity connectivity;
  final bool? onlineLegacy;
  final int? batteryPercent;
  final double? temperatureC;
  final double? totalInputW;
  final double? totalOutputW;
  final Map<String, dynamic> metrics;
  final DateTime updatedAt;

  @Deprecated('Use connectivity instead.')
  bool? get online => onlineLegacy;

  factory EcoFlowDeviceSnapshot.fromJson(Map<String, dynamic> json) {
    final onlineLegacy = _asBool(json['online']);
    final parsedConnectivity = json.containsKey('connectivity')
        ? EcoFlowConnectivityX.fromWire(json['connectivity'])
        : EcoFlowConnectivityX.fromLegacyOnline(onlineLegacy);
    return EcoFlowDeviceSnapshot(
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'displayName': displayName,
      'model': model,
      'imageUrl': imageUrl,
      'online': onlineLegacy,
      'connectivity': connectivity.wireName,
      'batteryPercent': batteryPercent,
      'temperatureC': temperatureC,
      'totalInputW': totalInputW,
      'totalOutputW': totalOutputW,
      'metrics': metrics,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EcoFlowDeviceSnapshot copyWith({
    String? deviceId,
    String? displayName,
    String? model,
    String? imageUrl,
    EcoFlowConnectivity? connectivity,
    bool? onlineLegacy,
    int? batteryPercent,
    double? temperatureC,
    double? totalInputW,
    double? totalOutputW,
    Map<String, dynamic>? metrics,
    DateTime? updatedAt,
  }) {
    return EcoFlowDeviceSnapshot(
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

class EcoFlowFleetItem {
  const EcoFlowFleetItem({
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
  final EcoFlowConnectivity connectivity;
  final bool? onlineLegacy;
  final int? batteryPercent;
  final DateTime updatedAt;

  factory EcoFlowFleetItem.fromJson(Map<String, dynamic> json) {
    final onlineLegacy = EcoFlowDeviceSnapshot._asBool(json['online']);
    final parsedConnectivity = json.containsKey('connectivity')
        ? EcoFlowConnectivityX.fromWire(json['connectivity'])
        : EcoFlowConnectivityX.fromLegacyOnline(onlineLegacy);
    return EcoFlowFleetItem(
      deviceId: (json['deviceId'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['deviceId'] ?? 'Unknown')
          .toString(),
      model: EcoFlowDeviceSnapshot._asString(json['model']),
      connectivity: parsedConnectivity,
      onlineLegacy: onlineLegacy,
      batteryPercent: EcoFlowDeviceSnapshot._asInt(json['batteryPercent']),
      updatedAt:
          EcoFlowDeviceSnapshot._asDateTime(json['updatedAt']) ??
          DateTime.now(),
    );
  }
}

class EcoFlowCatalogItem {
  const EcoFlowCatalogItem({
    required this.deviceId,
    required this.displayName,
    required this.model,
    required this.imageUrl,
  });

  final String deviceId;
  final String displayName;
  final String? model;
  final String? imageUrl;

  factory EcoFlowCatalogItem.fromJson(Map<String, dynamic> json) {
    return EcoFlowCatalogItem(
      deviceId: (json['deviceId'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['deviceId'] ?? 'Unknown')
          .toString(),
      model: EcoFlowDeviceSnapshot._asString(json['model']),
      imageUrl: EcoFlowDeviceSnapshot._asString(json['imageUrl']),
    );
  }
}

enum EcoFlowConnectionStatus { disconnected, connecting, connected, error }

class EcoFlowConnectionState {
  const EcoFlowConnectionState({required this.status, this.message});

  final EcoFlowConnectionStatus status;
  final String? message;
}
