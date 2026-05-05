import 'package:flutter/material.dart';

import '../core/ecoflow/ecoflow_settings_storage.dart';
import 'onboarding_flow.dart';
import 'settings_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  final EcoFlowSettingsStorage _settingsStorage = EcoFlowSettingsStorage();
  bool _loading = true;
  bool _hasCredentials = false;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    final credentials = await _settingsStorage.readCredentialsOrNull();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCredentials = credentials != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasCredentials) {
      return DeviceSelectorScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }

    return SettingsScreen(
      initialThemeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      onSaved: (result) {
        setState(() {
          _hasCredentials = result.saved;
        });
      },
    );
  }
}
