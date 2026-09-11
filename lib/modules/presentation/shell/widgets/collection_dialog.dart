import 'package:flutter/material.dart';

import '../../../../core/models/collection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_dialog.dart';

/// What the collection dialog returns.
typedef CollectionDraft = ({String name, DateTime? date});

/// Creates or renames a collection.
///
/// There is exactly one of these. The app used to have two, and only one of
/// them asked for a service date, so the same button produced different
/// results depending on which screen you pressed it from.
Future<CollectionDraft?> showCollectionDialog(BuildContext context, {Collection? existing}) {
  return showDialog<CollectionDraft>(
    context: context,
    builder: (_) => _CollectionDialog(existing: existing),
  );
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({this.existing});

  final Collection? existing;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final TextEditingController _nameCtrl;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
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
    final isNew = widget.existing == null;
    return AppDialog(
      title: isNew ? 'Nueva colección' : 'Editar colección',
      icon: Icons.folder_outlined,
      width: 400,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: _save, child: Text(isNew ? 'Crear' : 'Guardar')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _nameCtrl,
            hintText: 'Culto del domingo',
            label: 'Nombre',
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
                    _date != null ? _formatDate(_date!) : 'Fecha del servicio (opcional)',
                    style: TextStyle(
                      color: _date != null ? AppColors.textPrimary : AppColors.textDisabled,
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
