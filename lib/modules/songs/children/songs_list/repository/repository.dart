import '../../../../../core/api/api_client.dart';
import '../../../../../core/models/song.dart';
import '../../../../../core/song_import/imported_song.dart';
import '../../../../../core/utils/app_logger.dart';

class SongsListRepository {
  const SongsListRepository(this._api);
  final ApiClient _api;

  Future<List<Song>> getSongs({String? search}) async {
    appLogger.d('SongsListRepository.getSongs | search: $search');
    final rows = await _api.get<List<dynamic>>('/songs', query: {'search': ?search});
    return (rows ?? []).map((j) => Song.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Creates or replaces a song, verses included.
  ///
  /// One request rather than a save followed by a verse rewrite: the editor
  /// hands back the whole song, and two requests could leave a song stored
  /// with the previous set of verses if the second one failed.
  Future<Song> saveSong({
    String? id,
    required String title,
    String? author,
    String? copyright,
    String? ccliNumber,
    required List<({String type, String content, String? chords})> verses,
  }) async {
    appLogger.d('SongsListRepository.saveSong | id: $id title: $title');

    final payload = {
      'title': title,
      'author': author,
      'copyright': copyright,
      'ccli_number': ccliNumber,
      'language': 'es',
      'tags': <String>[],
      'verses': [
        for (final (index, verse) in verses.indexed)
          {
            'type': verse.type,
            'verse_order': index,
            'content': verse.content,
            'chords': ?verse.chords,
          },
      ],
    };

    final body = id == null
        ? await _api.post<Map<String, dynamic>>('/songs', data: payload)
        : await _api.put<Map<String, dynamic>>('/songs/$id', data: payload);

    return Song.fromJson(body!);
  }

  /// How many songs go in one import request. The server takes up to two
  /// hundred; fewer keeps each request quick on church wifi, and a dropped
  /// connection costs one piece of the library rather than all of it.
  static const importChunk = 100;

  /// Adds songs brought over from another program, a piece at a time, and
  /// returns how many were added.
  ///
  /// Each piece is all or nothing on the server. If one fails, the pieces
  /// before it are already in the library and the error says so through
  /// [onProgress], which has been told how many made it.
  Future<int> importSongs(List<ImportedSong> songs, {void Function(int done)? onProgress}) async {
    var done = 0;
    for (var start = 0; start < songs.length; start += importChunk) {
      final piece = songs.sublist(start, (start + importChunk).clamp(0, songs.length));
      await _api.post<Map<String, dynamic>>(
        '/songs/import',
        data: {
          'songs': [
            for (final song in piece)
              {
                'title': song.title,
                'author': song.author,
                'copyright': song.copyright,
                'ccli_number': song.ccliNumber,
                'language': 'es',
                'tags': <String>[],
                'verses': [
                  for (final (index, verse) in song.verses.indexed)
                    {'type': verse.type.value, 'verse_order': index, 'content': verse.content},
                ],
              },
          ],
        },
      );
      done += piece.length;
      onProgress?.call(done);
    }
    return done;
  }

  Future<void> deleteSong(String id) async {
    appLogger.d('SongsListRepository.deleteSong | id: $id');
    await _api.delete<void>('/songs/$id');
  }
}
