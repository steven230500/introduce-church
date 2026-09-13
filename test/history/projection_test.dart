import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/history/projection_event.dart';
import 'package:introduce_church/core/history/projection_report.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/song.dart';

void main() {
  final sunday = DateTime(2026, 6, 28, 10);

  CollectionItem song(String id, String title, {String? ccli, String? author}) => CollectionItem(
    id: id,
    collectionId: 'c1',
    type: CollectionItemType.song,
    order: 0,
    song: Song(id: 's-$id', title: title, author: author, ccliNumber: ccli),
  );

  const service = Collection(id: 'c1', name: 'Domingo');

  var ids = 0;
  SegmentTracker tracker() => SegmentTracker(newId: () => 'e${ids++}');

  group('what counts as having been on the screen', () {
    test('a song on air for a while is recorded when the next one replaces it', () {
      final t = tracker();
      final a = song('i1', 'Nada es imposible');

      expect(t.observe((collection: service, item: a), sunday), isNull);
      final closed = t.observe((
        collection: service,
        item: song('i2', 'Otra'),
      ), sunday.add(const Duration(minutes: 4)));

      expect(closed?.title, 'Nada es imposible');
      expect(closed?.duration, const Duration(minutes: 4));
      expect(closed?.collectionName, 'Domingo');
    });

    test('moving from the verse to the chorus is not a new use of the song', () {
      final t = tracker();
      final a = song('i1', 'Nada es imposible');

      t.observe((collection: service, item: a), sunday);
      // Same item, the slide changed. The tracker is told again.
      final again = t.observe((
        collection: service,
        item: a,
      ), sunday.add(const Duration(minutes: 1)));

      expect(again, isNull);
    });

    test('flicking past a song with the output live does not count', () {
      // Somebody stepping through the running order puts every song up for
      // half a second. Those would land in a licence report somebody signs.
      final t = tracker();

      t.observe((collection: service, item: song('i1', 'De paso')), sunday);
      final closed = t.observe((
        collection: service,
        item: song('i2', 'Otra'),
      ), sunday.add(const Duration(seconds: 2)));

      expect(closed, isNull);
    });

    test('taking the output off air closes what was on it', () {
      final t = tracker();

      t.observe((collection: service, item: song('i1', 'Final')), sunday);
      final closed = t.observe(null, sunday.add(const Duration(minutes: 3)));

      expect(closed?.title, 'Final');
    });

    test('nothing on air to nothing on air records nothing', () {
      expect(tracker().observe(null, sunday), isNull);
    });

    test('closing the app with a song still up keeps that song', () {
      final t = tracker();
      t.observe((collection: service, item: song('i1', 'Última')), sunday);

      final closed = t.finish(sunday.add(const Duration(minutes: 5)));

      expect(closed?.title, 'Última');
    });

    test('a song carries its licence details, copied at the moment it was used', () {
      final t = tracker();
      t.observe((
        collection: service,
        item: song('i1', 'Grande', ccli: '7654321', author: 'Autor'),
      ), sunday);

      final closed = t.observe(null, sunday.add(const Duration(minutes: 3)));

      expect(closed?.ccliNumber, '7654321');
      expect(closed?.songAuthor, 'Autor');
      expect(closed?.isSong, isTrue);
    });
  });

  group('sending an event', () {
    ProjectionEvent event({String? collectionId, String? songId}) => ProjectionEvent(
      id: newProjectionId(),
      itemType: 'song',
      title: 'x',
      collectionId: collectionId,
      songId: songId,
      startedAt: sunday,
      endedAt: sunday,
    );

    test('its id is a UUID, so the server can use it to ignore a resend', () {
      expect(
        newProjectionId(),
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });

    test('a real id goes as it is', () {
      const real = '3f2b8c1e-9a4d-4e5f-8b6a-1c2d3e4f5a6b';
      expect(event(collectionId: real).toJson()['collection_id'], real);
    });

    test('an id that is not a UUID goes as null instead of sinking the batch', () {
      // The server stores all of a batch or none of it. One odd id must not
      // keep a whole service out of the record.
      expect(event(collectionId: 'new-collection').toJson()['collection_id'], isNull);
      expect(event(songId: '').toJson()['song_id'], isNull);
    });

    test('it survives the trip to JSON and back', () {
      final original = event();
      expect(ProjectionEvent.fromJson(original.toJson()), original);
    });
  });

  ProjectionEvent use(
    String title, {
    required DateTime at,
    String collectionId = 'c1',
    String collectionName = 'Domingo',
    String type = 'song',
    String? ccli,
    String? author,
  }) => ProjectionEvent(
    id: newProjectionId(),
    collectionId: collectionId,
    collectionName: collectionName,
    itemType: type,
    title: title,
    ccliNumber: ccli,
    songAuthor: author,
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 4)),
  );

  group('reading it back as services', () {
    test('one running order on one day is one service, in the order it happened', () {
      final services = servicesFrom([
        use('Segunda', at: sunday.add(const Duration(minutes: 5))),
        use('Primera', at: sunday),
      ]);

      expect(services, hasLength(1));
      expect(services.single.events.map((e) => e.title), ['Primera', 'Segunda']);
    });

    test('the same running order on two Sundays is two services', () {
      final services = servicesFrom([
        use('Coro', at: sunday),
        use('Coro', at: sunday.add(const Duration(days: 7))),
      ]);

      expect(services, hasLength(2));
    });

    test('the newest service comes first, because the question is last Sunday', () {
      final services = servicesFrom([
        use('Vieja', at: sunday),
        use('Nueva', at: sunday.add(const Duration(days: 7))),
      ]);

      expect(services.first.events.single.title, 'Nueva');
    });
  });

  group('reading it back as a licence report', () {
    test('a song sung again after the sermon is still one use in that service', () {
      final report = songReport([
        use('Coro', at: sunday),
        use('Coro', at: sunday.add(const Duration(hours: 1))),
      ]);

      expect(report.single.uses, 1);
    });

    test('the same song on two Sundays is two uses', () {
      final report = songReport([
        use('Coro', at: sunday),
        use('Coro', at: sunday.add(const Duration(days: 7))),
      ]);

      expect(report.single.uses, 2);
      expect(report.single.days, hasLength(2));
    });

    test('only songs are in it: a verse or an announcement needs no licence', () {
      final report = songReport([
        use('Juan 3:16', at: sunday, type: 'bible_verse'),
        use('Coro', at: sunday),
      ]);

      expect(report.map((r) => r.title), ['Coro']);
    });

    test('a song imported twice still reports as one, when it has a licence number', () {
      final report = songReport([
        use('Grande es el Señor', at: sunday, ccli: '123'),
        use('Grande Es El Señor', at: sunday.add(const Duration(days: 7)), ccli: '123'),
      ]);

      expect(report, hasLength(1));
      expect(report.single.uses, 2);
    });

    test('most used comes first', () {
      final report = songReport([
        use('Poco', at: sunday),
        use('Mucho', at: sunday),
        use('Mucho', at: sunday.add(const Duration(days: 7))),
      ]);

      expect(report.map((r) => r.title), ['Mucho', 'Poco']);
    });

    test('the spreadsheet opens with accents intact and quotes escaped', () {
      final csv = songReportCsv(
        songReport([use('Canción "especial"', at: sunday, ccli: '9', author: 'Ñandú')]),
        headers: const ['Título', 'Autor', 'Copyright', 'CCLI', 'Usos', 'Fechas'],
      );

      expect(csv, startsWith('﻿'), reason: 'Excel needs the mark to read UTF-8');
      expect(csv, contains('"Canción ""especial"""'));
      expect(csv, contains('"Ñandú"'));
      expect(csv, contains('"2026-06-28"'));
    });
  });
}
