import 'package:flutter/material.dart';
import 'app_dialog.dart';
import '../../l10n/l10n.dart';

class FreeSlideResult {
  const FreeSlideResult({required this.text, this.title});
  final String text;
  final String? title;
}

Future<FreeSlideResult?> showFreeSlideDialog(BuildContext context) {
  return showDialog<FreeSlideResult>(context: context, builder: (_) => const _FreeSlideDialog());
}

class _FreeSlideDialog extends StatefulWidget {
  const _FreeSlideDialog();

  @override
  State<_FreeSlideDialog> createState() => _FreeSlideDialogState();
}

class _FreeSlideDialogState extends State<_FreeSlideDialog> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit => _textCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(
      context,
      FreeSlideResult(
        text: _textCtrl.text.trim(),
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: L10n.of(context).freeSlideTitle,
      icon: Icons.text_fields_rounded,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(disabledBackgroundColor: kDialogBorder),
          child: Text(L10n.of(context).add),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _titleCtrl,
            hintText: L10n.of(context).freeSlideTitleHint,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _textFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _textCtrl,
            focusNode: _textFocus,
            hintText: L10n.of(context).freeSlideContentHint,
            maxLines: 5,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            L10n.of(context).freeSlideNote,
            style: TextStyle(color: kTextSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
