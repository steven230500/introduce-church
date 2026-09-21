import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

const juan316In1909 =
    'Porque de tal manera amó Dios al mundo, que ha dado á su Hijo unigénito, para que '
    'todo aquel que en él cree, no se pierda, mas tenga vida eterna.';
const juan316In1960 =
    'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito, para que '
    'todo aquel que en él cree, no se pierda, mas tenga vida eterna.';

/// A version with John 3:16 in it and nothing else.
Future<void> install(AppDatabase db, String code, {required bool bundled, required String text}) =>
    db.insertVersion(
      code: code,
      name: code,
      isBundled: bundled,
      books: [
        for (var i = 0; i < 66; i++)
          {
            'abbrev': 'b$i',
            'name': 'Libro $i',
            'chapters': i == 42
                ? [
                    <String>[],
                    <String>[],
                    [for (var v = 1; v < 16; v++) 'v$v', text],
                  ]
                : [<String>[]],
          },
      ],
    );

Map<String, dynamic> passage(String id, String text) => itemRow(
  id: id,
  collectionId: 'c1',
  type: 'bible_verse',
  order: 0,
  contentJson: {
    'book': 'Juan',
    'bookIndex': 42,
    'chapter': 3,
    'verse': 16,
    'verseEnd': 16,
    'texts': [text],
    'version': 'RVR1960',
    'versionName': 'Reina-Valera 1960',
  },
);

void main() {
  late AppDatabase db;
  late FakeControlRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await install(db, 'RV1909', bundled: true, text: juan316In1909);
  });
  tearDown(() => db.close());

  Future<ControlCubit> open(List<Map<String, dynamic>> items) async {
    repo = FakeControlRepository(
      rows: [collectionRow(id: 'c1', items: items)],
    );
    final control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
      bible: BibleRepository(db),
    );
    addTearDown(control.close);
    await control.load();
    // The check runs after the plan is on screen, not in its way.
    await pumpEventQueue(times: 50);
    return control;
  }

  test('a passage saved as "RVR1960" with the 1909\'s words gets its real name', () async {
    final control = await open([passage('p1', juan316In1909)]);
    final item = (control.state as ControlLoadedState).model.collections.first.items.single;
    expect(item.contentJson!['version'], 'RV1909');
    expect(item.contentJson!['versionName'], 'Reina-Valera 1909');
  });

  test('a real 1960 passage is left alone', () async {
    await open([passage('p1', juan316In1960)]);
    expect(repo.calls.where((c) => c.startsWith('content:')), isEmpty);
  });

  test('when the 1960 the church imported has the same words, it is left alone', () async {
    await install(db, 'RVR1960', bundled: false, text: juan316In1909);
    await open([passage('p1', juan316In1909)]);
    expect(repo.calls.where((c) => c.startsWith('content:')), isEmpty);
  });
}
