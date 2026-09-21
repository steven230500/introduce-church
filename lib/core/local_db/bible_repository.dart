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

const _englishBookNames = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges', 'Ruth', //
  '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
  'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
  'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah',
  'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians',
  '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
  '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
  '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
];

/// A book's name in the language of the Bible it is read from: the English
/// Bible says "John 3:16", whatever language the app is in. [inReference]
/// is the name under a verse, where English says "Psalm 23", not "Psalms".
String bookName(int bookIndex, {String? language, bool inReference = false}) {
  if (language != 'en') return spanishBookName(bookIndex);
  if (bookIndex >= _englishBookNames.length) return '';
  return inReference && bookIndex == 18 ? 'Psalm' : _englishBookNames[bookIndex];
}

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

/// A verse found by its words.
typedef VerseHit = ({int bookIndex, int chapter, int verse, String text});

/// [text] lower case, without accents or punctuation: how a search is
/// compared, since nobody types "Jehová" with the accent in a hurry.
String searchable(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final lower = text.toLowerCase();
  final plain = StringBuffer();
  for (final c in lower.split('')) {
    plain.write(accents[c] ?? c);
  }
  return plain.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class BibleRepository {
  final AppDatabase _db;

  /// Every verse of a version in [searchable] form, read the first time the
  /// version is searched and kept: a second search is a scan of memory, not
  /// of the database.
  final _searchIndex = <String, List<({VerseHit hit, String plain})>>{};

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
    if (own.isNotEmpty) return own.first;
    // Of the ones the app carries, the one in the app's language.
    final language = await _prefs?.getLocale() ?? 'es';
    return versions.where((v) => (v.language ?? 'es') == language).firstOrNull ?? versions.first;
  }

  Future<void> rememberVersion(String code) async => _prefs?.setBibleVersion(code);

  /// Whether [texts] are, word for word, verses [start] onwards of [chapter]
  /// of book [bookIndex] in version [code]. False when that version is not
  /// on this computer.
  Future<bool> hasText(
    String code, {
    required int bookIndex,
    required int chapter,
    required int start,
    required List<String> texts,
  }) async {
    if (texts.isEmpty || start < 1) return false;
    final verses = await getVerses(code, bookIndex, chapter);
    if (start - 1 + texts.length > verses.length) return false;
    for (final (i, text) in texts.indexed) {
      if (verses[start - 1 + i].trim() != text.trim()) return false;
    }
    return true;
  }

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
  Future<void> install(
    ImportedBible bible, {
    required String code,
    required String name,
    String language = 'es',
  }) async {
    _searchIndex.remove(code);
    await _db.installVersion(
      code: code,
      name: name,
      language: language,
      books: bible.books,
      bookNames: language == 'en' ? _englishBookNames : _spanishBookNames,
      bookAbbrevs: bookAbbrevs,
    );
  }

  Future<void> delete(String code) async {
    _searchIndex.remove(code);
    await _db.deleteVersion(code);
  }

  /// The verses of version [code] that hold every word of [query], in the
  /// order of the Bible, at most [limit] of them. "de tal manera amo" finds
  /// John 3:16.
  Future<List<VerseHit>> searchText(String code, String query, {int limit = 50}) async {
    final words = searchable(query).split(' ').where((w) => w.length > 1).toList();
    if (words.isEmpty) return const [];
    final index = _searchIndex[code] ??= await _readForSearch(code);
    final hits = <VerseHit>[];
    for (final entry in index) {
      if (words.every(entry.plain.contains)) {
        hits.add(entry.hit);
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }

  Future<List<({VerseHit hit, String plain})>> _readForSearch(String code) async {
    final chapters = await _db.getChapters(code)
      ..sort(
        (a, b) => a.bookIndex != b.bookIndex
            ? a.bookIndex.compareTo(b.bookIndex)
            : a.chapter.compareTo(b.chapter),
      );
    return [
      for (final row in chapters)
        for (final (i, verse) in List<String>.from(jsonDecode(row.versesJson) as List).indexed)
          if (verse.trim().isNotEmpty)
            (
              hit: (bookIndex: row.bookIndex, chapter: row.chapter, verse: i + 1, text: verse),
              plain: ' ${searchable(verse)} ',
            ),
    ];
  }

  /// Gives version [code] a new code and name, text untouched. The operator's
  /// choice of version follows it.
  Future<void> rename(String code, {required String to, required String name}) async {
    _searchIndex.remove(code);
    await _db.renameVersion(code, to: to, name: name);
    if (await _prefs?.bibleVersion() == code) await rememberVersion(to);
  }

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
      bookName: bookName(bookIndex, language: version.language, inReference: true),
      bookAbbrev: book.abbrev,
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: clampedEnd,
      texts: texts,
    );
  }
}
