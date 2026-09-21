import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/local_db/bible_reference.dart';
import '../../../../core/local_db/bible_repository.dart';
import '../../../../core/sermon/sermon_outline.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';

/// A sermon as the dialog hands it back: the title slide, the points, and
/// the passages a pasted outline named that the operator kept.
typedef SermonDraft = ({String title, List<String> points, List<BibleVerseRef> passages});

/// Writes the sermon's title slide and its points, or corrects them when
/// [initial] is given.
///
/// A new sermon can come from the outline the pastor sent: with [paste] the
/// dialog opens already filled from the clipboard.
Future<SermonDraft?> showSermonDialog(
  BuildContext context, {
  SermonDraft? initial,
  bool paste = false,
  BibleRepository? repository,
}) {
  return showDialog<SermonDraft>(
    context: context,
    builder: (_) => SermonDialog(initial: initial, paste: paste, repository: repository),
  );
}

@visibleForTesting
class SermonDialog extends StatefulWidget {
  const SermonDialog({super.key, this.initial, this.paste = false, this.repository});

  final SermonDraft? initial;
  final bool paste;

  /// Injected by tests. In the app it comes from the injector.
  final BibleRepository? repository;

  @override
  State<SermonDialog> createState() => _SermonDialogState();
}

/// A passage the outline names, and what the Bible on this computer has for
/// it once it has been looked up.
class _Passage {
  const _Passage(this.reference, {this.found, this.looked = false, this.keep = false});

  final BibleReference reference;
  final BibleVerseRef? found;
  final bool looked;
  final bool keep;

  _Passage lookedUp(BibleVerseRef? found) =>
      _Passage(reference, found: found, looked: true, keep: found != null);

  _Passage toggled() => _Passage(reference, found: found, looked: looked, keep: !keep);
}

class _SermonDialogState extends State<SermonDialog> {
  late final _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
  late final List<TextEditingController> _pointCtrls = [
    for (final point in widget.initial?.points ?? const <String>[])
      TextEditingController(text: point),
  ];
  late final _repository = widget.repository ?? Modular.get<BibleRepository>();

  List<_Passage> _passages = const [];

  /// The version the passages were read in, which is the one they go out in.
  String _version = '';
  String? _pasteProblem;

  /// Which paste the lookups belong to: a second paste while the first is
  /// still being read must not get the first one's passages.
  var _pasted = 0;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    if (widget.paste) WidgetsBinding.instance.addPostFrameCallback((_) => _paste());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _pointCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPoint() => setState(() => _pointCtrls.add(TextEditingController()));

  void _removePoint(int index) {
    setState(() {
      _pointCtrls[index].dispose();
      _pointCtrls.removeAt(index);
    });
  }

  /// Fills the sermon from the outline on the clipboard: the title, a point
  /// per line, and the passages it names, looked up in the church's Bible.
  Future<void> _paste() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      // Something that is not text: nothing to read.
    }
    final outline = readSermonOutline(data?.text ?? '');
    if (!mounted) return;
    if (outline.isEmpty) {
      setState(() => _pasteProblem = L10n.of(context).sermonPasteNothing);
      return;
    }

    final paste = ++_pasted;
    setState(() {
      _pasteProblem = null;
      if (outline.title.isNotEmpty) _titleCtrl.text = outline.title;
      for (final c in _pointCtrls) {
        c.dispose();
      }
      _pointCtrls
        ..clear()
        ..addAll([for (final point in outline.points) TextEditingController(text: point)]);
      _passages = [for (final reference in outline.passages) _Passage(reference)];
    });

    final version = await _repository.preferredVersion();
    final found = <BibleVerseRef?>[];
    for (final passage in outline.passages) {
      try {
        found.add(version == null ? null : await _repository.passage(passage, version.code));
      } catch (_) {
        found.add(null);
      }
    }
    if (!mounted || paste != _pasted) return;
    setState(() {
      _version = version?.code ?? '';
      _passages = [for (final (i, passage) in _passages.indexed) passage.lookedUp(found[i])];
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final points = _pointCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    Navigator.pop(context, (
      title: title,
      points: points,
      passages: [
        for (final passage in _passages)
          if (passage.keep && passage.found != null) passage.found!,
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AppDialog(
      title: _isEdit ? t.sermonEdit : t.sermonNew,
      icon: Icons.mic_outlined,
      width: 480,
      headerActions: [
        if (!_isEdit)
          TextButton.icon(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste_rounded, size: 14),
            label: Text(t.sermonPasteOutline, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _titleCtrl.text.trim().isEmpty ? null : _save,
          child: Text(_isEdit ? t.saveChanges : t.save),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pasteProblem case final problem?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  problem,
                  style: const TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            AppTextField(
              controller: _titleCtrl,
              hintText: t.sermonTitleHint,
              label: t.sermonTitleSlide,
              autofocus: true,
              onSubmitted: (_) => _addPoint(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Text(t.sermonPoints, style: AppText.sectionLabel),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(t.add, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                ),
              ],
            ),
            ..._pointCtrls.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Row(
                  children: [
                    _Number(i + 1),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: AppTextField(
                        controller: entry.value,
                        hintText: t.sermonPoint(i + 1),
                        onSubmitted: (_) => _addPoint(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      tooltip: t.sermonRemovePoint,
                      onPressed: () => _removePoint(i),
                    ),
                  ],
                ),
              );
            }),
            if (_pointCtrls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(t.sermonAddFirstPoint),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
                ),
              ),
            if (_passages.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Text(t.sermonPassages, style: AppText.sectionLabel),
              const SizedBox(height: AppSpace.xs),
              Text(t.sermonPassagesNote, style: AppText.rowSubtitle),
              for (final (i, passage) in _passages.indexed)
                _PassageRow(
                  passage: passage,
                  version: _version,
                  onToggle: () => setState(() => _passages[i] = passage.toggled()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm),
      ),
      child: Center(
        child: Text('$number', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ),
    );
  }
}

/// A passage the outline names: kept or not, and what it says, so a wrong
/// reference is caught here and not on the wall.
class _PassageRow extends StatelessWidget {
  const _PassageRow({required this.passage, required this.version, required this.onToggle});

  final _Passage passage;
  final String version;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final found = passage.found;
    final missing = passage.looked && found == null;
    final words = found?.texts.where((text) => text.trim().isNotEmpty).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: passage.keep, onChanged: found == null ? null : (_) => onToggle()),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    found == null ? '${passage.reference}' : '${found.reference} • $version',
                    style: AppText.rowTitle,
                  ),
                  if (missing)
                    Text(
                      L10n.of(context).sermonPassageMissing(version.isEmpty ? '—' : version),
                      style: const TextStyle(color: AppColors.warning, fontSize: 11),
                    )
                  else if (words != null)
                    Text(
                      words,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowSubtitle,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
