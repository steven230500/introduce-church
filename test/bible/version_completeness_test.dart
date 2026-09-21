import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/app_database.dart';

/// Fills [db] with [books] books of one chapter each, as a download does.
Future<void> writeBooks(AppDatabase db, String code, int books, {int? chaptersWritten}) async {
  for (var i = 0; i < books; i++) {
    await db.insertBook(
      versionCode: code,
      bookIndex: i,
      abbrev: 'b$i',
      bookName: 'Libro $i',
      chapterCount: 1,
    );
  }
  for (var i = 0; i < (chaptersWritten ?? books); i++) {
    await db.insertChapter(
      versionCode: code,
      bookIndex: i,
      chapter: 1,
      versesJson: '["un versículo"]',
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('a Bible downloaded chapter by chapter', () {
    test('is not readable until every book is in', () async {
      await db.insertVersion(
        code: 'NVI',
        name: 'NVI',
        isBundled: false,
        books: [],
        isDownloaded: false,
      );
      await writeBooks(db, 'NVI', 5); // the download stopped after the Pentateuch

      expect(await db.isVersionDownloaded('NVI'), isFalse);
      expect(await db.isVersionComplete('NVI'), isFalse);
    });

    test('a version left installed by an older build is caught as incomplete', () async {
      // What 1.0.6 and earlier wrote: marked as downloaded from the first
      // chapter, so a cut download looked like a Bible.
      await db.insertVersion(code: 'NVI', name: 'NVI', isBundled: false, books: []);
      await writeBooks(db, 'NVI', 5);

      expect(await db.isVersionDownloaded('NVI'), isTrue);
      expect(await db.isVersionComplete('NVI'), isFalse, reason: 'five books is not a Bible');
    });

    test('with every book and chapter it is complete, and saying so is a separate step', () async {
      await db.insertVersion(
        code: 'NVI',
        name: 'NVI',
        isBundled: false,
        books: [],
        isDownloaded: false,
      );
      await writeBooks(db, 'NVI', AppDatabase.wholeBibleBooks);

      expect(await db.isVersionComplete('NVI'), isTrue);
      expect(await db.isVersionDownloaded('NVI'), isFalse);

      await db.markVersionDownloaded('NVI');
      expect(await db.isVersionDownloaded('NVI'), isTrue);
    });

    test('all the books but a chapter missing is still incomplete', () async {
      await db.insertVersion(
        code: 'NVI',
        name: 'NVI',
        isBundled: false,
        books: [],
        isDownloaded: false,
      );
      await writeBooks(db, 'NVI', AppDatabase.wholeBibleBooks, chaptersWritten: 60);

      expect(await db.isVersionComplete('NVI'), isFalse);
    });
  });
}
