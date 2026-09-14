import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/models/slide_template.dart';
import '../../../core/widgets/slide_background.dart';
import '../../../core/widgets/slide_transition_view.dart';
import '../../../core/widgets/slide_view.dart';
import '../../../core/motion/motion_scenes.dart';
import '../../../core/waiting/waiting_screen.dart';
import 'display_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // This is the projector: whatever moves, moves.
      body: SlideMotion(
        level: MotionLevel.all,
        child: BlocBuilder<DisplayCubit, DisplayState>(
          builder: (_, state) {
            final overlay = _overlayFor(state);
            final transition = state is DisplaySlideState
                ? state.template.transitionType
                : SlideTransitionType.fade;
            final durationMs = state is DisplaySlideState
                ? state.template.transitionDurationMs
                : 300;
            final duration = transition == SlideTransitionType.cut
                ? Duration.zero
                : Duration(milliseconds: durationMs);
            // A moving background is drawn once, underneath, for as long as
            // the design behind the slides keeps it. Drawn with each slide,
            // every new line of a song would cross-fade a loop into a second
            // copy of itself started from the top.
            final moving = state is DisplaySlideState && state.template.hasMovingBackground
                ? state.template
                : null;
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: duration,
                  child: moving == null
                      ? const SizedBox.expand(key: ValueKey('no_background'))
                      : SlideBackground(
                          key: ValueKey('background_${moving.backgroundSignature}'),
                          template: moving,
                        ),
                ),
                AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) =>
                      buildSlideTransition(child, animation, transition),
                  child: _buildChild(state, drawBackground: moving == null),
                ),
                if (overlay != null) _OverlayBar(text: overlay),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _overlayFor(DisplayState state) {
    return switch (state) {
      DisplaySlideState(overlayVisible: true, overlayText: final t) => t,
      DisplayImageState(overlayVisible: true, overlayText: final t) => t,
      DisplayVideoState(overlayVisible: true, overlayText: final t) => t,
      DisplayCountdownState(overlayVisible: true, overlayText: final t) => t,
      DisplayAnnouncementState(overlayVisible: true, overlayText: final t) => t,
      _ => null,
    };
  }

  Widget _buildChild(DisplayState state, {required bool drawBackground}) {
    return switch (state) {
      // Keyed by scene only, not by the words or the countdown: changing the
      // title while the loop is up must not restart the animation from the
      // top, which on a wall reads as a glitch.
      DisplayWaitingState() => WaitingScreen(
        key: ValueKey('waiting_${state.config.scene.id}'),
        config: state.config,
        countdownEnd: state.countdownEnd,
      ),
      DisplayCountdownState() => _CountdownView(
        key: ValueKey('countdown_${state.countdownEnd}'),
        countdownEnd: state.countdownEnd,
      ),
      DisplaySlideState() => SlideView(
        key: ValueKey('slide_${state.content}_${state.reference}_${state.template.id}'),
        content: state.content,
        reference: state.reference,
        template: state.template,
        showBackground: drawBackground,
      ),
      DisplayImageState() => Image.file(
        key: ValueKey('img_${state.imagePath}'),
        File(state.imagePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
      ),
      DisplayVideoState() => _VideoPlayer(
        key: ValueKey('video_${state.videoPath}'),
        videoPath: state.videoPath,
      ),
      DisplayAnnouncementState() => _AnnouncementView(
        key: ValueKey('ann_${state.message}_${state.timerTarget}'),
        message: state.message,
        timerTarget: state.timerTarget,
      ),
      DisplayBlankState() => const ColoredBox(
        key: ValueKey('blank'),
        color: Colors.black,
        child: SizedBox.expand(),
      ),
      _ => const SizedBox.expand(key: ValueKey('idle')),
    };
  }
}

// ── Announcement view ─────────────────────────────────────────────────────────

class _AnnouncementView extends StatefulWidget {
  const _AnnouncementView({required this.message, this.timerTarget, super.key});
  final String message;
  final DateTime? timerTarget;

  @override
  State<_AnnouncementView> createState() => _AnnouncementViewState();
}

class _AnnouncementViewState extends State<_AnnouncementView> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (widget.timerTarget == null) return;
    final r = widget.timerTarget!.difference(DateTime.now());
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = widget.timerTarget != null;
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.isNotEmpty)
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              if (hasTimer) ...[
                const SizedBox(height: 40),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 120,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  L10n.of(context).countdownStartsSoon,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Countdown view ────────────────────────────────────────────────────────────

class _CountdownView extends StatefulWidget {
  const _CountdownView({required this.countdownEnd, super.key});
  final DateTime countdownEnd;

  @override
  State<_CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<_CountdownView> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final remaining = widget.countdownEnd.difference(DateTime.now());
    if (mounted) setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final display = h > 0 ? '$h:$m:$s' : '$m:$s';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              display,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 180,
                fontWeight: FontWeight.w200,
                letterSpacing: -4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              L10n.of(context).countdownStartsSoon,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay bar (lower third) ─────────────────────────────────────────────────

class _OverlayBar extends StatelessWidget {
  const _OverlayBar({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 60,
      left: 80,
      right: 80,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: AppColors.accent, width: 4)),
          ),
          child: Text(
            text!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.videoPath, super.key});

  final String videoPath;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.setPlaylistMode(PlaylistMode.loop);
    _player.open(Media(widget.videoPath));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(controller: _controller, fill: Colors.black);
  }
}
