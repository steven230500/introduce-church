import '../../../../../core/api/api_client.dart';
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

  /// Creates a collection under [id], which the app chose.
  ///
  /// Sending the same id again is not an error, so a queue replayed after a
  /// lost response does not make two services.
  Future<void> createCollection({
    required String id,
    required String name,
    DateTime? serviceDate,
  }) async {
    appLogger.d('ControlRepository.createCollection | name: $name');
    await _api.post<Map<String, dynamic>>(
      '/collections',
      data: {'id': id, 'name': name, 'service_date': ?_date(serviceDate)},
    );
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

  /// Appends [items] to a collection in one request, under the ids they
  /// already carry.
  ///
  /// One request, so a fourteen-item plan cannot end up half copied because
  /// the wifi dropped between item six and item seven. An item the server
  /// already has is skipped, which is what makes a replayed add harmless and
  /// what lets undo put a deleted item back under its own id.
  Future<void> addItems(String collectionId, List<CollectionItem> items) async {
    if (items.isEmpty) return;
    appLogger.d('ControlRepository.addItems | $collectionId | ${items.length}');
    await _api.post<void>(
      '/collections/$collectionId/items',
      data: {
        'items': [for (final item in items) itemPayload(item)],
      },
    );
  }

  Future<void> removeItemFromCollection(String itemId) async {
    await _api.delete<void>('/collections/items/$itemId');
  }

  /// Everything about an item the server stores. The song goes by id: the
  /// server reads the song itself back out of the library.
  static Map<String, dynamic> itemPayload(CollectionItem item) => {
    'id': item.id,
    'item_type': item.type.value,
    'song_id': ?item.song?.id,
    'template_id': ?item.templateId,
    'content_json': ?item.contentJson,
    'notes': ?item.notes,
    'auto_advance_secs': ?item.autoAdvanceSecs,
    'planned_secs': ?item.plannedSecs,
  };

  /// Renames an item whose title lives in its own content.
  ///
  /// Only the title is sent: the server merges it into content_json, so a
  /// rename cannot overwrite the slide paths or the sermon points that sit
  /// beside it.
  Future<void> updateItemTitle(String itemId, String title) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'title': title});
  }

  /// Merges [content] into the item's `content_json`, leaving the keys it does
  /// not name alone.
  ///
  /// A corrected sermon sends its points; the design, the notes and the title
  /// it did not touch stay as they are.
  Future<void> updateItemContent(String itemId, Map<String, dynamic> content) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'content': content});
  }

  Future<void> updateItemNotes(String itemId, String? notes) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'notes': notes});
  }

  Future<void> updateItemAutoAdvance(String itemId, int? secs) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'auto_advance_secs': secs});
  }

  Future<void> updateItemPlanned(String itemId, int? secs) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'planned_secs': secs});
  }

  /// Writes a whole new running order in one request, so the set list is never
  /// briefly left with two items claiming the same position.
  Future<void> reorderItems(String collectionId, List<String> orderedIds) async {
    await _api.put<void>('/collections/$collectionId/order', data: {'item_ids': orderedIds});
  }

  // ── Live state ─────────────────────────────────────────────────────────────

  /// Fallback for when the websocket is down. During a service the socket
  /// carries these changes instead.
  /// Writes the live state as the socket would have carried it.
  ///
  /// The whole of it, not a chosen few fields: this path used to leave out the
  /// stage message, the waiting screen and the timing, so a stage display on
  /// another machine never heard about any of them unless the live link
  /// happened to be connected.
  Future<void> upsertPresentationState(Map<String, dynamic> state) async {
    await _api.put<void>('/presentation/state', data: state);
  }

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
}
