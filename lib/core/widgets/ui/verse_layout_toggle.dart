import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../../l10n/l10n.dart';

/// Whether a passage goes on the screen a verse at a time or all at once.
///
/// A pastor reading three verses straight through does not want the screen
/// changing under him, and a single verse read slowly wants the opposite. The
/// choice is the operator's, and it sticks for the next passage.
class VerseLayoutToggle extends StatelessWidget {
  const VerseLayoutToggle({super.key, required this.together, required this.onChanged});

  final bool together;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Row(
      children: [
        _Option(label: t.bibleOnePerSlide, selected: !together, onTap: () => onChanged(false)),
        const SizedBox(width: AppSpace.xs),
        _Option(label: t.bibleTogether, selected: together, onTap: () => onChanged(true)),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentFill : AppColors.surfaceControl,
            borderRadius: AppRadius.all(AppRadius.sm),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
