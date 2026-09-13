import '../imported_song.dart';
import 'songselect.dart';

/// Reads lyrics saved as plain text: paragraphs are slides, a line like
/// "Coro" or "Verse 2" labels the paragraph after it, and a short first line
/// standing on its own is the title.
ImportedSong readPlainText(String text, {required String source, required String name}) {
  final lines = text.split(RegExp(r'\r?\n'));
  var title = name;
  var start = 0;
  final first = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (first != -1 &&
      first + 1 < lines.length &&
      lines[first + 1].trim().isEmpty &&
      lines[first].trim().length <= 60 &&
      readSections([lines[first]]).isNotEmpty) {
    title = lines[first].trim();
    start = first + 1;
  }
  return ImportedSong(
    title: title,
    verses: readSections(lines.skip(start)),
    source: source,
    format: SongFormat.plainText,
  );
}
