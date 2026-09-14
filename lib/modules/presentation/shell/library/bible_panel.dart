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
import '../../../../core/widgets/ui/empty_state.dart';
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
                  onAction: () => showBibleVersionsDialog(context),
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
                    icon: Icons.cloud_download_outlined,
                    tooltip: L10n.of(context).bibleManageVersions,
                    size: 26,
                    iconSize: 15,
                    onTap: () => showBibleVersionsDialog(context),
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
      buildWhen: (a, b) => a.filteredBooks != b.filteredBooks,
      builder: (context, state) {
        if (state.filteredBooks.isEmpty) {
          return EmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: L10n.of(context).bibleNoBookMatches,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          itemCount: state.filteredBooks.length,
          itemBuilder: (_, i) {
            final book = state.filteredBooks[i];
            return _BibleRow(
              label: book.displayName,
              trailing: '${book.book.chapterCount}',
              onTap: () => context.read<BibleBrowserCubit>().selectBook(book),
            );
          },
        );
      },
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

class _VersesList extends StatelessWidget {
  const _VersesList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BibleBrowserCubit, BibleBrowserState>(
      buildWhen: (a, b) =>
          a.verses != b.verses ||
          a.selectedVerse != b.selectedVerse ||
          a.selectedVerseEnd != b.selectedVerseEnd,
      builder: (context, state) {
        final start = state.selectedVerse;
        final end = state.selectedVerseEnd ?? start;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          itemCount: state.verses.length,
          itemBuilder: (_, i) {
            final number = i + 1;
            final selected = start != null && end != null && number >= start && number <= end;

            return GestureDetector(
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
          },
        );
      },
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
              _AddPassageButton(reference: reference, count: count),
            ],
          ),
        );
      },
    );
  }
}

class _AddPassageButton extends StatelessWidget {
  const _AddPassageButton({required this.reference, required this.count});

  final String reference;
  final int count;

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
                  await control.addBibleVerse(ref);
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
