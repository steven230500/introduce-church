import '../../../../../core/local_db/bible_repository.dart';
import '../../../../../core/models/collection.dart';
import '../../../../../core/models/collection_item_type.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/utils/app_logger.dart';

class ControlRepository {
  final SupabaseService _supabase;

  ControlRepository(this._supabase);

  Future<List<Collection>> getCollections() async {
    final raw = await getCollectionsRaw();
    return raw.map(Collection.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getCollectionsRaw() async {
    appLogger.d('ControlRepository.getCollectionsRaw');
    final data = await _supabase.client
        .from('collections')
        .select('*, collection_items(*, songs(*, verses(*)))')
        .order('service_date', ascending: false)
        .timeout(const Duration(seconds: 5));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Collection> createCollection({required String name, DateTime? serviceDate}) async {
    final userId = _supabase.currentUser!.id;
    appLogger.d('ControlRepository.createCollection | name: $name');
    final result = await _supabase.client
        .from('collections')
        .insert({
          'user_id': userId,
          'created_by': userId,
          if (_supabase.orgId != null) 'org_id': _supabase.orgId,
          'name': name,
          if (serviceDate != null) 'service_date': serviceDate.toIso8601String().substring(0, 10),
        })
        .select('*, collection_items(*, songs(*, verses(*)))')
        .single();
    return Collection.fromJson(result);
  }

  Future<void> updateCollection({
    required String id,
    required String name,
    DateTime? serviceDate,
  }) async {
    appLogger.d('ControlRepository.updateCollection | id: $id');
    await _supabase.client
        .from('collections')
        .update({
          'name': name,
          if (serviceDate != null) 'service_date': serviceDate.toIso8601String().substring(0, 10),
        })
        .eq('id', id);
  }

  Future<void> deleteCollection(String id) async {
    appLogger.d('ControlRepository.deleteCollection | id: $id');
    await _supabase.client.from('collections').delete().eq('id', id);
  }

  Future<void> addSongToCollection({
    required String collectionId,
    required String songId,
    required int order,
  }) async {
    appLogger.d('ControlRepository.addSongToCollection $collectionId $songId');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.song.value,
      'song_id': songId,
      'item_order': order,
    });
  }

  Future<void> addFreeSlideToCollection({
    required String collectionId,
    required String text,
    required int order,
    String? title,
  }) async {
    appLogger.d('ControlRepository.addFreeSlideToCollection');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.freeSlide.value,
      'item_order': order,
      'content_json': {'text': text, if (title != null && title.isNotEmpty) 'title': title},
    });
  }

  Future<void> removeItemFromCollection(String itemId) async {
    appLogger.d('ControlRepository.removeItemFromCollection | id: $itemId');
    await _supabase.client.from('collection_items').delete().eq('id', itemId);
  }

  Future<void> addBibleVerseToCollection({
    required String collectionId,
    required BibleVerseRef ref,
    required int order,
  }) async {
    appLogger.d('ControlRepository.addBibleVerseToCollection $collectionId ${ref.reference}');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.bibleVerse.value,
      'item_order': order,
      'content_json': ref.toJson(),
    });
  }

  Future<void> addFreeSlideBatch({
    required String collectionId,
    required List<String> texts,
    required int startOrder,
    String? templateId,
  }) async {
    if (texts.isEmpty) return;
    final rows = texts.asMap().entries.map((e) {
      final row = {
        'collection_id': collectionId,
        'item_type': CollectionItemType.freeSlide.value,
        'item_order': startOrder + e.key,
        'content_json': {'text': e.value},
      };
      if (templateId != null) row['template_id'] = templateId;
      return row;
    }).toList();
    await _supabase.client.from('collection_items').insert(rows);
  }

  Future<void> addSermonToCollection({
    required String collectionId,
    required String title,
    required List<String> points,
    required int order,
  }) async {
    appLogger.d('ControlRepository.addSermonToCollection | $title | ${points.length} points');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.sermon.value,
      'item_order': order,
      'content_json': {'title': title, 'points': points},
    });
  }

  Future<void> addVideoToCollection({
    required String collectionId,
    required String videoPath,
    required String title,
    required int order,
  }) async {
    appLogger.d('ControlRepository.addVideoToCollection | $title');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.videoSlide.value,
      'item_order': order,
      'content_json': {'path': videoPath, 'title': title},
    });
  }

  Future<void> addImageSlideBatch({
    required String collectionId,
    required List<String> imagePaths,
    required String title,
    required int startOrder,
  }) async {
    appLogger.d('ControlRepository.addImageSlideBatch | $title | ${imagePaths.length} images');
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.imageSlide.value,
      'item_order': startOrder,
      'content_json': {'title': title, 'paths': imagePaths},
    });
  }

  Future<void> addAnnouncement({
    required String collectionId,
    required String message,
    required int order,
    String? title,
    DateTime? timerTarget,
  }) async {
    await _supabase.client.from('collection_items').insert({
      'collection_id': collectionId,
      'item_type': CollectionItemType.announcement.value,
      'item_order': order,
      'content_json': {
        'message': message,
        if (title != null) 'title': title,
        if (timerTarget != null) 'timerTarget': timerTarget.toIso8601String(),
      },
    });
  }

  Future<void> updateItemNotes(String itemId, String? notes) async {
    await _supabase.client.from('collection_items').update({'notes': notes}).eq('id', itemId);
  }

  Future<void> updateCollectionBgAudio(String id, String? path) async {
    await _supabase.client.from('collections').update({'bg_audio_path': path}).eq('id', id);
  }

  Future<void> updateItemAutoAdvance(String itemId, int? secs) async {
    await _supabase.client
        .from('collection_items')
        .update({'auto_advance_secs': secs})
        .eq('id', itemId);
  }

  Future<void> reorderItems(String collectionId, List<String> orderedIds) async {
    final updates = orderedIds.asMap().entries.map(
      (e) => {'id': e.value, 'collection_id': collectionId, 'item_order': e.key},
    );
    for (final u in updates) {
      await _supabase.client
          .from('collection_items')
          .update({'item_order': u['item_order']})
          .eq('id', u['id']!);
    }
  }

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
    final userId = _supabase.currentUser!.id;
    await _supabase.client.from('presentation_state').upsert({
      'user_id': userId,
      'collection_id': collectionId,
      'current_item_index': itemIndex,
      'current_slide_index': slideIndex,
      'is_live': isLive,
      'blank_screen': blankScreen,
      'countdown_active': countdownActive,
      'countdown_end': countdownEnd?.toUtc().toIso8601String(),
      'overlay_visible': overlayVisible,
      'overlay_text': overlayText,
    }, onConflict: 'user_id');
  }
}
