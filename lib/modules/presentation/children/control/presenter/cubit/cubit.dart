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
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/local_db/bible_repository.dart';
import '../../../../../../core/services/app_prefs_service.dart';
import '../../../../../../core/services/supabase_service.dart';
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
    this.isLive = false,
    this.blankScreen = false,
    this.gridView = true,
    this.userTemplates = const [],
    this.countdownActive = false,
    this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
  });

  final List<Collection> collections;
  final Collection? activeCollection;
  final int currentItemIndex;
  final int currentSlideIndex;
  final bool isLive;
  final bool blankScreen;
  final bool gridView;
  final List<SlideTemplate> userTemplates;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final bool overlayVisible;
  final String? overlayText;

  SlideTemplate? findTemplate(String id) =>
      SlideTemplate.findPreset(id) ?? userTemplates.where((t) => t.id == id).firstOrNull;

  SlideTemplate get activeTemplate {
    final itemId = currentItem?.templateId;
    if (itemId != null) {
      final t = findTemplate(itemId);
      if (t != null) return t;
    }
    final id = activeCollection?.templateId;
    return (id != null ? findTemplate(id) : null) ?? SlideTemplate.defaultTemplate;
  }

  CollectionItem? get currentItem => activeCollection != null && activeCollection!.items.isNotEmpty
      ? activeCollection!.items[currentItemIndex.clamp(0, activeCollection!.items.length - 1)]
      : null;

  Song? get currentSong => currentItem?.song;

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

  bool get hasPrevSlide {
    if (activeCollection == null || activeCollection!.items.isEmpty) return false;
    return currentSlideIndex > 0 || currentItemIndex > 0;
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
  }) {
    return ControlModel(
      collections: collections ?? this.collections,
      activeCollection: clearCollection ? null : activeCollection ?? this.activeCollection,
      currentItemIndex: currentItemIndex ?? this.currentItemIndex,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      isLive: isLive ?? this.isLive,
      blankScreen: blankScreen ?? this.blankScreen,
      gridView: gridView ?? this.gridView,
      userTemplates: userTemplates ?? this.userTemplates,
      countdownActive: countdownActive ?? this.countdownActive,
      countdownEnd: clearCountdownEnd ? null : countdownEnd ?? this.countdownEnd,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      overlayText: clearOverlayText ? null : overlayText ?? this.overlayText,
    );
  }

  @override
  List<Object?> get props => [
    collections,
    activeCollection,
    currentItemIndex,
    currentSlideIndex,
    isLive,
    blankScreen,
    gridView,
    userTemplates,
    countdownActive,
    countdownEnd,
    overlayVisible,
    overlayText,
  ];
}

class ControlCubit extends Cubit<ControlState> {
  ControlCubit(this._repository, this._templateRepository, this._prefs)
    : super(const ControlLoadingState());

  final ControlRepository _repository;
  final TemplateRepository _templateRepository;
  final AppPrefsService _prefs;
  WindowController? _displayController;
  Timer? _autoAdvanceTimer;
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
    final previous = state is ControlLoadedState ? (state as ControlLoadedState).model : null;
    if (showSpinner) emit(const ControlLoadingState());
    try {
      final rawCollections = await _repository.getCollectionsRaw();
      final userTemplates = await _templateRepository.getTemplates();
      final collections = rawCollections.map(Collection.fromJson).toList();
      final active = previousCollectionId != null
          ? collections.where((c) => c.id == previousCollectionId).firstOrNull
          : null;
      await _prefs.saveCollections(rawCollections);
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
      if (s.contains('Access token') ||
          s.contains('AuthRetryable') ||
          s.contains('JWT') ||
          e is AuthException) {
        Modular.get<SupabaseService>().clearOrg();
        await Supabase.instance.client.auth.signOut();
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
          final active = previousCollectionId != null
              ? collections.where((c) => c.id == previousCollectionId).firstOrNull
              : null;
          emit(
            ControlLoadedState(
              ControlModel(
                collections: collections,
                activeCollection: active,
                userTemplates: previous?.userTemplates ?? const [],
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
        current.copyWith(activeCollection: collection, currentItemIndex: 0, currentSlideIndex: 0),
      ),
    );
  }

  void selectItem(int itemIndex) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    emit(ControlLoadedState(current.copyWith(currentItemIndex: itemIndex, currentSlideIndex: 0)));
    _syncState();
    _scheduleAutoAdvance();
  }

  void selectSlide(int slideIndex) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    emit(ControlLoadedState(current.copyWith(currentSlideIndex: slideIndex)));
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
      emit(
        ControlLoadedState(
          model.copyWith(currentItemIndex: prevItem, currentSlideIndex: prevSlides.length - 1),
        ),
      );
      _syncState();
      _scheduleAutoAdvance();
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'type': 'stage', 'user_id': userId}),
      ),
    );
    await controller.show();
  }

  Future<void> openDisplayWindow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

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
        arguments: jsonEncode({'user_id': userId, 'screen': screenData}),
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
    final secs = model.currentItem?.autoAdvanceSecs;
    if (secs == null || secs <= 0 || !model.hasNextSlide) return;
    _autoAdvanceTimer = Timer(Duration(seconds: secs), nextSlide);
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

  void _syncState() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    _repository.upsertPresentationState(
      collectionId: model.activeCollection?.id,
      itemIndex: model.currentItemIndex,
      slideIndex: model.currentSlideIndex,
      isLive: model.isLive,
      blankScreen: model.blankScreen,
      countdownActive: model.countdownActive,
      countdownEnd: model.countdownEnd,
      overlayVisible: model.overlayVisible,
      overlayText: model.overlayText,
    );
  }
}
