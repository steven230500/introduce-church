part of '../page.dart';

/// Across the top of the presenter while a rehearsal runs: that it is one,
/// how long it has gone, and the item being timed.
///
/// Hard to miss on purpose. An operator who forgets a rehearsal is running
/// goes into the service with the clock still going and the licence report
/// not counting.
class _RehearsalBar extends StatefulWidget {
  const _RehearsalBar({required this.model});

  final ControlModel model;

  @override
  State<_RehearsalBar> createState() => _RehearsalBarState();
}

class _RehearsalBarState extends State<_RehearsalBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<ControlCubit>();
    final model = widget.model;
    final started = cubit.rehearsalStartedAt;
    final item = model.isLive ? model.liveItem : model.currentItem;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpace.sm),
          Text(
            t.rehearsalLabel,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          if (started != null)
            Text(
              clockText(DateTime.now().difference(started)),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          if (item != null) ...[
            const SizedBox(width: AppSpace.lg),
            Flexible(
              child: Text(
                t.rehearsalOn(item.displayTitle, clockText(cubit.rehearsedOn(item.id))),
                style: AppText.rowSubtitle.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          Text(t.rehearsalNote, style: AppText.rowSubtitle),
          const SizedBox(width: AppSpace.md),
          FilledButton.tonalIcon(
            onPressed: () => finishRehearsal(context),
            icon: const Icon(Icons.stop_rounded, size: 16),
            label: Text(t.rehearsalEnd),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}
