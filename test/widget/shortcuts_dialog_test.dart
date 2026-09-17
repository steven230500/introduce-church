import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/shortcuts_dialog.dart';

import '../helpers/builders.dart';

void main() {
  group('the keyboard reference', () {
    testWidgets('fits a short window instead of running off the bottom', (tester) async {
      // A laptop window at the app's minimum height: the list of shortcuts is
      // longer than this, and used to overflow by a hundred pixels.
      await tester.binding.setSurfaceSize(const Size(1280, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showShortcutsDialog(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('lists the keys that move the text of the design', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showShortcutsDialog(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Subir o bajar el texto del diseño'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
