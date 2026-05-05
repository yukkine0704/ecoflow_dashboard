import 'package:flutter/material.dart';

import '../core/ecoflow/ecoflow_settings_storage.dart';
import '../design_system/design_system.dart';

class SettingsScreenResult {
  const SettingsScreenResult({
    required this.saved,
    required this.reconnectRequested,
  });

  final bool saved;
  final bool reconnectRequested;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialThemeMode,
    this.allowReconnect = false,
    this.onThemeModeChanged,
    this.onSaved,
  });

  final ThemeMode? initialThemeMode;
  final bool allowReconnect;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<SettingsScreenResult>? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _bundledEmail = String.fromEnvironment('ECOFLOW_APP_EMAIL');
  static const _bundledPassword = String.fromEnvironment(
    'ECOFLOW_APP_PASSWORD',
  );
  static const _bundledAccessKey = String.fromEnvironment(
    'ECOFLOW_OPEN_ACCESS_KEY',
  );
  static const _bundledSecretKey = String.fromEnvironment(
    'ECOFLOW_OPEN_SECRET_KEY',
  );
  static const _bundledEcoFlowBaseUrl = String.fromEnvironment(
    'ECOFLOW_BASE_URL',
    defaultValue: EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
  );
  static const _bundledOpenApiBaseUrl = String.fromEnvironment(
    'ECOFLOW_OPEN_BASE_URL',
    defaultValue: EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _ecoflowBaseUrlController = TextEditingController();
  final _openApiBaseUrlController = TextEditingController();
  final _settingsStorage = EcoFlowSettingsStorage();

  bool _loading = true;
  bool _saving = false;
  bool _mockSecurityLock = false;
  bool _mockEcoMode = true;
  bool _mockDefaultSwitch = true;
  ThemeMode _themeMode = ThemeMode.system;
  static const List<SegmentOption<ThemeMode>> _themeOptions = [
    SegmentOption<ThemeMode>(
      value: ThemeMode.light,
      label: 'Light',
      icon: Icons.light_mode,
    ),
    SegmentOption<ThemeMode>(
      value: ThemeMode.dark,
      label: 'Dark',
      icon: Icons.dark_mode,
    ),
    SegmentOption<ThemeMode>(
      value: ThemeMode.system,
      label: 'System',
      icon: Icons.settings_suggest,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _ecoflowBaseUrlController.dispose();
    _openApiBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    try {
      final credentialsFuture = _settingsStorage.readCredentials();
      final themeModeFuture = widget.initialThemeMode == null
          ? _settingsStorage.readThemeMode()
          : Future<ThemeMode>.value(widget.initialThemeMode!);
      final results = await Future.wait<dynamic>([
        credentialsFuture,
        themeModeFuture,
      ]);
      if (!mounted) return;
      final credentials = results[0] as EcoFlowCredentials;
      _emailController.text = credentials.email;
      _passwordController.text = credentials.password;
      _accessKeyController.text = credentials.openApiAccessKey;
      _secretKeyController.text = credentials.openApiSecretKey;
      _ecoflowBaseUrlController.text = credentials.ecoflowBaseUrl;
      _openApiBaseUrlController.text = credentials.openApiBaseUrl;
      _themeMode = results[1] as ThemeMode;
    } catch (_) {
      if (!mounted) return;
      _ecoflowBaseUrlController.text =
          EcoFlowSettingsStorage.defaultEcoFlowBaseUrl;
      _openApiBaseUrlController.text =
          EcoFlowSettingsStorage.defaultEcoFlowBaseUrl;
      _themeMode = ThemeMode.system;
      appGooeyToast.warning(
        'We could not load your saved settings',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    setState(() => _themeMode = mode);
    await _settingsStorage.writeThemeMode(mode);
    widget.onThemeModeChanged?.call(mode);
  }

  String? _validateCredentials() {
    if (_emailController.text.trim().isEmpty) {
      return 'Enter your EcoFlow account email.';
    }
    if (_passwordController.text.trim().isEmpty) {
      return 'Enter your EcoFlow account password.';
    }
    if (_accessKeyController.text.trim().isEmpty) {
      return 'Enter your EcoFlow Open API access key.';
    }
    if (_secretKeyController.text.trim().isEmpty) {
      return 'Enter your EcoFlow Open API secret key.';
    }
    for (final entry in <String, String>{
      'EcoFlow API URL': _ecoflowBaseUrlController.text,
      'Open API URL': _openApiBaseUrlController.text,
    }.entries) {
      final uri = Uri.tryParse(entry.value.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        return '${entry.key} is not a valid URL.';
      }
      if (uri.scheme != 'https') {
        return '${entry.key} must use https://.';
      }
    }
    return null;
  }

  EcoFlowCredentials _credentialsFromForm() {
    return EcoFlowCredentials(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      openApiAccessKey: _accessKeyController.text.trim(),
      openApiSecretKey: _secretKeyController.text.trim(),
      ecoflowBaseUrl: _ecoflowBaseUrlController.text.trim(),
      openApiBaseUrl: _openApiBaseUrlController.text.trim(),
    );
  }

  void _loadBundledDevCredentials() {
    final missing = <String>[
      if (_bundledEmail.isEmpty) 'ECOFLOW_APP_EMAIL',
      if (_bundledPassword.isEmpty) 'ECOFLOW_APP_PASSWORD',
      if (_bundledAccessKey.isEmpty) 'ECOFLOW_OPEN_ACCESS_KEY',
      if (_bundledSecretKey.isEmpty) 'ECOFLOW_OPEN_SECRET_KEY',
    ];
    if (missing.isNotEmpty) {
      appGooeyToast.error(
        'Bundled credentials missing',
        config: AppToastConfig(
          description: 'Missing dart-defines: ${missing.join(', ')}',
          meta: 'SETTINGS',
        ),
      );
      return;
    }
    setState(() {
      _emailController.text = _bundledEmail;
      _passwordController.text = _bundledPassword;
      _accessKeyController.text = _bundledAccessKey;
      _secretKeyController.text = _bundledSecretKey;
      _ecoflowBaseUrlController.text = _bundledEcoFlowBaseUrl;
      _openApiBaseUrlController.text = _bundledOpenApiBaseUrl;
    });
    appGooeyToast.success(
      'Bundled dev credentials loaded',
      config: const AppToastConfig(meta: 'SETTINGS'),
    );
  }

  Future<bool> _saveConfiguration() async {
    final error = _validateCredentials();
    if (error != null) {
      appGooeyToast.error(
        'EcoFlow credentials needed',
        config: AppToastConfig(description: error, meta: 'SETTINGS'),
      );
      return false;
    }
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await _settingsStorage.writeCredentials(_credentialsFromForm());
      if (!mounted) return true;
      appGooeyToast.success(
        'EcoFlow connection saved',
        config: const AppToastConfig(meta: 'SETTINGS'),
      );
      return true;
    } catch (error) {
      if (mounted) {
        appGooeyToast.error(
          'Could not save settings',
          config: AppToastConfig(description: '$error', meta: 'SETTINGS'),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndClose({required bool reconnectRequested}) async {
    final ok = await _saveConfiguration();
    if (!ok || !mounted) return;
    final result = SettingsScreenResult(
      saved: true,
      reconnectRequested: reconnectRequested,
    );
    if (widget.onSaved != null) {
      widget.onSaved!(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EcoFlow connection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            surfaceLevel: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect directly to EcoFlow',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use your EcoFlow account and Open API keys for live MQTT telemetry without a local bridge.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Loading your saved connection...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                AppTextField(
                  controller: _emailController,
                  label: 'EcoFlow email',
                  hintText: 'you@example.com',
                  prefixIcon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _passwordController,
                  label: 'EcoFlow password',
                  hintText: 'Account password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _accessKeyController,
                  label: 'Open API access key',
                  hintText: 'EcoFlow developer access key',
                  prefixIcon: Icons.vpn_key_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _secretKeyController,
                  label: 'Open API secret key',
                  hintText: 'EcoFlow developer secret key',
                  prefixIcon: Icons.key_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Load bundled dev credentials',
                  variant: AppButtonVariant.tertiary,
                  fullWidth: true,
                  leading: const Icon(Icons.folder_open_rounded),
                  onPressed: _loadBundledDevCredentials,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  surfaceLevel: 2,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSegmentedControl<ThemeMode>(
                        options: _themeOptions,
                        value: _themeMode,
                        onChanged: _setThemeMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  surfaceLevel: 2,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Switch mock preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Visual demo only, does not affect saved settings.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Device lock',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          AppSwitch(
                            value: _mockSecurityLock,
                            onChanged: (next) {
                              setState(() => _mockSecurityLock = next);
                            },
                            activeTrackColor: const Color(0xFF3BBE7A),
                            inactiveTrackColor: const Color(0xFFE18686),
                            activeIcon: const Icon(Icons.lock_open_rounded),
                            inactiveIcon: const Icon(Icons.lock_rounded),
                            activeThumbIcon: const Icon(Icons.check_rounded),
                            inactiveThumbIcon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Eco mode',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          AppSwitch(
                            value: _mockEcoMode,
                            onChanged: (next) {
                              setState(() => _mockEcoMode = next);
                            },
                            width: 72,
                            activeTrackGradient: const LinearGradient(
                              colors: [Color(0xFF72DFA8), Color(0xFF2FA76E)],
                            ),
                            inactiveTrackGradient: const LinearGradient(
                              colors: [Color(0xFFE8D6A5), Color(0xFFC0A86A)],
                            ),
                            activeIcon: const Icon(Icons.eco_rounded),
                            inactiveIcon: const Icon(Icons.power_settings_new),
                            activeThumbIcon: const Icon(Icons.bolt_rounded),
                            inactiveThumbIcon: const Icon(
                              Icons.pause_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Default switch',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          AppSwitch(
                            value: _mockDefaultSwitch,
                            onChanged: (next) {
                              setState(() => _mockDefaultSwitch = next);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'Advanced endpoints',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    'Keep defaults unless your account uses another EcoFlow region',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    AppTextField(
                      controller: _ecoflowBaseUrlController,
                      label: 'EcoFlow API URL',
                      hintText: EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
                      prefixIcon: Icons.cloud_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _openApiBaseUrlController,
                      label: 'Open API URL',
                      hintText: EcoFlowSettingsStorage.defaultEcoFlowBaseUrl,
                      prefixIcon: Icons.api_rounded,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save connection',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  loading: _saving,
                  onPressed: _saving ? null : _saveConfiguration,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: widget.allowReconnect
                      ? 'Save and reconnect'
                      : 'Save and continue',
                  fullWidth: true,
                  trailing: Icon(
                    widget.allowReconnect ? Icons.refresh : Icons.arrow_forward,
                  ),
                  onPressed: _saving
                      ? null
                      : () => _saveAndClose(
                          reconnectRequested: widget.allowReconnect,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
