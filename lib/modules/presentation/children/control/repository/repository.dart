import '../../../../../core/api/api_client.dart';
import '../../../../../core/local_db/bible_repository.dart';
import '../../../../../core/models/collection.dart';
import '../../../../../core/models/collection_item_type.dart';
import '../../../../../core/utils/app_logger.dart';

/// Everything the presenter reads and writes about service plans.
///
/// Item payloads keep the `content_json` shapes the models already parse, so
/// the slide logic did not have to change when the backend did.
class ControlRepository {
  const ControlRepository(this._api);
  final ApiClient _api;

  Future<List<Collection>> getCollections() async {
    final raw = await getCollectionsRaw();
    return raw.map(Collection.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getCollectionsRaw() async {
    appLogger.d('ControlRepository.getCollectionsRaw');
    final rows = await _api.get<List<dynamic>>('/collections');
    return (rows ?? []).cast<Map<String, dynamic>>();
  }

  // ── Collections ────────────────────────────────────────────────────────────

  Future<Collection> createCollection({required String name, DateTime? serviceDate}) async {
    appLogger.d('ControlRepository.createCollection | name: $name');
    final body = await _api.post<Map<String, dynamic>>(
      '/collections',
      data: {'name': name, 'service_date': ?_date(serviceDate)},
    );
    return Collection.fromJson(body!);
  }

  Future<void> updateCollection({
    required String id,
    required String name,
    DateTime? serviceDate,
  }) async {
    await _api.patch<void>(
      '/collections/$id',
      data: {
        'name': name,
        // Always sent, so clearing the date actually clears it.
        'service_date': _date(serviceDate),
      },
    );
  }

  Future<void> deleteCollection(String id) async {
    await _api.delete<void>('/collections/$id');
  }

  Future<void> updateCollectionBgAudio(String id, String? path) async {
    await _api.patch<void>('/collections/$id', data: {'bg_audio_path': path});
  }

  // ── Items ──────────────────────────────────────────────────────────────────

  Future<void> addSongToCollection({
    required String collectionId,
    required String songId,
    required int order,
  }) => _addItems(collectionId, [
    {'item_type': CollectionItemType.song.value, 'song_id': songId},
  ]);

  Future<void> addBibleVerseToCollection({
    required String collectionId,
    required BibleVerseRef ref,
    required int order,
  }) {
    appLogger.d('ControlRepository.addBibleVerse | ${ref.reference}');
    return _addItems(collectionId, [
      {'item_type': CollectionItemType.bibleVerse.value, 'content_json': ref.toJson()},
    ]);
  }

  Future<void> addFreeSlideToCollection({
    required String collectionId,
    required String text,
    String? title,
    required int order,
  }) => _addItems(collectionId, [
    {
      'item_type': CollectionItemType.freeSlide.value,
      'content_json': {'text': text, 'title': ?title},
    },
  ]);

  Future<void> addFreeSlideBatch({
    required String collectionId,
    required List<String> texts,
    required int startOrder,
    String? templateId,
  }) {
    if (texts.isEmpty) return Future.value();
    return _addItems(collectionId, [
      for (final text in texts)
        {
          'item_type': CollectionItemType.freeSlide.value,
          'content_json': {'text': text},
          'template_id': ?templateId,
        },
    ]);
  }

  Future<void> addSermonToCollection({
    required String collectionId,
    required String title,
    required List<String> points,
    required int order,
  }) {
    appLogger.d('ControlRepository.addSermon | $title | ${points.length} points');
    return _addItems(collectionId, [
      {
        'item_type': CollectionItemType.sermon.value,
        'content_json': {'title': title, 'points': points},
      },
    ]);
  }

  Future<void> addVideoToCollection({
    required String collectionId,
    required String videoPath,
    required String title,
    required int order,
  }) => _addItems(collectionId, [
    {
      'item_type': CollectionItemType.videoSlide.value,
      'content_json': {'path': videoPath, 'title': title},
    },
  ]);

  /// Adds an imported deck as one item holding every page.
  Future<void> addImageSlideBatch({
    required String collectionId,
    required List<String> imagePaths,
    required String title,
    required int startOrder,
  }) {
    appLogger.d('ControlRepository.addImageSlideBatch | $title | ${imagePaths.length}');
    return _addItems(collectionId, [
      {
        'item_type': CollectionItemType.imageSlide.value,
        'content_json': {'title': title, 'paths': imagePaths},
      },
    ]);
  }

  Future<void> addAnnouncement({
    required String collectionId,
    required String message,
    required int order,
    String? title,
    DateTime? timerTarget,
  }) => _addItems(collectionId, [
    {
      'item_type': CollectionItemType.announcement.value,
      'content_json': {
        'message': message,
        'title': ?title,
        'timerTarget': ?timerTarget?.toIso8601String(),
      },
    },
  ]);

  Future<void> removeItemFromCollection(String itemId) async {
    await _api.delete<void>('/collections/items/$itemId');
  }

  /// Puts a deleted item back, carrying everything that was set on it.
  ///
  /// The API only ever appends, so the restored row lands at the end of the
  /// running order and the caller has to move it back to where it was.
  Future<void> restoreItem(CollectionItem item) =>
      _addItems(item.collectionId, [_itemPayload(item)]);

  /// Copies a whole running order into another collection.
  ///
  /// One request, so a fourteen-item plan cannot end up half copied because
  /// the wifi dropped between item six and item seven.
  Future<void> copyItemsInto(String collectionId, List<CollectionItem> items) {
    if (items.isEmpty) return Future.value();
    return _addItems(collectionId, [for (final item in items) _itemPayload(item)]);
  }

  /// Everything about an item that is worth carrying to a new row.
  static Map<String, dynamic> _itemPayload(CollectionItem item) => {
    'item_type': item.type.value,
    'song_id': ?item.song?.id,
    'template_id': ?item.templateId,
    'content_json': ?item.contentJson,
    'notes': ?item.notes,
    'auto_advance_secs': ?item.autoAdvanceSecs,
  };

  /// Renames an item whose title lives in its own content.
  ///
  /// Only the title is sent: the server merges it into content_json, so a
  /// rename cannot overwrite the slide paths or the sermon points that sit
  /// beside it.
  Future<void> updateItemTitle(String itemId, String title) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'title': title});
  }

  Future<void> updateItemNotes(String itemId, String? notes) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'notes': notes});
  }

  Future<void> updateItemAutoAdvance(String itemId, int? secs) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'auto_advance_secs': secs});
  }

  /// Writes a whole new running order in one request, so the set list is never
  /// briefly left with two items claiming the same position.
  Future<void> reorderItems(String collectionId, List<String> orderedIds) async {
    await _api.put<void>('/collections/$collectionId/order', data: {'item_ids': orderedIds});
  }

  // ── Live state ─────────────────────────────────────────────────────────────

  /// Fallback for when the websocket is down. During a service the socket
  /// carries these changes instead.
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
    await _api.put<void>(
      '/presentation/state',
      data: {
        'collection_id': collectionId,
        'current_item_index': itemIndex,
        'current_slide_index': slideIndex,
        'is_live': isLive,
        'blank_screen': blankScreen,
        'countdown_active': countdownActive,
        'countdown_end': countdownEnd?.toUtc().toIso8601String(),
        'overlay_visible': overlayVisible,
        'overlay_text': overlayText,
      },
    );
  }

  Future<void> _addItems(String collectionId, List<Map<String, dynamic>> items) async {
    await _api.post<void>('/collections/$collectionId/items', data: {'items': items});
  }

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
}
