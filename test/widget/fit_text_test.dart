import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/fit_text.dart';

void main() {
  const style = TextStyle(fontSize: 60, height: 1.4);

  group('fitting a verse to its box', () {
    test('short text is left at the size it was designed', () {
      // Nothing is ever drawn larger than the design asked for, so every
      // existing design looks the same except where it used to clip.
      final size = fitFontSize(
        text: 'Aleluya',
        style: style,
        textAlign: TextAlign.center,
        box: const Size(1200, 600),
      );

      expect(size, 60);
    });

    test('a long verse gives way instead of running off the screen', () {
      final long = List.filled(60, 'palabra').join(' ');

      final size = fitFontSize(
        text: long,
        style: style,
        textAlign: TextAlign.center,
        box: const Size(600, 200),
      );

      expect(size, lessThan(60));
      expect(size, greaterThanOrEqualTo(10));
    });

    test('it stops shrinking where nobody could read it anyway', () {
      final absurd = List.filled(4000, 'palabra').join(' ');

      final size = fitFontSize(
        text: absurd,
        style: style,
        textAlign: TextAlign.center,
        box: const Size(300, 80),
        minFontSize: 14,
      );

      expect(size, greaterThanOrEqualTo(14));
    });

    test('the size it lands on actually fits', () {
      final text = List.filled(40, 'palabra').join(' ');
      const box = Size(500, 240);

      final size = fitFontSize(text: text, style: style, textAlign: TextAlign.center, box: box);

      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: size),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: box.width);

      expect(painter.height, lessThanOrEqualTo(box.height));
    });

    test('a taller box lets the same verse stay bigger', () {
      final text = List.filled(30, 'palabra').join(' ');

      final tight = fitFontSize(
        text: text,
        style: style,
        textAlign: TextAlign.center,
        box: const Size(600, 150),
      );
      final roomy = fitFontSize(
        text: text,
        style: style,
        textAlign: TextAlign.center,
        box: const Size(600, 400),
      );

      expect(roomy, greaterThan(tight));
    });

    test('an unmeasurable box returns the design size rather than throwing', () {
      expect(
        fitFontSize(
          text: 'Algo',
          style: style,
          textAlign: TextAlign.center,
          box: const Size(double.infinity, 100),
        ),
        60,
      );
    });
  });

  testWidgets('the widget draws at the fitted size', (tester) async {
    final long = List.filled(80, 'palabra').join(' ');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: 160,
            child: FitText(text: long, style: style, textAlign: TextAlign.center),
          ),
        ),
      ),
    );

    final drawn = tester.widget<Text>(find.byType(Text));
    expect(drawn.style!.fontSize, lessThan(60));
  });
}
