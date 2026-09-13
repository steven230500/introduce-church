import '../models/song.dart';

/// Reads a section label - "Verse 1", "Coro", "Pre-Chorus", "Puente 2" - as
/// the kind of section it is, or null when the label is not one.
///
/// Every program names its sections in the operator's language, and churches
/// that sing in Spanish often keep English labels from the file they started
/// from, so both are read, and Portuguese, which the same files often carry.
VerseType? sectionType(String label) {
  final words = _fold(
    label,
  ).replaceAll(RegExp(r'[\[\]():#.]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (words.isEmpty) return null;
  final match = _pattern.firstMatch(words);
  if (match == null) return null;
  final name = match.group(1)!;
  for (final entry in _names.entries) {
    if (entry.value.contains(name)) return entry.key;
  }
  return null;
}

/// Like [sectionType], but anything that is not a known label is a verse.
///
/// For the programs where every group has a name the operator made up -
/// "Intro guitarra", "Final lento" - and the slides still have to be something.
VerseType sectionTypeOr(String label) => sectionType(label) ?? _loose(label) ?? VerseType.verse;

/// A label that starts with a known word even though more follows it.
VerseType? _loose(String label) {
  final first = _fold(label).split(RegExp(r'[\s\d\-_:]+')).where((w) => w.isNotEmpty).firstOrNull;
  if (first == null) return null;
  for (final entry in _names.entries) {
    if (entry.value.contains(first)) return entry.key;
  }
  return null;
}

const _names = {
  VerseType.verse: {'verse', 'verso', 'estrofa', 'stanza', 'strophe', 'v', 'vs', 'estrofe'},
  VerseType.chorus: {'chorus', 'coro', 'refrain', 'estribillo', 'refrao', 'c', 'ch', 'cor'},
  VerseType.preCHORUS: {
    'pre-chorus',
    'prechorus',
    'pre chorus',
    'pre-coro',
    'precoro',
    'pre coro',
    'pre-refrao',
    'pre',
    'p',
  },
  VerseType.bridge: {'bridge', 'puente', 'ponte', 'b'},
  VerseType.tag: {'tag', 'coda', 'vamp', 'final', 'finale'},
  VerseType.intro: {'intro', 'introduccion', 'introducao', 'i'},
  VerseType.outro: {'outro', 'ending', 'end', 'salida', 'e'},
};

final _pattern = RegExp(
  '^(${(_names.values.expand((s) => s).toList()..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|')})'
  r'(?:\s*\d+[a-z]?)?(?:\s*x\s*\d+)?$',
);

/// Lower case with the accents taken off, so "Introducción" and "introduccion"
/// are the same word.
String _fold(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i == -1 ? ch : to[i]);
  }
  return out.toString();
}
