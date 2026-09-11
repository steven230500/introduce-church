import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';
import '../models/song.dart';

class ParsedVerse {
  const ParsedVerse(this.content, this.type);
  final String content;
  final VerseType type;
}

class LyricImportResult {
  const LyricImportResult({required this.verses, this.title, this.author});
  final List<ParsedVerse> verses;
  final String? title;
  final String? author;
}

class LyricImportService {
  Future<LyricImportResult> extract(String filePath) async {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.docx')) return _extractDocx(filePath);
    if (lower.endsWith('.pdf')) return _extractPdf(filePath);
    if (lower.endsWith('.xml')) return _extractOpenLyrics(filePath);
    if (lower.endsWith('.cho') || lower.endsWith('.chordpro') || lower.endsWith('.chopro')) {
      return _extractChordPro(filePath);
    }
    throw UnsupportedError('Formato no soportado. Usa .docx, .pdf, .xml o .cho');
  }

  // ── DOCX ──────────────────────────────────────────────────────────────────

  LyricImportResult _extractDocx(String path) {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docEntry = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw FormatException('No es un archivo .docx válido'),
    );
    final xmlStr = String.fromCharCodes(docEntry.content as List<int>);
    final doc = XmlDocument.parse(xmlStr);

    final lines = <String>[];
    for (final para in doc.findAllElements('w:p')) {
      final buf = StringBuffer();
      for (final t in para.findAllElements('w:t')) {
        buf.write(t.innerText);
      }
      lines.add(buf.toString());
    }
    return LyricImportResult(verses: _segmentLines(lines));
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<LyricImportResult> _extractPdf(String path) async {
    final doc = await PdfDocument.openFile(path);
    final buf = StringBuffer();
    for (final page in doc.pages) {
      final textPage = await page.loadText();
      buf.writeln(textPage.fullText);
    }
    doc.dispose();
    return LyricImportResult(verses: _segmentLines(buf.toString().split('\n')));
  }

  // ── OpenLyrics XML ────────────────────────────────────────────────────────

  LyricImportResult _extractOpenLyrics(String path) {
    final content = File(path).readAsStringSync();
    final doc = XmlDocument.parse(content);

    String? title;
    String? author;

    final titleEl = doc.findAllElements('title').firstOrNull;
    if (titleEl != null) title = titleEl.innerText.trim();

    final authorEl = doc.findAllElements('author').firstOrNull;
    if (authorEl != null) author = authorEl.innerText.trim();

    final verses = <ParsedVerse>[];
    for (final verseEl in doc.findAllElements('verse')) {
      final name = verseEl.getAttribute('name') ?? '';
      final type = _openLyricsVerseType(name);

      final buf = StringBuffer();
      for (final lines in verseEl.findAllElements('lines')) {
        for (final node in lines.children) {
          if (node is XmlElement && node.name.local == 'br') {
            buf.writeln();
          } else if (node is XmlText) {
            buf.write(node.value);
          }
        }
      }
      final text = buf.toString().trim();
      if (text.isNotEmpty) verses.add(ParsedVerse(text, type));
    }

    return LyricImportResult(verses: verses, title: title, author: author);
  }

  static VerseType _openLyricsVerseType(String name) {
    final n = name.toLowerCase();
    if (n.startsWith('c')) return VerseType.chorus;
    if (n.startsWith('b')) return VerseType.bridge;
    if (n.startsWith('p')) return VerseType.preCHORUS;
    if (n == 'i' || n.startsWith('intro')) return VerseType.intro;
    if (n == 'o' || n.startsWith('outro')) return VerseType.outro;
    if (n == 'e' || n.startsWith('tag')) return VerseType.tag;
    return VerseType.verse;
  }

  // ── ChordPro ──────────────────────────────────────────────────────────────

  LyricImportResult _extractChordPro(String path) {
    final lines = File(path).readAsLinesSync();

    String? title;
    String? author;
    VerseType currentType = VerseType.verse;
    final verses = <ParsedVerse>[];
    final buffer = <String>[];

    void flushBuffer() {
      final text = buffer.join('\n').trim();
      if (text.isNotEmpty) verses.add(ParsedVerse(text, currentType));
      buffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();

      // Directives: {title: ...}, {artist: ...}, {key: ...}
      if (line.startsWith('{') && line.endsWith('}')) {
        final inner = line.substring(1, line.length - 1);
        final colon = inner.indexOf(':');
        if (colon != -1) {
          final key = inner.substring(0, colon).trim().toLowerCase();
          final val = inner.substring(colon + 1).trim();
          if (key == 'title' || key == 't') title ??= val;
          if (key == 'artist' || key == 'author' || key == 'a') author ??= val;
        }
        continue;
      }

      // Section markers: [Verse], [Chorus], [Bridge], etc.
      if (line.startsWith('[') && line.endsWith(']')) {
        flushBuffer();
        currentType = _chordProSectionType(line.substring(1, line.length - 1));
        continue;
      }

      // Skip pure chord lines: lines where all non-space content is inside [...]
      if (_isPureChordLine(line)) continue;

      // Strip inline chords [G], [Am], [C/E], etc. from lyric lines
      final lyric = line.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();

      // Empty line = section break
      if (lyric.isEmpty) {
        flushBuffer();
      } else {
        buffer.add(lyric);
      }
    }
    flushBuffer();

    return LyricImportResult(verses: verses, title: title, author: author);
  }

  static VerseType _chordProSectionType(String section) {
    final s = section.toLowerCase();
    if (s.contains('chorus') || s.contains('coro')) return VerseType.chorus;
    if (s.contains('bridge') || s.contains('puente')) return VerseType.bridge;
    if (s.contains('pre')) return VerseType.preCHORUS;
    if (s.contains('intro')) return VerseType.intro;
    if (s.contains('outro')) return VerseType.outro;
    if (s.contains('tag')) return VerseType.tag;
    return VerseType.verse;
  }

  static bool _isPureChordLine(String line) {
    if (line.isEmpty) return false;
    final stripped = line.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    return stripped.isEmpty;
  }

  // ── Segmentation (for docx/pdf) ───────────────────────────────────────────

  static List<ParsedVerse> segmentLines(List<String> lines) => _segmentLines(lines);

  static List<ParsedVerse> _segmentLines(List<String> lines) {
    final segments = <ParsedVerse>[];
    final buffer = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (buffer.isNotEmpty) {
          segments.add(ParsedVerse(buffer.join('\n'), VerseType.verse));
          buffer.clear();
        }
      } else {
        buffer.add(trimmed);
      }
    }
    if (buffer.isNotEmpty) {
      segments.add(ParsedVerse(buffer.join('\n'), VerseType.verse));
    }
    return segments;
  }
}
