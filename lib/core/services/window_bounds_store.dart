import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Remembers where the control window was, so the app opens back where the
/// operator left it instead of jumping to the middle of the laptop screen
/// every Sunday.
///
/// It keeps its own file rather than joining the shared preferences: the
/// window is read and written from `main`, before dependency injection exists,
/// and the preferences instance the rest of the app uses caches the whole
/// document. Two writers over one cached document drop each other's keys.
class WindowBoundsStore {
  Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'window.json'));
  }

  Future<Rect?> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Rect.fromLTWH(
        (data['x'] as num).toDouble(),
        (data['y'] as num).toDouble(),
        (data['w'] as num).toDouble(),
        (data['h'] as num).toDouble(),
      );
    } catch (_) {
      // A corrupt file just means we fall back to the default placement.
      return null;
    }
  }

  Future<void> save(Rect bounds) async {
    try {
      final file = await _file;
      await file.writeAsString(
        jsonEncode({'x': bounds.left, 'y': bounds.top, 'w': bounds.width, 'h': bounds.height}),
      );
    } catch (_) {
      // Losing the window position is not worth failing a resize over.
    }
  }
}

/// Smallest window the presenter layout is designed for.
///
/// Four fixed columns sit side by side — the rail, the set list, the queue and
/// the library — and together they take 896px. This leaves the preview between
/// them about 380px, which is the least that still reads as the centre of the
/// window rather than a gap between panels.
const kMinWindowSize = Size(1280, 760);

/// Picks the bounds to open with.
///
/// [saved] is used when it still lands on a display that exists, so moving the
/// app to the projector-side monitor sticks. Otherwise the window opens
/// centred on [primary] at most of its height, which is what an operator wants
/// on a machine they have never run this on.
Rect resolveWindowBounds({
  required Rect? saved,
  required Rect primary,
  required List<Rect> displays,
}) {
  if (saved != null) {
    final onAScreen = displays.any((d) => d.contains(saved.center));
    if (onAScreen) {
      return Rect.fromLTWH(
        saved.left,
        saved.top,
        saved.width.clamp(kMinWindowSize.width, double.infinity),
        saved.height.clamp(kMinWindowSize.height, double.infinity),
      );
    }
  }

  // 92%, not 80%: at 80% of a 1440pt laptop screen the preview column ends up
  // narrower than the panels either side of it.
  //
  // The minimum wins over the fraction, and the display wins over the minimum,
  // so a screen too small to hold the layout gets a full-screen window rather
  // than one hanging half off the edge.
  final width = _fit(primary.width * 0.92, kMinWindowSize.width, primary.width);
  final height = _fit(primary.height * 0.92, kMinWindowSize.height, primary.height);
  return Rect.fromLTWH(
    primary.left + (primary.width - width) / 2,
    primary.top + (primary.height - height) / 2,
    width,
    height,
  );
}

double _fit(double wanted, double atLeast, double atMost) {
  final raised = wanted < atLeast ? atLeast : wanted;
  return raised > atMost ? atMost : raised;
}
