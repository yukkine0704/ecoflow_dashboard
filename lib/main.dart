import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'design_system/design_system.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const double _solarMaxPower = 1300;
  static const double _solarLowThreshold = 400;

  ThemeMode _themeMode = ThemeMode.system;
  bool _switchValue = true;
  String _period = 'Hoy';
  double _solarPower = 840;
  bool _isSolarLow = false;
  final _nameController = TextEditingController();
  final _quotaController = TextEditingController(text: '80');

  @override
  void dispose() {
    _nameController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  void _updateSolarPower(double next, BuildContext context) {
    final clamped = next.clamp(0, _solarMaxPower).toDouble();
    final wasLow = _isSolarLow;
    final isLow = clamped < _solarLowThreshold;

    setState(() {
      _solarPower = clamped;
      _isSolarLow = isLow;
    });

    if (!wasLow && isLow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alerta solar: potencia baja (${clamped.toStringAsFixed(0)}W).',
          ),
        ),
      );
    } else if (wasLow && !isLow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Potencia solar recuperada (${clamped.toStringAsFixed(0)}W).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('EcoFlow Design System')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    AppSegmentedControl<ThemeMode>(
                      value: _themeMode,
                      onChanged: (next) => setState(() => _themeMode = next),
                      options: const [
                        SegmentOption(
                          value: ThemeMode.light,
                          label: 'Claro',
                          icon: Iconsax.sun_1_copy,
                        ),
                        SegmentOption(
                          value: ThemeMode.dark,
                          label: 'Oscuro',
                          icon: Iconsax.moon_copy,
                        ),
                        SegmentOption(
                          value: ThemeMode.system,
                          label: 'Auto',
                          icon: Iconsax.mobile_copy,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppGaugeCard(
                title: 'Entrada Solar',
                value: _solarPower,
                maxValue: _solarMaxPower,
                unit: 'W',
                subtitle: 'Produccion estimada para las proximas 2 horas',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppNeedleGaugeCard(
                value: _solarPower,
                maxValue: _solarMaxPower,
                lowPowerThreshold: _solarLowThreshold,
                title: 'Gauge de Aguja',
                subtitle: 'Capacidad maxima EcoFlow Delta 3',
                onLowPowerChanged: (low) {
                  if (!mounted || low == _isSolarLow) {
                    return;
                  }
                  setState(() => _isSolarLow = low);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                surfaceLevel: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajuste de Potencia Solar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        AppStatusBadge(
                          label: _isSolarLow
                              ? 'Baja (< ${_solarLowThreshold.toInt()}W)'
                              : 'Normal',
                          tone: _isSolarLow
                              ? AppStatusTone.warning
                              : AppStatusTone.active,
                        ),
                      ],
                    ),
                    Slider(
                      min: 0,
                      max: _solarMaxPower,
                      value: _solarPower.clamp(0, _solarMaxPower),
                      onChanged: (next) => _updateSolarPower(next, context),
                    ),
                    Text(
                      '${_solarPower.toStringAsFixed(0)} / ${_solarMaxPower.toInt()} W',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Botones',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton(
                          label: 'Primario',
                          onPressed: () {},
                          leading: const Icon(Iconsax.flash_1_copy),
                        ),
                        AppButton(
                          label: 'Secundario',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Tertiario',
                          variant: AppButtonVariant.tertiary,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Peligro',
                          variant: AppButtonVariant.danger,
                          onPressed: () {},
                        ),
                        const AppButton(label: 'Loading', loading: true),
                        const AppButton(
                          label: 'Disabled',
                          variant: AppButtonVariant.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        AppIconButton(
                          icon: Iconsax.setting_2_copy,
                          tooltip: 'Configuracion',
                          onPressed: () {},
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppIconButton(
                          icon: Iconsax.notification_copy,
                          tooltip: 'Alertas',
                          filled: true,
                          onPressed: () {},
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppSwitch(
                          value: _switchValue,
                          onChanged: (next) =>
                              setState(() => _switchValue = next),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chips y Estado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppChip(label: 'Modo Eco', tone: AppChipTone.primary),
                        AppChip(label: 'PV Online', tone: AppChipTone.success),
                        AppChip(
                          label: 'Revisar Red',
                          tone: AppChipTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppStatusBadge(
                          label: 'Activo',
                          tone: AppStatusTone.active,
                        ),
                        AppStatusBadge(
                          label: 'En espera',
                          tone: AppStatusTone.neutral,
                        ),
                        AppStatusBadge(
                          label: 'Advertencia',
                          tone: AppStatusTone.warning,
                        ),
                        AppStatusBadge(
                          label: 'Error',
                          tone: AppStatusTone.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                surfaceLevel: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inputs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _nameController,
                      label: 'Nombre del dispositivo',
                      hintText: 'Ej: Delta Pro 3',
                      prefixIcon: Iconsax.battery_full_copy,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _quotaController,
                      label: 'Limite de carga',
                      hintText: '0-100',
                      keyboardType: TextInputType.number,
                      suffixIcon: Iconsax.percentage_square_copy,
                      errorText: _quotaController.text.isEmpty
                          ? 'Campo requerido'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSegmentedControl<String>(
                      value: _period,
                      onChanged: (next) => setState(() => _period = next),
                      options: const [
                        SegmentOption(value: 'Hoy', label: 'Hoy'),
                        SegmentOption(value: 'Semana', label: 'Semana'),
                        SegmentOption(value: 'Mes', label: 'Mes'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
