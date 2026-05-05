import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/ecoflow/ecoflow_settings_storage.dart';
import 'design_system/design_system.dart';
import 'flows/app_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const EcoFlowApp());
}

class EcoFlowApp extends StatefulWidget {
  const EcoFlowApp({super.key});

  @override
  State<EcoFlowApp> createState() => _EcoFlowAppState();
}

class _EcoFlowAppState extends State<EcoFlowApp> {
  final _settingsStorage = EcoFlowSettingsStorage();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _settingsStorage.readThemeMode();
    if (!mounted) {
      return;
    }
    setState(() => _themeMode = mode);
  }

  Future<void> _handleThemeModeChanged(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    setState(() => _themeMode = mode);
    await _settingsStorage.writeThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      builder: (context, child) {
        return AppGooeyToasterHost(child: child ?? const SizedBox.shrink());
      },
      home: AppEntryScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChanged,
      ),
    );
  }
}
