import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../models/media_item.dart';

/// The organization's images and videos.
///
/// The bytes live on the API's disk and the row is its index, so one call both
/// stores the file and lists it in the library.
class MediaRepository {
  const MediaRepository(this._api);
  final ApiClient _api;

  Future<List<MediaItem>> listMedia() async {
    final rows = await _api.get<List<dynamic>>('/media');
    return (rows ?? [])
        .map((r) => MediaItem.fromJson(r as Map<String, dynamic>))
        .toList();
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

  Future<void> delete(MediaItem item) async {
    await _api.delete<void>('/media/item/${item.id}');
  }
}
