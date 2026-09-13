import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies of the church's background files on this machine's disk.
///
/// A loop behind the lyrics plays for the whole service, over and over. Played
/// from the server it is downloaded again on every lap, it stutters when the
/// church wifi does, and on the Sunday the building has no internet it is not
/// there at all. So the first time a background is played it is also saved,
/// and every time after that it plays from here.
class BackgroundCache {
  BackgroundCache({Directory? directory, Dio? dio})
    : _override = directory,
      _dio = dio ?? Dio(),
      _enabled = true;

  /// A cache that never saves anything and always answers with the address it
  /// was given.
  ///
  /// For tests, which have no application support directory: asking for one
  /// inside a widget test waits on a platform channel that never answers.
  BackgroundCache.disabled() : _override = null, _dio = null, _enabled = false;

  static BackgroundCache instance = BackgroundCache();

  final Directory? _override;
  final Dio? _dio;
  final bool _enabled;

  final _inFlight = <String, Future<void>>{};
  Directory? _resolved;

  Future<Directory> _directory() async {
    if (_resolved != null) return _resolved!;
    final base = _override ?? await getApplicationSupportDirectory();
    return _resolved = Directory(p.join(base.path, 'backgrounds'));
  }

  static bool _isRemote(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  /// The file a remote address is saved as. Named by a hash of the address, so
  /// the same background uploaded twice is two files and one address is never
  /// two.
  Future<File> _fileFor(String url) async {
    final ext = p.extension(Uri.tryParse(url)?.path ?? '').toLowerCase();
    return File(p.join((await _directory()).path, '${_fnv1a(url)}$ext'));
  }

  /// What to play for [source]: the copy on disk when there is one, otherwise
  /// the address itself - with a copy started for next time.
  Future<String> playable(String source) async {
    if (!_enabled || !_isRemote(source)) return source;
    try {
      final file = await _fileFor(source);
      if (await file.exists()) return file.path;
      unawaited(save(source));
    } catch (_) {
      // A cache that cannot be written is a slower Sunday, not a broken one.
    }
    return source;
  }

  /// Downloads [url] to disk, once, however many times it is asked for.
  Future<void> save(String url) {
    if (!_enabled || !_isRemote(url)) return Future.value();
    // A block, not an arrow: remove() returns the future being completed, and
    // whenComplete waits on a future its callback returns - so an arrow here
    // has the download wait on itself forever.
    return _inFlight[url] ??= _download(url).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<void> _download(String url) async {
    final file = await _fileFor(url);
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    // Into a partial file first and renamed at the end, so a download cut off
    // halfway is never mistaken for the whole loop next time.
    final partial = File('${file.path}.part');
    try {
      await _dio!.download(url, partial.path);
      await partial.rename(file.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
    }
  }

  /// Keeps a file that is already on this machine as the copy of [url].
  ///
  /// For the operator who has just uploaded it: the bytes are right here, and
  /// downloading them back from the server would be the upload again in
  /// reverse.
  Future<void> adopt(String url, File local) async {
    if (!_enabled || !_isRemote(url)) return;
    try {
      final file = await _fileFor(url);
      if (await file.exists()) return;
      await file.parent.create(recursive: true);
      await local.copy(file.path);
    } catch (_) {
      // Next time it plays it will be downloaded instead.
    }
  }
}

/// FNV-1a over the address, as hex. Not for security: for a file name that is
/// the same on every run, which String.hashCode does not promise.
String _fnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    // Native ints are 64 bits and wrap, which is the arithmetic FNV wants.
    hash *= 0x100000001b3;
  }
  // In two halves: an int with its top bit set is negative, and its radix
  // string starts with a minus sign.
  String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
  return half(hash >>> 32) + half(hash & 0xFFFFFFFF);
}
