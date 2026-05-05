import 'ecoflow_models.dart';

class _TrackerState {
  _TrackerState({required this.lastDataAt, required this.explicitOffline});

  DateTime lastDataAt;
  bool explicitOffline;
}

class EcoFlowStatusTracker {
  EcoFlowStatusTracker(this.assumeOffline, this.forceOfflineMultiplier);

  final Duration assumeOffline;
  final int forceOfflineMultiplier;
  final Map<String, _TrackerState> _byDevice = <String, _TrackerState>{};

  void onDataReceived(String deviceId) {
    final item = _getOrCreate(deviceId);
    item.lastDataAt = DateTime.now();
    item.explicitOffline = false;
  }

  void onExplicitStatus(String deviceId, bool online) {
    final item = _getOrCreate(deviceId);
    if (online) {
      item.lastDataAt = DateTime.now();
      item.explicitOffline = false;
      return;
    }
    item.explicitOffline = true;
  }

  EcoFlowConnectivity state(String deviceId) {
    final item = _getOrCreate(deviceId);
    if (item.explicitOffline) return EcoFlowConnectivity.offline;
    final age = DateTime.now().difference(item.lastDataAt);
    if (age < assumeOffline) return EcoFlowConnectivity.online;
    if (age < assumeOffline * forceOfflineMultiplier) {
      return EcoFlowConnectivity.assumeOffline;
    }
    return EcoFlowConnectivity.offline;
  }

  bool wantsStatusPoll(String deviceId) {
    return state(deviceId) == EcoFlowConnectivity.assumeOffline;
  }

  _TrackerState _getOrCreate(String deviceId) {
    return _byDevice.putIfAbsent(
      deviceId,
      () => _TrackerState(
        lastDataAt: DateTime.fromMillisecondsSinceEpoch(0),
        explicitOffline: false,
      ),
    );
  }
}
