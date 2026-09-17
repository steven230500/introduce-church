import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/free_slide_dialog.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/page.dart';

import '../helpers/builders.dart';

/// Opens [open] as soon as the screen is up, and keeps what it returns.
Widget opener(Future<void> Function(BuildContext context) open) => localizedApp(
  Builder(
    builder: (context) => TextButton(onPressed: () => open(context), child: const Text('abrir')),
  ),
);

void main() {
  group('a sermon already in the service', () {
    testWidgets('opens with what was written, and hands back the corrections', (tester) async {
      SermonDraft? result;
      await tester.pumpWidget(
        opener((context) async {
          result = await showSermonDialog(
            context,
            initial: (title: 'El llamado', points: ['Mateo 9:9', 'Sobra']),
          );
        }),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Editar prédica'), findsOneWidget);
      expect(find.text('El llamado'), findsOneWidget);
      expect(find.text('Mateo 9:9'), findsOneWidget);

      await tester.enterText(find.text('Sobra'), 'Lucas 5:27');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(result?.title, 'El llamado');
      expect(result?.points, ['Mateo 9:9', 'Lucas 5:27']);
    });

    testWidgets('a new one still says it is new, and starts empty', (tester) async {
      await tester.pumpWidget(opener((context) => showSermonDialog(context)));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva prédica'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
    });
  });

  group('a text slide already in the service', () {
    testWidgets('opens with its words in the box', (tester) async {
      FreeSlideResult? result;
      await tester.pumpWidget(
        opener((context) async {
          result = await showFreeSlideDialog(
            context,
            initial: const FreeSlideResult(text: 'Bienvenidos', title: 'Saludo'),
          );
        }),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Editar slide'), findsOneWidget);
      expect(find.text('Saludo'), findsOneWidget);

      await tester.enterText(find.text('Bienvenidos'), 'Bienvenidos a la casa de Dios');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(result?.text, 'Bienvenidos a la casa de Dios');
      expect(result?.title, 'Saludo');
    });
  });
}
