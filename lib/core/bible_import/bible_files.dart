import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../utils/text_encoding.dart';
import 'formats/book_list.dart';
import 'formats/freeshow.dart';
import 'formats/osis.dart';
import 'formats/sqlite_bible.dart';
import 'formats/usfm.dart';
import 'formats/usfx.dart';
import 'formats/xml_bible.dart';
import 'formats/xml_support.dart';
import 'imported_bible.dart';

/// Every extension a Bible can be read from.
const bibleFileExtensions = [
  'xml', 'osis', 'json', 'fsb', 'zip', //
  'usfx', 'usfm', 'sfm', 'ptx',
  'bblx', 'mybible', 'sqlite3', 'sqlite',
];

/// A file read: a Bible, or why it is not one.
typedef BibleFileResult = ({ImportedBible? bible, BibleFileFailure? failure});

/// Reads one file's bytes as a Bible, working out which program wrote it from
/// what is inside: extensions are shared (every one of the XML formats is a
/// .xml), the first bytes are not.
BibleFileResult readBibleBytes(String path, Uint8List bytes, {String? source}) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  final name = bibleNameFromFile(path);
  final from = source ?? path;
  BibleFileResult failed(BibleFileProblem problem) =>
      (bible: null, failure: BibleFileFailure(from, problem));

  if (!bibleFileExtensions.contains(ext)) return failed(BibleFileProblem.unsupported);
  if (ext == 'zip') return _readZip(bytes, from);

  try {
    final ImportedBible bible;
    if (_isSqlite(bytes)) {
      bible = _readSqlite(bytes, source: from, name: name);
    } else {
      final text = decodeText(bytes).trimLeft();
      if (text.startsWith('[')) {
        bible = readBookList(text, source: from, name: name);
      } else if (text.startsWith('{')) {
        bible = readFreeShowBible(text, source: from, name: name);
      } else if (text.startsWith('<')) {
        final shape = xmlShape(text);
        switch (shape.root) {
          case 'xmlbible':
            bible = readZefania(text, source: from, name: name);
          case 'osis':
            bible = readOsis(text, source: from, name: name);
          case 'usfx':
            bible = readUsfx(text, source: from, name: name);
          case 'bible' when shape.firstChild == 'b':
            bible = readOpenSong(text, source: from, name: name);
          case 'bible':
            bible = readBeblia(text, source: from, name: name);
          default:
            return failed(BibleFileProblem.unsupported);
        }
      } else if (looksLikeUsfm(text)) {
        bible = readUsfm(text, source: from, name: name);
      } else {
        return failed(BibleFileProblem.unsupported);
      }
    }
    if (bible.verseCount == 0) return failed(BibleFileProblem.empty);
    return (bible: bible, failure: null);
  } catch (_) {
    return failed(BibleFileProblem.unreadable);
  }
}

/// What a file's name says the Bible is called: "La_Biblia_de_Las_Americas"
/// as "La Biblia de Las Americas", and eBible's "spaRV1909_usfx" as "RV1909".
String bibleNameFromFile(String path) {
  var stem = p.basename(path);
  // ".bbl.mybible" and the like: every extension, not just the last.
  final dot = stem.indexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  stem = stem.replaceFirst(
    RegExp(r'[_-](usfx|usfm|vpl|osis|readaloud|html|sword)$', caseSensitive: false),
    '',
  );
  final ebible = RegExp(r'^(spa|eng|por|fra|deu|ita)([A-Z0-9][A-Za-z0-9]*)$').firstMatch(stem);
  if (ebible != null) stem = ebible.group(2)!;
  return stem.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isSqlite(Uint8List bytes) =>
    bytes.length > 16 && String.fromCharCodes(bytes.sublist(0, 15)) == 'SQLite format 3';

/// SQLite reads from a file, and the bytes may have come out of a zip.
ImportedBible _readSqlite(Uint8List bytes, {required String source, required String name}) {
  final dir = Directory.systemTemp.createTempSync('introduce_bible');
  try {
    final file = File(p.join(dir.path, 'bible.sqlite'))..writeAsBytesSync(bytes);
    return readSqliteBible(file.path, source: source, name: name);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Some Bibles are passed around zipped. The biggest file inside that is one
/// of the kinds above is the Bible; the rest are readmes and licences. USFM
/// comes as a file per book, and those are read together.
BibleFileResult _readZip(Uint8List bytes, String source) {
  try {
    String ext(ArchiveFile f) => p.extension(f.name).replaceFirst('.', '').toLowerCase();
    final inside =
        ZipDecoder()
            .decodeBytes(bytes)
            .files
            .where(
              (f) =>
                  f.isFile &&
                  !f.name.contains('__MACOSX') &&
                  bibleFileExtensions.contains(ext(f)) &&
                  ext(f) != 'zip',
            )
            .toList()
          ..sort((a, b) => b.size.compareTo(a.size));
    if (inside.isEmpty) {
      return (bible: null, failure: BibleFileFailure(source, BibleFileProblem.unsupported));
    }
    final books = inside.where((f) => const {'usfm', 'sfm', 'ptx'}.contains(ext(f))).toList();
    if (books.length > 1) {
      books.sort((a, b) => a.name.compareTo(b.name));
      final all = [
        for (final book in books) decodeText(Uint8List.fromList(book.content as List<int>)),
      ].join('\n');
      final bible = readUsfm(all, source: source, name: bibleNameFromFile(source));
      return bible.verseCount == 0
          ? (bible: null, failure: BibleFileFailure(source, BibleFileProblem.empty))
          : (bible: bible, failure: null);
    }
    final file = inside.first;
    return readBibleBytes(file.name, Uint8List.fromList(file.content as List<int>), source: source);
  } catch (_) {
    return (bible: null, failure: BibleFileFailure(source, BibleFileProblem.unreadable));
  }
}

/// Reads [path] off the main thread: a whole Bible takes a second or two,
/// which on the UI isolate is a window that stops answering.
Future<BibleFileResult> readBibleFile(String path) => Isolate.run(() => _readPath(path));

BibleFileResult _readPath(String path) {
  try {
    return readBibleBytes(path, File(path).readAsBytesSync());
  } catch (_) {
    return (bible: null, failure: BibleFileFailure(path, BibleFileProblem.unreadable));
  }
}
