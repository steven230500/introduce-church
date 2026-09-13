/// Matching what somebody typed against a list of names.
///
/// Written for the command palette, where the operator is halfway through a
/// service and types three letters. Two rules come from that: accents and case
/// never matter, because nobody reaches for the accent key in a hurry; and a
/// match at the start of a word beats one in the middle, because "cor" should
/// find "Coro" before "Incorruptible".
library;

/// How well [query] matches [text], or null when it does not match at all.
///
/// Higher is better. The number itself means nothing outside a comparison
/// between two candidates for the same query.
int? matchScore(String query, String text) {
  final needle = foldForSearch(query);
  if (needle.isEmpty) return 0;
  final haystack = foldForSearch(text);
  if (haystack.isEmpty) return null;

  // The whole query, in one piece.
  final at = haystack.indexOf(needle);
  if (at == 0) return 1000 - haystack.length;
  if (at > 0) {
    // Right after a space or a dash is the start of a word, which reads as a
    // deliberate match rather than an accident inside a longer one.
    final onWordStart = _isBoundary(haystack.codeUnitAt(at - 1));
    return (onWordStart ? 700 : 400) - at - haystack.length ~/ 4;
  }

  // Every word of the query somewhere, in any order: "nada imposible" finds
  // "NADA ES IMPOSIBLE".
  final words = needle.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length > 1 && words.every(haystack.contains)) {
    return 300 - haystack.length ~/ 4;
  }

  // Initials: "nei" finds "Nada Es Imposible". Only for short queries, or
  // three random letters would match half the library.
  if (needle.length <= 4 && !needle.contains(' ') && _initials(haystack).startsWith(needle)) {
    return 250;
  }

  return null;
}

/// Orders [items] by how well they match, dropping the ones that do not.
///
/// Ties keep the order they came in, so a library already sorted by name does
/// not shuffle itself on every keystroke.
List<T> rankByMatch<T>(String query, Iterable<T> items, String Function(T) nameOf) {
  final scored = <({T item, int score, int index})>[];
  for (final (index, item) in items.indexed) {
    final score = matchScore(query, nameOf(item));
    if (score != null) scored.add((item: item, score: score, index: index));
  }
  scored.sort((a, b) => a.score == b.score ? a.index - b.index : b.score - a.score);
  return [for (final row in scored) row.item];
}

/// Lower case, no accents, single spaces. The same shape the Bible reference
/// parser folds names into, for the same reason.
String foldForSearch(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
    'â': 'a',
    'ê': 'e',
    'ô': 'o',
    'ç': 'c',
  };
  final lower = value.toLowerCase().trim();
  final stripped = lower.split('').map((c) => accents[c] ?? c).join();
  return stripped.replaceAll(RegExp(r'\s+'), ' ');
}

String _initials(String folded) =>
    folded.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).join();

bool _isBoundary(int codeUnit) {
  const space = 32;
  const dash = 45;
  const underscore = 95;
  return codeUnit == space || codeUnit == dash || codeUnit == underscore;
}
