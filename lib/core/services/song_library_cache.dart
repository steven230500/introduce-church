import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The song library as it was last downloaded, for a service with no internet.
///
/// Without it the songs panel shows an error the moment the router is off, and
/// a song cannot be added to the plan - the one thing a worship team changes
/// most often, standing in the room where the service is.
///
/// A file of its own rather than a key in the preferences: a library brought
/// over from another program runs to thousands of songs, and the preferences
/// file is rewritten whole every time a panel is dragged.
class SongLibraryCache {
  SongLibraryCache({File? file}) : _override = file, _onDisk = true;

  /// A cache that forgets when the process does, for tests: asking for the
  /// application support directory inside a widget test never answers.
  SongLibraryCache.inMemory() : _override = null, _onDisk = false;

  final File? _override;
  final bool _onDisk;
  List<Map<String, dynamic>>? _rows;

  Future<File> get _file async {
    if (_override != null) return _override;
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'songs_cache.json'));
  }

  Future<void> save(List<Map<String, dynamic>> rows) async {
    _rows = rows;
    if (!_onDisk) return;
    final file = await _file;
    await file.parent.create(recursive: true);
    // Written aside and moved into place, so a laptop that dies mid-write
    // keeps last week's library rather than half of this one.
    final part = File('${file.path}.part');
    await part.writeAsString(jsonEncode(rows));
    await part.rename(file.path);
  }

  /// The last library saved, or null when there has never been one.
  Future<List<Map<String, dynamic>>?> load() async {
    if (_rows != null || !_onDisk) return _rows;
    try {
      final file = await _file;
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return _rows = decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
