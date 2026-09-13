/// Making a layer land where it was meant to.
///
/// Everything here works in the same 0 to 1 space the layers are stored in, so
/// a design snapped on a laptop is snapped on a projector.
library;

import 'dart:ui';

/// How far inside the slide a design should keep its text.
///
/// Projectors overscan and screens get cropped by curtains, brackets and the
/// edge of the wall. Text that reaches the very edge of the canvas is text
/// somebody in the third row cannot read.
const kSlideSafeInset = 0.05;

/// The lines a layer sticks to.
class SnapLines {
  const SnapLines({required this.vertical, required this.horizontal});

  /// Positions across the slide, left to right.
  final List<double> vertical;

  /// Positions down the slide, top to bottom.
  final List<double> horizontal;

  /// The slide's own edges, its middle, and the safe area inside it.
  static const slide = SnapLines(
    vertical: [0, kSlideSafeInset, 0.5, 1 - kSlideSafeInset, 1],
    horizontal: [0, kSlideSafeInset, 0.5, 1 - kSlideSafeInset, 1],
  );

  /// The slide's lines plus the edges and middles of everything in [others],
  /// so layers line up with each other and not only with the frame.
  factory SnapLines.around(Iterable<Rect> others) => SnapLines(
    vertical: [
      ...slide.vertical,
      for (final r in others) ...[r.left, r.center.dx, r.right],
    ],
    horizontal: [
      ...slide.horizontal,
      for (final r in others) ...[r.top, r.center.dy, r.bottom],
    ],
  );
}

/// A rectangle after snapping, and the lines it landed on.
///
/// The lines come back so the canvas can draw them: a layer that silently
/// jumps is worse than one that does not snap at all.
typedef Snapped = ({Rect rect, List<double> vertical, List<double> horizontal});

/// Slides [rect] onto nearby lines without changing its size.
///
/// Its left edge, middle and right edge all look for a line, and the closest
/// of the three wins, so a box centres on the slide as readily as it aligns
/// to another box's edge.
Snapped snapMove(Rect rect, SnapLines lines, Offset tolerance) {
  final x = _closest([rect.left, rect.center.dx, rect.right], lines.vertical, tolerance.dx);
  final y = _closest([rect.top, rect.center.dy, rect.bottom], lines.horizontal, tolerance.dy);

  return (
    rect: rect.shift(Offset(x?.shift ?? 0, y?.shift ?? 0)),
    vertical: [?x?.line],
    horizontal: [?y?.line],
  );
}

/// Snaps only the edges being dragged, leaving the opposite ones alone.
Snapped snapResize(
  Rect rect,
  SnapLines lines,
  Offset tolerance, {
  required bool left,
  required bool top,
  required bool right,
  required bool bottom,
}) {
  var result = rect;
  final vertical = <double>[];
  final horizontal = <double>[];

  final leftSnap = left ? _closest([result.left], lines.vertical, tolerance.dx) : null;
  if (leftSnap != null) {
    result = Rect.fromLTRB(leftSnap.line, result.top, result.right, result.bottom);
    vertical.add(leftSnap.line);
  }

  final rightSnap = right ? _closest([result.right], lines.vertical, tolerance.dx) : null;
  if (rightSnap != null) {
    result = Rect.fromLTRB(result.left, result.top, rightSnap.line, result.bottom);
    vertical.add(rightSnap.line);
  }

  final topSnap = top ? _closest([result.top], lines.horizontal, tolerance.dy) : null;
  if (topSnap != null) {
    result = Rect.fromLTRB(result.left, topSnap.line, result.right, result.bottom);
    horizontal.add(topSnap.line);
  }

  final bottomSnap = bottom ? _closest([result.bottom], lines.horizontal, tolerance.dy) : null;
  if (bottomSnap != null) {
    result = Rect.fromLTRB(result.left, result.top, result.right, bottomSnap.line);
    horizontal.add(bottomSnap.line);
  }

  return (rect: result, vertical: vertical, horizontal: horizontal);
}

/// The nearest line to any of [edges], and how far the rectangle has to move
/// to reach it. Null when nothing is close enough to be worth pulling towards.
({double line, double shift})? _closest(List<double> edges, List<double> lines, double tolerance) {
  ({double line, double shift})? best;
  var bestDistance = tolerance;

  for (final edge in edges) {
    for (final line in lines) {
      final distance = (line - edge).abs();
      if (distance > bestDistance) continue;
      bestDistance = distance;
      best = (line: line, shift: line - edge);
    }
  }
  return best;
}
