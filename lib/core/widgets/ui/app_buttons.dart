import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// Button for toolbars and panel headers.
///
/// Pass a [label] and it renders icon plus text. An icon alone is only legible
/// when its meaning is obvious, and in a projection toolbar almost none of them
/// are: a plain rectangle for "black screen" and two near-identical monitors for
/// two different outputs tell the operator nothing. Tooltips do not help, since
/// they need a hover and a wait.
///
/// [active] marks a state that is currently on. A [subtle] button tints itself
/// instead of filling, for toggles that change the workspace rather than what
/// the congregation sees.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.active = false,
    this.activeColor = AppColors.accent,
    this.subtle = false,
    this.size = 34,
    this.iconSize = 16,
  });

  final IconData icon;

  /// Hover text. Says what the control does, and names its shortcut.
  final String tooltip;

  /// Visible text beside the icon. Omit only where space genuinely forbids it.
  final String? label;

  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  /// Tint rather than fill when active.
  final bool subtle;

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final Color background;
    final Color foreground;
    if (active && subtle) {
      background = activeColor.withValues(alpha: 0.18);
      foreground = activeColor;
    } else if (active) {
      background = activeColor;
      foreground = Colors.white;
    } else {
      background = Colors.transparent;
      foreground = enabled ? AppColors.textTertiary : AppColors.textDisabled;
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          height: size,
          width: label == null ? size : null,
          padding: label == null ? null : const EdgeInsets.symmetric(horizontal: AppSpace.sm + 2),
          decoration: BoxDecoration(color: background, borderRadius: AppRadius.all(AppRadius.sm)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: foreground),
              if (label != null) ...[
                const SizedBox(width: AppSpace.sm - 2),
                Text(
                  label!,
                  style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented container that groups related [AppIconButton]s. Grouping is what
/// tells the operator which controls belong together.
class AppButtonGroup extends StatelessWidget {
  const AppButtonGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      padding: const EdgeInsets.all(AppSpace.xs),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Thin rule separating two button groups.
class AppVerticalDivider extends StatelessWidget {
  const AppVerticalDivider({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: height,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
  );
}

/// Pill toggle with an icon and a label, for view-mode switches.
class AppToggleChip extends StatelessWidget {
  const AppToggleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textTertiary;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
          decoration: BoxDecoration(
            color: active ? AppColors.accentFillSoft : Colors.transparent,
            borderRadius: AppRadius.all(AppRadius.sm),
            border: Border.all(color: active ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: AppSpace.xs),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row used inside every popup menu, so menus across the app match.
class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 16, color: danger ? AppColors.danger : AppColors.textTertiary),
        const SizedBox(width: AppSpace.sm),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        if (trailing != null) ...[
          const Spacer(),
          const SizedBox(width: AppSpace.md),
          Text(trailing!, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
        ],
      ],
    );
  }
}
