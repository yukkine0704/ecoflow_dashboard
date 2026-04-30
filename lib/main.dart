import 'package:flutter/material.dart';

import 'design_system/design_system.dart';
import 'flows/app_entry_screen.dart';

void main() {
  runApp(const EcoFlowApp());
}

class EcoFlowApp extends StatelessWidget {
  const EcoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return AppGooeyToasterHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppEntryScreen(),
    );
  }
}
