import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:introduce_church/core/api/api_client.dart';
import 'package:introduce_church/core/api/presentation_socket.dart';
import 'package:introduce_church/core/backgrounds/background_probe.dart';
import 'package:introduce_church/core/backgrounds/background_standard.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/media_item.dart';
import 'package:introduce_church/core/models/storage_usage.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/models/saved_notice.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/repositories/media_repository.dart';
import 'package:introduce_church/core/song_import/imported_song.dart';
import 'package:introduce_church/modules/songs/children/songs_list/repository/repository.dart';
import 'package:introduce_church/core/repositories/organization_repository.dart';
import 'package:introduce_church/core/repositories/template_repository.dart';
import 'package:introduce_church/core/services/app_prefs_service.dart';
import 'package:introduce_church/modules/presentation/children/control/repository/repository.dart';

import 'builders.dart';

/// An API client wired to a Dio that is never called.
///
/// Repository fakes override every method that would reach the network, so the
/// client exists only to satisfy their constructors.
ApiClient fakeApiClient() => ApiClient(Dio(), FakePrefsService());

/// A socket that reports itself disconnected, so ControlCubit takes the HTTP
/// path and the fake repository sees the write.
class FakePresentationSocket extends PresentationSocket {
  FakePresentationSocket() : super(fakeApiClient(), '');

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}
}

/// Prefs that keep everything in memory.
///
/// The real one writes to the application support directory through
/// path_provider, which has no implementation under `flutter test`.
class FakePrefsService extends AppPrefsService {
  List<Map<String, dynamic>>? saved;
  Map<String, dynamic>? session;

  @override
  Future<void> saveCollections(List<Map<String, dynamic>> raw) async {
    // A copy, as a file on disk would be: the fake repository changes its rows
    // in place, and a cache sharing them would see the future.
    saved = (jsonDecode(jsonEncode(raw)) as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>?> loadCollections() async => saved;

  List<Map<String, dynamic>>? savedTemplates;

  @override
  Future<void> saveTemplates(List<Map<String, dynamic>> raw) async {
    savedTemplates = raw;
  }

  @override
  Future<List<Map<String, dynamic>>?> loadTemplates() async => savedTemplates;

  String? bibleVersionCode;

  @override
  Future<String?> bibleVersion() async => bibleVersionCode;

  @override
  Future<void> setBibleVersion(String code) async {
    bibleVersionCode = code;
  }

  int? gridZoom;

  @override
  Future<void> saveGridZoom(int zoom) async {
    gridZoom = zoom == 0 ? null : zoom;
  }

  @override
  Future<int?> loadGridZoom() async => gridZoom;

  Map<String, dynamic>? waiting;

  @override
  Future<Map<String, dynamic>?> loadWaiting() async => waiting;

  Map<String, dynamic>? remote;

  @override
  Future<Map<String, dynamic>?> loadRemote() async => remote;

  @override
  Future<void> saveRemote(Map<String, dynamic> value) async {
    remote = value;
  }

  Map<String, dynamic>? streamStyle;

  @override
  Future<Map<String, dynamic>?> loadStreamStyle() async => streamStyle;

  @override
  Future<void> saveStreamStyle(Map<String, dynamic> style) async {
    streamStyle = style;
  }

  @override
  Future<void> saveWaiting(Map<String, dynamic> config) async {
    waiting = config;
  }

  /// The chosen language, or null while the machine follows the computer.
  String? locale;

  @override
  Future<String?> getLocale() async => locale;

  @override
  Future<void> setLocale(String? code) async {
    locale = code;
    languageWasAsked = true;
  }

  bool languageWasAsked = false;

  @override
  Future<bool> languageAsked() async => languageWasAsked || locale != null;

  @override
  Future<void> setLanguageAsked() async => languageWasAsked = true;

  /// Whether the computer counts as one that was in use before.
  bool used = false;

  @override
  Future<bool> hasBeenUsed() async => used || session != null || saved != null;

  Map<String, double>? layout;

  @override
  Future<void> saveLayout(Map<String, double> widths) async {
    layout = widths;
  }

  @override
  Future<Map<String, double>?> loadLayout() async => layout;

  @override
  Future<Map<String, dynamic>?> loadSession() async => session;

  @override
  Future<void> saveSession(Map<String, dynamic> value) async {
    session = value;
  }

  @override
  Future<void> clearSession() async {
    session = null;
  }
}

/// A stored session, expiring in [inSeconds].
///
/// Negative means it already has, which is the state a machine is in fifteen
/// minutes into a service.
Map<String, dynamic> storedSession({int inSeconds = 900}) => {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'user': {'id': 'u1', 'email': 'operador@iglesia.test', 'display_name': 'Operador'},
  'expires_at': DateTime.now().add(Duration(seconds: inSeconds)).toIso8601String(),
  'org_id': 'org-1',
};

/// Control repository that serves canned rows and records what was asked of it,
/// so cubit behaviour can be asserted without a server.
class FakeControlRepository extends ControlRepository {
  FakeControlRepository({this.rows = const []}) : super(fakeApiClient());

  /// Rows returned by [getCollectionsRaw], in the API's wire shape.
  List<Map<String, dynamic>> rows;

  /// Throw this on the next read, to exercise the offline and error paths.
  Object? failWith;

  /// While set, reads wait for it.
  Future<void>? readGate;

  /// Throw this on every write until it is cleared, to exercise the queue that
  /// holds changes made with no network.
  Object? failWritesWith;

  int reads = 0;
  int syncs = 0;

  /// The position of the last state published, so a test can check that what
  /// went out to the projector is the live one and not the operator's cursor.
  (int item, int slide)? lastSync;

  final List<String> calls = [];

  @override
  Future<List<Map<String, dynamic>>> getCollectionsRaw() async {
    reads++;
    // Holds the answer back, so a test can act while a reload is on its way.
    final gate = readGate;
    if (gate != null) await gate;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    return rows;
  }

  @override
  Future<void> upsertPresentationState(Map<String, dynamic> state) async {
    syncs++;
    lastSync = (state['current_item_index'] as int, state['current_slide_index'] as int);
    lastState = state;
  }

  /// Everything the last write carried.
  Map<String, dynamic>? lastState;

  // Writes mutate `rows` so the next read returns different data, the way a
  // real backend would. Without this a reload emits a state equal to the
  // previous one, bloc suppresses it, and a test can't tell a working refresh
  // from a broken one.
  /// Adds rows the way the server does: under the ids the app chose, at the
  /// end of the running order, skipping an id it already has.
  @override
  Future<void> addItems(String collectionId, List<CollectionItem> items) async {
    _checkNetwork('addItems');
    if (items.isEmpty) return;
    calls.add('addItems:${items.length}');
    final target = _items(collectionId);
    for (final item in items) {
      calls.add(switch (item.type) {
        CollectionItemType.song => 'addSong:${item.song?.id}',
        CollectionItemType.bibleVerse => 'addVerse:${item.displayTitle}',
        _ => 'add:${item.type.value}',
      });
      if (target.any((row) => row['id'] == item.id)) continue;
      target.add({...item.toJson(), 'collection_id': collectionId, 'item_order': target.length});
    }
  }

  @override
  Future<void> removeItemFromCollection(String itemId) async {
    _checkNetwork();
    calls.add('removeItem:$itemId');
    for (final row in rows) {
      final items = List<Map<String, dynamic>>.from(row['collection_items'] as List)
        ..removeWhere((i) => i['id'] == itemId);
      for (final (order, item) in items.indexed) {
        item['item_order'] = order;
      }
      row['collection_items'] = items;
    }
  }

  List<Map<String, dynamic>> _items(String collectionId) {
    final row = rows.firstWhere((r) => r['id'] == collectionId);
    // A copy, not a cast: a builder's default is a const list, and casting one
    // hands back a view that cannot be added to.
    final items = List<Map<String, dynamic>>.from(row['collection_items'] as List);
    row['collection_items'] = items;
    return items;
  }

  /// Every write goes through here, so one switch turns the network off for
  /// all of them at once.
  void _checkNetwork([String call = '']) {
    final failure = failWritesWith;
    if (failure != null) throw failure;
    // The network dropping for one request and not another, as it does when
    // the wifi comes back halfway through sending a queue.
    if (networkDownFor?.call(call) ?? false) {
      throw const SocketException('Network is unreachable');
    }
  }

  /// Fails the writes this picks out - by the call name, `createCollection`,
  /// `addItems` and so on - as if the network were down for just those.
  bool Function(String call)? networkDownFor;

  @override
  Future<void> updateItemAutoAdvance(String itemId, int? secs) async {
    _checkNetwork();
    calls.add('autoAdvance:$itemId:$secs');
  }

  @override
  Future<void> updateItemPlanned(String itemId, int? secs) async {
    _checkNetwork();
    calls.add('planned:$itemId:$secs');
  }

  @override
  Future<void> updateItemTitle(String itemId, String title) async {
    _checkNetwork();
    calls.add('title:$itemId:$title');
    for (final row in rows) {
      for (final item in (row['collection_items'] as List).cast<Map<String, dynamic>>()) {
        if (item['id'] != itemId) continue;
        final content = Map<String, dynamic>.from(
          (item['content_json'] as Map?)?.cast<String, dynamic>() ?? {},
        );
        content['title'] = title;
        item['content_json'] = content;
      }
    }
  }

  // Applies the new order the way the server does, so a test can read the set
  // list back and see where an item actually landed.
  @override
  Future<void> reorderItems(String collectionId, List<String> orderedIds) async {
    _checkNetwork();
    calls.add('reorder:${orderedIds.join(",")}');
    final items = _items(collectionId)
      ..sort(
        (a, b) =>
            orderedIds.indexOf(a['id'] as String).compareTo(orderedIds.indexOf(b['id'] as String)),
      );
    for (var i = 0; i < items.length; i++) {
      items[i]['item_order'] = i;
    }
  }

  @override
  Future<void> updateItemContent(String itemId, Map<String, dynamic> content) async {
    _checkNetwork();
    calls.add('content:$itemId:${content.keys.join(",")}');
    for (final row in rows) {
      for (final item in (row['collection_items'] as List).cast<Map<String, dynamic>>()) {
        if (item['id'] != itemId) continue;
        item['content_json'] = {
          ...(item['content_json'] as Map?)?.cast<String, dynamic>() ?? const {},
          ...content,
        };
      }
    }
  }

  @override
  Future<void> updateSong(Song song) async {
    _checkNetwork();
    calls.add('song:${song.id}:${song.verses.length}');
    // Every service that sings it gets the new words, as on the server.
    for (final row in rows) {
      for (final item in (row['collection_items'] as List).cast<Map<String, dynamic>>()) {
        final stored = item['songs'] as Map?;
        if (stored == null || stored['id'] != song.id) continue;
        item['songs'] = song.toJson();
      }
    }
  }

  @override
  Future<void> updateItemNotes(String itemId, String? notes) async {
    _checkNetwork();
    calls.add('notes:$itemId:$notes');
  }

  @override
  Future<void> createCollection({
    required String id,
    required String name,
    DateTime? serviceDate,
  }) async {
    _checkNetwork('createCollection');
    calls.add('createCollection:$name');
    // A repeat of the same id is the same service, as on the server.
    if (rows.any((row) => row['id'] == id)) return;
    rows = [
      ...rows,
      collectionRow(id: id, name: name, serviceDate: serviceDate?.toIso8601String()),
    ];
  }

  @override
  Future<void> deleteCollection(String id) async {
    _checkNetwork();
    calls.add('deleteCollection:$id');
    rows = [
      for (final row in rows)
        if (row['id'] != id) row,
    ];
  }
}

/// Template repository backed by a plain list.
class FakeTemplateRepository extends TemplateRepository {
  FakeTemplateRepository({this.templates = const []}) : super(fakeApiClient());

  List<SlideTemplate> templates;
  final List<String> calls = [];

  @override
  Future<List<SlideTemplate>> getTemplates() async => templates;

  // The cubit reads the raw rows so it can cache them for a service with no
  // internet. Without this override the fake falls through to a real request.
  @override
  Future<List<Map<String, dynamic>>> getTemplatesRaw() async => [
    for (final template in templates)
      {'id': template.id, 'name': template.name, 'config': template.toJson()},
  ];

  /// Throw this on a save, to exercise a Sunday with no internet.
  Object? failSaveWith;

  /// Saves the way the server does: a preset id or an empty one means a new
  /// design, which comes back under an id of its own.
  @override
  Future<SlideTemplate> saveTemplate(SlideTemplate t) async {
    final failure = failSaveWith;
    if (failure != null) throw failure;
    final isNew = t.id.startsWith('preset_') || t.id.isEmpty;
    final saved = isNew ? t.copyWith(id: 'custom_${templates.length + 1}') : t;
    calls.add('saveTemplate:${saved.id}');
    templates = [
      for (final existing in templates)
        if (existing.id != saved.id) existing,
      saved,
    ];
    return saved;
  }

  @override
  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    calls.add('collectionTemplate:$collectionId:$templateId');
  }

  @override
  Future<void> setItemTemplate(String itemId, String? templateId) async {
    calls.add('itemTemplate:$itemId:$templateId');
  }
}

/// An API client that fails the way a machine with no internet fails.
///
/// A projector window must draw from what the control window handed it, so any
/// call that reaches for the network here is a bug this makes visible.
class OfflineApiClient extends ApiClient {
  OfflineApiClient() : super(Dio(), FakePrefsService());

  int calls = 0;

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls++;
    throw const ApiException('sin conexión');
  }
}

/// Organization repository backed by a list, so the notices dialog can be
/// driven without a server.
class FakeOrganizationRepository extends OrganizationRepository {
  FakeOrganizationRepository({this.notices = const []}) : super(fakeApiClient());

  List<SavedNotice> notices;
  List<int> palette = const [];

  @override
  Future<List<SavedNotice>> getNotices() async => notices;

  @override
  Future<List<SavedNotice>> setNotices(List<SavedNotice> next) async {
    notices = next;
    return next;
  }

  @override
  Future<List<int>> getPalette() async => palette;

  @override
  Future<List<int>> setPalette(List<int> next) async {
    palette = next;
    return next;
  }
}

/// The church's backgrounds, in memory.
class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository({List<MediaItem>? backgrounds, this.maxUploadBytes = 500 << 20})
    : backgrounds = backgrounds ?? [],
      super(fakeApiClient());

  List<MediaItem> backgrounds;
  int maxUploadBytes;

  /// What was sent, so a test can say nothing was.
  final uploads = <BackgroundCandidate>[];
  final posters = <File?>[];
  final deleted = <String>[];

  /// When set, the upload fails with it, the way the server refuses.
  ApiException? refuse;

  @override
  Future<List<MediaItem>> listBackgrounds() async => backgrounds;

  @override
  Future<StorageUsage> usage() async => StorageUsage(
    plan: 'free',
    label: 'Gratis',
    usedBytes: 0,
    totalBytes: 500 << 20,
    maxUploadBytes: maxUploadBytes,
  );

  @override
  Future<MediaItem> uploadBackground(
    BackgroundCandidate candidate, {
    File? poster,
    void Function(double progress)? onProgress,
  }) async {
    if (refuse != null) throw refuse!;
    uploads.add(candidate);
    posters.add(poster);
    onProgress?.call(0.5);
    onProgress?.call(1);
    final video = candidate.kind == BackgroundKind.video;
    final item = MediaItem(
      id: 'bg${uploads.length}',
      name: candidate.path.split('/').last.split('.').first,
      url: 'https://media.test/${video ? 'videos' : 'images'}/${uploads.length}',
      storagePath: 'x',
      mediaType: video ? MediaType.video : MediaType.image,
      isBackground: true,
      width: candidate.width,
      height: candidate.height,
      durationMs: candidate.duration?.inMilliseconds,
      posterUrl: video && poster != null ? 'https://media.test/images/poster' : null,
    );
    backgrounds = [item, ...backgrounds];
    return item;
  }

  @override
  Future<void> delete(MediaItem item) async {
    deleted.add(item.id);
    backgrounds = backgrounds.where((b) => b.id != item.id).toList();
  }
}

/// Answers for files by name, without reading any.
class FakeBackgroundProbe extends BackgroundProbe {
  const FakeBackgroundProbe(this.files, {this.still});

  final Map<String, BackgroundCandidate> files;
  final File? still;

  @override
  Future<BackgroundCandidate> read(String path) async =>
      files[path] ?? BackgroundCandidate(path: path, bytes: 0);

  @override
  Future<File?> poster(String videoPath) async => still;
}

/// The song library, in memory.
class FakeSongsRepository extends SongsListRepository {
  FakeSongsRepository({List<Song>? songs}) : songs = songs ?? [], super(fakeApiClient());

  List<Song> songs;

  /// Every import request, as the songs it carried.
  final requests = <List<ImportedSong>>[];

  /// The saves the song form made.
  final saved = <Map<String, Object?>>[];

  /// Fails the import request with this number (1-based), after the ones
  /// before it went through.
  int? failOnRequest;

  @override
  Future<List<Song>> getSongs({String? search}) async => songs;

  @override
  Future<int> importSongs(List<ImportedSong> songs, {void Function(int done)? onProgress}) async {
    var done = 0;
    for (var start = 0; start < songs.length; start += SongsListRepository.importChunk) {
      if (failOnRequest == requests.length + 1) {
        throw const ApiException('sin conexión');
      }
      final piece = songs.sublist(
        start,
        (start + SongsListRepository.importChunk).clamp(0, songs.length),
      );
      requests.add(piece);
      done += piece.length;
      onProgress?.call(done);
    }
    return done;
  }

  @override
  Future<Song> saveSong({
    String? id,
    required String title,
    String? author,
    String? copyright,
    String? ccliNumber,
    required List<({String type, String content, String? chords})> verses,
  }) async {
    saved.add({'id': id, 'title': title, 'copyright': copyright, 'ccli': ccliNumber});
    return Song(id: id ?? 'new', title: title, copyright: copyright, ccliNumber: ccliNumber);
  }
}
