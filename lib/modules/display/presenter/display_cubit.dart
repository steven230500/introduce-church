import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/presentation_socket.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/collection_item_type.dart';
import '../../../core/models/slide_template.dart';
import '../../../core/waiting/waiting_screen.dart';
import '../../../core/windows/window_link.dart';

/// What the projector is drawing.
///
/// These carry value equality because the same position now arrives twice: once
/// over the local window link and, when there is internet, again over the
/// socket. Without it the projector rebuilds on the duplicate, which for a
/// video means tearing down a playing decoder and starting it again.
sealed class DisplayState extends Equatable {
  const DisplayState();

  @override
  List<Object?> get props => [];
}

class DisplayIdleState extends DisplayState {}

class DisplayBlankState extends DisplayState {}

class DisplaySlideState extends DisplayState {
  final String content;
  final String reference;
  final SlideTemplate template;
  final bool overlayVisible;
  final String? overlayText;
  const DisplaySlideState({
    required this.content,
    required this.reference,
    required this.template,
    this.overlayVisible = false,
    this.overlayText,
  });

  @override
  List<Object?> get props => [content, reference, template, overlayVisible, overlayText];
}

class DisplayImageState extends DisplayState {
  final String imagePath;
  final bool overlayVisible;
  final String? overlayText;
  const DisplayImageState({required this.imagePath, this.overlayVisible = false, this.overlayText});

  @override
  List<Object?> get props => [imagePath, overlayVisible, overlayText];
}

class DisplayVideoState extends DisplayState {
  final String videoPath;
  final bool overlayVisible;
  final String? overlayText;
  const DisplayVideoState({required this.videoPath, this.overlayVisible = false, this.overlayText});

  @override
  List<Object?> get props => [videoPath, overlayVisible, overlayText];
}

class DisplayCountdownState extends DisplayState {
  final DateTime countdownEnd;
  final bool overlayVisible;
  final String? overlayText;
  const DisplayCountdownState({
    required this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
  });

  @override
  List<Object?> get props => [countdownEnd, overlayVisible, overlayText];
}

/// An animated scene with the church's words, while nothing else is on.
class DisplayWaitingState extends DisplayState {
  const DisplayWaitingState({required this.config, this.countdownEnd});

  final WaitingConfig config;

  /// A running countdown shows in place of the clock.
  final DateTime? countdownEnd;

  @override
  List<Object?> get props => [config, countdownEnd];
}

class DisplayAnnouncementState extends DisplayState {
  final String message;
  final DateTime? timerTarget;
  final bool overlayVisible;
  final String? overlayText;
  const DisplayAnnouncementState({
    required this.message,
    this.timerTarget,
    this.overlayVisible = false,
    this.overlayText,
  });

  @override
  List<Object?> get props => [message, timerTarget, overlayVisible, overlayText];
}

class DisplayCubit extends Cubit<DisplayState> {
  DisplayCubit(this._api, this._socket, {String Function(CollectionItem item)? titleOf})
    : _titleOf = titleOf ?? _storedTitle,
      super(DisplayIdleState());

  final ApiClient _api;
  final PresentationSocket _socket;

  /// The name shown as a slide's reference when it has none of its own - an
  /// untitled announcement - in the window's language.
  final String Function(CollectionItem item) _titleOf;
  static String _storedTitle(CollectionItem item) => item.displayTitle;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Collections, cached by id.
  ///
  /// The operator changes slide every few seconds and each change resolves the
  /// same collection, so re-fetching it every time would put the projector at
  /// the mercy of the network.
  final Map<String, Collection> _collections = {};

  Future<void> init() async {
    _sub = _socket.states.listen(_onStateChange, onError: (_) => emit(DisplayIdleState()));
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
    final blank = row['blank_screen'] as bool? ?? false;
    final countdownActive = row['countdown_active'] as bool? ?? false;
    final countdownEndStr = row['countdown_end'] as String?;
    final overlayVisible = row['overlay_visible'] as bool? ?? false;
    final overlayText = row['overlay_text'] as String?;
    final waiting = WaitingConfig.fromJson(row['waiting']);

    // The waiting scene sits above slides and above a bare countdown, and
    // carries the countdown with it when one is running: counting down to the
    // service over the pre-service loop is the reason both exist.
    if (waiting.active && isLive && !blank) {
      DateTime? end;
      if (countdownActive && countdownEndStr != null) {
        final parsed = DateTime.parse(countdownEndStr).toLocal();
        if (parsed.isAfter(DateTime.now())) end = parsed;
      }
      emit(DisplayWaitingState(config: waiting, countdownEnd: end));
      return;
    }

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

    // A passage the operator sent up without adding it to the service. It sits
    // above the running order until it is taken down, and the service is
    // untouched underneath.
    if (row['loose_verse'] case final Map<dynamic, dynamic> loose) {
      final content = loose['content'] as String? ?? '';
      if (content.isNotEmpty) {
        emit(
          DisplaySlideState(
            content: content,
            reference: loose['reference'] as String? ?? '',
            template: await _templateById(loose['template_id'] as String?),
            overlayVisible: overlayVisible,
            overlayText: overlayText,
          ),
        );
        return;
      }
    }

    final collectionId = row['collection_id'] as String?;
    final itemIndex = (row['current_item_index'] as int?) ?? 0;
    final slideIndex = (row['current_slide_index'] as int?) ?? 0;

    if (collectionId == null) {
      emit(DisplayIdleState());
      return;
    }

    try {
      final collection = await _collection(collectionId);
      if (collection == null) {
        emit(DisplayIdleState());
        return;
      }

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
      final reference = ref.isNotEmpty ? ref : _titleOf(item);
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

  /// Returns a collection, reading through the cache.
  ///
  /// A miss means the operator opened a plan this window has not seen, so the
  /// list is pulled once and every collection cached at the same time.
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

  // Cache to avoid re-resolving the same custom design on every slide change.
  final Map<String, SlideTemplate> _templateCache = {};

  Future<SlideTemplate> _resolveTemplate(Collection collection, CollectionItem item) =>
      _templateById(item.templateId ?? collection.templateId);

  Future<SlideTemplate> _templateById(String? id) async {
    if (id == null) return SlideTemplate.defaultTemplate;

    // Preset
    final preset = SlideTemplate.findPreset(id);
    if (preset != null) return preset;

    // Custom — try cache first
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
