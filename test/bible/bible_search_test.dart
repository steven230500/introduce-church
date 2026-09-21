import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/core/widgets/bible_browser/bible_browser_cubit.dart';

import '../helpers/bibles.dart';
import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late BibleRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BibleRepository(db, FakePrefsService());
    await repo.install(
      importedBible({
        0: [
          ['En el principio creó Dios los cielos y la tierra.'],
        ],
        42: [
          [],
          [],
          [
            for (var v = 1; v <= 16; v++)
              v == 16
                  ? 'Porque de tal manera amó Dios al mundo, que ha dado á su Hijo'
                  : 'Verso $v',
          ],
        ],
      }),
      code: 'RV',
      name: 'RV',
    );
  });
  tearDown(() => db.close());

  test('finds a verse by its words, without the accents or the capitals', () async {
    final hits = await repo.searchText('RV', 'DE TAL MANERA amo');
    expect(hits.single.bookIndex, 42);
    expect(hits.single.chapter, 3);
    expect(hits.single.verse, 16);
  });

  test('a word matches from its start, not from inside another word', () async {
    expect(await repo.searchText('RV', 'amo'), hasLength(1), reason: 'amó, not álamo');
    expect(await repo.searchText('RV', 'princ'), hasLength(1), reason: 'still being typed');
    expect(await repo.searchText('RV', 'ncipio'), isEmpty);
  });

  test('every word has to be there, and the order is the Bible\'s', () async {
    expect(await repo.searchText('RV', 'dios mundo'), hasLength(1));
    final both = await repo.searchText('RV', 'dios');
    expect(both.map((h) => h.bookIndex), [0, 42]);
    expect(await repo.searchText('RV', 'dios ballena'), isEmpty);
    expect(await repo.searchText('RV', 'verso', limit: 3), hasLength(3));
  });

  test('typing in the browser searches the words, and a result opens its chapter', () async {
    final browser = BibleBrowserCubit(repo);
    addTearDown(browser.close);
    await browser.load();

    browser.filterBooks('tal manera');
    await pumpEventQueue();
    expect(browser.state.filteredBooks, isEmpty);
    expect(browser.state.textHits, hasLength(1));

    await browser.openHit(browser.state.textHits.single);
    expect(browser.state.view, BibleBrowserView.verses);
    expect(browser.state.selectedChapter, 3);
    expect(browser.state.selectedVerse, 16);
    expect(browser.state.selectedBook?.displayName, 'Juan');
    expect(browser.state.revealVerse, 16, reason: 'the list scrolls down to it');
  });

  test('switching versions keeps the search, and searches the new version', () async {
    await repo.install(
      importedBible({
        42: [
          [],
          [],
          [for (var v = 1; v <= 16; v++) v == 16 ? 'For God so loved the world' : 'v'],
        ],
      }),
      code: 'WEB',
      name: 'WEB',
      language: 'en',
    );
    final browser = BibleBrowserCubit(repo);
    addTearDown(browser.close);
    await browser.load();
    browser.filterBooks('loved world');
    await pumpEventQueue();

    final web = browser.state.versions.firstWhere((v) => v.code == 'WEB');
    await browser.selectVersion(web);
    await pumpEventQueue();

    expect(browser.state.filteredBooks, isEmpty, reason: 'the words still name no book');
    expect(browser.state.textHits.single.verse, 16);
  });

  test('what was found for an earlier search is gone as soon as the search changes', () async {
    final browser = BibleBrowserCubit(repo);
    addTearDown(browser.close);
    await browser.load();
    browser.filterBooks('principio');
    await pumpEventQueue();
    expect(browser.state.textHits, isNotEmpty);

    browser.filterBooks('principio creo x');
    expect(browser.state.textHits, isEmpty, reason: 'not the hits of "principio"');
  });
}
