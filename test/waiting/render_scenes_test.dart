import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/waiting/waiting_scenes.dart';

/// Writes a frame of every scene to disk when RENDER_SCENES_TO is set, so the
/// scenes can be looked at without launching the app. Skipped otherwise.
void main() {
  final out = Platform.environment['RENDER_SCENES_TO'];

  test('render every scene to an image', () async {
    if (out == null) return;
    const size = Size(960, 540);
    for (final scene in WaitingScene.values) {
      for (final t in [3.0, 40.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Offset.zero & size);
        scene.painter(t).paint(canvas, size);
        final image = await recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$out/${scene.id}_${t.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
  });
}
