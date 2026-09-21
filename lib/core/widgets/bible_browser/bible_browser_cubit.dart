import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../local_db/app_database.dart';
import '../../local_db/bible_repository.dart';

part 'bible_browser_state.dart';

class BibleBrowserCubit extends Cubit<BibleBrowserState> {
  BibleBrowserCubit(this._repo) : super(const BibleBrowserState());

  final BibleRepository _repo;

  /// Opens on the version the operator uses, and again after the versions
  /// dialog added or removed one.
  Future<void> load() async {
    final versions = await _repo.getVersions();
    final selected = await _repo.preferredVersion();
    if (versions.isEmpty || selected == null) {
      emit(const BibleBrowserState());
      return;
    }
    final books = await _buildBookItems(selected);
    // From scratch: a book picked in a version that may no longer be there
    // means nothing now.
    emit(
      BibleBrowserState(
        versions: versions,
        selectedVersion: selected,
        allBooks: books,
        filteredBooks: books,
      ),
    );
  }

  Future<void> selectVersion(BibleVersion version) async {
    await _repo.rememberVersion(version.code);
    if (state.query.trim().length >= _searchFrom) unawaited(_searchTextIn(version));
    final books = await _buildBookItems(version);
    emit(
      state.copyWith(
        selectedVersion: version,
        allBooks: books,
        filteredBooks: books,
        clearBook: true,
        chapters: [],
        selectedChapter: null,
        verses: [],
        selectedVerse: null,
        view: BibleBrowserView.books,
      ),
    );
  }

  void filterBooks(String query) {
    final q = query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? state.allBooks
        : state.allBooks.where((b) => b.displayName.toLowerCase().contains(q)).toList();
    final searching = q.length >= _searchFrom;
    emit(
      state.copyWith(
        filteredBooks: filtered,
        query: query,
        textHits: searching ? state.textHits : const [],
      ),
    );
    if (searching) unawaited(_searchText(query));
  }

  /// Below this many letters a search of the words finds half the Bible.
  static const _searchFrom = 3;

  /// Looks for [query] in the words of the selected version. An answer that
  /// arrives after the operator typed more is dropped.
  Future<void> _searchText(String query) async {
    final version = state.selectedVersion;
    if (version == null) return;
    final hits = await _repo.searchText(version.code, query);
    if (isClosed || state.query != query) return;
    emit(state.copyWith(textHits: hits));
  }

  Future<void> _searchTextIn(BibleVersion version) async {
    final query = state.query;
    final hits = await _repo.searchText(version.code, query);
    if (isClosed || state.query != query || state.selectedVersion?.code != version.code) return;
    emit(state.copyWith(textHits: hits));
  }

  /// Opens the chapter of a verse found by its words, with the verse chosen.
  Future<void> openHit(VerseHit hit) async {
    final book = state.allBooks.where((b) => b.book.bookIndex == hit.bookIndex).firstOrNull;
    if (book == null) return;
    await selectBook(book);
    await selectChapter(hit.chapter);
    selectVerse(hit.verse);
  }

  Future<void> selectBook(BibleBookItem book) async {
    final chapters = List.generate(book.book.chapterCount, (i) => i + 1);
    emit(
      state.copyWith(
        selectedBook: book,
        chapters: chapters,
        selectedChapter: null,
        verses: [],
        selectedVerse: null,
        view: BibleBrowserView.chapters,
      ),
    );
  }

  Future<void> selectChapter(int chapter) async {
    if (state.selectedVersion == null || state.selectedBook == null) return;
    final verses = await _repo.getVerses(
      state.selectedVersion!.code,
      state.selectedBook!.book.bookIndex,
      chapter,
    );
    emit(
      state.copyWith(
        selectedChapter: chapter,
        verses: verses,
        selectedVerse: null,
        view: BibleBrowserView.verses,
      ),
    );
  }

  void selectVerse(int verseNumber) {
    if (state.selectedVerse == null) {
      // First tap: set start
      emit(state.copyWith(selectedVerse: verseNumber, selectedVerseEnd: verseNumber));
    } else if (verseNumber == state.selectedVerse && verseNumber == state.selectedVerseEnd) {
      // Tap same single verse again: deselect
      emit(state.copyWith(clearVerse: true));
    } else {
      // Second tap: extend range (always min..max)
      final start = state.selectedVerse!;
      final newStart = verseNumber < start ? verseNumber : start;
      final newEnd = verseNumber > start ? verseNumber : start;
      emit(state.copyWith(selectedVerse: newStart, selectedVerseEnd: newEnd));
    }
  }

  void goBack() {
    if (state.view == BibleBrowserView.verses) {
      emit(state.copyWith(view: BibleBrowserView.chapters, selectedVerse: null));
    } else if (state.view == BibleBrowserView.chapters) {
      emit(
        state.copyWith(
          view: BibleBrowserView.books,
          clearBook: true,
          chapters: [],
          selectedChapter: null,
        ),
      );
    }
  }

  Future<BibleVerseRef?> buildVerseRef() async {
    final s = state;
    if (s.selectedVersion == null ||
        s.selectedBook == null ||
        s.selectedChapter == null ||
        s.selectedVerse == null) {
      return null;
    }
    return _repo.getVerseRange(
      versionCode: s.selectedVersion!.code,
      bookIndex: s.selectedBook!.book.bookIndex,
      chapter: s.selectedChapter!,
      verseStart: s.selectedVerse!,
      verseEnd: s.selectedVerseEnd ?? s.selectedVerse!,
    );
  }

  /// The books of [version], named in its language: an English Bible lists
  /// "John", not "Juan".
  Future<List<BibleBookItem>> _buildBookItems(BibleVersion version) async {
    final books = await _repo.getBooks(version.code);
    return books
        .map(
          (b) => BibleBookItem(
            book: b,
            displayName: bookName(b.bookIndex, language: version.language),
          ),
        )
        .toList();
  }
}
