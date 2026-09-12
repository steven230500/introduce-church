import 'package:dio/dio.dart';
import 'package:introduce_church/core/api/api_client.dart';
import 'package:introduce_church/core/api/presentation_socket.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/models/song.dart';
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

  @override
  Future<void> saveCollections(List<Map<String, dynamic>> raw) async {
    saved = raw;
  }

  @override
  Future<List<Map<String, dynamic>>?> loadCollections() async => saved;
}

/// Control repository that serves canned rows and records what was asked of it,
/// so cubit behaviour can be asserted without a server.
class FakeControlRepository extends ControlRepository {
  FakeControlRepository({this.rows = const []}) : super(fakeApiClient());

  /// Rows returned by [getCollectionsRaw], in the API's wire shape.
  List<Map<String, dynamic>> rows;

  /// Throw this on the next read, to exercise the offline and error paths.
  Object? failWith;

  int reads = 0;
  int syncs = 0;
  final List<String> calls = [];

  @override
  Future<List<Map<String, dynamic>>> getCollectionsRaw() async {
    reads++;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    return rows;
  }

  @override
  Future<void> upsertPresentationState({
    required String? collectionId,
    required int itemIndex,
    required int slideIndex,
    required bool isLive,
    required bool blankScreen,
    bool countdownActive = false,
    DateTime? countdownEnd,
    bool overlayVisible = false,
    String? overlayText,
  }) async {
    syncs++;
  }

  // Writes mutate `rows` so the next read returns different data, the way a
  // real backend would. Without this a reload emits a state equal to the
  // previous one, bloc suppresses it, and a test can't tell a working refresh
  // from a broken one.
  @override
  Future<void> addSongToCollection({
    required String collectionId,
    required String songId,
    required int order,
  }) async {
    calls.add('addSong:$songId');
    _items(
      collectionId,
    ).add(songItemRow(id: 'item-$songId', collectionId: collectionId, order: order, title: songId));
  }

  @override
  Future<void> removeItemFromCollection(String itemId) async {
    calls.add('removeItem:$itemId');
    for (final row in rows) {
      (row['collection_items'] as List).removeWhere((i) => i['id'] == itemId);
    }
  }

  List<Map<String, dynamic>> _items(String collectionId) {
    final row = rows.firstWhere((r) => r['id'] == collectionId);
    final items = (row['collection_items'] as List).cast<Map<String, dynamic>>();
    row['collection_items'] = items;
    return items;
  }

  @override
  Future<void> restoreItem(CollectionItem item) async {
    calls.add('restore:${item.displayTitle}');
    final items = _items(item.collectionId);
    items.add({
      'id': 'restored-${item.id}',
      'collection_id': item.collectionId,
      'item_type': item.type.value,
      'item_order': items.length,
      'template_id': item.templateId,
      'content_json': item.contentJson,
      'notes': item.notes,
      'auto_advance_secs': item.autoAdvanceSecs,
      // The server rehydrates the song from song_id on the way back out, so
      // the fake has to hand the row its song too or a restored song item
      // comes back with no title.
      'songs': ?_songRow(item.song),
    });
  }

  static Map<String, dynamic>? _songRow(Song? song) => song == null
      ? null
      : {
          'id': song.id,
          'title': song.title,
          'author': song.author,
          'language': song.language,
          'tags': song.tags,
          'verses': [
            for (final verse in song.verses)
              {
                'id': verse.id,
                'song_id': verse.songId,
                'type': verse.type.name,
                'verse_order': verse.order,
                'content': verse.content,
              },
          ],
        };

  @override
  Future<void> updateItemTitle(String itemId, String title) async {
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
  Future<void> updateItemNotes(String itemId, String? notes) async {
    calls.add('notes:$itemId:$notes');
  }

  @override
  Future<Collection> createCollection({required String name, DateTime? serviceDate}) async {
    calls.add('createCollection:$name');
    return Collection(id: 'new-collection', name: name, serviceDate: serviceDate);
  }

  @override
  Future<void> deleteCollection(String id) async {
    calls.add('deleteCollection:$id');
  }
}

/// Template repository backed by a plain list.
class FakeTemplateRepository extends TemplateRepository {
  FakeTemplateRepository({this.templates = const []}) : super(fakeApiClient());

  List<SlideTemplate> templates;
  final List<String> calls = [];

  @override
  Future<List<SlideTemplate>> getTemplates() async => templates;

  @override
  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    calls.add('collectionTemplate:$collectionId:$templateId');
  }

  @override
  Future<void> setItemTemplate(String itemId, String? templateId) async {
    calls.add('itemTemplate:$itemId:$templateId');
  }
}
