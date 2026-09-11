import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Versiones descargadas (RVR1960 bundled, otras descargadas)
class BibleVersions extends Table {
  TextColumn get code => text()(); // 'RVR1960', 'NVI', etc.
  TextColumn get name => text()();
  BoolColumn get isBundled => boolean().withDefault(const Constant(false))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {code};
}

// Libros de cada versión
class BibleBooks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get versionCode => text()();
  IntColumn get bookIndex => integer()(); // 0-65
  TextColumn get abbrev => text()(); // 'gn', 'ex', 'jn', etc.
  TextColumn get name => text()(); // 'Génesis', 'Juan', etc.
  IntColumn get chapterCount => integer()();
}

// Capítulos (versículos como JSON array)
class BibleChapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get versionCode => text()();
  IntColumn get bookIndex => integer()();
  IntColumn get chapter => integer()(); // 1-based
  TextColumn get versesJson => text()(); // '["En el principio...", "Y la tierra..."]'
}

@DriftDatabase(tables: [BibleVersions, BibleBooks, BibleChapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'introduce_church_local');
  }

  // Versiones
  Future<List<BibleVersion>> getAllVersions() => select(bibleVersions).get();

  Future<bool> isVersionDownloaded(String code) async {
    final v = await (select(bibleVersions)..where((t) => t.code.equals(code))).getSingleOrNull();
    return v?.isDownloaded ?? false;
  }

  // Libros
  Future<List<BibleBook>> getBooks(String versionCode) {
    return (select(bibleBooks)
          ..where((t) => t.versionCode.equals(versionCode))
          ..orderBy([(t) => OrderingTerm.asc(t.bookIndex)]))
        .get();
  }

  // Capítulos
  Future<BibleChapter?> getChapter(String versionCode, int bookIndex, int chapter) {
    return (select(bibleChapters)..where(
          (t) =>
              t.versionCode.equals(versionCode) &
              t.bookIndex.equals(bookIndex) &
              t.chapter.equals(chapter),
        ))
        .getSingleOrNull();
  }

  Future<void> deleteVersion(String code) async {
    await transaction(() async {
      await (delete(bibleChapters)..where((t) => t.versionCode.equals(code))).go();
      await (delete(bibleBooks)..where((t) => t.versionCode.equals(code))).go();
      await (delete(bibleVersions)..where((t) => t.code.equals(code))).go();
    });
  }

  // Insertar libro individual (para descarga progresiva)
  Future<void> insertBook({
    required String versionCode,
    required int bookIndex,
    required String abbrev,
    required String bookName,
    required int chapterCount,
  }) async {
    await into(bibleBooks).insertOnConflictUpdate(
      BibleBooksCompanion(
        versionCode: Value(versionCode),
        bookIndex: Value(bookIndex),
        abbrev: Value(abbrev),
        name: Value(bookName),
        chapterCount: Value(chapterCount),
      ),
    );
  }

  // Insertar capítulo individual (para descarga progresiva)
  Future<void> insertChapter({
    required String versionCode,
    required int bookIndex,
    required int chapter,
    required String versesJson,
  }) async {
    await into(bibleChapters).insertOnConflictUpdate(
      BibleChaptersCompanion(
        versionCode: Value(versionCode),
        bookIndex: Value(bookIndex),
        chapter: Value(chapter),
        versesJson: Value(versesJson),
      ),
    );
  }

  // Eliminar libros y capítulos de una versión (sin borrar la fila de versión)
  Future<void> deleteBooksAndChapters(String code) async {
    await (delete(bibleChapters)..where((t) => t.versionCode.equals(code))).go();
    await (delete(bibleBooks)..where((t) => t.versionCode.equals(code))).go();
  }

  // Insertar versión completa (bulk)
  Future<void> insertVersion({
    required String code,
    required String name,
    required bool isBundled,
    required List<Map<String, dynamic>> books,
  }) async {
    await transaction(() async {
      await into(bibleVersions).insertOnConflictUpdate(
        BibleVersionsCompanion(
          code: Value(code),
          name: Value(name),
          isBundled: Value(isBundled),
          isDownloaded: Value(true),
          downloadedAt: Value(DateTime.now()),
        ),
      );

      for (final (i, book) in books.indexed) {
        final chapters = book['chapters'] as List;

        await into(bibleBooks).insertOnConflictUpdate(
          BibleBooksCompanion(
            versionCode: Value(code),
            bookIndex: Value(i),
            abbrev: Value(book['abbrev'] as String),
            name: Value(book['name'] as String),
            chapterCount: Value(chapters.length),
          ),
        );

        for (var c = 0; c < chapters.length; c++) {
          final verses = chapters[c] as List;
          await into(bibleChapters).insertOnConflictUpdate(
            BibleChaptersCompanion(
              versionCode: Value(code),
              bookIndex: Value(i),
              chapter: Value(c + 1),
              versesJson: Value(jsonEncode(verses)),
            ),
          );
        }
      }
    });
  }
}
