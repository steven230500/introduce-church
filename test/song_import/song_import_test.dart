import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/song_import/imported_song.dart';
import 'package:introduce_church/core/song_import/song_files.dart';
import 'package:introduce_church/modules/songs/children/song_form/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/songs/import/song_import_cubit.dart';
import 'package:introduce_church/modules/songs/import/song_import_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

ImportedSong imported(String title, {String? ccli, int verses = 2}) => ImportedSong(
  title: title,
  ccliNumber: ccli,
  verses: [for (var i = 0; i < verses; i++) ImportedVerse(VerseType.verse, '$title $i')],
  source: '/biblioteca/$title.pro',
  format: SongFormat.proPresenter7,
);

void main() {
  late FakeSongsRepository repo;

  setUp(() {
    repo = FakeSongsRepository(
      songs: const [
        Song(id: '1', title: '¡Cuán Grande Es Él!'),
        Song(id: '2', title: 'Otro nombre', ccliNumber: '18723'),
      ],
    );
  });

  SongImportCubit cubitReading(List<SongFileResult> results) => SongImportCubit(
    repo,
    reader: (paths, {onProgress}) async {
      onProgress?.call(paths.length);
      return results;
    },
    lister: (_) async => [for (final r in results) r.song?.source ?? r.failure!.source],
  );

  SongFileResult ok(ImportedSong song) => (song: song, failure: null);

  group('reading a library', () {
    test('what is already in the library is found by title or by CCLI number', () async {
      // "Cuan grande es el" is "¡Cuán Grande Es Él!" without its accents and
      // marks; and a song under another name with the same CCLI number is the
      // same song.
      final cubit = cubitReading([
        ok(imported('Cuan grande es el')),
        ok(imported('Grande es tu fidelidad', ccli: '18723')),
        ok(imported('Renuévame')),
        ok(imported('renuevame')),
        (
          song: null,
          failure: const SongFileFailure('/biblioteca/foto.jpg', SongFileProblem.unsupported),
        ),
      ]);
      addTearDown(cubit.close);

      await cubit.openFolder('/biblioteca');

      final review = cubit.state as SongImportReview;
      Map<String, ImportStatus> statuses() => {
        for (final c in review.candidates) c.song.title: c.status,
      };
      expect(statuses(), {
        'Cuan grande es el': ImportStatus.inLibrary,
        'Grande es tu fidelidad': ImportStatus.inLibrary,
        'Renuévame': ImportStatus.fresh,
        'renuevame': ImportStatus.repeated,
      });
      expect(review.selectedCount, 1, reason: 'only what is new starts ticked');
      expect(review.failures.single.problem, SongFileProblem.unsupported);
    });

    test('of several copies of one song, the fullest is the one ticked', () async {
      final cubit = cubitReading([
        ok(imported('Amazing Grace', verses: 1)),
        ok(imported('Amazing Grace', verses: 28)),
        ok(imported('Amazing Grace', verses: 3)),
      ]);
      addTearDown(cubit.close);
      await cubit.openFiles(const []);

      final review = cubit.state as SongImportReview;
      final ticked = review.candidates.where((c) => c.selected).single;
      expect(ticked.song.verses, hasLength(28));
      expect(ticked.status, ImportStatus.fresh);
    });

    test('the operator can bring the existing ones in anyway', () async {
      final cubit = cubitReading([ok(imported('Cuan grande es el')), ok(imported('Nueva'))]);
      addTearDown(cubit.close);
      await cubit.openFiles(['a', 'b']);

      cubit.selectWhere(ImportStatus.inLibrary, true);

      expect((cubit.state as SongImportReview).selectedCount, 2);
    });
  });

  group('importing', () {
    test('a large library goes in pieces, and only what is ticked', () async {
      final cubit = cubitReading([
        for (var i = 0; i < 250; i++) ok(imported('Canción $i')),
        ok(imported('Cuan grande es el')),
      ]);
      addTearDown(cubit.close);
      await cubit.openFiles(const []);

      await cubit.import();

      expect(repo.requests.map((r) => r.length), [100, 100, 50]);
      expect(repo.requests.expand((r) => r).any((s) => s.title == 'Cuan grande es el'), isFalse);
      expect(cubit.state, const SongImportDone(imported: 250, failures: []));
    });

    test('a connection lost halfway says how many made it', () async {
      repo.failOnRequest = 2;
      final cubit = cubitReading([for (var i = 0; i < 150; i++) ok(imported('Canción $i'))]);
      addTearDown(cubit.close);
      await cubit.openFiles(const []);

      await cubit.import();

      final done = cubit.state as SongImportDone;
      expect(done.imported, 100);
      expect(done.error, 'sin conexión');
    });
  });

  group('the dialog', () {
    Future<SongImportCubit> pump(WidgetTester tester, List<SongFileResult> results) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = cubitReading(results);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        localizedApp(
          BlocProvider.value(
            value: cubit,
            child: SongImportDialog(
              pickFiles: () async => ['x'],
              pickFolder: () async => '/biblioteca',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('names every program it can read from', (tester) async {
      await pump(tester, const []);

      for (final name in [
        'ProPresenter 7',
        'ProPresenter 4–6',
        'OpenLP · OpenLyrics',
        'SongSelect (CCLI)',
        'ChordPro',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a folder is reviewed song by song, with the words beside the list', (
      tester,
    ) async {
      await pump(tester, [ok(imported('Cuan grande es el')), ok(imported('Renuévame', verses: 3))]);

      await tester.tap(find.text('Elegir carpeta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 canciones encontradas'), findsOneWidget);
      expect(find.text('Ya está'), findsOneWidget);
      expect(find.text('Importar 1 canción'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Renuévame'));
      await tester.pumpAndSettle();
      expect(find.text('Renuévame 2'), findsOneWidget, reason: 'its last slide, in the preview');
    });

    testWidgets('importing ends by saying how many were added', (tester) async {
      await pump(tester, [ok(imported('Renuévame'))]);
      await tester.tap(find.text('Elegir archivos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Importar 1 canción'));
      await tester.pumpAndSettle();

      expect(find.text('Se agregó 1 canción a la biblioteca'), findsOneWidget);
    });
  });

  group('the song form', () {
    test('editing a song keeps its copyright and CCLI number', () async {
      // The form did not carry them, so saving any edit wiped both, and the
      // licence report lost the song's number.
      final form = SongFormCubit(repo);
      addTearDown(form.close);
      form.init(
        const Song(
          id: 's1',
          title: 'Grande es tu fidelidad',
          copyright: '© 1923 Hope Publishing',
          ccliNumber: '18723',
        ),
      );

      form.updateTitle('Grande es tu fidelidad (en vivo)');
      await form.save();

      expect(repo.saved.single, {
        'id': 's1',
        'title': 'Grande es tu fidelidad (en vivo)',
        'copyright': '© 1923 Hope Publishing',
        'ccli': '18723',
      });
    });
  });
}
