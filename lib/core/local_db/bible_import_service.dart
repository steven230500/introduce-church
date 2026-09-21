import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_database.dart';
import '../utils/app_logger.dart';

/// The Bible that comes with the app: the Reina-Valera 1909, in the public
/// domain, so any church may project it and Introduce may hand it out.
const bundledBibleCode = 'RV1909';
const bundledBibleName = 'Reina-Valera 1909';

/// The English one, for the bilingual churches: the World English Bible, in
/// the public domain, the edition that reads "the LORD".
const bundledEnglishCode = 'WEB';
const bundledEnglishName = 'World English Bible';

/// Every Bible the app carries: its code, name, file and language.
const _bundled = [
  (
    code: bundledBibleCode,
    name: bundledBibleName,
    asset: 'assets/bibles/rv1909.json',
    language: 'es',
  ),
  (
    code: bundledEnglishCode,
    name: bundledEnglishName,
    asset: 'assets/bibles/web.json',
    language: 'en',
  ),
];

/// What builds up to 1.1.0 called the same text. It was never the 1960
/// revision - "crió", "á su Hijo", "reformaos" are the 1909 - so a church saw
/// "RVR1960" under words its Bibles do not have.
const _mislabelledCode = 'RVR1960';

class BibleImportService {
  final AppDatabase _db;

  BibleImportService(this._db);

  Future<void> ensureBundledBiblesImported() async {
    await retireMislabelled();

    for (final bible in _bundled) {
      if (await _db.isVersionDownloaded(bible.code)) {
        final current = bible.code != bundledBibleCode || await bundledTextIsCurrent();
        if (await _isDataValid(bible.code) && current) {
          appLogger.d('BibleImportService: ${bible.code} already imported');
          continue;
        }
        appLogger.w('BibleImportService: ${bible.code} outdated or damaged, re-importing...');
        await _db.deleteVersion(bible.code);
      }
      appLogger.i('BibleImportService: importing ${bible.code}...');
      await _importFromAsset(
        assetPath: bible.asset,
        code: bible.code,
        name: bible.name,
        language: bible.language,
      );
    }
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

  /// Whether the included Bible on this computer is the text this build
  /// carries. Builds up to 1.4 carried it with the printed edition's drop
  /// capitals typed out as capitals - "EN el principio", "Y ACONTECIO",
  /// "JEHOVA es mi pastor" - at the start of more than half the chapters, and
  /// without their accents. A computer that has that text gets this one, once.
  Future<bool> bundledTextIsCurrent() async {
    try {
      final chapter = await _db.getChapter(bundledBibleCode, 0, 1);
      if (chapter == null) return false;
      final verses = jsonDecode(chapter.versesJson) as List;
      return verses.isNotEmpty && !'${verses.first}'.startsWith('EN el');
    } catch (_) {
      return false;
    }
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
    required String language,
  }) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final books = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    await _db.insertVersion(
      code: code,
      name: name,
      isBundled: true,
      books: books,
      language: language,
    );
  }
}
