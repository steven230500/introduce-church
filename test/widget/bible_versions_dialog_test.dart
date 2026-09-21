import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/imported_bible.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/modules/presentation/shell/bible_versions_cubit.dart';
import 'package:introduce_church/modules/presentation/shell/bible_versions_dialog.dart';

import '../helpers/bibles.dart';
import '../helpers/builders.dart';

/// The versions a church has, kept in a list: a real database cannot be
/// driven from inside a widget test's fake clock.
class _FakeBibles extends BibleRepository {
  _FakeBibles() : super(AppDatabase.instance);

  final versions = <BibleVersion>[
    const BibleVersion(
      code: 'RV1909',
      name: 'Reina-Valera 1909',
      isBundled: true,
      isDownloaded: true,
    ),
  ];
  String? remembered;

  @override
  Future<List<BibleVersion>> getInstalledVersions() async => [...versions];

  @override
  Future<bool> isComplete(BibleVersion version) async => true;

  @override
  Future<void> install(
    ImportedBible bible, {
    required String code,
    required String name,
    String language = 'es',
  }) async {
    versions.add(
      BibleVersion(
        code: code,
        name: name,
        isBundled: false,
        isDownloaded: true,
        language: language,
      ),
    );
  }

  @override
  Future<void> rememberVersion(String code) async => remembered = code;
}

void main() {
  late _FakeBibles repo;
  late BibleVersionsCubit cubit;

  setUp(() {
    repo = _FakeBibles();
    final read = wholeBible('lbla');
    cubit = BibleVersionsCubit(
      repo,
      reader: (path) async => (
        bible: ImportedBible(
          title: 'La Biblia de Las Americas',
          books: read.books,
          source: path,
          format: BibleFormat.zefania,
        ),
        failure: null,
      ),
    );
  });
  tearDown(() => cubit.close());

  Future<void> pumpDialog(WidgetTester tester) async {
    await cubit.load();
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: cubit,
          child: BibleVersionsDialog(pickFile: () async => '/descargas/lbla.xml'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Bible is imported from a file after checking its name and code', (tester) async {
    await pumpDialog(tester);
    expect(find.text('RV1909 • Incluida'), findsOneWidget);

    await tester.tap(find.text('Importar Biblia…'));
    await tester.pumpAndSettle();

    expect(find.text('66 de 66 libros · 66 versículos · Zefania XML'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'La Biblia de Las Americas'), findsOneWidget);
    expect(find.text('Así sale en pantalla: Juan 3:16 • LBLA'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
    await tester.pumpAndSettle();

    expect(repo.versions.map((v) => v.code), ['RV1909', 'LBLA']);
    expect(repo.remembered, 'LBLA');
    expect(find.text('La Biblia de Las Americas'), findsOneWidget);
    expect(find.text('Importar Biblia…'), findsOneWidget);
  });

  testWidgets('the included version\'s code cannot be used for another', (tester) async {
    await pumpDialog(tester);
    await tester.tap(find.text('Importar Biblia…'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'LBLA'), 'RV1909');
    await tester.pump();

    expect(find.text('RV1909 es la versión incluida. Usa otra sigla.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Importar'));
    expect(button.onPressed, isNull);
  });
}
