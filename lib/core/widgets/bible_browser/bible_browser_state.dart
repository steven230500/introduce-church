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
    this.query = '',
    this.textHits = const [],
    this.revealVerse,
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

  /// What the operator typed in the search, and the verses whose words hold
  /// it: "de tal manera amó" is a way into the Bible as much as "Juan" is.
  final String query;
  final List<VerseHit> textHits;

  /// A verse opened from a search, which the list scrolls to: John 3:16 is
  /// sixteen rows down, below the fold.
  final int? revealVerse;

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
    String? query,
    List<VerseHit>? textHits,
    int? revealVerse,
    bool clearReveal = false,
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
      query: query ?? this.query,
      textHits: textHits ?? this.textHits,
      revealVerse: clearReveal ? null : revealVerse ?? this.revealVerse,
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
    query,
    textHits,
    revealVerse,
  ];
}
