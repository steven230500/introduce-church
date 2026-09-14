import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/models/song.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/app_search_field.dart';
import '../../../../core/widgets/ui/empty_state.dart';
import '../../../songs/children/song_form/presenter/cubit/cubit.dart';
import '../../../songs/children/song_form/presenter/page.dart';
import '../../../songs/children/songs_list/presenter/cubit/cubit.dart';
import '../../../songs/import/song_import_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import 'library_dock.dart';

/// Song library. Search, add to the set list, create and edit.
class SongsPanel extends StatelessWidget {
  const SongsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => Modular.get<SongsListCubit>()..load(),
      child: const _SongsPanelView(),
    );
  }
}

class _SongsPanelView extends StatelessWidget {
  const _SongsPanelView();

  @override
  Widget build(BuildContext context) {
    return DockPanel(
      toolbar: Row(
        children: [
          Expanded(
            child: AppSearchField(
              dense: true,
              hintText: L10n.of(context).songsSearchHint,
              onChanged: context.read<SongsListCubit>().onSearchChanged,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          AppIconButton(
            icon: Icons.library_add_outlined,
            tooltip: L10n.of(context).importTooltip,
            iconSize: 17,
            size: 30,
            onTap: () async {
              final list = context.read<SongsListCubit>();
              final added = await showSongImportDialog(context);
              if (added > 0) await list.load();
            },
          ),
          AppIconButton(
            icon: Icons.add_rounded,
            tooltip: L10n.of(context).songsNew,
            iconSize: 18,
            size: 30,
            onTap: () => openSongForm(context, null),
          ),
        ],
      ),
      body: BlocBuilder<SongsListCubit, SongsListState>(
        builder: (context, state) => switch (state) {
          SongsListLoadingState() => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SongsListErrorState(:final message) => ErrorStateView(
            message: message,
            onRetry: context.read<SongsListCubit>().load,
          ),
          SongsListLoadedState(:final model) =>
            model.songs.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: Icons.music_off_rounded,
                    title: model.search.isEmpty
                        ? L10n.of(context).songsEmptyTitle
                        : L10n.of(context).songsNoMatch,
                    message: model.search.isEmpty ? L10n.of(context).songsEmptyMessage : null,
                    actionLabel: model.search.isEmpty ? L10n.of(context).songsNew : null,
                    onAction: model.search.isEmpty ? () => openSongForm(context, null) : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    itemCount: model.songs.length,
                    itemBuilder: (_, i) => _SongRow(song: model.songs[i]),
                  ),
        },
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _SongRow extends StatefulWidget {
  const _SongRow({required this.song});

  final Song song;

  @override
  State<_SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<_SongRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        // Double click is the fast path for an operator building a set list.
        onDoubleTap: () => _add(context, song),
        child: Container(
          color: _hovering ? AppColors.surfaceControl : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.xs, AppSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (song.author?.isNotEmpty == true) song.author!,
                        L10n.of(context).songsVerseCount(song.verses.length),
                      ].join('  •  '),
                      style: AppText.rowSubtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              AddToSetListButton(size: 26, onAdd: () => _add(context, song)),
              _SongMenu(song: song, visible: _hovering),
            ],
          ),
        ),
      ),
    );
  }

  void _add(BuildContext context, Song song) {
    final control = context.read<ControlCubit>();
    if (control.state is! ControlLoadedState) return;
    if ((control.state as ControlLoadedState).model.activeCollection == null) {
      return;
    }
    control.addSong(song);
    showAddedToast(context, song.title);
  }
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({required this.song, required this.visible});

  final Song song;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: visible ? 1 : 0,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 15, color: AppColors.textMuted),
        padding: EdgeInsets.zero,
        iconSize: 15,
        color: AppColors.surfaceControl,
        tooltip: L10n.of(context).moreActions,
        enabled: visible,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            height: 38,
            child: AppMenuRow(icon: Icons.edit_outlined, label: L10n.of(context).edit),
          ),
          PopupMenuItem(
            value: 'delete',
            height: 38,
            child: AppMenuRow(
              icon: Icons.delete_outline,
              label: L10n.of(context).delete,
              danger: true,
            ),
          ),
        ],
        onSelected: (value) async {
          final cubit = context.read<SongsListCubit>();
          if (value == 'edit') {
            await openSongForm(context, song);
          } else if (value == 'delete') {
            final ok = await showAppConfirmDialog(
              context,
              title: L10n.of(context).songsDeleteTitle,
              message: L10n.of(context).confirmDeleteNamed(song.title),
              confirmLabel: L10n.of(context).delete,
              destructive: true,
              icon: Icons.delete_outline,
            );
            if (ok) await cubit.deleteSong(song.id);
          }
        },
      ),
    );
  }
}

// ── Form ──────────────────────────────────────────────────────────────────────

/// Opens the song editor. Shared by the dock and anywhere else that edits a
/// song, so there is exactly one song-editing experience.
Future<void> openSongForm(BuildContext context, Song? song) async {
  final cubit = context.read<SongsListCubit>();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.xxl),
      child: SizedBox(
        width: 680,
        height: 680,
        child: BlocProvider(
          create: (_) => Modular.get<SongFormCubit>()..init(song),
          child: const SongFormPage(),
        ),
      ),
    ),
  );
  if (saved == true) await cubit.load();
}
