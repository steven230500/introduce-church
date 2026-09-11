import 'package:dio/dio.dart';

class LyricSearchResult {
  const LyricSearchResult({required this.title, required this.artist});
  final String title;
  final String artist;
}

class LyricSearchService {
  LyricSearchService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  final Dio _dio;

  static const _suggestBase = 'https://api.lyrics.ovh/suggest';
  static const _lyricsBase = 'https://api.lyrics.ovh/v1';

  Future<List<LyricSearchResult>> search(String query) async {
    final resp = await _dio.get('$_suggestBase/${Uri.encodeComponent(query)}');
    final data = (resp.data['data'] as List?) ?? [];
    return data
        .map(
          (e) =>
              LyricSearchResult(title: e['title'] as String, artist: e['artist']['name'] as String),
        )
        .take(15)
        .toList();
  }

  Future<String?> fetchLyrics(String artist, String title) async {
    final url = '$_lyricsBase/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}';
    try {
      final resp = await _dio.get(url);
      return resp.data['lyrics'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
