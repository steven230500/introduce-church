import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_database.dart';
import '../utils/app_logger.dart';

/// The Bible that comes with the app: the Reina-Valera 1909, in the public
/// domain, so any church may project it and Introduce may hand it out.
const bundledBibleCode = 'RV1909';
const bundledBibleName = 'Reina-Valera 1909';

/// What builds up to 1.1.0 called the same text. It was never the 1960
/// revision - "crió", "á su Hijo", "reformaos" are the 1909 - so a church saw
/// "RVR1960" under words its Bibles do not have.
const _mislabelledCode = 'RVR1960';

class BibleImportService {
  final AppDatabase _db;

  BibleImportService(this._db);

  Future<void> ensureBundledBiblesImported() async {
    await retireMislabelled();

    final alreadyImported = await _db.isVersionDownloaded(bundledBibleCode);
    if (alreadyImported) {
      final valid = await _isDataValid(bundledBibleCode);
      if (valid) {
        appLogger.d('BibleImportService: $bundledBibleCode already imported');
        return;
      }
      appLogger.w('BibleImportService: $bundledBibleCode data corrupted, re-importing...');
      await _db.deleteVersion(bundledBibleCode);
    }

    appLogger.i('BibleImportService: importing $bundledBibleCode...');
    await _importFromAsset(
      assetPath: 'assets/bibles/rv1909.json',
      code: bundledBibleCode,
      name: bundledBibleName,
      isBundled: true,
    );
    appLogger.i('BibleImportService: $bundledBibleCode import complete');
  }

  /// Gives the included Bible its real name on a computer that has it under
  /// the old one. Renamed, not imported again: the text is the same.
  Future<void> retireMislabelled() async {
    final versions = await _db.getAllVersions();
    final old = versions.where((v) => v.code == _mislabelledCode && v.isBundled).firstOrNull;
    if (old == null) return;
    if (versions.any((v) => v.code == bundledBibleCode)) {
      await _db.deleteVersion(_mislabelledCode);
    } else {
      await _db.renameVersion(_mislabelledCode, to: bundledBibleCode, name: bundledBibleName);
    }
    appLogger.i('BibleImportService: $_mislabelledCode renamed to $bundledBibleCode');
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
    final books = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    appLogger.i('BibleImportService: ${books.length} books found, inserting into SQLite...');
    await _db.insertVersion(code: code, name: name, isBundled: isBundled, books: books);
  }
}
