import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/collection.dart';
import '../../../../core/models/collection_item_type.dart';
import '../../../../core/models/labels.dart';
import '../../../../core/models/slide_template.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/slide_view.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../../../../l10n/l10n.dart';

/// Corrects the words of one slide without leaving the service.
///
/// What the operator asked for after a Sunday on FreeShow: a typo on the
/// screen, a verse that wraps badly, a stanza too long for one slide, fixed
/// from the grid in a few seconds. Opens on slide [slideIndex] of the item
/// selected in the set list, or on the selected slide.
Future<void> showSlideEditor(BuildContext context, {int? slideIndex}) async {
  final cubit = context.read<ControlCubit>();
  final state = cubit.state;
  if (state is! ControlLoadedState) return;
  final model = state.model;
  final item = model.currentItem;
  if (item == null) return;
  if (!item.slidesEditable) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(L10n.of(context).slideEditUnavailable)));
    return;
  }
  final index = slideIndex ?? model.currentSlideIndex;
  if (index < 0 || index >= item.slides.length) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = L10n.of(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: SlideEditorDialog(item: item, slideIndex: index, template: model.templateFor(item)),
    ),
  );
  // A song changed in the library is a change to every service that sings
  // it: taking it back has to be one click away, as removing an item is.
  if (saved != true || !cubit.canUndoSlideEdit || messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(t.slideEditSaved(item.titleIn(t))),
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      width: 420,
      action: SnackBarAction(label: t.undo, onPressed: cubit.undoSlideEdit),
    ),
  );
}

@visibleForTesting
class SlideEditorDialog extends StatefulWidget {
  const SlideEditorDialog({
    super.key,
    required this.item,
    required this.slideIndex,
    required this.template,
  });

  final CollectionItem item;
  final int slideIndex;

  /// The design the slide goes out in, so the preview wraps where the
  /// projector will.
  final SlideTemplate template;

  @override
  State<SlideEditorDialog> createState() => _SlideEditorDialogState();
}

class _SlideEditorDialogState extends State<SlideEditorDialog> {
  late final _text = TextEditingController(text: widget.item.slides[widget.slideIndex]);
  bool _busy = false;
  String? _failure;

  CollectionItem get _item => widget.item;
  bool get _isSong => _item.type == CollectionItemType.song;

  @override
  void initState() {
    super.initState();
    // The preview follows the words, and the split button the cursor, which
    // moves with the arrows as well as with typing.
    _text.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  /// The text on either side of the cursor, when both have words in them.
  (String, String)? get _halves {
    final at = _text.selection.baseOffset;
    if (at <= 0 || at >= _text.text.length) return null;
    final before = _text.text.substring(0, at).trim();
    final after = _text.text.substring(at).trim();
    if (before.isEmpty || after.isEmpty) return null;
    return (before, after);
  }

  Future<void> _apply(List<String> parts) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final changed = await context.read<ControlCubit>().editSlide(
        _item.id,
        widget.slideIndex,
        parts,
      );
      if (mounted) Navigator.pop(context, changed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = L10n.of(context).saveFailed('$e'.split('\n').first);
      });
    }
  }

  void _save() {
    if (_text.text.trim().isEmpty) return;
    _apply([_text.text]);
  }

  void _split() {
    final halves = _halves;
    if (halves != null) _apply([halves.$1, halves.$2]);
  }

  Future<void> _remove() async {
    final t = L10n.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: t.slideEditRemoveTitle,
      message: _isSong ? t.slideEditRemoveSong : t.slideEditRemovePoint,
      confirmLabel: t.slideEditRemove,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed) await _apply(const []);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final labels = _item.slideLabelsIn(t);
    final label = widget.slideIndex < labels.length && labels[widget.slideIndex].isNotEmpty
        ? labels[widget.slideIndex]
        : t.slideNumber(widget.slideIndex + 1);
    final repeats = _isSong ? _item.song!.repeatsOf(widget.slideIndex) : 0;
    final canSplit = _item.canSplitSlide(widget.slideIndex);

    return AppDialog(
      title: t.slideEdit,
      icon: Icons.edit_outlined,
      width: 760,
      showClose: !_busy,
      actions: [
        if (_item.canRemoveSlide(widget.slideIndex))
          TextButton.icon(
            onPressed: _busy ? null : _remove,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(t.slideEditRemove),
          ),
        if (canSplit)
          Tooltip(
            message: t.slideEditSplitHelp,
            child: TextButton.icon(
              onPressed: _busy || _halves == null ? null : _split,
              icon: const Icon(Icons.vertical_split_outlined, size: 16),
              label: Text(t.slideEditSplit),
            ),
          ),
        const Spacer(),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _busy || _text.text.trim().isEmpty ? null : _save,
          child: Text(t.save),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_item.titleIn(t)}  ·  $label',
            style: AppText.rowSubtitle,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
                    const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
                  },
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    enabled: !_busy,
                    minLines: 7,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceControl,
                      contentPadding: const EdgeInsets.all(AppSpace.md),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.all(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.all(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              SizedBox(
                width: 300,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: AppRadius.all(AppRadius.sm),
                    child: SlideView(content: _text.text, reference: '', template: widget.template),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(t.slideEditSaveHint('⌘↵'), style: AppText.rowSubtitle),
          if (_isSong) ...[
            const SizedBox(height: AppSpace.sm),
            Text(t.slideEditSongNote, style: AppText.body),
            if (repeats > 0) ...[
              const SizedBox(height: AppSpace.xs),
              Text(t.slideEditRepeats(repeats), style: AppText.body),
            ],
            if (_item.song!.verses[widget.slideIndex].chords?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpace.xs),
              Text(t.slideEditChords, style: AppText.body.copyWith(color: AppColors.warning)),
            ],
          ],
          if (_failure != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_failure!, style: AppText.body.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}
