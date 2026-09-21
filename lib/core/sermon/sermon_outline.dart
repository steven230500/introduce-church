/// Reading a sermon outline the way a pastor sends it.
///
/// The outline arrives on WhatsApp on Saturday night: a title, a point per
/// line, numbered or bulleted or in bold, and the passages named along the
/// way. Typing it again into the sermon's fields is where the typos come
/// from; this reads it as it came.
library;

import '../local_db/bible_reference.dart';

/// What an outline turns into: the sermon's title slide, its points, and the
/// passages it names, in the order it names them.
class SermonOutline {
  const SermonOutline({required this.title, required this.points, required this.passages});

  final String title;
  final List<String> points;
  final List<BibleReference> passages;

  bool get isEmpty => title.isEmpty && points.isEmpty && passages.isEmpty;
}

/// Reads [text] as an outline.
///
/// The title is the line that says so ("Tema: La fe que vence") or else the
/// first line. Every other line is a point, without its number or bullet,
/// except a line that only names a passage ("Texto: Hebreos 11:1-6",
/// "(Ro 8:28)"): that is the passage, not something to put on the screen as a
/// point. A point that names one keeps it in its words, and the passage is
/// taken too.
SermonOutline readSermonOutline(String text) {
  final lines = <({_Label? label, String text})>[];
  final passages = <BibleReference>[];
  final seen = <String>{};

  for (final raw in text.split(RegExp(r'\r\n?|\n'))) {
    final (label, line) = _labelled(_clean(raw));
    if (line.isEmpty) continue;
    final found = findBibleReferences(line);
    for (final reference in found) {
      if (seen.add('${reference.reference}')) passages.add(reference.reference);
    }
    if (label == _Label.passage || _onlyReferences(line, found)) continue;
    lines.add((label: label, text: line));
  }

  final titled = lines.where((line) => line.label == _Label.title).firstOrNull;
  final title = titled ?? lines.firstOrNull;
  return SermonOutline(
    title: title?.text ?? '',
    points: [
      for (final line in lines)
        if (!identical(line, title)) line.text,
    ],
    passages: passages,
  );
}

enum _Label { title, passage }

/// What a line says it is, and what is left of it after saying so.
(_Label?, String) _labelled(String line) {
  final match = _labelPattern.firstMatch(line);
  if (match == null) return (null, line);
  final word = _plain(match.group(1)!);
  final rest = line.substring(match.end).trim();
  if (_titleLabels.contains(word)) return (_Label.title, rest);
  if (_passageLabels.contains(word)) return (_Label.passage, rest);
  // "Puntos:", "Bosquejo:", "Introducción:" on a line of their own head
  // what follows; they are not points themselves.
  if (rest.isEmpty) return (null, '');
  return (null, line);
}

final _labelPattern = RegExp(r'^([\p{L} ]{2,24}?)\s*:\s*', unicode: true);

const _titleLabels = {
  'tema', 'titulo', 'mensaje', 'predica', 'sermon', 'predicacion', //
  'title', 'topic', 'theme', 'message',
};

const _passageLabels = {
  'texto', 'textos', 'texto base', 'texto biblico', 'base biblica', 'lectura', //
  'lectura biblica', 'cita', 'citas', 'versiculo', 'versiculos', 'pasaje', 'pasajes',
  'text', 'texts', 'reading', 'scripture', 'scriptures', 'passage', 'verse', 'verses',
};

/// The line without WhatsApp's bold and italics, and without the number,
/// letter, bullet or emoji it starts with.
String _clean(String line) {
  var clean = line.replaceAll(RegExp(r'[*_~]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final marker in _markers) {
    clean = clean.replaceFirst(marker, '');
  }
  return clean.trim();
}

final _markers = [
  // What WhatsApp puts before a message copied with others:
  // "[21/9 9:40 p. m.] Pastor Andrés: "
  RegExp(r'^\[[^\]]{4,40}\]\s*[^:]{1,40}:\s*'),
  // Bullets, dashes, arrows, emoji and the keycap digits WhatsApp uses: 1\uFE0F\u20E3
  RegExp(r'^[^\p{L}\p{N}(¿¡"«“]+', unicode: true),
  RegExp(r'^\d{1,2}\uFE0F?\u20E3\s*', unicode: true),
  // "Punto 1:", "Punto uno -"
  RegExp(r'^punto\s+\S+\s*[:.\-–—)]\s*', caseSensitive: false),
  // "1.", "2)", "(3)", "IV.", "b)"
  RegExp(r'^\(?\d{1,2}[.)\-]\s*'),
  RegExp(r'^\(?[ivxlc]{1,6}[.)]\s+', caseSensitive: false),
  RegExp(r'^\(?[a-z][.)]\s+', caseSensitive: false),
  RegExp(r'^[^\p{L}\p{N}(¿¡"«“]+', unicode: true),
];

/// Whether [line] is nothing but the passages [found] in it, give or take
/// brackets, punctuation and an "and".
bool _onlyReferences(String line, List<FoundReference> found) {
  if (found.isEmpty) return false;
  var rest = line;
  for (final reference in found.reversed) {
    rest = rest.replaceRange(reference.start, reference.end, ' ');
  }
  final words = rest
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.isNotEmpty && !_joiners.contains(_plain(word)));
  return words.isEmpty;
}

const _joiners = {'y', 'e', 'and', 'cf', 'ver', 'vea', 'vv', 'v', 'vs'};

String _plain(String value) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  return value.toLowerCase().trim().split('').map((c) => accents[c] ?? c).join();
}
