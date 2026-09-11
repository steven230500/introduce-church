import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';

/// Header for a full-page library view.
///
/// Every library used to hand-roll this with a different padding, which is why
/// the sections never lined up when you switched between them. Use this.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;

  /// Back button or similar, shown before the title.
  final Widget? leading;

  /// Primary actions, right-aligned.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.pageGutter,
        AppSpace.xl,
        AppSpace.pageGutter,
        AppSpace.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpace.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.pageTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.rowSubtitle),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: AppSpace.sm), action],
        ],
      ),
    );
  }
}

/// Header for a panel inside the presenter. Shorter and denser than
/// [PageHeader] because panels are narrow and stacked.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.actions = const [], this.leading});

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.panelHeaderHeight,
      padding: const EdgeInsets.only(left: AppSpace.md, right: AppSpace.xs),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpace.sm)],
          Expanded(
            child: Text(title, style: AppText.panelTitle, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
        ],
      ),
    );
  }
}
