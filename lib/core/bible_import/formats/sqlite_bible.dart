import 'package:sqlite3/sqlite3.dart';

import '../../utils/rtf.dart';
import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';

/// Reads a Bible kept as a SQLite database: MySword's `.bbl.mybible`,
/// e-Sword's `.bblx` and MyBible's `.SQLite3`. Between them they hold most of
/// the Bibles Spanish-speaking churches already have on a computer.
///
/// Throws [FormatException] when the database is none of these.
ImportedBible readSqliteBible(String path, {required String source, required String name}) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final tables = {
      for (final row in db.select("select name from sqlite_master where type = 'table'"))
        (row['name'] as String).toLowerCase(),
    };
    if (tables.contains('verses')) return _myBible(db, source: source, name: name);
    if (tables.contains('bible')) return _bibleTable(db, source: source, name: name);
    throw const FormatException('not a Bible database');
  } finally {
    db.close();
  }
}

/// MySword and e-Sword: a `Bible` table of Book (1 to 66), Chapter, Verse and
/// Scripture, and a `Details` table naming it. MySword marks the text up the
/// GBF way (`<FI>`, `<RF>`), e-Sword in RTF.
ImportedBible _bibleTable(Database db, {required String source, required String name}) {
  final collector = VerseCollector();
  var rtf = false;
  for (final row in db.select('select Book, Chapter, Verse, Scripture from Bible')) {
    final number = row['Book'] as int?;
    final book = number == null ? null : bookIndexFromNumber(number);
    if (book == null) {
      collector.skip('$number');
      continue;
    }
    final raw = '${row['Scripture'] ?? ''}';
    final isRtf = raw.contains(r'\') || raw.startsWith('{');
    rtf = rtf || isRtf;
    collector.add(
      book,
      row['Chapter'] as int? ?? 0,
      row['Verse'] as int? ?? 0,
      isRtf ? _fromRtf(raw) : _fromGbf(raw),
    );
  }
  final details = _details(db);
  return collector.build(
    format: rtf ? BibleFormat.eSword : BibleFormat.mySword,
    title: titleOr(details.title, name),
    abbreviation: details.abbreviation,
    source: source,
    language: details.language,
  );
}

/// MyBible: a `verses` table numbered its own way (Genesis 10, Revelation 730)
/// and an `info` table of names and values. A `books` table, when there is
/// one, says which number is which book, and is believed over the usual list.
ImportedBible _myBible(Database db, {required String source, required String name}) {
  final collector = VerseCollector();
  final byNumber = <int, int?>{};
  try {
    for (final row in db.select('select book_number, long_name, short_name from books')) {
      final number = row['book_number'] as int?;
      if (number == null) continue;
      byNumber[number] =
          bookIndexFromName('${row['long_name'] ?? ''}') ??
          bookIndexFromName('${row['short_name'] ?? ''}') ??
          bookIndexFromMyBible(number);
    }
  } on SqliteException {
    // Older modules have no books table; the usual numbers stand.
  }
  for (final row in db.select('select book_number, chapter, verse, text from verses')) {
    final number = row['book_number'] as int?;
    if (number == null) continue;
    final book = byNumber.containsKey(number) ? byNumber[number] : bookIndexFromMyBible(number);
    if (book == null) {
      collector.skip('$number');
      continue;
    }
    collector.add(
      book,
      row['chapter'] as int? ?? 0,
      row['verse'] as int? ?? 0,
      _fromMyBible('${row['text'] ?? ''}'),
    );
  }
  String? info(String key) {
    try {
      final rows = db.select('select value from info where name = ?', [key]);
      return rows.isEmpty ? null : '${rows.first['value']}';
    } on SqliteException {
      return null;
    }
  }

  return collector.build(
    format: BibleFormat.myBible,
    title: titleOr(info('description'), name),
    source: source,
    language: info('language'),
  );
}

({String? title, String? abbreviation, String? language}) _details(Database db) {
  try {
    final rows = db.select('select * from Details limit 1');
    if (rows.isEmpty) return (title: null, abbreviation: null, language: null);
    final row = rows.first;
    String? read(String column) =>
        row.keys.contains(column) && row[column] != null ? '${row[column]}' : null;
    return (
      title: read('Title') ?? read('Description'),
      abbreviation: read('Abbreviation'),
      language: read('Language'),
    );
  } on SqliteException {
    return (title: null, abbreviation: null, language: null);
  }
}

/// MySword's GBF: notes between `<RF>` and `<Rf>`, headings between `<TS>`
/// and `<Ts>`, Strong's numbers as `<WH1234>`; everything else is formatting.
String _fromGbf(String text) => stripTags(
  text
      .replaceAll(RegExp(r'<RF[^>]*>.*?<Rf>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<TS[^>]*>.*?<Ts>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<(CM|CL)>'), ' '),
);

/// e-Sword's RTF, with the superscript groups that hold Strong's numbers and
/// verse notes taken out before the words are read.
String _fromRtf(String text) =>
    rtfToText(text.replaceAll(RegExp(r'\{[^{}]*\\super[^{}]*\}'), ' ')).replaceAll('\n', ' ');

/// MyBible's markup: Strong's numbers in `<S>`, footnotes in `<f>`, notes in
/// `<n>`, headings in `<h>`; line breaks as `<br/>` and `<pb/>`.
String _fromMyBible(String text) => stripTags(
  text
      .replaceAll(RegExp(r'<(S|f|n|h)>.*?</\1>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<(br|pb)\s*/?>'), ' '),
);
