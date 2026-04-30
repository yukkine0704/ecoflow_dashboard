import 'package:flutter/material.dart';

import '../core/bridge/bridge_settings_storage.dart';
import 'onboarding_flow.dart';
import 'settings_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  final BridgeSettingsStorage _settingsStorage = BridgeSettingsStorage();
  bool _loading = true;
  String? _wsUrl;

  @override
  void initState() {
    super.initState();
    _loadStoredWsUrl();
  }

  Future<void> _loadStoredWsUrl() async {
    final wsUrl = await _settingsStorage.readStoredWsUrlOrNull();
    if (!mounted) {
      return;
    }
    setState(() {
      _wsUrl = wsUrl;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_wsUrl != null && _wsUrl!.isNotEmpty) {
      return DeviceSelectorScreen(wsUrl: _wsUrl!);
    }

    return SettingsScreen(
      onSaved: (result) {
        setState(() {
          _wsUrl = result.wsUrl;
        });
      },
    );
  }
}
