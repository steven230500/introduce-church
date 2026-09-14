import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/models/saved_notice.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/hover_builder.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../../../../l10n/l10n.dart';

/// Everything an operator says in the middle of a service.
///
/// Two audiences, one place: a notice over the slide, which everyone reads,
/// and a line for the platform, which nobody in the pews sees. The two are
/// told apart by colour, because the cost of confusing them is telling four
/// hundred people that the preacher is running long.
Future<void> showNoticesDialog(BuildContext context, {OrganizationRepository? repository}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ControlCubit>(),
      child: NoticesDialog(repository: repository),
    ),
  );
}

@visibleForTesting
class NoticesDialog extends StatefulWidget {
  const NoticesDialog({super.key, this.repository});

  /// Injected by tests. In the app it comes from the injector.
  final OrganizationRepository? repository;

  @override
  State<NoticesDialog> createState() => _NoticesDialogState();
}

class _NoticesDialogState extends State<NoticesDialog> {
  late final _repository = widget.repository ?? Modular.get<OrganizationRepository>();
  final _compose = TextEditingController();
  final _stage = TextEditingController();

  List<SavedNotice> _saved = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<ControlCubit>().state;
    if (state is ControlLoadedState) _stage.text = state.model.stageMessage ?? '';
    _load();
  }

  Future<void> _load() async {
    final notices = await _repository.getNotices();
    if (!mounted) return;
    setState(() {
      _saved = notices;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _compose.dispose();
    _stage.dispose();
    super.dispose();
  }

  Future<void> _store(List<SavedNotice> next) async {
    setState(() => _saved = next);
    final stored = await _repository.setNotices(next);
    if (mounted) setState(() => _saved = stored);
  }

  Future<void> _remember() async {
    final text = _compose.text.trim();
    if (text.isEmpty || _saved.any((n) => n.text == text)) return;
    _compose.clear();
    await _store([..._saved, SavedNotice(text: text)]);
  }

  Future<void> _forget(SavedNotice notice) => _store([..._saved]..remove(notice));

  Future<void> _setHide(SavedNotice notice, int seconds) => _store([
    for (final n in _saved)
      if (n == notice) SavedNotice(text: n.text, autoHideSecs: seconds) else n,
  ]);

  void _show(ControlCubit cubit, String text, {int seconds = 0}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    cubit.showOverlay(trimmed, autoHideSecs: seconds);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ControlCubit>();
    final model = context.select<ControlCubit, ControlModel?>(
      (c) => c.state is ControlLoadedState ? (c.state as ControlLoadedState).model : null,
    );

    return AppDialog(
      title: L10n.of(context).barNotices,
      icon: Icons.campaign_outlined,
      width: 520,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).close)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // What is out there right now, first, because it is the only thing
          // here that is already costing the congregation something.
          if (model?.overlayVisible ?? false)
            _NowShowing(
              text: model?.overlayText ?? '',
              onHide: () {
                cubit.hideOverlay();
                Navigator.pop(context);
              },
            ),
          _Heading(
            icon: Icons.tv_rounded,
            title: L10n.of(context).noticesOnSlide,
            hint: L10n.of(context).noticesOnSlideHint,
            tone: AppColors.accent,
          ),
          const SizedBox(height: AppSpace.md),
          if (_loading)
            Text(L10n.of(context).loading, style: AppText.rowSubtitle)
          else if (_saved.isNotEmpty) ...[
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final notice in _saved)
                  _NoticeCard(
                    notice: notice,
                    onShow: () => _show(cubit, notice.text, seconds: notice.autoHideSecs),
                    onForget: () => _forget(notice),
                    onSetHide: (s) => _setHide(notice, s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
          ],
          _Composer(
            controller: _compose,
            hint: _saved.isEmpty
                ? L10n.of(context).noticesComposeFirst
                : L10n.of(context).noticesComposeAnother,
            onShow: () => _show(cubit, _compose.text),
            onRemember: _remember,
          ),
          const SizedBox(height: AppSpace.xl),
          _Heading(
            icon: Icons.co_present_outlined,
            title: L10n.of(context).noticesStageOnly,
            hint: L10n.of(context).noticesStageOnlyHint,
            tone: AppColors.warning,
          ),
          const SizedBox(height: AppSpace.md),
          _StageLine(
            controller: _stage,
            active: (model?.stageMessage ?? '').isNotEmpty,
            onSend: () {
              cubit.setStageMessage(_stage.text);
              Navigator.pop(context);
            },
            onClear: () {
              cubit.setStageMessage(null);
              _stage.clear();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

/// The notice the congregation is reading right now.
class _NowShowing extends StatelessWidget {
  const _NowShowing({required this.text, required this.onHide});

  final String text;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.lg),
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.sm, AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.14),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.live),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowTitle,
            ),
          ),
          TextButton(onPressed: onHide, child: Text(L10n.of(context).remove)),
        ],
      ),
    );
  }
}

/// A section title and, beside it, the one thing worth knowing about it.
class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.title, required this.hint, required this.tone});

  final IconData icon;
  final String title;
  final String hint;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: tone),
        const SizedBox(width: AppSpace.sm),
        Text(
          title,
          style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowSubtitle,
          ),
        ),
      ],
    );
  }
}

/// A saved notice, sized to be hit without looking.
///
/// Deliberately not a row that resembles a text field: the thing you press and
/// the thing you type into were the same shape, and during a service that is
/// one mistake away from projecting a half-typed sentence.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.onShow,
    required this.onForget,
    required this.onSetHide,
  });

  final SavedNotice notice;
  final VoidCallback onShow;
  final VoidCallback onForget;
  final ValueChanged<int> onSetHide;

  static const _durations = [0, 5, 10, 20, 30];

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onShow,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.fromLTRB(AppSpace.md, 10, AppSpace.md, 10),
              decoration: BoxDecoration(
                color: hovering ? AppColors.accentFill : AppColors.surfaceControl,
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(color: hovering ? AppColors.accent : AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle,
                  ),
                  const SizedBox(height: 3),
                  _Duration(notice: notice, onSelected: onSetHide),
                ],
              ),
            ),
          ),
          // On hover only, and inside the card. A row of cards each wearing a
          // delete button is a row nobody wants to press, and one hanging over
          // the edge cannot be pressed at all: Flutter does not hit-test the
          // part of a child that falls outside its parent.
          if (hovering)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onForget,
                child: Tooltip(
                  message: L10n.of(context).noticesForget,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 11, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How long a notice stays up, shown on the card it belongs to.
class _Duration extends StatelessWidget {
  const _Duration({required this.notice, required this.onSelected});

  final SavedNotice notice;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: L10n.of(context).noticesHowLong,
      color: AppColors.surfaceControl,
      itemBuilder: (_) => [
        for (final seconds in _NoticeCard._durations)
          PopupMenuItem(
            value: seconds,
            height: 34,
            child: Text(
              seconds == 0
                  ? L10n.of(context).noticesUntilRemoved
                  : L10n.of(context).noticesSeconds(seconds),
              style: AppText.body,
            ),
          ),
      ],
      onSelected: onSelected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            notice.hides ? Icons.timer_outlined : Icons.push_pin_outlined,
            size: 11,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 3),
          Text(
            notice.hides
                ? L10n.of(context).noticesSecondsShort(notice.autoHideSecs)
                : L10n.of(context).noticesUntilRemovedShort,
            style: AppText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}

/// Where a new notice is written. Shaped like a composer, not like a card.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.onShow,
    required this.onRemember,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onShow;
  final VoidCallback onRemember;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(controller: controller, hintText: hint, onSubmitted: (_) => onShow()),
        ),
        const SizedBox(width: AppSpace.sm),
        TextButton.icon(
          onPressed: onRemember,
          icon: const Icon(Icons.bookmark_add_outlined, size: 15),
          label: Text(L10n.of(context).save),
        ),
        const SizedBox(width: AppSpace.xs),
        FilledButton(onPressed: onShow, child: Text(L10n.of(context).noticesShow)),
      ],
    );
  }
}

/// The line for the platform, in the colour the monitor shows it in.
class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.controller,
    required this.active,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool active;
  final VoidCallback onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: active ? 0.12 : 0.05),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: active ? 0.45 : 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: controller,
              hintText: L10n.of(context).noticesStageHint,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (active) TextButton(onPressed: onClear, child: Text(L10n.of(context).remove)),
          FilledButton(onPressed: onSend, child: Text(L10n.of(context).send)),
        ],
      ),
    );
  }
}
