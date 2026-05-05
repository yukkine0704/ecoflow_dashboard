import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

class DesignSystemTestView extends StatelessWidget {
  const DesignSystemTestView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(
            child: Text(
              'Vista de pruebas simplificada.\nLa telemetría ahora se consume en modo EcoFlow directo.',
            ),
          ),
        ],
      ),
    );
  }
}
