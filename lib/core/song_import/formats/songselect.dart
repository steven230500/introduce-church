import '../../models/song.dart';
import '../imported_song.dart';
import '../section_names.dart';

/// Whether [text] is a SongSelect `.usr` file.
bool looksLikeSongSelectUsr(String text) =>
    RegExp(r'^\s*\[File\]', multiLine: true).hasMatch(text) &&
    RegExp(r'^\s*Words\s*=', multiLine: true).hasMatch(text);

/// Whether [text] is lyrics downloaded from SongSelect as text: its footer
/// names the song's CCLI number.
bool looksLikeSongSelectText(String text) => _songNumber.hasMatch(text);

final _songNumber = RegExp(r'^\s*CCLI[^\n#]*#\s*(\d+)', multiLine: true, caseSensitive: false);

/// Reads a SongSelect `.usr` file.
ImportedSong readSongSelectUsr(String text, {required String source, required String name}) {
  final values = <String, String>{};
  String? number;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    final header = RegExp(r'^\[S\s+A?(\d+)\]$').firstMatch(line);
    if (header != null) number = header.group(1);
    final eq = line.indexOf('=');
    if (eq > 0) values[line.substring(0, eq).trim().toLowerCase()] = line.substring(eq + 1);
  }
  final words = values['words'];
  if (words == null) throw const FormatException('not a SongSelect file');

  final fields = (values['fields'] ?? '').split('/t');
  final blocks = words.split('/t');
  final verses = <ImportedVerse>[];
  for (final (index, block) in blocks.indexed) {
    final content = tidyLyrics(block.split('/n').join('\n'));
    if (content.isEmpty) continue;
    final label = index < fields.length ? fields[index] : '';
    verses.add(ImportedVerse(sectionTypeOr(label), content));
  }

  return ImportedSong(
    title: nonEmpty(values['title']) ?? name,
    author: _people(values['author']),
    copyright: nonEmpty(values['copyright']?.split('|').map((p) => p.trim()).join('; ')),
    ccliNumber: number ?? nonEmpty(values['ccli']),
    verses: verses,
    source: source,
    format: SongFormat.songSelect,
  );
}

/// Reads lyrics downloaded from SongSelect as text.
///
/// ```
/// Grande Es Tu Fidelidad
///
/// Verse 1
/// Oh Dios eterno tu misericordia
/// ...
///
/// CCLI Song # 18723
/// Thomas O. Chisholm | William M. Runyan
/// © 1923. Ren. 1951 Hope Publishing Company
/// For use solely with the SongSelect® Terms of Use. All rights reserved.
/// CCLI License # 12345
/// ```
ImportedSong readSongSelectText(String text, {required String source, required String name}) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
  final numberAt = lines.indexWhere((l) => _songNumber.hasMatch(l));
  // Since 2023 the authors sit on the line right above the number; before,
  // right below it. Lyrics always end with a blank line before the footer, so
  // a line with no gap above the number is the authors.
  final authorsAbove = numberAt > 0 && lines[numberAt - 1].isNotEmpty;
  final footer = numberAt == -1 ? -1 : (authorsAbove ? numberAt - 1 : numberAt);
  final body = footer == -1 ? lines : lines.sublist(0, footer);
  final tail = footer == -1 ? const <String>[] : lines.sublist(numberAt);

  final titleAt = body.indexWhere((l) => l.isNotEmpty);
  final title = titleAt == -1 ? name : body[titleAt];

  String? author = authorsAbove ? _people(lines[numberAt - 1]) : null;
  String? copyright;
  for (final line in tail.skip(1)) {
    final lower = line.toLowerCase();
    if (line.isEmpty ||
        lower.contains('ccli') ||
        lower.startsWith('for use solely') ||
        lower.startsWith('para uso exclusivo') ||
        lower.contains('all rights reserved') ||
        lower.contains('todos los derechos')) {
      continue;
    }
    if (line.startsWith('©') || line.toLowerCase().startsWith('copyright')) {
      copyright ??= line;
    } else {
      author ??= _people(line);
    }
  }

  return ImportedSong(
    title: title,
    author: author,
    copyright: copyright,
    ccliNumber: numberAt == -1 ? null : _songNumber.firstMatch(lines[numberAt])!.group(1),
    verses: readSections(body.skip(titleAt + 1)),
    source: source,
    format: SongFormat.songSelect,
  );
}

/// Lyrics laid out as paragraphs, some of them preceded by a label on a line
/// of its own. A label sets the kind of every paragraph after it until the
/// next one.
List<ImportedVerse> readSections(Iterable<String> lines) {
  final verses = <ImportedVerse>[];
  var type = VerseType.verse;
  final buffer = <String>[];
  var afterBreak = true;

  void flush() {
    final content = tidyLyrics(buffer.join('\n'));
    if (content.isNotEmpty) verses.add(ImportedVerse(type, content));
    buffer.clear();
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
      afterBreak = true;
      continue;
    }
    final label = sectionType(trimmed);
    if (label != null && (afterBreak || buffer.isEmpty)) {
      flush();
      type = label;
      afterBreak = false;
      continue;
    }
    buffer.add(trimmed);
    afterBreak = false;
  }
  flush();
  return verses;
}

String? _people(String? value) =>
    nonEmpty(value?.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).join(', '));
