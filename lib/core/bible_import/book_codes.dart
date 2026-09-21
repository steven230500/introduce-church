/// How other programs name the 66 books, so a file from any of them lands
/// each book in its place.
///
/// Files number the books, name them or give an OSIS code; which one depends
/// on the program that made the file. A book that is none of these 66 - the
/// deuterocanonical books of a Catholic Bible - has no place here and is left
/// out rather than put where another book goes.
library;

import '../local_db/bible_reference.dart' show matchBooks;

/// OSIS book codes, in canonical order.
const osisBookCodes = [
  'Gen', 'Exod', 'Lev', 'Num', 'Deut', 'Josh', 'Judg', 'Ruth', '1Sam', '2Sam', //
  '1Kgs', '2Kgs', '1Chr', '2Chr', 'Ezra', 'Neh', 'Esth', 'Job', 'Ps', 'Prov',
  'Eccl', 'Song', 'Isa', 'Jer', 'Lam', 'Ezek', 'Dan', 'Hos', 'Joel', 'Amos',
  'Obad', 'Jonah', 'Mic', 'Nah', 'Hab', 'Zeph', 'Hag', 'Zech', 'Mal', 'Matt',
  'Mark', 'Luke', 'John', 'Acts', 'Rom', '1Cor', '2Cor', 'Gal', 'Eph', 'Phil',
  'Col', '1Thess', '2Thess', '1Tim', '2Tim', 'Titus', 'Phlm', 'Heb', 'Jas', '1Pet',
  '2Pet', '1John', '2John', '3John', 'Jude', 'Rev',
];

/// English names, for the OpenSong files that were made in English.
const _englishNames = [
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua', 'judges', //
  'ruth', '1 samuel', '2 samuel', '1 kings', '2 kings', '1 chronicles', '2 chronicles',
  'ezra', 'nehemiah', 'esther', 'job', 'psalms', 'proverbs', 'ecclesiastes',
  'song of solomon', 'isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea',
  'joel', 'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts', 'romans',
  '1 corinthians', '2 corinthians', 'galatians', 'ephesians', 'philippians',
  'colossians', '1 thessalonians', '2 thessalonians', '1 timothy', '2 timothy', 'titus',
  'philemon', 'hebrews', 'james', '1 peter', '2 peter', '1 john', '2 john', '3 john',
  'jude', 'revelation',
];

const _englishAliases = {'psalm': 18, 'song of songs': 21, 'canticles': 21, 'revelations': 65};

/// The short codes stored with each book, the same ones the included Bible
/// has always used.
const bookAbbrevs = [
  'gn', 'ex', 'lv', 'nm', 'dt', 'js', 'jud', 'rt', '1sm', '2sm', '1kgs', '2kgs', //
  '1ch', '2ch', 'ezr', 'ne', 'et', 'job', 'ps', 'prv', 'ec', 'so', 'is', 'jr', 'lm',
  'ez', 'dn', 'ho', 'jl', 'am', 'ob', 'jn', 'mi', 'na', 'hk', 'zp', 'hg', 'zc', 'ml',
  'mt', 'mk', 'lk', 'jo', 'act', 'rm', '1co', '2co', 'gl', 'eph', 'ph', 'cl', '1ts',
  '2ts', '1tm', '2tm', 'tt', 'phm', 'hb', 'jm', '1pe', '2pe', '1jo', '2jo', '3jo',
  'jd', 're',
];

/// Where a book numbered 1 to 66 goes, or null for any other number.
int? bookIndexFromNumber(int number) => number >= 1 && number <= 66 ? number - 1 : null;

/// Where an OSIS code goes: "Gen", "1Cor".
int? bookIndexFromOsis(String code) {
  final index = osisBookCodes.indexWhere((c) => c.toLowerCase() == code.toLowerCase());
  return index < 0 ? null : index;
}

/// Where a book goes by its name, in Spanish or in English.
int? bookIndexFromName(String name) {
  final plain = _plain(name);
  final exact = _englishNames.indexOf(plain);
  if (exact >= 0) return exact;
  final alias = _englishAliases[plain];
  if (alias != null) return alias;
  // Spanish names, abbreviations and the ways operators type them.
  final spanish = matchBooks(plain);
  return spanish.length == 1 ? spanish.single : null;
}

/// Lower case, single spaces, and "II Kings" read as "2 kings".
String _plain(String value) {
  final spaced = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final roman = RegExp(r'^(i{1,3})\.? ').firstMatch(spaced);
  if (roman == null) return spaced;
  return '${roman.group(1)!.length} ${spaced.substring(roman.end)}';
}
