import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/timing/service_clock.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../../../../core/models/labels.dart';

/// Ends the rehearsal and offers to keep what it measured as the plan.
Future<void> finishRehearsal(BuildContext context) async {
  final cubit = context.read<ControlCubit>();
  final result = cubit.endRehearsal();
  if (result == null || !context.mounted) return;
  final chosen = await showDialog<Map<String, int>>(
    context: context,
    builder: (_) => RehearsalSummaryDialog(result: result),
  );
  if (chosen != null && chosen.isNotEmpty) await cubit.setPlannedTimes(chosen);
}

@visibleForTesting
class RehearsalSummaryDialog extends StatefulWidget {
  const RehearsalSummaryDialog({super.key, required this.result});

  final RehearsalResult result;

  /// Shorter than this and the item was only passed on the way to another.
  static const reached = Duration(seconds: 10);

  @override
  State<RehearsalSummaryDialog> createState() => _RehearsalSummaryDialogState();
}

class _RehearsalSummaryDialogState extends State<RehearsalSummaryDialog> {
  late final Set<String> _keep = {
    for (final entry in widget.result.items)
      if (entry.spent >= RehearsalSummaryDialog.reached) entry.item.id,
  };

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final items = widget.result.items;
    return AppDialog(
      title: t.rehearsalSummaryTitle,
      icon: Icons.timer_outlined,
      width: 640,
      height: 560,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.rehearsalDiscard)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _keep.isEmpty
              ? null
              : () => Navigator.pop(context, {
                  for (final entry in items)
                    if (_keep.contains(entry.item.id))
                      entry.item.id: plannedFromRehearsal(entry.spent),
                }),
          child: Text(t.rehearsalSave(_keep.length)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.rehearsalSummaryIntro, style: AppText.body),
          const SizedBox(height: AppSpace.sm),
          Text(
            t.rehearsalTotal(clockText(widget.result.total)),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.md),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: AppSpace.sm),
            child: Row(
              children: [
                Expanded(child: Text(t.rehearsalColItem, style: AppText.sectionLabel)),
                SizedBox(
                  width: 96,
                  child: Text(
                    t.rehearsalColRehearsed,
                    style: AppText.sectionLabel,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    t.rehearsalColPlanned,
                    style: AppText.sectionLabel,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppSpace.md),
          Expanded(
            child: ListView(
              children: [
                for (final entry in items)
                  _Row(
                    title: entry.item.titleIn(t),
                    rehearsed: entry.spent,
                    planned: entry.item.plannedSecs,
                    keep: _keep.contains(entry.item.id),
                    onChanged: entry.spent >= RehearsalSummaryDialog.reached
                        ? (value) => setState(
                            () => value ? _keep.add(entry.item.id) : _keep.remove(entry.item.id),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.rehearsed,
    required this.planned,
    required this.keep,
    required this.onChanged,
  });

  final String title;
  final Duration rehearsed;
  final int? planned;
  final bool keep;

  /// Null for an item the rehearsal never really reached.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final reached = onChanged != null;
    final muted = TextStyle(
      fontSize: 13,
      color: reached ? AppColors.textSecondary : AppColors.textDisabled,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: Row(
        children: [
          Checkbox(
            value: keep,
            onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: reached ? AppColors.textPrimary : AppColors.textDisabled,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              reached ? clockText(Duration(seconds: plannedFromRehearsal(rehearsed))) : '—',
              style: muted.copyWith(color: reached ? AppColors.textPrimary : null),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              planned == null ? '—' : clockText(Duration(seconds: planned!)),
              style: muted,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
