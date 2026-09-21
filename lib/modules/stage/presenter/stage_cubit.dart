import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/presentation_socket.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/collection_item_type.dart';
import '../../../core/models/slide_template.dart';
import '../../../core/windows/window_link.dart';

class StageSlide extends Equatable {
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
    this.moment,
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

  /// The moment of the service the slide belongs to: "Alabanza", "Prédica".
  /// The musicians read it to know where the service is going next.
  final String? moment;

  @override
  List<Object?> get props => [
    moment,
    content,
    reference,
    template,
    itemTitle,
    slideIndex,
    slideCount,
    imagePath,
    notes,
    chords,
  ];
}

/// What the stage monitor is showing.
///
/// Value equality, because the same position now arrives twice: once over the
/// local window link and, when there is internet, again over the socket.
class StageState extends Equatable {
  const StageState({
    this.current,
    this.next,
    this.isLive = false,
    this.isBlank = false,
    this.countdownActive = false,
    this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
    this.stageMessage,
    this.itemStartedAt,
    this.plannedSecs,
    this.rehearsal = false,
  });

  final StageSlide? current;
  final StageSlide? next;
  final bool isLive;
  final bool isBlank;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final bool overlayVisible;
  final String? overlayText;

  /// A line from the operator that only this window shows.
  final String? stageMessage;

  /// When the item on the screen went on it, and how long it is meant to
  /// take: the preacher's clock.
  final DateTime? itemStartedAt;
  final int? plannedSecs;

  /// The band is rehearsing, not leading a service.
  final bool rehearsal;

  @override
  List<Object?> get props => [
    current,
    next,
    isLive,
    isBlank,
    countdownActive,
    countdownEnd,
    overlayVisible,
    overlayText,
    stageMessage,
    itemStartedAt,
    plannedSecs,
    rehearsal,
  ];
}

class StageCubit extends Cubit<StageState> {
  StageCubit(this._api, this._socket, {String Function(CollectionItem item)? titleOf})
    : _titleOf = titleOf ?? _storedTitle,
      super(const StageState());

  final ApiClient _api;
  final PresentationSocket _socket;

  /// An item's name in the window's language, for items with no title.
  final String Function(CollectionItem item) _titleOf;
  static String _storedTitle(CollectionItem item) => item.displayTitle;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final Map<String, SlideTemplate> _templateCache = {};
  final Map<String, Collection> _collections = {};

  Future<void> init() async {
    _sub = _socket.states.listen(_onStateChange, onError: (_) {});
    // The link that works in a building with no internet, and the one that
    // arrives with the plan attached so nothing here has to be fetched.
    await WindowLink.listen((state) => unawaited(applyLocalState(state)));
    await _socket.connect();
  }

  /// Applies a message from the control window.
  ///
  /// The plan and the designs travel with the position, so everything this
  /// needs to draw is in the message and none of it is fetched.
  Future<void> applyLocalState(Map<String, dynamic> state) async {
    final payload = readPresentationPayload(state);
    final collection = payload.collection;
    if (collection != null) _collections[collection.id] = collection;
    for (final template in payload.templates) {
      _templateCache[template.id] = template;
    }
    await _onStateChange(state);
  }

  Future<void> _onStateChange(Map<String, dynamic> row) async {
    final isLive = row['is_live'] as bool? ?? false;
    final isBlank = row['blank_screen'] as bool? ?? false;
    final countdownActive = row['countdown_active'] as bool? ?? false;
    final countdownEndStr = row['countdown_end'] as String?;
    final overlayVisible = row['overlay_visible'] as bool? ?? false;
    final overlayText = row['overlay_text'] as String?;
    final stageMessage = row['stage_message'] as String?;
    final timing = row['timing'] is Map ? row['timing'] as Map : const {};
    final itemStartedAt = DateTime.tryParse(timing['item_started_at'] as String? ?? '')?.toLocal();
    final plannedSecs = (timing['planned_secs'] as num?)?.toInt();
    final rehearsal = timing['rehearsal'] == true;

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
          stageMessage: stageMessage,
          rehearsal: rehearsal,
        ),
      );
      return;
    }

    try {
      final collection = await _collection(collectionId);
      if (collection == null) {
        emit(const StageState());
        return;
      }
      // A passage projected without being added to the service: the musicians
      // and the preacher see what the congregation sees, and nothing follows
      // it until it comes down.
      final loose = row['loose_verse'] is Map ? row['loose_verse'] as Map : null;
      final looseContent = loose?['content'] as String? ?? '';
      final current = looseContent.isNotEmpty
          ? StageSlide(
              content: looseContent,
              reference: loose?['reference'] as String? ?? '',
              template: await _templateById(collection.templateId),
              itemTitle: loose?['reference'] as String? ?? '',
              slideIndex: 0,
              slideCount: 1,
            )
          : await _buildSlide(collection, itemIndex, slideIndex);
      final next = looseContent.isNotEmpty
          ? null
          : await _buildNextSlide(collection, itemIndex, slideIndex);

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
          stageMessage: stageMessage,
          itemStartedAt: itemStartedAt,
          plannedSecs: plannedSecs,
          rehearsal: rehearsal,
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
      reference: ref.isNotEmpty ? ref : _titleOf(item),
      template: template,
      itemTitle: _titleOf(item),
      slideIndex: clamped,
      slideCount: slides.length,
      imagePath: item.type == CollectionItemType.imageSlide ? slides[clamped] : null,
      notes: item.notes,
      chords: chords,
      moment: col.momentOf(item)?.displayTitle,
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
    // First slide of the next thing on the screen, past the mark of a moment
    // that starts in between: a mark has nothing to show.
    for (var i = itemIndex + 1; i < col.items.length; i++) {
      if (!col.items[i].isSection) return _buildSlide(col, i, 0);
    }
    return null;
  }

  /// Returns a collection, reading through the cache, so a slide change does
  /// not wait on the network.
  Future<Collection?> _collection(String id) async {
    final cached = _collections[id];
    if (cached != null) return cached;

    final rows = await _api.get<List<dynamic>>('/collections');
    for (final row in rows ?? []) {
      final collection = Collection.fromJson(row as Map<String, dynamic>);
      _collections[collection.id] = collection;
    }
    return _collections[id];
  }

  Future<SlideTemplate> _resolveTemplate(Collection col, CollectionItem item) =>
      _templateById(col.designsFor(item).firstOrNull);

  Future<SlideTemplate> _templateById(String? id) async {
    if (id == null) return SlideTemplate.defaultTemplate;
    final preset = SlideTemplate.findPreset(id);
    if (preset != null) return preset;
    if (_templateCache.containsKey(id)) return _templateCache[id]!;
    try {
      final rows = await _api.get<List<dynamic>>('/templates');
      for (final raw in rows ?? []) {
        final row = raw as Map<String, dynamic>;
        _templateCache[row['id'] as String] = SlideTemplate.fromJson(
          id: row['id'] as String,
          name: row['name'] as String,
          json: Map<String, dynamic>.from(row['config'] as Map),
        );
      }
      return _templateCache[id] ?? SlideTemplate.defaultTemplate;
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
