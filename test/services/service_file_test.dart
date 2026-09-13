import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/services/service_file.dart';

void main() {
  Song song(String id, String title, {String? author}) => Song(
    id: id,
    title: title,
    author: author,
    verses: [
      Verse(id: '$id-0', songId: id, type: VerseType.verse, order: 0, content: 'Línea uno'),
      Verse(id: '$id-1', songId: id, type: VerseType.chorus, order: 1, content: 'Coro'),
    ],
  );

  CollectionItem item(
    String id,
    CollectionItemType type, {
    Song? withSong,
    String? designId,
    Map<String, dynamic>? content,
    String? notes,
  }) => CollectionItem(
    id: id,
    collectionId: 'c1',
    type: type,
    order: 0,
    song: withSong,
    templateId: designId,
    contentJson: content,
    notes: notes,
  );

  final design = SlideTemplate.defaultTemplate.copyWith(id: 'd1', name: 'Azul noche');
  final unused = SlideTemplate.defaultTemplate.copyWith(id: 'd9', name: 'Otro');

  Collection service() => Collection(
    id: 'c1',
    name: 'Domingo 28 junio',
    serviceDate: DateTime(2026, 6, 28),
    templateId: 'd1',
    items: [
      item('i1', CollectionItemType.song, withSong: song('s1', 'Nada es imposible')),
      item(
        'i2',
        CollectionItemType.bibleVerse,
        designId: 'd1',
        content: {'book': 'Génesis', 'chapter': 1, 'verse': 1},
        notes: 'leer lento',
      ),
    ],
  );

  String saved() => encodeService(service(), designs: [design, unused]);

  group('what travels in the file', () {
    test('the service comes back with its name and its date', () {
      final read = decodeService(saved());

      expect(read.name, 'Domingo 28 junio');
      expect(read.serviceDate, DateTime(2026, 6, 28));
    });

    test('every item comes back, in order', () {
      final read = decodeService(saved());

      expect(read.items.map((i) => i.type), [
        CollectionItemType.song,
        CollectionItemType.bibleVerse,
      ]);
    });

    test('the lyrics travel, not a reference to them', () {
      // The church opening the file is usually not the one that made it, and a
      // song id from somewhere else points at nothing here.
      final read = decodeService(saved());

      expect(read.songs.single.title, 'Nada es imposible');
      expect(read.songs.single.verses.map((v) => v.content), ['Línea uno', 'Coro']);
      expect(read.songs.single.verses.map((v) => v.type), [VerseType.verse, VerseType.chorus]);
    });

    test('a note written for the desk travels with its item', () {
      expect(decodeService(saved()).items.last.notes, 'leer lento');
    });

    test('only the designs this service uses are carried', () {
      // Exporting a church's whole design library inside one Sunday is not
      // what anyone asked for.
      final read = decodeService(saved());

      expect(read.designs.map((d) => d.id), ['d1']);
    });

    test('a design keeps what makes it look the way it does', () {
      final withLook = design.copyWith(fontSize: 72, textColor: 0xFFFF9500);
      final read = decodeService(encodeService(service(), designs: [withLook]));

      expect(read.designs.single.fontSize, 72);
      expect(read.designs.single.textColor, 0xFFFF9500);
    });

    test('the pre-chorus keeps its wire spelling across the round trip', () {
      // Its enum name and its stored value differ, which is exactly the kind
      // of thing that survives a review and not a round trip.
      final withPre = Collection(
        id: 'c1',
        name: 'Culto',
        items: [
          item(
            'i1',
            CollectionItemType.song,
            withSong: Song(
              id: 's1',
              title: 'Canción',
              verses: [
                Verse(id: 'v', songId: 's1', type: VerseType.preCHORUS, order: 0, content: 'Sube'),
              ],
            ),
          ),
        ],
      );

      final read = decodeService(encodeService(withPre, designs: const []));

      expect(read.songs.single.verses.single.type, VerseType.preCHORUS);
    });
  });

  group('opening a file that is not one', () {
    test('a file that is not JSON says so, not a decoding error', () {
      expect(
        () => decodeService('esto no es json'),
        throwsA(isA<ServiceFileError>().having((e) => e.message, 'message', contains('leer'))),
      );
    });

    test('somebody else\'s JSON is refused by name', () {
      expect(
        () => decodeService('{"hello": "world"}'),
        throwsA(isA<ServiceFileError>().having((e) => e.message, 'message', contains('Introduce'))),
      );
    });

    test('a file from a newer version says to update, not that it is broken', () {
      final future = jsonDecode(saved()) as Map<String, dynamic>;
      future['version'] = kServiceFileVersion + 1;

      expect(
        () => decodeService(jsonEncode(future)),
        throwsA(isA<ServiceFileError>().having((e) => e.message, 'message', contains('Actualiza'))),
      );
    });

    test('a file from an older version is still read', () {
      // Refusing to open yesterday's backup would defeat the point of one.
      final old = jsonDecode(saved()) as Map<String, dynamic>;
      old['version'] = kServiceFileVersion - 1;

      expect(decodeService(jsonEncode(old)).items, hasLength(2));
    });

    test('a file with no name is refused rather than opened as "null"', () {
      final nameless = jsonDecode(saved()) as Map<String, dynamic>..remove('name');

      expect(() => decodeService(jsonEncode(nameless)), throwsA(isA<ServiceFileError>()));
    });

    test('an item of a kind this version does not know does not sink the file', () {
      final odd = jsonDecode(saved()) as Map<String, dynamic>;
      (odd['items'] as List).add({'type': 'holograma'});

      expect(decodeService(jsonEncode(odd)).items, hasLength(3));
    });
  });

  group('the name it lands on disk with', () {
    test('carries the service and the date', () {
      expect(
        serviceFileName('Domingo 28 junio', on: DateTime(2026, 6, 28)),
        'introduce_20260628_Domingo_28_junio.introduce',
      );
    });

    test('drops what a file system would argue about', () {
      final name = serviceFileName('Culto: "especial" /2/', on: DateTime(2026, 1, 5));

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('"')));
      expect(name, startsWith('introduce_20260105_'));
    });

    test('a service with no usable name still gets a file name', () {
      expect(serviceFileName('¿¡!?', on: DateTime(2026, 1, 5)), contains('servicio'));
    });
  });
}
