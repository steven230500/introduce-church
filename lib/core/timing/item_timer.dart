import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'service_clock.dart';

/// How long the item on the screen has been there, against its plan.
///
/// "3:12 / 4:30" in the ordinary colour, amber for the last fifth of the plan,
/// red past it with how far over. Without a plan, only the time.
class ItemTimer extends StatefulWidget {
  const ItemTimer({
    super.key,
    required this.startedAt,
    this.plannedSecs,
    this.fontSize = 13,
    this.now,
  });

  final DateTime? startedAt;
  final int? plannedSecs;
  final double fontSize;
  final DateTime Function()? now;

  @override
  State<ItemTimer> createState() => _ItemTimerState();
}

class _ItemTimerState extends State<ItemTimer> {
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
    final started = widget.startedAt;
    if (started == null) return const SizedBox.shrink();
    final elapsed = (widget.now ?? DateTime.now)().difference(started);
    final reading = timerReading(elapsed, widget.plannedSecs);
    final colour = switch (reading.pace) {
      TimerPace.onTime => AppColors.textSecondary,
      TimerPace.closing => AppColors.warning,
      TimerPace.over => AppColors.danger,
    };
    return Semantics(
      label: reading.text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: widget.fontSize, color: colour),
          SizedBox(width: widget.fontSize * 0.3),
          Text(
            reading.text,
            style: TextStyle(
              color: colour,
              fontSize: widget.fontSize,
              fontWeight: reading.pace == TimerPace.over ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

enum TimerPace { onTime, closing, over }

/// What an item timer says for [elapsed] against a plan of [plannedSecs].
({String text, TimerPace pace}) timerReading(Duration elapsed, int? plannedSecs) {
  final shown = elapsed.isNegative ? Duration.zero : elapsed;
  if (plannedSecs == null || plannedSecs <= 0) {
    return (text: clockText(shown), pace: TimerPace.onTime);
  }
  final plan = Duration(seconds: plannedSecs);
  if (shown > plan) {
    return (
      text: '${clockText(shown)} / ${clockText(plan)}  +${clockText(shown - plan)}',
      pace: TimerPace.over,
    );
  }
  final closing = shown.inSeconds >= plannedSecs * 0.8;
  return (
    text: '${clockText(shown)} / ${clockText(plan)}',
    pace: closing ? TimerPace.closing : TimerPace.onTime,
  );
}
