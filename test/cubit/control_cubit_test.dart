import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late FakeTemplateRepository templates;
  late ControlCubit cubit;

  /// One collection holding a three-verse song and a two-verse song.
  List<Map<String, dynamic>> twoSongs() => [
    collectionRow(
      id: 'c1',
      name: 'Culto domingo',
      items: [
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          title: 'Primera',
          verses: ['a', 'b', 'c'],
        ),
        songItemRow(id: 'i2', collectionId: 'c1', order: 1, title: 'Segunda', verses: ['d', 'e']),
      ],
    ),
  ];

  setUp(() {
    repo = FakeControlRepository(rows: twoSongs());
    templates = FakeTemplateRepository();
    cubit = ControlCubit(repo, templates, FakePrefsService(), FakePresentationSocket());
  });

  tearDown(() => cubit.close());

  ControlModel model() => (cubit.state as ControlLoadedState).model;

  /// Records every state emitted while [action] runs.
  ///
  /// Stream events arrive on a later microtask, so the queue is drained before
  /// the subscription is cancelled. Without the drain the list comes back empty
  /// and every assertion on it passes for the wrong reason.
  Future<List<ControlState>> statesDuring(Future<void> Function() action) async {
    final states = <ControlState>[];
    final sub = cubit.stream.listen(states.add);
    await action();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return states;
  }

  /// Loads and opens the first collection, the state most tests start from.
  Future<void> openFirstCollection() async {
    await cubit.load();
    cubit.selectCollection(model().collections.first);
  }

  group('load', () {
    test('goes from loading to loaded', () async {
      final states = await statesDuring(cubit.load);

      expect(states.first, isA<ControlLoadingState>());
      expect(states.last, isA<ControlLoadedState>());
      expect(model().collections, hasLength(1));
    });

    test('reports an error when the read fails and nothing is cached', () async {
      repo.failWith = Exception('boom');

      await cubit.load();

      expect(cubit.state, isA<ControlErrorState>());
    });

    test('falls back to cached collections when the network is down', () async {
      final prefs = FakePrefsService();
      final offline = ControlCubit(repo, templates, prefs, FakePresentationSocket());
      await offline.load(); // primes the cache
      repo.failWith = Exception('Failed host lookup: supabase.co');

      await offline.load();

      expect(offline.state, isA<ControlLoadedState>());
      expect((offline.state as ControlLoadedState).model.collections, hasLength(1));
      await offline.close();
    });
  });

  group('refresh', () {
    test('never emits a loading state, so the set list stays on screen', () async {
      await openFirstCollection();
      // Change the data so the reload produces a genuinely new state. Bloc
      // suppresses an emit equal to the current state, so an unchanged refresh
      // emits nothing at all and would prove nothing here.
      repo.rows = [
        collectionRow(
          id: 'c1',
          name: 'Culto domingo',
          items: [
            songItemRow(id: 'i1', collectionId: 'c1', order: 0, verses: ['a', 'b', 'c']),
          ],
        ),
      ];

      final states = await statesDuring(cubit.refresh);

      expect(states, isNotEmpty, reason: 'refresh must publish the new data');
      expect(states.whereType<ControlLoadingState>(), isEmpty);
      expect(cubit.state, isA<ControlLoadedState>());
    });

    test('an unchanged refresh publishes nothing, avoiding a needless rebuild', () async {
      await openFirstCollection();

      final states = await statesDuring(cubit.refresh);

      expect(states, isEmpty);
    });

    test('keeps the projector live across a reload', () async {
      await openFirstCollection();
      cubit.toggleLive();
      expect(model().isLive, isTrue);

      await cubit.refresh();

      expect(model().isLive, isTrue);
    });

    test('keeps the cursor where the operator left it', () async {
      await openFirstCollection();
      cubit.selectItem(1);
      cubit.selectSlide(1);

      await cubit.refresh();

      expect(model().currentItemIndex, 1);
      expect(model().currentSlideIndex, 1);
    });

    test('pulls the cursor back in range when items were removed', () async {
      await openFirstCollection();
      cubit.selectItem(1);
      repo.rows = [
        collectionRow(
          id: 'c1',
          name: 'Culto domingo',
          items: [
            songItemRow(id: 'i1', collectionId: 'c1', order: 0, verses: ['a']),
          ],
        ),
      ];

      await cubit.refresh();

      expect(model().currentItemIndex, 0);
    });

    test('keeps the blank screen on across a reload', () async {
      await openFirstCollection();
      cubit.toggleBlank();

      await cubit.refresh();

      expect(model().blankScreen, isTrue);
    });
  });

  group('mutations', () {
    test('adding a song writes through and reloads without a spinner', () async {
      await openFirstCollection();

      final states = await statesDuring(() => cubit.addSong('song-9'));

      expect(repo.calls, contains('addSong:song-9'));
      expect(states, isNotEmpty);
      expect(states.whereType<ControlLoadingState>(), isEmpty);
    });

    test('removing an item does not blank the screen either', () async {
      await openFirstCollection();

      final states = await statesDuring(() => cubit.removeItem('i2'));

      expect(repo.calls, contains('removeItem:i2'));
      expect(states, isNotEmpty);
      expect(states.whereType<ControlLoadingState>(), isEmpty);
    });

    test('reorder moves the item locally before the server confirms', () async {
      await openFirstCollection();

      await cubit.reorderItem(0, 1);

      expect(model().activeCollection!.items.map((i) => i.id), ['i2', 'i1']);
      expect(repo.calls, contains('reorder:i2,i1'));
    });
  });

  group('slide navigation', () {
    test('advances within an item', () async {
      await openFirstCollection();

      cubit.nextSlide();

      expect(model().currentSlideIndex, 1);
      expect(model().currentItemIndex, 0);
    });

    test('rolls onto the next item from the last slide', () async {
      await openFirstCollection();
      cubit.selectSlide(2); // last verse of the first song

      cubit.nextSlide();

      expect(model().currentItemIndex, 1);
      expect(model().currentSlideIndex, 0);
    });

    test('going back from a first slide lands on the previous item last slide', () async {
      await openFirstCollection();
      cubit.selectItem(1);

      cubit.prevSlide();

      expect(model().currentItemIndex, 0);
      expect(model().currentSlideIndex, 2);
    });

    test('stops at both ends instead of wrapping', () async {
      await openFirstCollection();

      cubit.prevSlide();
      expect(model().currentItemIndex, 0);
      expect(model().currentSlideIndex, 0);

      cubit.selectItem(1);
      cubit.selectSlide(1);
      cubit.nextSlide();
      expect(model().currentItemIndex, 1);
      expect(model().currentSlideIndex, 1);
    });

    test('mirrors every move to the display window', () async {
      await openFirstCollection();
      final before = repo.syncs;

      cubit.nextSlide();

      expect(repo.syncs, greaterThan(before));
    });
  });

  group('projector state', () {
    test('live and blank toggle independently', () async {
      await openFirstCollection();

      cubit.toggleLive();
      cubit.toggleBlank();

      expect(model().isLive, isTrue);
      expect(model().blankScreen, isTrue);

      cubit.toggleBlank();
      expect(model().isLive, isTrue);
      expect(model().blankScreen, isFalse);
    });

    test('a countdown records its end time and clears it on stop', () async {
      await openFirstCollection();

      cubit.startCountdown(600);
      expect(model().countdownActive, isTrue);
      expect(model().countdownEnd, isNotNull);

      cubit.stopCountdown();
      expect(model().countdownActive, isFalse);
      expect(model().countdownEnd, isNull);
    });

    test('overlay text survives hiding the overlay', () async {
      await openFirstCollection();

      cubit.setOverlayText('Bienvenidos');
      cubit.toggleOverlay();
      cubit.toggleOverlay();

      expect(model().overlayVisible, isFalse);
      expect(model().overlayText, 'Bienvenidos');
    });
  });

  group('designs', () {
    test('applying a design to the collection updates it in place', () async {
      await openFirstCollection();

      await cubit.setCollectionTemplate('c1', SlideTemplate.light.id);

      expect(model().activeCollection!.templateId, SlideTemplate.light.id);
      expect(templates.calls, contains('collectionTemplate:c1:${SlideTemplate.light.id}'));
    });

    test('an item design overrides the collection design', () async {
      await openFirstCollection();
      await cubit.setCollectionTemplate('c1', SlideTemplate.light.id);

      await cubit.setItemTemplate('c1', 'i1', SlideTemplate.blueNight.id);

      expect(model().activeTemplate.id, SlideTemplate.blueNight.id);
    });

    test('clearing an item design falls back to the collection design', () async {
      await openFirstCollection();
      await cubit.setCollectionTemplate('c1', SlideTemplate.light.id);
      await cubit.setItemTemplate('c1', 'i1', SlideTemplate.blueNight.id);

      await cubit.setItemTemplate('c1', 'i1', null);

      expect(model().activeTemplate.id, SlideTemplate.light.id);
    });
  });
}
