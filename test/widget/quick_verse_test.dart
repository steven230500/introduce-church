import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/quick_verse_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// A bible with one chapter in it, so the dialog has something to find.
class _FakeBible extends BibleRepository {
  _FakeBible() : super(AppDatabase.instance);

  @override
  Future<List<BibleVersion>> getVersions() async => const [
    BibleVersion(code: 'rvr1960', name: 'Reina Valera 1960', isBundled: true, isDownloaded: true),
  ];

  @override
  Future<List<String>> getVerses(String versionCode, int bookIndex, int chapter) async =>
      bookIndex == 42 && chapter == 3 ? ['uno', 'dos', 'tres'] : [];

  @override
  Future<BibleVerseRef?> getVerseRange({
    required String versionCode,
    required int bookIndex,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) async {
    final verses = await getVerses(versionCode, bookIndex, chapter);
    if (verses.isEmpty || verseStart > verses.length) return null;
    return BibleVerseRef(
      versionCode: versionCode,
      versionName: 'Reina Valera 1960',
      bookIndex: bookIndex,
      bookName: spanishBookName(bookIndex),
      bookAbbrev: 'jo',
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd.clamp(verseStart, verses.length),
      texts: verses.sublist(verseStart - 1, verseEnd.clamp(verseStart, verses.length)),
    );
  }
}

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;

  setUp(() {
    repo = FakeControlRepository(
      rows: [
        collectionRow(
          id: 'c1',
          items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Primera')],
        ),
      ],
    );
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
  });

  tearDown(() => control.close());

  Future<void> pumpDialog(WidgetTester tester) async {
    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);

    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: control,
          child: QuickVerseDialog(repository: _FakeBible()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reads the reference back as it is typed', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:1');
    await tester.pump();

    expect(find.text('Juan 3:1'), findsOneWidget);
  });

  testWidgets('the words show up while it is typed, before anyone reads them', (tester) async {
    // A wrong reference used to be found out by the whole congregation at
    // once, on the wall.
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('dos'), findsOneWidget);
  });

  testWidgets('a range says how many verses it is', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:1-3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('uno dos tres'), findsOneWidget);
    expect(find.text('3 versículos'), findsOneWidget);
  });

  testWidgets('half a book name offers the books it could be', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'cor');
    await tester.pump();

    expect(find.text('1 Corintios'), findsOneWidget);
    expect(find.text('2 Corintios'), findsOneWidget);

    await tester.tap(find.text('2 Corintios'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '2 Corintios ',
      reason: 'ready for the chapter, with no book left to type',
    );
    // The chapter is typed straight after picking the book, so the caret has
    // to be back in the field and not left on the chip.
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
    // Focus returning selects the text, and the next keystroke would wipe the
    // book out; the caret belongs at the end.
    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(controller.selection, TextSelection.collapsed(offset: controller.text.length));
  });

  testWidgets('a name that is already one book offers nothing', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:1');
    await tester.pump();

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('Enter adds the passage, which is the whole point', (tester) async {
    // Typing a reference instead of browsing to it only saves time if the
    // hand never leaves the keyboard.
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:1');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('addVerse:Juan 3:1'));
  });

  testWidgets('the button does the same thing', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3:1');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('addVerse:Juan 3:1'));
  });

  testWidgets('a passage that is not there says so instead of adding nothing', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 99:1');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No encontré'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('addVerse')), isEmpty);
  });

  testWidgets('a chapter on its own takes all of it', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), 'jn 3');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('addVerse:Juan 3:1-3'));
  });
}
