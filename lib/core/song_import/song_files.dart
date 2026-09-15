import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'formats/chordpro.dart';
import 'formats/freeshow.dart';
import 'formats/openlyrics.dart';
import 'formats/plain_text.dart';
import 'formats/propresenter.dart';
import 'formats/songselect.dart';
import 'imported_song.dart';

/// Every extension a song can be read from.
const songFileExtensions = [
  'pro',
  'pro6',
  'pro5',
  'pro4',
  'xml',
  'usr',
  'bin',
  'txt',
  'cho',
  'chordpro',
  'chopro',
  'crd',
  'show',
];

/// A file read: a song, or why it is not one.
typedef SongFileResult = ({ImportedSong? song, SongFileFailure? failure});

/// Reads one file's bytes as a song, working out which program wrote it from
/// its name and, where names are shared, from what is inside.
SongFileResult readSongBytes(String path, Uint8List bytes) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  final name = p.basenameWithoutExtension(path);
  SongFileResult failed(SongFileProblem problem) =>
      (song: null, failure: SongFileFailure(path, problem));

  if (!songFileExtensions.contains(ext)) return failed(SongFileProblem.unsupported);
  // SongSelect's own download is a .bin; any other .bin is not a song.
  if (ext == 'bin' && !looksLikeSongSelectUsr(decodeText(bytes))) {
    return failed(SongFileProblem.unsupported);
  }

  try {
    final ImportedSong song;
    if (ext == 'pro' && !_looksLikeText(bytes)) {
      // .pro is ProPresenter 7, which is binary. A ChordPro file saved with the
      // same ending is text, and is read as ChordPro below.
      song = readProPresenter7(bytes, source: path, name: name);
    } else {
      final text = decodeText(bytes);
      final head = text.length > 2000 ? text.substring(0, 2000) : text;
      if (ext == 'show' || (head.trimLeft().startsWith('[') && looksLikeFreeShow(text))) {
        // FreeShow keeps passages and slide decks in the same kind of file as
        // songs, and neither belongs in a song library.
        final category = freeShowCategory(text);
        if (category == 'scripture' || category == 'presentation') {
          return failed(SongFileProblem.notASong);
        }
        song = readFreeShow(text, source: path, name: name);
      } else if (head.contains('<RVPresentationDocument')) {
        song = readProPresenter6(text, source: path, name: name);
      } else if (ext == 'xml' || head.trimLeft().startsWith('<?xml')) {
        song = readOpenLyrics(text, source: path, name: name);
      } else if (ext == 'usr' || looksLikeSongSelectUsr(head)) {
        song = readSongSelectUsr(text, source: path, name: name);
      } else if (ext == 'pro') {
        // A .pro that is text and not ProPresenter is ChordPro only if it
        // reads as ChordPro. Anything else with that ending is a damaged
        // ProPresenter file, not a one-slide song made of its bytes.
        if (!looksLikeChordPro(text)) return failed(SongFileProblem.unreadable);
        song = readChordPro(text, source: path, name: name);
      } else if (['cho', 'chordpro', 'chopro', 'crd'].contains(ext) || looksLikeChordPro(text)) {
        song = readChordPro(text, source: path, name: name);
      } else if (looksLikeSongSelectText(text)) {
        song = readSongSelectText(text, source: path, name: name);
      } else if (ext == 'txt') {
        song = readPlainText(text, source: path, name: name);
      } else {
        return failed(SongFileProblem.unsupported);
      }
    }
    if (song.verses.isEmpty) return failed(SongFileProblem.empty);
    return (song: song, failure: null);
  } catch (_) {
    return failed(SongFileProblem.unreadable);
  }
}

/// Text in whatever encoding the program that wrote it chose: UTF-8 with or
/// without a byte order mark, UTF-16 from Windows exports, or Latin-1 from
/// older ones.
String decodeText(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes.sublist(2), littleEndian: false);
  }
  var start = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) start = 3;
  final body = Uint8List.sublistView(bytes, start);
  try {
    return utf8.decode(body);
  } on FormatException {
    return latin1.decode(body, allowInvalid: true);
  }
}

String _utf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(littleEndian ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}

/// Whether the start of a file is text rather than binary.
bool _looksLikeText(Uint8List bytes) {
  final sample = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  if (sample.isEmpty) return true;
  final control = sample.where((b) => b < 0x09 || (b > 0x0D && b < 0x20)).length;
  return control == 0;
}

/// The song files in [directory] and every folder inside it, sorted, up to
/// [limit] of them.
///
/// Hidden folders are passed over, and so is the __MACOSX folder a zip from a
/// Mac leaves behind, whose files have the right names and nothing in them.
Future<List<String>> listSongFiles(String directory, {int limit = 5000}) async {
  final found = <String>[];
  final root = Directory(directory);
  if (!await root.exists()) return found;
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final parts = p.split(p.relative(entity.path, from: directory));
    if (parts.any((part) => part.startsWith('.') || part == '__MACOSX')) continue;
    final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
    if (!songFileExtensions.contains(ext)) continue;
    // A folder of anything can hold .bin files; only SongSelect's are listed,
    // so the rest do not fill the review with files that were never songs.
    if (ext == 'bin' && !await _isSongSelectBin(entity)) continue;
    found.add(entity.path);
    if (found.length >= limit) break;
  }
  found.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return found;
}

Future<bool> _isSongSelectBin(File file) async {
  try {
    if (await file.length() > 256 * 1024) return false;
    return looksLikeSongSelectUsr(decodeText(await file.readAsBytes()));
  } catch (_) {
    return false;
  }
}

/// Reads [paths] off the main thread, a chunk at a time, calling [onProgress]
/// with how many are done so a library of a thousand songs shows movement.
Future<List<SongFileResult>> readSongFiles(
  List<String> paths, {
  void Function(int done)? onProgress,
  int chunk = 40,
}) async {
  final results = <SongFileResult>[];
  for (var start = 0; start < paths.length; start += chunk) {
    final slice = paths.sublist(start, (start + chunk).clamp(0, paths.length));
    results.addAll(await Isolate.run(() => [for (final path in slice) _readPath(path)]));
    onProgress?.call(results.length);
  }
  return results;
}

SongFileResult _readPath(String path) {
  try {
    return readSongBytes(path, File(path).readAsBytesSync());
  } catch (_) {
    return (song: null, failure: SongFileFailure(path, SongFileProblem.unreadable));
  }
}
