part of 'bible_browser_cubit.dart';

enum BibleBrowserView { books, chapters, verses }

class BibleBookItem {
  const BibleBookItem({required this.book, required this.displayName});
  final BibleBook book;
  final String displayName;
}

class BibleBrowserState extends Equatable {
  const BibleBrowserState({
    this.versions = const [],
    this.selectedVersion,
    this.allBooks = const [],
    this.filteredBooks = const [],
    this.selectedBook,
    this.chapters = const [],
    this.selectedChapter,
    this.verses = const [],
    this.selectedVerse,
    this.selectedVerseEnd,
    this.view = BibleBrowserView.books,
  });

  final List<BibleVersion> versions;
  final BibleVersion? selectedVersion;
  final List<BibleBookItem> allBooks;
  final List<BibleBookItem> filteredBooks;
  final BibleBookItem? selectedBook;
  final List<int> chapters;
  final int? selectedChapter;
  final List<String> verses;
  final int? selectedVerse;
  final int? selectedVerseEnd;
  final BibleBrowserView view;

  bool get canConfirm =>
      selectedVersion != null &&
      selectedBook != null &&
      selectedChapter != null &&
      selectedVerse != null;

  bool get isRange =>
      selectedVerse != null && selectedVerseEnd != null && selectedVerseEnd! > selectedVerse!;

  BibleBrowserState copyWith({
    List<BibleVersion>? versions,
    BibleVersion? selectedVersion,
    List<BibleBookItem>? allBooks,
    List<BibleBookItem>? filteredBooks,
    BibleBookItem? selectedBook,
    bool clearBook = false,
    List<int>? chapters,
    int? selectedChapter,
    List<String>? verses,
    int? selectedVerse,
    int? selectedVerseEnd,
    bool clearVerse = false,
    BibleBrowserView? view,
  }) {
    return BibleBrowserState(
      versions: versions ?? this.versions,
      selectedVersion: selectedVersion ?? this.selectedVersion,
      allBooks: allBooks ?? this.allBooks,
      filteredBooks: filteredBooks ?? this.filteredBooks,
      selectedBook: clearBook ? null : selectedBook ?? this.selectedBook,
      chapters: chapters ?? this.chapters,
      selectedChapter: selectedChapter ?? this.selectedChapter,
      verses: verses ?? this.verses,
      selectedVerse: clearVerse ? null : selectedVerse ?? this.selectedVerse,
      selectedVerseEnd: clearVerse ? null : selectedVerseEnd ?? this.selectedVerseEnd,
      view: view ?? this.view,
    );
  }

  @override
  List<Object?> get props => [
    versions,
    selectedVersion,
    allBooks,
    filteredBooks,
    selectedBook,
    chapters,
    selectedChapter,
    verses,
    selectedVerse,
    selectedVerseEnd,
    view,
  ];
}
