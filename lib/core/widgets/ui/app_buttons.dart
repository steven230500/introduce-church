import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// Square icon button used in toolbars and panel headers.
///
/// [active] fills it with [activeColor] so a toggled state reads at a glance
/// from across the sound booth.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.accent,
    this.size = 34,
    this.iconSize = 16,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: active
                ? Colors.white
                : enabled
                ? AppColors.textTertiary
                : AppColors.textDisabled,
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
