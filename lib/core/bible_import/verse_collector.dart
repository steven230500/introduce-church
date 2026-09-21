import 'imported_bible.dart';

/// Verses as a reader finds them, in whatever order, put in place at the end.
///
/// Every format ends up here, so a gap in the numbering, a verse split across
/// two elements or a book that is not among the 66 is dealt with once.
class VerseCollector {
  final _verses = <int, Map<int, Map<int, String>>>{};
  final _skipped = <String>{};

  /// Verse [verse] of chapter [chapter] of book [book] (0 to 65).
  void add(int book, int chapter, int verse, String raw) {
    if (chapter < 1 || verse < 1) return;
    final text = raw.replaceAll(_studyMarks, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final chapters = _verses.putIfAbsent(book, () => {});
    final verses = chapters.putIfAbsent(chapter, () => {});
    // A verse split in two in the file is still one verse.
    final before = verses[verse];
    verses[verse] = before == null || before.isEmpty ? text : '$before $text'.trim();
  }

  /// A book that is not among the 66, named however the file names it.
  void skip(String book) => _skipped.add(book);

  ImportedBible build({
    required BibleFormat format,
    required String title,
    required String source,
    String? abbreviation,
  }) {
    final books = <int, List<List<String>>>{};
    for (final book in _verses.keys.toList()..sort()) {
      final chapters = _verses[book]!;
      books[book] = [
        for (var c = 1; c <= _last(chapters.keys); c++)
          if (chapters[c] case final verses?)
            [for (var v = 1; v <= _last(verses.keys); v++) verses[v] ?? '']
          else
            const <String>[],
      ];
    }
    return ImportedBible(
      title: title,
      abbreviation: abbreviation,
      books: books,
      skippedBooks: _skipped.length,
      source: source,
      format: format,
    );
  }

  static int _last(Iterable<int> numbers) => numbers.reduce((a, b) => a > b ? a : b);
}

/// The asterisk La Biblia de las Américas and the NBLA put after a verb in the
/// historical present ("le dijo*"). A study aid on paper; on a screen in front
/// of a congregation it reads as a typo.
final _studyMarks = RegExp(r'(?<=\p{L})\*', unicode: true);

/// "20", "20-21" and "20a" are all verse 20.
int? leadingNumber(Object? value) {
  if (value == null) return null;
  final match = RegExp(r'\d+').firstMatch('$value');
  return match == null ? null : int.parse(match.group(0)!);
}

/// Spaces tidied, and the file's name when the file gives no title.
String titleOr(String? value, String fallback) {
  final trimmed = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

/// Italics and small caps some programs keep as markup inside the verse.
String stripTags(String text) => text.replaceAll(RegExp(r'<[^>]+>'), '');
