import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';

/// Reads USFM, the text format translators work in: `\id GEN` names the book,
/// `\c 1` the chapter, `\v 1` the verse, and the words run on until the next
/// marker. A Bible usually comes as one file per book; [usfm] may hold them
/// all, one after another.
ImportedBible readUsfm(String usfm, {required String source, required String name}) {
  final collector = VerseCollector();
  final text = usfm
      .replaceAll('\r\n', '\n')
      // Footnotes, endnotes and cross references, with everything inside them.
      .replaceAll(RegExp(r'\\(f|fe|x|ef|ex)\s.*?\\\1\*', dotAll: true), ' ')
      // A word with its Strong's number: "\w principio|strong="H7225"\w*".
      .replaceAllMapped(RegExp(r'\\\+?w\s+([^|\\]*?)(\|[^\\]*)?\\\+?w\*'), (m) => m.group(1)!)
      // Titles, headings, a psalm's title, the introduction: whole lines that
      // are not verses.
      .replaceAll(
        RegExp(
          r'^\\(mt\d*|mte\d*|ms\d*|mr|s\d*|sr|sp|d|r|h|toc\d*|toca\d*|ide|rem|cl|cd|is\d*|ip|ipi|im|ipq|imq|ipr|iq\d*|ib|ili\d*|iot|io\d*|imt\d*|imte\d*|ie|periph)\b.*$',
          multiLine: true,
        ),
        '',
      );

  int? book;
  var chapter = 0;
  int? verse;
  final verseText = StringBuffer();

  void finish() {
    if (book != null && verse != null) {
      final words = verseText
          .toString()
          // Every other marker - poetry lines, paragraphs, added words, the
          // words of Jesus - carries no words of its own.
          .replaceAll(RegExp(r'\\\+?[a-z]+\d*\*?'), ' ');
      collector.add(book, chapter, verse!, words);
    }
    verse = null;
    verseText.clear();
  }

  final marker = RegExp(r'\\(id|c|v)\s+(\S+)');
  var at = 0;
  for (final match in marker.allMatches(text)) {
    if (verse != null) verseText.write(text.substring(at, match.start));
    at = match.end;
    final value = match.group(2)!;
    switch (match.group(1)) {
      case 'id':
        finish();
        book = bookIndexFromUsfm(value);
        if (book == null) collector.skip(value);
        chapter = 0;
      case 'c':
        finish();
        chapter = leadingNumber(value) ?? chapter + 1;
      case 'v':
        finish();
        verse = leadingNumber(value);
    }
  }
  if (verse != null) verseText.write(text.substring(at));
  finish();

  return collector.build(format: BibleFormat.usfm, title: name, source: source);
}

/// Whether [text] reads as USFM rather than as some other text.
bool looksLikeUsfm(String text) {
  final head = text.length > 4000 ? text.substring(0, 4000) : text;
  return RegExp(r'^\\id\s+[1-3A-Z]{3}', multiLine: true).hasMatch(head) ||
      (head.contains(r'\c ') && head.contains(r'\v '));
}
