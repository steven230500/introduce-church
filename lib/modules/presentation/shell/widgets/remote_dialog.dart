import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/remote/remote_control.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';

Future<void> showRemoteDialog(BuildContext context, RemoteControl remote) async {
  await remote.refreshAddresses();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => RemoteDialog(remote: remote),
  );
}

@visibleForTesting
class RemoteDialog extends StatelessWidget {
  const RemoteDialog({super.key, required this.remote});

  final RemoteControl remote;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: remote.status,
      builder: (context, status, _) => AppDialog(
        title: t.remoteTitle,
        icon: Icons.phonelink_ring_outlined,
        width: 560,
        actions: [
          if (status.enabled) TextButton(onPressed: remote.renewPin, child: Text(t.remoteRenew)),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.remoteIntro, style: AppText.body),
            const SizedBox(height: AppSpace.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: status.enabled,
              onChanged: (on) => on ? remote.enable() : remote.disable(),
              title: Text(t.remoteEnable, style: const TextStyle(fontSize: 14)),
              subtitle: status.enabled
                  ? null
                  : Text(t.remoteEnableNote, style: AppText.rowSubtitle),
            ),
            if (status.failed)
              _Warning(text: t.remoteFailed)
            else if (status.enabled) ...[
              if (status.pairingUrl == null)
                _Warning(text: t.remoteNoNetwork)
              else
                _Pairing(status: status),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: status.devices > 0 ? AppColors.success : AppColors.textDisabled,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(t.remoteDevices(status.devices), style: AppText.body),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Text(t.remoteSameWifi, style: AppText.rowSubtitle),
              const SizedBox(height: AppSpace.xs),
              Text(t.remoteFirewall, style: AppText.rowSubtitle),
              const SizedBox(height: AppSpace.xs),
              Text(t.remoteRenewNote, style: AppText.rowSubtitle),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pairing extends StatelessWidget {
  const _Pairing({required this.status});

  final RemoteStatus status;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // White all the way round: phone cameras read a QR code by its quiet
        // zone, and a dark dialog behind it is not one.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.all(AppRadius.md)),
          child: QrImageView(
            data: status.pairingUrl!,
            size: 170,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.remoteScan, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpace.sm),
              Text(t.remoteOrOpen, style: AppText.rowSubtitle),
              const SizedBox(height: AppSpace.xs),
              SelectableText(
                'http://${status.address}',
                style: const TextStyle(fontSize: 15, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: AppSpace.md),
              Text(t.remotePin.toUpperCase(), style: AppText.sectionLabel),
              Row(
                children: [
                  Text(
                    status.pin,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () => Clipboard.setData(ClipboardData(text: status.pin)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.1),
      borderRadius: AppRadius.all(AppRadius.md),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(text, style: AppText.body)),
      ],
    ),
  );
}
