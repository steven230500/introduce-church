import 'dart:convert';

import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';

/// Reads a Bible kept as a list of books, each a list of chapters, each a list
/// of verse texts: the format the included Bible comes in, and the one the
/// versions dialog asked for before any other was read.
ImportedBible readBookList(String json, {required String source, required String name}) {
  final data = jsonDecode(json);
  if (data is! List) throw const FormatException('not a list of books');

  final collector = VerseCollector();
  for (final (position, entry) in data.indexed) {
    if (entry is! Map || entry['chapters'] is! List) {
      throw const FormatException('not a list of books');
    }
    final bookName = entry['name'];
    // Sixty-six entries are the 66 books in order; fewer have to say which.
    final book = data.length == 66
        ? position
        : (bookName is String ? bookIndexFromName(bookName) : null);
    if (book == null) {
      collector.skip('$bookName');
      continue;
    }
    for (final (c, chapter) in (entry['chapters'] as List).indexed) {
      if (chapter is! List) continue;
      for (final (v, verse) in chapter.indexed) {
        collector.add(book, c + 1, v + 1, stripTags('$verse'));
      }
    }
  }
  return collector.build(format: BibleFormat.bookList, title: name, source: source);
}
