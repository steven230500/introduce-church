import 'dart:convert';
import 'app_database.dart';

const _spanishBookNames = [
  'Génesis',
  'Éxodo',
  'Levítico',
  'Números',
  'Deuteronomio',
  'Josué',
  'Jueces',
  'Rut',
  '1 Samuel',
  '2 Samuel',
  '1 Reyes',
  '2 Reyes',
  '1 Crónicas',
  '2 Crónicas',
  'Esdras',
  'Nehemías',
  'Ester',
  'Job',
  'Salmos',
  'Proverbios',
  'Eclesiastés',
  'Cantares',
  'Isaías',
  'Jeremías',
  'Lamentaciones',
  'Ezequiel',
  'Daniel',
  'Oseas',
  'Joel',
  'Amós',
  'Abdías',
  'Jonás',
  'Miqueas',
  'Nahúm',
  'Habacuc',
  'Sofonías',
  'Hageo',
  'Zacarías',
  'Malaquías',
  'Mateo',
  'Marcos',
  'Lucas',
  'Juan',
  'Hechos',
  'Romanos',
  '1 Corintios',
  '2 Corintios',
  'Gálatas',
  'Efesios',
  'Filipenses',
  'Colosenses',
  '1 Tesalonicenses',
  '2 Tesalonicenses',
  '1 Timoteo',
  '2 Timoteo',
  'Tito',
  'Filemón',
  'Hebreos',
  'Santiago',
  '1 Pedro',
  '2 Pedro',
  '1 Juan',
  '2 Juan',
  '3 Juan',
  'Judas',
  'Apocalipsis',
];

String spanishBookName(int bookIndex) =>
    bookIndex < _spanishBookNames.length ? _spanishBookNames[bookIndex] : '';

class BibleVerseRef {
  final String versionCode;
  final String versionName;
  final int bookIndex;
  final String bookName;
  final String bookAbbrev;
  final int chapter;
  final int verseStart; // 1-based
  final int verseEnd; // inclusive, same as verseStart for single verse
  final List<String> texts; // one per verse in range

  const BibleVerseRef({
    required this.versionCode,
    required this.versionName,
    required this.bookIndex,
    required this.bookName,
    required this.bookAbbrev,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.texts,
  });

  bool get isRange => verseEnd > verseStart;

  String get reference =>
      isRange ? '$bookName $chapter:$verseStart-$verseEnd' : '$bookName $chapter:$verseStart';

  Map<String, dynamic> toJson() => {
    'book': bookName,
    'bookIndex': bookIndex,
    'bookAbbrev': bookAbbrev,
    'chapter': chapter,
    'verse': verseStart,
    'verseEnd': verseEnd,
    'texts': texts,
    'version': versionCode,
    'versionName': versionName,
  };
}

class BibleRepository {
  final AppDatabase _db;

  BibleRepository(this._db);

  Future<List<BibleVersion>> getVersions() => _db.getAllVersions();

  Future<List<BibleBook>> getBooks(String versionCode) => _db.getBooks(versionCode);

  Future<List<String>> getVerses(String versionCode, int bookIndex, int chapter) async {
    final row = await _db.getChapter(versionCode, bookIndex, chapter);
    if (row == null) return [];
    final raw = jsonDecode(row.versesJson);
    return List<String>.from(raw as List);
  }

  Future<BibleVerseRef?> getVerseRange({
    required String versionCode,
    required int bookIndex,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) async {
    final versions = await _db.getAllVersions();
    final version = versions.firstWhere((v) => v.code == versionCode);
    final books = await _db.getBooks(versionCode);
    final book = books.firstWhere((b) => b.bookIndex == bookIndex);
    final verses = await getVerses(versionCode, bookIndex, chapter);
    if (verseStart < 1 || verseEnd > verses.length) return null;
    final clampedEnd = verseEnd.clamp(verseStart, verses.length);
    final texts = verses.sublist(verseStart - 1, clampedEnd);
    return BibleVerseRef(
      versionCode: versionCode,
      versionName: version.name,
      bookIndex: bookIndex,
      bookName: spanishBookName(bookIndex),
      bookAbbrev: book.abbrev,
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: clampedEnd,
      texts: texts,
    );
  }
}
