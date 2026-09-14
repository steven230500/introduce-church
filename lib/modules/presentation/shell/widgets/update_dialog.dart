import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_version.dart';
import '../../../../core/services/update_checker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/open_file.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';

/// Tells the operator a newer version is out and how to put it in place.
///
/// Opened by hand, from the sidebar or the settings, never by itself.
Future<void> showUpdateDialog(BuildContext context, AvailableUpdate update) {
  return showDialog<void>(
    context: context,
    builder: (_) => UpdateDialog(update: update, current: appVersion, open: openWithSystem),
  );
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.update, required this.current, required this.open});

  final AvailableUpdate update;
  final String current;

  /// Hands a web address to the browser.
  final Future<void> Function(String url) open;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    // Replacing an app is a different gesture on each system, and the person
    // doing it has usually never installed one by hand before.
    final steps = defaultTargetPlatform == TargetPlatform.windows
        ? t.updateStepsWindows
        : t.updateStepsMac;

    return AppDialog(
      title: t.updateTitle(update.version),
      icon: Icons.system_update_alt_rounded,
      width: 460,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.updateLater)),
        const SizedBox(width: AppSpace.sm),
        FilledButton.icon(
          onPressed: () {
            open(update.downloadUrl);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(t.updateDownload),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.updateBody(current), style: AppText.rowTitle),
          const SizedBox(height: AppSpace.md),
          Text(steps, style: AppText.body),
          const SizedBox(height: AppSpace.sm),
          TextButton.icon(
            onPressed: () => open(update.pageUrl),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.accentLight,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: Text(t.updateWhatsNew),
          ),
        ],
      ),
    );
  }
}
