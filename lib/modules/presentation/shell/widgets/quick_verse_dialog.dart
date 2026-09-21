import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/local_db/app_database.dart' show BibleVersion;
import '../../../../core/local_db/bible_reference.dart';
import '../../../../core/local_db/bible_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/services/app_prefs_service.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/verse_layout_toggle.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../../../../l10n/l10n.dart';

/// Puts a passage on deck from a line of text.
///
/// The preacher says where to go and the operator has a few seconds. Browsing
/// there is a book list, a chapter grid and a verse list, all while the room
/// waits. This is one line and Enter.
Future<void> showQuickVerseDialog(
  BuildContext context, {
  BibleRepository? repository,
  String? initial,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ControlCubit>(),
      child: QuickVerseDialog(repository: repository, initial: initial),
    ),
  );
}

@visibleForTesting
class QuickVerseDialog extends StatefulWidget {
  const QuickVerseDialog({super.key, this.repository, this.initial});

  /// Injected by tests. In the app it comes from the injector.
  final BibleRepository? repository;

  /// A reference the operator already typed somewhere else, so they do not
  /// type it twice.
  final String? initial;

  @override
  State<QuickVerseDialog> createState() => _QuickVerseDialogState();
}

class _QuickVerseDialogState extends State<QuickVerseDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');
  final _field = FocusNode(debugLabel: 'quick verse');
  late final _repository = widget.repository ?? Modular.get<BibleRepository>();

  ReferenceResult _parsed = (reference: null, problem: ReferenceProblem.empty, typed: null);
  String? _failure;
  bool _busy = false;

  /// The words of the passage being typed, so the operator reads it here
  /// before the congregation reads it on the wall. A wrong reference used to
  /// be found out by the whole room at once.
  String? _preview;
  int _previewCount = 0;

  /// The version the preview was read in, which is the one that will go out.
  String _previewVersion = '';
  String _previewOf = '';
  Timer? _previewDebounce;

  /// Null in a test that pumps this dialog on its own.
  final _prefs = Modular.tryGet<AppPrefsService>();

  /// The versions on this computer, and the one this passage goes out in.
  /// Chosen here, it is remembered: the next passage is in the same one.
  List<BibleVersion> _versions = const [];
  BibleVersion? _version;

  Future<BibleVersion?> _currentVersion() async => _version ?? await _repository.preferredVersion();

  void _chooseVersion(String code) {
    final version = _versions.where((v) => v.code == code).firstOrNull;
    if (version == null) return;
    setState(() {
      _version = version;
      _previewOf = '';
    });
    unawaited(_repository.rememberVersion(code));
    _schedulePreview();
  }

  /// The whole passage on one slide. Remembered from the last time.
  bool _together = false;

  void _chooseLayout(bool together) {
    setState(() => _together = together);
    unawaited(_prefs?.setVersesTogether(together) ?? Future.value());
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reparse);
    _prefs?.versesTogether().then((value) {
      if (mounted) setState(() => _together = value);
    });
    unawaited(() async {
      final versions = await _repository.getVersions();
      final preferred = await _repository.preferredVersion();
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _version = preferred;
      });
    }());
    // A reference handed in from the palette is already a reference; show its
    // verdict without waiting for a keystroke.
    if (widget.initial?.isNotEmpty == true) _reparse();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _field.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Books whose name starts with what was typed, for a line that does not
  /// name one book yet: "cor" is two letters away from two different books.
  List<int> get _bookChoices {
    final problem = _parsed.problem;
    if (problem != ReferenceProblem.ambiguous && problem != ReferenceProblem.noChapter) {
      return const [];
    }
    final typed = _parsed.typed ?? '';
    // "1 co 13" carries the chapter along; the book is what comes before it.
    final book = typed.replaceAll(RegExp(r'\s*\d{1,3}\s*$'), '').trim();
    final matches = booksMatching(book.isEmpty ? typed : book);
    return matches.length > 1 || problem == ReferenceProblem.noChapter
        ? matches.take(6).toList()
        : const [];
  }

  void _chooseBook(int index) {
    final name = spanishBookName(index);
    _controller.value = TextEditingValue(
      text: '$name ',
      selection: TextSelection.collapsed(offset: name.length + 1),
    );
    // Picking the book is half the line; the chapter is typed straight after,
    // so the caret goes back to the field rather than staying on the chip.
    // Returning focus selects what is there, and the next keystroke would
    // wipe the book out, so the caret is put back at the end afterwards.
    _field.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    });
  }

  /// Reads the passage a beat after the typing stops, so a reference on its
  /// way to "1 co 13:4" does not send four lookups.
  void _schedulePreview() {
    _previewDebounce?.cancel();
    final reference = _parsed.reference;
    if (reference == null) {
      _preview = null;
      _previewOf = '';
      return;
    }
    if ('$reference' == _previewOf) return;
    _previewDebounce = Timer(const Duration(milliseconds: 200), () => unawaited(_loadPreview()));
  }

  Future<void> _loadPreview() async {
    final reference = _parsed.reference;
    if (reference == null) return;
    final key = '$reference';
    try {
      final version = await _currentVersion();
      if (version == null) return;
      final verses = await _repository.getVerses(
        version.code,
        reference.bookIndex,
        reference.chapter,
      );
      if (verses.isEmpty || !mounted) return;
      final start = (reference.verseStart ?? 1).clamp(1, verses.length);
      final end = (reference.verseEnd ?? reference.verseStart ?? verses.length).clamp(
        start,
        verses.length,
      );
      setState(() {
        _preview = verses.sublist(start - 1, end).where((v) => v.trim().isNotEmpty).join(' ');
        _previewCount = end - start + 1;
        _previewVersion = version.code;
        _previewOf = key;
      });
    } catch (_) {
      // The preview is a courtesy; a failure here must not stop the add.
    }
  }

  void _reparse() {
    setState(() {
      _parsed = parseBibleReference(_controller.text);
      _failure = null;
    });
    _schedulePreview();
  }

  /// Adds the passage to the service, or only puts it on the screen.
  Future<void> _submit({bool project = false}) async {
    final reference = _parsed.reference;
    if (reference == null || _busy) return;

    final cubit = context.read<ControlCubit>();
    setState(() => _busy = true);

    try {
      final version = await _currentVersion();
      if (version == null) {
        setState(() {
          _busy = false;
          _failure = L10n.of(context).quickVerseNoBible;
        });
        return;
      }

      // A chapter on its own means all of it, and how long it is depends on
      // the chapter, so it has to be read before the range can be asked for.
      var start = reference.verseStart ?? 1;
      var end = reference.verseEnd ?? reference.verseStart ?? 0;
      if (reference.verseStart == null) {
        final verses = await _repository.getVerses(
          version.code,
          reference.bookIndex,
          reference.chapter,
        );
        if (verses.isEmpty) {
          setState(() {
            _busy = false;
            _failure = L10n.of(context).quickVerseNoChapter(reference.bookName, reference.chapter);
          });
          return;
        }
        start = 1;
        end = verses.length;
      }

      final verseRef = await _repository.getVerseRange(
        versionCode: version.code,
        bookIndex: reference.bookIndex,
        chapter: reference.chapter,
        verseStart: start,
        verseEnd: end,
      );

      if (verseRef == null) {
        setState(() {
          _busy = false;
          _failure = L10n.of(context).quickVerseNotFound('$reference', version.name);
        });
        return;
      }

      if (project) {
        cubit.projectLoose(verseRef, together: _together);
      } else {
        await cubit.addBibleVerseAfterCurrent(verseRef, together: _together);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _failure = L10n.of(context).quickVerseReadFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = _parsed.reference;

    return AppDialog(
      title: L10n.of(context).addQuickVerse,
      icon: Icons.bolt_rounded,
      width: 460,
      // Only when there is a choice to make.
      headerActions: [
        if (_versions.length > 1 && _version != null)
          _VersionChoice(versions: _versions, selected: _version!.code, onChanged: _chooseVersion),
      ],
      actions: [
        // Two actions and no Cancel: the X and Escape already close this, and
        // a third button crowds the row.
        // Straight to the screen, without leaving anything in the service.
        OutlinedButton(
          onPressed: reference == null || _busy ? null : () => _submit(project: true),
          child: Text(L10n.of(context).bibleProject),
        ),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: reference == null || _busy ? null : _submit,
          child: Text(_busy ? L10n.of(context).searching : L10n.of(context).add),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enter is the whole point of typing a reference instead of browsing
          // to it, so it is bound here rather than left to the text field: the
          // field's own submit callback does not fire on this platform.
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): _submit,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
            },
            child: AppTextField(
              controller: _controller,
              focusNode: _field,
              hintText: 'jn 3:16',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _Feedback(result: _parsed, failure: _failure),
          if (_bookChoices.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            _BookChoices(books: _bookChoices, onPick: _chooseBook),
          ],
          if (_preview case final text? when _parsed.reference != null) ...[
            const SizedBox(height: AppSpace.md),
            _Preview(text: text, count: _previewCount, version: _previewVersion),
          ],
          // Only worth asking when the reference covers more than one verse:
          // a range, or a whole chapter, which names no verse at all.
          if (_parsed.reference case final r?
              when r.verseStart == null || r.verseEnd != r.verseStart) ...[
            const SizedBox(height: AppSpace.md),
            VerseLayoutToggle(together: _together, onChanged: _chooseLayout),
          ],
          const SizedBox(height: AppSpace.lg),
          Text(L10n.of(context).quickVerseAddsAfter, style: AppText.rowSubtitle),
          const SizedBox(height: AppSpace.xs),
          Text(L10n.of(context).looseHint, style: AppText.rowSubtitle),
          const SizedBox(height: AppSpace.xs),
          Text(
            L10n.of(context).quickVerseExamples('jn 3:16   ·   1 co 13:4-7   ·   salmos 23'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Says what the line will turn into, before the operator commits to it.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.result, required this.failure});

  final ReferenceResult result;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final message = failure;
    if (message != null) return _Line(text: message, color: AppColors.danger);

    final reference = result.reference;
    if (reference != null) {
      return _Line(text: reference.toString(), color: AppColors.success, bold: true);
    }

    return switch (result.problem) {
      ReferenceProblem.empty ||
      null => _Line(text: L10n.of(context).quickVerseTypeBook, color: AppColors.textTertiary),
      ReferenceProblem.noChapter => _Line(
        text: L10n.of(context).quickVerseMissingChapter,
        color: AppColors.textTertiary,
      ),
      ReferenceProblem.noBook => _Line(
        text: L10n.of(context).quickVerseUnknownBook(result.typed ?? ''),
        color: AppColors.warning,
      ),
      ReferenceProblem.ambiguous => _Line(
        text: L10n.of(context).quickVerseAmbiguous(result.typed ?? ''),
        color: AppColors.warning,
      ),
    };
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.color, this.bold = false});

  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// The books a half-typed name could mean, one tap from being the one.
class _BookChoices extends StatelessWidget {
  const _BookChoices({required this.books, required this.onPick});

  final List<int> books;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: [
        for (final index in books)
          ActionChip(
            label: Text(spanishBookName(index), style: const TextStyle(fontSize: 12)),
            onPressed: () => onPick(index),
            backgroundColor: AppColors.surfaceControl,
            side: const BorderSide(color: AppColors.border),
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// The passage itself, before it goes anywhere.
/// Which Bible the passage goes out in, beside the dialog's title.
class _VersionChoice extends StatelessWidget {
  const _VersionChoice({required this.versions, required this.selected, required this.onChanged});

  final List<BibleVersion> versions;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).bibleVersions,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceControl,
          borderRadius: AppRadius.all(AppRadius.sm),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            isDense: true,
            focusColor: Colors.transparent,
            dropdownColor: AppColors.surfaceControl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            icon: const Icon(Icons.expand_more, size: 14, color: AppColors.textMuted),
            items: [for (final v in versions) DropdownMenuItem(value: v.code, child: Text(v.code))],
            onChanged: (code) {
              if (code != null) onChanged(code);
            },
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.count, required this.version});

  final String text;
  final int count;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            [version, if (count > 1) L10n.of(context).quickVerseVerseCount(count)].join(' · '),
            style: AppText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}
