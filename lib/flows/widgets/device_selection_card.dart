import 'package:flutter/material.dart';

import '../../core/bridge/bridge_models.dart';
import '../../design_system/design_system.dart';

class DeviceSelectionCard extends StatelessWidget {
  const DeviceSelectionCard({
    super.key,
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final BridgeDeviceSnapshot device;
  final bool selected;
  final VoidCallback onTap;
  static const Map<String, String> _deviceImageAssetsById = <String, String>{
    'P351ZAHAPH2R2706': 'assets/Delta-3.png',
    'R651ZAB5XH111262': 'assets/River-3.png',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final battery = device.batteryPercent;
    final connectivity = device.connectivity;
    final batteryValue = battery == null ? 0.0 : battery.clamp(0, 100) / 100.0;
    final statusLabel = switch (connectivity) {
      BridgeConnectivity.online => 'Online',
      BridgeConnectivity.assumeOffline => 'Assume offline',
      BridgeConnectivity.offline => 'Offline',
    };
    final statusTone = switch (connectivity) {
      BridgeConnectivity.online => AppStatusTone.active,
      BridgeConnectivity.assumeOffline => AppStatusTone.warning,
      BridgeConnectivity.offline => AppStatusTone.danger,
    };
    final estimateLabel = _estimateLabel(device, battery);
    final localAssetImagePath = _deviceImageAssetsById[device.deviceId];

    Widget imageBlock() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: isMobile ? double.infinity : 136,
          height: isMobile ? 180 : 136,
          child: localAssetImagePath != null
              ? Image.asset(
                  localAssetImagePath,
                  fit: isMobile ? BoxFit.cover : BoxFit.contain,
                )
              : (device.imageUrl == null
              ? Container(
                  color: colors.primaryContainer.withValues(alpha: 0.32),
                  child: const Icon(Icons.battery_charging_full_rounded),
                )
              : Image.network(
                  device.imageUrl!,
                  fit: isMobile ? BoxFit.cover : BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colors.primaryContainer.withValues(alpha: 0.32),
                    child: const Icon(Icons.battery_charging_full_rounded),
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
              Expanded(
                child: Text(
                  device.displayName,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            device.model ?? 'Model unavailable',
            style: textTheme.titleLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
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
                estimateLabel,
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
      surfaceLevel: selected ? 2 : 1,
      onTap: onTap,
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

  String _estimateLabel(BridgeDeviceSnapshot device, int? battery) {
    if (device.connectivity == BridgeConnectivity.offline) {
      return 'Disconnected';
    }
    if (battery == null) {
      return 'Est. n/a';
    }
    if (battery < 30) {
      return battery < 15 ? 'May run out soon!' : 'Needs to charge soon';
    }
    final outputW = device.totalOutputW?.abs();
    if (outputW == null || outputW <= 0) {
      return 'Ready to charge';
    }
    final estimatedHours = (battery / 100) * 12;
    return 'Est. ${estimatedHours.toStringAsFixed(0)}h remaining';
  }
}
