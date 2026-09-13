import '../../models/song.dart';
import '../imported_song.dart';
import '../section_names.dart';

/// Whether [text] reads as ChordPro: it has at least one {directive}.
bool looksLikeChordPro(String text) => RegExp(
  r'^\s*\{\s*[a-z_]+\s*(:[^}]*)?\}\s*$',
  multiLine: true,
  caseSensitive: false,
).hasMatch(text);

/// Reads a ChordPro song: lyrics with chords in brackets, and {directives}.
ImportedSong readChordPro(String text, {required String source, required String name}) {
  String? title;
  String? author;
  String? copyright;
  String? ccli;
  var type = VerseType.verse;
  final verses = <ImportedVerse>[];
  final buffer = <String>[];

  // "{c: Chorus}" means two things in the files people share. Right before a
  // chorus's words it labels them; standing alone between paragraphs it means
  // "sing the chorus again here". Which one is only known from the next line.
  VerseType? pending;

  void flush() {
    final content = tidyLyrics(buffer.join('\n'));
    if (content.isNotEmpty) verses.add(ImportedVerse(type, content));
    buffer.clear();
  }

  void repeatPending() {
    final label = pending;
    pending = null;
    if (label == null) return;
    final earlier = verses.lastWhere(
      (v) => v.type == label,
      orElse: () => const ImportedVerse(VerseType.verse, ''),
    );
    if (earlier.content.isNotEmpty) verses.add(earlier);
    type = VerseType.verse;
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('#')) continue;

    final directive = RegExp(r'^\{\s*([a-zA-Z_]+)\s*(?::\s*(.*?))?\s*\}$').firstMatch(line);
    if (directive != null) {
      final key = directive.group(1)!.toLowerCase();
      final value = directive.group(2) ?? '';
      switch (key) {
        case 'title' || 't':
          title ??= nonEmpty(value);
        case 'artist' || 'author' || 'composer' || 'lyricist' || 'a':
          author ??= nonEmpty(value);
        case 'copyright':
          copyright ??= nonEmpty(value);
        case 'ccli':
          ccli ??= nonEmpty(value);
        case 'start_of_chorus' || 'soc':
          flush();
          type = VerseType.chorus;
        case 'start_of_bridge' || 'sob':
          flush();
          type = VerseType.bridge;
        case 'start_of_verse' || 'sov':
          flush();
          type = VerseType.verse;
        case 'end_of_chorus' || 'eoc' || 'end_of_bridge' || 'eob' || 'end_of_verse' || 'eov':
          flush();
          type = VerseType.verse;
        case 'comment' || 'c' || 'comment_italic' || 'ci' || 'comment_box' || 'cb':
          final label = sectionType(value);
          if (label != null) {
            flush();
            repeatPending();
            pending = label;
          }
        case 'chorus':
          // ChordPro 6: the chorus again, by name.
          flush();
          pending = VerseType.chorus;
          repeatPending();
      }
      continue;
    }

    // [Chorus] on its own line is a section; [G] on its own line is a chord.
    final bracket = RegExp(r'^\[([^\]]+)\]$').firstMatch(line);
    if (bracket != null) {
      final label = sectionType(bracket.group(1)!);
      if (label != null) {
        flush();
        type = label;
      }
      continue;
    }

    final lyric = line.replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (lyric.isEmpty) {
      if (line.isEmpty) {
        flush();
        repeatPending();
      }
      continue;
    }
    if (pending != null) {
      type = pending!;
      pending = null;
    }
    // A plain section label, the way many ChordPro files from the web carry
    // one ("Coro:" before the chorus).
    final label = sectionType(lyric);
    if (label != null && buffer.isEmpty) {
      type = label;
      continue;
    }
    buffer.add(lyric);
  }
  flush();
  repeatPending();

  return ImportedSong(
    title: title ?? name,
    author: author,
    copyright: copyright,
    ccliNumber: ccli,
    verses: verses,
    source: source,
    format: SongFormat.chordPro,
  );
}
