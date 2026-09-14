import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';
import '../models/song.dart';
import '../song_import/song_files.dart';

class ParsedVerse {
  const ParsedVerse(this.content, this.type);
  final String content;
  final VerseType type;
}

class LyricImportResult {
  const LyricImportResult({
    required this.verses,
    this.title,
    this.author,
    this.copyright,
    this.ccliNumber,
  });
  final List<ParsedVerse> verses;
  final String? title;
  final String? author;
  final String? copyright;
  final String? ccliNumber;
}

class LyricImportService {
  /// Every file the song form can fill itself from.
  static const extensions = ['docx', 'pdf', ...songFileExtensions];

  Future<LyricImportResult> extract(String filePath) async {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.docx')) return _extractDocx(filePath);
    if (lower.endsWith('.pdf')) return _extractPdf(filePath);
    // Everything else is a song from another program, read the same way the
    // library import reads it.
    final result = readSongBytes(filePath, await File(filePath).readAsBytes());
    final song = result.song;
    if (song == null) {
      // Thrown as it is, so the form can say what is wrong in the operator's
      // language rather than in the one this was written in.
      throw result.failure!;
    }
    return LyricImportResult(
      verses: [for (final v in song.verses) ParsedVerse(v.content, v.type)],
      title: song.title,
      author: song.author,
      copyright: song.copyright,
      ccliNumber: song.ccliNumber,
    );
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
