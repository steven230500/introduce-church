import 'package:introduce_church/core/bible_import/imported_bible.dart';
import 'package:introduce_church/core/local_db/app_database.dart';

ImportedBible importedBible(Map<int, List<List<String>>> books) => ImportedBible(
  title: 'Prueba',
  books: books,
  source: '/prueba.xml',
  format: BibleFormat.zefania,
);

/// The whole Bible, one verse per book, as a file brings it.
ImportedBible wholeBible(String verse) => importedBible({
  for (var i = 0; i < 66; i++)
    i: [
      ['$verse $i'],
    ],
});

/// What builds up to 1.1.0 left on every computer: the 1909 text, included
/// with the app, under the name of the 1960.
Future<void> installMislabelled(AppDatabase db) => db.insertVersion(
  code: 'RVR1960',
  name: 'Reina-Valera 1960',
  isBundled: true,
  books: [
    for (var i = 0; i < 66; i++)
      {
        'abbrev': 'b$i',
        'name': 'Libro $i',
        'chapters': [
          ['crió Dios $i'],
        ],
      },
  ],
);
