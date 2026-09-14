import 'package:flutter/material.dart';

import '../../../../core/models/collection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';

/// What the collection dialog returns.
typedef CollectionDraft = ({String name, DateTime? date});

/// Creates or renames a collection.
///
/// There is exactly one of these. The app used to have two, and only one of
/// them asked for a service date, so the same button produced different
/// results depending on which screen you pressed it from.
Future<CollectionDraft?> showCollectionDialog(
  BuildContext context, {
  Collection? existing,
  Collection? duplicating,
}) {
  return showDialog<CollectionDraft>(
    context: context,
    builder: (_) => _CollectionDialog(existing: existing, duplicating: duplicating),
  );
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({this.existing, this.duplicating});

  /// The collection being renamed.
  final Collection? existing;

  /// The collection being copied. Its name is offered with a suffix and its
  /// date is left blank, because a copy is for a different Sunday.
  final Collection? duplicating;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final TextEditingController _nameCtrl;
  DateTime? _date;

  bool _ready = false;

  // The suggested name is worded in the operator's language, which initState
  // cannot read yet.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final copying = widget.duplicating;
    final suggested =
        widget.existing?.name ?? (copying == null ? '' : L10n.of(context).copySuffix(copying.name));
    _nameCtrl = TextEditingController(text: suggested)
      // Selected, not just filled, so the suggestion can be typed over.
      ..selection = TextSelection(baseOffset: 0, extentOffset: suggested.length);
    _date = widget.existing?.serviceDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, date: _date));
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isCopy = widget.duplicating != null;
    final isNew = widget.existing == null;
    return AppDialog(
      title: isCopy
          ? L10n.of(context).collectionDuplicateTitle
          : (isNew ? L10n.of(context).newCollection : L10n.of(context).collectionEditTitle),
      icon: isCopy ? Icons.copy_all_outlined : Icons.folder_outlined,
      width: 400,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _save,
          child: Text(
            isCopy
                ? L10n.of(context).duplicate
                : (isNew ? L10n.of(context).create : L10n.of(context).save),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _nameCtrl,
            hintText: L10n.of(context).collectionNameHint,
            label: L10n.of(context).name,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: _pickDate,
            borderRadius: AppRadius.all(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.md - 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceControl,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.all(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpace.md - 2),
                  Text(
                    _date != null ? _formatDate(_date!) : L10n.of(context).collectionDateOptional,
                    style: TextStyle(
                      color: _date != null ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (_date != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _date = null),
                      child: const Icon(Icons.close, size: 14, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
