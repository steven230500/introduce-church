import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/widgets/slide_transition_view.dart';
import 'package:introduce_church/core/widgets/slide_view.dart';
import 'package:introduce_church/core/widgets/ui/panel_resizer.dart';
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
    control = ControlCubit(
      repo,
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
        child: localizedApp(const ControlPage()),
      ),
    );
    await control.load();
    if (open) {
      control.selectCollection((control.state as ControlLoadedState).model.collections.first);
    }
    await tester.pumpAndSettle();
  }

  group('empty states', () {
    testWidgets('tells the operator no collection is open, once', (tester) async {
      await pumpPresenter(tester, open: false);

      // One message for the whole workspace. Three panels each announcing
      // their own emptiness read as three separate problems.
      expect(find.text('Nada en pantalla'), findsOneWidget);
      expect(find.text('Nueva colección'), findsOneWidget);
    });

    testWidgets('offers the collections it already has as one click', (tester) async {
      await pumpPresenter(tester, open: false);

      expect(find.text('Culto domingo'), findsOneWidget);

      await tester.tap(find.text('Culto domingo'));
      await tester.pumpAndSettle();

      expect(find.text('Sublime Gracia'), findsWidgets);
    });

    testWidgets('an empty collection offers the add action', (tester) async {
      repo.rows = [collectionRow(id: 'c1', name: 'Vacía')];
      await pumpPresenter(tester);

      expect(find.text('Colección vacía'), findsOneWidget);
      expect(find.text('Agregar elemento'), findsOneWidget);
    });
  });

  group('set list rows', () {
    testWidgets('each row says how long it runs, on its own line', (tester) async {
      // The count used to be a bare number between the title and the kebab,
      // where it read as part of the title and ate the width that made titles
      // fit at all.
      await pumpPresenter(tester);

      expect(find.text('2 slides'), findsOneWidget);
      expect(find.text('1 slide'), findsOneWidget);
    });

    testWidgets('the order badge is the drag handle', (tester) async {
      // Dropping the separate handle gives the title back about 24px, which is
      // the difference between "NADA ES IMPOSIBLE" and "NADA ES IMPOSIB...".
      await pumpPresenter(tester);

      expect(
        find.descendant(
          of: find.byType(ReorderableDragStartListener).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });
  });

  group('holding the screen', () {
    testWidgets('the output panel keeps showing what is on the projector', (tester) async {
      await pumpPresenter(tester);
      control.setFollowCursor(false);
      control.selectItem(1); // "Anuncios", which has one slide
      await tester.pumpAndSettle();

      // The live item still has two. Following the cursor would read "1 de 1".
      expect(find.text('1 de 2'), findsOneWidget);
    });

    testWidgets('the set list marks the row that is on the projector', (tester) async {
      await pumpPresenter(tester);
      control.toggleLive();
      control.setFollowCursor(false);
      control.selectItem(1);
      await tester.pumpAndSettle();

      expect(find.byTooltip('En la pantalla ahora'), findsOneWidget);
    });

    testWidgets('off air nothing is marked as being on the screen', (tester) async {
      // Red says "they are seeing this". With the feed cut they are seeing
      // nothing, whatever the live position happens to be.
      await pumpPresenter(tester);
      control.setFollowCursor(false);
      control.selectItem(1);
      await tester.pumpAndSettle();

      expect(find.byTooltip('En la pantalla ahora'), findsNothing);
    });

    testWidgets('the big preview says it is not on air, and sends', (tester) async {
      await pumpPresenter(tester);
      control.toggleGridView(); // the large single slide
      control.setFollowCursor(false);
      control.selectItem(1);
      await tester.pumpAndSettle();

      expect(find.text('SIN ENVIAR'), findsOneWidget);

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('SIN ENVIAR'), findsNothing);
      expect(control.state, isA<ControlLoadedState>());
      expect((control.state as ControlLoadedState).model.liveItemIndex, 1);
    });

    testWidgets('the grid says it too, having no frame to badge', (tester) async {
      // Exactly one marker per mode: the large slide badges its frame, the
      // grid puts it in the header. Two at once is noise.
      await pumpPresenter(tester); // grid is the default view
      control.setFollowCursor(false);
      control.selectItem(1);
      await tester.pumpAndSettle();

      expect(find.text('SIN ENVIAR'), findsOneWidget);
    });

    testWidgets('nothing is marked twice while the screen follows', (tester) async {
      await pumpPresenter(tester);

      expect(find.byTooltip('En la pantalla ahora'), findsNothing);
      expect(find.text('SIN ENVIAR'), findsNothing);
    });
  });

  group('the workspace itself', () {
    /// Drags the set list edge by [dx], past the slop a pointer spends being
    /// recognised as a drag at all.
    Future<void> dragSetListEdge(WidgetTester tester, double dx) async {
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PanelResizer).first));
      await gesture.moveBy(const Offset(kDragSlopDefault, 0));
      await gesture.moveBy(Offset(dx, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      // The width is written once the drag settles, and a timer still pending
      // when the test ends is a failure in its own right.
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('the columns can be dragged to a different width', (tester) async {
      // One hard-coded width was always going to be wrong for somebody: a set
      // list full of long titles wants room, a small screen wants the preview.
      await pumpPresenter(tester);

      await dragSetListEdge(tester, 40);

      expect(shell.state.widthOf(ShellPanel.setList), ShellPanel.setList.defaultWidth + 40);
    });

    testWidgets('a double click puts a column back', (tester) async {
      await pumpPresenter(tester);
      await dragSetListEdge(tester, 40);

      await tester.tap(find.byType(PanelResizer).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PanelResizer).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(shell.state.widthOf(ShellPanel.setList), ShellPanel.setList.defaultWidth);
    });

    testWidgets('the preview moves between slides the way the projector does', (tester) async {
      // It used to cut while the screen it mirrors dissolved, which made the
      // preview a slightly dishonest picture and the workspace feel stiff.
      await pumpPresenter(tester);

      expect(find.byType(SlideTransitionView), findsWidgets);
    });
  });

  group('the item menu', () {
    testWidgets('offers a rename for what an import named after a file', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.text('Anuncios'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Renombrar'), findsOneWidget);
    });

    for (final (entry, typed) in [
      ('Renombrar', 'Anuncios del mes'),
      ('Duración', '4:30'),
      ('Auto-avance', '12'),
    ]) {
      testWidgets('$entry: Enter in the field saves and closes cleanly', (tester) async {
        // The controller was disposed the moment the dialog returned, while the
        // dialog was still animating out with its field attached. Closing it
        // from inside the field, with Enter, took the app down.
        await pumpPresenter(tester);

        await tester.tap(find.text('Anuncios'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, typed);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNothing, reason: 'the dialog closed');
      });
    }

    testWidgets('does not offer to rename a song from here', (tester) async {
      // Its name is the song's. Changing it here would either lie about the
      // library or have to be undone in two places.
      await pumpPresenter(tester);

      await tester.tap(find.text('Sublime Gracia').first, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Renombrar'), findsNothing);
      expect(find.text('Quitar del set list'), findsOneWidget);
    });

    testWidgets('removing an item offers the way back', (tester) async {
      // The menu entry that removes sits two rows from the one that changes a
      // design, and removing used to be immediate and final.
      await pumpPresenter(tester);

      await tester.tap(find.text('Anuncios'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar del set list'));
      await tester.pumpAndSettle();

      expect(find.text('Anuncios'), findsNothing);
      expect(find.text('Deshacer'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(find.text('Anuncios'), findsWidgets);
    });
  });

  group('repeated items', () {
    testWidgets('say which time round they are', (tester) async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'NADA ES IMPOSIBLE'),
            songItemRow(id: 'i2', collectionId: 'c1', order: 1, title: 'Otra'),
            songItemRow(id: 'i3', collectionId: 'c1', order: 2, title: 'NADA ES IMPOSIBLE'),
          ],
        ),
      ];
      await pumpPresenter(tester);

      expect(find.textContaining('1ª de 2'), findsOneWidget);
      expect(find.textContaining('2ª de 2'), findsOneWidget);
      // The title that appears once is left alone.
      expect(find.text('1 slide'), findsOneWidget);
    });
  });

  group('slide grid', () {
    testWidgets('a lone slide fills the column instead of sitting in a corner', (tester) async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'free_slide',
              order: 0,
              contentJson: {'title': 'Bienvenida', 'text': 'Bienvenidos'},
            ),
          ],
        ),
      ];
      await pumpPresenter(tester);

      final tile = tester.getSize(
        find.descendant(of: find.byType(GridView), matching: find.byType(SlideView)).first,
      );

      expect(tile.width, greaterThan(400));
    });

    testWidgets('a long song packs into columns rather than one huge tile', (tester) async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              verses: [for (var i = 0; i < 12; i++) 'Verso $i'],
            ),
          ],
        ),
      ];
      await pumpPresenter(tester);

      final tiles = find.descendant(of: find.byType(GridView), matching: find.byType(SlideView));
      final tile = tester.getSize(tiles.first);

      expect(tile.width, lessThan(400));
      // All twelve fit on screen, so no scrolling mid-song to find a verse.
      expect(tiles, findsNWidgets(12));
    });

    testWidgets('each tile names its slide below the frame, never over it', (tester) async {
      // As a badge inside the frame the label landed on the lyric whenever the
      // line ran long, which is the moment you need to read both.
      await pumpPresenter(tester);

      expect(find.text('Verso'), findsWidgets);
      expect(
        find.descendant(of: find.byType(SlideView), matching: find.text('Verso')),
        findsNothing,
      );
    });
  });

  group('what comes next', () {
    testWidgets('the output panel previews the next slide', (tester) async {
      await pumpPresenter(tester);

      expect(find.text('A CONTINUACIÓN'), findsOneWidget);
    });

    testWidgets('names the item when the next press crosses into one', (tester) async {
      await pumpPresenter(tester);
      // The last slide of the song: pressing next leaves the item entirely.
      control.nextSlide();
      await tester.pumpAndSettle();

      // Once in the set list, once in the card.
      expect(find.text('Anuncios'), findsNWidgets(2));
    });

    testWidgets('says so at the end of the set list', (tester) async {
      await pumpPresenter(tester);
      control.nextSlide();
      control.nextSlide();
      await tester.pumpAndSettle();

      expect(find.text('Fin del set list'), findsOneWidget);
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

    testWidgets('choosing to browse opens the Bible tab', (tester) async {
      await pumpPresenter(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar en la Biblia'));
      await tester.pumpAndSettle();

      expect(shell.state.tab, LibraryTab.bible);
    });

    testWidgets('the quick verse is offered first, with its key', (tester) async {
      // Browsing to a passage is a book list, a chapter grid and a verse list
      // while the room waits. The line of text goes above it.
      await pumpPresenter(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Versículo rápido'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
    });
  });
  group('editing a slide from the grid', () {
    testWidgets('every slide has a pencil, and it opens the editor without projecting', (
      tester,
    ) async {
      await pumpPresenter(tester);
      expect(find.byTooltip('Editar slide'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Editar slide').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Segunda'), findsOneWidget);
      // The pencil has its own tap: the second slide was not put on the screen.
      expect((control.state as ControlLoadedState).model.currentSlideIndex, 0);
    });

    testWidgets('a correction is saved to the song', (tester) async {
      await pumpPresenter(tester);
      await tester.tap(find.byTooltip('Editar slide').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Segunda'), 'Segunda estrofa');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('song:song-i1:2'));
      expect(find.text('Segunda estrofa'), findsWidgets);
    });

    testWidgets('a saved correction can be taken back from the notice', (tester) async {
      await pumpPresenter(tester);
      await tester.tap(find.byTooltip('Editar slide').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Segunda'), 'Segunda estrofa');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Guardado en «Sublime Gracia»'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect((control.state as ControlLoadedState).model.currentItem!.slides, [
        'Primera',
        'Segunda',
      ]);
    });

    testWidgets('a slide is split where the cursor is', (tester) async {
      await pumpPresenter(tester);
      await tester.tap(find.byTooltip('Editar slide').first);
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Primera');
      final controller = tester.widget<TextField>(field).controller!;
      await tester.enterText(field, 'Primera mitad segunda mitad');
      // At the end of the text there is nothing to split off.
      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Partir aquí')).onPressed,
        isNull,
      );
      controller.selection = const TextSelection.collapsed(offset: 14);
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Partir aquí'));
      await tester.pumpAndSettle();

      expect((control.state as ControlLoadedState).model.currentItem!.slides, [
        'Primera mitad',
        'segunda mitad',
        'Segunda',
      ]);
    });

    testWidgets('a slide libre is corrected but has nothing to split', (tester) async {
      await pumpPresenter(tester);
      control.selectItem(1);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Editar slide'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Reunión de jóvenes'), findsOneWidget);
      expect(find.text('Partir aquí'), findsNothing);
      expect(find.text('Quitar slide'), findsNothing);
    });
  });
}
