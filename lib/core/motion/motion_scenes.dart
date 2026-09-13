import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The animated scenes that come with the app: behind the words of a waiting
/// screen, and behind the lyrics of a design.
///
/// Painted, not played. A video loop would be tens of megabytes per scene, has
/// a visible seam where it restarts, and looks soft on a 4K projector. These
/// are a few hundred lines of geometry: they weigh nothing, work with no
/// internet, are sharp at any resolution, and never loop visibly because every
/// frame is a function of time rather than a position in a file.
///
/// Every painter is a pure function of [t] - seconds since the scene started -
/// and the size it is given. The same t draws the same frame on the operator's
/// preview and on the projector, and a test can draw any moment without a
/// clock.
///
/// New scenes go at the end: the order is the order they are offered in, and
/// an operator who has learned where theirs sits should find it there.
enum MotionScene { aurora, light, waves, sunrise, stars, calm, mist, rays, silk }

extension MotionSceneX on MotionScene {
  /// The id that travels over the wire and is stored.
  String get id => name;

  static MotionScene fromId(String? id) =>
      MotionScene.values.where((scene) => scene.id == id).firstOrNull ?? MotionScene.aurora;

  /// Whether [id] names a scene this version can draw.
  static bool knows(String? id) => MotionScene.values.any((scene) => scene.id == id);

  CustomPainter painter(double t) => switch (this) {
    MotionScene.aurora => AuroraPainter(t),
    MotionScene.light => LightPainter(t),
    MotionScene.waves => WavesPainter(t),
    MotionScene.sunrise => SunrisePainter(t),
    MotionScene.stars => StarsPainter(t),
    MotionScene.calm => CalmPainter(t),
    MotionScene.mist => MistPainter(t),
    MotionScene.rays => RaysPainter(t),
    MotionScene.silk => SilkPainter(t),
  };

  /// The one colour that stands for the scene.
  ///
  /// Two jobs. It is what the design editor judges text against, since a
  /// moving picture has no single colour to measure. And it is stored as the
  /// design's plain colour too, so a copy of the app too old to know this
  /// scene shows something close to it rather than whatever colour was there
  /// before.
  int get baseColor => switch (this) {
    MotionScene.aurora => 0xFF0E1838,
    MotionScene.light => 0xFF24160B,
    MotionScene.waves => 0xFF23324F,
    MotionScene.sunrise => 0xFF6A2C45,
    MotionScene.stars => 0xFF080C20,
    MotionScene.calm => 0xFF1F3445,
    MotionScene.mist => 0xFF1D2733,
    MotionScene.rays => 0xFF1A1D2B,
    MotionScene.silk => 0xFF1A1233,
  };
}

/// The moment every moving background on this machine is drawn at.
///
/// Wall-clock seconds, not seconds since something started. The projector and
/// the operator's preview run in separate windows with separate clocks of
/// their own, and this is the one they share, so the thumbnail of the output
/// shows the frame the room is looking at. It also means two slides with the
/// same background cross-fade into each other without the background jumping,
/// because both are drawing the same instant.
double motionClock() => DateTime.now().microsecondsSinceEpoch / 1e6;

/// A stable pseudo-random number in [0, 1) for a given seed.
///
/// Particles are placed with this instead of a Random, so the forty points of
/// light are in the same places on the preview and on the projector, and in
/// the same places every time the scene comes back.
double seeded(int seed) {
  final x = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// Northern lights: ribbons of colour drifting across a night sky.
///
/// Soft enough to put a title over and still calm enough that nobody watches
/// the background instead of the room.
class AuroraPainter extends CustomPainter {
  const AuroraPainter(this.t);
  final double t;

  static const _sky = [Color(0xFF050814), Color(0xFF0B1330), Color(0xFF101A3D)];
  static const _ribbons = [Color(0xFF2EE6B6), Color(0xFF38B6FF), Color(0xFF9B6BFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _sky,
        ).createShader(rect),
    );

    for (var band = 0; band < _ribbons.length; band++) {
      final phase = t * (0.08 + band * 0.025) + band * 1.9;
      final baseline = size.height * (0.30 + band * 0.13);
      final amplitude = size.height * (0.07 + band * 0.02);
      final thickness = size.height * (0.22 - band * 0.03);

      final path = Path()..moveTo(0, baseline);
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final u = i / steps;
        final y =
            baseline +
            math.sin(u * math.pi * 2.2 + phase) * amplitude +
            math.sin(u * math.pi * 5.1 - phase * 1.4) * amplitude * 0.35;
        path.lineTo(x, y);
      }
      for (var i = steps; i >= 0; i--) {
        final x = size.width * i / steps;
        final u = i / steps;
        final y =
            baseline + thickness + math.sin(u * math.pi * 1.7 + phase * 0.8) * amplitude * 0.6;
        path.lineTo(x, y);
      }
      path.close();

      final colour = _ribbons[band];
      // Fades in and out on its own slow breath so the three never peak at
      // once, which is what makes it read as light rather than as stripes.
      final breath = 0.55 + 0.45 * math.sin(t * 0.21 + band * 2.1);
      // Blurred, because a crisp edge is what turns an aurora into a range of
      // hills. The sigma scales with the screen so it looks the same on a
      // laptop preview and on a 4K wall.
      canvas.drawPath(
        path,
        Paint()
          ..color = colour.withValues(alpha: 0.42 * breath)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.045)
          ..blendMode = BlendMode.plus,
      );
      // A thinner, brighter core along the top edge, where real aurora is
      // brightest.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.012
          ..color = colour.withValues(alpha: 0.30 * breath)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.012)
          ..blendMode = BlendMode.plus,
      );
    }

    _vignette(canvas, size);
  }

  @override
  bool shouldRepaint(AuroraPainter old) => old.t != t;
}

/// Points of warm light rising slowly out of the dark, out of focus.
class LightPainter extends CustomPainter {
  const LightPainter(this.t);
  final double t;

  static const _count = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.4),
          radius: 1.1,
          colors: [Color(0xFF3A2410), Color(0xFF1A0F07), Color(0xFF080503)],
        ).createShader(rect),
    );

    final shortSide = size.shortestSide;
    for (var i = 0; i < _count; i++) {
      // Nearer lights are bigger, dimmer and faster, which is what gives the
      // field depth without any actual depth.
      final depth = seeded(i * 7 + 1);
      final radius = shortSide * (0.012 + depth * 0.05);
      final speed = 0.006 + depth * 0.018;
      final rise = (seeded(i * 13 + 5) + t * speed) % 1.0;

      final sway = math.sin(t * (0.15 + depth * 0.2) + i) * size.width * 0.015;
      final x = seeded(i * 3 + 11) * size.width + sway;
      final y = size.height * (1.15 - rise * 1.3);

      // Fade in as it appears at the bottom and out as it leaves at the top.
      final life = math.sin(rise * math.pi);
      final twinkle = 0.75 + 0.25 * math.sin(t * (0.8 + depth) + i * 1.7);
      final alpha = (0.22 + (1 - depth) * 0.45) * life * twinkle;

      final warm = Color.lerp(const Color(0xFFFFC46B), const Color(0xFFFFE9B8), seeded(i * 5 + 3))!;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              warm.withValues(alpha: alpha),
              warm.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius))
          ..blendMode = BlendMode.plus,
      );
    }

    _vignette(canvas, size);
  }

  @override
  bool shouldRepaint(LightPainter old) => old.t != t;
}

/// A calm sea at dusk: layers of water moving at different speeds.
class WavesPainter extends CustomPainter {
  const WavesPainter(this.t);
  final double t;

  static const _layers = [
    Color(0xFF123A5C),
    Color(0xFF0E2F4D),
    Color(0xFF0A2440),
    Color(0xFF071A31),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A4A), Color(0xFF3A4E73), Color(0xFF6E7C9B)],
          stops: [0, 0.55, 0.72],
        ).createShader(rect),
    );

    // The low sun behind the water, so the scene has somewhere for the eye to
    // rest that is not the text.
    final sun = Offset(size.width * 0.5, size.height * 0.62);
    canvas.drawCircle(
      sun,
      size.height * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFD29A).withValues(alpha: 0.35), const Color(0x00FFD29A)],
        ).createShader(Rect.fromCircle(center: sun, radius: size.height * 0.5)),
    );

    for (var layer = 0; layer < _layers.length; layer++) {
      final top = size.height * (0.62 + layer * 0.09);
      final amplitude = size.height * (0.012 + layer * 0.008);
      final speed = 0.25 + layer * 0.18;
      final length = 1.4 - layer * 0.18;

      final path = Path()..moveTo(0, size.height);
      const steps = 60;
      for (var i = 0; i <= steps; i++) {
        final u = i / steps;
        final y =
            top +
            math.sin(u * math.pi * 2 * length * 2 + t * speed + layer) * amplitude +
            math.sin(u * math.pi * 2 * length * 5 - t * speed * 0.7) * amplitude * 0.3;
        path.lineTo(size.width * u, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(path, Paint()..color = _layers[layer].withValues(alpha: 0.85));
    }

    _vignette(canvas, size);
  }

  @override
  bool shouldRepaint(WavesPainter old) => old.t != t;
}

/// A slow sunrise: a warm glow that breathes and rays that turn.
class SunrisePainter extends CustomPainter {
  const SunrisePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0E2E), Color(0xFF5A2346), Color(0xFFC2533F), Color(0xFFF2A65A)],
          stops: [0, 0.45, 0.8, 1],
        ).createShader(rect),
    );

    final centre = Offset(size.width * 0.5, size.height * 1.02);
    final reach = size.longestSide * 0.95;

    // Rays: long thin wedges turning so slowly that nobody sees them move,
    // only that the light is alive.
    const rays = 18;
    final turn = t * 0.012;
    for (var i = 0; i < rays; i++) {
      final angle = math.pi + (i / rays) * math.pi + turn;
      final spread = 0.035 + 0.02 * seeded(i + 40);
      final ray = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(
          centre.dx + math.cos(angle - spread) * reach,
          centre.dy + math.sin(angle - spread) * reach,
        )
        ..lineTo(
          centre.dx + math.cos(angle + spread) * reach,
          centre.dy + math.sin(angle + spread) * reach,
        )
        ..close();
      final flicker = 0.5 + 0.5 * math.sin(t * 0.3 + i * 1.3);
      canvas.drawPath(
        ray,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.bottomCenter,
            radius: 1,
            colors: [
              const Color(0xFFFFE3A3).withValues(alpha: 0.10 * flicker),
              const Color(0x00FFE3A3),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: reach))
          ..blendMode = BlendMode.plus,
      );
    }

    final breath = 0.85 + 0.15 * math.sin(t * 0.25);
    final glow = size.height * 0.55 * breath;
    canvas.drawCircle(
      centre,
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF1C9).withValues(alpha: 0.85),
            const Color(0xFFFFB86B).withValues(alpha: 0.35),
            const Color(0x00FFB86B),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: glow)),
    );

    _vignette(canvas, size, strength: 0.35);
  }

  @override
  bool shouldRepaint(SunrisePainter old) => old.t != t;
}

/// A clear night: stars that twinkle and drift, and a faint band of the sky.
class StarsPainter extends CustomPainter {
  const StarsPainter(this.t);
  final double t;

  static const _count = 180;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF02030A), Color(0xFF070B1E), Color(0xFF0D1030)],
        ).createShader(rect),
    );

    // The band of the galaxy, a soft diagonal haze.
    final band = Offset(size.width * (0.5 + 0.05 * math.sin(t * 0.03)), size.height * 0.45);
    canvas.save();
    canvas.translate(band.dx, band.dy);
    canvas.rotate(-0.45);
    // A radial gradient is round whatever rectangle it is given, so the canvas
    // is squashed instead to stretch the glow into a band.
    canvas.scale(1, 0.28);
    final haze = Rect.fromCircle(center: Offset.zero, radius: size.longestSide * 0.8);
    canvas.drawCircle(
      Offset.zero,
      haze.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7B68EE).withValues(alpha: 0.22),
            const Color(0xFF4B3F9E).withValues(alpha: 0.08),
            const Color(0x004B3F9E),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(haze),
    );
    canvas.restore();

    final drift = t * 0.004;
    for (var i = 0; i < _count; i++) {
      final x = ((seeded(i * 2 + 1) + drift * (0.3 + seeded(i + 900))) % 1.0) * size.width;
      final y = seeded(i * 2 + 2) * size.height;
      final bright = seeded(i * 7 + 3);
      final twinkle = 0.5 + 0.5 * math.sin(t * (0.6 + bright * 2.2) + i * 3.1);
      final radius = size.shortestSide * (0.0012 + bright * bright * 0.0035);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25 + 0.7 * bright * twinkle),
      );
    }

    _vignette(canvas, size);
  }

  @override
  bool shouldRepaint(StarsPainter old) => old.t != t;
}

/// Almost nothing: two soft fields of colour moving past each other.
///
/// For the church that wants the name on the screen and nothing competing
/// with it.
class CalmPainter extends CustomPainter {
  const CalmPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0E1116));

    void blob(Color colour, double phase, double scale) {
      final centre = Offset(
        size.width * (0.5 + 0.28 * math.sin(t * 0.05 + phase)),
        size.height * (0.5 + 0.22 * math.cos(t * 0.04 + phase * 1.3)),
      );
      final radius = size.longestSide * scale;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [colour.withValues(alpha: 0.62), colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    blob(const Color(0xFF3A7CA5), 0, 0.55);
    blob(const Color(0xFF6A4C9C), 2.4, 0.5);
    blob(const Color(0xFF2A9D8F), 4.1, 0.38);

    _vignette(canvas, size, strength: 0.4);
  }

  @override
  bool shouldRepaint(CalmPainter old) => old.t != t;
}

/// Fog drifting across a dark valley.
///
/// Made for lyrics: almost no contrast of its own, so the words are the
/// brightest thing on the wall, and the movement is slow enough that nobody
/// follows it with their eyes.
class MistPainter extends CustomPainter {
  const MistPainter(this.t);
  final double t;

  static const _bands = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E141C), Color(0xFF1D2733), Color(0xFF2B3542)],
        ).createShader(rect),
    );

    // A moon behind the fog, far enough gone that it is only a lighter patch.
    final moon = Offset(size.width * 0.68, size.height * 0.22);
    final moonGlow = size.height * 0.6;
    canvas.drawCircle(
      moon,
      moonGlow,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFB9CCE0).withValues(alpha: 0.16), const Color(0x00B9CCE0)],
        ).createShader(Rect.fromCircle(center: moon, radius: moonGlow)),
    );

    void fog(int i) {
      final depth = seeded(i * 11 + 2);
      final bandWidth = size.width * (0.9 + depth * 0.7);
      final bandHeight = size.height * (0.07 + seeded(i * 5 + 9) * 0.08);
      final y = size.height * (0.42 + i * 0.075) + math.sin(t * 0.03 + i) * size.height * 0.015;
      // Nearer fog moves faster, and alternate bands move the other way, so
      // it reads as air with depth rather than one sheet sliding sideways.
      final direction = i.isEven ? 1 : -1;
      final travel = (seeded(i * 17 + 4) + direction * t * (0.004 + depth * 0.006)) % 1.0;
      final x = -size.width * 0.5 + travel * size.width * 2;
      final breath = 0.75 + 0.25 * math.sin(t * 0.07 + i * 1.3);
      final paint = Paint()
        ..color = const Color(0xFFC3D0DE).withValues(alpha: (0.12 + (1 - depth) * 0.12) * breath)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.045);
      // Drawn a full lap either side as well, so a band leaving one edge is
      // already arriving at the other instead of popping into existence.
      for (final lap in const [-2.0, 0.0, 2.0]) {
        final centre = Offset(x + lap * size.width, y);
        if (centre.dx + bandWidth < 0 || centre.dx - bandWidth > size.width) continue;
        canvas.drawOval(
          Rect.fromCenter(center: centre, width: bandWidth, height: bandHeight),
          paint,
        );
      }
    }

    // Hills, so the fog has something to lie in. Without a horizon it read as
    // a smudge on the lens.
    void hills(double top, double height, double seed, Color colour) {
      final path = Path()..moveTo(0, size.height);
      const steps = 40;
      for (var s = 0; s <= steps; s++) {
        final u = s / steps;
        final y =
            size.height * top +
            math.sin(u * math.pi * 1.4 + seed) * size.height * height +
            math.sin(u * math.pi * 3.7 + seed * 2) * size.height * height * 0.35;
        path.lineTo(size.width * u, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = colour);
    }

    hills(0.60, 0.05, 0.8, const Color(0xFF1A232E));
    for (var i = 0; i < 4; i++) {
      fog(i);
    }
    hills(0.76, 0.06, 2.6, const Color(0xFF0F151C));
    for (var i = 4; i < _bands; i++) {
      fog(i);
    }

    _vignette(canvas, size, strength: 0.5);
  }

  @override
  bool shouldRepaint(MistPainter old) => old.t != t;
}

/// Light falling from above through a dim room, with dust turning in it.
class RaysPainter extends CustomPainter {
  const RaysPainter(this.t);
  final double t;

  static const _rays = 11;
  static const _motes = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C3148), Color(0xFF151824), Color(0xFF0A0B11)],
        ).createShader(rect),
    );

    final source = Offset(size.width * (0.5 + 0.04 * math.sin(t * 0.02)), -size.height * 0.3);
    final reach = size.height * 1.5;

    for (var i = 0; i < _rays; i++) {
      final spreadOut = (i / (_rays - 1)) - 0.5;
      final angle = math.pi / 2 + spreadOut * 1.1 + 0.04 * math.sin(t * 0.045 + i * 1.7);
      final half = 0.018 + seeded(i + 70) * 0.03;
      final ray = Path()
        ..moveTo(source.dx, source.dy)
        ..lineTo(
          source.dx + math.cos(angle - half) * reach,
          source.dy + math.sin(angle - half) * reach,
        )
        ..lineTo(
          source.dx + math.cos(angle + half) * reach,
          source.dy + math.sin(angle + half) * reach,
        )
        ..close();
      // Each ray fades on its own slow cycle, the way light through a window
      // comes and goes as clouds pass.
      final strength = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 0.11 + i * 2.3));
      canvas.drawPath(
        ray,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF3D6).withValues(alpha: 0.22 * strength),
              const Color(0xFFFFF3D6).withValues(alpha: 0.05 * strength),
              const Color(0x00FFF3D6),
            ],
            stops: const [0.15, 0.6, 1],
          ).createShader(Rect.fromCircle(center: source, radius: reach))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.02)
          ..blendMode = BlendMode.plus,
      );
    }

    final haze = Offset(size.width * 0.5, 0);
    canvas.drawCircle(
      haze,
      size.height * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFF3D6).withValues(alpha: 0.18), const Color(0x00FFF3D6)],
        ).createShader(Rect.fromCircle(center: haze, radius: size.height * 0.7)),
    );

    final shortSide = size.shortestSide;
    for (var i = 0; i < _motes; i++) {
      final fall = (seeded(i * 9 + 1) + t * (0.004 + seeded(i * 3 + 7) * 0.006)) % 1.0;
      final x =
          size.width * (0.2 + seeded(i * 4 + 5) * 0.6) + math.sin(t * 0.2 + i) * size.width * 0.02;
      final y = size.height * fall;
      final twinkle = 0.5 + 0.5 * math.sin(t * (0.9 + seeded(i + 30)) + i * 2.1);
      // Only visible where the light is, which is towards the top.
      final lit = (1 - fall).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        shortSide * (0.0015 + seeded(i * 6 + 2) * 0.0025),
        Paint()
          ..color = const Color(0xFFFFF3D6).withValues(alpha: 0.5 * twinkle * lit)
          ..blendMode = BlendMode.plus,
      );
    }

    _vignette(canvas, size, strength: 0.5);
  }

  @override
  bool shouldRepaint(RaysPainter old) => old.t != t;
}

/// A ribbon of fine threads folding over itself, like silk in slow water.
class SilkPainter extends CustomPainter {
  const SilkPainter(this.t);
  final double t;

  static const _threads = 38;
  static const _steps = 90;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C0A1D), Color(0xFF1A1233), Color(0xFF0A1530)],
        ).createShader(rect),
    );

    double yAt(double u, double k) =>
        size.height *
        (0.55 +
            0.16 * math.sin(u * math.pi * 1.6 + t * 0.12) +
            // Scaled by the thread's place in the ribbon, so the ribbon is wide
            // in some places and pinches to a twist in others.
            k * 0.26 * math.sin(u * math.pi * 1.3 + t * 0.07 + 1.1) +
            0.045 * math.sin(u * math.pi * 4.2 - t * 0.09 + k * 2));

    // A glow along the middle of the ribbon, so it lights the dark around it.
    final centre = Path()..moveTo(0, yAt(0, 0));
    for (var s = 1; s <= _steps; s++) {
      final u = s / _steps;
      centre.lineTo(size.width * u, yAt(u, 0));
    }
    canvas.drawPath(
      centre,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.16
        ..color = const Color(0xFF8A5CF6).withValues(alpha: 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.08),
    );

    for (var i = 0; i < _threads; i++) {
      final k = i / (_threads - 1) - 0.5;
      final path = Path()..moveTo(0, yAt(0, k));
      for (var s = 1; s <= _steps; s++) {
        final u = s / _steps;
        path.lineTo(size.width * u, yAt(u, k));
      }
      final colour = Color.lerp(const Color(0xFFE56BD6), const Color(0xFF5BC8FA), k + 0.5)!;
      final edge = 1 - (k.abs() * 1.6).clamp(0.0, 0.85);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, size.height * 0.0018)
          ..color = colour.withValues(alpha: 0.42 * edge)
          ..blendMode = BlendMode.plus,
      );
    }

    _vignette(canvas, size, strength: 0.5);
  }

  @override
  bool shouldRepaint(SilkPainter old) => old.t != t;
}

/// Darkens the corners, which pulls the eye to the middle where the text is and
/// hides the edges of a projector that is not quite square to the wall.
void _vignette(Canvas canvas, Size size, {double strength = 0.55}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          const Color(0x00000000),
          const Color(0xFF000000).withValues(alpha: strength),
        ],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
}
