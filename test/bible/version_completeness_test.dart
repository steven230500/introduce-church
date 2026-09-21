import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/book_codes.dart';
import 'package:introduce_church/core/local_db/app_database.dart';

/// [count] books of one chapter each, in the form the bulk insert takes.
List<Map<String, dynamic>> books(int count) => [
  for (var i = 0; i < count; i++)
    {
      'abbrev': 'b$i',
      'name': 'Libro $i',
      'chapters': [
        ['un versículo'],
      ],
    },
];

Future<void> install(AppDatabase db, Map<int, List<List<String>>> books) => db.installVersion(
  code: 'NVI',
  name: 'NVI',
  books: books,
  bookNames: [for (var i = 0; i < 66; i++) 'Libro $i'],
  bookAbbrevs: bookAbbrevs,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('a Bible an older build downloaded', () {
    test('cut off before it was marked is not readable', () async {
      await db.insertVersion(
        code: 'NVI',
        name: 'NVI',
        isBundled: false,
        books: books(5), // the download stopped after the Pentateuch
        isDownloaded: false,
      );

      expect(await db.isVersionDownloaded('NVI'), isFalse);
      expect(await db.isVersionComplete('NVI'), isFalse);
    });

    test('marked as installed with five books is caught as incomplete', () async {
      // What 1.0.6 and earlier wrote: marked as downloaded from the first
      // chapter, so a cut download looked like a Bible.
      await db.insertVersion(code: 'NVI', name: 'NVI', isBundled: false, books: books(5));

      expect(await db.isVersionDownloaded('NVI'), isTrue);
      expect(await db.isVersionComplete('NVI'), isFalse, reason: 'five books is not a Bible');
    });
  });

  group('a Bible imported from a file', () {
    test('with every book and chapter is complete', () async {
      await install(db, {
        for (var i = 0; i < AppDatabase.wholeBibleBooks; i++)
          i: [
            ['un versículo'],
          ],
      });
      expect(await db.isVersionComplete('NVI'), isTrue);
    });

    test('with all the books but a chapter missing is still incomplete', () async {
      await install(db, {
        for (var i = 0; i < AppDatabase.wholeBibleBooks; i++)
          i: [
            ['un versículo'],
            // Genesis names a second chapter the file has no verses for.
            if (i == 0) <String>[],
          ],
      });
      expect(await db.isVersionComplete('NVI'), isFalse);
    });
  });
}
