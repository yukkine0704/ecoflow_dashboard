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
  int _stepSliderIndex = 5;
  int _tabIndex = 0;
  int _expandedMenuIndex = 2;

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
      appGooeyToast.warning(
        'Alerta solar: potencia baja',
        config: AppToastConfig(
          description: '${clamped.toStringAsFixed(0)}W por debajo de ${_solarLowThreshold.toInt()}W',
          position: AppToastPosition.topCenter,
          meta: 'ECOFLOW',
          showTimestamp: true,
        ),
      );
    } else if (wasLow && !isLow) {
      appGooeyToast.success(
        'Potencia solar recuperada',
        config: AppToastConfig(
          description: '${clamped.toStringAsFixed(0)}W estable',
          position: AppToastPosition.topCenter,
          meta: 'ECOFLOW',
          showTimestamp: true,
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
      builder: (context, child) {
        return AppGooeyToasterHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('EcoFlow Design System')),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: AppLinearBottomTabs(
              items: const [
                AppLinearTabItem(icon: Iconsax.home_copy, label: 'Inicio'),
                AppLinearTabItem(icon: Iconsax.flash_1_copy, label: 'Solar'),
                AppLinearTabItem(icon: Icons.trending_up, label: 'Pulse'),
                AppLinearTabItem(icon: Iconsax.setting_2_copy, label: 'Ajustes'),
              ],
              selectedIndex: _tabIndex,
              onTabSelected: (index) => setState(() => _tabIndex = index),
              expandedItems: const [
                AppExpandedMenuItem(icon: Iconsax.home_copy, label: 'Home'),
                AppExpandedMenuItem(icon: Iconsax.message_copy, label: 'Inbox'),
                AppExpandedMenuItem(icon: Icons.bug_report_outlined, label: 'My Issues'),
                AppExpandedMenuItem(icon: Iconsax.flash_1_copy, label: 'Pulse'),
                AppExpandedMenuItem(icon: Iconsax.document_copy, label: 'View'),
                AppExpandedMenuItem(icon: Icons.rocket_launch_outlined, label: 'Initiatives'),
                AppExpandedMenuItem(icon: Icons.inventory_2_outlined, label: 'Projects'),
                AppExpandedMenuItem(icon: Iconsax.setting_copy, label: 'Settings'),
              ],
              onExpandedItemSelected: (index) {
                setState(() => _expandedMenuIndex = index);
                appGooeyToast.info(
                  'Menú seleccionado',
                  config: AppToastConfig(
                    description: 'Ítem #${index + 1}',
                    meta: 'LINEAR TABS',
                    duration: const Duration(milliseconds: 2400),
                  ),
                );
              },
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
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
                subtitle: 'Producción estimada para las próximas 2 horas',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppNeedleGaugeCard(
                value: _solarPower,
                maxValue: _solarMaxPower,
                lowPowerThreshold: _solarLowThreshold,
                title: 'Gauge de Aguja',
                subtitle: 'Capacidad máxima EcoFlow Delta 3',
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
                surfaceLevel: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StepSlider',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Índice seleccionado: $_stepSliderIndex',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppStepSlider(
                      stepCount: 11,
                      defaultIndex: _stepSliderIndex,
                      stepShape: StepSliderShape.diamond,
                      onValueChange: (index) {
                        setState(() => _stepSliderIndex = index);
                      },
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
                      'Gooey Toast',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton(
                          label: 'Success',
                          onPressed: () {
                            appGooeyToast.success(
                              'Configuración guardada',
                              config: const AppToastConfig(
                                description: 'Cambios aplicados en el inversor',
                                meta: 'SUCCESS',
                                showTimestamp: true,
                              ),
                            );
                          },
                        ),
                        AppButton(
                          label: 'Error',
                          variant: AppButtonVariant.danger,
                          onPressed: () {
                            appGooeyToast.error(
                              'No se pudo conectar',
                              config: AppToastConfig(
                                description: 'Revisa red y reintenta',
                                meta: 'NETWORK',
                                action: AppToastAction(
                                  label: 'Reintentar',
                                  onPressed: () {},
                                ),
                                bodyLayout: AppToastBodyLayout.spread,
                              ),
                            );
                          },
                        ),
                        AppButton(
                          label: 'Promise',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            appGooeyToast.promise(
                              Future<void>.delayed(const Duration(seconds: 2)),
                              loading: 'Actualizando cuota...',
                              success: 'Cuota actualizada',
                              error: 'No se pudo actualizar',
                              config: const AppToastConfig(
                                description: 'Esperando respuesta del equipo',
                                position: AppToastPosition.bottomCenter,
                              ),
                              successDescription: (_) => 'Respuesta confirmada',
                              errorDescription: (err) => '$err',
                            );
                          },
                        ),
                        AppButton(
                          label: 'Dismiss all',
                          variant: AppButtonVariant.tertiary,
                          onPressed: () => appGooeyToast.dismissAll(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Linear Tabs', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tab: $_tabIndex | Menú: $_expandedMenuIndex',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                      label: 'Límite de carga',
                      hintText: '0-100',
                      keyboardType: TextInputType.number,
                      suffixIcon: Iconsax.percentage_square_copy,
                      errorText: _quotaController.text.isEmpty ? 'Campo requerido' : null,
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
                    const SizedBox(height: AppSpacing.md),
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppChip(label: 'Modo Eco', tone: AppChipTone.primary),
                        AppChip(label: 'PV Online', tone: AppChipTone.success),
                        AppChip(label: 'Revisar Red', tone: AppChipTone.warning),
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
