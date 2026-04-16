import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'core/mqtt/mqtt_client_factory.dart';
import 'core/mqtt/mqtt_models.dart';
import 'core/mqtt/mqtt_telemetry_client.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late MqttTelemetryClient _mqttClient;
  MqttProtocolVersion _protocol = MqttProtocolVersion.v5;

  @override
  void initState() {
    super.initState();
    _mqttClient = _buildClient(_protocol);
  }

  @override
  void dispose() {
    _mqttClient.dispose();
    super.dispose();
  }

  MqttTelemetryClient _buildClient(MqttProtocolVersion protocol) {
    return MqttClientFactory.create(
      MqttClientConfig(
        host: 'broker.hivemq.com',
        clientId: 'ecoflow-dashboard-demo',
        protocol: protocol,
      ),
    );
  }

  void _changeProtocol(MqttProtocolVersion nextProtocol) {
    if (_protocol == nextProtocol) {
      return;
    }
    _mqttClient.dispose();
    setState(() {
      _protocol = nextProtocol;
      _mqttClient = _buildClient(nextProtocol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('EcoFlow Dashboard'),
          leading: const Icon(Iconsax.flash),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cliente MQTT activo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButton<MqttProtocolVersion>(
                value: _protocol,
                onChanged: (value) {
                  if (value != null) {
                    _changeProtocol(value);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: MqttProtocolVersion.v311,
                    child: Text('MQTT 3.1.1'),
                  ),
                  DropdownMenuItem(
                    value: MqttProtocolVersion.v5,
                    child: Text('MQTT 5'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _protocol == MqttProtocolVersion.v5
                    ? 'Preparado para brokers MQTT 5.'
                    : 'Preparado para brokers MQTT 3.1.1.',
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Iconsax.battery_full),
                  SizedBox(width: 8),
                  Text('Iconsax configurado como libreria de iconos'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
