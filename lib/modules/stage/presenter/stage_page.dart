import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/slide_view.dart';
import '../../../core/timing/item_timer.dart';
import 'stage_cubit.dart';
import '../../../core/theme/app_colors.dart';

class StagePage extends StatelessWidget {
  const StagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chrome,
      body: BlocBuilder<StageCubit, StageState>(builder: (_, state) => _StageLayout(state: state)),
    );
  }
}

class _StageLayout extends StatelessWidget {
  const _StageLayout({required this.state});
  final StageState state;

  @override
  Widget build(BuildContext context) {
    final message = state.stageMessage;

    return Column(
      children: [
        // Above everything, because it is the one thing here that somebody
        // typed on purpose for the person reading this screen.
        if (message != null && message.isNotEmpty) _StageMessage(text: message),
        Expanded(child: _panels()),
      ],
    );
  }

  Widget _panels() {
    return Row(
      children: [
        // Left: current slide (large)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _SectionLabel('ACTUAL', isLive: state.isLive),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 6, 12),
                  child: _SlidePreviewBox(
                    slide: state.current,
                    isBlank: state.isBlank,
                    countdownActive: state.countdownActive,
                    countdownEnd: state.countdownEnd,
                    borderColor: state.isLive ? const Color(0xFFFF3B30) : AppColors.surfaceControl,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right column: next slide + info
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _SectionLabel('SIGUIENTE', isLive: false),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
                  child: _SlidePreviewBox(
                    slide: state.next,
                    isBlank: false,
                    countdownActive: false,
                    countdownEnd: null,
                    borderColor: AppColors.surfaceControl,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 12, 12),
                  child: _InfoPanel(state: state),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

/// A line the operator sent to the platform.
class _StageMessage extends StatelessWidget {
  const _StageMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFFCC00),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, size: 22, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.isLive});
  final String label;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          if (isLive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '● EN VIVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Slide preview box ─────────────────────────────────────────────────────────

class _SlidePreviewBox extends StatelessWidget {
  const _SlidePreviewBox({
    required this.slide,
    required this.isBlank,
    required this.countdownActive,
    required this.countdownEnd,
    required this.borderColor,
  });

  final StageSlide? slide;
  final bool isBlank;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: _content()),
      ),
    );
  }

  Widget _content() {
    if (countdownActive && countdownEnd != null) {
      return _MiniCountdown(countdownEnd: countdownEnd!);
    }
    if (isBlank) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    final s = slide;
    if (s == null) {
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.border, fontSize: 32)),
      );
    }
    if (s.imagePath != null) {
      return Image.file(
        File(s.imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black, child: SizedBox.expand()),
      );
    }
    return SlideView(content: s.content, reference: s.reference, template: s.template);
  }
}

// ── Mini countdown (for preview box) ─────────────────────────────────────────

class _MiniCountdown extends StatefulWidget {
  const _MiniCountdown({required this.countdownEnd});
  final DateTime countdownEnd;

  @override
  State<_MiniCountdown> createState() => _MiniCountdownState();
}

class _MiniCountdownState extends State<_MiniCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final r = widget.countdownEnd.difference(DateTime.now());
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          '$m:$s',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w200,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ── Info panel ────────────────────────────────────────────────────────────────

class _InfoPanel extends StatefulWidget {
  const _InfoPanel({required this.state});
  final StageState state;

  @override
  State<_InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<_InfoPanel> {
  late Timer _clockTimer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) setState(() => _time = '$h:$m:$s');
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final current = state.current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clock
          Row(
            children: [
              Text(
                _time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (state.rehearsal) const _RehearsalTag(),
            ],
          ),

          const Divider(color: AppColors.surfaceControl, height: 24),

          if (current != null) ...[
            Text(
              current.itemTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Slide ${current.slideIndex + 1} / ${current.slideCount}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            // Large enough to read from the pulpit: this is the number the
            // preacher is looking for.
            if (state.isLive && state.itemStartedAt != null) ...[
              const SizedBox(height: 10),
              ItemTimer(
                startedAt: state.itemStartedAt,
                plannedSecs: state.plannedSecs,
                fontSize: 22,
              ),
            ],
            if (current.chords?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACORDES',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current.chords!,
                      style: const TextStyle(
                        color: Color(0xFF5AC8FA),
                        fontSize: 12,
                        fontFamily: 'Courier',
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (current.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.note.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.note.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 12, color: AppColors.note),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        current.notes!,
                        style: const TextStyle(color: AppColors.note, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            const Text(
              'Sin slide activo',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
            ),

          const Spacer(),

          // Overlay status
          if (state.overlayVisible && (state.overlayText?.isNotEmpty ?? false))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.subtitles_outlined, size: 12, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.overlayText!,
                      style: const TextStyle(color: AppColors.success, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Countdown status
          if (state.countdownActive && state.countdownEnd != null)
            _CountdownChip(end: state.countdownEnd!),
        ],
      ),
    );
  }
}

class _CountdownChip extends StatefulWidget {
  const _CountdownChip({required this.end});
  final DateTime end;

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  late Timer _t;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _update();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final r = widget.end.difference(DateTime.now());
    final d = r.isNegative ? Duration.zero : r;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (mounted) setState(() => _label = '$m:$s');
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            _label,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Says a rehearsal is running, so nobody on the platform mistakes it for the
/// service.
class _RehearsalTag extends StatelessWidget {
  const _RehearsalTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
    ),
    child: const Text(
      'ENSAYO',
      style: TextStyle(
        color: AppColors.warning,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}
