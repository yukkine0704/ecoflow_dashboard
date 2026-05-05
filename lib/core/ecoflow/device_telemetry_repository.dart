import 'ecoflow_history_store.dart';
import 'ecoflow_models.dart';

abstract class DeviceTelemetryRepository {
  Stream<List<EcoFlowDeviceSnapshot>> get fleet;
  Stream<EcoFlowDeviceSnapshot> get deviceUpdates;
  Stream<EcoFlowConnectionState> get connection;
  Stream<List<EcoFlowCatalogItem>> get catalog;
  List<EcoFlowDeviceSnapshot> get currentFleet;

  Stream<DeviceHistorySeries> watchHistory(String deviceId);
  Future<DeviceHistorySeries> readHistory(String deviceId);
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
}
