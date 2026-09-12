import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/page.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;
  late ShellCubit shell;

  List<Map<String, dynamic>> serviceRows() => [
        collectionRow(
          id: 'c1',
          name: 'Culto domingo',
          serviceDate: '2026-09-13',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              title: 'Sublime Gracia',
              verses: ['Primera', 'Segunda'],
            ),
            itemRow(
              id: 'i2',
              collectionId: 'c1',
              type: 'free_slide',
              order: 1,
              contentJson: {'title': 'Anuncios', 'text': 'Reunión de jóvenes'},
              notes: 'Bajar el volumen',
            ),
          ],
        ),
      ];

  setUp(() {
    repo = FakeControlRepository(rows: serviceRows());
    control = ControlCubit(repo, FakeTemplateRepository(), FakePrefsService(), FakePresentationSocket());
    shell = ShellCubit();
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  Future<void> pumpPresenter(WidgetTester tester, {bool open = true}) async {
    // A wide surface, because the presenter is a three-column desktop layout.
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: const MaterialApp(home: Scaffold(body: ControlPage())),
      ),
    );
    await control.load();
    if (open) {
      control.selectCollection(
        (control.state as ControlLoadedState).model.collections.first,
      );
    }
    await tester.pumpAndSettle();
  }

  group('empty states', () {
    testWidgets('tells the operator no collection is open', (tester) async {
      await pumpPresenter(tester, open: false);

      expect(find.text('Ninguna colección abierta'), findsWidgets);
    });

    testWidgets('an empty collection offers the add action', (tester) async {
      repo.rows = [collectionRow(id: 'c1', name: 'Vacía')];
      await pumpPresenter(tester);

      expect(find.text('Colección vacía'), findsOneWidget);
      expect(find.text('Agregar elemento'), findsOneWidget);
    });
  });

  group('set list', () {
    testWidgets('names the collection and counts its items', (tester) async {
      await pumpPresenter(tester);

      expect(find.text('Culto domingo'), findsOneWidget);
      expect(find.text('2 elementos  •  13/9/2026'), findsOneWidget);
    });

    testWidgets('lists every item in order', (tester) async {
      await pumpPresenter(tester);

      expect(find.text('Sublime Gracia'), findsWidgets);
      expect(find.text('Anuncios'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('shows the operator note on the item that carries it', (tester) async {
      await pumpPresenter(tester);

      expect(find.text('Bajar el volumen'), findsOneWidget);
    });

    testWidgets('tapping an item moves the presenter to it', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.text('Anuncios'));
      await tester.pumpAndSettle();

      expect((control.state as ControlLoadedState).model.currentItemIndex, 1);
    });
  });

  group('view modes', () {
    testWidgets('both modes are named, not left as a bare icon', (tester) async {
      await pumpPresenter(tester);

      expect(find.text('Cuadrícula'), findsOneWidget);
      expect(find.text('Slide grande'), findsOneWidget);
    });

    testWidgets('the grid keeps an output panel beside it', (tester) async {
      await pumpPresenter(tester);

      expect((control.state as ControlLoadedState).model.gridView, isTrue);
      expect(find.text('Salida'), findsOneWidget);
    });

    testWidgets('switching to the large slide swaps in the slide queue', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.text('Slide grande'));
      await tester.pumpAndSettle();

      expect((control.state as ControlLoadedState).model.gridView, isFalse);
      expect(find.text('Salida'), findsNothing);
      // The queue lists every verse of the current item, which the grid mode
      // side panel never does. The first verse also appears in the large
      // preview, so only the second is unique to the queue.
      expect(find.text('Primera'), findsNWidgets(2));
      expect(find.text('Segunda'), findsOneWidget);
    });
  });

  group('projector state', () {
    testWidgets('a blank screen is called out, not just dark', (tester) async {
      await pumpPresenter(tester);
      control.toggleGridView(); // large preview
      control.toggleBlank();
      await tester.pumpAndSettle();

      expect(find.text('PANTALLA NEGRA'), findsOneWidget);
    });

    testWidgets('going live marks the preview', (tester) async {
      await pumpPresenter(tester);
      control.toggleGridView();
      control.toggleLive();
      await tester.pumpAndSettle();

      expect(find.text('● EN VIVO'), findsOneWidget);
    });
  });

  group('add menu', () {
    testWidgets('groups content by where it comes from', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('DE LA BIBLIOTECA'), findsOneWidget);
      expect(find.text('CREAR'), findsOneWidget);
      expect(find.text('IMPORTAR ARCHIVO'), findsOneWidget);
    });

    testWidgets('choosing a song opens the library instead of a modal', (tester) async {
      await pumpPresenter(tester);
      shell.toggleDock(); // close it, to prove the menu reopens it

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canción'));
      await tester.pumpAndSettle();

      expect(shell.state.tab, LibraryTab.songs);
      expect(shell.state.dockOpen, isTrue);
    });

    testWidgets('choosing a verse opens the Bible tab', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Versículo'));
      await tester.pumpAndSettle();

      expect(shell.state.tab, LibraryTab.bible);
    });
  });
}
