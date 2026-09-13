import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../imported_song.dart';
import '../protobuf.dart';
import '../rtf.dart';
import '../section_names.dart';

/// A group of slides as ProPresenter keeps it: "Verse 1" and its slides.
class _Group {
  _Group(this.id, this.name, this.slides);
  final String id;
  final String name;
  final List<String> slides;
}

/// Spells out the song in the order the operator last arranged it, or in the
/// order of its groups when there is no arrangement.
List<ImportedVerse> _versesOf(List<_Group> groups, {List<String>? arrangement}) {
  final byId = {for (final g in groups) g.id: g};
  final order = [for (final id in arrangement ?? const <String>[]) ?byId[id]];
  final sequence = order.isNotEmpty ? order : groups;
  return [
    for (final group in sequence)
      for (final slide in group.slides)
        if (tidyLyrics(slide).isNotEmpty)
          ImportedVerse(sectionTypeOr(group.name), tidyLyrics(slide)),
  ];
}

String? _copyright(int? year, String? publisher) {
  final who = nonEmpty(publisher)?.replaceFirst(RegExp(r'^(©|\(c\))\s*', caseSensitive: false), '');
  // Publishers are often written with their year already in them.
  final when = year != null && year > 0 && !(who ?? '').contains('$year') ? '$year' : null;
  final parts = [?when, ?who];
  return parts.isEmpty ? null : '© ${parts.join(' ')}';
}

/// RTF is meant to be ASCII with everything else escaped, and ProPresenter
/// writes it that way, but files made by other tools put UTF-8 straight in.
/// Read as UTF-8 when it is valid, which ASCII always is.
String _rtfSource(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

// ── ProPresenter 7 ──────────────────────────────────────────────────────────
//
// Field numbers from rv.data.Presentation (github.com/greyshirtguy/
// ProPresenter7-Proto). The words of a slide are at
//   cues(13) → actions(10) → slide(23) → presentation(2) → base_slide(1)
//   → elements(1) → element(1) → text(13) → rtf_data(5)
// and nowhere else: the slide's notes, at presentation(2) → notes(2), are the
// operator's, not the congregation's.

/// Reads a ProPresenter 7 `.pro` document. Throws [FormatException] when the
/// bytes are not one.
ImportedSong readProPresenter7(Uint8List bytes, {required String source, required String name}) {
  final doc = readProto(bytes);
  if (doc == null || doc.field(13) == null && doc.field(12) == null) {
    throw const FormatException('not a ProPresenter 7 document');
  }

  String uuid(List<ProtoField>? message) => message?.string(1) ?? '';

  final slideText = <String, String>{};
  final cueOrder = <String>[];
  for (final cueField in doc.all(13)) {
    final cue = cueField.message;
    if (cue == null) continue;
    final id = uuid(cue.message(1));
    final texts = <String>[];
    for (final actionField in cue.all(10)) {
      final base = actionField.message?.message(23)?.message(2)?.message(1);
      for (final elementField in base?.all(1) ?? const <ProtoField>[]) {
        final rtf = elementField.message?.message(1)?.message(13)?.field(5)?.bytes;
        if (rtf == null) continue;
        final text = tidyLyrics(rtfToText(_rtfSource(rtf)));
        if (text.isNotEmpty) texts.add(text);
      }
    }
    slideText[id] = texts.join('\n');
    cueOrder.add(id);
  }

  final groups = <_Group>[];
  for (final groupField in doc.all(12)) {
    final cueGroup = groupField.message;
    if (cueGroup == null) continue;
    final group = cueGroup.message(1);
    groups.add(
      _Group(uuid(group?.message(1)), group?.string(2) ?? '', [
        for (final cueId in cueGroup.all(2)) slideText[uuid(cueId.message)] ?? '',
      ]),
    );
  }
  // A document with slides and no groups: every slide in the order it was made.
  if (groups.isEmpty) groups.add(_Group('', '', [for (final id in cueOrder) slideText[id]!]));

  final selected = uuid(doc.message(10));
  List<String>? arrangement;
  for (final arrangementField in doc.all(11)) {
    final a = arrangementField.message;
    if (a == null || uuid(a.message(1)) != selected) continue;
    arrangement = [for (final g in a.all(3)) uuid(g.message)];
  }

  final ccli = doc.message(14);
  final number = ccli?.varint(6);
  return ImportedSong(
    title: nonEmpty(ccli?.string(3)) ?? nonEmpty(doc.string(3)) ?? name,
    author: nonEmpty(ccli?.string(1)) ?? nonEmpty(ccli?.string(2)),
    copyright: _copyright(ccli?.varint(5), ccli?.string(4)),
    ccliNumber: number != null && number > 0 ? '$number' : null,
    verses: _versesOf(groups, arrangement: arrangement),
    source: source,
    format: SongFormat.proPresenter7,
  );
}

// ── ProPresenter 6 (and 5) ──────────────────────────────────────────────────

/// Reads a ProPresenter 6 `.pro6`, 5 `.pro5` or 4 `.pro4` document, which are XML with
/// each slide's text inside as base64.
ImportedSong readProPresenter6(String xml, {required String source, required String name}) {
  final XmlElement root;
  try {
    root = XmlDocument.parse(xml).rootElement;
  } on XmlException {
    throw const FormatException('not a ProPresenter 6 document');
  }
  if (root.name.local != 'RVPresentationDocument') {
    throw const FormatException('not a ProPresenter 6 document');
  }

  String decode64(String value) {
    try {
      return _rtfSource(base64.decode(value.trim()));
    } on FormatException {
      return '';
    }
  }

  String textOf(XmlElement element) {
    // 6.x writes the plain text beside the RTF; 5.x only the RTF, as an
    // attribute rather than a child.
    for (final child in element.childElements) {
      if (child.getAttribute('rvXMLIvarName') == 'PlainText' && child.innerText.trim().isNotEmpty) {
        return decode64(child.innerText);
      }
    }
    for (final child in element.childElements) {
      if (child.getAttribute('rvXMLIvarName') == 'RTFData') {
        return rtfToText(decode64(child.innerText));
      }
    }
    final attribute = element.getAttribute('RTFData');
    return attribute == null ? '' : rtfToText(decode64(attribute));
  }

  String slideText(XmlElement slide) => [
    for (final text in slide.findAllElements('RVTextElement')) tidyLyrics(textOf(text)),
  ].where((t) => t.isNotEmpty).join('\n');

  final groups = [
    for (final group in root.findAllElements('RVSlideGrouping'))
      _Group(group.getAttribute('uuid') ?? '', group.getAttribute('name') ?? '', [
        for (final slide in group.findAllElements('RVDisplaySlide')) slideText(slide),
      ]),
  ];
  // ProPresenter 4 had no groups: the slides hang off the document itself.
  if (groups.isEmpty) {
    groups.add(
      _Group('', '', [
        for (final slide in root.findAllElements('RVDisplaySlide')) slideText(slide),
      ]),
    );
  }

  final selected = root.getAttribute('selectedArrangementID');
  List<String>? arrangement;
  for (final a in root.findAllElements('RVSongArrangement')) {
    if (a.getAttribute('uuid') != selected) continue;
    arrangement = [
      for (final id in a.descendantElements)
        if (id.name.local.contains('String')) id.innerText.trim(),
    ];
  }

  final number = int.tryParse(root.getAttribute('CCLISongNumber') ?? '');
  return ImportedSong(
    title: nonEmpty(root.getAttribute('CCLISongTitle')) ?? name,
    author:
        nonEmpty(root.getAttribute('CCLIAuthor')) ??
        nonEmpty(root.getAttribute('CCLIArtistCredits')) ??
        nonEmpty(root.getAttribute('author')) ??
        nonEmpty(root.getAttribute('artist')),
    copyright: _copyright(
      int.tryParse(root.getAttribute('CCLICopyrightYear') ?? ''),
      root.getAttribute('CCLIPublisher'),
    ),
    ccliNumber: number != null && number > 0 ? '$number' : null,
    verses: _versesOf(groups, arrangement: arrangement),
    source: source,
    format: SongFormat.proPresenter6,
  );
}
