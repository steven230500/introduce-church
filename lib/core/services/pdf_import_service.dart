import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../utils/app_logger.dart';

/// Turns a PDF into one picture per page.
///
/// The church's announcements arrive as a PDF someone made in Canva or Word,
/// and what has to reach the screen is the page exactly as it was designed -
/// not the text pulled out of it. Rendering happens inside the app, so unlike
/// the PowerPoint path this needs neither LibreOffice nor poppler on the
/// machine: the operator opens the file and it works.
class PdfImportService {
  const PdfImportService();

  /// How wide each page is rendered. A projector is rarely wider than this, and
  /// a page rendered larger only costs disk and memory.
  static const pageWidth = 1920.0;

  /// Renders every page of [filePath] and returns the images in page order.
  ///
  /// Pages already rendered for this file are reused: re-importing the same
  /// announcements does not redraw them.
  Future<List<String>> renderPages(String filePath) async {
    final document = await PdfDocument.openFile(filePath);
    try {
      final support = await getApplicationSupportDirectory();
      final name = p.basenameWithoutExtension(filePath);
      final folder = Directory(p.join(support.path, 'pdf_images', _folderName(filePath, name)));
      if (!await folder.exists()) await folder.create(recursive: true);

      final paths = <String>[];
      for (final page in document.pages) {
        final file = File(p.join(folder.path, 'page-${_padded(page.pageNumber)}.png'));
        if (!await file.exists()) {
          final bytes = await _renderPage(page);
          if (bytes == null) continue;
          await file.writeAsBytes(bytes);
        }
        paths.add(file.path);
      }
      appLogger.d('PdfImportService.renderPages | ${paths.length} páginas de $name');
      return paths;
    } finally {
      document.dispose();
    }
  }

  Future<Uint8List?> _renderPage(PdfPage page) async {
    final scale = pageWidth / page.width;
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      // A PDF page is usually white with no background of its own; without
      // this it comes out transparent and the words vanish on the projector.
      backgroundColor: const ui.Color(0xFFFFFFFF),
    );
    if (rendered == null) return null;
    ui.Image? image;
    try {
      image = await rendered.createImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image?.dispose();
      rendered.dispose();
    }
  }

  /// A folder per file, told apart by size and date: two different PDFs named
  /// "anuncios.pdf" must not land on each other's pages.
  String _folderName(String filePath, String name) {
    final stat = File(filePath).statSync();
    return '$name-${stat.size}-${stat.modified.millisecondsSinceEpoch}';
  }

  static String _padded(int page) => page.toString().padLeft(3, '0');
}
