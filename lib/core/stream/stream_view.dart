import 'package:flutter/widgets.dart';

import '../widgets/fit_text.dart';
import 'stream_style.dart';

/// The words of the slide as a streaming overlay: a band of text over a flat
/// key colour, at whatever size the window is.
///
/// Drawn for a keyer rather than for a wall. No blurred shadows, whose soft
/// edges fade into the key colour and come out of the keyer as a green halo;
/// an outline gives the same legibility over any camera shot with a hard edge.
class StreamView extends StatelessWidget {
  const StreamView({super.key, required this.style, this.text = '', this.reference = ''});

  final StreamStyle style;

  /// Empty shows the key colour alone: the camera, with nothing over it.
  final String text;
  final String reference;

  /// Sizes are authored against a 1920-wide frame, like the slides.
  static const designWidth = 1920.0;

  @override
  Widget build(BuildContext context) {
    // Its own text style, rather than one inherited: the stream window has no
    // Material around it, and Flutter's fallback for that is a double yellow
    // underline under every word - which went out on the stream.
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none, color: Color(0xFFFFFFFF)),
      child: ColoredBox(
        color: style.key.color,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (text.trim().isEmpty) return const SizedBox.expand();
            final width = constraints.hasBoundedWidth ? constraints.maxWidth : designWidth;
            final unit = width / designWidth;
            final fontSize = 54 * style.scale * unit;
            final maxHeight =
                (constraints.hasBoundedHeight ? constraints.maxHeight : width * 9 / 16) * 0.34;
            final words = _Words(
              text: text,
              fontSize: fontSize,
              maxHeight: maxHeight,
              outline: !style.bar,
            );
            final showReference = style.showReference && reference.trim().isNotEmpty;

            final band = Container(
              width: width * 0.86,
              padding: EdgeInsets.symmetric(horizontal: 40 * unit, vertical: 22 * unit),
              decoration: style.bar
                  ? BoxDecoration(
                      color: const Color(0xFF111318),
                      borderRadius: BorderRadius.circular(6 * unit),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  words,
                  if (showReference) ...[
                    SizedBox(height: 8 * unit),
                    _Outlined(
                      text: reference,
                      style: TextStyle(
                        color: const Color(0xFFD9DCE3),
                        fontSize: fontSize * 0.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                      outline: !style.bar,
                    ),
                  ],
                ],
              ),
            );

            return Align(
              alignment: style.position == StreamPosition.bottom
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Padding(
                // A title-safe margin: broadcast players crop the edges.
                padding: EdgeInsets.symmetric(vertical: 48 * unit),
                child: band,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({
    required this.text,
    required this.fontSize,
    required this.maxHeight,
    required this.outline,
  });

  final String text;
  final double fontSize;
  final double maxHeight;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    // A lower third has a height it must not grow past, or it covers the
    // preacher's face. Long verses give way in size, the way slides do.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: outline
          ? Stack(
              children: [
                FitText(
                  text: text,
                  textAlign: TextAlign.center,
                  minFontSize: fontSize * 0.4,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = fontSize * 0.12
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xFF000000),
                    color: null,
                  ),
                ),
                FitText(
                  text: text,
                  textAlign: TextAlign.center,
                  minFontSize: fontSize * 0.4,
                  style: style,
                ),
              ],
            )
          : FitText(
              text: text,
              textAlign: TextAlign.center,
              minFontSize: fontSize * 0.4,
              style: style,
            ),
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined({required this.text, required this.style, required this.outline});

  final String text;
  final TextStyle style;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final plain = Text(text, style: style, textAlign: TextAlign.center, maxLines: 1);
    if (!outline) return plain;
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: style.copyWith(
            color: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (style.fontSize ?? 20) * 0.12
              ..color = const Color(0xFF000000),
          ),
        ),
        plain,
      ],
    );
  }
}
