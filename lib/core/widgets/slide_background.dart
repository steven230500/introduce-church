import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../backgrounds/background_cache.dart';
import '../models/slide_template.dart';
import '../motion/motion_scenes.dart';

/// How much a moving background may move at this point in the tree.
enum MotionLevel {
  /// A still frame. Thumbnails, lists, the stage display: dozens of designs on
  /// screen at once, and none of them is what the room is looking at.
  still,

  /// Painted scenes move; a video shows its still frame. For previews on the
  /// operator's screen, where a second and third copy of a playing loop would
  /// cost the machine running the service more than it shows the operator.
  scenes,

  /// Everything plays. The projector, and the design editor.
  all,
}

/// Sets the [MotionLevel] for every background below it.
class SlideMotion extends InheritedWidget {
  const SlideMotion({super.key, required this.level, required super.child});

  final MotionLevel level;

  /// Still, when nothing above has said otherwise: a background that is not
  /// asked to move costs nothing.
  static MotionLevel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SlideMotion>()?.level ?? MotionLevel.still;

  @override
  bool updateShouldNotify(SlideMotion oldWidget) => oldWidget.level != level;
}

/// What a design's text sits on.
class SlideBackground extends StatelessWidget {
  const SlideBackground({super.key, required this.template});

  final SlideTemplate template;

  /// The moment a still scene is drawn at: far enough in that every scene has
  /// something in it, and the same everywhere, so a thumbnail looks the same
  /// each time it is drawn.
  static const stillMoment = 12.0;

  @override
  Widget build(BuildContext context) {
    final level = SlideMotion.of(context);
    final fallback = ColoredBox(color: Color(template.bgColor), child: const SizedBox.expand());
    return switch (template.bgType) {
      BackgroundType.solid => fallback,
      BackgroundType.gradient => _gradient(),
      BackgroundType.image =>
        template.bgImagePath == null
            ? fallback
            : _Darkened(
                opacity: template.bgOverlayOpacity,
                child: _Picture(source: template.bgImagePath!, fallback: template.bgColor),
              ),
      // A scene this version does not know - saved by a newer copy of the app
      // - shows its colour, which is the closest thing to it on hand.
      BackgroundType.motion =>
        MotionSceneX.knows(template.bgMotion)
            ? _Darkened(
                opacity: template.bgOverlayOpacity,
                child: _MotionScene(
                  scene: MotionSceneX.fromId(template.bgMotion),
                  animate: level != MotionLevel.still,
                ),
              )
            : fallback,
      BackgroundType.video =>
        template.bgVideoPath == null
            ? fallback
            : _Darkened(
                opacity: template.bgOverlayOpacity,
                child: level == MotionLevel.all
                    ? _Loop(
                        source: template.bgVideoPath!,
                        poster: template.bgPosterPath,
                        fallback: template.bgColor,
                      )
                    : template.bgPosterPath == null
                    ? fallback
                    : _Picture(source: template.bgPosterPath!, fallback: template.bgColor),
              ),
    };
  }

  Widget _gradient() {
    final rad = template.bgGradientAngle * math.pi / 180;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-math.sin(rad), -math.cos(rad)),
          end: Alignment(math.sin(rad), math.cos(rad)),
          colors: [Color(template.bgColor), Color(template.bgGradientEnd)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// A picture with the darkening layer over it that keeps text readable.
class _Darkened extends StatelessWidget {
  const _Darkened({required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (opacity > 0) ColoredBox(color: Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0))),
    ],
  );
}

/// A still image from this machine or from the server, filling the slide.
///
/// A remote one is read from the background cache when it has been saved
/// there, so a design keeps its picture on a Sunday without internet.
class _Picture extends StatefulWidget {
  const _Picture({required this.source, required this.fallback});

  final String source;
  final int fallback;

  @override
  State<_Picture> createState() => _PictureState();
}

class _PictureState extends State<_Picture> {
  late Future<String> _resolved = BackgroundCache.instance.playable(widget.source);

  @override
  void didUpdateWidget(_Picture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _resolved = BackgroundCache.instance.playable(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: Color(widget.fallback));
    return FutureBuilder<String>(
      future: _resolved,
      // Until the cache answers, the address itself: the image cache usually
      // already has it, and a frame of plain colour flickers.
      initialData: widget.source,
      builder: (context, snapshot) {
        final path = snapshot.data ?? widget.source;
        final remote = path.startsWith('http://') || path.startsWith('https://');
        return remote
            ? Image.network(
                path,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              );
      },
    );
  }
}

/// One of the app's own scenes, drawn at the shared clock.
class _MotionScene extends StatefulWidget {
  const _MotionScene({required this.scene, required this.animate});

  final MotionScene scene;
  final bool animate;

  @override
  State<_MotionScene> createState() => _MotionSceneState();
}

class _MotionSceneState extends State<_MotionScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<double> _moment;

  @override
  void initState() {
    super.initState();
    _moment = ValueNotifier(widget.animate ? motionClock() : SlideBackground.stillMoment);
    _ticker = createTicker((_) => _moment.value = motionClock());
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(_MotionScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _ticker.start();
    } else {
      _ticker.stop();
      _moment.value = SlideBackground.stillMoment;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _moment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: _moment,
      builder: (context, t, _) =>
          CustomPaint(painter: widget.scene.painter(t), child: const SizedBox.expand()),
    ),
  );
}

/// A church's video loop, playing without sound for as long as it is shown.
class _Loop extends StatefulWidget {
  const _Loop({required this.source, required this.poster, required this.fallback});

  final String source;
  final String? poster;
  final int fallback;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> {
  late final Player _player = Player(configuration: const PlayerConfiguration(muted: true));
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.setPlaylistMode(PlaylistMode.loop);
    _open(widget.source);
  }

  @override
  void didUpdateWidget(_Loop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _open(widget.source);
  }

  Future<void> _open(String source) async {
    final playable = await BackgroundCache.instance.playable(source);
    if (!mounted) return;
    await _player.open(Media(playable));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // The still frame under the video, so the moment before the first frame
      // decodes is the picture rather than a flash of black.
      if (widget.poster != null)
        _Picture(source: widget.poster!, fallback: widget.fallback)
      else
        ColoredBox(color: Color(widget.fallback)),
      Video(
        controller: _controller,
        fit: BoxFit.cover,
        fill: const Color(0x00000000),
        controls: NoVideoControls,
        // The projector window is rarely the focused one; the loop must not
        // stop because the operator clicked on their own screen.
        pauseUponEnteringBackgroundMode: false,
      ),
    ],
  );
}
