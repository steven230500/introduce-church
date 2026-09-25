import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/local_db/bible_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/bible_browser/bible_browser_cubit.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/app_search_field.dart';
import '../../../../core/services/app_prefs_service.dart';
import '../../../../core/widgets/ui/empty_state.dart';
import '../../../../core/widgets/ui/reveal_row.dart';
import '../../../../core/widgets/ui/verse_layout_toggle.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../bible_versions_dialog.dart';
import 'library_dock.dart';
import '../../../../l10n/l10n.dart';

/// Bible library: book, then chapter, then verse, with the add action pinned
/// to the bottom so the selection and the button are never far apart.
class BiblePanel extends StatelessWidget {
  const BiblePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BibleBrowserCubit(Modular.get<BibleRepository>())..load(),
      child: const _BiblePanelView(),
    );
  }
}

class _BiblePanelView extends StatelessWidget {
  const _BiblePanelView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _BibleToolbar(),
        Expanded(
          child: BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
            buildWhen: (a, b) => a.view != b.view || a.versions != b.versions,
            builder: (context, state) {
              if (state.versions.isEmpty) {
                return EmptyState(
                  compact: true,
                  icon: Icons.menu_book_outlined,
                  title: L10n.of(context).bibleNoVersionsTitle,
                  message: L10n.of(context).bibleNoVersionsMessage,
                  actionLabel: L10n.of(context).bibleVersions,
                  onAction: () => _manageVersions(context),
                );
              }
              return switch (state.view) {
                BibleBrowserView.books => const _BooksList(),
                BibleBrowserView.chapters => const _ChaptersGrid(),
                BibleBrowserView.verses => const _VersesList(),
              };
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const _BibleAddBar(),
      ],
    );
  }
}

/// Opens the versions dialog, and reads the list again if a version was
/// imported or removed there.
Future<void> _manageVersions(BuildContext context) async {
  final cubit = context.read<BibleBrowserCubit>();
  if (await showBibleVersionsDialog(context)) await cubit.load();
}

// ── Toolbar: breadcrumb, version, search ──────────────────────────────────────

class _BibleToolbar extends StatelessWidget {
  const _BibleToolbar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) =>
          a.view != b.view ||
          a.selectedBook != b.selectedBook ||
          a.selectedChapter != b.selectedChapter ||
          a.selectedVersion != b.selectedVersion ||
          a.versions != b.versions,
      builder: (context, state) {
        final cubit = context.read<BibleBrowserCubit>();
        return Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            children: [
              Row(
                children: [
                  if (state.view != BibleBrowserView.books)
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: L10n.of(context).back,
                      size: 26,
                      iconSize: 15,
                      onTap: cubit.goBack,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                      child: Text(
                        switch (state.view) {
                          BibleBrowserView.books => L10n.of(context).bibleBooks,
                          BibleBrowserView.chapters => state.selectedBook?.displayName ?? '',
                          BibleBrowserView.verses =>
                            '${state.selectedBook?.displayName ?? ''} ${state.selectedChapter ?? ''}',
                        },
                        style: AppText.panelTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (state.versions.isNotEmpty) _VersionPicker(state: state),
                  AppIconButton(
                    icon: Icons.library_books_outlined,
                    tooltip: L10n.of(context).bibleManageVersions,
                    size: 26,
                    iconSize: 15,
                    onTap: () => _manageVersions(context),
                  ),
                ],
              ),
              if (state.view == BibleBrowserView.books) ...[
                const SizedBox(height: AppSpace.sm),
                AppSearchField(
                  dense: true,
                  hintText: L10n.of(context).bibleSearchBook,
                  debounce: const Duration(milliseconds: 120),
                  onChanged: cubit.filterBooks,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VersionPicker extends StatelessWidget {
  const _VersionPicker({required this.state});

  final BibleBrowserState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm - 2),
      margin: const EdgeInsets.only(right: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.selectedVersion?.code,
          isDense: true,
          dropdownColor: AppColors.surfaceControl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
          icon: const Icon(Icons.expand_more, size: 14, color: AppColors.textMuted),
          items: state.versions
              .map((v) => DropdownMenuItem(value: v.code, child: Text(v.code)))
              .toList(),
          onChanged: (code) {
            if (code == null) return;
            final version = state.versions.firstWhere((v) => v.code == code);
            context.read<BibleBrowserCubit>().selectVersion(version);
          },
        ),
      ),
    );
  }
}

// ── Books ─────────────────────────────────────────────────────────────────────

class _BooksList extends StatelessWidget {
  const _BooksList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) => a.filteredBooks != b.filteredBooks || a.textHits != b.textHits,
      builder: (context, state) {
        final t = L10n.of(context);
        final cubit = context.read<BibleBrowserCubit>();
        if (state.filteredBooks.isEmpty && state.textHits.isEmpty) {
          return EmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: t.bibleNoBookMatches,
          );
        }
        final language = state.selectedVersion?.language;
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          children: [
            for (final book in state.filteredBooks)
              _BibleRow(
                label: book.displayName,
                trailing: '${book.book.chapterCount}',
                onTap: () => cubit.selectBook(book),
              ),
            if (state.textHits.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.xs,
                ),
                child: Text(t.bibleInTheText.toUpperCase(), style: AppText.sectionLabel),
              ),
              for (final hit in state.textHits)
                _VerseHitRow(
                  reference:
                      '${bookName(hit.bookIndex, language: language, inReference: true)} '
                      '${hit.chapter}:${hit.verse}',
                  text: hit.text,
                  onTap: () => cubit.openHit(hit),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// A verse found by its words: where it is, and the words themselves.
class _VerseHitRow extends StatelessWidget {
  const _VerseHitRow({required this.reference, required this.text, required this.onTap});

  final String reference;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reference, style: AppText.rowTitle),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BibleRow extends StatelessWidget {
  const _BibleRow({required this.label, required this.onTap, this.trailing});

  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm + 1),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) Text(trailing!, style: AppText.rowSubtitle),
          ],
        ),
      ),
    );
  }
}

// ── Chapters ──────────────────────────────────────────────────────────────────

class _ChaptersGrid extends StatelessWidget {
  const _ChaptersGrid();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) => a.chapters != b.chapters || a.selectedChapter != b.selectedChapter,
      builder: (context, state) {
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpace.sm),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: AppSpace.xs + 2,
            mainAxisSpacing: AppSpace.xs + 2,
            childAspectRatio: 1,
          ),
          itemCount: state.chapters.length,
          itemBuilder: (_, i) {
            final chapter = state.chapters[i];
            final selected = state.selectedChapter == chapter;
            return GestureDetector(
              onTap: () => context.read<BibleBrowserCubit>().selectChapter(chapter),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.surfaceControl,
                  borderRadius: AppRadius.all(AppRadius.sm),
                ),
                child: Text(
                  '$chapter',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Verses ────────────────────────────────────────────────────────────────────

class _VersesList extends StatefulWidget {
  const _VersesList();

  @override
  State<_VersesList> createState() => _VersesListState();
}

class _VersesListState extends State<_VersesList> {
  /// The row of a verse opened from a search, to bring into view once drawn.
  final _reveal = GlobalKey();
  final _scroll = ScrollController();
  int? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _bringIntoView(int? verse, List<int> present) {
    if (verse == null || verse == _revealed) return;
    _revealed = verse;
    final at = present.indexOf(verse - 1);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => revealRow(key: _reveal, controller: _scroll, at: at, count: present.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) =>
          a.verses != b.verses ||
          a.selectedVerse != b.selectedVerse ||
          a.selectedVerseEnd != b.selectedVerseEnd ||
          a.revealVerse != b.revealVerse,
      builder: (context, state) {
        final start = state.selectedVerse;
        final end = state.selectedVerseEnd ?? start;

        // A verse the imported file does not have is not listed, and the ones
        // after it keep their numbers.
        final present = [
          for (var i = 0; i < state.verses.length; i++)
            if (state.verses[i].trim().isNotEmpty) i,
        ];

        _bringIntoView(state.revealVerse, present);

        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          children: [for (final i in present) _row(context, state, i, start, end)],
        );
      },
    );
  }

  Widget _row(BuildContext context, BibleBrowserState state, int i, int? start, int? end) {
    final number = i + 1;
    final selected = start != null && end != null && number >= start && number <= end;

    return GestureDetector(
      key: number == state.revealVerse ? _reveal : null,
      onTap: () => context.read<BibleBrowserCubit>().selectVerse(number),
      child: Container(
        color: selected ? AppColors.accentFillSoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$number',
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                state.verses[i],
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add bar ───────────────────────────────────────────────────────────────────

class _BibleAddBar extends StatelessWidget {
  const _BibleAddBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) =>
          a.canConfirm != b.canConfirm ||
          a.selectedVerse != b.selectedVerse ||
          a.selectedVerseEnd != b.selectedVerseEnd,
      builder: (context, state) {
        if (!state.canConfirm) {
          return Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: Text(
              L10n.of(context).bibleTapVerse,
              style: AppText.rowSubtitle,
              textAlign: TextAlign.center,
            ),
          );
        }

        final start = state.selectedVerse!;
        final end = state.selectedVerseEnd ?? start;
        final count = end - start + 1;
        final reference = count > 1
            ? '${state.selectedBook?.displayName} ${state.selectedChapter}:$start-$end'
            : '${state.selectedBook?.displayName} ${state.selectedChapter}:$start';

        return Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(reference, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpace.sm),
              _PassageActions(reference: reference, count: count),
            ],
          ),
        );
      },
    );
  }
}

/// The choice of how the passage is projected, and the button that adds it.
class _PassageActions extends StatefulWidget {
  const _PassageActions({required this.reference, required this.count});

  final String reference;
  final int count;

  @override
  State<_PassageActions> createState() => _PassageActionsState();
}

class _PassageActionsState extends State<_PassageActions> {
  /// Null in a test that pumps the panel on its own.
  final _prefs = Modular.tryGet<AppPrefsService>();
  bool _together = false;

  @override
  void initState() {
    super.initState();
    _prefs?.versesTogether().then((value) {
      if (mounted) setState(() => _together = value);
    });
  }

  void _choose(bool together) {
    setState(() => _together = together);
    unawaited(_prefs?.setVersesTogether(together) ?? Future.value());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One verse has nothing to join, so the choice only appears when it
        // changes something.
        if (widget.count > 1) ...[
          VerseLayoutToggle(together: _together, onChanged: _choose),
          const SizedBox(height: AppSpace.sm),
        ],
        Row(
          children: [
            Expanded(child: _ProjectPassageButton(together: _together)),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: _AddPassageButton(count: widget.count, together: _together),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddPassageButton extends StatelessWidget {
  const _AddPassageButton({required this.count, required this.together});

  final int count;
  final bool together;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      buildWhen: (a, b) => _hasTarget(a) != _hasTarget(b),
      builder: (context, controlState) {
        final enabled = _hasTarget(controlState);
        return FilledButton.icon(
          onPressed: !enabled
              ? null
              : () async {
                  final browser = context.read<BibleBrowserCubit>();
                  final control = context.read<ControlCubit>();
                  final ref = await browser.buildVerseRef();
                  if (ref == null || !context.mounted) return;
                  await control.addBibleVerse(ref, together: together);
                  if (!context.mounted) return;
                  showAddedToast(context, ref.reference);
                },
          icon: const Icon(Icons.playlist_add_rounded, size: 16),
          label: Text(
            L10n.of(context).bibleAddPassage(count),
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  static bool _hasTarget(ControlState s) =>
      s is ControlLoadedState && s.model.activeCollection != null;
}

/// Sends the passage to the screen and leaves the service alone. This is the
/// button for the verse the pastor asks for in the middle of the sermon.
class _ProjectPassageButton extends StatelessWidget {
  const _ProjectPassageButton({required this.together});

  final bool together;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).looseHint,
      child: OutlinedButton.icon(
        onPressed: () async {
          final browser = context.read<BibleBrowserCubit>();
          final control = context.read<ControlCubit>();
          final ref = await browser.buildVerseRef();
          if (ref == null) return;
          control.projectLoose(ref, together: together);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        ),
        icon: const Icon(Icons.present_to_all_rounded, size: 16),
        label: Text(L10n.of(context).bibleProject, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
