import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'waiting_scenes.dart';

/// What the screen shows while nothing else is on it, and whether it is up.
class WaitingConfig extends Equatable {
  const WaitingConfig({
    this.active = false,
    this.scene = WaitingScene.aurora,
    this.title = '',
    this.subtitle = '',
    this.showClock = false,
  });

  final bool active;
  final WaitingScene scene;

  /// Usually the church's name.
  final String title;

  /// "Bienvenidos", "El servicio comienza pronto", or nothing.
  final String subtitle;

  /// The time of day under the text. A countdown, when one is running, takes
  /// its place: counting down to the service is the better thing to show.
  final bool showClock;

  WaitingConfig copyWith({
    bool? active,
    WaitingScene? scene,
    String? title,
    String? subtitle,
    bool? showClock,
  }) => WaitingConfig(
    active: active ?? this.active,
    scene: scene ?? this.scene,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    showClock: showClock ?? this.showClock,
  );

  Map<String, dynamic> toJson() => {
    'active': active,
    'scene': scene.id,
    'title': title,
    'subtitle': subtitle,
    'clock': showClock,
  };

  /// Reads what arrived over the wire. Anything missing or malformed reads as
  /// "no waiting screen", which is the safe way to be wrong: the room sees
  /// whatever was already meant to be on the screen.
  static WaitingConfig fromJson(Object? raw) {
    if (raw is! Map) return const WaitingConfig();
    return WaitingConfig(
      active: raw['active'] == true,
      scene: WaitingSceneX.fromId(raw['scene'] as String?),
      title: raw['title'] as String? ?? '',
      subtitle: raw['subtitle'] as String? ?? '',
      showClock: raw['clock'] == true,
    );
  }

  @override
  List<Object?> get props => [active, scene, title, subtitle, showClock];
}

/// A waiting scene, moving, with the church's words over it.
///
/// Draws at whatever size it is given and keeps its proportions, so the same
/// widget is the full projector output and a thumbnail in the picker.
class WaitingScreen extends StatefulWidget {
  const WaitingScreen({
    super.key,
    required this.config,
    this.countdownEnd,
    this.animate = true,
    this.frozenAt = 12,
    this.now,
  });

  final WaitingConfig config;

  /// When a countdown is running it replaces the clock.
  final DateTime? countdownEnd;

  /// Off for tests and for anywhere a still frame is enough.
  final bool animate;

  /// The moment drawn when [animate] is off.
  final double frozenAt;

  final DateTime Function()? now;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _elapsed = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _elapsed.value = widget.frozenAt;
    if (widget.animate) {
      // A ticker rather than an animation controller: the scene is a function
      // of elapsed time and never ends, so there is nothing to control.
      _ticker = createTicker((elapsed) {
        _elapsed.value = widget.frozenAt + elapsed.inMicroseconds / 1e6;
      })..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 540.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Only the painting repaints each frame; the text above it is laid
            // out once and left alone.
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _elapsed,
                builder: (context, t, _) => CustomPaint(painter: config.scene.painter(t)),
              ),
            ),
            _Words(
              config: config,
              height: height,
              countdownEnd: widget.countdownEnd,
              animate: widget.animate,
              now: widget.now ?? DateTime.now,
            ),
          ],
        );
      },
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({
    required this.config,
    required this.height,
    required this.countdownEnd,
    required this.animate,
    required this.now,
  });

  final WaitingConfig config;
  final double height;
  final DateTime? countdownEnd;
  final bool animate;
  final DateTime Function() now;

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 4))];

  @override
  Widget build(BuildContext context) {
    final showTime = countdownEnd != null || config.showClock;
    return Padding(
      // The projector's own safe area: text near the edge falls off a screen
      // that is not quite square to the wall.
      padding: EdgeInsets.symmetric(horizontal: height * 0.12, vertical: height * 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (config.title.isNotEmpty)
            Text(
              config.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFFFFF),
                fontSize: height * 0.105,
                fontWeight: FontWeight.w300,
                letterSpacing: height * 0.001,
                height: 1.1,
                shadows: _shadow,
              ),
            ),
          if (config.subtitle.isNotEmpty) ...[
            SizedBox(height: height * 0.025),
            Text(
              config.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xDDFFFFFF),
                fontSize: height * 0.048,
                fontWeight: FontWeight.w400,
                letterSpacing: height * 0.002,
                shadows: _shadow,
              ),
            ),
          ],
          if (showTime) ...[
            SizedBox(height: height * 0.06),
            _Clock(countdownEnd: countdownEnd, height: height, animate: animate, now: now),
          ],
        ],
      ),
    );
  }
}

/// The time of day, or the time left before a countdown ends.
class _Clock extends StatefulWidget {
  const _Clock({
    required this.countdownEnd,
    required this.height,
    required this.animate,
    required this.now,
  });

  final DateTime? countdownEnd;
  final double height;
  final bool animate;
  final DateTime Function() now;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final Ticker? _ticker;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = _read();
    _ticker = widget.animate
        ? Ticker((_) {
            final next = _read();
            // Only rebuild when the digits change, which is once a second, not
            // sixty times.
            if (next != _text && mounted) setState(() => _text = next);
          })
        : null;
    _ticker?.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  String _read() {
    final now = widget.now();
    final end = widget.countdownEnd;
    String two(int n) => n.toString().padLeft(2, '0');
    if (end != null) {
      final left = end.difference(now);
      if (left.isNegative) return '0:00';
      final minutes = left.inMinutes;
      return '$minutes:${two(left.inSeconds % 60)}';
    }
    return '${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: widget.height * (widget.countdownEnd != null ? 0.14 : 0.075),
        fontWeight: FontWeight.w200,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: _Words._shadow,
      ),
    );
  }
}
