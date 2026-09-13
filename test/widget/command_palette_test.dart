import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/media_item.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/command_palette.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;
  late ShellCubit shell;

  final songs = [
    const Song(id: 's1', title: 'NADA ES IMPOSIBLE', author: 'Un Corazón'),
    const Song(id: 's2', title: 'Bautizados en fuego'),
    const Song(id: 's3', title: 'Perfume a tus pies'),
    const Song(id: 's4', title: 'Bautizados otra vez'),
  ];

  const media = [
    MediaItem(
      id: 'm1',
      name: 'Cuenta regresiva',
      url: 'https://example.test/countdown.mp4',
      storagePath: 'videos/countdown.mp4',
      mediaType: MediaType.video,
    ),
  ];

  setUp(() {
    repo = FakeControlRepository(
      rows: [collectionRow(id: 'c1', name: 'Domingo')],
    );
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    shell = ShellCubit(prefs: FakePrefsService());
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  ControlModel model() => (control.state as ControlLoadedState).model;

  Future<void> pump(WidgetTester tester, {bool openService = true}) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await control.load();
    if (openService) control.selectCollection(model().collections.first);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: localizedApp(CommandPalette(songs: songs, media: media)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  group('finding things by name', () {
    testWidgets('a song is found by part of its title', (tester) async {
      await pump(tester);

      await type(tester, 'imposible');

      expect(find.text('NADA ES IMPOSIBLE'), findsOneWidget);
      expect(find.text('Bautizados en fuego'), findsNothing);
    });

    testWidgets('accents are not needed, because nobody types them in a hurry', (tester) async {
      await pump(tester);

      await type(tester, 'corazon');

      expect(find.text('NADA ES IMPOSIBLE'), findsOneWidget);
    });

    testWidgets('media is found alongside songs', (tester) async {
      await pump(tester);

      await type(tester, 'cuenta');

      expect(find.text('Cuenta regresiva'), findsOneWidget);
    });

    testWidgets('a control of the live bar is reachable by name', (tester) async {
      // The point of a palette: one place to type the name of the thing you
      // want, whether it is content or a control.
      await pump(tester);

      await type(tester, 'negro');

      expect(find.textContaining('negro'), findsWidgets);
    });

    testWidgets('a typed reference is offered before anything else', (tester) async {
      // Somebody who writes "jn 3:16" wants the passage, not a song whose
      // title happens to contain a 3.
      await pump(tester);

      await type(tester, 'jn 3:16');

      expect(find.textContaining('Juan 3:16'), findsOneWidget);
    });

    testWidgets('a query that matches nothing says so, with what was typed', (tester) async {
      await pump(tester);

      await type(tester, 'zzzzz');

      expect(find.textContaining('Nada coincide'), findsOneWidget);
    });
  });

  group('choosing a result', () {
    testWidgets('a song goes into the open service', (tester) async {
      await pump(tester);
      await type(tester, 'bautizados');

      await tester.tap(find.text('Bautizados en fuego'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('addSong:s2'));
    });

    testWidgets('Enter takes the first result, without touching the mouse', (tester) async {
      // A palette that needs the mouse is a menu.
      await pump(tester);
      await type(tester, 'bautizados');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.calls, contains('addSong:s2'));
    });

    testWidgets('the arrow keys move the choice before Enter takes it', (tester) async {
      // Two songs match, so pressing down once and Enter must take the second
      // one and not the first.
      await pump(tester);
      await type(tester, 'bautizados');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.calls, contains('addSong:s4'));
      expect(repo.calls, isNot(contains('addSong:s2')));
    });
  });

  group('with no service open', () {
    testWidgets('it says why adding is not possible instead of failing quietly', (tester) async {
      await pump(tester, openService: false);

      expect(find.textContaining('Abre un servicio'), findsOneWidget);
    });

    testWidgets('a song cannot be added to a service that is not open', (tester) async {
      await pump(tester, openService: false);
      await type(tester, 'bautizados');

      await tester.tap(find.text('Bautizados en fuego'));
      await tester.pumpAndSettle();

      expect(repo.calls.where((c) => c.startsWith('addSong')), isEmpty);
    });
  });
}
