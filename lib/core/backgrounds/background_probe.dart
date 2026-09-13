import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import 'background_standard.dart';

/// Reads what the background standard is checked against out of a file on
/// this machine.
abstract class BackgroundProbe {
  const BackgroundProbe();

  Future<BackgroundCandidate> read(String path);

  /// A still frame of a video, written next to the other temporary files, or
  /// null when one could not be taken. Every place that shows a design without
  /// playing it shows this frame.
  Future<File?> poster(String videoPath);
}

/// The probe the app uses: Flutter's own image decoder for stills, the video
/// player for loops.
class NativeBackgroundProbe extends BackgroundProbe {
  const NativeBackgroundProbe();

  /// How long a video gets to say how big and how long it is. A file that says
  /// nothing in this time is not one the projector will play either.
  static const _patience = Duration(seconds: 10);

  @override
  Future<BackgroundCandidate> read(String path) async {
    final file = File(path);
    final bytes = await file.length();
    try {
      return switch (BackgroundStandard.kindOf(path)) {
        BackgroundKind.image => await _readImage(path, bytes),
        BackgroundKind.video => await _withPlayer(path, (player) async {
          await _ready(player);
          return BackgroundCandidate(
            path: path,
            bytes: bytes,
            width: player.state.width,
            height: player.state.height,
            duration: player.state.duration,
          );
        }),
        null => BackgroundCandidate(path: path, bytes: bytes),
      };
    } catch (_) {
      // Unreadable is an answer the standard knows how to explain.
      return BackgroundCandidate(path: path, bytes: bytes);
    }
  }

  /// The header of the image, not the picture: the size is known without
  /// decoding forty megapixels to find it.
  Future<BackgroundCandidate> _readImage(String path, int bytes) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final candidate = BackgroundCandidate(
        path: path,
        bytes: bytes,
        width: descriptor.width,
        height: descriptor.height,
      );
      descriptor.dispose();
      return candidate;
    } finally {
      buffer.dispose();
    }
  }

  @override
  Future<File?> poster(String videoPath) async {
    try {
      return await _withPlayer(videoPath, (player) async {
        await _ready(player);
        // A second in, or a third of the way through a very short loop: the
        // first frame of a loop is often black while it fades in.
        final duration = player.state.duration;
        final at = duration > const Duration(seconds: 3)
            ? const Duration(seconds: 1)
            : duration ~/ 3;
        await player.seek(at);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final jpeg = await player.screenshot(format: 'image/jpeg');
        if (jpeg == null || jpeg.isEmpty) return null;
        final out = File(
          p.join(
            Directory.systemTemp.path,
            'introduce_poster_${DateTime.now().microsecondsSinceEpoch}.jpg',
          ),
        );
        await out.writeAsBytes(jpeg);
        return out;
      });
    } catch (_) {
      return null;
    }
  }

  Future<T> _withPlayer<T>(String path, Future<T> Function(Player player) use) async {
    final player = Player(configuration: const PlayerConfiguration(muted: true));
    // A video controller, though nothing is shown: without somewhere to draw,
    // the player never decodes a frame, so there is no size and no still.
    VideoController(player);
    try {
      await player.open(Media(path), play: false);
      return await use(player);
    } finally {
      await player.dispose();
    }
  }

  Future<void> _ready(Player player) async {
    bool known() =>
        (player.state.width ?? 0) > 0 &&
        (player.state.height ?? 0) > 0 &&
        player.state.duration > Duration.zero;
    if (known()) return;
    final done = Completer<void>();
    final subs = [
      player.stream.width.listen((_) => known() && !done.isCompleted ? done.complete() : null),
      player.stream.height.listen((_) => known() && !done.isCompleted ? done.complete() : null),
      player.stream.duration.listen((_) => known() && !done.isCompleted ? done.complete() : null),
    ];
    try {
      await done.future.timeout(_patience);
    } on TimeoutException {
      // Whatever is known by now is what the standard is checked against.
    } finally {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
  }
}
