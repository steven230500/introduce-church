import 'package:flutter/widgets.dart';

/// Making a verse fit the box it was given.
///
/// A design sets one font size and every slide is drawn at it, so a design
/// that looks right on a two-line sample cuts an eight-line verse in half. The
/// size in the template becomes a ceiling here rather than a fixed value:
/// nothing is ever drawn larger than it was designed, and long text gives way
/// instead of disappearing.
class FitText extends StatelessWidget {
  const FitText({
    super.key,
    required this.text,
    required this.style,
    required this.textAlign,
    this.minFontSize = 10,
  });

  final String text;

  /// Its `fontSize` is the largest the text may be drawn at.
  final TextStyle style;

  final TextAlign textAlign;

  /// Below this nobody at the back can read it anyway, so it stops shrinking
  /// and lets the text run over rather than pretending it worked.
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = fitFontSize(
          text: text,
          style: style,
          textAlign: textAlign,
          box: Size(constraints.maxWidth, constraints.maxHeight),
          textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
          minFontSize: minFontSize,
        );
        return Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}

/// The largest size at or below the style's own that lets [text] fit in [box].
///
/// Binary search rather than stepping down one point at a time: a long psalm
/// in a small box would otherwise lay the text out fifty times per frame.
double fitFontSize({
  required String text,
  required TextStyle style,
  required TextAlign textAlign,
  required Size box,
  TextScaler textScaler = TextScaler.noScaling,
  double minFontSize = 10,
}) {
  final ceiling = style.fontSize ?? 16;
  if (text.isEmpty || !box.width.isFinite || box.width <= 0) return ceiling;

  bool fits(double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: size),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: box.width);
    // Height is the only real constraint: the painter already wraps to width.
    return !box.height.isFinite || painter.height <= box.height;
  }

  if (fits(ceiling)) return ceiling;

  var low = minFontSize;
  var high = ceiling;
  // Ten halvings take a 10-to-200 range down to a fifth of a point, which is
  // finer than anything a projector can show.
  for (var i = 0; i < 10; i++) {
    final mid = (low + high) / 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return low;
}
