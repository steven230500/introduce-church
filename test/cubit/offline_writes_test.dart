import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late Directory dir;
  late FakeControlRepository repo;
  late FakePrefsService prefs;
  late ControlCubit control;

  /// What a machine with no route to the server actually throws.
  const noNetwork = SocketException('Failed host lookup: api.example.com');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('offline_writes');
    repo = FakeControlRepository(
      rows: [
        collectionRow(
          id: 'c1',
          items: [
            // Free slides, not songs: a song's name comes from the song row,
            // so renaming the item would not be visible on either path.
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'free_slide',
              order: 0,
              contentJson: {'text': 'algo', 'title': 'Uno'},
            ),
            itemRow(
              id: 'i2',
              collectionId: 'c1',
              type: 'free_slide',
              order: 1,
              contentJson: {'text': 'otra cosa', 'title': 'Dos'},
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
      pending: PendingWrites(file: File('${dir.path}/pending.json')),
    );
  });

  tearDown(() async {
    await control.close();
    dir.deleteSync(recursive: true);
  });

  ControlModel model() => (control.state as ControlLoadedState).model;

  Future<void> open() async {
    await control.load();
    control.selectCollection(model().collections.first);
  }

  test('a rename with no network is kept, not lost', () async {
    // Before this, the request threw into nothing: the operator saw the old
    // title, assumed the click had missed, and renamed it again.
    await open();
    repo.failWritesWith = noNetwork;

    await control.setItemTitle('i1', 'Bienvenida');

    expect(model().activeCollection!.items.first.displayTitle, 'Bienvenida');
    expect(model().offline, isTrue);
    expect(model().pendingWrites, 1);
  });

  test('it is sent by itself when the network comes back', () async {
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls, contains('title:i1:Bienvenida'));
    expect(model().pendingWrites, 0);
    expect(model().offline, isFalse);
  });

  test('the same rename four times is one request', () async {
    await open();
    repo.failWritesWith = noNetwork;
    for (final title in ['B', 'Bi', 'Bien', 'Bienvenida']) {
      await control.setItemTitle('i1', title);
    }

    expect(model().pendingWrites, 1);

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls.where((c) => c.startsWith('title:')), hasLength(1));
    expect(repo.calls, contains('title:i1:Bienvenida'));
  });

  test('two different changes both arrive, oldest first', () async {
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');
    await control.updateItemNotes('i2', 'leer lento');

    expect(model().pendingWrites, 2);

    repo.failWritesWith = null;
    await control.refresh();

    final sent = repo.calls.where((c) => c.startsWith('title:') || c.startsWith('notes:')).toList();
    expect(sent, ['title:i1:Bienvenida', 'notes:i2:leer lento']);
  });

  test('what was queued survives the app being closed', () async {
    // The network usually comes back after the laptop has been shut and
    // reopened, which is the case a queue in memory would not survive.
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');
    await control.close();

    final reopened = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites(file: File('${dir.path}/pending.json')),
    );
    addTearDown(reopened.close);
    repo.failWritesWith = null;
    await reopened.load();

    expect(repo.calls, contains('title:i1:Bienvenida'));
  });

  test('a request the server refuses is not retried forever', () async {
    // A 400 means the server has an opinion about this change. Replaying it on
    // every refresh would fail exactly the same way, every time, for good.
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');

    repo.failWritesWith = StateError('400 bad request');
    await control.refresh();

    expect(model().pendingWrites, 0, reason: 'dropped rather than stuck');
  });

  test('an error that is not the network still reaches the caller', () async {
    // Queuing a genuine failure would hide a real bug behind an offline mark.
    await open();
    repo.failWritesWith = StateError('column does not exist');

    await expectLater(control.setItemTitle('i1', 'Bienvenida'), throwsStateError);
    expect(model().offline, isFalse);
  });

  test('a new order made offline is kept in the order it was made', () async {
    await open();
    repo.failWritesWith = noNetwork;

    await control.reorderItem(0, 1);

    expect(model().activeCollection!.items.map((i) => i.id), ['i2', 'i1']);
    expect(model().pendingWrites, 1);

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls, contains('reorder:i2,i1'));
  });

  group('making and removing things with no network', () {
    const song = Song(
      id: 'song-1',
      title: 'Cuán grande es Él',
      verses: [
        Verse(
          id: 'v1',
          songId: 'song-1',
          type: VerseType.verse,
          order: 0,
          content: 'Señor mi Dios',
        ),
        Verse(id: 'v2', songId: 'song-1', type: VerseType.chorus, order: 1, content: 'Mi corazón'),
      ],
    );

    ControlCubit reopen({String? org}) {
      final cubit = ControlCubit(
        repo,
        FakeTemplateRepository(),
        prefs,
        FakePresentationSocket(),
        pending: PendingWrites(file: File('${dir.path}/pending.json')),
        currentOrg: () => org,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    List<String> serverItemIds(String collectionId) => [
      for (final item
          in repo.rows.firstWhere((r) => r['id'] == collectionId)['collection_items'] as List)
        item['id'] as String,
    ];

    test('a new service opens straight away, and reaches the server later', () async {
      // Planning next Sunday in the church building, where the wifi is off.
      await open();
      repo.failWritesWith = noNetwork;

      await control.createCollection('Culto de jóvenes');

      final made = model().activeCollection!;
      expect(made.name, 'Culto de jóvenes');
      expect(model().pendingWrites, 1);

      repo.failWritesWith = null;
      await control.refresh();

      expect(repo.rows.map((r) => r['id']), contains(made.id), reason: 'under the same id');
      expect(model().activeCollection!.id, made.id);
      expect(model().pendingWrites, 0);
    });

    test('what is added to a service made offline lands in it', () async {
      // The case the queue used to refuse: the service has no server id yet,
      // and the items point at it anyway.
      await open();
      repo.failWritesWith = noNetwork;
      await control.createCollection('Culto de jóvenes');
      await control.addSong(song);
      await control.addFreeSlide('Bienvenidos');
      final local = model().activeCollection!;

      expect(local.items.map((i) => i.displayTitle), ['Cuán grande es Él', 'Bienvenidos']);

      repo.failWritesWith = null;
      await control.refresh();

      expect(serverItemIds(local.id), local.items.map((i) => i.id));
      final sent = repo.calls.where((c) => !c.startsWith('title')).toList();
      expect(
        sent.indexOf('createCollection:Culto de jóvenes'),
        lessThan(sent.indexOf('addItems:1')),
      );
    });

    test('a song added offline shows its words before the server has them', () async {
      await open();
      repo.failWritesWith = noNetwork;

      await control.addSong(song);

      final added = model().activeCollection!.items.last;
      expect(added.slides, ['Señor mi Dios', 'Mi corazón']);
    });

    test('a removal with no network takes it off now and off the server later', () async {
      await open();
      repo.failWritesWith = noNetwork;

      await control.removeItem('i1');

      expect(model().activeCollection!.items.map((i) => i.id), ['i2']);
      expect(model().activeCollection!.items.single.order, 0);

      repo.failWritesWith = null;
      await control.refresh();

      expect(serverItemIds('c1'), ['i2']);
    });

    test('undo with no network puts the item back where it was, under its own id', () async {
      await open();
      repo.failWritesWith = noNetwork;
      final removed = model().activeCollection!.items.first;

      await control.removeItem(removed.id);
      await control.restoreItem(removed, 0);

      expect(model().activeCollection!.items.map((i) => i.id), ['i1', 'i2']);

      repo.failWritesWith = null;
      await control.refresh();

      expect(serverItemIds('c1'), ['i1', 'i2']);
      expect(model().activeCollection!.items.map((i) => i.id), ['i1', 'i2']);
    });

    test('a service deleted offline is gone now, and from the server later', () async {
      await open();
      repo.failWritesWith = noNetwork;

      await control.deleteCollection('c1');

      expect(model().collections, isEmpty);
      expect(model().activeCollection, isNull);

      repo.failWritesWith = null;
      await control.refresh();

      expect(repo.calls, contains('deleteCollection:c1'));
      expect(repo.rows, isEmpty);
    });

    test('a copy made offline carries its running order', () async {
      await open();
      repo.failWritesWith = noNetwork;

      final copy = await control.duplicateCollection(model().activeCollection!, name: 'Copia');

      expect(copy, isNotNull);
      expect(model().activeCollection!.name, 'Copia');
      expect(model().activeCollection!.items.map((i) => i.displayTitle), ['Uno', 'Dos']);
      expect(
        model().activeCollection!.items.map((i) => i.id),
        isNot(contains('i1')),
        reason: 'the copies are new items, not the originals moved',
      );
    });

    test('what was made offline is still there after the laptop is closed and reopened', () async {
      await open();
      repo.failWritesWith = noNetwork;
      await control.createCollection('Culto de jóvenes');
      await control.addFreeSlide('Bienvenidos');
      final made = model().activeCollection!.id;
      await control.close();

      repo.failWith = noNetwork;
      final reopened = reopen();
      await reopened.load();
      final collections = (reopened.state as ControlLoadedState).model.collections;

      final service = collections.where((c) => c.id == made).single;
      expect(service.items.single.displayTitle, 'Bienvenidos');
    });

    test('a new change waits behind the ones still queued', () async {
      // Sent straight away, the item would reach the server before the
      // service it belongs to, and be refused for pointing at nothing.
      await open();
      repo.failWritesWith = noNetwork;
      await control.createCollection('Culto de jóvenes');
      repo.failWritesWith = null;

      await control.addFreeSlide('Bienvenidos');

      final sent = repo.calls.where((c) => c.startsWith('create') || c.startsWith('add')).toList();
      expect(sent.first, 'createCollection:Culto de jóvenes');
      expect(serverItemIds(model().activeCollection!.id), hasLength(1));
      expect(model().pendingWrites, 0);
    });

    test('a queue stops at the first change the network drops', () async {
      // The wifi back for the second request and not the first must not send
      // the items of a service the server has not been told about.
      await open();
      repo.failWritesWith = noNetwork;
      await control.createCollection('Culto de jóvenes');
      await control.addFreeSlide('Bienvenidos');

      repo.failWritesWith = null;
      repo.networkDownFor = (call) => call == 'createCollection';
      await control.refresh();

      expect(repo.calls.where((c) => c.startsWith('addItems')), isEmpty);
      expect(model().pendingWrites, 2, reason: 'both still waiting, neither dropped');
    });

    test('another church signing in does not send this church\'s changes', () async {
      // Changes waiting, someone signs out, another church signs in on the
      // same laptop: its library must not receive the first church's service.
      await control.close();
      final first = reopen(org: 'iglesia-a');
      await first.load();
      first.selectCollection((first.state as ControlLoadedState).model.collections.first);
      repo.failWritesWith = noNetwork;
      await first.createCollection('Culto de jóvenes');
      await first.close();

      repo.failWritesWith = null;
      final second = reopen(org: 'iglesia-b');
      await second.load();

      expect(repo.calls, isNot(contains('createCollection:Culto de jóvenes')));
      final seen = (second.state as ControlLoadedState).model;
      expect(seen.collections.map((c) => c.name), isNot(contains('Culto de jóvenes')));
      expect(seen.pendingWrites, 0);
      await second.close();

      final back = reopen(org: 'iglesia-a');
      await back.load();

      expect(repo.calls, contains('createCollection:Culto de jóvenes'));
    });

    test(
      'what is queued goes out when the network returns, with nobody touching anything',
      () async {
        // Otherwise a service planned offline on Saturday waits for someone to
        // change something before the other computers ever see it.
        await open();
        repo.failWritesWith = noNetwork;
        await control.createCollection('Culto de jóvenes');
        control.keepRetrying(every: const Duration(milliseconds: 20));

        repo.failWritesWith = null;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(repo.calls, contains('createCollection:Culto de jóvenes'));
        expect(model().pendingWrites, 0);
        expect(model().offline, isFalse);
      },
    );

    test('the projector is handed the plan on the screen, not the last download', () async {
      // Reordered with no network, the operator's item two was the projector's
      // item one, and the next press put the wrong song on the wall.
      await open();
      repo.failWritesWith = noNetwork;

      await control.reorderItem(0, 1);

      final projected = Collection.fromJson(control.projectedCollection!);
      expect(projected.items.map((i) => i.id), ['i2', 'i1']);
    });
  });
}
