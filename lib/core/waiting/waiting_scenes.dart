import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The animated backgrounds a church can leave on the screen while nothing
/// else is on it.
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
enum WaitingScene { aurora, light, waves, sunrise, stars, calm }

extension WaitingSceneX on WaitingScene {
  /// The id that travels over the wire and is stored.
  String get id => name;

  static WaitingScene fromId(String? id) =>
      WaitingScene.values.where((scene) => scene.id == id).firstOrNull ?? WaitingScene.aurora;

  CustomPainter painter(double t) => switch (this) {
    WaitingScene.aurora => AuroraPainter(t),
    WaitingScene.light => LightPainter(t),
    WaitingScene.waves => WavesPainter(t),
    WaitingScene.sunrise => SunrisePainter(t),
    WaitingScene.stars => StarsPainter(t),
    WaitingScene.calm => CalmPainter(t),
  };
}

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
