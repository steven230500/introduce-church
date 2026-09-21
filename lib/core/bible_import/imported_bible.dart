import 'package:equatable/equatable.dart';

/// The programs a Bible can be brought over from, by the file they leave.
enum BibleFormat {
  zefania('Zefania XML'),
  osis('OSIS'),
  openSong('OpenSong'),
  beblia('Beblia XML'),
  freeShow('FreeShow'),
  usfx('USFX'),
  usfm('USFM'),
  mySword('MySword'),
  eSword('e-Sword'),
  myBible('MyBible'),

  /// A list of books of chapters of verses: what the included Bible is kept in.
  bookList('JSON');

  const BibleFormat(this.label);

  /// The name people know the format by, the same in every language.
  final String label;
}

/// A Bible read out of another program's file, before it is saved.
///
/// Introduce does not hand out Bibles: most Spanish translations belong to a
/// publisher, and the right to use one is the church's. So the church brings
/// the file and it stays on that computer.
class ImportedBible extends Equatable {
  const ImportedBible({
    required this.title,
    required this.books,
    required this.source,
    required this.format,
    this.abbreviation,
    this.skippedBooks = 0,
    this.language,
  });

  /// What the file calls itself, or the file's name when it does not say.
  final String title;

  /// A short code the file gives itself, when it gives one.
  final String? abbreviation;

  /// Book (0 to 65) to its chapters, and each chapter to its verses, with
  /// verse n at n - 1. A verse the file does not have is an empty string, so
  /// the ones after it keep their numbers.
  final Map<int, List<List<String>>> books;

  /// Books in the file that are not among the 66 - the deuterocanonical books
  /// of a Catholic Bible - left out rather than put where another book goes.
  final int skippedBooks;

  /// The file it came from.
  final String source;
  final BibleFormat format;

  /// "es" or "en" when the file says which, null when it does not.
  final String? language;

  /// The language the Bible is in: what the file says, or else what its words
  /// look like. A handful of the commonest words in each language is enough
  /// to tell Spanish from English in a few hundred verses.
  String get probableLanguage {
    if (language != null) return language!;
    var english = 0, spanish = 0;
    var seen = 0;
    for (final chapters in books.values) {
      for (final verses in chapters) {
        for (final verse in verses) {
          for (final word in verse.toLowerCase().split(RegExp(r'[^a-záéíóúñü]+'))) {
            if (const {'the', 'and', 'of', 'to', 'he', 'his'}.contains(word)) english++;
            if (const {'de', 'la', 'que', 'el', 'y', 'los'}.contains(word)) spanish++;
          }
          if (++seen > 400) return english > spanish ? 'en' : 'es';
        }
      }
    }
    return english > spanish ? 'en' : 'es';
  }

  int get missingBooks => 66 - books.length;

  int get verseCount => books.values.fold(
    0,
    (sum, chapters) =>
        sum +
        chapters.fold(0, (inBook, verses) => inBook + verses.where((v) => v.isNotEmpty).length),
  );

  @override
  List<Object?> get props => [title, abbreviation, books, skippedBooks, source, format, language];
}

/// Why a file did not become a Bible.
enum BibleFileProblem {
  /// Not a kind of file any of the readers knows.
  unsupported,

  /// The kind is known but the file is damaged or not what its name says.
  unreadable,

  /// It was read, and there were no verses in it.
  empty,
}

class BibleFileFailure extends Equatable implements Exception {
  const BibleFileFailure(this.source, this.problem);

  final String source;
  final BibleFileProblem problem;

  @override
  List<Object?> get props => [source, problem];
}
