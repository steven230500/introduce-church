import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/app_database.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/sermon_dialog.dart';

import '../helpers/bibles.dart';
import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// Hebreos 11 with six verses, and nothing else.
class _FakeBible extends BibleRepository {
  _FakeBible() : super(unopenedDatabase);

  static const version = BibleVersion(
    code: 'RV1909',
    name: 'Reina-Valera 1909',
    isBundled: true,
    isDownloaded: true,
  );

  @override
  Future<BibleVersion?> preferredVersion() async => version;

  @override
  Future<List<String>> getVerses(String versionCode, int bookIndex, int chapter) async =>
      bookIndex == 57 && chapter == 11
      ? [
          'Es pues la fe',
          'Porque por ella',
          'Por la fe',
          'Por la fe Abel',
          'Por la fe Enoc',
          'Empero sin fe',
        ]
      : [];

  @override
  Future<BibleVerseRef?> getVerseRange({
    required String versionCode,
    required int bookIndex,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) async {
    final verses = await getVerses(versionCode, bookIndex, chapter);
    if (verseStart < 1 || verseEnd > verses.length) return null;
    return BibleVerseRef(
      versionCode: versionCode,
      versionName: version.name,
      bookIndex: bookIndex,
      bookName: spanishBookName(bookIndex),
      bookAbbrev: 'he',
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
      texts: verses.sublist(verseStart - 1, verseEnd),
    );
  }
}

const _outline = '''
*LA FE QUE VENCE*
Texto: Hebreos 11:1-6
1️⃣ La fe es certeza (He 11:1)
2️⃣ La fe agrada a Dios
Hebreos 11:6
3️⃣ La fe actúa – Santiago 2:17
''';

void main() {
  String? clipboard;

  setUp(() {
    clipboard = _outline;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' && clipboard != null ? {'text': clipboard} : null,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  /// Opens the dialog, and keeps what it hands back in [onClosed].
  Future<void> open(
    WidgetTester tester, {
    bool paste = true,
    ValueChanged<SermonDraft?>? onClosed,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final draft = await showSermonDialog(context, paste: paste, repository: _FakeBible());
              onClosed?.call(draft);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('the outline the pastor sent fills the sermon, and names its passages', (
    tester,
  ) async {
    SermonDraft? draft;
    await open(tester, onClosed: (result) => draft = result);

    expect(find.text('LA FE QUE VENCE'), findsOneWidget);
    expect(find.text('La fe es certeza (He 11:1)'), findsOneWidget);
    expect(find.text('La fe agrada a Dios'), findsOneWidget);
    expect(find.text('La fe actúa – Santiago 2:17'), findsOneWidget);
    expect(find.text('Hebreos 11:6'), findsNothing, reason: 'a passage is not a point');

    expect(find.text('Hebreos 11:1-6 • RV1909'), findsOneWidget);
    expect(find.text('Es pues la fe'), findsNWidgets(2), reason: '11:1-6 and 11:1 start alike');
    expect(find.text('Empero sin fe'), findsOneWidget);
    expect(find.text('No está en RV1909'), findsOneWidget, reason: 'Santiago is not in this one');

    // The operator does not want the whole of 11:1-6 after all.
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(draft?.title, 'LA FE QUE VENCE');
    expect(draft?.points, hasLength(3));
    expect(draft?.passages.map((p) => p.reference), ['Hebreos 11:1', 'Hebreos 11:6']);
  });

  testWidgets('with nothing copied it says what to do, and the sermon can be written by hand', (
    tester,
  ) async {
    clipboard = null;
    await open(tester);

    expect(find.textContaining('Copia primero el bosquejo'), findsOneWidget);
    expect(find.text('Nueva prédica'), findsOneWidget);
  });

  testWidgets('it can be pasted after the dialog is open', (tester) async {
    await open(tester, paste: false);
    expect(find.text('LA FE QUE VENCE'), findsNothing);

    await tester.tap(find.text('Pegar bosquejo'));
    await tester.pumpAndSettle();
    expect(find.text('LA FE QUE VENCE'), findsOneWidget);
  });

  group('adding what the outline gave', () {
    late FakeControlRepository repository;
    late ControlCubit control;

    setUp(() async {
      repository = FakeControlRepository(
        rows: [collectionRow(id: 'c1', name: 'Domingo', items: [])],
      );
      control = ControlCubit(
        repository,
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
      control.selectCollection((control.state as ControlLoadedState).model.collections.first);
    });
    tearDown(() => control.close());

    test('the sermon first, then its passages in the order it names them', () async {
      final bible = _FakeBible();
      final first = await bible.getVerseRange(
        versionCode: 'RV1909',
        bookIndex: 57,
        chapter: 11,
        verseStart: 1,
        verseEnd: 1,
      );
      final sixth = await bible.getVerseRange(
        versionCode: 'RV1909',
        bookIndex: 57,
        chapter: 11,
        verseStart: 6,
        verseEnd: 6,
      );

      await control.addSermon('La fe', ['Certeza'], passages: [first!, sixth!]);

      expect(repository.calls, contains('addItems:3'), reason: 'one request, not three');
      final items = (control.state as ControlLoadedState).model.activeCollection!.items;
      expect(items.map((i) => i.type), [
        CollectionItemType.sermon,
        CollectionItemType.bibleVerse,
        CollectionItemType.bibleVerse,
      ]);
      expect(items.map((i) => i.displayTitle).skip(1), ['Hebreos 11:1', 'Hebreos 11:6']);
    });
  });
}
