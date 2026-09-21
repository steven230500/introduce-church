import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Versiones instaladas (RV1909 incluida, las demás importadas por la iglesia)
class BibleVersions extends Table {
  TextColumn get code => text()(); // 'RV1909', 'NVI', etc.
  TextColumn get name => text()();
  BoolColumn get isBundled => boolean().withDefault(const Constant(false))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  /// The language the Bible is in, "es" or "en": its books are named in it.
  /// Null for the versions saved before this was kept, all of them Spanish.
  TextColumn get language => text().nullable()();

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

  /// A database that lives only as long as the test does.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(bibleVersions, bibleVersions.language);
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'introduce_church_local');
  }

  // Versiones
  Future<List<BibleVersion>> getAllVersions() => select(bibleVersions).get();

  Future<bool> isVersionDownloaded(String code) async {
    final v = await (select(bibleVersions)..where((t) => t.code.equals(code))).getSingleOrNull();
    return v?.isDownloaded ?? false;
  }

  /// The whole Bible, as every version the app offers counts it.
  static const wholeBibleBooks = 66;

  /// Whether a version has all of its books and all of their chapters.
  ///
  /// A download that is cut off - the wifi drops, the laptop sleeps - used to
  /// leave a Bible with the first few books in it, marked as installed, and
  /// the operator found out on a Sunday that Romans was not there.
  Future<bool> isVersionComplete(String code) async {
    final books = await getBooks(code);
    if (books.length < wholeBibleBooks) return false;
    final expected = books.fold<int>(0, (sum, b) => sum + b.chapterCount);
    final stored =
        await (selectOnly(bibleChapters)
              ..addColumns([bibleChapters.id.count()])
              ..where(bibleChapters.versionCode.equals(code)))
            .map((row) => row.read(bibleChapters.id.count()) ?? 0)
            .getSingle();
    return stored >= expected;
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

  /// Every chapter of a version, for reading it whole.
  Future<List<BibleChapter>> getChapters(String versionCode) =>
      (select(bibleChapters)..where((t) => t.versionCode.equals(versionCode))).get();

  Future<void> deleteVersion(String code) async {
    await transaction(() async {
      await (delete(bibleChapters)..where((t) => t.versionCode.equals(code))).go();
      await (delete(bibleBooks)..where((t) => t.versionCode.equals(code))).go();
      await (delete(bibleVersions)..where((t) => t.code.equals(code))).go();
    });
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
    // False only in tests, for a download an older build left half done.
    bool isDownloaded = true,
    String? language,
  }) async {
    await transaction(() async {
      await into(bibleVersions).insertOnConflictUpdate(
        BibleVersionsCompanion(
          code: Value(code),
          name: Value(name),
          language: Value(language),
          isBundled: Value(isBundled),
          isDownloaded: Value(isDownloaded),
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

  /// Saves a Bible read from a file, replacing any version with that code.
  ///
  /// [books] maps each book's place among the 66 to its chapters, so a file
  /// with only the New Testament puts Matthew where Matthew goes. One
  /// transaction: a Bible is either all there or not there at all.
  Future<void> installVersion({
    required String code,
    required String name,
    required Map<int, List<List<String>>> books,
    required List<String> bookNames,
    required List<String> bookAbbrevs,
    String? language,
  }) async {
    await transaction(() async {
      await deleteBooksAndChapters(code);
      await into(bibleVersions).insertOnConflictUpdate(
        BibleVersionsCompanion(
          code: Value(code),
          name: Value(name),
          language: Value(language),
          isBundled: const Value(false),
          isDownloaded: const Value(true),
          downloadedAt: Value(DateTime.now()),
        ),
      );
      await batch((b) {
        for (final MapEntry(key: index, value: chapters) in books.entries) {
          b.insert(
            bibleBooks,
            BibleBooksCompanion.insert(
              versionCode: code,
              bookIndex: index,
              abbrev: bookAbbrevs[index],
              name: bookNames[index],
              chapterCount: chapters.length,
            ),
          );
          for (final (c, verses) in chapters.indexed) {
            if (verses.isEmpty) continue;
            b.insert(
              bibleChapters,
              BibleChaptersCompanion.insert(
                versionCode: code,
                bookIndex: index,
                chapter: c + 1,
                versesJson: jsonEncode(verses),
              ),
            );
          }
        }
      });
    });
  }

  /// Gives a version a new code and name, keeping its text.
  Future<void> renameVersion(String from, {required String to, required String name}) async {
    await transaction(() async {
      final row = await (select(
        bibleVersions,
      )..where((t) => t.code.equals(from))).getSingleOrNull();
      if (row == null) return;
      await into(
        bibleVersions,
      ).insertOnConflictUpdate(row.copyWith(code: to, name: name).toCompanion(true));
      await (update(bibleBooks)..where((t) => t.versionCode.equals(from))).write(
        BibleBooksCompanion(versionCode: Value(to)),
      );
      await (update(bibleChapters)..where((t) => t.versionCode.equals(from))).write(
        BibleChaptersCompanion(versionCode: Value(to)),
      );
      await (delete(bibleVersions)..where((t) => t.code.equals(from))).go();
    });
  }
}
