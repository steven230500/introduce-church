import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../utils/text_encoding.dart';
import 'formats/book_list.dart';
import 'formats/freeshow.dart';
import 'formats/osis.dart';
import 'formats/xml_bible.dart';
import 'formats/xml_support.dart';
import 'imported_bible.dart';

/// Every extension a Bible can be read from.
const bibleFileExtensions = ['xml', 'osis', 'json', 'fsb', 'zip'];

/// A file read: a Bible, or why it is not one.
typedef BibleFileResult = ({ImportedBible? bible, BibleFileFailure? failure});

/// Reads one file's bytes as a Bible, working out which program wrote it from
/// what is inside: extensions are shared (every one of the XML formats is a
/// .xml), the first element is not.
BibleFileResult readBibleBytes(String path, Uint8List bytes, {String? source}) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  final name = p.basenameWithoutExtension(path).replaceAll('_', ' ').trim();
  final from = source ?? path;
  BibleFileResult failed(BibleFileProblem problem) =>
      (bible: null, failure: BibleFileFailure(from, problem));

  if (!bibleFileExtensions.contains(ext)) return failed(BibleFileProblem.unsupported);
  if (ext == 'zip') return _readZip(bytes, from);

  try {
    final text = decodeText(bytes).trimLeft();
    final ImportedBible bible;
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
        case 'bible' when shape.firstChild == 'b':
          bible = readOpenSong(text, source: from, name: name);
        case 'bible':
          bible = readBeblia(text, source: from, name: name);
        default:
          return failed(BibleFileProblem.unsupported);
      }
    } else {
      return failed(BibleFileProblem.unsupported);
    }
    if (bible.verseCount == 0) return failed(BibleFileProblem.empty);
    return (bible: bible, failure: null);
  } catch (_) {
    return failed(BibleFileProblem.unreadable);
  }
}

/// Some Bibles are passed around zipped. The biggest file inside that is one
/// of the kinds above is the Bible; the rest are readmes and licences.
BibleFileResult _readZip(Uint8List bytes, String source) {
  try {
    final inside =
        ZipDecoder()
            .decodeBytes(bytes)
            .files
            .where(
              (f) =>
                  f.isFile &&
                  !f.name.contains('__MACOSX') &&
                  bibleFileExtensions.contains(
                    p.extension(f.name).replaceFirst('.', '').toLowerCase(),
                  ) &&
                  !f.name.toLowerCase().endsWith('.zip'),
            )
            .toList()
          ..sort((a, b) => b.size.compareTo(a.size));
    if (inside.isEmpty) {
      return (bible: null, failure: BibleFileFailure(source, BibleFileProblem.unsupported));
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
