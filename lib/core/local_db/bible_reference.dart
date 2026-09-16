/// Reading a reference the way an operator types it.
///
/// The preacher says "vamos a Juan tres dieciséis" and the operator has a few
/// seconds. Browsing to it is a book list, a chapter grid and a verse list;
/// this is a line of text.
library;

import 'bible_repository.dart' show spanishBookName;

/// A reference as someone typed it, before the text is looked up.
class BibleReference {
  const BibleReference({
    required this.bookIndex,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
  });

  final int bookIndex;
  final int chapter;

  /// Null when only a chapter was named, which means all of it.
  final int? verseStart;
  final int? verseEnd;

  String get bookName => spanishBookName(bookIndex);

  @override
  String toString() {
    if (verseStart == null) return '$bookName $chapter';
    if (verseEnd == null || verseEnd == verseStart) return '$bookName $chapter:$verseStart';
    return '$bookName $chapter:$verseStart-$verseEnd';
  }
}

/// Why a line could not be turned into a reference.
enum ReferenceProblem { empty, noBook, ambiguous, noChapter }

/// The outcome of reading one line.
typedef ReferenceResult = ({BibleReference? reference, ReferenceProblem? problem, String? typed});

/// Reads a line like "jn 3:16", "Juan 3:16-18", "1 co 13" or "salmos 23".
///
/// Accepts a colon or a dot between chapter and verse, and a hyphen or a dash
/// for a range, because operators type all of them.
ReferenceResult parseBibleReference(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return (reference: null, problem: ReferenceProblem.empty, typed: null);

  final match = _pattern.firstMatch(trimmed);
  if (match == null) {
    // Something was typed but no chapter number came with it.
    return (reference: null, problem: ReferenceProblem.noChapter, typed: trimmed);
  }

  final bookText = match.group(1)?.trim() ?? '';
  final matches = matchBooks(bookText);
  if (matches.isEmpty) {
    return (reference: null, problem: ReferenceProblem.noBook, typed: bookText);
  }
  if (matches.length > 1) {
    return (reference: null, problem: ReferenceProblem.ambiguous, typed: bookText);
  }

  final verseStart = match.group(3) == null ? null : int.tryParse(match.group(3)!);
  final verseEnd = match.group(4) == null ? null : int.tryParse(match.group(4)!);

  return (
    reference: BibleReference(
      bookIndex: matches.single,
      chapter: int.parse(match.group(2)!),
      verseStart: verseStart,
      // A backwards range is a typo, not a request for nothing.
      verseEnd: verseEnd == null || verseStart == null
          ? verseStart
          : (verseEnd < verseStart ? verseStart : verseEnd),
    ),
    problem: null,
    typed: null,
  );
}

/// Book indexes whose name or abbreviation starts with what was typed.
///
/// Exact wins over a prefix, so "juan" is Juan and never 1 Juan, and "job" is
/// Job rather than every book starting with those letters.
List<int> matchBooks(String text) {
  final needle = _normalise(text);
  if (needle.isEmpty) return const [];

  final exact = <int>[];
  final prefixes = <int>[];

  for (var index = 0; index < 66; index++) {
    final names = [_normalise(spanishBookName(index)), ...?_aliases[index]];
    if (names.contains(needle)) {
      exact.add(index);
      continue;
    }
    if (names.any((name) => name.startsWith(needle))) prefixes.add(index);
  }

  return exact.isNotEmpty ? exact : prefixes;
}

/// Books whose name or abbreviation holds what was typed, for offering
/// choices while the operator is still typing.
///
/// Looser than [matchBooks] on purpose: "cor" names no book, because the
/// books are "1 Corintios" and "2 Corintios", and an operator who types it
/// wants to be shown both rather than told it is not a book.
List<int> booksMatching(String text) {
  final exactOrPrefix = matchBooks(text);
  if (exactOrPrefix.isNotEmpty) return exactOrPrefix;

  final needle = _normalise(text);
  if (needle.length < 2) return const [];
  return [
    for (var index = 0; index < 66; index++)
      if ([_normalise(spanishBookName(index)), ...?_aliases[index]].any((n) => n.contains(needle)))
        index,
  ];
}

/// The chapter-and-verse tail, with everything before it taken as the book.
final _pattern = RegExp(r'^(.*?)\s*(\d{1,3})(?:\s*[:.]\s*(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?)?$');

/// Accents and case are not how anyone types a reference in a hurry.
String _normalise(String value) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final lower = value.toLowerCase().trim();
  final stripped = lower.split('').map((c) => accents[c] ?? c).join();
  // "1 juan", "1juan" and "1  juan" are the same book.
  return stripped.replaceAll(RegExp(r'\s+'), ' ');
}

/// How these books are shortened in Spanish.
///
/// Deliberately not the abbreviations in the bible file: those are English
/// derived, where "jn" is Jonás and "jud" is Jueces. An operator typing "jn"
/// means Juan, and giving them Jonás mid-sermon is worse than not finding it.
const _aliases = <int, List<String>>{
  0: ['gn', 'gen'],
  1: ['ex', 'exo'],
  2: ['lv', 'lev'],
  3: ['nm', 'num'],
  4: ['dt', 'deu'],
  5: ['jos'],
  6: ['jue', 'jc'],
  7: ['rt'],
  8: ['1 s', '1s', '1 sam'],
  9: ['2 s', '2s', '2 sam'],
  10: ['1 r', '1r', '1 re'],
  11: ['2 r', '2r', '2 re'],
  12: ['1 cr', '1cr'],
  13: ['2 cr', '2cr'],
  14: ['esd'],
  15: ['neh', 'ne'],
  16: ['est'],
  17: ['jb'],
  18: ['sal', 'sl', 'ps'],
  19: ['pr', 'prov'],
  20: ['ec', 'ecl'],
  21: ['cnt', 'cant'],
  22: ['is', 'isa'],
  23: ['jer', 'jr'],
  24: ['lm', 'lam'],
  25: ['ez', 'eze'],
  26: ['dn', 'dan'],
  27: ['os'],
  28: ['jl'],
  29: ['am'],
  30: ['abd'],
  31: ['jon'],
  32: ['mi', 'miq'],
  33: ['nah', 'na'],
  34: ['hab'],
  35: ['sof'],
  36: ['hag'],
  37: ['zac', 'zc'],
  38: ['mal'],
  39: ['mt', 'mat'],
  40: ['mr', 'mc', 'mar'],
  41: ['lc', 'luc'],
  42: ['jn', 'juan'],
  43: ['hch', 'hec'],
  44: ['ro', 'rom'],
  45: ['1 co', '1co', '1 cor'],
  46: ['2 co', '2co', '2 cor'],
  47: ['ga', 'gal'],
  48: ['ef'],
  49: ['fil', 'flp'],
  50: ['col', 'cl'],
  51: ['1 ts', '1ts', '1 tes'],
  52: ['2 ts', '2ts', '2 tes'],
  53: ['1 ti', '1ti', '1 tim'],
  54: ['2 ti', '2ti', '2 tim'],
  55: ['tit', 'tt'],
  56: ['flm'],
  57: ['heb', 'he'],
  58: ['stg', 'sant'],
  59: ['1 p', '1p', '1 pe'],
  60: ['2 p', '2p', '2 pe'],
  61: ['1 jn', '1jn', '1 juan'],
  62: ['2 jn', '2jn', '2 juan'],
  63: ['3 jn', '3jn', '3 juan'],
  64: ['jud', 'jds'],
  65: ['ap', 'apo'],
};
