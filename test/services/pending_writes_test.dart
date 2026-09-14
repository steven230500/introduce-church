import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/services/pending_writes.dart';

void main() {
  late Directory dir;
  late PendingWrites queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pending_writes');
    queue = PendingWrites(file: File('${dir.path}/pending.json'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  PendingWrite rename(String itemId, String title) =>
      PendingWrite(kind: PendingKind.itemTitle, target: itemId, args: {'title': title});

  group('what is waiting to be sent', () {
    test('nothing, on a machine that has always had internet', () async {
      expect(await queue.load(), isEmpty);
    });

    test('a change survives the app being closed', () async {
      // The network usually comes back long after the operator has gone home
      // and shut the laptop.
      await queue.add(rename('i1', 'Bienvenida'));

      final reopened = PendingWrites(file: File('${dir.path}/pending.json'));

      expect((await reopened.load()).single.args['title'], 'Bienvenida');
    });

    test('the same field changed four times is sent once', () async {
      for (final title in ['B', 'Bi', 'Bien', 'Bienvenida']) {
        await queue.add(rename('i1', title));
      }

      final waiting = await queue.load();

      expect(waiting, hasLength(1));
      expect(waiting.single.args['title'], 'Bienvenida', reason: 'the last one wins');
    });

    test('different fields on the same item are both kept', () async {
      await queue.add(rename('i1', 'Bienvenida'));
      await queue.add(
        const PendingWrite(
          kind: PendingKind.itemNotes,
          target: 'i1',
          args: {'notes': 'leer lento'},
        ),
      );

      expect(await queue.load(), hasLength(2));
    });

    test('the order they were made in is the order they are sent in', () async {
      await queue.add(rename('i1', 'uno'));
      await queue.add(rename('i2', 'dos'));

      expect((await queue.load()).map((w) => w.target), ['i1', 'i2']);
    });

    test('a file left half-written by a crash costs the queue, not the app', () async {
      final file = File('${dir.path}/pending.json')..writeAsStringSync('[{"kind":');

      final recovered = PendingWrites(file: file);

      expect(await recovered.load(), isEmpty);
    });

    test('a kind written by a newer version is skipped, not fatal', () async {
      final file = File('${dir.path}/pending.json')
        ..writeAsStringSync(
          '[{"kind":"teletransporte","target":"i1","args":{}},'
          '{"kind":"itemTitle","target":"i2","args":{"title":"Ok"}}]',
        );

      final loaded = await PendingWrites(file: file).load();

      expect(loaded, hasLength(1));
      expect(loaded.single.target, 'i2');
    });

    test('an emptied queue leaves no file behind', () async {
      await queue.add(rename('i1', 'x'));
      await queue.clear();

      expect(File('${dir.path}/pending.json').existsSync(), isFalse);
    });
  });

  group('showing the change before it is sent', () {
    CollectionItem item(String id, int order, {String? title}) => CollectionItem(
      id: id,
      collectionId: 'c1',
      type: CollectionItemType.freeSlide,
      order: order,
      contentJson: {'text': 'algo', 'title': ?title},
    );

    Collection collection() => Collection(
      id: 'c1',
      name: 'Domingo',
      items: [
        item('i1', 0, title: 'Uno'),
        item('i2', 1, title: 'Dos'),
      ],
    );

    test('a rename shows straight away', () {
      // Otherwise the operator renames it, sees the old title, and renames it
      // again - which is the silence this whole queue exists to end.
      final after = applyPendingWrite(collection(), rename('i1', 'Bienvenida'));

      expect(after.items.first.contentJson?['title'], 'Bienvenida');
    });

    test('a rename leaves the rest of the item alone', () {
      // The title lives beside the slide paths and the sermon points.
      final after = applyPendingWrite(collection(), rename('i1', 'Bienvenida'));

      expect(after.items.first.contentJson?['text'], 'algo');
    });

    test('a change to another collection touches nothing here', () {
      final elsewhere = const PendingWrite(
        kind: PendingKind.collectionDetails,
        target: 'otra',
        args: {'name': 'Otra cosa'},
      );

      expect(applyPendingWrite(collection(), elsewhere).name, 'Domingo');
    });

    test('a new running order is applied in place', () {
      final reorder = const PendingWrite(
        kind: PendingKind.itemOrder,
        target: 'c1',
        args: {
          'item_ids': ['i2', 'i1'],
        },
      );

      final after = applyPendingWrite(collection(), reorder);

      expect(after.items.map((i) => i.id), ['i2', 'i1']);
      expect(after.items.map((i) => i.order), [0, 1]);
    });

    test('an order that forgot an item does not lose it', () {
      // A stale list is a bug; a service that silently drops a song is a
      // Sunday.
      final partial = const PendingWrite(
        kind: PendingKind.itemOrder,
        target: 'c1',
        args: {
          'item_ids': ['i2'],
        },
      );

      final after = applyPendingWrite(collection(), partial);

      expect(after.items.map((i) => i.id), ['i2', 'i1']);
    });

    test('clearing the auto-advance clears it', () {
      final withTimer = Collection(
        id: 'c1',
        name: 'Domingo',
        items: [item('i1', 0).copyWith(autoAdvanceSecs: 8)],
      );

      final after = applyPendingWrite(
        withTimer,
        const PendingWrite(
          kind: PendingKind.itemAutoAdvance,
          target: 'i1',
          args: {'auto_advance_secs': null},
        ),
      );

      expect(after.items.single.autoAdvanceSecs, isNull);
    });

    test('clearing the background audio clears it', () {
      final withAudio = Collection(id: 'c1', name: 'Domingo', bgAudioPath: '/tmp/pad.mp3');

      final after = applyPendingWrite(
        withAudio,
        const PendingWrite(kind: PendingKind.collectionBgAudio, target: 'c1', args: {'path': null}),
      );

      expect(after.bgAudioPath, isNull);
    });
  });

  group('adding and removing, before it is sent', () {
    CollectionItem item(String id, int order) => CollectionItem(
      id: id,
      collectionId: 'c1',
      type: CollectionItemType.freeSlide,
      order: order,
      contentJson: {'text': id},
    );

    Collection service({String id = 'c1', DateTime? date, List<CollectionItem>? items}) =>
        Collection(id: id, name: id, serviceDate: date, items: items ?? [item('i1', 0)]);

    PendingWrite add(List<CollectionItem> items) => PendingWrite(
      kind: PendingKind.itemsAdd,
      target: 'c1',
      args: {
        'items': [for (final i in items) i.toJson()],
      },
    );

    test('an added item goes on the end of the plan', () {
      final after = applyPendingWrite(service(), add([item('i9', 5)]));

      expect(after.items.map((i) => i.id), ['i1', 'i9']);
      expect(after.items.last.order, 1, reason: 'where it lands, not where it came from');
    });

    test('an add applied twice adds once', () {
      // The queue is laid over the cache on every reload, and the cache may
      // already hold what the queue sent.
      final once = applyPendingWrite(service(), add([item('i9', 0)]));
      final twice = applyPendingWrite(once, add([item('i9', 0)]));

      expect(twice.items.map((i) => i.id), ['i1', 'i9']);
    });

    test('two songs added to one service are two changes, not one', () async {
      final dir = Directory.systemTemp.createTempSync('pending_adds');
      addTearDown(() => dir.deleteSync(recursive: true));
      final queue = PendingWrites(file: File('${dir.path}/pending.json'));

      await queue.add(add([item('a', 0)]));
      await queue.add(add([item('b', 0)]));

      expect(await queue.load(), hasLength(2));
    });

    test('a removal closes the gap it leaves', () {
      final plan = service(items: [item('i1', 0), item('i2', 1), item('i3', 2)]);

      final after = applyPendingWrite(
        plan,
        const PendingWrite(kind: PendingKind.itemRemove, target: 'i2', args: {}),
      );

      expect(after.items.map((i) => i.id), ['i1', 'i3']);
      expect(after.items.map((i) => i.order), [0, 1]);
    });

    test('a new service takes its place by date, the way the server lists them', () {
      final list = [
        service(id: 'later', date: DateTime(2026, 9, 27)),
        service(id: 'earlier', date: DateTime(2026, 9, 6)),
        service(id: 'undated'),
      ];

      final after = applyPendingWriteToAll(
        list,
        const PendingWrite(
          kind: PendingKind.collectionCreate,
          target: 'new',
          args: {'name': 'Domingo', 'service_date': '2026-09-13T00:00:00.000'},
        ),
      );

      expect(after.map((c) => c.id), ['later', 'new', 'earlier', 'undated']);
      expect(after[1].items, isEmpty);
    });

    test('a service created twice is one service', () {
      const create = PendingWrite(
        kind: PendingKind.collectionCreate,
        target: 'new',
        args: {'name': 'Domingo'},
      );

      final after = applyPendingWriteToAll(applyPendingWriteToAll([service()], create), create);

      expect(after.map((c) => c.id), ['new', 'c1'], reason: 'the newest first among undated');
    });

    test('a deleted service leaves the list', () {
      final after = applyPendingWriteToAll([
        service(),
        service(id: 'c2'),
      ], const PendingWrite(kind: PendingKind.collectionDelete, target: 'c1', args: {}));

      expect(after.map((c) => c.id), ['c2']);
    });

    test('the church a change was made for survives the app being closed', () {
      const write = PendingWrite(
        kind: PendingKind.itemTitle,
        target: 'i1',
        args: {'title': 'x'},
        org: 'iglesia-a',
      );

      expect(PendingWrite.fromJson(write.toJson()), write);
    });
  });
}
