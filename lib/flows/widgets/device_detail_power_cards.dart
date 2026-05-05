part of '../device_detail_screen.dart';

extension _DeviceDetailPowerCards on _DeviceDetailScreenState {
  bool _isDelta3Device() {
    if (_snapshot.deviceId == 'P351ZAHAPH2R2706') {
      return true;
    }
    final model = _snapshot.model?.toLowerCase();
    return model?.contains('delta 3') ?? false;
  }

  AppStatusTone _temperatureTone(double? value) {
    if (value == null) {
      return AppStatusTone.neutral;
    }
    if (value >= 48) {
      return AppStatusTone.danger;
    }
    if (value >= 40) {
      return AppStatusTone.warning;
    }
    return AppStatusTone.active;
  }

  _ExtraBatteryVm _extraBatteryVm(int index) {
    final suffix = '$index';
    return _ExtraBatteryVm(
      index: index,
      portWatts: _metricAsDouble('pd.powGet4p8$suffix'),
      soc: _metricAsDouble('pd.extraBattery$suffix.soc'),
      tempC: _metricAsDouble('pd.extraBattery$suffix.temp'),
      maxCellTempC: _metricAsDouble('pd.extraBattery$suffix.maxCellTemp'),
      minCellTempC: _metricAsDouble('pd.extraBattery$suffix.minCellTemp'),
      inputWatts: _metricAsDouble('pd.extraBattery$suffix.inputWatts'),
      outputWatts: _metricAsDouble('pd.extraBattery$suffix.outputWatts'),
      cycles: _metricAsDouble('pd.extraBattery$suffix.cycles'),
    );
  }

  bool _hasExtraBatteryData() {
    if (!_isDelta3Device()) {
      return false;
    }
    return _extraBatteryVm(1).hasAnyData || _extraBatteryVm(2).hasAnyData;
  }

  Widget _buildExtraBatteriesCard(BuildContext context) {
    if (!_isDelta3Device()) {
      return const SizedBox.shrink();
    }

    final eb1 = _extraBatteryVm(1);
    final eb2 = _extraBatteryVm(2);
    final batteries = [eb1, eb2].where((vm) => vm.hasAnyData).toList();
    if (batteries.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget batteryCard(_ExtraBatteryVm vm) {
      return AppCard(
        surfaceLevel: 2,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EB${vm.index}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (vm.soc != null)
                  AppStatusBadge(
                    label: 'SOC ${vm.soc!.toStringAsFixed(0)}%',
                    tone: AppStatusTone.active,
                  ),
                if (vm.portWatts != null)
                  AppStatusBadge(
                    label: 'Port ${vm.portWatts!.toStringAsFixed(0)}W',
                    tone: AppStatusTone.active,
                  ),
                if (vm.inputWatts != null)
                  AppStatusBadge(
                    label: 'In ${vm.inputWatts!.toStringAsFixed(0)}W',
                    tone: AppStatusTone.active,
                  ),
                if (vm.outputWatts != null)
                  AppStatusBadge(
                    label: 'Out ${vm.outputWatts!.toStringAsFixed(0)}W',
                    tone: AppStatusTone.active,
                  ),
                if (vm.tempC != null)
                  AppStatusBadge(
                    label: 'Temp ${vm.tempC!.toStringAsFixed(1)}°C',
                    tone: _temperatureTone(vm.tempC),
                  ),
                if (vm.maxCellTempC != null)
                  AppStatusBadge(
                    label: 'Cell Max ${vm.maxCellTempC!.toStringAsFixed(1)}°C',
                    tone: _temperatureTone(vm.maxCellTempC),
                  ),
                if (vm.minCellTempC != null)
                  AppStatusBadge(
                    label: 'Cell Min ${vm.minCellTempC!.toStringAsFixed(1)}°C',
                    tone: _temperatureTone(vm.minCellTempC),
                  ),
                if (vm.cycles != null)
                  AppStatusBadge(
                    label: 'Cycles ${vm.cycles!.toStringAsFixed(0)}',
                    tone: AppStatusTone.neutral,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      surfaceLevel: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra Batteries',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Telemetría dedicada de baterías auxiliares para Delta 3.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ...batteries.map(
            (vm) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: batteryCard(vm),
            ),
          ),
        ],
      ),
    );
  }

  List<_OutputChannelVm> _outputChannels() {
    const channelCandidates = <String, List<String>>{
      'AC Output': ['powgetacout', 'powgetac', 'acoutputwatts', 'outpower'],
      'Puerto 12V': ['powget12v', 'dc12v', '12vout'],
      'Puerto 24V': ['powget24v', '24vout'],
      'USB-C 1': ['powgettypec1', 'typec1', 'usbc1'],
      'USB-C 2': ['powgettypec2', 'typec2', 'usbc2'],
      'USB-A 1': ['powgetqcusb1', 'qcusb1', 'usba1', 'usb1'],
      'USB-A 2': ['powgetqcusb2', 'qcusb2', 'usba2', 'usb2'],
      'DC Port': ['powgetdcp', 'dcp', 'dcout'],
    };

    final normalizedEntries = _snapshot.metrics.entries.map((entry) {
      final normalized = entry.key.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      return (original: entry.key, normalized: normalized, value: entry.value);
    }).toList();

    final channels = <_OutputChannelVm>[];
    final usedKeys = <String>{};

    for (final candidate in channelCandidates.entries) {
      double? watts;
      String? sourceKey;
      for (final entry in normalizedEntries) {
        final isMatch = candidate.value.any(entry.normalized.contains);
        if (!isMatch) continue;
        final asNum = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());
        if (asNum == null) continue;
        watts = asNum;
        sourceKey = entry.original;
        break;
      }
      channels.add(
        _OutputChannelVm(
          label: candidate.key,
          watts: watts,
          metricKey: sourceKey,
          category: candidate.key.toLowerCase().contains('usb')
              ? 'usb'
              : (candidate.key.toLowerCase().contains('ac') ? 'ac' : 'dc'),
          isDerivedFallback: false,
        ),
      );
      if (sourceKey != null) {
        usedKeys.add(sourceKey);
      }
    }

    for (final entry in normalizedEntries) {
      if (usedKeys.contains(entry.original)) continue;
      if (!entry.normalized.contains('powget')) continue;
      final asNum = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse(entry.value.toString());
      channels.add(
        _OutputChannelVm(
          label: entry.original,
          watts: asNum,
          metricKey: entry.original,
          category:
              entry.normalized.contains('usb') ||
                  entry.normalized.contains('typec')
              ? 'usb'
              : (entry.normalized.contains('ac') ? 'ac' : 'dc'),
          isDerivedFallback: true,
        ),
      );
    }

    final hasMeasured = channels.any((c) => c.watts != null);
    if (!hasMeasured) {
      channels.addAll([
        _OutputChannelVm(
          label: 'AC (resumen)',
          watts: _metricAsDouble('outputByType.acW'),
          metricKey: 'outputByType.acW',
          category: 'ac',
          isDerivedFallback: true,
        ),
        _OutputChannelVm(
          label: 'DC (resumen)',
          watts: _metricAsDouble('outputByType.dcW'),
          metricKey: 'outputByType.dcW',
          category: 'dc',
          isDerivedFallback: true,
        ),
      ]);
    }

    channels.sort((a, b) => a.label.compareTo(b.label));
    return channels;
  }

  Widget _buildDeviceHeroCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final battery = _snapshot.batteryPercent;
    final batteryValue = battery == null ? 0.0 : battery.clamp(0, 100) / 100.0;
    final localAssetImagePath =
        _DeviceDetailScreenState._deviceImageAssetsById[_snapshot.deviceId];

    Widget imageBlock() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: isMobile ? double.infinity : 180,
          height: isMobile ? 220 : 180,
          child: localAssetImagePath != null
              ? Image.asset(
                  localAssetImagePath,
                  fit: isMobile ? BoxFit.cover : BoxFit.contain,
                )
              : (_snapshot.imageUrl == null
                    ? Container(
                        color: colors.primaryContainer.withValues(alpha: 0.32),
                        child: const Icon(
                          Icons.battery_charging_full_rounded,
                          size: 56,
                        ),
                      )
                    : Image.network(
                        _snapshot.imageUrl!,
                        fit: isMobile ? BoxFit.cover : BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.primaryContainer.withValues(
                            alpha: 0.32,
                          ),
                          child: const Icon(
                            Icons.battery_charging_full_rounded,
                            size: 56,
                          ),
                        ),
                      )),
        ),
      );
    }

    Widget detailsBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _snapshot.displayName,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _snapshot.model ?? 'Model unavailable',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Battery Level',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                battery == null ? 'n/a' : '$battery%',
                style: textTheme.displaySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 20,
              child: LinearProgressIndicator(
                value: battery == null ? null : batteryValue,
                minHeight: 20,
                backgroundColor: colors.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '0%',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _estimateLabel(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '100%',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AppCard(
      surfaceLevel: 1,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            imageBlock(),
            const SizedBox(height: 16),
            detailsBlock(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageBlock(),
                const SizedBox(width: 20),
                Expanded(child: detailsBlock()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOutputChannelsCard(BuildContext context) {
    final channels = _outputChannels();
    final usbChannels = channels.where((c) => c.category == 'usb').toList();
    final topChannels = channels.where((c) => c.category != 'usb').toList();
    final cs = Theme.of(context).colorScheme;

    Widget channelTile(_OutputChannelVm channel, {bool compact = false}) {
      final on = (channel.watts ?? 0) > 0;
      final bg = on
          ? cs.surfaceContainerHighest.withValues(alpha: 0.9)
          : cs.surfaceContainerLow;
      final color = on ? cs.primary : cs.onSurfaceVariant;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 18 : 22),
        ),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              channel.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              channel.watts == null
                  ? 'N/D'
                  : '${channel.watts!.toStringAsFixed(0)}W',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      surfaceLevel: 1,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DC Channels', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (topChannels.isEmpty)
            Text(
              'No hay datos de salidas por puerto disponibles.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: topChannels
                  .map(
                    (channel) => SizedBox(
                      width: MediaQuery.sizeOf(context).width > 520
                          ? 220
                          : (MediaQuery.sizeOf(context).width - 72) / 2,
                      child: channelTile(channel),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Puertos USB', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (usbChannels.isEmpty)
            Text(
              'Sin telemetría USB en este momento.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: usbChannels.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.65,
              ),
              itemBuilder: (context, index) =>
                  channelTile(usbChannels[index], compact: true),
            ),
        ],
      ),
    );
  }
}

class _OutputChannelVm {
  const _OutputChannelVm({
    required this.label,
    required this.watts,
    required this.metricKey,
    required this.category,
    required this.isDerivedFallback,
  });

  final String label;
  final double? watts;
  final String? metricKey;
  final String category;
  final bool isDerivedFallback;
}

class _ExtraBatteryVm {
  const _ExtraBatteryVm({
    required this.index,
    required this.portWatts,
    required this.soc,
    required this.tempC,
    required this.maxCellTempC,
    required this.minCellTempC,
    required this.inputWatts,
    required this.outputWatts,
    required this.cycles,
  });

  final int index;
  final double? portWatts;
  final double? soc;
  final double? tempC;
  final double? maxCellTempC;
  final double? minCellTempC;
  final double? inputWatts;
  final double? outputWatts;
  final double? cycles;

  bool get hasAnyData =>
      portWatts != null ||
      soc != null ||
      tempC != null ||
      maxCellTempC != null ||
      minCellTempC != null ||
      inputWatts != null ||
      outputWatts != null ||
      cycles != null;
}
