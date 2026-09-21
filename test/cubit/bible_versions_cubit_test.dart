import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/bible_files.dart';
import 'package:introduce_church/core/bible_import/imported_bible.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_import_service.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/modules/presentation/shell/bible_versions_cubit.dart';

import '../helpers/bibles.dart';
import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakePrefsService prefs;
  late BibleRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = FakePrefsService();
    repo = BibleRepository(db, prefs);
    await installMislabelled(db);
    await BibleImportService(db).retireMislabelled();
  });
  tearDown(() => db.close());

  /// A cubit whose file reader returns [result] for any path.
  BibleVersionsCubit cubitReading(BibleFileResult result) =>
      BibleVersionsCubit(repo, reader: (_) async => result);

  BibleFileResult found(ImportedBible bible) => (bible: bible, failure: null);

  ImportedBible lbla() {
    final bible = wholeBible('lbla');
    return ImportedBible(
      title: 'La Biblia de Las Americas',
      books: bible.books,
      source: '/descargas/lbla.xml',
      format: BibleFormat.zefania,
    );
  }

  test('lists the included Bible under its real name', () async {
    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    final versions = cubit.state.model.versions;
    expect(versions.single.code, 'RV1909');
    expect(versions.single.bundled, isTrue);
    expect(versions.single.complete, isTrue);
    await cubit.close();
  });

  test('a file read is offered for review with the name and code it suggests', () async {
    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    await cubit.open('/descargas/lbla.xml');

    final state = cubit.state as BibleVersionsReview;
    expect(state.name, 'La Biblia de Las Americas');
    expect(state.code, 'LBLA');
    expect(await repo.getVersions(), hasLength(1), reason: 'nothing is saved before confirming');
    await cubit.close();
  });

  test('confirming saves it, marks it, and makes it the one used', () async {
    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    await cubit.open('/descargas/lbla.xml');
    await cubit.install(name: 'La Biblia de las Américas', code: 'lbla');

    final state = cubit.state as BibleVersionsIdle;
    expect(state.added, 'LBLA');
    expect(state.model.versions.map((v) => v.code), ['LBLA', 'RV1909']);
    expect(prefs.bibleVersionCode, 'LBLA');
    expect(cubit.changed, isTrue);
    expect((await repo.preferredVersion())?.name, 'La Biblia de las Américas');
    await cubit.close();
  });

  test('the included version\'s code cannot be taken', () async {
    expect(BibleVersionsCubit.canInstall(name: 'Otra', code: 'rv1909'), isFalse);
    expect(BibleVersionsCubit.canInstall(name: ' ', code: 'LBLA'), isFalse);
    expect(BibleVersionsCubit.canInstall(name: 'LBLA', code: '--'), isFalse);
    expect(BibleVersionsCubit.canInstall(name: 'LBLA', code: 'LBLA'), isTrue);

    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    await cubit.open('/descargas/lbla.xml');
    await cubit.install(name: 'Otra', code: 'RV1909');
    expect(cubit.state, isA<BibleVersionsReview>());
    expect((await repo.getVersions()).single.name, 'Reina-Valera 1909');
    await cubit.close();
  });

  test('a file that is not a Bible says why, and nothing changes', () async {
    final cubit = cubitReading((
      bible: null,
      failure: const BibleFileFailure('/cancion.xml', BibleFileProblem.unsupported),
    ));
    await cubit.load();
    await cubit.open('/cancion.xml');

    final state = cubit.state as BibleVersionsIdle;
    expect(state.problem, BibleImportProblem.unsupported);
    expect(cubit.changed, isFalse);
    await cubit.close();
  });

  test('cancelling a review saves nothing', () async {
    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    await cubit.open('/descargas/lbla.xml');
    cubit.cancel();
    expect(cubit.state, isA<BibleVersionsIdle>());
    expect(await repo.getVersions(), hasLength(1));
    await cubit.close();
  });

  test('an imported version can be removed; the included one cannot', () async {
    final cubit = cubitReading(found(lbla()));
    await cubit.load();
    await cubit.open('/descargas/lbla.xml');
    await cubit.install(name: 'LBLA', code: 'LBLA');

    await cubit.delete('RV1909');
    await cubit.delete('LBLA');
    expect(cubit.state.model.versions.map((v) => v.code), ['RV1909']);
    await cubit.close();
  });
}
