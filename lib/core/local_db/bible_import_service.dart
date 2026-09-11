import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_database.dart';
import '../utils/app_logger.dart';

class BibleImportService {
  final AppDatabase _db;

  BibleImportService(this._db);

  Future<void> ensureBundledBiblesImported() async {
    final alreadyImported = await _db.isVersionDownloaded('RVR1960');
    if (alreadyImported) {
      final valid = await _isDataValid('RVR1960');
      if (valid) {
        appLogger.d('BibleImportService: RVR1960 already imported');
        return;
      }
      appLogger.w('BibleImportService: RVR1960 data corrupted, re-importing...');
      await _db.deleteVersion('RVR1960');
    }

    appLogger.i('BibleImportService: importing RVR1960...');
    await _importFromAsset(
      assetPath: 'assets/bibles/rvr1960.json',
      code: 'RVR1960',
      name: 'Reina-Valera 1960',
      isBundled: true,
    );
    appLogger.i('BibleImportService: RVR1960 import complete');
  }

  Future<bool> _isDataValid(String versionCode) async {
    try {
      final chapter = await _db.getChapter(versionCode, 0, 1);
      if (chapter == null) return false;
      final decoded = jsonDecode(chapter.versesJson);
      return decoded is List && decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _importFromAsset({
    required String assetPath,
    required String code,
    required String name,
    required bool isBundled,
  }) async {
    appLogger.i('BibleImportService: loading $assetPath from bundle...');
    final jsonString = await rootBundle.loadString(assetPath);

    appLogger.i('BibleImportService: parsing JSON...');
    final books = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    appLogger.i('BibleImportService: ${books.length} books found, inserting into SQLite...');

    for (var i = 0; i < books.length; i++) {
      final book = books[i];
      appLogger.d('BibleImportService: [${i + 1}/${books.length}] ${book['name']}');
    }

    await _db.insertVersion(code: code, name: name, isBundled: isBundled, books: books);
  }
}
