import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/collection_item_type.dart';
import '../../../core/models/slide_template.dart';

sealed class DisplayState {}

class DisplayIdleState extends DisplayState {}

class DisplayBlankState extends DisplayState {}

class DisplaySlideState extends DisplayState {
  final String content;
  final String reference;
  final SlideTemplate template;
  final bool overlayVisible;
  final String? overlayText;
  DisplaySlideState({
    required this.content,
    required this.reference,
    required this.template,
    this.overlayVisible = false,
    this.overlayText,
  });
}

class DisplayImageState extends DisplayState {
  final String imagePath;
  final bool overlayVisible;
  final String? overlayText;
  DisplayImageState({required this.imagePath, this.overlayVisible = false, this.overlayText});
}

class DisplayVideoState extends DisplayState {
  final String videoPath;
  final bool overlayVisible;
  final String? overlayText;
  DisplayVideoState({required this.videoPath, this.overlayVisible = false, this.overlayText});
}

class DisplayCountdownState extends DisplayState {
  final DateTime countdownEnd;
  final bool overlayVisible;
  final String? overlayText;
  DisplayCountdownState({
    required this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
  });
}

class DisplayAnnouncementState extends DisplayState {
  final String message;
  final DateTime? timerTarget;
  final bool overlayVisible;
  final String? overlayText;
  DisplayAnnouncementState({
    required this.message,
    this.timerTarget,
    this.overlayVisible = false,
    this.overlayText,
  });
}

class DisplayCubit extends Cubit<DisplayState> {
  DisplayCubit(this._supabase, this._userId) : super(DisplayIdleState());

  final SupabaseClient _supabase;
  final String _userId;
  StreamSubscription? _sub;

  void init() {
    _sub = _supabase
        .from('presentation_state')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', _userId)
        .listen(_onStateChange, onError: (_) => emit(DisplayIdleState()));
  }

  Future<void> _onStateChange(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      emit(DisplayIdleState());
      return;
    }
    final row = rows.first;
    final isLive = row['is_live'] as bool? ?? false;
    final blank = row['blank_screen'] as bool? ?? false;
    final countdownActive = row['countdown_active'] as bool? ?? false;
    final countdownEndStr = row['countdown_end'] as String?;
    final overlayVisible = row['overlay_visible'] as bool? ?? false;
    final overlayText = row['overlay_text'] as String?;

    // Countdown takes priority over everything
    if (countdownActive && countdownEndStr != null) {
      final end = DateTime.parse(countdownEndStr).toLocal();
      if (end.isAfter(DateTime.now())) {
        emit(
          DisplayCountdownState(
            countdownEnd: end,
            overlayVisible: overlayVisible,
            overlayText: overlayText,
          ),
        );
        return;
      }
    }

    if (!isLive) {
      emit(DisplayIdleState());
      return;
    }
    if (blank) {
      emit(DisplayBlankState());
      return;
    }

    final collectionId = row['collection_id'] as String?;
    final itemIndex = (row['current_item_index'] as int?) ?? 0;
    final slideIndex = (row['current_slide_index'] as int?) ?? 0;

    if (collectionId == null) {
      emit(DisplayIdleState());
      return;
    }

    try {
      final data = await _supabase
          .from('collections')
          .select('*, collection_items(*, songs(*, verses(*)))')
          .eq('id', collectionId)
          .single();

      final collection = Collection.fromJson(data);

      if (itemIndex >= collection.items.length) {
        emit(DisplayIdleState());
        return;
      }

      final item = collection.items[itemIndex];

      if (item.type == CollectionItemType.announcement) {
        final message = item.contentJson?['message'] as String? ?? '';
        final timerStr = item.contentJson?['timerTarget'] as String?;
        emit(
          DisplayAnnouncementState(
            message: message,
            timerTarget: timerStr != null ? DateTime.parse(timerStr) : null,
            overlayVisible: overlayVisible,
            overlayText: overlayText,
          ),
        );
        return;
      }

      if (item.type == CollectionItemType.videoSlide) {
        final path = item.slides.firstOrNull ?? '';
        if (path.isEmpty) {
          emit(DisplayIdleState());
          return;
        }
        emit(
          DisplayVideoState(
            videoPath: path,
            overlayVisible: overlayVisible,
            overlayText: overlayText,
          ),
        );
        return;
      }

      if (item.type == CollectionItemType.imageSlide) {
        final paths = item.slides;
        if (paths.isEmpty) {
          emit(DisplayIdleState());
          return;
        }
        final clampedSlide = slideIndex.clamp(0, paths.length - 1);
        emit(
          DisplayImageState(
            imagePath: paths[clampedSlide],
            overlayVisible: overlayVisible,
            overlayText: overlayText,
          ),
        );
        return;
      }

      final slides = item.slides;
      if (slides.isEmpty) {
        emit(DisplayIdleState());
        return;
      }

      final clampedSlide = slideIndex.clamp(0, slides.length - 1);
      final content = slides[clampedSlide];
      final refs = item.slideReferences;
      final ref = refs.isNotEmpty ? refs[clampedSlide] : '';
      final reference = ref.isNotEmpty ? ref : item.displayTitle;
      final template = await _resolveTemplate(collection, item);

      emit(
        DisplaySlideState(
          content: content,
          reference: reference,
          template: template,
          overlayVisible: overlayVisible,
          overlayText: overlayText,
        ),
      );
    } catch (_) {
      emit(DisplayIdleState());
    }
  }

  // Cache to avoid re-fetching same custom template on every slide change
  final Map<String, SlideTemplate> _templateCache = {};

  Future<SlideTemplate> _resolveTemplate(Collection collection, CollectionItem item) async {
    final id = item.templateId ?? collection.templateId;
    if (id == null) return SlideTemplate.defaultTemplate;

    // Preset
    final preset = SlideTemplate.findPreset(id);
    if (preset != null) return preset;

    // Custom — try cache first
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
