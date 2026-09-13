import 'package:equatable/equatable.dart';

import '../models/song.dart';

/// The programs a song can be brought over from, by the file they leave.
enum SongFormat { proPresenter7, proPresenter6, openLyrics, songSelect, chordPro, plainText }

class ImportedVerse extends Equatable {
  const ImportedVerse(this.type, this.content);

  final VerseType type;
  final String content;

  @override
  List<Object?> get props => [type, content];
}

/// A song read out of another program's file, before it is in the library.
class ImportedSong extends Equatable {
  const ImportedSong({
    required this.title,
    required this.verses,
    required this.source,
    required this.format,
    this.author,
    this.copyright,
    this.ccliNumber,
  });

  final String title;
  final String? author;
  final String? copyright;

  /// Carried over so the licence report can name the song by its number.
  final String? ccliNumber;

  /// In the order they are shown, repeats included: where the other program
  /// kept an arrangement - verse, chorus, verse, chorus - it is spelled out
  /// here, because a song in this library is the sequence of its slides.
  final List<ImportedVerse> verses;

  /// The file it came from.
  final String source;
  final SongFormat format;

  ImportedSong copyWith({String? title}) => ImportedSong(
    title: title ?? this.title,
    verses: verses,
    source: source,
    format: format,
    author: author,
    copyright: copyright,
    ccliNumber: ccliNumber,
  );

  @override
  List<Object?> get props => [title, author, copyright, ccliNumber, verses, source, format];
}

/// Why a file did not become a song.
enum SongFileProblem {
  /// Not a kind of file any of the readers knows.
  unsupported,

  /// The kind is known but the file is damaged or not what its name says.
  unreadable,

  /// It was read, and there were no words in it.
  empty,
}

class SongFileFailure extends Equatable {
  const SongFileFailure(this.source, this.problem);

  final String source;
  final SongFileProblem problem;

  @override
  List<Object?> get props => [source, problem];
}

/// Returns null for nothing, so an empty field in another program's file does
/// not arrive as an empty string that shows up as a blank line.
String? nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Tidies the words of a slide: trailing spaces off every line, no blank
/// lines at either end, and no more than one blank line in a row.
String tidyLyrics(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.replaceAll(' ', ' ').trimRight())
      .toList();
  final out = <String>[];
  for (final line in lines) {
    if (line.trim().isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(line.trim().isEmpty ? '' : line.trim());
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}
