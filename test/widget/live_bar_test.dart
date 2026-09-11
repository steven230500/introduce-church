import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/live_bar.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;
  late ShellCubit shell;

  setUp(() {
    repo = FakeControlRepository(rows: [
      collectionRow(
        id: 'c1',
        name: 'Culto domingo',
        items: [
          songItemRow(
            id: 'i1',
            collectionId: 'c1',
            order: 0,
            title: 'Sublime Gracia',
            verses: ['a', 'b'],
          ),
        ],
      ),
    ]);
    control = ControlCubit(repo, FakeTemplateRepository(), FakePrefsService());
    shell = ShellCubit();
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: const MaterialApp(home: Scaffold(body: LiveBar())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCollection(WidgetTester tester) async {
    await control.load();
    control.selectCollection(
      (control.state as ControlLoadedState).model.collections.first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says there is no collection before one is opened', (tester) async {
    await pumpBar(tester);

    expect(find.text('Sin colección activa'), findsOneWidget);
  });

  testWidgets('names the collection and the slide on the projector', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    expect(find.text('Culto domingo'), findsOneWidget);
    expect(find.text('Sublime Gracia'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('the readout follows the operator to the next slide', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    control.nextSlide();
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('the live button cuts the feed on and off', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    expect(find.text('En vivo'), findsOneWidget);

    await tester.tap(find.text('En vivo'));
    await tester.pumpAndSettle();

    expect(find.text('EN VIVO'), findsOneWidget);
  });

  testWidgets('the blank control reflects the projector state', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    await tester.tap(find.byTooltip('Pantalla negra  ·  B'));
    await tester.pumpAndSettle();

    expect((control.state as ControlLoadedState).model.blankScreen, isTrue);
  });

  testWidgets('the dock toggle drives the shell, not just itself', (tester) async {
    await pumpBar(tester);
    expect(shell.state.dockOpen, isTrue);

    await tester.tap(find.byTooltip('Ocultar biblioteca'));
    await tester.pumpAndSettle();

    expect(shell.state.dockOpen, isFalse);
    expect(find.byTooltip('Mostrar biblioteca'), findsOneWidget);
  });

  testWidgets('every control is reachable while a library is open', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);
    shell.goTo(ShellSection.collections);
    await tester.pumpAndSettle();

    // The bar lives in the shell, so leaving the presenter must not remove it.
    expect(find.byTooltip('Pantalla negra  ·  B'), findsOneWidget);
    expect(find.byTooltip('Abrir pantalla de proyección'), findsOneWidget);
    expect(find.byTooltip('Monitor de escenario'), findsOneWidget);
    expect(find.text('En vivo'), findsOneWidget);
  });

  testWidgets('controls stay disabled until data has loaded', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byTooltip('Pantalla negra  ·  B'));
    await tester.pumpAndSettle();

    expect(control.state, isA<ControlLoadingState>());
  });
}
