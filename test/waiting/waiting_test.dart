import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/history/projection_recorder.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/motion/motion_scenes.dart';
import 'package:introduce_church/core/waiting/waiting_screen.dart';
import 'package:introduce_church/modules/display/presenter/display_cubit.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/waiting_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  group('what travels over the wire', () {
    test('a waiting screen survives the trip', () {
      const config = WaitingConfig(
        active: true,
        scene: MotionScene.stars,
        title: 'Casa Vida',
        subtitle: 'Bienvenidos',
        showClock: true,
      );

      expect(WaitingConfig.fromJson(config.toJson()), config);
    });

    test('nothing, or nonsense, reads as no waiting screen', () {
      // The safe way to be wrong: the room sees what was meant to be there.
      expect(WaitingConfig.fromJson(null).active, isFalse);
      expect(WaitingConfig.fromJson('garbage').active, isFalse);
      expect(WaitingConfig.fromJson({'active': 'yes'}).active, isFalse);
    });

    test('a scene this version does not know falls back to one it does', () {
      expect(
        WaitingConfig.fromJson({'active': true, 'scene': 'holograma'}).scene,
        MotionScene.aurora,
      );
    });
  });

  group('the presenter', () {
    late ControlCubit control;
    late FakePrefsService prefs;

    setUp(() async {
      prefs = FakePrefsService();
      control = ControlCubit(
        FakeControlRepository(
          rows: [
            collectionRow(
              id: 'c1',
              items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Coro')],
            ),
          ],
        ),
        FakeTemplateRepository(),
        prefs,
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
      control.selectCollection((control.state as ControlLoadedState).model.collections.first);
    });

    tearDown(() => control.close());

    ControlModel model() => (control.state as ControlLoadedState).model;

    const loop = WaitingConfig(scene: MotionScene.light, title: 'Casa Vida');

    test('putting a waiting screen up puts it on the screen', () {
      // An operator pressing it before the service expects the room to see it,
      // not to also find and press "live" first.
      control.showWaiting(loop);

      expect(model().waiting.active, isTrue);
      expect(model().isLive, isTrue);
      expect(model().blankScreen, isFalse);
    });

    test('it takes black off, because the scene is what was asked for', () {
      control.toggleLive();
      control.toggleBlank();

      control.showWaiting(loop);

      expect(model().blankScreen, isFalse);
    });

    test('the one chosen is remembered for next Sunday', () async {
      control.showWaiting(loop);
      await Future<void>.delayed(Duration.zero);

      final remembered = WaitingConfig.fromJson(prefs.waiting);
      expect(remembered.scene, MotionScene.light);
      expect(remembered.title, 'Casa Vida');
      expect(remembered.active, isFalse, reason: 'remembered as a choice, not as up');
    });

    test('W brings the last one back', () async {
      control.showWaiting(loop);
      control.hideWaiting();
      expect(model().waiting.active, isFalse);

      await control.toggleWaiting();

      expect(model().waiting.active, isTrue);
      expect(model().waiting.title, 'Casa Vida');
    });

    test('a refresh does not take the waiting screen down', () async {
      control.showWaiting(loop);

      await control.refresh();

      expect(model().waiting.active, isTrue);
    });

    test('a waiting screen is not recorded as part of the service', () {
      // A loop left up for twenty minutes before the service is not twenty
      // minutes of the first song.
      control.showWaiting(loop);

      expect(onAirIn(control.state), isNull);
    });
  });

  group('the projector', () {
    Future<DisplayState> render(Map<String, dynamic> row) async {
      final display = DisplayCubit(fakeApiClient(), FakePresentationSocket());
      addTearDown(display.close);
      await display.applyLocalState(row);
      return display.state;
    }

    const up = {
      'active': true,
      'scene': 'waves',
      'title': 'Casa Vida',
      'subtitle': '',
      'clock': false,
    };

    test('shows the waiting scene when it is up and the signal is live', () async {
      final state = await render({'is_live': true, 'blank_screen': false, 'waiting': up});

      expect(state, isA<DisplayWaitingState>());
      expect((state as DisplayWaitingState).config.scene, MotionScene.waves);
    });

    test('cutting the signal takes the scene down too', () async {
      final state = await render({'is_live': false, 'blank_screen': false, 'waiting': up});

      expect(state, isNot(isA<DisplayWaitingState>()));
    });

    test('black wins over the scene', () async {
      final state = await render({'is_live': true, 'blank_screen': true, 'waiting': up});

      expect(state, isA<DisplayBlankState>());
    });

    test('a running countdown shows on the scene instead of on its own', () async {
      final end = DateTime.now().add(const Duration(minutes: 5));
      final state = await render({
        'is_live': true,
        'blank_screen': false,
        'countdown_active': true,
        'countdown_end': end.toUtc().toIso8601String(),
        'waiting': up,
      });

      expect(state, isA<DisplayWaitingState>());
      expect((state as DisplayWaitingState).countdownEnd, isNotNull);
    });
  });

  group('the words on the scene', () {
    testWidgets('the title and message are shown over the scene', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 960,
            height: 540,
            child: WaitingScreen(
              animate: false,
              config: WaitingConfig(active: true, title: 'Casa Vida', subtitle: 'Bienvenidos'),
            ),
          ),
        ),
      );

      expect(find.text('Casa Vida'), findsOneWidget);
      expect(find.text('Bienvenidos'), findsOneWidget);
    });

    testWidgets('the clock reads the time of day', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 960,
            height: 540,
            child: WaitingScreen(
              animate: false,
              now: () => DateTime(2026, 6, 28, 9, 5),
              config: const WaitingConfig(active: true, showClock: true),
            ),
          ),
        ),
      );

      expect(find.text('09:05'), findsOneWidget);
    });

    testWidgets('a countdown replaces the clock', (tester) async {
      final now = DateTime(2026, 6, 28, 9, 55);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 960,
            height: 540,
            child: WaitingScreen(
              animate: false,
              now: () => now,
              countdownEnd: now.add(const Duration(minutes: 4, seconds: 30)),
              config: const WaitingConfig(active: true, showClock: true),
            ),
          ),
        ),
      );

      expect(find.text('4:30'), findsOneWidget);
      expect(find.text('09:55'), findsNothing);
    });
  });

  group('choosing one', () {
    late ControlCubit control;

    setUp(() async {
      control = ControlCubit(
        FakeControlRepository(rows: [collectionRow(id: 'c1')]),
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
    });

    tearDown(() => control.close());

    Future<void> pumpDialog(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BlocProvider.value(
          value: control,
          child: localizedApp(
            const WaitingDialog(initial: WaitingConfig(title: 'Casa Vida'), animate: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fits the smallest window the app allows, every scene in view', (tester) async {
      // It was taller than that window, and the last scene hid behind the
      // edge of a scrolling strip where most people would never find it.
      await pumpDialog(tester);

      expect(tester.takeException(), isNull);
      for (final name in [
        'Aurora',
        'Luces',
        'Mar',
        'Amanecer',
        'Estrellas',
        'Sereno',
        'Bruma',
        'Luz de lo alto',
        'Seda',
      ]) {
        expect(find.text(name), findsOneWidget, reason: '$name must be visible');
      }
    });

    testWidgets('picking a scene and pressing show puts it up', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Estrellas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar en pantalla'));
      await tester.pumpAndSettle();

      final model = (control.state as ControlLoadedState).model;
      expect(model.waiting.active, isTrue);
      expect(model.waiting.scene, MotionScene.stars);
      expect(model.waiting.title, 'Casa Vida');
    });
  });
}
