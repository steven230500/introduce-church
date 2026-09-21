import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';

/// Keyboard reference.
///
/// The shortcuts existed before but nothing in the interface said so, so nobody
/// used them. Reachable from the sidebar and from Shift + /.
Future<void> showShortcutsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ShortcutsDialog());
}

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  static Map<String, List<(String, String)>> _groups(L10n t) => {
    t.shortcutsGroupSlides: [
      ('→   ·   ↓   ·   ${t.shortcutsKeySpace}', t.shortcutsNextSlide),
      ('←   ·   ↑', t.shortcutsPreviousSlide),
      (t.shortcutsKeyHomeEnd, t.shortcutsFirstLast),
      ('1 … 9', t.shortcutsJump),
      ('M   ·   Shift + M', t.shortcutsMoments),
    ],
    t.shortcutsGroupProjection: [
      ('L', t.shortcutsLive),
      ('B', t.shortcutsBlack),
      ('W', t.shortcutsWaiting),
      ('Esc', t.shortcutsUnblank),
      ('⌥ ↑   ·   ⌥ ↓', t.shortcutsNudgeText),
    ],
    t.shortcutsGroupContent: [
      ('⌘K', t.shortcutsSearch),
      ('V', t.shortcutsQuickVerse),
      ('E', t.shortcutsEditSlide),
    ],
    t.shortcutsGroupHold: [('K', t.shortcutsHold), ('Enter', t.shortcutsSend)],
    t.shortcutsGroupView: [
      ('G', t.shortcutsToggleView),
      ('F', t.shortcutsToggleLibrary),
      ('Shift + /', t.shortcutsHelp),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AppDialog(
      title: t.shortcutsTitle,
      icon: Icons.keyboard_outlined,
      width: 420,
      // The list is longer than a laptop window is tall once the church adds a
      // display, so it scrolls rather than running off the bottom.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _groups(t).entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.sm),
                child: Text(entry.key.toUpperCase(), style: AppText.sectionLabel),
              ),
              for (final (keys, description) in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Row(
                    children: [
                      SizedBox(width: 150, child: _KeyCap(label: keys)),
                      const SizedBox(width: AppSpace.md),
                      Expanded(child: Text(description, style: AppText.body)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpace.sm),
            Text(t.shortcutsNotWhileTyping, style: AppText.rowSubtitle),
          ],
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs + 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
