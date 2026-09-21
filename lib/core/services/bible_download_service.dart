import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../local_db/app_database.dart';

const _bollsBase = 'https://bolls.life';

class BibleDownloadService {
  BibleDownloadService(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  // ── Legacy: download single JSON from URL ─────────────────────────────────

  Future<void> downloadAndImport({
    required String url,
    required String code,
    required String name,
    required void Function(double progress) onProgress,
  }) async {
    final response = await _dio.get<String>(
      url,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
      options: Options(responseType: ResponseType.plain),
    );
    if (response.data == null) throw Exception('Respuesta vacía del servidor');
    await _parseAndInsert(response.data!, code: code, name: name);
  }

  // ── bolls.life API download ───────────────────────────────────────────────

  /// Downloads a Bible translation from bolls.life chapter by chapter.
  /// [apiCode] is the bolls.life translation code (e.g. 'NVI', 'LBLA').
  Future<void> downloadFromApi({
    required String apiCode,
    required String code,
    required String name,
    required void Function(double progress) onProgress,
  }) async {
    // 1. Fetch book list
    final booksRes = await _dio.get<String>(
      '$_bollsBase/get-books/$apiCode/',
      options: Options(responseType: ResponseType.plain),
    );
    if (booksRes.data == null) throw Exception('No se pudo obtener la lista de libros');

    final booksList = List<Map<String, dynamic>>.from(jsonDecode(booksRes.data!) as List);
    final totalChapters = booksList.fold<int>(0, (sum, b) => sum + (b['chapters'] as int));
    var completedChapters = 0;

    // 2. Prepare version row, not yet readable: what is half downloaded must
    // not look installed.
    await _db.insertVersion(
      code: code,
      name: name,
      isBundled: false,
      books: [],
      isDownloaded: false,
    );

    // Wipe existing data for clean re-import
    await _db.deleteBooksAndChapters(code);

    // 3. Download chapter by chapter, book by book
    for (var bi = 0; bi < booksList.length; bi++) {
      final book = booksList[bi];
      final bookId = book['bookid'] as int;
      final bookName = book['name'] as String;
      final chapterCount = book['chapters'] as int;
      final abbrev = _spanishAbbrev(bi);

      await _db.insertBook(
        versionCode: code,
        bookIndex: bi,
        abbrev: abbrev,
        bookName: bookName,
        chapterCount: chapterCount,
      );

      // Fetch chapters in small parallel batches
      const batchSize = 8;
      for (var start = 1; start <= chapterCount; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, chapterCount);
        final futures = [for (var ch = start; ch <= end; ch++) _fetchChapter(apiCode, bookId, ch)];
        final results = await Future.wait(futures);

        for (var i = 0; i < results.length; i++) {
          final chapter = start + i;
          await _db.insertChapter(
            versionCode: code,
            bookIndex: bi,
            chapter: chapter,
            versesJson: jsonEncode(results[i]),
          );
          completedChapters++;
          onProgress(completedChapters / totalChapters);
        }
      }
    }

    // 4. Only now is it a Bible.
    await _db.markVersionDownloaded(code);
  }

  Future<List<String>> _fetchChapter(String apiCode, int bookId, int chapter) async {
    final res = await _dio.get<String>(
      '$_bollsBase/get-text/$apiCode/$bookId/$chapter/',
      options: Options(responseType: ResponseType.plain),
    );
    if (res.data == null) return [];
    final verses = List<Map<String, dynamic>>.from(jsonDecode(res.data!) as List);
    return verses.map((v) => _stripHtml(v['text'] as String? ?? '')).toList();
  }

  // ── Import from local file ────────────────────────────────────────────────

  Future<void> importFromFile({
    required String filePath,
    required String code,
    required String name,
  }) async {
    final content = await File(filePath).readAsString();
    await _parseAndInsert(content, code: code, name: name);
  }

  Future<void> _parseAndInsert(String jsonStr, {required String code, required String name}) async {
    final raw = jsonStr.startsWith('﻿') ? jsonStr.substring(1) : jsonStr;
    final books = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    await _db.insertVersion(code: code, name: name, isBundled: false, books: books);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> isDownloaded(String code) => _db.isVersionDownloaded(code);

  /// Whether what is stored is the whole Bible. A version downloaded by an
  /// older build may say it is installed while holding only its first books.
  Future<bool> isComplete(String code) => _db.isVersionComplete(code);
  Future<void> deleteVersion(String code) => _db.deleteVersion(code);

  static String _stripHtml(String text) => text.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static const _abbrevs = [
    'gn',
    'ex',
    'lv',
    'nm',
    'dt',
    'jos',
    'jue',
    'rt',
    '1s',
    '2s',
    '1r',
    '2r',
    '1cr',
    '2cr',
    'esd',
    'ne',
    'est',
    'job',
    'sal',
    'pr',
    'ec',
    'cnt',
    'is',
    'jer',
    'lm',
    'ez',
    'dn',
    'os',
    'jl',
    'am',
    'ab',
    'jon',
    'mi',
    'na',
    'hab',
    'sof',
    'hag',
    'zac',
    'mal',
    'mt',
    'mr',
    'lc',
    'jn',
    'hch',
    'ro',
    '1co',
    '2co',
    'ga',
    'ef',
    'fil',
    'col',
    '1ts',
    '2ts',
    '1ti',
    '2ti',
    'tit',
    'flm',
    'he',
    'stg',
    '1p',
    '2p',
    '1jn',
    '2jn',
    '3jn',
    'jud',
    'ap',
  ];

  static String _spanishAbbrev(int index) =>
      index < _abbrevs.length ? _abbrevs[index] : 'b${index + 1}';
}
