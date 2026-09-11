import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../local_db/app_database.dart';
import '../../local_db/bible_repository.dart';

part 'bible_browser_state.dart';

class BibleBrowserCubit extends Cubit<BibleBrowserState> {
  BibleBrowserCubit(this._repo) : super(const BibleBrowserState());

  final BibleRepository _repo;

  Future<void> load() async {
    final versions = await _repo.getVersions();
    if (versions.isEmpty) return;
    final selected = versions.first;
    final books = await _buildBookItems(selected.code);
    emit(
      state.copyWith(
        versions: versions,
        selectedVersion: selected,
        allBooks: books,
        filteredBooks: books,
        view: BibleBrowserView.books,
      ),
    );
  }

  Future<void> selectVersion(BibleVersion version) async {
    final books = await _buildBookItems(version.code);
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
    emit(state.copyWith(filteredBooks: filtered));
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

  Future<List<BibleBookItem>> _buildBookItems(String versionCode) async {
    final books = await _repo.getBooks(versionCode);
    return books
        .map((b) => BibleBookItem(book: b, displayName: spanishBookName(b.bookIndex)))
        .toList();
  }
}
