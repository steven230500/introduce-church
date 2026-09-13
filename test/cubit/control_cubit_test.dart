import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
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
      final model = (offline.state as ControlLoadedState).model;
      expect(model.collections, hasLength(1));
      // The service runs from the disk, but nothing edited now is being saved
      // anywhere else, and the operator has no other way to find that out.
      expect(model.offline, isTrue);
      await offline.close();
    });

    test('a read that reaches the server clears the warning', () async {
      await cubit.load();

      expect((cubit.state as ControlLoadedState).model.offline, isFalse);
    });

    test('a church with no internet still gets its own design', () async {
      // Falling back to the built-in design the moment the router is off
      // changes what the congregation sees for reasons nobody in the room can
      // explain. The cache is read by a second cubit because the real case is
      // the app being started in a building that has never had a signal.
      final prefs = FakePrefsService();
      templates.templates = [SlideTemplate.blueNight];

      final primed = ControlCubit(repo, templates, prefs, FakePresentationSocket());
      await primed.load();
      await primed.close();

      final offline = ControlCubit(repo, templates, prefs, FakePresentationSocket());
      repo.failWith = Exception('Failed host lookup: api.introduce.test');
      await offline.load();

      final model = (offline.state as ControlLoadedState).model;
      expect(model.userTemplates.map((t) => t.id), [SlideTemplate.blueNight.id]);
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

  group('holding the screen', () {
    test('by default the projector goes wherever the operator goes', () async {
      await openFirstCollection();

      cubit.selectItem(1);

      expect(model().liveItemIndex, 1);
      expect(model().isHolding, isFalse);
      expect(repo.lastSync, (1, 0));
    });

    test('held, the projector stays put while the operator browses', () async {
      // The reason this exists: finding the next song during the sermon used
      // to put the next song on the wall.
      await openFirstCollection();
      cubit.setFollowCursor(false);

      cubit.selectItem(1);
      cubit.selectSlide(1);

      expect(model().currentItemIndex, 1);
      expect(model().currentSlideIndex, 1);
      expect(model().liveItemIndex, 0);
      expect(model().liveSlideIndex, 0);
      expect(model().isHolding, isTrue);
    });

    test('nothing goes out to the projector while it is held', () async {
      await openFirstCollection();
      cubit.setFollowCursor(false);
      repo.syncs = 0;

      cubit.selectItem(1);
      cubit.nextSlide();

      expect(repo.syncs, 0);
    });

    test('sending catches the projector up', () async {
      await openFirstCollection();
      cubit.setFollowCursor(false);
      cubit.selectItem(1);

      cubit.take();

      expect(model().liveItemIndex, 1);
      expect(model().isHolding, isFalse);
      expect(repo.lastSync, (1, 0));
    });

    test('sending twice does nothing the second time', () async {
      await openFirstCollection();
      cubit.setFollowCursor(false);
      cubit.selectSlide(2);
      cubit.take();
      repo.syncs = 0;

      cubit.take();

      expect(repo.syncs, 0);
    });

    test('following again sends what is being looked at', () async {
      // Leaving the screen behind after the operator says "follow me" is the
      // surprise the whole mode exists to avoid.
      await openFirstCollection();
      cubit.setFollowCursor(false);
      cubit.selectItem(1);

      cubit.setFollowCursor(true);

      expect(model().liveItemIndex, 1);
      expect(repo.lastSync, (1, 0));
    });

    test('what goes out is the live position, never the cursor', () async {
      await openFirstCollection();
      cubit.setFollowCursor(false);
      cubit.selectSlide(2);
      cubit.toggleBlank();

      // Blanking publishes state, and that publish must not leak the cursor.
      expect(repo.lastSync, (0, 0));
    });

    test('the item on screen keeps its own auto-advance clock', () async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              verses: ['a', 'b'],
              autoAdvanceSecs: 1,
            ),
            songItemRow(id: 'i2', collectionId: 'c1', order: 1, verses: ['c']),
          ],
        ),
      ];
      await openFirstCollection();
      cubit.toggleLive();
      cubit.setFollowCursor(false);
      cubit.selectItem(1);

      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // The projector moved on; the operator's cursor did not move with it.
      expect(model().liveSlideIndex, 1);
      expect(model().currentItemIndex, 1);
    });
  });

  group('duplicating a service', () {
    test('carries the whole running order into the copy', () async {
      // Most services share a skeleton, and rebuilding it every week is the
      // kind of work an app is for.
      await openFirstCollection();
      final source = model().activeCollection!;

      await cubit.duplicateCollection(source, name: 'Culto siguiente');

      expect(repo.calls, contains('createCollection:Culto siguiente'));
      expect(repo.calls, contains('copyItems:2'));
      expect(model().activeCollection!.name, 'Culto siguiente');
      expect(model().activeCollection!.items.map((i) => i.displayTitle), ['Primera', 'Segunda']);
    });

    test('the copy opens, so the next edit lands in it', () async {
      await openFirstCollection();
      final source = model().activeCollection!;

      await cubit.duplicateCollection(source, name: 'Copia');

      expect(model().activeCollection!.id, isNot(source.id));
      expect(model().collections, hasLength(2));
    });

    test('the design comes along, because a copy that looks different is not one', () async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          templateId: SlideTemplate.blueNight.id,
          items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0)],
        ),
      ];
      await openFirstCollection();

      await cubit.duplicateCollection(model().activeCollection!, name: 'Copia');

      expect(
        templates.calls,
        contains('collectionTemplate:new-collection:${SlideTemplate.blueNight.id}'),
      );
    });

    test('an empty plan copies as an empty plan, not as a failure', () async {
      repo.rows = [collectionRow(id: 'c1', name: 'Vacía')];
      await openFirstCollection();

      await cubit.duplicateCollection(model().activeCollection!, name: 'Copia');

      expect(model().activeCollection!.items, isEmpty);
      expect(repo.calls.where((c) => c.startsWith('copyItems')), isEmpty);
    });
  });

  group('a verse looked up mid-sermon', () {
    BibleVerseRef verse() => const BibleVerseRef(
      versionCode: 'rvr1960',
      versionName: 'Reina Valera 1960',
      bookIndex: 42,
      bookName: 'Juan',
      bookAbbrev: 'jo',
      chapter: 3,
      verseStart: 16,
      verseEnd: 16,
      texts: ['Porque de tal manera amó Dios al mundo...'],
    );

    test('lands right after what is on screen, not at the end', () async {
      // Left at the end it would be out of order in the plan, and the press
      // after it would land past the end of the service.
      await openFirstCollection();

      await cubit.addBibleVerseAfterCurrent(verse());

      expect(model().activeCollection!.items.map((i) => i.displayTitle), [
        'Primera',
        'Juan 3:16',
        'Segunda',
      ]);
    });

    test('the operator is taken to it', () async {
      await openFirstCollection();

      await cubit.addBibleVerseAfterCurrent(verse());

      expect(model().currentItemIndex, 1);
      expect(model().currentItem!.displayTitle, 'Juan 3:16');
    });

    test('an empty plan takes it as the first item', () async {
      repo.rows = [collectionRow(id: 'c1')];
      await openFirstCollection();

      await cubit.addBibleVerseAfterCurrent(verse());

      expect(model().activeCollection!.items.single.displayTitle, 'Juan 3:16');
      expect(model().currentItemIndex, 0);
    });
  });

  group('undo a removal', () {
    test('puts the item back where it was, not at the end', () async {
      await openFirstCollection();
      final removed = model().activeCollection!.items.first;

      await cubit.removeItem(removed.id);
      expect(model().activeCollection!.items.map((i) => i.displayTitle), ['Segunda']);

      await cubit.restoreItem(removed, 0);

      expect(model().activeCollection!.items.map((i) => i.displayTitle), ['Primera', 'Segunda']);
    });

    test('carries the note and the auto-advance back with it', () async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'free_slide',
              order: 0,
              contentJson: {'title': 'Aviso', 'text': 'Hola'},
              notes: 'Bajar el volumen',
              autoAdvanceSecs: 15,
            ),
          ],
        ),
      ];
      await openFirstCollection();
      final removed = model().activeCollection!.items.single;

      await cubit.removeItem(removed.id);
      await cubit.restoreItem(removed, 0);

      final back = model().activeCollection!.items.single;
      expect(back.notes, 'Bajar el volumen');
      expect(back.autoAdvanceSecs, 15);
      expect(back.displayTitle, 'Aviso');
    });

    test('leaves a one-item list alone rather than reordering nothing', () async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Sola')],
        ),
      ];
      await openFirstCollection();
      final removed = model().activeCollection!.items.single;

      await cubit.removeItem(removed.id);
      await cubit.restoreItem(removed, 0);

      expect(model().activeCollection!.items.map((i) => i.displayTitle), ['Sola']);
      expect(repo.calls.where((c) => c.startsWith('reorder')), isEmpty);
    });
  });

  group('renaming', () {
    test('changes the title without touching the rest of the content', () async {
      repo.rows = [
        collectionRow(
          id: 'c1',
          items: [
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'image_slide',
              order: 0,
              contentJson: {
                'title': 'ChatGPT Image 9 jul 2026.png',
                'paths': ['/a.png', '/b.png'],
              },
            ),
          ],
        ),
      ];
      await openFirstCollection();

      await cubit.setItemTitle('i1', 'Bienvenida');

      final item = model().activeCollection!.items.single;
      expect(item.displayTitle, 'Bienvenida');
      expect(item.slides, ['/a.png', '/b.png']);
    });
  });

  group('jumping around the set list', () {
    test('a number key past the end of the plan does nothing', () async {
      await openFirstCollection();

      cubit.selectItem(9);

      expect(model().currentItemIndex, 0);
    });

    test('End goes to the last slide of the item on screen', () async {
      await openFirstCollection();

      cubit.lastSlide();

      expect(model().currentSlideIndex, 2);
    });

    test('Escape uncovers the screen and never covers it', () async {
      await openFirstCollection();

      cubit.clearBlank();
      expect(model().blankScreen, isFalse);

      cubit.toggleBlank();
      expect(model().blankScreen, isTrue);

      cubit.clearBlank();
      expect(model().blankScreen, isFalse);
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
