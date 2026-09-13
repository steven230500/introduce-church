import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/motion/motion_scenes.dart';

void main() {
  // A painter that throws takes the projector down to a red error screen in
  // front of the whole room. Every scene is drawn at many moments, at a
  // projector size and at a thumbnail size, and none may throw.
  for (final scene in MotionScene.values) {
    test('${scene.id} draws at every moment and size', () {
      // Including the wall clock, which is the moment a design's background
      // is actually drawn at: seconds since 1970, not since the scene began.
      final now = motionClock();
      for (final size in const [Size(1920, 1080), Size(116, 65), Size(1, 1)]) {
        for (final t in [0.0, 0.5, 7.3, 60.0, 3600.0, 86400.0, now, now + 1 / 60]) {
          final recorder = ui.PictureRecorder();
          scene.painter(t).paint(Canvas(recorder), size);
          recorder.endRecording();
        }
      }
    });
  }

  test('the same moment draws the same frame, so preview and projector agree', () {
    expect(seeded(42), seeded(42));
    expect(seeded(42), isNot(seeded(43)));
    for (var i = 0; i < 1000; i++) {
      expect(seeded(i), inInclusiveRange(0, 1));
    }
  });

  test('a scene only repaints when time moves', () {
    const a = AuroraPainter(10);
    expect(a.shouldRepaint(const AuroraPainter(10)), isFalse);
    expect(a.shouldRepaint(const AuroraPainter(10.016)), isTrue);
  });

  test('a scene id this version does not know is recognised as unknown', () {
    // A design saved by a newer copy of the app must not be drawn as some
    // other scene; it falls back to its colour instead.
    expect(MotionSceneX.knows('mist'), isTrue);
    expect(MotionSceneX.knows('holograma'), isFalse);
    expect(MotionSceneX.knows(null), isFalse);
  });

  test('scene ids are stable, because designs store them', () {
    expect(MotionScene.values.map((s) => s.id), [
      'aurora',
      'light',
      'waves',
      'sunrise',
      'stars',
      'calm',
      'mist',
      'rays',
      'silk',
    ]);
  });
}
