import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'package:intl/intl.dart';

import '../../../core/bible_import/bible_files.dart';
import '../../../core/bible_import/version_naming.dart';
import '../../../core/local_db/bible_import_service.dart' show bundledBibleCode;
import '../../../core/local_db/bible_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../l10n/l10n.dart';
import 'bible_versions_cubit.dart';

/// The Bibles on this computer, and importing one from a file. Returns whether
/// the list changed, so whoever opened it can read the versions again.
Future<bool> showBibleVersionsDialog(BuildContext context) async {
  final cubit = BibleVersionsCubit(Modular.get<BibleRepository>())..load();
  await showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(value: cubit, child: const BibleVersionsDialog()),
  );
  final changed = cubit.changed;
  await cubit.close();
  return changed;
}

@visibleForTesting
class BibleVersionsDialog extends StatelessWidget {
  const BibleVersionsDialog({super.key, this.pickFile});

  /// Stands in for the system picker in tests.
  final Future<String?> Function()? pickFile;

  Future<void> _import(BibleVersionsCubit cubit) async {
    final path = pickFile != null
        ? await pickFile!()
        : (await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: bibleFileExtensions,
          ))?.files.firstOrNull?.path;
    if (path == null) return;
    await cubit.open(path);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BibleVersionsCubit>();
    return BlocBuilder<BibleVersionsCubit, BibleVersionsState>(
      builder: (context, state) {
        final busy = state is BibleVersionsReading || state is BibleVersionsSaving;
        return AppDialog(
          title: L10n.of(context).bibleVersionsTitle,
          icon: Icons.menu_book_outlined,
          width: 520,
          showClose: !busy,
          contentPadding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state is BibleVersionsLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpace.xl),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Flexible(
                  child: _VersionList(
                    versions: state.model.versions,
                    added: state is BibleVersionsIdle ? state.added : null,
                    enabled: !busy,
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              switch (state) {
                BibleVersionsReview() => _Review(key: ValueKey(state.bible.source), state: state),
                BibleVersionsReading() => _Working(L10n.of(context).bibleImportReading),
                BibleVersionsSaving(:final name) => _Working(
                  L10n.of(context).bibleImportSaving(name),
                ),
                BibleVersionsIdle(:final problem, :final detail) => _ImportButton(
                  problem: problem,
                  detail: detail,
                  onPressed: () => _import(cubit),
                ),
                BibleVersionsLoading() => const SizedBox.shrink(),
              },
              const SizedBox(height: AppSpace.md),
              const _Note(),
            ],
          ),
        );
      },
    );
  }
}

// ── Versions ──────────────────────────────────────────────────────────────────

class _VersionList extends StatelessWidget {
  const _VersionList({required this.versions, required this.added, required this.enabled});

  final List<InstalledBible> versions;
  final String? added;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: versions.length,
      separatorBuilder: (_, _) => const Divider(color: kDialogBorder, height: AppSpace.lg),
      itemBuilder: (_, i) => _VersionRow(
        version: versions[i],
        highlighted: versions[i].code == added,
        enabled: enabled,
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.version, required this.highlighted, required this.enabled});

  final InstalledBible version;
  final bool highlighted;
  final bool enabled;

  Future<void> _delete(BuildContext context) async {
    final t = L10n.of(context);
    final cubit = context.read<BibleVersionsCubit>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: t.bibleVersionDeleteTitle(version.name),
      message: t.bibleVersionDeleteMessage,
      confirmLabel: t.delete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed) await cubit.delete(version.code);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: AppRadius.all(AppRadius.md),
            border: highlighted ? Border.all(color: AppColors.success) : null,
          ),
          child: Icon(
            Icons.menu_book_rounded,
            size: 18,
            color: version.complete ? AppColors.success : AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(version.name, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    version.bundled ? t.bibleVersionBundled(version.code) : version.code,
                    style: AppText.rowSubtitle,
                  ),
                  if (!version.complete) ...[
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      t.bibleVersionIncomplete,
                      style: AppText.rowSubtitle.copyWith(color: AppColors.warning),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (version.bundled)
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
        else ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textTertiary),
            tooltip: t.bibleVersionRename,
            onPressed: enabled ? () => _rename(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: t.delete,
            onPressed: enabled ? () => _delete(context) : null,
          ),
        ],
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<BibleVersionsCubit>();
    final result = await showDialog<({String name, String code})>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _RenameDialog(version: version),
      ),
    );
    if (result != null) await cubit.rename(version.code, name: result.name, newCode: result.code);
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.version});

  final InstalledBible version;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.version.name);
  late final _code = TextEditingController(text: widget.version.code);

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _code.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _valid => context.read<BibleVersionsCubit>().canRename(
    widget.version.code,
    name: _name.text,
    newCode: _code.text,
  );

  void _save() {
    if (_valid) Navigator.pop(context, (name: _name.text, code: _code.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final code = cleanVersionCode(_code.text);
    return AppDialog(
      title: t.bibleVersionRename,
      icon: Icons.edit_outlined,
      width: 420,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: _valid ? _save : null, child: Text(t.save)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: t.bibleImportName,
            hintText: t.bibleImportName,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _code,
            label: t.bibleImportCode,
            hintText: t.bibleImportCode,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(t.bibleImportCodeHelp(code.isEmpty ? '…' : code), style: AppText.rowSubtitle),
          if (!_valid && code.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              code == bundledBibleCode
                  ? t.bibleImportCodeTaken(code)
                  : t.bibleVersionCodeInUse(code),
              style: AppText.body.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Importing ─────────────────────────────────────────────────────────────────

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.problem, required this.detail, required this.onPressed});

  final BibleImportProblem? problem;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final message = switch (problem) {
      null => null,
      BibleImportProblem.unsupported => t.bibleImportUnsupported,
      BibleImportProblem.unreadable => t.bibleImportUnreadable,
      BibleImportProblem.empty => t.bibleImportEmpty,
      BibleImportProblem.notSaved => t.bibleImportNotSaved(detail ?? ''),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: Text(t.bibleImport),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(message, style: AppText.body.copyWith(color: AppColors.danger)),
        ],
      ],
    );
  }
}

class _Working extends StatelessWidget {
  const _Working(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(label, style: AppText.body, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// The Bible just read, with its name and code to confirm before it is saved.
class _Review extends StatefulWidget {
  const _Review({super.key, required this.state});

  final BibleVersionsReview state;

  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  late final _name = TextEditingController(text: widget.state.name);
  late final _code = TextEditingController(text: widget.state.code);

  /// The language the books are named in, on the screen and under a verse:
  /// what the file says or its words suggest, for the operator to correct.
  late String _language = widget.state.bible.probableLanguage;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _install() {
    if (!BibleVersionsCubit.canInstall(name: _name.text, code: _code.text)) return;
    context.read<BibleVersionsCubit>().install(
      name: _name.text,
      code: _code.text,
      language: _language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final bible = widget.state.bible;
    final code = cleanVersionCode(_code.text);
    final verses = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(bible.verseCount);

    final warnings = [
      if (code == bundledBibleCode) t.bibleImportCodeTaken(code),
      if (code != bundledBibleCode && widget.state.model.has(code)) t.bibleImportReplaces(code),
      if (bible.missingBooks > 0) t.bibleImportMissing(bible.missingBooks),
      if (bible.skippedBooks > 0) t.bibleImportSkipped(bible.skippedBooks),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.bibleImportSummary(bible.books.length, verses, bible.format.label),
            style: AppText.rowSubtitle,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: _name,
                  label: t.bibleImportName,
                  hintText: t.bibleImportName,
                  fillColor: AppColors.surface,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: AppTextField(
                  controller: _code,
                  label: t.bibleImportCode,
                  hintText: t.bibleImportCode,
                  fillColor: AppColors.surface,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _install(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(t.bibleImportCodeHelp(code.isEmpty ? '…' : code), style: AppText.rowSubtitle),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Text(t.bibleImportLanguage, style: AppText.rowSubtitle),
              const SizedBox(width: AppSpace.sm),
              for (final (code, label) in [
                ('es', t.bibleLanguageEs),
                ('en', t.bibleLanguageEn),
              ]) ...[
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: _language == code,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _language = code),
                ),
                const SizedBox(width: AppSpace.xs),
              ],
            ],
          ),
          for (final warning in warnings) ...[
            const SizedBox(height: AppSpace.sm),
            Text(warning, style: AppText.body.copyWith(color: AppColors.warning)),
          ],
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: context.read<BibleVersionsCubit>().cancel,
                child: Text(t.cancel),
              ),
              const SizedBox(width: AppSpace.sm),
              FilledButton(
                onPressed: BibleVersionsCubit.canInstall(name: _name.text, code: _code.text)
                    ? _install
                    : null,
                child: Text(t.import),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Note ──────────────────────────────────────────────────────────────────────

/// Why the church brings its own Bible, said where the button is.
class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            L10n.of(context).bibleImportNote,
            style: AppText.rowSubtitle.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}
