import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/widgets/slide_view.dart';

void main() {
  const verse = '"EN el principio crió Dios los cielos y la tierra."';

  /// Renders a slide at [width], 16:9, and returns the font size it chose.
  ///
  /// The surface is grown to fit: the default test window is 800px wide and
  /// would silently clamp anything larger, which reads as a scaling bug.
  Future<double> fontSizeAt(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width + 40, width * 9 / 16 + 40));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: width * 9 / 16,
              child: SlideView(
                content: verse,
                reference: 'Génesis 1:1',
                template: SlideTemplate.darkClassic,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(verse));
    return text.style!.fontSize!;
  }

  group('scaling', () {
    testWidgets('a full-size slide uses the design font size', (tester) async {
      final size = await fontSizeAt(tester, SlideView.designWidth);

      expect(size, closeTo(SlideTemplate.darkClassic.fontSize, 0.01));
    });

    testWidgets('a half-width slide halves the font', (tester) async {
      final size = await fontSizeAt(tester, SlideView.designWidth / 2);

      expect(size, closeTo(SlideTemplate.darkClassic.fontSize / 2, 0.01));
    });

    testWidgets('a thumbnail scales down proportionally', (tester) async {
      final size = await fontSizeAt(tester, 192);

      expect(size, closeTo(SlideTemplate.darkClassic.fontSize * 0.1, 0.01));
    });

    testWidgets('the same text occupies the same fraction at every size', (tester) async {
      // This is the property that makes a preview trustworthy: what the
      // operator sees in a small box is what the congregation sees on the wall.
      // The scale used to be hardcoded per call site, so a preview could cut a
      // verse in half that fit perfectly on the projector.
      final big = await fontSizeAt(tester, 1920);
      final small = await fontSizeAt(tester, 480);

      expect(small / big, closeTo(480 / 1920, 0.001));
    });
  });

  group('rendering', () {
    testWidgets('shows the verse and its reference', (tester) async {
      await fontSizeAt(tester, 960);

      expect(find.text(verse), findsOneWidget);
      expect(find.text('Génesis 1:1'), findsOneWidget);
    });

    testWidgets('a long passage still renders without overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 360,
                child: SlideView(
                  content: List.filled(12, 'palabra').join(' '),
                  reference: 'Salmos 119',
                  template: SlideTemplate.darkClassic,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without a reference when the design hides it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: SlideView(
                content: 'Solo el texto',
                reference: 'Oculta',
                template: SlideTemplate.darkClassic.copyWith(showReference: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solo el texto'), findsOneWidget);
      expect(find.text('Oculta'), findsNothing);
    });
  });
}
