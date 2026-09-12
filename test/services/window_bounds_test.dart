import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';

void main() {
  const laptop = Rect.fromLTWH(0, 25, 1440, 875);
  const projectorSide = Rect.fromLTWH(1440, 0, 2560, 1080);
  const displays = [laptop, projectorSide];

  group('with nothing remembered', () {
    final bounds = resolveWindowBounds(saved: null, primary: laptop, displays: displays);

    test('fills most of the primary display', () {
      expect(bounds.width, closeTo(1440 * 0.92, 0.01));
      expect(bounds.height, closeTo(875 * 0.92, 0.01));
    });

    test('is centred on it', () {
      expect(bounds.center.dx, closeTo(laptop.center.dx, 0.01));
      expect(bounds.center.dy, closeTo(laptop.center.dy, 0.01));
    });

    test('never opens smaller than the layout needs', () {
      const tiny = Rect.fromLTWH(0, 0, 900, 600);
      final small = resolveWindowBounds(saved: null, primary: tiny, displays: [tiny]);

      // A display this small cannot hold the minimum, so the window fills it
      // rather than being placed half off the screen.
      expect(small.width, 900);
      expect(small.height, 600);
    });
  });

  group('with a remembered position', () {
    test('reopens exactly where it was left', () {
      const saved = Rect.fromLTWH(1500, 40, 2000, 900);
      final bounds = resolveWindowBounds(saved: saved, primary: laptop, displays: displays);

      expect(bounds, saved);
    });

    test('comes back to the primary display when that monitor is gone', () {
      // Unplugging the projector-side monitor used to leave the window
      // parked at coordinates no screen covers, which looks like a crash.
      const saved = Rect.fromLTWH(3000, 40, 1400, 800);
      final bounds = resolveWindowBounds(saved: saved, primary: laptop, displays: const [laptop]);

      expect(laptop.contains(bounds.center), isTrue);
    });

    test('grows a remembered size that is now below the minimum', () {
      const saved = Rect.fromLTWH(100, 100, 800, 500);
      final bounds = resolveWindowBounds(saved: saved, primary: laptop, displays: displays);

      expect(bounds.width, kMinWindowSize.width);
      expect(bounds.height, kMinWindowSize.height);
    });
  });
}
