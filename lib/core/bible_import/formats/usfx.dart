import 'package:xml/xml_events.dart';

import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';
import 'xml_support.dart';

/// Reads a USFX Bible: what eBible.org publishes for every translation it
/// carries, the public-domain Spanish and English ones included.
///
/// Verses are marked by an empty `<v id="1"/>` where they start and, usually,
/// an empty `<ve/>` where they end; words sit inside `<w>` elements carrying
/// Strong's numbers, which are dropped. Headings, footnotes and cross
/// references are not the Bible's words and are passed over.
ImportedBible readUsfx(String xml, {required String source, required String name}) {
  final collector = VerseCollector();
  int? book;
  var chapter = 0;
  int? verse;
  StringBuffer? verseText;
  var skipping = 0;
  String? language;
  var readingLanguage = false;

  void finish() {
    final text = verseText;
    if (book != null && verse != null && text != null) {
      collector.add(book, chapter, verse!, text.toString());
    }
    verse = null;
    verseText = null;
  }

  for (final event in parseEvents(xml)) {
    switch (event) {
      case XmlStartElementEvent(name: final element, :final attributes, :final isSelfClosing):
        final tag = localName(element);
        if (skipping > 0) {
          if (!isSelfClosing) skipping++;
          continue;
        }
        switch (tag) {
          case 'languagecode':
            readingLanguage = !isSelfClosing;
          case 'book':
            finish();
            final id = attributeOf(attributes, ['id']) ?? '';
            book = bookIndexFromUsfm(id);
            if (book == null) collector.skip(id);
          case 'c':
            finish();
            chapter = leadingNumber(attributeOf(attributes, ['id'])) ?? chapter + 1;
          case 'v':
            finish();
            verse = leadingNumber(attributeOf(attributes, ['id']));
            verseText = StringBuffer();
          case 've':
            finish();
          case 'p' when _isHeading(attributeOf(attributes, ['sfm'])):
            if (!isSelfClosing) skipping = 1;
          case _ when _notVerseText.contains(tag):
            if (!isSelfClosing) skipping = 1;
          case _ when lineBreaks.contains(tag) || tag == 'q':
            verseText?.write(' ');
        }

      case XmlEndElementEvent(name: final element):
        final tag = localName(element);
        if (skipping > 0) {
          skipping--;
          continue;
        }
        if (tag == 'book') finish();
        if (tag == 'languagecode') readingLanguage = false;
        if (lineBreaks.contains(tag) || tag == 'q') verseText?.write(' ');

      case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
        if (readingLanguage) language = value;
        if (skipping == 0) verseText?.write(value);
    }
  }
  finish();

  return collector.build(format: BibleFormat.usfx, title: name, source: source, language: language);
}

/// Footnotes, cross references, headings and the book's names in its
/// header, none of which are verses.
const _notVerseText = {
  'f',
  'fe',
  'x',
  'h',
  'toc',
  'id',
  'ide',
  's',
  'd',
  'ms',
  'mt',
  'rem',
  'fig',
  'note',
};

/// A paragraph that is a title or a heading, by its USFM marker: "mt", "s1",
/// "d" for a psalm's title.
bool _isHeading(String? sfm) =>
    sfm != null && RegExp(r'^(mt|ms|mr|s|sr|sp|d|r|cl|i)', caseSensitive: false).hasMatch(sfm);
