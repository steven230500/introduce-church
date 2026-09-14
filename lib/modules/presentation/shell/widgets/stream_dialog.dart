import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/stream/stream_style.dart';
import '../../../../core/stream/stream_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../children/control/presenter/cubit/cubit.dart';

/// Sets up the streaming output: how the words look, and how to get them
/// into the streaming program.
Future<void> showStreamDialog(BuildContext context) async {
  final control = context.read<ControlCubit>();
  final initial = await control.streamStyle();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: control,
      child: StreamDialog(initial: initial),
    ),
  );
}

@visibleForTesting
class StreamDialog extends StatefulWidget {
  const StreamDialog({super.key, required this.initial});

  final StreamStyle initial;

  @override
  State<StreamDialog> createState() => _StreamDialogState();
}

class _StreamDialogState extends State<StreamDialog> {
  late StreamStyle _style = widget.initial;

  /// Applied as it is changed, not on a save button: the window being
  /// captured is the preview that matters, and it should move with the slider.
  void _set(StreamStyle next) {
    setState(() => _style = next);
    context.read<ControlCubit>().setStreamStyle(next);
  }

  static String keyName(L10n t, StreamKey key) => switch (key) {
    StreamKey.green => t.streamKeyGreen,
    StreamKey.blue => t.streamKeyBlue,
    StreamKey.magenta => t.streamKeyMagenta,
    StreamKey.black => t.streamKeyBlack,
  };

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final control = context.read<ControlCubit>();
    final state = context.watch<ControlCubit>().state;
    // The slide on the projector when there is one, so the operator tunes the
    // size against the verse the church is actually on.
    final model = state is ControlLoadedState ? state.model : null;
    final live = model != null && model.isLive ? model.liveSlideContent : null;
    final text = live == null || live.trim().isEmpty ? t.streamSample : live;
    final reference = live == null ? t.streamSampleReference : model!.liveSlideReference;

    return AppDialog(
      title: t.streamTitle,
      icon: Icons.cast_outlined,
      width: 860,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
        const SizedBox(width: AppSpace.sm),
        FilledButton.icon(
          onPressed: () {
            control.openStreamWindow();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(t.streamOpen),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.streamIntro, style: AppText.body),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: AppRadius.all(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: StreamView(style: _style, text: text, reference: reference),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.streamKey, style: AppText.sectionLabel),
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: [
                        for (final key in StreamKey.values)
                          ChoiceChip(
                            avatar: CircleAvatar(backgroundColor: key.color, radius: 6),
                            label: Text(keyName(t, key)),
                            selected: _style.key == key,
                            onSelected: (_) => _set(_style.copyWith(key: key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(t.streamPosition, style: AppText.sectionLabel),
                    const SizedBox(height: AppSpace.xs),
                    SegmentedButton<StreamPosition>(
                      segments: [
                        ButtonSegment(value: StreamPosition.bottom, label: Text(t.streamBottom)),
                        ButtonSegment(value: StreamPosition.top, label: Text(t.streamTop)),
                      ],
                      selected: {_style.position},
                      onSelectionChanged: (s) => _set(_style.copyWith(position: s.first)),
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        Text(t.streamSize, style: AppText.sectionLabel),
                        Expanded(
                          child: Slider(
                            value: _style.scale,
                            min: StreamStyle.minScale,
                            max: StreamStyle.maxScale,
                            divisions: 10,
                            label: '${(_style.scale * 100).round()} %',
                            onChanged: (v) => _set(_style.copyWith(scale: v)),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _style.bar,
                      onChanged: (v) => _set(_style.copyWith(bar: v)),
                      title: Text(t.streamBar, style: const TextStyle(fontSize: 13)),
                      subtitle: _style.bar
                          ? null
                          : Text(t.streamBarNote, style: AppText.rowSubtitle),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _style.showReference,
                      onChanged: (v) => _set(_style.copyWith(showReference: v)),
                      title: Text(t.streamReference, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: AppRadius.all(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.streamHowTitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpace.xs),
                Text('1.  ${t.streamHowWindow}', style: AppText.body.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '2.  ${_style.key == StreamKey.black ? t.streamHowLuma : t.streamHowChroma(keyName(t, _style.key).toLowerCase())}',
                  style: AppText.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
