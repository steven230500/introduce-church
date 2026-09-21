import 'dart:convert';
import '../bible_import/book_codes.dart' show bookAbbrevs;
import '../bible_import/imported_bible.dart';
import '../services/app_prefs_service.dart';
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

  /// Where the operator's choice of version is kept. Null in tests that do
  /// not care which version is chosen.
  final AppPrefsService? _prefs;

  BibleRepository(this._db, [this._prefs]);

  /// The versions that can be read, the church's own first.
  ///
  /// One whose download was cut off is left out: it has holes, and a passage
  /// that falls in one would come up empty in the middle of a service.
  Future<List<BibleVersion>> getVersions() async {
    final versions = (await _db.getAllVersions()).where((v) => v.isDownloaded).toList();
    versions.sort((a, b) {
      if (a.isBundled != b.isBundled) return a.isBundled ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return versions;
  }

  /// The version to use when nobody picks one: the one the operator chose last,
  /// else the one the church brought in most recently, else the included one.
  ///
  /// A church that went to the trouble of importing its Bible wants that one,
  /// not the 1909 that comes in the box.
  Future<BibleVersion?> preferredVersion() async {
    final versions = await getVersions();
    if (versions.isEmpty) return null;
    final chosen = await _prefs?.bibleVersion();
    final match = versions.where((v) => v.code == chosen).firstOrNull;
    if (match != null) return match;
    final own = versions.where((v) => !v.isBundled).toList()
      ..sort((a, b) => (b.downloadedAt ?? DateTime(0)).compareTo(a.downloadedAt ?? DateTime(0)));
    return own.firstOrNull ?? versions.first;
  }

  Future<void> rememberVersion(String code) async => _prefs?.setBibleVersion(code);

  /// Every version on this computer, a half-installed one included, for the
  /// versions dialog to show and let the operator remove.
  Future<List<BibleVersion>> getInstalledVersions() => _db.getAllVersions();

  /// Whether every book and chapter of [version] is there. The included one
  /// always is.
  Future<bool> isComplete(BibleVersion version) async =>
      version.isBundled || (version.isDownloaded && await _db.isVersionComplete(version.code));

  /// Saves a Bible the church brought, replacing any version with [code].
  ///
  /// Only on this computer. Nothing here goes to the server: the church's copy
  /// is the church's, and passing it through Introduce would make Introduce
  /// the one handing it out.
  Future<void> install(ImportedBible bible, {required String code, required String name}) =>
      _db.installVersion(
        code: code,
        name: name,
        books: bible.books,
        bookNames: _spanishBookNames,
        bookAbbrevs: bookAbbrevs,
      );

  Future<void> delete(String code) => _db.deleteVersion(code);

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
