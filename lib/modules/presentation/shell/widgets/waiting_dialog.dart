import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/waiting/waiting_scenes.dart';
import '../../../../core/waiting/waiting_screen.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../children/control/presenter/cubit/cubit.dart';

/// Choosing what the screen shows while nothing else is on it.
Future<void> showWaitingDialog(BuildContext context) async {
  final control = context.read<ControlCubit>();
  final initial = await control.lastWaiting();
  if (!context.mounted) return;
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: control,
      child: WaitingDialog(initial: initial),
    ),
  );
}

@visibleForTesting
class WaitingDialog extends StatefulWidget {
  const WaitingDialog({super.key, required this.initial, this.animate = true});

  final WaitingConfig initial;

  /// Off in tests, where six scenes animating forever would never settle.
  final bool animate;

  @override
  State<WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<WaitingDialog> {
  late WaitingConfig _config = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title);
  late final _subtitle = TextEditingController(text: widget.initial.subtitle);

  @override
  void initState() {
    super.initState();
    // The preview follows the fields as they are typed, so the operator sees
    // the words on the scene before the room does.
    _title.addListener(() => setState(() => _config = _config.copyWith(title: _title.text)));
    _subtitle.addListener(
      () => setState(() => _config = _config.copyWith(subtitle: _subtitle.text)),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  static String _sceneName(L10n t, WaitingScene scene) => switch (scene) {
    WaitingScene.aurora => t.waitingSceneAurora,
    WaitingScene.light => t.waitingSceneLight,
    WaitingScene.waves => t.waitingSceneWaves,
    WaitingScene.sunrise => t.waitingSceneSunrise,
    WaitingScene.stars => t.waitingSceneStars,
    WaitingScene.calm => t.waitingSceneCalm,
  };

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final control = context.read<ControlCubit>();
    final state = context.watch<ControlCubit>().state;
    final up = state is ControlLoadedState && state.model.waiting.active;

    return AppDialog(
      title: t.waitingTitle,
      icon: Icons.auto_awesome_outlined,
      width: 760,
      actions: [
        if (up)
          TextButton(
            onPressed: () {
              control.hideWaiting();
              Navigator.pop(context);
            },
            child: Text(t.waitingHide),
          ),
        FilledButton.icon(
          onPressed: () {
            control.showWaiting(_config);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(up ? t.waitingUpdate : t.waitingShow),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.waitingIntro, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: AppSpace.lg),

          // The chosen scene, large, with the words on it as they will look.
          // Capped in height: at full dialog width the preview alone was taller
          // than the smallest window the app allows.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ClipRRect(
                borderRadius: AppRadius.all(AppRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: WaitingScreen(
                    key: ValueKey('preview_${_config.scene.id}'),
                    config: _config,
                    animate: widget.animate,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),

          // Every scene, moving, so the choice is made by looking rather than
          // by guessing from a name.
          // All six in one row, sharing the width. A scrolling strip hid the
          // last one behind the edge, and a choice you have to scroll to find
          // is one most people never see.
          Row(
            children: [
              for (final (index, scene) in WaitingScene.values.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _SceneThumb(
                      label: _sceneName(t, scene),
                      scene: scene,
                      selected: scene == _config.scene,
                      animate: widget.animate,
                      onTap: () => setState(() => _config = _config.copyWith(scene: scene)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.lg),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: t.waitingFieldTitle,
                    hintText: t.waitingFieldTitleHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: TextField(
                  controller: _subtitle,
                  decoration: InputDecoration(
                    labelText: t.waitingFieldSubtitle,
                    hintText: t.waitingFieldSubtitleHint,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _config.showClock,
            onChanged: (value) => setState(() => _config = _config.copyWith(showClock: value)),
            title: Text(t.waitingClock, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              t.waitingClockNote,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneThumb extends StatelessWidget {
  const _SceneThumb({
    required this.label,
    required this.scene,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final String label;
  final WaitingScene scene;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: AppRadius.all(AppRadius.sm + 2),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.all(AppRadius.sm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WaitingScreen(
                    config: WaitingConfig(scene: scene),
                    animate: animate,
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      color: const Color(0x99000000),
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
