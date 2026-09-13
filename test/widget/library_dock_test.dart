import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/library/library_dock.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late ControlCubit control;
  late ShellCubit shell;

  setUp(() {
    control = ControlCubit(
      FakeControlRepository(
        rows: [collectionRow(id: 'c1', name: 'Culto domingo')],
      ),
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    shell = ShellCubit();
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: localizedApp(child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCollection(WidgetTester tester) async {
    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);
    await tester.pumpAndSettle();
  }

  group('AddToSetListButton', () {
    testWidgets('says why it cannot act when no collection is open', (tester) async {
      await pump(tester, AddToSetListButton(onAdd: () {}));

      expect(find.byTooltip('Sin colección activa'), findsOneWidget);
    });

    testWidgets('does nothing when there is nowhere to add', (tester) async {
      var added = false;
      await pump(tester, AddToSetListButton(onAdd: () => added = true));

      await tester.tap(find.byType(AddToSetListButton));
      await tester.pumpAndSettle();

      expect(added, isFalse);
    });

    testWidgets('acts once a collection is open', (tester) async {
      var added = false;
      await pump(tester, AddToSetListButton(onAdd: () => added = true));
      await openCollection(tester);

      expect(find.byTooltip('Agregar al set list'), findsOneWidget);

      await tester.tap(find.byType(AddToSetListButton));
      await tester.pumpAndSettle();

      expect(added, isTrue);
    });

    testWidgets('wakes up the moment a collection is opened', (tester) async {
      await pump(tester, AddToSetListButton(onAdd: () {}));
      expect(find.byTooltip('Sin colección activa'), findsOneWidget);

      await openCollection(tester);

      expect(find.byTooltip('Sin colección activa'), findsNothing);
    });
  });

  group('DockPanel', () {
    testWidgets('keeps the toolbar above a scrolling body', (tester) async {
      await pump(tester, const DockPanel(toolbar: Text('barra'), body: Text('contenido')));

      expect(find.text('barra'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });
  });

  group('showAddedToast', () {
    testWidgets('confirms the add without blocking the operator', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAddedToast(context, 'Sublime Gracia'),
            child: const Text('agregar'),
          ),
        ),
      );

      await tester.tap(find.text('agregar'));
      await tester.pump();

      expect(find.text('Sublime Gracia agregado al set list'), findsOneWidget);
    });
  });
}
