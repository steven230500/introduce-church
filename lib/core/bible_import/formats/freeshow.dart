import 'dart:convert';

import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';

/// Reads a FreeShow Bible (`.fsb`): books, chapters and verses as objects that
/// carry their own numbers.
ImportedBible readFreeShowBible(String json, {required String source, required String name}) {
  final data = jsonDecode(json);
  if (data is! Map || data['books'] is! List) {
    throw const FormatException('not a FreeShow Bible');
  }

  final collector = VerseCollector();
  for (final (position, entry) in (data['books'] as List).indexed) {
    if (entry is! Map) continue;
    final number = leadingNumber(entry['number']);
    final bookName = entry['name'];
    final book = number != null
        ? bookIndexFromNumber(number)
        : bookName is String
        ? bookIndexFromName(bookName)
        : (position < 66 ? position : null);
    if (book == null) {
      collector.skip('${bookName ?? number}');
      continue;
    }
    final chapters = entry['chapters'];
    if (chapters is! List) continue;
    for (final (c, chapter) in chapters.indexed) {
      if (chapter is! Map || chapter['verses'] is! List) continue;
      final chapterNumber = leadingNumber(chapter['number']) ?? c + 1;
      for (final (v, verse) in (chapter['verses'] as List).indexed) {
        if (verse is! Map) continue;
        final text = verse['text'] ?? verse['value'] ?? '';
        collector.add(
          book,
          chapterNumber,
          leadingNumber(verse['number']) ?? v + 1,
          stripTags('$text'),
        );
      }
    }
  }

  final metadata = data['metadata'];
  final title = data['name'] ?? (metadata is Map ? metadata['title'] : null);
  final abbreviation = metadata is Map ? metadata['abbreviation'] : null;
  return collector.build(
    format: BibleFormat.freeShow,
    title: titleOr(title is String ? title : null, name),
    abbreviation: abbreviation is String ? abbreviation.trim() : null,
    source: source,
  );
}
