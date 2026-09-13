import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/template_picker/canvas_snap.dart';

void main() {
  const tolerance = Offset(0.02, 0.02);

  group('dragging a layer', () {
    test('centres on the slide when it is nearly centred', () {
      // Eyeballing the centre is the thing everyone does badly and notices
      // from the third row.
      const rect = Rect.fromLTWH(0.24, 0.4, 0.5, 0.2);

      final snapped = snapMove(rect, SnapLines.slide, tolerance);

      expect(snapped.rect.center.dx, closeTo(0.5, 0.0001));
      expect(snapped.rect.width, closeTo(0.5, 0.0001), reason: 'a move must not resize');
      expect(snapped.vertical, contains(0.5));
    });

    test('sticks to the safe area, not just to the edge of the slide', () {
      const rect = Rect.fromLTWH(0.045, 0.3, 0.4, 0.2);

      final snapped = snapMove(rect, SnapLines.slide, tolerance);

      expect(snapped.rect.left, closeTo(kSlideSafeInset, 0.0001));
    });

    test('lines up with another layer', () {
      const other = Rect.fromLTWH(0.2, 0.1, 0.3, 0.1);
      const rect = Rect.fromLTWH(0.21, 0.6, 0.3, 0.1);

      final snapped = snapMove(rect, SnapLines.around([other]), tolerance);

      expect(snapped.rect.left, closeTo(0.2, 0.0001));
    });

    test('is left alone when nothing is close', () {
      const rect = Rect.fromLTWH(0.31, 0.33, 0.22, 0.14);

      final snapped = snapMove(rect, SnapLines.slide, tolerance);

      expect(snapped.rect, rect);
      expect(snapped.vertical, isEmpty);
      expect(snapped.horizontal, isEmpty);
    });
  });

  group('resizing a layer', () {
    test('only the corner being dragged moves', () {
      const rect = Rect.fromLTWH(0.045, 0.3, 0.4, 0.2);

      final snapped = snapResize(
        rect,
        SnapLines.slide,
        tolerance,
        left: true,
        top: true,
        right: false,
        bottom: false,
      );

      expect(snapped.rect.left, closeTo(kSlideSafeInset, 0.0001));
      expect(snapped.rect.right, closeTo(rect.right, 0.0001), reason: 'the far edge stays put');
    });

    test('an edge that is not being dragged does not snap', () {
      // Its right edge is a hair from the safe area, but the hand is on the
      // left one, and a box that changes width at both ends is unusable.
      const rect = Rect.fromLTWH(0.3, 0.3, 0.645, 0.2);

      final snapped = snapResize(
        rect,
        SnapLines.slide,
        tolerance,
        left: true,
        top: false,
        right: false,
        bottom: false,
      );

      expect(snapped.rect.right, closeTo(rect.right, 0.0001));
    });
  });

  test('the safe area is inside the slide, with room on every side', () {
    expect(kSlideSafeInset, greaterThan(0));
    expect(kSlideSafeInset, lessThan(0.2));
    expect(SnapLines.slide.vertical, containsAll([0.0, kSlideSafeInset, 0.5, 1.0]));
  });
}
