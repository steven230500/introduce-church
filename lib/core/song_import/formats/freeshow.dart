import 'dart:convert';

import '../imported_song.dart';
import '../section_names.dart';

/// Reads a FreeShow `.show` file.
///
/// FreeShow writes a JSON pair: an id and the show. The show holds its slides
/// in a map, keyed by id and in no particular order, and the order lives in a
/// layout. A church that arranged the song - verse, chorus, verse - said so in
/// that layout, so it is what decides the slides here.
///
/// A slide's text sits in items, and an item marked as decoration is the
/// furniture FreeShow draws around it: the reference and the version under a
/// Bible passage, a logo in a corner. Those are not lyrics and are left out.
ImportedSong readFreeShow(String json, {required String source, required String name}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const FormatException('not a FreeShow file');
  }
  if (decoded is! List || decoded.length < 2 || decoded[1] is! Map) {
    throw const FormatException('not a FreeShow file');
  }

  final show = Map<String, dynamic>.from(decoded[1] as Map);
  final slides = show['slides'];
  if (slides is! Map) throw const FormatException('a FreeShow file with no slides');

  final meta = show['meta'] is Map ? Map<String, dynamic>.from(show['meta'] as Map) : const {};

  final verses = <ImportedVerse>[];
  for (final id in _order(show, slides)) {
    final slide = slides[id];
    if (slide is! Map) continue;
    final content = _slideText(slide);
    if (content.isEmpty) continue;
    verses.add(ImportedVerse(sectionTypeOr(slide['group'] as String? ?? ''), content));
  }

  return ImportedSong(
    title: _text(show['name']) ?? name,
    author: _text(meta['artist']) ?? _text(meta['author']),
    copyright: _text(meta['copyright']),
    ccliNumber: _text(meta['CCLI']) ?? _text(meta['ccli']),
    verses: verses,
    source: source,
    format: SongFormat.freeShow,
  );
}

/// What a FreeShow file says it is: songs carry the id of a category the
/// church made, while passages and slide decks name themselves.
String freeShowCategory(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List && decoded.length > 1 && decoded[1] is Map) {
      return (decoded[1] as Map)['category'] as String? ?? '';
    }
  } on FormatException {
    // Not a FreeShow file at all; the reader says so.
  }
  return '';
}

bool looksLikeFreeShow(String text) {
  final head = text.trimLeft();
  return head.startsWith('[') && head.contains('"slides"');
}

/// The slides in the order the church arranged them, falling back to the order
/// the file happens to list them in when there is no layout.
List<String> _order(Map<String, dynamic> show, Map<dynamic, dynamic> slides) {
  final layouts = show['layouts'];
  if (layouts is Map && layouts.isNotEmpty) {
    final settings = show['settings'];
    final active = settings is Map ? settings['activeLayout'] as String? : null;
    final layout = layouts[active] ?? layouts.values.first;
    if (layout is Map && layout['slides'] is List) {
      final ordered = [
        for (final entry in layout['slides'] as List)
          if (entry is Map && entry['id'] is String) entry['id'] as String,
      ];
      if (ordered.isNotEmpty) return ordered;
    }
  }
  return slides.keys.whereType<String>().toList();
}

String _slideText(Map<dynamic, dynamic> slide) {
  final items = slide['items'];
  if (items is! List) return '';
  final lines = <String>[];
  for (final item in items) {
    if (item is! Map || item['decoration'] == true) continue;
    final itemLines = item['lines'];
    if (itemLines is! List) continue;
    for (final line in itemLines) {
      if (line is! Map || line['text'] is! List) continue;
      final text = [
        for (final part in line['text'] as List)
          if (part is Map && part['value'] is String) part['value'] as String,
      ].join();
      if (text.trim().isNotEmpty) lines.add(text.trim());
    }
  }
  return lines.join('\n').trim();
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
