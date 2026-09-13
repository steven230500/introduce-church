import 'dart:async';
import 'dart:convert';
import 'package:media_kit/media_kit.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path/path.dart' as p;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../../../../core/local_db/bible_repository.dart';
import '../../../../../../core/services/app_prefs_service.dart';
import '../../../../../../core/utils/app_logger.dart';
import '../../../../../../core/windows/window_link.dart';
import '../../../../../../core/api/api_client.dart';
import '../../../../../../core/api/presentation_socket.dart';
import '../../../../../../core/services/pptx_import_service.dart';
import '../../../../../../core/models/collection.dart';
import '../../../../../../core/models/slide_template.dart';
import '../../../../../../core/models/song.dart';
import '../../../../../../core/repositories/template_repository.dart';
import '../../repository/repository.dart';
import '../../../../../../modules/auth/utils/navigator.dart';

part 'state.dart';

class ControlModel extends Equatable {
  const ControlModel({
    this.collections = const [],
    this.activeCollection,
    this.currentItemIndex = 0,
    this.currentSlideIndex = 0,
    this.liveItemIndex = 0,
    this.liveSlideIndex = 0,
    this.followCursor = true,
    this.isLive = false,
    this.blankScreen = false,
    this.gridView = true,
    this.userTemplates = const [],
    this.countdownActive = false,
    this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
    this.offline = false,
  });

  final List<Collection> collections;
  final Collection? activeCollection;

  /// Where the operator is looking.
  final int currentItemIndex;
  final int currentSlideIndex;

  /// What the congregation is looking at.
  ///
  /// The two are the same while [followCursor] is on, which is how the app has
  /// always behaved. They come apart when the operator wants to find the next
  /// song during the sermon without the projector following them there.
  final int liveItemIndex;
  final int liveSlideIndex;

  final bool followCursor;
  final bool isLive;
  final bool blankScreen;
  final bool gridView;
  final List<SlideTemplate> userTemplates;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final bool overlayVisible;
  final String? overlayText;

  /// True when the last read came from the cache because the server could not
  /// be reached.
  ///
  /// Everything needed to run the service is on the disk, so the presenter
  /// keeps working. What does not work is writing, and an operator who removes
  /// an item and sees nothing happen deserves to know why.
  final bool offline;

  SlideTemplate? findTemplate(String id) =>
      SlideTemplate.findPreset(id) ?? userTemplates.where((t) => t.id == id).firstOrNull;

  /// The design [item] will be drawn with: its own, else the collection's,
  /// else the built-in default.
  SlideTemplate templateFor(CollectionItem? item) {
    final itemId = item?.templateId;
    if (itemId != null) {
      final t = findTemplate(itemId);
      if (t != null) return t;
    }
    final id = activeCollection?.templateId;
    return (id != null ? findTemplate(id) : null) ?? SlideTemplate.defaultTemplate;
  }

  SlideTemplate get activeTemplate => templateFor(currentItem);

  CollectionItem? get currentItem => activeCollection != null && activeCollection!.items.isNotEmpty
      ? activeCollection!.items[currentItemIndex.clamp(0, activeCollection!.items.length - 1)]
      : null;

  Song? get currentSong => currentItem?.song;

  /// The item on the projector, which is not always the one being browsed.
  CollectionItem? get liveItem {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    if (items.isEmpty) return null;
    return items[liveItemIndex.clamp(0, items.length - 1)];
  }

  List<String> get liveSlides => liveItem?.slides ?? [];

  String? get liveSlideContent =>
      liveSlides.isNotEmpty ? liveSlides[liveSlideIndex.clamp(0, liveSlides.length - 1)] : null;

  String get liveSlideReference {
    final refs = liveItem?.slideReferences ?? [];
    if (refs.isEmpty) return liveItem?.displayTitle ?? '';
    final ref = refs[liveSlideIndex.clamp(0, refs.length - 1)];
    return ref.isNotEmpty ? ref : (liveItem?.displayTitle ?? '');
  }

  SlideTemplate get liveTemplate => templateFor(liveItem);

  /// Whether a given position is the one the congregation is seeing.
  ///
  /// Off air nothing is, so the red marker has to go with the feed. It used to
  /// mark the live position even with the projector cut, which says "they are
  /// seeing this" about a screen showing nothing.
  bool isLiveAt(int itemIndex, int slideIndex) =>
      isLive && itemIndex == liveItemIndex && slideIndex == liveSlideIndex;

  /// Whether the congregation is seeing this item, on any of its slides.
  bool isLiveItem(int itemIndex) => isLive && itemIndex == liveItemIndex;

  /// True when the operator is looking at something the congregation is not.
  ///
  /// This is the only state in which the send button means anything, and the
  /// only one in which the set list has to mark two different rows.
  bool get isHolding => currentItemIndex != liveItemIndex || currentSlideIndex != liveSlideIndex;

  List<String> get currentSlides => currentItem?.slides ?? [];

  String? get currentSlideContent => currentSlides.isNotEmpty
      ? currentSlides[currentSlideIndex.clamp(0, currentSlides.length - 1)]
      : null;

  String get currentSlideReference {
    final refs = currentItem?.slideReferences ?? [];
    if (refs.isEmpty) return currentItem?.displayTitle ?? '';
    final ref = refs[currentSlideIndex.clamp(0, refs.length - 1)];
    return ref.isNotEmpty ? ref : (currentItem?.displayTitle ?? '');
  }

  /// What pressing Next will put on the projector, crossing into the following
  /// item when the current one runs out.
  ///
  /// The operator could always see the slides of the item they were on, but
  /// never the first slide of the one after it, which is exactly the moment a
  /// service goes wrong.
  ({CollectionItem item, int slide})? get upNext {
    final collection = activeCollection;
    final item = currentItem;
    if (collection == null || item == null) return null;

    if (currentSlideIndex + 1 < item.slides.length) {
      return (item: item, slide: currentSlideIndex + 1);
    }
    final next = currentItemIndex.clamp(0, collection.items.length - 1) + 1;
    if (next >= collection.items.length) return null;
    return (item: collection.items[next], slide: 0);
  }

  bool get hasPrevSlide {
    if (activeCollection == null || activeCollection!.items.isEmpty) return false;
    return currentSlideIndex > 0 || currentItemIndex > 0;
  }

  /// Whether the projector has somewhere to go, which is what the auto-advance
  /// timer asks and is not the same question as [hasNextSlide].
  bool get hasNextLiveSlide {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    if (items.isEmpty) return false;
    final lastItem = liveItemIndex >= items.length - 1;
    final lastSlide = liveSlideIndex >= liveSlides.length - 1;
    return !lastItem || !lastSlide;
  }

  bool get hasNextSlide {
    if (activeCollection == null || activeCollection!.items.isEmpty) return false;
    final lastItem = currentItemIndex == activeCollection!.items.length - 1;
    final lastSlide = currentSlideIndex == currentSlides.length - 1;
    return !lastItem || !lastSlide;
  }

  ControlModel copyWith({
    List<Collection>? collections,
    Collection? activeCollection,
    bool clearCollection = false,
    int? currentItemIndex,
    int? currentSlideIndex,
    int? liveItemIndex,
    int? liveSlideIndex,
    bool? followCursor,
    bool? isLive,
    bool? blankScreen,
    bool? gridView,
    List<SlideTemplate>? userTemplates,
    bool? countdownActive,
    DateTime? countdownEnd,
    bool clearCountdownEnd = false,
    bool? overlayVisible,
    String? overlayText,
    bool clearOverlayText = false,
    bool? offline,
  }) {
    return ControlModel(
      collections: collections ?? this.collections,
      activeCollection: clearCollection ? null : activeCollection ?? this.activeCollection,
      currentItemIndex: currentItemIndex ?? this.currentItemIndex,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      liveItemIndex: liveItemIndex ?? this.liveItemIndex,
      liveSlideIndex: liveSlideIndex ?? this.liveSlideIndex,
      followCursor: followCursor ?? this.followCursor,
      isLive: isLive ?? this.isLive,
      blankScreen: blankScreen ?? this.blankScreen,
      gridView: gridView ?? this.gridView,
      userTemplates: userTemplates ?? this.userTemplates,
      countdownActive: countdownActive ?? this.countdownActive,
      countdownEnd: clearCountdownEnd ? null : countdownEnd ?? this.countdownEnd,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      overlayText: clearOverlayText ? null : overlayText ?? this.overlayText,
      offline: offline ?? this.offline,
    );
  }

  @override
  List<Object?> get props => [
    collections,
    activeCollection,
    currentItemIndex,
    currentSlideIndex,
    liveItemIndex,
    liveSlideIndex,
    followCursor,
    isLive,
    blankScreen,
    gridView,
    userTemplates,
    countdownActive,
    countdownEnd,
    overlayVisible,
    overlayText,
    offline,
  ];
}

class ControlCubit extends Cubit<ControlState> {
  ControlCubit(this._repository, this._templateRepository, this._prefs, this._socket)
    : super(const ControlLoadingState());

  final ControlRepository _repository;
  final TemplateRepository _templateRepository;
  final AppPrefsService _prefs;
  final PresentationSocket _socket;
  WindowController? _displayController;
  Timer? _autoAdvanceTimer;

  /// The collection rows exactly as the server sent them.
  ///
  /// Kept so the projector and stage windows can be handed the plan itself
  /// rather than an id they would have to resolve over a network that, in most
  /// of these rooms, is not there.
  List<Map<String, dynamic>> _rawCollections = const [];
  Player? _audioPlayer;

  /// Full load with a loading state. Use only for the first load and for
  /// recovering from an error screen.
  Future<void> load() => _fetch(showSpinner: true);

  /// Reloads from the server while keeping the current screen on display.
  ///
  /// Every mutation goes through this. Emitting a loading state after an edit
  /// blanks the set list mid-service, which reads as a crash to the operator.
  Future<void> refresh() => _fetch(showSpinner: false);

  Future<void> _fetch({required bool showSpinner}) async {
    final previousCollectionId = state is ControlLoadedState
        ? (state as ControlLoadedState).model.activeCollection?.id
        : null;
    final previousItemIndex = state is ControlLoadedState
        ? (state as ControlLoadedState).model.currentItemIndex
        : 0;
    final previousSlideIndex = state is ControlLoadedState
        ? (state as ControlLoadedState).model.currentSlideIndex
        : 0;
    final previousLiveItem = state is ControlLoadedState
        ? (state as ControlLoadedState).model.liveItemIndex
        : 0;
    final previousLiveSlide = state is ControlLoadedState
        ? (state as ControlLoadedState).model.liveSlideIndex
        : 0;
    final previous = state is ControlLoadedState ? (state as ControlLoadedState).model : null;
    if (showSpinner) emit(const ControlLoadingState());
    try {
      final rawCollections = await _repository.getCollectionsRaw();
      final rawTemplates = await _templateRepository.getTemplatesRaw();
      final userTemplates = TemplateRepository.parseTemplates(rawTemplates);
      final collections = rawCollections.map(Collection.fromJson).toList();
      _rawCollections = rawCollections;
      final active = previousCollectionId != null
          ? collections.where((c) => c.id == previousCollectionId).firstOrNull
          : null;
      await _prefs.saveCollections(rawCollections);
      await _prefs.saveTemplates(rawTemplates);
      final itemCount = active?.items.length ?? 0;
      emit(
        ControlLoadedState(
          ControlModel(
            collections: collections,
            activeCollection: active,
            userTemplates: userTemplates,
            // A refresh must not move the projector. Keep the cursor and every
            // broadcast flag exactly where the operator left them.
            currentItemIndex: itemCount == 0 ? 0 : previousItemIndex.clamp(0, itemCount - 1),
            currentSlideIndex: previousSlideIndex,
            liveItemIndex: itemCount == 0 ? 0 : previousLiveItem.clamp(0, itemCount - 1),
            liveSlideIndex: previousLiveSlide,
            followCursor: previous?.followCursor ?? true,
            offline: false,
            isLive: previous?.isLive ?? false,
            blankScreen: previous?.blankScreen ?? false,
            gridView: previous?.gridView ?? true,
            countdownActive: previous?.countdownActive ?? false,
            countdownEnd: previous?.countdownEnd,
            overlayVisible: previous?.overlayVisible ?? false,
            overlayText: previous?.overlayText,
          ),
        ),
      );
    } catch (e) {
      final s = e.toString();
      if (e is ApiException && e.isAuthFailure) {
        await Modular.get<ApiClient>().signOut();
        AuthNavigator.goToLogin();
        return;
      }
      final isNetworkError =
          s.contains('host lookup') ||
          s.contains('SocketException') ||
          s.contains('timeout') ||
          s.contains('TimeoutException') ||
          s.contains('Failed host lookup');
      if (isNetworkError) {
        final cached = await _prefs.loadCollections();
        if (cached != null && cached.isNotEmpty) {
          final collections = cached.map(Collection.fromJson).toList();
          _rawCollections = cached;
          final cachedTemplates = await _prefs.loadTemplates() ?? const [];
          final active = previousCollectionId != null
              ? collections.where((c) => c.id == previousCollectionId).firstOrNull
              : null;
          emit(
            ControlLoadedState(
              ControlModel(
                collections: collections,
                activeCollection: active,
                userTemplates: previous?.userTemplates.isNotEmpty == true
                    ? previous!.userTemplates
                    : TemplateRepository.parseTemplates(cachedTemplates),
                followCursor: previous?.followCursor ?? true,
                // Everything needed to run the service is on the disk. Writing
                // is what stops working, and the operator has to be told.
                offline: true,
                isLive: previous?.isLive ?? false,
                blankScreen: previous?.blankScreen ?? false,
                gridView: previous?.gridView ?? true,
              ),
            ),
          );
          return;
        }
        emit(const ControlErrorState('Sin conexión y sin datos en caché.'));
        return;
      }
      emit(ControlErrorState('Error al cargar: ${s.split('\n').first}'));
    }
  }

  void selectCollection(Collection collection) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    emit(
      ControlLoadedState(
        current.copyWith(
          activeCollection: collection,
          currentItemIndex: 0,
          currentSlideIndex: 0,
          liveItemIndex: 0,
          liveSlideIndex: 0,
        ),
      ),
    );
    _syncState();
  }

  void selectItem(int itemIndex) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    // The number keys can name an item that is not there. Storing the index
    // anyway would leave the cursor pointing past the end of the set list.
    final items = current.activeCollection?.items ?? const <CollectionItem>[];
    if (itemIndex < 0 || itemIndex >= items.length) return;
    _moveCursor(current, itemIndex, 0);
  }

  void selectSlide(int slideIndex) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    _moveCursor(current, current.currentItemIndex, slideIndex);
  }

  /// Moves what the operator is looking at, and the projector with it while
  /// the two are linked.
  void _moveCursor(ControlModel model, int itemIndex, int slideIndex) {
    final follows = model.followCursor;
    emit(
      ControlLoadedState(
        model.copyWith(
          currentItemIndex: itemIndex,
          currentSlideIndex: slideIndex,
          liveItemIndex: follows ? itemIndex : null,
          liveSlideIndex: follows ? slideIndex : null,
        ),
      ),
    );
    if (follows) _syncState();
    _scheduleAutoAdvance();
  }

  /// Puts what the operator is looking at on the projector.
  ///
  /// Does nothing when the two already agree, so pressing it twice cannot cut
  /// the screen to somewhere unexpected.
  void take() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.isHolding) return;
    emit(
      ControlLoadedState(
        model.copyWith(
          liveItemIndex: model.currentItemIndex,
          liveSlideIndex: model.currentSlideIndex,
        ),
      ),
    );
    _syncState();
    _scheduleAutoAdvance();
  }

  /// Links or unlinks the projector from the operator's cursor.
  ///
  /// Linking again sends whatever is being looked at, because leaving the
  /// screen behind after the operator has said "follow me" is the surprise
  /// this whole mode exists to avoid.
  void setFollowCursor(bool follow) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.followCursor == follow) return;

    emit(
      ControlLoadedState(
        model.copyWith(
          followCursor: follow,
          liveItemIndex: follow ? model.currentItemIndex : null,
          liveSlideIndex: follow ? model.currentSlideIndex : null,
        ),
      ),
    );
    if (follow) _syncState();
    _scheduleAutoAdvance();
  }

  void toggleFollowCursor() {
    if (state is! ControlLoadedState) return;
    setFollowCursor(!(state as ControlLoadedState).model.followCursor);
  }

  /// Moves the projector on by one, leaving the cursor where it is.
  ///
  /// Only the auto-advance timer uses this: an item that advances itself has
  /// to keep doing so while the operator looks somewhere else.
  void _advanceLive() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.followCursor) {
      nextSlide();
      return;
    }
    if (!model.hasNextLiveSlide) return;

    final onLastSlide = model.liveSlideIndex >= model.liveSlides.length - 1;
    emit(
      ControlLoadedState(
        onLastSlide
            ? model.copyWith(liveItemIndex: model.liveItemIndex + 1, liveSlideIndex: 0)
            : model.copyWith(liveSlideIndex: model.liveSlideIndex + 1),
      ),
    );
    _syncState();
    _scheduleAutoAdvance();
  }

  void nextSlide() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.hasNextSlide) return;

    if (model.currentSlideIndex < model.currentSlides.length - 1) {
      selectSlide(model.currentSlideIndex + 1);
    } else {
      selectItem(model.currentItemIndex + 1);
    }
  }

  void prevSlide() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.hasPrevSlide) return;

    if (model.currentSlideIndex > 0) {
      selectSlide(model.currentSlideIndex - 1);
    } else {
      final prevItem = model.currentItemIndex - 1;
      final prevSlides = model.activeCollection!.items[prevItem].slides;
      _moveCursor(model, prevItem, prevSlides.length - 1);
    }
  }

  void toggleLive() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(isLive: !model.isLive)));
    _syncState();
    _scheduleAutoAdvance();
    _updateAudio();
  }

  /// Jumps to the last slide of the item on screen.
  void lastSlide() {
    if (state is! ControlLoadedState) return;
    final slides = (state as ControlLoadedState).model.currentSlides;
    if (slides.isEmpty) return;
    selectSlide(slides.length - 1);
  }

  /// Takes the projector out of black, and does nothing if it already is.
  ///
  /// Escape is the key someone hits when they do not know what else to press,
  /// so it must only ever uncover the screen, never cover it.
  void clearBlank() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.blankScreen) return;
    emit(ControlLoadedState(model.copyWith(blankScreen: false)));
    _syncState();
  }

  void toggleBlank() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(blankScreen: !model.blankScreen)));
    _syncState();
  }

  void toggleGridView() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(gridView: !model.gridView)));
  }

  Future<void> createCollection(String name, {DateTime? serviceDate}) async {
    final col = await _repository.createCollection(name: name, serviceDate: serviceDate);
    await refresh();
    if (state is ControlLoadedState) {
      final model = (state as ControlLoadedState).model;
      final created = model.collections.firstWhere((c) => c.id == col.id, orElse: () => col);
      emit(
        ControlLoadedState(
          model.copyWith(activeCollection: created, currentItemIndex: 0, currentSlideIndex: 0),
        ),
      );
    }
  }

  Future<void> updateCollection(String id, String name, {DateTime? serviceDate}) async {
    await _repository.updateCollection(id: id, name: name, serviceDate: serviceDate);
    await refresh();
  }

  Future<void> deleteCollection(String id) async {
    await _repository.deleteCollection(id);
    await refresh();
  }

  Future<void> addSong(String songId) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    final order = model.activeCollection!.items.length;
    await _repository.addSongToCollection(
      collectionId: model.activeCollection!.id,
      songId: songId,
      order: order,
    );
    await refresh();
  }

  Future<int> importPptx(String filePath, {String? templateId}) async {
    if (state is! ControlLoadedState) return 0;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return 0;
    final slides = await PptxImportService().extractSlides(filePath);
    if (slides.isEmpty) return 0;
    final startOrder = model.activeCollection!.items.length;
    await _repository.addFreeSlideBatch(
      collectionId: model.activeCollection!.id,
      texts: slides,
      startOrder: startOrder,
      templateId: templateId,
    );
    await refresh();
    return slides.length;
  }

  Future<int> importPptxAsImages(String filePath) async {
    if (state is! ControlLoadedState) return 0;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return 0;
    final imagePaths = await PptxImportService().extractSlidesAsImages(filePath);
    if (imagePaths.isEmpty) return 0;
    final startOrder = model.activeCollection!.items.length;
    await _repository.addImageSlideBatch(
      collectionId: model.activeCollection!.id,
      imagePaths: imagePaths,
      title: p.basename(filePath),
      startOrder: startOrder,
    );
    await refresh();
    return imagePaths.length;
  }

  Future<void> addAnnouncement(String message, {String? title, DateTime? timerTarget}) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    await _repository.addAnnouncement(
      collectionId: model.activeCollection!.id,
      message: message,
      order: model.activeCollection!.items.length,
      title: title,
      timerTarget: timerTarget,
    );
    await refresh();
  }

  Future<void> addFreeSlide(String text, {String? title}) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    final order = model.activeCollection!.items.length;
    await _repository.addFreeSlideToCollection(
      collectionId: model.activeCollection!.id,
      text: text,
      title: title,
      order: order,
    );
    await refresh();
  }

  Future<void> addImageSlide(String imagePath, {String? title}) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    final order = model.activeCollection!.items.length;
    await _repository.addImageSlideBatch(
      collectionId: model.activeCollection!.id,
      imagePaths: [imagePath],
      title: title ?? p.basenameWithoutExtension(imagePath),
      startOrder: order,
    );
    await refresh();
  }

  Future<void> importVideo(String filePath) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    final order = model.activeCollection!.items.length;
    final title = p.basenameWithoutExtension(filePath);
    await _repository.addVideoToCollection(
      collectionId: model.activeCollection!.id,
      videoPath: filePath,
      title: title,
      order: order,
    );
    await refresh();
  }

  Future<({int images, int videos})> importFolder({
    required String folderTitle,
    required List<String> imagePaths,
    required List<String> videoPaths,
  }) async {
    if (state is! ControlLoadedState) return (images: 0, videos: 0);
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return (images: 0, videos: 0);

    final collectionId = model.activeCollection!.id;
    int order = model.activeCollection!.items.length;

    if (imagePaths.isNotEmpty) {
      await _repository.addImageSlideBatch(
        collectionId: collectionId,
        imagePaths: imagePaths,
        title: folderTitle,
        startOrder: order,
      );
      order++;
    }

    for (final videoPath in videoPaths) {
      await _repository.addVideoToCollection(
        collectionId: collectionId,
        videoPath: videoPath,
        title: p.basenameWithoutExtension(videoPath),
        order: order++,
      );
    }

    await refresh();
    return (images: imagePaths.isNotEmpty ? 1 : 0, videos: videoPaths.length);
  }

  Future<void> removeItem(String itemId) async {
    await _repository.removeItemFromCollection(itemId);
    await refresh();
  }

  /// Puts [item] back at [index].
  ///
  /// Restoring appends, so the row arrives last and the whole running order is
  /// then rewritten to drop it back in place. Done in that order a failure
  /// leaves the item present but misplaced, which an operator can fix by
  /// dragging; the other way round it would be gone for good.
  Future<void> restoreItem(CollectionItem item, int index) async {
    await _repository.restoreItem(item);
    await refresh();
    await _moveNewestItemTo(item.collectionId, index);
  }

  /// Moves the row that was just added into position.
  ///
  /// The API only ever appends, so anything that has to land somewhere else
  /// gets there by rewriting the running order afterwards.
  Future<void> _moveNewestItemTo(String collectionId, int index) async {
    if (state is! ControlLoadedState) return;
    final collection = (state as ControlLoadedState).model.collections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    if (collection == null) return;

    final ids = collection.items.map((i) => i.id).toList();
    if (ids.length < 2 || index < 0 || index >= ids.length - 1) return;
    ids.insert(index, ids.removeLast());
    await _repository.reorderItems(collection.id, ids);
    await refresh();
  }

  /// Adds a reading straight after the item on screen, and goes to it.
  ///
  /// Left at the end of the plan it would be out of order, and the press after
  /// it would land past the end of the service. This is the path a preacher
  /// naming a verse mid-sermon takes, so it has to come out where the service
  /// actually is.
  Future<void> addBibleVerseAfterCurrent(BibleVerseRef ref) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final collection = model.activeCollection;
    if (collection == null) return;

    final target = collection.items.isEmpty ? 0 : model.currentItemIndex + 1;
    await _repository.addBibleVerseToCollection(
      collectionId: collection.id,
      ref: ref,
      order: collection.items.length,
    );
    await refresh();
    await _moveNewestItemTo(collection.id, target);
    selectItem(target);
  }

  Future<void> setItemTitle(String itemId, String title) async {
    await _repository.updateItemTitle(itemId, title);
    await refresh();
  }

  Future<void> addSermon(String title, List<String> points) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;
    final order = model.activeCollection!.items.length;
    await _repository.addSermonToCollection(
      collectionId: model.activeCollection!.id,
      title: title,
      points: points,
      order: order,
    );
    await refresh();
  }

  Future<void> addBibleVerse(BibleVerseRef ref) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.activeCollection == null) return;

    final order = model.activeCollection!.items.length;
    await _repository.addBibleVerseToCollection(
      collectionId: model.activeCollection!.id,
      ref: ref,
      order: order,
    );
    await refresh();
  }

  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    await _templateRepository.setCollectionTemplate(collectionId, templateId);
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final updatedCollections = model.collections.map((c) {
      return c.id == collectionId
          ? c.copyWith(templateId: templateId, clearTemplateId: templateId == null)
          : c;
    }).toList();
    final updatedActive = model.activeCollection?.id == collectionId
        ? model.activeCollection!.copyWith(
            templateId: templateId,
            clearTemplateId: templateId == null,
          )
        : model.activeCollection;
    emit(
      ControlLoadedState(
        model.copyWith(collections: updatedCollections, activeCollection: updatedActive),
      ),
    );
  }

  Future<void> setItemTemplate(String collectionId, String itemId, String? templateId) async {
    await _templateRepository.setItemTemplate(itemId, templateId);
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;

    Collection applyToCollection(Collection c) {
      if (c.id != collectionId) return c;
      final items = c.items
          .map((item) => item.id == itemId ? item.withTemplateId(templateId) : item)
          .toList();
      return c.copyWith(items: items);
    }

    emit(
      ControlLoadedState(
        model.copyWith(
          collections: model.collections.map(applyToCollection).toList(),
          activeCollection: model.activeCollection != null
              ? applyToCollection(model.activeCollection!)
              : null,
        ),
      ),
    );
  }

  Future<void> openStageMonitor() async {
    // The window reads the stored session itself, so it only needs to be told
    // which kind of window to be.
    final controller = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: jsonEncode({'type': 'stage'})),
    );
    await controller.show();
  }

  Future<void> openDisplayWindow() async {
    // Reset live so display starts black
    if (state is ControlLoadedState) {
      final model = (state as ControlLoadedState).model;
      if (model.isLive) {
        emit(ControlLoadedState(model.copyWith(isLive: false)));
        _syncState();
      }
    }

    // Reuse existing window if still open
    if (_displayController != null) {
      try {
        await _displayController!.show();
        return;
      } catch (_) {
        _displayController = null;
      }
    }

    final displays = await screenRetriever.getAllDisplays();
    Map<String, dynamic> screenData = {};
    if (displays.length > 1) {
      final d = displays[1];
      final pos = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? d.size;
      screenData = {'x': pos.dx, 'y': pos.dy, 'w': size.width, 'h': size.height};
    }

    _displayController = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'type': 'display', 'screen': screenData}),
      ),
    );
    await _displayController!.show();
  }

  Future<void> updateItemNotes(String itemId, String? notes) async {
    await _repository.updateItemNotes(itemId, notes);
    await refresh();
  }

  Future<void> reorderItem(int oldIndex, int newIndex) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final col = model.activeCollection;
    if (col == null) return;

    final items = List<CollectionItem>.from(col.items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    final updated = col.copyWith(items: items);
    emit(ControlLoadedState(model.copyWith(activeCollection: updated)));

    await _repository.reorderItems(col.id, items.map((i) => i.id).toList());
  }

  void startCountdown(int seconds) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final end = DateTime.now().add(Duration(seconds: seconds));
    emit(ControlLoadedState(model.copyWith(countdownActive: true, countdownEnd: end)));
    _syncState();
  }

  void stopCountdown() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(countdownActive: false, clearCountdownEnd: true)));
    _syncState();
  }

  void setOverlayText(String text) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(overlayText: text)));
  }

  void toggleOverlay() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    emit(ControlLoadedState(model.copyWith(overlayVisible: !model.overlayVisible)));
    _syncState();
  }

  Future<void> setCollectionBgAudio(String collectionId, String? path) async {
    await _repository.updateCollectionBgAudio(collectionId, path);
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final updated = model.activeCollection?.copyWith(bgAudioPath: path, clearBgAudio: path == null);
    if (updated == null) return;
    final collections = model.collections.map((c) => c.id == collectionId ? updated : c).toList();
    emit(ControlLoadedState(model.copyWith(activeCollection: updated, collections: collections)));
    _updateAudio();
  }

  void _updateAudio() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final path = model.activeCollection?.bgAudioPath;

    if (model.isLive && path != null && path.isNotEmpty) {
      if (_audioPlayer == null) {
        _audioPlayer = Player();
        _audioPlayer!.setPlaylistMode(PlaylistMode.loop);
      }
      _audioPlayer!.open(Media(path));
    } else {
      _audioPlayer?.stop();
    }
  }

  @override
  Future<void> close() {
    _autoAdvanceTimer?.cancel();
    _audioPlayer?.dispose();
    return super.close();
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.isLive) return;
    // The timer belongs to the item on the projector, not to the one being
    // browsed: a video keeps its own clock while the operator looks ahead.
    final secs = model.liveItem?.autoAdvanceSecs;
    if (secs == null || secs <= 0 || !model.hasNextLiveSlide) return;
    _autoAdvanceTimer = Timer(Duration(seconds: secs), _advanceLive);
  }

  Future<void> setItemAutoAdvance(String itemId, int? secs) async {
    await _repository.updateItemAutoAdvance(itemId, secs);
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final col = model.activeCollection;
    if (col == null) return;
    final items = col.items
        .map(
          (i) => i.id == itemId
              ? i.copyWith(autoAdvanceSecs: secs, clearAutoAdvance: secs == null)
              : i,
        )
        .toList();
    final updated = col.copyWith(items: items);
    emit(ControlLoadedState(model.copyWith(activeCollection: updated)));
    _scheduleAutoAdvance();
  }

  /// Publishes what is on the projector to the projector and stage windows.
  ///
  /// It sends the live position, not the cursor. While the two are linked they
  /// are the same number; while they are not, this is the difference between
  /// the congregation seeing the next song and not.
  ///
  /// The socket is the path that matters during a service: it reaches the other
  /// windows in milliseconds and the server persists on the way through. The
  /// HTTP write is the fallback for when the socket is down.
  void _syncState() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;

    final position = {
      'collection_id': model.activeCollection?.id,
      'current_item_index': model.liveItemIndex,
      'current_slide_index': model.liveSlideIndex,
      'is_live': model.isLive,
      'blank_screen': model.blankScreen,
      'countdown_active': model.countdownActive,
      'countdown_end': model.countdownEnd?.toUtc().toIso8601String(),
      'overlay_visible': model.overlayVisible,
      'overlay_text': model.overlayText,
    };

    // The other windows first, and over the local link, which is the only path
    // that works in a building with no internet. It carries the plan and the
    // designs with the position so nothing has to be fetched at the far end.
    unawaited(
      WindowLink.broadcast({
        ...position,
        'collection': ?_rawCollection(model.activeCollection?.id),
        'templates': [
          for (final template in model.userTemplates)
            {'id': template.id, 'name': template.name, 'config': template.toJson()},
        ],
      }),
    );

    if (_socket.isConnected) {
      _socket.send(position);
      return;
    }

    // No socket: write it through so the server remembers where the service
    // is. Offline this always fails, and a slide change is not the moment to
    // tell anyone about it.
    unawaited(
      _repository
          .upsertPresentationState(
            collectionId: model.activeCollection?.id,
            itemIndex: model.liveItemIndex,
            slideIndex: model.liveSlideIndex,
            isLive: model.isLive,
            blankScreen: model.blankScreen,
            countdownActive: model.countdownActive,
            countdownEnd: model.countdownEnd,
            overlayVisible: model.overlayVisible,
            overlayText: model.overlayText,
          )
          .catchError((Object e) {
            appLogger.w('ControlCubit._syncState | state not written: $e');
          }),
    );
  }

  Map<String, dynamic>? _rawCollection(String? id) {
    if (id == null) return null;
    return _rawCollections.where((row) => row['id'] == id).firstOrNull;
  }
}
