import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/media_item.dart';
import '../services/introduce_api_service.dart';
import '../services/supabase_service.dart';

const _bucket = 'org-media';
const _apiCategories = {'images', 'audio', 'videos'};
const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.webm'};
const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'};

class MediaRepository {
  const MediaRepository(this._supabase, this._api);
  final SupabaseService _supabase;
  final IntroduceApiService _api;

  Future<List<MediaItem>> listMedia() async {
    final rows = await _supabase.client
        .from('media_items')
        .select()
        .order('created_at', ascending: false);
    return rows.map(MediaItem.fromJson).toList();
  }

  Future<MediaItem> upload(File file, {String? displayName}) async {
    final userId = _supabase.currentUser!.id;
    final orgId = _supabase.orgId;
    final ext = p.extension(file.path).toLowerCase();
    final name = displayName ?? p.basenameWithoutExtension(file.path);
    final mediaType = _videoExts.contains(ext) ? MediaType.video : MediaType.image;

    final result = await _api.upload(file);

    final row = await _supabase.client
        .from('media_items')
        .insert({
          'user_id': userId,
          if (orgId != null) 'org_id': orgId,
          'name': name,
          'url': result.url,
          'storage_path': result.storagePath,
          'media_type': mediaType.value,
          'size_bytes': result.sizeBytes,
        })
        .select()
        .single();

    return MediaItem.fromJson(row);
  }

  Future<void> delete(MediaItem item) async {
    final parts = item.storagePath.split('/');
    if (parts.length == 2 && _apiCategories.contains(parts[0])) {
      await _api.delete(parts[0], parts[1]);
    } else {
      // Legacy items stored in Supabase Storage
      await _supabase.client.storage.from(_bucket).remove([item.storagePath]);
    }
    await _supabase.client.from('media_items').delete().eq('id', item.id);
  }

  static bool isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return _imageExts.contains(ext) || _videoExts.contains(ext);
  }

  static MediaType typeOf(String path) {
    final ext = p.extension(path).toLowerCase();
    return _videoExts.contains(ext) ? MediaType.video : MediaType.image;
  }
}
