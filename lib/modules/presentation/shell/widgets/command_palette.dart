import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/local_db/bible_reference.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/models/slide_template.dart';
import '../../../../core/models/song.dart';
import '../../../../core/repositories/media_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/fuzzy_match.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/children/songs_list/repository/repository.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../shell_cubit.dart';
import 'notices_dialog.dart';
import 'quick_verse_dialog.dart';

/// One place to type the name of the thing you want.
///
/// A church's library outgrows its tabs by the second year: forty songs, a
/// dozen designs, a folder of media. Finding the right one meant remembering
/// which tab it lived in and scrolling. Here the operator types three letters
/// of the name and presses Enter, and it works the same for a passage and for
/// a control on the live bar.
Future<void> showCommandPalette(BuildContext context) {
  final control = context.read<ControlCubit>();
  final shell = context.read<ShellCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: control),
        BlocProvider.value(value: shell),
      ],
      child: const CommandPalette(),
    ),
  );
}

/// What one row of the palette does when it is chosen.
enum ResultKind { action, bible, song, media, design }

class PaletteResult {
  const PaletteResult({
    required this.kind,
    required this.title,
    required this.icon,
    required this.run,
    this.subtitle,
    this.enabled = true,
  });

  final ResultKind kind;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool enabled;

  /// Runs the thing. The palette closes first, so a dialog opened here is not
  /// stacked behind one that is on its way out.
  final void Function(BuildContext context) run;
}

@visibleForTesting
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, this.songs, this.media});

  /// Injected by tests. In the app these come from the repositories.
  final List<Song>? songs;
  final List<MediaItem>? media;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  var _cursor = 0;

  List<Song> _songs = const [];
  List<MediaItem> _media = const [];

  @override
  void initState() {
    super.initState();
    _songs = widget.songs ?? const [];
    _media = widget.media ?? const [];
    if (widget.songs == null) _loadLibrary();
    _query.addListener(() => setState(() => _cursor = 0));
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Songs and media, once, when the palette opens.
  ///
  /// A church with no internet still gets the actions, the designs and the
  /// Bible, which are all on this machine.
  Future<void> _loadLibrary() async {
    try {
      final songs = await Modular.get<SongsListRepository>().getSongs();
      if (mounted) setState(() => _songs = songs);
    } catch (_) {
      // No network. The rest of the palette still works.
    }
    try {
      final media = await Modular.get<MediaRepository>().listMedia();
      if (mounted) setState(() => _media = media);
    } catch (_) {
      // Same.
    }
  }

  ControlModel? get _model {
    final state = context.read<ControlCubit>().state;
    return state is ControlLoadedState ? state.model : null;
  }

  bool get _hasService => _model?.activeCollection != null;

  List<PaletteResult> _results(L10n t) {
    final query = _query.text.trim();
    final control = context.read<ControlCubit>();
    final shell = context.read<ShellCubit>();
    final model = _model;

    final results = <PaletteResult>[];

    // A typed reference wins the top of the list: somebody who writes "jn 3:16"
    // wants the passage, not a song whose title happens to contain a 3.
    final reference = parseBibleReference(query);
    if (reference.reference case final ref?) {
      results.add(
        PaletteResult(
          kind: ResultKind.bible,
          icon: Icons.menu_book_outlined,
          title: t.searchAddPassage('$ref'),
          enabled: _hasService,
          // Handed to the dialog that already knows how to look a passage up
          // and what to say when a chapter does not exist.
          run: (context) => showQuickVerseDialog(context, initial: query),
        ),
      );
    }

    for (final action in _actions(t, control, shell, model)) {
      if (matchScore(query, action.title) != null) results.add(action);
    }

    results.addAll(
      // The author counts as part of the name: "todas las de Un Corazón" is a
      // real way people look for a song.
      rankByMatch(query, _songs, (song) => '${song.title} ${song.author ?? ''}')
          .take(8)
          .map(
            (song) => PaletteResult(
              kind: ResultKind.song,
              icon: Icons.music_note_outlined,
              title: song.title,
              subtitle: song.author,
              enabled: _hasService,
              run: (_) => control.addSong(song),
            ),
          ),
    );

    final designs = [...SlideTemplate.presets, ...?model?.userTemplates];
    results.addAll(
      rankByMatch(query, designs, (design) => design.name)
          .take(5)
          .map(
            (design) => PaletteResult(
              kind: ResultKind.design,
              icon: Icons.palette_outlined,
              title: design.name,
              subtitle: t.searchApplyDesign,
              enabled: _hasService,
              run: (_) => control.setCollectionTemplate(model!.activeCollection!.id, design.id),
            ),
          ),
    );

    results.addAll(
      rankByMatch(query, _media, (item) => item.name)
          .take(5)
          .map(
            (item) => PaletteResult(
              kind: ResultKind.media,
              icon: item.mediaType.isImage ? Icons.image_outlined : Icons.movie_outlined,
              title: item.name,
              subtitle: item.sizeLabel,
              enabled: _hasService,
              run: (_) => item.mediaType.isImage
                  ? control.addImageSlide(item.url, title: item.name)
                  : control.importVideo(item.url),
            ),
          ),
    );

    return results;
  }

  /// The controls of the live bar, reachable by name.
  List<PaletteResult> _actions(
    L10n t,
    ControlCubit control,
    ShellCubit shell,
    ControlModel? model,
  ) => [
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.podcasts_rounded,
      title: model?.isLive == true ? t.tipLiveOff : t.tipLiveOn,
      run: (_) => control.toggleLive(),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.visibility_off_outlined,
      title: t.tipBlank,
      run: (_) => control.toggleBlank(),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.campaign_outlined,
      title: t.tipNotices,
      run: showNoticesDialog,
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.library_music_outlined,
      title: '${t.tipLibraryShow} · ${t.tabSongs}',
      run: (_) => shell.openLibrary(LibraryTab.songs),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.menu_book_outlined,
      title: '${t.tipLibraryShow} · ${t.tabBible}',
      run: (_) => shell.openLibrary(LibraryTab.bible),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.present_to_all_outlined,
      title: t.tipProjector,
      run: (_) => control.openDisplayWindow(),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.co_present_outlined,
      title: t.tipStage,
      run: (_) => control.openStageMonitor(),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.grid_view_rounded,
      title: model?.gridView == true ? t.bigSlideView : t.gridView,
      run: (_) => control.toggleGridView(),
    ),
    PaletteResult(
      kind: ResultKind.action,
      icon: Icons.link_rounded,
      title: model?.followCursor == true ? t.tipFollowOff : t.tipFollowOn,
      run: (_) => control.toggleFollowCursor(),
    ),
  ];

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _cursor = (_cursor + by).clamp(0, count - 1));
    // Keep the highlighted row in view when the list is longer than the box.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (_cursor * _rowHeight - 120).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  static const _rowHeight = 52.0;

  void _choose(PaletteResult result) {
    if (!result.enabled) return;
    Navigator.pop(context);
    result.run(context);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event, int count) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1, count);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1, count);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final results = _results(t);
    final cursor = results.isEmpty ? 0 : _cursor.clamp(0, results.length - 1);

    return Align(
      // Near the top, where a palette belongs: the operator's eyes are already
      // on the set list and a centred box would cover it.
      alignment: const Alignment(0, -0.62),
      child: Focus(
        onKeyEvent: (node, event) => _onKey(node, event, results.length),
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.all(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 620,
            decoration: BoxDecoration(
              borderRadius: AppRadius.all(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(controller: _query, onSubmit: () => _submit(results, cursor)),
                const Divider(height: 1),
                if (results.isEmpty)
                  _Empty(query: _query.text.trim(), t: t)
                else
                  // Capped, not Flexible alone: with an empty query the whole
                  // library is a result, and a box that grows to the height of
                  // the window is not a palette.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                      itemCount: results.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (context, index) => _Row(
                        result: results[index],
                        label: _groupLabel(t, results[index].kind),
                        selected: index == cursor,
                        onTap: () => _choose(results[index]),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                _Footer(t: t, needsService: !_hasService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(List<PaletteResult> results, int cursor) {
    if (results.isEmpty) return;
    _choose(results[cursor]);
  }

  static String _groupLabel(L10n t, ResultKind kind) => switch (kind) {
    ResultKind.action => t.groupActions,
    ResultKind.bible => t.groupBible,
    ResultKind.song => t.groupSongs,
    ResultKind.media => t.groupMedia,
    ResultKind.design => t.groupDesigns,
  };
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: t.searchHint,
                hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.result,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PaletteResult result;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dim = !result.enabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Material(
        color: selected ? AppColors.accentFill : Colors.transparent,
        borderRadius: AppRadius.all(AppRadius.md),
        child: InkWell(
          onTap: result.enabled ? onTap : null,
          borderRadius: AppRadius.all(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
            child: Row(
              children: [
                Icon(
                  result.icon,
                  size: 17,
                  color: dim
                      ? AppColors.textDisabled
                      : selected
                      ? AppColors.accentLight
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: dim ? AppColors.textDisabled : AppColors.textPrimary,
                        ),
                      ),
                      if (result.subtitle?.isNotEmpty == true)
                        Text(
                          result.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppColors.textTertiary,
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

class _Empty extends StatelessWidget {
  const _Empty({required this.query, required this.t});

  final String query;
  final L10n t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: AppSpace.lg),
    child: Text(
      t.searchNothing(query),
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.t, required this.needsService});

  final L10n t;
  final bool needsService;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            needsService ? t.searchOpenServiceFirst : t.searchHintKeys,
            style: TextStyle(
              fontSize: 11,
              color: needsService ? AppColors.warning : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    ),
  );
}
