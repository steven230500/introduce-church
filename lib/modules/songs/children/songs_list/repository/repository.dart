import '../../../../../core/api/api_client.dart';
import '../../../../../core/models/song.dart';
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

  Future<void> deleteSong(String id) async {
    appLogger.d('SongsListRepository.deleteSong | id: $id');
    await _api.delete<void>('/songs/$id');
  }
}
