import 'package:xml/xml_events.dart';

import '../book_codes.dart';
import '../imported_bible.dart';
import '../verse_collector.dart';
import 'xml_support.dart';

/// Reads a Zefania XML Bible (`XMLBIBLE` / `BIBLEBOOK` / `CHAPTER` / `VERS`),
/// the format most Bibles found online for projection software come in.
ImportedBible readZefania(String xml, {required String source, required String name}) =>
    _readTagged(xml, BibleFormat.zefania, source: source, name: name);

/// Reads a Beblia XML Bible (`bible` / `book` / `chapter` / `verse`).
ImportedBible readBeblia(String xml, {required String source, required String name}) =>
    _readTagged(xml, BibleFormat.beblia, source: source, name: name);

/// Reads an OpenSong Bible (`bible` / `b` / `c` / `v`), which OpenLP and
/// OpenSong share.
ImportedBible readOpenSong(String xml, {required String source, required String name}) =>
    _readTagged(xml, BibleFormat.openSong, source: source, name: name);

/// The three are the same shape under three sets of names, so one reader
/// takes all of them. Read as a stream of events, not a tree: a whole Bible
/// as a tree is several times the size of the file.
ImportedBible _readTagged(
  String xml,
  BibleFormat format, {
  required String source,
  required String name,
}) {
  final collector = VerseCollector();
  String? title;
  String? abbreviation;

  int? book;
  var booksSeen = 0;
  var chapter = 0;
  var chaptersSeen = 0;
  var verse = 0;
  var versesSeen = 0;
  StringBuffer? verseText;
  var skipping = 0;

  // Zefania's <INFORMATION> block.
  var inInformation = false;
  String? field;
  final fieldText = StringBuffer();

  for (final event in parseEvents(xml)) {
    switch (event) {
      case XmlStartElementEvent(name: final element, :final attributes, :final isSelfClosing):
        final tag = localName(element);
        if (skipping > 0) {
          if (!isSelfClosing) skipping++;
          continue;
        }
        switch (tag) {
          case 'xmlbible' || 'bible':
            title = attributeOf(attributes, ['biblename', 'name', 'translation']);
          case 'information':
            inInformation = !isSelfClosing;
          case 'title' || 'identifier' when inInformation:
            field = tag;
            fieldText.clear();
          case 'biblebook' || 'book' || 'b':
            booksSeen++;
            chaptersSeen = 0;
            final number = leadingNumber(attributeOf(attributes, ['bnumber', 'number']));
            final bookName = attributeOf(attributes, ['bname', 'name', 'n']);
            book = _whichBook(number, bookName, booksSeen);
            if (book == null) collector.skip(bookName ?? '$number');
          case 'chapter' || 'c':
            chaptersSeen++;
            versesSeen = 0;
            chapter =
                leadingNumber(attributeOf(attributes, ['cnumber', 'number', 'n'])) ?? chaptersSeen;
          case 'vers' || 'verse' || 'v':
            versesSeen++;
            verse =
                leadingNumber(attributeOf(attributes, ['vnumber', 'number', 'n'])) ?? versesSeen;
            verseText = isSelfClosing ? null : StringBuffer();
          case _ when notBibleText.contains(tag) && verseText != null:
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
          case 'information':
            inInformation = false;
          case 'title' || 'identifier' when field == tag:
            if (tag == 'title') title = fieldText.toString();
            if (tag == 'identifier') abbreviation = fieldText.toString();
            field = null;
          case 'vers' || 'verse' || 'v':
            if (verseText != null && book != null) {
              collector.add(book, chapter, verse, verseText.toString());
            }
            verseText = null;
          case _ when lineBreaks.contains(tag):
            verseText?.write(' ');
        }

      case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
        if (skipping > 0) continue;
        if (verseText != null) {
          verseText.write(value);
        } else if (field != null) {
          fieldText.write(value);
        }
    }
  }

  return collector.build(
    format: format,
    title: titleOr(title, name),
    abbreviation: abbreviation?.trim(),
    source: source,
  );
}

/// A book by its number, else by its name (OpenSong's `n` can be either),
/// else by where it comes in the file.
int? _whichBook(int? number, String? name, int position) {
  if (number != null) return bookIndexFromNumber(number);
  if (name != null) {
    final asNumber = int.tryParse(name.trim());
    return asNumber != null ? bookIndexFromNumber(asNumber) : bookIndexFromName(name);
  }
  return position <= 66 ? position - 1 : null;
}
