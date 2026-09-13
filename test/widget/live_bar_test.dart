import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/live_bar.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late FakePrefsService prefs;
  late ControlCubit control;
  late ShellCubit shell;

  setUp(() {
    repo = FakeControlRepository(
      rows: [
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
      ],
    );
    prefs = FakePrefsService();
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      prefs,
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    shell = ShellCubit();
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  Future<void> pumpBar(WidgetTester tester, {double width = 1400}) async {
    await tester.binding.setSurfaceSize(Size(width, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: localizedApp(const LiveBar()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCollection(WidgetTester tester) async {
    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);
    await tester.pumpAndSettle();
  }

  testWidgets('says there is no collection before one is opened', (tester) async {
    await pumpBar(tester);

    expect(find.text('Sin colección activa'), findsOneWidget);
  });

  testWidgets('the two output windows are named, never left as icons', (tester) async {
    // Two near-identical monitor glyphs were impossible to tell apart. These
    // two open different windows for different audiences, so they carry both
    // distinct icons and permanent labels.
    await pumpBar(tester);

    expect(find.text('Proyector'), findsOneWidget);
    expect(find.text('Escenario'), findsOneWidget);
    expect(find.byIcon(Icons.present_to_all_outlined), findsOneWidget);
    expect(find.byIcon(Icons.co_present_outlined), findsOneWidget);
  });

  testWidgets('the screen-state controls are named on a wide window', (tester) async {
    await pumpBar(tester, width: 1440);

    for (final label in ['Cuenta', 'Avisos', 'Negro']) {
      expect(find.text(label), findsOneWidget, reason: '$label must be readable');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every button is labelled at the narrowest allowed window', (tester) async {
    // The label thresholds used to sit above the width the app actually
    // opened at, so the three buttons that change what a congregation sees
    // were the three that never said what they did. Measured against the
    // window the app refuses to shrink below, they cannot drift apart again.
    await pumpBar(tester, width: kMinWindowSize.width);

    for (final label in ['Cuenta', 'Avisos', 'Negro', 'Espera', 'Proyector', 'Escenario']) {
      expect(find.text(label), findsOneWidget, reason: '$label must be readable');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('folds labels away rather than overflow if put somewhere narrow', (tester) async {
    await pumpBar(tester, width: 900);

    expect(find.text('Proyector'), findsNothing);
    expect(find.text('Negro'), findsNothing);
    expect(tester.takeException(), isNull);
    // Every control is still there, reachable by icon and tooltip.
    expect(find.byIcon(Icons.present_to_all_outlined), findsOneWidget);
    expect(find.byIcon(Icons.co_present_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });

  // The readout is one run of rich text, so it is searched by fragment.
  Finder readout(String fragment) => find.textContaining(fragment, findRichText: true);

  testWidgets('names the collection and the slide on the projector', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    expect(readout('Culto domingo'), findsOneWidget);
    expect(readout('Sublime Gracia'), findsOneWidget);
    expect(readout('1/2'), findsOneWidget);
  });

  testWidgets('the readout follows the operator to the next slide', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    control.nextSlide();
    await tester.pumpAndSettle();

    expect(readout('2/2'), findsOneWidget);
  });

  testWidgets('says when the machine cannot reach the server', (tester) async {
    // Not an error: the plan and the designs are on this disk and the service
    // runs from them. What it warns about is that edits are going nowhere.
    await pumpBar(tester);
    await openCollection(tester);
    expect(find.text('Sin conexión'), findsNothing);

    repo.failWith = Exception('Failed host lookup: api.introduce.test');
    await control.load();
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(prefs.saved, isNotNull, reason: 'the plan it falls back on');
  });

  testWidgets('the hold toggle says which way round it is', (tester) async {
    // Wide enough for its label, which it gives up first on a narrow window.
    await pumpBar(tester, width: 1600);
    await openCollection(tester);

    expect(find.text('Sigue'), findsOneWidget);

    await tester.tap(find.text('Sigue'));
    await tester.pumpAndSettle();

    expect(find.text('Retenido'), findsOneWidget);
    expect((control.state as ControlLoadedState).model.followCursor, isFalse);
  });

  testWidgets('the send button appears only when there is something to send', (tester) async {
    // A send button that is always there is one an operator learns to ignore.
    await pumpBar(tester);
    await openCollection(tester);

    expect(find.text('Enviar'), findsNothing);

    control.setFollowCursor(false);
    control.nextSlide();
    await tester.pumpAndSettle();

    expect(find.text('Enviar'), findsOneWidget);
  });

  testWidgets('the readout keeps naming what is on the projector', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);

    control.setFollowCursor(false);
    control.nextSlide();
    await tester.pumpAndSettle();

    // The cursor moved to the second slide; the congregation is still on the
    // first, and this line answers for the congregation.
    expect(readout('1/2'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Poner la pantalla en negro  ·  B'));
    await tester.pumpAndSettle();

    expect((control.state as ControlLoadedState).model.blankScreen, isTrue);
  });

  testWidgets('the dock toggle drives the shell, not just itself', (tester) async {
    await pumpBar(tester);
    expect(shell.state.dockOpen, isTrue);

    await tester.tap(find.byTooltip('Ocultar la biblioteca  ·  F'));
    await tester.pumpAndSettle();

    expect(shell.state.dockOpen, isFalse);
    expect(find.byTooltip('Mostrar la biblioteca  ·  F'), findsOneWidget);
  });

  testWidgets('every control is reachable while a library is open', (tester) async {
    await pumpBar(tester);
    await openCollection(tester);
    shell.goTo(ShellSection.collections);
    await tester.pumpAndSettle();

    // The bar lives in the shell, so leaving the presenter must not remove it.
    expect(find.byTooltip('Poner la pantalla en negro  ·  B'), findsOneWidget);
    expect(find.byIcon(Icons.present_to_all_outlined), findsOneWidget);
    expect(find.byTooltip('Abrir el monitor con notas para el equipo'), findsOneWidget);
    expect(find.text('En vivo'), findsOneWidget);
  });

  testWidgets('controls stay disabled until data has loaded', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byTooltip('Poner la pantalla en negro  ·  B'));
    await tester.pumpAndSettle();

    expect(control.state, isA<ControlLoadingState>());
  });
}
