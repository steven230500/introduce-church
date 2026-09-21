import 'package:xml/xml_events.dart';

import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';
import 'xml_support.dart';

/// Reads an OSIS Bible, what CrossWire's SWORD modules and eBible.org export.
///
/// OSIS marks verses two ways: as an element around the text, or as a pair of
/// empty markers at its start and end, with headings and paragraphs free to
/// fall between them. Both carry the reference, "Gen.1.1", which is all that
/// is needed to put the text in place.
ImportedBible readOsis(String xml, {required String source, required String name}) {
  final collector = VerseCollector();
  String? title;
  String? abbreviation;

  String? current;
  StringBuffer? verseText;
  var skipping = 0;
  var inHeader = false;
  var readingTitle = false;
  final titleText = StringBuffer();

  void finish() {
    final reference = current;
    final body = verseText;
    current = null;
    verseText = null;
    if (reference == null || body == null) return;
    final parts = reference.split('.');
    if (parts.length < 3) return;
    final book = bookIndexFromOsis(parts[0]);
    if (book == null) {
      collector.skip(parts[0]);
      return;
    }
    final chapter = leadingNumber(parts[1]);
    final verse = leadingNumber(parts[2]);
    if (chapter == null || verse == null) return;
    collector.add(book, chapter, verse, body.toString());
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
          case 'osistext':
            abbreviation = attributeOf(attributes, ['osisidwork']);
          case 'header':
            inHeader = !isSelfClosing;
          case 'title' when inHeader && title == null:
            readingTitle = true;
            titleText.clear();
          case 'verse':
            if (attributeOf(attributes, ['eid']) != null) {
              finish();
              continue;
            }
            final id = attributeOf(attributes, ['osisid', 'sid']);
            if (id == null) continue;
            finish();
            // "Gen.1.1 Gen.1.2" is two verses printed as one; it is kept
            // under the first.
            current = id.trim().split(RegExp(r'\s+')).first;
            verseText = StringBuffer();
          case _ when notBibleText.contains(tag) && !inHeader:
            if (!isSelfClosing) skipping = 1;
          case _ when lineBreaks.contains(tag):
            verseText?.write(' ');
        }

      case XmlEndElementEvent(name: final element):
        final tag = localName(element);
        if (skipping > 0) {
          skipping--;
          continue;
        }
        switch (tag) {
          case 'header':
            inHeader = false;
          case 'title' when readingTitle:
            title = titleText.toString();
            readingTitle = false;
          // Only the element form ends here; a milestone's end is a marker.
          case 'verse':
            finish();
          case _ when lineBreaks.contains(tag):
            verseText?.write(' ');
        }

      case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
        if (skipping > 0) continue;
        if (readingTitle) {
          titleText.write(value);
        } else {
          verseText?.write(value);
        }
    }
  }
  finish();

  return collector.build(
    format: BibleFormat.osis,
    title: titleOr(title, name),
    abbreviation: abbreviation?.trim(),
    source: source,
  );
}
