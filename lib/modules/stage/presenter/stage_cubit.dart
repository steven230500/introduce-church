import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/collection_item_type.dart';
import '../../../core/models/slide_template.dart';

class StageSlide {
  const StageSlide({
    required this.content,
    required this.reference,
    required this.template,
    required this.itemTitle,
    required this.slideIndex,
    required this.slideCount,
    this.imagePath,
    this.notes,
    this.chords,
  });

  final String content;
  final String reference;
  final SlideTemplate template;
  final String itemTitle;
  final int slideIndex;
  final int slideCount;
  final String? imagePath;
  final String? notes;
  final String? chords;
}

class StageState {
  const StageState({
    this.current,
    this.next,
    this.isLive = false,
    this.isBlank = false,
    this.countdownActive = false,
    this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
  });

  final StageSlide? current;
  final StageSlide? next;
  final bool isLive;
  final bool isBlank;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final bool overlayVisible;
  final String? overlayText;
}

class StageCubit extends Cubit<StageState> {
  StageCubit(this._supabase, this._userId) : super(const StageState());

  final SupabaseClient _supabase;
  final String _userId;
  StreamSubscription? _sub;
  final Map<String, SlideTemplate> _templateCache = {};

  void init() {
    _sub = _supabase
        .from('presentation_state')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', _userId)
        .listen(_onStateChange, onError: (_) {});
  }

  Future<void> _onStateChange(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      emit(const StageState());
      return;
    }
    final row = rows.first;

    final isLive = row['is_live'] as bool? ?? false;
    final isBlank = row['blank_screen'] as bool? ?? false;
    final countdownActive = row['countdown_active'] as bool? ?? false;
    final countdownEndStr = row['countdown_end'] as String?;
    final overlayVisible = row['overlay_visible'] as bool? ?? false;
    final overlayText = row['overlay_text'] as String?;

    DateTime? countdownEnd;
    if (countdownActive && countdownEndStr != null) {
      countdownEnd = DateTime.parse(countdownEndStr).toLocal();
    }

    final collectionId = row['collection_id'] as String?;
    final itemIndex = (row['current_item_index'] as int?) ?? 0;
    final slideIndex = (row['current_slide_index'] as int?) ?? 0;

    if (collectionId == null) {
      emit(
        StageState(
          isLive: isLive,
          isBlank: isBlank,
          countdownActive: countdownActive,
          countdownEnd: countdownEnd,
          overlayVisible: overlayVisible,
          overlayText: overlayText,
        ),
      );
      return;
    }

    try {
      final data = await _supabase
          .from('collections')
          .select('*, collection_items(*, songs(*, verses(*)))')
          .eq('id', collectionId)
          .single();

      final collection = Collection.fromJson(data);
      final current = await _buildSlide(collection, itemIndex, slideIndex);
      final next = await _buildNextSlide(collection, itemIndex, slideIndex);

      emit(
        StageState(
          current: current,
          next: next,
          isLive: isLive,
          isBlank: isBlank,
          countdownActive: countdownActive,
          countdownEnd: countdownEnd,
          overlayVisible: overlayVisible,
          overlayText: overlayText,
        ),
      );
    } catch (_) {
      emit(const StageState());
    }
  }

  Future<StageSlide?> _buildSlide(Collection col, int itemIndex, int slideIndex) async {
    if (itemIndex >= col.items.length) return null;
    final item = col.items[itemIndex];
    final slides = item.slides;
    if (slides.isEmpty) return null;

    final clamped = slideIndex.clamp(0, slides.length - 1);
    final template = await _resolveTemplate(col, item);
    final refs = item.slideReferences;
    final ref = refs.isNotEmpty ? refs[clamped] : '';

    String? chords;
    if (item.type == CollectionItemType.song && item.song != null) {
      final verses = item.song!.verses;
      if (clamped < verses.length) chords = verses[clamped].chords;
    }

    return StageSlide(
      content: item.type == CollectionItemType.imageSlide ? '' : slides[clamped],
      reference: ref.isNotEmpty ? ref : item.displayTitle,
      template: template,
      itemTitle: item.displayTitle,
      slideIndex: clamped,
      slideCount: slides.length,
      imagePath: item.type == CollectionItemType.imageSlide ? slides[clamped] : null,
      notes: item.notes,
      chords: chords,
    );
  }

  Future<StageSlide?> _buildNextSlide(Collection col, int itemIndex, int slideIndex) async {
    if (itemIndex >= col.items.length) return null;
    final item = col.items[itemIndex];
    final slides = item.slides;

    // Next slide in same item
    if (slideIndex + 1 < slides.length) {
      return _buildSlide(col, itemIndex, slideIndex + 1);
    }
    // First slide of next item
    if (itemIndex + 1 < col.items.length) {
      return _buildSlide(col, itemIndex + 1, 0);
    }
    return null;
  }

  Future<SlideTemplate> _resolveTemplate(Collection col, CollectionItem item) async {
    final id = item.templateId ?? col.templateId;
    if (id == null) return SlideTemplate.defaultTemplate;
    final preset = SlideTemplate.findPreset(id);
    if (preset != null) return preset;
    if (_templateCache.containsKey(id)) return _templateCache[id]!;
    try {
      final row = await _supabase
          .from('templates')
          .select('id, name, config')
          .eq('id', id)
          .single();
      final t = SlideTemplate.fromJson(
        id: row['id'] as String,
        name: row['name'] as String,
        json: row['config'] as Map<String, dynamic>,
      );
      _templateCache[id] = t;
      return t;
    } catch (_) {
      return SlideTemplate.defaultTemplate;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
