import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/template_picker/color_field.dart';

import '../helpers/builders.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int value,
    required ValueChanged<int> onChanged,
    int? against,
    List<int> saved = const [],
    List<int> fromPhoto = const [],
    ValueChanged<int>? onSave,
    ValueChanged<int>? onForget,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        SizedBox(
          width: 420,
          child: ColorField(
            label: 'Color texto',
            value: value,
            against: against,
            saved: saved,
            fromPhoto: fromPhoto,
            onSave: onSave,
            onForget: onForget,
            onChanged: onChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the colour in use as hex', (tester) async {
    await pump(tester, value: 0xFF1A73E8, onChanged: (_) {});

    expect(find.text('#1A73E8'), findsOneWidget);
  });

  testWidgets('a typed colour is taken', (tester) async {
    // Twenty swatches written into the source is not a palette. A church with
    // its own colours needs to be able to type one.
    var picked = 0;
    await pump(tester, value: 0xFF000000, onChanged: (c) => picked = c);

    await tester.enterText(find.byType(TextField), '#FF9900');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked, 0xFFFF9900);
  });

  testWidgets('nonsense is put back rather than left on screen', (tester) async {
    var picked = 0;
    await pump(tester, value: 0xFF1A73E8, onChanged: (c) => picked = c);

    await tester.enterText(find.byType(TextField), 'azul');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked, 0, reason: 'nothing was changed');
    expect(find.text('#1A73E8'), findsOneWidget);
  });

  testWidgets('says when a pairing will not be read from the back', (tester) async {
    await pump(tester, value: 0xFF444444, against: 0xFF000000, onChanged: (_) {});

    expect(find.text('No se va a leer'), findsOneWidget);
  });

  testWidgets('says when it will', (tester) async {
    await pump(tester, value: 0xFFFFFFFF, against: 0xFF000000, onChanged: (_) {});

    expect(find.text('Se lee bien'), findsOneWidget);
  });

  testWidgets('with nothing known to sit on, no verdict is offered', (tester) async {
    await pump(tester, value: 0xFFFFFFFF, onChanged: (_) {});

    for (final label in ['Se lee bien', 'Justo', 'No se va a leer']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('the current colour can be kept for the church', (tester) async {
    int? saved;
    await pump(tester, value: 0xFF1A73E8, onChanged: (_) {}, onSave: (c) => saved = c);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(saved, 0xFF1A73E8);
  });

  testWidgets('a colour already kept is not offered for keeping again', (tester) async {
    await pump(
      tester,
      value: 0xFF1A73E8,
      saved: const [0xFF1A73E8],
      onChanged: (_) {},
      onSave: (_) {},
    );

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('DE LA IGLESIA'), findsOneWidget);
  });

  testWidgets('the colours of the background photo are offered', (tester) async {
    // Matching the text to something already in the picture is what makes a
    // design look deliberate, and it should not mean eyeballing a hex code.
    var picked = 0;
    await pump(
      tester,
      value: 0xFFFFFFFF,
      fromPhoto: const [0xFFE67828, 0xFF141420],
      onChanged: (c) => picked = c,
    );

    expect(find.text('DE LA FOTO'), findsOneWidget);

    await tester.tap(find.byTooltip('#E67828'));
    await tester.pumpAndSettle();

    expect(picked, 0xFFE67828);
  });

  testWidgets('a design with no photo says nothing about one', (tester) async {
    await pump(tester, value: 0xFFFFFFFF, onChanged: (_) {});

    expect(find.text('DE LA FOTO'), findsNothing);
  });
}
