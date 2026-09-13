import 'package:xml/xml.dart';

import '../../models/song.dart';
import '../imported_song.dart';

/// Reads an OpenLyrics `.xml` song: what OpenLP exports, and what several
/// other programs can write.
ImportedSong readOpenLyrics(String xml, {required String source, required String name}) {
  final XmlElement root;
  try {
    root = XmlDocument.parse(xml).rootElement;
  } on XmlException {
    throw const FormatException('not an OpenLyrics document');
  }
  if (root.name.local != 'song') throw const FormatException('not an OpenLyrics document');

  Iterable<XmlElement> named(XmlElement parent, String local) =>
      parent.descendantElements.where((e) => e.name.local == local);
  String? text(String local) => nonEmpty(named(root, local).firstOrNull?.innerText);

  final authors = <String>[];
  for (final author in named(root, 'author')) {
    final value = nonEmpty(author.innerText);
    if (value != null && !authors.contains(value)) authors.add(value);
  }

  // Translations of the same verse share its name and differ by language;
  // the song is imported in the first language it has.
  final verseElements = named(root, 'verse').toList();
  final language = verseElements.map((v) => v.getAttribute('lang')).whereType<String>().firstOrNull;
  final verses = <String, ImportedVerse>{};
  final natural = <ImportedVerse>[];
  for (final verse in verseElements) {
    final lang = verse.getAttribute('lang');
    if (lang != null && lang != language) continue;
    final name = (verse.getAttribute('name') ?? '').toLowerCase();
    final content = tidyLyrics(
      [for (final lines in named(verse, 'lines')) _lines(lines)].join('\n'),
    );
    if (content.isEmpty) continue;
    final imported = ImportedVerse(_type(name), content);
    verses.putIfAbsent(name, () => imported);
    natural.add(imported);
  }

  final order = (text('verseOrder') ?? '')
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((n) => n.isNotEmpty)
      .map((n) => verses[n])
      .whereType<ImportedVerse>()
      .toList();

  return ImportedSong(
    title: text('title') ?? name,
    author: authors.isEmpty ? null : authors.join(', '),
    copyright: text('copyright'),
    ccliNumber: text('ccliNo'),
    verses: order.isNotEmpty ? order : natural,
    source: source,
    format: SongFormat.openLyrics,
  );
}

/// The words in a `<lines>` element: line breaks where `<br/>` is, chords and
/// comments left out, and the indentation of a pretty-printed file ignored.
String _lines(XmlElement lines) {
  final out = StringBuffer();
  void walk(XmlNode node) {
    for (final child in node.children) {
      if (child is XmlText) {
        // Older OpenLP wrote chords into the text as [D] or [Ami], hidden by
        // a formatting tag; the tag is walked like any other, so the chord
        // names are taken out here.
        out.write(child.value.replaceAll(_chord, '').replaceAll(RegExp(r'\s+'), ' '));
      } else if (child is XmlElement) {
        switch (child.name.local) {
          case 'br':
            out.write('\n');
          case 'comment':
            break;
          default:
            // A 0.9 chord wraps the syllable it sits on; the syllable stays.
            walk(child);
        }
      }
    }
  }

  walk(lines);
  return out.toString().split('\n').map((l) => l.trim()).join('\n');
}

final _chord = RegExp(r'\[[A-H][#b]?[^\]\s]{0,7}\]');

/// OpenLyrics names: v1, c, c2, b, p, i, e (ending), o (other).
VerseType _type(String name) => switch (name.isEmpty ? '' : name[0]) {
  'c' => VerseType.chorus,
  'b' => VerseType.bridge,
  'p' => VerseType.preCHORUS,
  'i' => VerseType.intro,
  'e' => VerseType.outro,
  _ => VerseType.verse,
};
