import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_import_service.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';

import '../helpers/bibles.dart';
import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakePrefsService prefs;
  late BibleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = FakePrefsService();
    repo = BibleRepository(db, prefs);
  });
  tearDown(() => db.close());

  group('a Bible brought from a file', () {
    test('puts a New Testament where the New Testament goes', () async {
      await repo.install(
        importedBible({
          39: [
            ['Libro de la genealogía de Jesucristo'],
          ],
        }),
        code: 'NT',
        name: 'Nuevo Testamento',
      );
      final books = await repo.getBooks('NT');
      expect(books.single.bookIndex, 39);
      expect(books.single.name, 'Mateo');
      expect(await repo.getVerses('NT', 39, 1), ['Libro de la genealogía de Jesucristo']);
    });

    test('is readable and complete when it has every book', () async {
      await repo.install(wholeBible('versículo'), code: 'LBLA', name: 'LBLA');
      final version = (await repo.getVersions()).single;
      expect(version.isBundled, isFalse);
      expect(await repo.isComplete(version), isTrue);
    });

    test('with only some books is readable but not complete', () async {
      await repo.install(
        importedBible({
          0: [
            ['uno'],
          ],
        }),
        code: 'AT',
        name: 'AT',
      );
      final version = (await repo.getVersions()).single;
      expect(await repo.isComplete(version), isFalse);
    });

    test('replaces what was there under the same code', () async {
      await repo.install(wholeBible('vieja'), code: 'NVI', name: 'NVI vieja');
      await repo.install(
        importedBible({
          42: [
            ['nueva'],
          ],
        }),
        code: 'NVI',
        name: 'NVI nueva',
      );
      final books = await repo.getBooks('NVI');
      expect(books.map((b) => b.bookIndex), [42]);
      expect((await repo.getVersions()).single.name, 'NVI nueva');
    });
  });

  group('the included Bible', () {
    test('an old install has its name corrected, keeping the text', () async {
      await installMislabelled(db);
      await BibleImportService(db).retireMislabelled();

      final versions = await db.getAllVersions();
      expect(versions.map((v) => v.code), ['RV1909']);
      expect(versions.single.name, 'Reina-Valera 1909');
      expect(versions.single.isBundled, isTrue);
      expect(await repo.getVerses('RV1909', 42, 1), ['crió Dios 42']);
      expect(await repo.getVerses('RVR1960', 42, 1), isEmpty);
    });

    test('a real 1960 the church imported is left alone', () async {
      await repo.install(wholeBible('creó'), code: 'RVR1960', name: 'Reina-Valera 1960');
      await BibleImportService(db).retireMislabelled();
      expect((await db.getAllVersions()).map((v) => v.code), ['RVR1960']);
    });

    test('the old copy goes when the 1909 is already there', () async {
      await installMislabelled(db);
      await db.renameVersion('RVR1960', to: 'RV1909', name: 'Reina-Valera 1909');
      await installMislabelled(db);
      await BibleImportService(db).retireMislabelled();
      expect((await db.getAllVersions()).map((v) => v.code), ['RV1909']);
    });
  });

  group('the version used when nobody picks one', () {
    setUp(() async {
      await installMislabelled(db);
      await BibleImportService(db).retireMislabelled();
    });

    test('is the included one when it is the only one', () async {
      expect((await repo.preferredVersion())?.code, 'RV1909');
    });

    test('is the church\'s own over the included one', () async {
      await repo.install(wholeBible('lbla'), code: 'LBLA', name: 'LBLA');
      expect((await repo.preferredVersion())?.code, 'LBLA');
    });

    test('is the one the operator chose last', () async {
      await repo.install(wholeBible('lbla'), code: 'LBLA', name: 'LBLA');
      await repo.rememberVersion('RV1909');
      expect((await repo.preferredVersion())?.code, 'RV1909');
    });

    test('is never one whose download was cut off', () async {
      await db.insertVersion(
        code: 'NVI',
        name: 'NVI',
        isBundled: false,
        books: [],
        isDownloaded: false,
      );
      await repo.rememberVersion('NVI');
      expect((await repo.getVersions()).map((v) => v.code), ['RV1909']);
      expect((await repo.preferredVersion())?.code, 'RV1909');
      // The versions dialog still lists it, so it can be removed.
      expect((await repo.getInstalledVersions()).map((v) => v.code), contains('NVI'));
    });
  });
}
