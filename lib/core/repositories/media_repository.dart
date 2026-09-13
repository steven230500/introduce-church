import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../models/media_item.dart';
import '../models/storage_usage.dart';

/// The organization's images and videos.
///
/// The bytes live wherever the API was configured to keep them - its own disk
/// for a self-hosted install, a bucket for a hosted plan - and the row is the
/// index, so one call both stores the file and lists it in the library.
class MediaRepository {
  const MediaRepository(this._api);
  final ApiClient _api;

  Future<List<MediaItem>> listMedia() async {
    final rows = await _api.get<List<dynamic>>('/media');
    return (rows ?? []).map((r) => MediaItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<MediaItem> upload(File file, {String? displayName}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: displayName ?? p.basename(file.path),
      ),
    });
    final body = await _api.upload<Map<String, dynamic>>('/media/upload', form);
    return MediaItem.fromJson(body!);
  }

  /// How much of the plan's room is gone.
  ///
  /// Read before an upload, so a file that will be refused is refused now and
  /// not four minutes into sending it.
  Future<StorageUsage> usage() async {
    final body = await _api.get<Map<String, dynamic>>('/media/usage');
    return StorageUsage.fromJson(body ?? const {});
  }

  Future<void> delete(MediaItem item) async {
    await _api.delete<void>('/media/item/${item.id}');
  }
}
