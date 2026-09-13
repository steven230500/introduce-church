import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'package:path/path.dart' as p;

import '../../../core/models/song.dart';
import '../../../core/song_import/imported_song.dart';
import '../../../core/song_import/song_files.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../l10n/l10n.dart';
import '../children/songs_list/repository/repository.dart';
import 'song_import_cubit.dart';

/// Brings songs over from other programs. Returns how many were added.
Future<int> showSongImportDialog(BuildContext context) async {
  final cubit = SongImportCubit(Modular.get<SongsListRepository>());
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(value: cubit, child: const SongImportDialog()),
  );
  final state = cubit.state;
  await cubit.close();
  return state is SongImportDone ? state.imported : 0;
}

@visibleForTesting
class SongImportDialog extends StatelessWidget {
  const SongImportDialog({super.key, this.pickFiles, this.pickFolder});

  /// Stand in for the system pickers in tests.
  final Future<List<String>?> Function()? pickFiles;
  final Future<String?> Function()? pickFolder;

  Future<void> _files(SongImportCubit cubit) async {
    final paths = pickFiles != null
        ? await pickFiles!()
        : (await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: songFileExtensions,
            allowMultiple: true,
          ))?.files.map((f) => f.path).whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    await cubit.openFiles(paths);
  }

  Future<void> _folder(SongImportCubit cubit) async {
    final directory = pickFolder != null
        ? await pickFolder!()
        : await FilePicker.platform.getDirectoryPath();
    if (directory == null) return;
    await cubit.openFolder(directory);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<SongImportCubit>();
    return BlocBuilder<SongImportCubit, SongImportState>(
      builder: (context, state) {
        final busy = state is SongImportReading || state is SongImportSaving;
        return AppDialog(
          title: t.importTitle,
          icon: Icons.library_add_outlined,
          width: 920,
          height: 620,
          showClose: !busy,
          actions: switch (state) {
            SongImportIdle() => [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
            ],
            SongImportReview() => [
              TextButton(onPressed: cubit.startOver, child: Text(t.importPickOther)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
              const SizedBox(width: AppSpace.sm),
              FilledButton(
                onPressed: state.selectedCount == 0 ? null : cubit.import,
                child: Text(t.importAction(state.selectedCount)),
              ),
            ],
            SongImportDone() => [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.importDoneAction),
              ),
            ],
            _ => null,
          },
          child: switch (state) {
            SongImportIdle() => _Start(
              onFiles: () => _files(cubit),
              onFolder: () => _folder(cubit),
            ),
            SongImportReading(:final done, :final total) => _Progress(
              label: t.importReading(done, total),
              value: total == 0 ? null : done / total,
            ),
            SongImportReview() when state.candidates.isEmpty => _Nothing(failures: state.failures),
            SongImportReview() => _Review(state: state),
            SongImportSaving(:final done, :final total) => _Progress(
              label: t.importSaving(done, total),
              value: total == 0 ? null : done / total,
            ),
            SongImportDone() => _Done(state: state),
          },
        );
      },
    );
  }
}

// ── Start ─────────────────────────────────────────────────────────────────────

class _Start extends StatelessWidget {
  const _Start({required this.onFiles, required this.onFolder});

  final VoidCallback onFiles;
  final VoidCallback onFolder;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final formats = [
      ('ProPresenter 7', '.pro', t.importWherePro7),
      ('ProPresenter 4–6', '.pro6 · .pro5 · .pro4', t.importWherePro6),
      ('OpenLP · OpenLyrics', '.xml', t.importWhereOpenLyrics),
      ('SongSelect (CCLI)', '.usr · .bin · .txt', t.importWhereSongSelect),
      ('ChordPro', '.cho · .chordpro', t.importWhereChordPro),
      (t.formatText, '.txt', t.importWhereText),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.importIntro, style: AppText.body),
        const SizedBox(height: AppSpace.xl),
        Expanded(
          // A fixed height rather than a proportion: the cards hold two lines
          // of advice, and a ratio made them too short for it at the narrowest
          // window the app allows.
          child: GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpace.md,
              mainAxisSpacing: AppSpace.md,
              mainAxisExtent: 124,
            ),
            children: [
              for (final (name, extensions, where) in formats)
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: AppRadius.all(AppRadius.md),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        extensions,
                        style: const TextStyle(fontSize: 12, color: AppColors.accentLight),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        where,
                        style: AppText.rowSubtitle.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onFiles,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(t.importPickFiles),
            ),
            const SizedBox(width: AppSpace.md),
            FilledButton.tonalIcon(
              onPressed: onFolder,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text(t.importPickFolder),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.body),
          const SizedBox(height: AppSpace.md),
          LinearProgressIndicator(value: value, minHeight: 4),
        ],
      ),
    ),
  );
}

// ── Review ────────────────────────────────────────────────────────────────────

class _Review extends StatelessWidget {
  const _Review({required this.state});

  final SongImportReview state;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<SongImportCubit>();
    final inLibrary = state.count(ImportStatus.inLibrary);
    final summary = [
      t.importFound(state.candidates.length),
      t.importFresh(state.count(ImportStatus.fresh)),
      if (inLibrary > 0) t.importInLibrary(inLibrary),
      if (state.count(ImportStatus.repeated) > 0)
        t.importRepeated(state.count(ImportStatus.repeated)),
    ].join('  ·  ');
    final includingExisting =
        inLibrary > 0 &&
        state.candidates.where((c) => c.status == ImportStatus.inLibrary).every((c) => c.selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(summary, style: AppText.body)),
            if (inLibrary > 0)
              Row(
                children: [
                  Checkbox(
                    value: includingExisting,
                    onChanged: (v) => cubit.selectWhere(ImportStatus.inLibrary, v ?? false),
                  ),
                  Text(t.importIncludeExisting, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: AppRadius.all(AppRadius.md),
                  ),
                  child: ListView(
                    children: [
                      for (final (index, candidate) in state.candidates.indexed)
                        _CandidateRow(
                          candidate: candidate,
                          previewing: index == state.previewing,
                          onToggle: () => cubit.toggle(index),
                          onPreview: () => cubit.preview(index),
                        ),
                      if (state.failures.isNotEmpty) _Failures(failures: state.failures),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(flex: 4, child: _Preview(song: state.candidates[state.previewing].song)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.previewing,
    required this.onToggle,
    required this.onPreview,
  });

  final ImportCandidate candidate;
  final bool previewing;
  final VoidCallback onToggle;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final song = candidate.song;
    final details = [
      ?song.author,
      t.importSlides(song.verses.length),
      formatName(t, song.format),
    ].join('  ·  ');
    return Material(
      color: previewing ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
          child: Row(
            children: [
              Checkbox(value: candidate.selected, onChanged: (_) => onToggle()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                    Text(details, style: AppText.rowSubtitle, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (candidate.status != ImportStatus.fresh)
                Container(
                  margin: const EdgeInsets.only(right: AppSpace.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        (candidate.status == ImportStatus.inLibrary
                                ? AppColors.warning
                                : AppColors.textMuted)
                            .withValues(alpha: 0.18),
                    borderRadius: AppRadius.all(AppRadius.xs),
                  ),
                  child: Text(
                    candidate.status == ImportStatus.inLibrary
                        ? t.importStatusInLibrary
                        : t.importStatusRepeated,
                    style: TextStyle(
                      fontSize: 11,
                      color: candidate.status == ImportStatus.inLibrary
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.song});

  final ImportedSong song;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final credits = [?song.copyright, if (song.ccliNumber != null) t.importCcli(song.ccliNumber!)];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Text(song.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (song.author != null) Text(song.author!, style: AppText.body),
          if (credits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(credits.join('  ·  '), style: AppText.rowSubtitle),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: AppSpace.md),
            child: Text(
              p.basename(song.source),
              style: AppText.rowSubtitle.copyWith(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final verse in song.verses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verse.type.label.toUpperCase(),
                    style: AppText.sectionLabel.copyWith(
                      color: verse.type == VerseType.chorus ? AppColors.accentLight : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(verse.content, style: const TextStyle(fontSize: 13, height: 1.35)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Failures extends StatelessWidget {
  const _Failures({required this.failures});

  final List<SongFileFailure> failures;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ExpansionTile(
      dense: true,
      leading: const Icon(Icons.error_outline, size: 18, color: AppColors.warning),
      title: Text(t.importFailures(failures.length), style: const TextStyle(fontSize: 13)),
      children: [
        for (final failure in failures)
          ListTile(
            dense: true,
            title: Text(p.basename(failure.source), style: const TextStyle(fontSize: 12)),
            subtitle: Text(problemText(t, failure.problem), style: AppText.rowSubtitle),
          ),
      ],
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.failures});

  final List<SongFileFailure> failures;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.xl),
        const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
        const SizedBox(height: AppSpace.md),
        Text(t.importNothing, style: AppText.body, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.lg),
        if (failures.isNotEmpty)
          Expanded(
            child: ListView(children: [_Failures(failures: failures)]),
          ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.state});

  final SongImportDone state;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final stopped = state.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.xl),
        Icon(
          stopped ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 44,
          color: stopped ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          t.importDone(state.imported),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (stopped)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
            child: Text(
              t.importStopped(state.error!),
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        if (state.failures.isNotEmpty)
          Expanded(
            child: ListView(children: [_Failures(failures: state.failures)]),
          ),
      ],
    );
  }
}

String formatName(L10n t, SongFormat format) => switch (format) {
  SongFormat.proPresenter7 => 'ProPresenter 7',
  SongFormat.proPresenter6 => 'ProPresenter 6',
  SongFormat.openLyrics => 'OpenLyrics',
  SongFormat.songSelect => 'SongSelect',
  SongFormat.chordPro => 'ChordPro',
  SongFormat.plainText => t.formatText,
};

String problemText(L10n t, SongFileProblem problem) => switch (problem) {
  SongFileProblem.unsupported => t.importProblemUnsupported,
  SongFileProblem.unreadable => t.importProblemUnreadable,
  SongFileProblem.empty => t.importProblemEmpty,
};
