import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/api_client.dart';
import 'package:introduce_church/core/services/song_library_cache.dart';
import 'package:introduce_church/modules/songs/children/songs_list/repository/repository.dart';

import '../helpers/fakes.dart';

/// A server that answers until the router is switched off.
class _Server extends ApiClient {
  _Server() : super(Dio(), FakePrefsService());

  bool online = true;
  Object failure = const SocketException('Failed host lookup: api.example.com');

  final library = <Map<String, dynamic>>[
    _song('s1', 'Cuán grande es Él', 'Carl Boberg'),
    _song('s2', 'Sublime gracia', 'John Newton'),
    _song('s3', 'Renuévame', null),
  ];

  static Map<String, dynamic> _song(String id, String title, String? author) => {
    'id': id,
    'title': title,
    'author': author,
    'language': 'es',
    'tags': <String>[],
    'verses': [
      {'id': 'v-$id', 'song_id': id, 'type': 'verse', 'verse_order': 0, 'content': title},
    ],
  };

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (!online) throw failure;
    final search = (query?['search'] as String? ?? '').toLowerCase();
    return library
            .where((row) => '${row['title']} ${row['author']}'.toLowerCase().contains(search))
            .toList()
        as T;
  }
}

void main() {
  late Directory dir;
  late _Server server;
  late SongsListRepository songs;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('song_library');
    server = _Server();
    songs = SongsListRepository(
      server,
      cache: SongLibraryCache(file: File('${dir.path}/songs.json')),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('with no network, the library from the last download answers', () async {
    // Otherwise the songs panel is an error message in exactly the room where
    // a song gets added at the last minute.
    await songs.getSongs();
    server.online = false;

    final offline = await songs.getSongs();

    expect(offline.map((s) => s.title), ['Cuán grande es Él', 'Sublime gracia', 'Renuévame']);
    expect(offline.first.verses, isNotEmpty, reason: 'the words, not just the titles');
  });

  test('it survives the app being closed', () async {
    await songs.getSongs();
    server.online = false;

    final reopened = SongsListRepository(
      server,
      cache: SongLibraryCache(file: File('${dir.path}/songs.json')),
    );

    expect(await reopened.getSongs(), hasLength(3));
  });

  test('searching offline finds by title or author, accents or not', () async {
    await songs.getSongs();
    server.online = false;

    expect((await songs.getSongs(search: 'cuan')).map((s) => s.id), ['s1']);
    expect((await songs.getSongs(search: 'newton')).map((s) => s.id), ['s2']);
  });

  test('a search result is not kept as the whole library', () async {
    await songs.getSongs(search: 'sublime');
    server.online = false;

    await expectLater(songs.getSongs(), throwsA(isA<SocketException>()));
  });

  test('a refused request is not hidden behind the cache', () async {
    await songs.getSongs();
    server
      ..online = false
      ..failure = const ApiException('prohibido', statusCode: 403);

    await expectLater(songs.getSongs(), throwsA(isA<ApiException>()));
  });
}
