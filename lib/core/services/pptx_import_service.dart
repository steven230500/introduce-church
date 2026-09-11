import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

List<String> get _libreofficeCandidates => Platform.isWindows
    ? [
        r'C:\Program Files\LibreOffice\program\soffice.exe',
        r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
      ]
    : [
        '/Applications/LibreOffice.app/Contents/MacOS/soffice',
        '/usr/local/bin/soffice',
        '/usr/bin/soffice',
      ];

List<String> get _pdftoppmCandidates => Platform.isWindows
    ? [
        r'C:\Program Files\poppler\Library\bin\pdftoppm.exe',
        r'C:\Program Files (x86)\poppler\bin\pdftoppm.exe',
      ]
    : ['/opt/homebrew/bin/pdftoppm', '/usr/local/bin/pdftoppm', '/usr/bin/pdftoppm'];

String get _libreofficeInstallHint => Platform.isWindows
    ? 'Descárgalo en https://www.libreoffice.org'
    : 'Instálalo en /Applications/LibreOffice.app';

String get _pdftoppmInstallHint => Platform.isWindows
    ? 'Descarga poppler para Windows: https://github.com/oschwartz10612/poppler-windows/releases'
    : 'Instala poppler: brew install poppler';

class PptxImportService {
  /// Returns slide texts in order. Empty slides are skipped.
  Future<List<String>> extractSlides(String filePath) async {
    try {
      debugPrint('[PPTX] reading file: $filePath');
      final bytes = await File(filePath).readAsBytes();
      debugPrint('[PPTX] file size: ${bytes.length} bytes');

      final archive = ZipDecoder().decodeBytes(bytes);
      debugPrint('[PPTX] archive entries: ${archive.files.map((f) => f.name).toList()}');

      final slideFiles =
          archive.files
              .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name) && f.isFile)
              .toList()
            ..sort((a, b) => _slideNum(a.name).compareTo(_slideNum(b.name)));

      debugPrint('[PPTX] matched slide files: ${slideFiles.map((f) => f.name).toList()}');

      final result = <String>[];
      for (final file in slideFiles) {
        final raw = file.content;
        if (raw == null) {
          debugPrint('[PPTX] ${file.name}: content is null, skipping');
          continue;
        }
        final slideBytes = raw is List<int> ? raw : List<int>.from(raw as Iterable);
        final xmlStr = utf8.decode(slideBytes);
        final text = _extractText(xmlStr);
        debugPrint(
          '[PPTX] ${file.name}: extracted ${text.split('\n').length} lines → "${text.substring(0, text.length.clamp(0, 60))}"',
        );
        if (text.isNotEmpty) result.add(text);
      }
      debugPrint('[PPTX] total slides extracted: ${result.length}');
      return result;
    } catch (e, st) {
      debugPrint('[PPTX] ERROR: $e\n$st');
      return [];
    }
  }

  /// Converts PPTX → PDF (LibreOffice) → PNG per page (pdftoppm).
  /// Returns list of absolute image paths saved to app support directory.
  /// Throws if LibreOffice or pdftoppm are not found.
  Future<List<String>> extractSlidesAsImages(String filePath) async {
    final loPath = await _findExecutable(_libreofficeCandidates);
    if (loPath == null) {
      throw Exception('LibreOffice no encontrado. $_libreofficeInstallHint');
    }

    final ppmPath = await _findExecutable(_pdftoppmCandidates);
    if (ppmPath == null) {
      throw Exception('pdftoppm no encontrado. $_pdftoppmInstallHint');
    }

    final tempDir = await getTemporaryDirectory();
    final appSupport = await getApplicationSupportDirectory();
    final pptxName = p.basenameWithoutExtension(filePath);
    final imgDir = Directory('${appSupport.path}/pptx_images/$pptxName');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);

    // Step 1: PPTX → PDF
    debugPrint('[PPTX-IMG] LibreOffice: "$pptxName" → PDF...');
    final loResult = await Process.run(loPath, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      tempDir.path,
      filePath,
    ]);
    debugPrint('[PPTX-IMG] LO stdout: ${loResult.stdout}');
    if (loResult.exitCode != 0) {
      throw Exception('LibreOffice error (${loResult.exitCode}): ${loResult.stderr}');
    }
    final pdfPath = '${tempDir.path}/$pptxName.pdf';
    if (!await File(pdfPath).exists()) {
      throw Exception('PDF no generado: $pdfPath');
    }

    // Step 2: PDF → PNG per page via pdftoppm
    final outPrefix = '${imgDir.path}/slide';
    debugPrint('[PPTX-IMG] pdftoppm: PDF → PNGs...');
    final ppmResult = await Process.run(ppmPath, ['-png', '-r', '150', pdfPath, outPrefix]);
    debugPrint('[PPTX-IMG] ppm stdout: ${ppmResult.stdout}');
    if (ppmResult.exitCode != 0) {
      throw Exception('pdftoppm error (${ppmResult.exitCode}): ${ppmResult.stderr}');
    }

    // Collect output files sorted by slide number
    final pngs = imgDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final imagePaths = pngs.map((f) => f.path).toList();
    debugPrint('[PPTX-IMG] Total imágenes: ${imagePaths.length}');
    return imagePaths;
  }

  Future<String?> _findExecutable(List<String> candidates) async {
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  int _slideNum(String name) {
    final m = RegExp(r'slide(\d+)\.xml$').firstMatch(name);
    return int.tryParse(m?.group(1) ?? '0') ?? 0;
  }

  String _extractText(String xmlStr) {
    try {
      final doc = XmlDocument.parse(xmlStr);
      final lines = <String>[];

      for (final para in doc.findAllElements('a:p')) {
        final buf = StringBuffer();
        for (final run in para.findAllElements('a:r')) {
          for (final t in run.findAllElements('a:t')) {
            buf.write(t.innerText);
          }
        }
        final line = buf.toString().trim();
        if (line.isNotEmpty) lines.add(line);
      }

      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }
}
