import 'package:flutter/material.dart';
import '../../../../l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../shell_cubit.dart';
import 'bible_panel.dart';
import 'media_panel.dart';
import 'songs_panel.dart';
import 'templates_panel.dart';

/// The library, docked to the right of the presenter.
///
/// Songs, Bible, media and designs used to be four full-page destinations AND
/// four modal dialogs, eight interfaces for four things. This is the one place
/// they live now, and it sits next to the set list so adding content never
/// costs you sight of what is on the projector.
class LibraryDock extends StatelessWidget {
  const LibraryDock({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, ShellState>(
      buildWhen: (a, b) => a.tab != b.tab,
      builder: (context, shell) {
        return Container(
          width: width,
          color: AppColors.surface,
          child: Column(
            children: [
              _DockTabs(current: shell.tab),
              const Divider(height: 1, color: AppColors.divider),
              const _DockTarget(),
              Expanded(
                child: switch (shell.tab) {
                  LibraryTab.songs => const SongsPanel(),
                  LibraryTab.bible => const BiblePanel(),
                  LibraryTab.media => const MediaPanel(),
                  LibraryTab.templates => const TemplatesPanel(),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _DockTabs extends StatelessWidget {
  const _DockTabs({required this.current});

  final LibraryTab current;

  static const _icons = {
    LibraryTab.songs: Icons.music_note_rounded,
    LibraryTab.bible: Icons.menu_book_rounded,
    LibraryTab.media: Icons.perm_media_rounded,
    LibraryTab.templates: Icons.palette_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellCubit>();
    final t = L10n.of(context);
    return Container(
      height: AppSizes.panelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Row(
        children: [
          for (final tab in LibraryTab.values)
            Expanded(
              child: _DockTab(
                icon: _icons[tab]!,
                label: tab.label(t),
                active: tab == current,
                onTap: () => shell.openLibrary(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
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
    final color = active ? AppColors.accent : AppColors.textMuted;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: AppSpace.xs + 1),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
          decoration: BoxDecoration(
            color: active ? AppColors.accentFillSoft : Colors.transparent,
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          // The four tabs split a 300px panel, so the longest label has about
          // 60px to live in. Scaling down beats letting the text run outside
          // its own highlight, which is what an ellipsis or a clip would do.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: AppSpace.xs),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Target indicator ──────────────────────────────────────────────────────────

/// Names the collection that the dock's add buttons will write into.
///
/// The old library pages had an add button that silently did nothing when no
/// collection was active. This states the target up front, and says how to fix
/// it when there isn't one.
class _DockTarget extends StatelessWidget {
  const _DockTarget();

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        final collection = state is ControlLoadedState ? state.model.activeCollection : null;
        final hasTarget = collection != null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm - 1),
          color: hasTarget ? AppColors.chrome : AppColors.surfaceControl,
          child: Row(
            children: [
              Icon(
                hasTarget ? Icons.playlist_add_rounded : Icons.info_outline_rounded,
                size: 13,
                color: hasTarget ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: AppSpace.sm - 2),
              Expanded(
                child: Text(
                  hasTarget ? t.dockAddTo(collection.name) : t.dockPickCollectionFirst,
                  style: TextStyle(
                    color: hasTarget ? AppColors.textSecondary : AppColors.textPrimary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!hasTarget)
                GestureDetector(
                  onTap: () => context.read<ShellCubit>().goTo(ShellSection.collections),
                  child: Text(
                    t.dockChoose,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared panel chrome ───────────────────────────────────────────────────────

/// Standard layout for a dock panel: a fixed toolbar over a scrolling body.
class DockPanel extends StatelessWidget {
  const DockPanel({super.key, required this.toolbar, required this.body});

  final Widget toolbar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.sm),
          child: toolbar,
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Add-to-set-list button shared by every dock panel.
///
/// When there is no active collection it stays visible but disabled and says
/// why, instead of looking enabled and doing nothing.
class AddToSetListButton extends StatelessWidget {
  const AddToSetListButton({super.key, required this.onAdd, this.tooltip, this.size = 30});

  final VoidCallback onAdd;

  /// Null means the plain "add this to the running order" wording, which
  /// cannot be a default because it is only known once there is a context.
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return BlocBuilder<ControlCubit, ControlState>(
      buildWhen: (a, b) => _target(a) != _target(b),
      builder: (context, state) {
        final enabled = _target(state) != null;
        return Tooltip(
          message: enabled ? (tooltip ?? t.dockAddToSetList) : t.barNoCollection,
          child: GestureDetector(
            onTap: enabled ? onAdd : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: enabled ? AppColors.accentFillSoft : AppColors.surfaceControl,
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Icon(
                Icons.add_rounded,
                size: size * 0.55,
                color: enabled ? AppColors.accent : AppColors.textDisabled,
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _target(ControlState state) =>
      state is ControlLoadedState ? state.model.activeCollection?.id : null;
}

/// Confirms an add with a brief, non-blocking message.
void showAddedToast(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(L10n.of(context).addedToSetList(label)),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      width: 360,
    ),
  );
}
