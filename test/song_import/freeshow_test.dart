import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/song_import/imported_song.dart';
import 'package:introduce_church/core/song_import/song_files.dart';

/// A slide as FreeShow writes one: text in items, each item a list of lines.
Map<String, dynamic> slide(String group, List<String> lines, {bool decorated = false}) => {
  'group': group,
  'items': [
    {
      'lines': [
        for (final line in lines)
          {
            'text': [
              {'value': line, 'style': 'font-size:90px;'},
            ],
          },
      ],
    },
    if (decorated)
      {
        'decoration': true,
        'lines': [
          {
            'text': [
              {'value': 'Salmos 27:3'},
            ],
          },
        ],
      },
  ],
};

String showFile({
  String name = 'A danzar',
  String category = '763d15a96bf',
  Map<String, dynamic> meta = const {},
  required Map<String, dynamic> slides,
  List<String>? order,
}) => jsonEncode([
  'd1960ab4d56',
  {
    'name': name,
    'category': category,
    'meta': meta,
    'settings': {'activeLayout': 'layout-1'},
    'slides': slides,
    if (order != null)
      'layouts': {
        'layout-1': {
          'slides': [
            for (final id in order) {'id': id},
          ],
        },
      },
  },
]);

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('a song brought over from FreeShow', () {
    test('comes in with its slides in the order the church arranged them', () {
      final file = showFile(
        meta: {'artist': 'Barak', 'copyright': '2019 Barak', 'CCLI': '7654321'},
        slides: {
          'a': slide('Verso', ['A danzar', 'Delante de su presencia']),
          'b': slide('Coro', ['Da un paso al frente']),
        },
        // The chorus is sung twice, as the layout says.
        order: ['a', 'b', 'a', 'b'],
      );

      final result = readSongBytes('/tmp/A danzar - Barak.show', bytes(file));

      final song = result.song!;
      expect(song.title, 'A danzar');
      expect(song.format, SongFormat.freeShow);
      expect(song.author, 'Barak');
      expect(song.copyright, '2019 Barak');
      expect(song.ccliNumber, '7654321');
      expect(song.verses.map((v) => v.type), [
        VerseType.verse,
        VerseType.chorus,
        VerseType.verse,
        VerseType.chorus,
      ]);
      expect(song.verses.first.content, 'A danzar\nDelante de su presencia');
    });

    test('what FreeShow draws around the words is not part of them', () {
      final file = showFile(
        slides: {
          'a': slide('Verso', ['Levanta tus manos'], decorated: true),
        },
        order: ['a'],
      );

      final song = readSongBytes('/tmp/song.show', bytes(file)).song!;

      expect(song.verses.single.content, 'Levanta tus manos');
    });

    test('with no layout, the slides come as the file lists them', () {
      final file = showFile(
        slides: {
          'a': slide('Verso', ['Primera']),
          'b': slide('Coro', ['Segunda']),
        },
      );

      final song = readSongBytes('/tmp/song.show', bytes(file)).song!;

      expect(song.verses.map((v) => v.content), ['Primera', 'Segunda']);
    });

    test('the file name is the title when the show has no name', () {
      final file = showFile(
        name: '',
        slides: {
          'a': slide('Verso', ['Primera']),
        },
        order: ['a'],
      );

      final song = readSongBytes('/tmp/Sublime gracia.show', bytes(file)).song!;

      expect(song.title, 'Sublime gracia');
    });
  });

  group('a FreeShow file that is not a song', () {
    test('a Bible passage says so instead of joining the song library', () {
      // FreeShow keeps passages in the same kind of file, and the app already
      // has the Bible inside it.
      final file = showFile(
        category: 'scripture',
        slides: {
          'a': slide('Salmos 27:3', ['Aunque un ejército acampe contra mí'], decorated: true),
        },
        order: ['a'],
      );

      final result = readSongBytes('/tmp/Salmos 27,3 - Rei.show', bytes(file));

      expect(result.song, isNull);
      expect(result.failure?.problem, SongFileProblem.notASong);
    });

    test('a sermon deck says so too', () {
      final file = showFile(
        category: 'presentation',
        slides: {
          'a': slide('Verso', ['1. EL LLAMADO', 'Mateo 9: 9']),
        },
        order: ['a'],
      );

      expect(
        readSongBytes('/tmp/PREDICA.show', bytes(file)).failure?.problem,
        SongFileProblem.notASong,
      );
    });

    test('a damaged file is damaged, not empty', () {
      expect(
        readSongBytes('/tmp/roto.show', bytes('[not json at all')).failure?.problem,
        SongFileProblem.unreadable,
      );
    });

    test('a show with slides but no words in them is empty', () {
      final file = showFile(
        slides: {
          'a': slide('Verso', ['   ']),
        },
        order: ['a'],
      );

      expect(readSongBytes('/tmp/vacia.show', bytes(file)).failure?.problem, SongFileProblem.empty);
    });
  });
}
