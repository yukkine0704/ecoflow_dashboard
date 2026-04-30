import 'package:flutter/material.dart';

import '../core/bridge/bridge_settings_storage.dart';
import 'device_dashboard_screen.dart';
import 'onboarding_flow.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  final BridgeSettingsStorage _settingsStorage = BridgeSettingsStorage();
  Future<String?>? _storedWsUrlFuture;

  @override
  void initState() {
    super.initState();
    _storedWsUrlFuture = _settingsStorage.readStoredWsUrlOrNull();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _storedWsUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final wsUrl = snapshot.data;
        if (wsUrl != null && wsUrl.isNotEmpty) {
          return DeviceDashboardScreen(wsUrl: wsUrl);
        }
        return const ApiConfigurationScreen();
      },
    );
  }
}
