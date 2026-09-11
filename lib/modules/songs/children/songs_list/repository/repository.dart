import '../../../../../core/models/song.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/utils/app_logger.dart';

class SongsListRepository {
  final SupabaseService _supabase;

  SongsListRepository(this._supabase);

  Future<List<Song>> getSongs({String? search}) async {
    appLogger.d('SongsListRepository.getSongs | search: $search');
    var query = _supabase.client.from('songs').select('*, verses(*)');
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    final result = await query.order('title');
    return result.map((j) => Song.fromJson(j)).toList();
  }

  Future<Song> upsertSong({
    String? id,
    required String title,
    String? author,
    String? copyright,
    String? ccliNumber,
  }) async {
    final userId = _supabase.currentUser!.id;
    final data = {
      'title': title,
      'author': author,
      'copyright': copyright,
      'ccli_number': ccliNumber,
      'user_id': userId,
    };
    if (id != null) {
      data['id'] = id;
    } else {
      data['created_by'] = userId;
      if (_supabase.orgId != null) data['org_id'] = _supabase.orgId!;
    }

    appLogger.d('SongsListRepository.upsertSong | id: $id title: $title');
    final result = await _supabase.client
        .from('songs')
        .upsert(data)
        .select('*, verses(*)')
        .single();
    return Song.fromJson(result);
  }

  Future<void> replaceVerses(String songId, List<Map<String, dynamic>> verses) async {
    appLogger.d('SongsListRepository.replaceVerses | songId: $songId count: ${verses.length}');
    await _supabase.client.from('verses').delete().eq('song_id', songId);
    if (verses.isNotEmpty) {
      await _supabase.client.from('verses').insert(verses);
    }
  }

  Future<void> deleteSong(String id) async {
    appLogger.d('SongsListRepository.deleteSong | id: $id');
    await _supabase.client.from('songs').delete().eq('id', id);
  }
}
