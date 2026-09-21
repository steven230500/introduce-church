import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:media_kit/media_kit.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path/path.dart' as p;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../../../../core/local_db/bible_import_service.dart'
    show bundledBibleCode, bundledBibleName;
import '../../../../../../core/local_db/bible_repository.dart';
import '../../../../../../core/services/app_prefs_service.dart';
import '../../../../../../core/services/pdf_import_service.dart';
import '../../../../../../core/utils/app_logger.dart';
import '../../../../../../core/utils/new_id.dart';
import '../../../../../../core/windows/window_link.dart';
import '../../../../../../core/api/api_client.dart';
import '../../../../../../core/api/error_text.dart';
import '../../../../../../core/api/network_failure.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../core/api/presentation_socket.dart';
import '../../../../../../core/services/pending_writes.dart';
import '../../../../../../core/motion/motion_scenes.dart';
import '../../../../../../core/stream/stream_style.dart';
import '../../../../../../core/timing/service_clock.dart';
import '../../../../../../core/waiting/waiting_screen.dart';
import '../../../../../../core/services/service_file.dart';
import '../../../../../songs/children/songs_list/repository/repository.dart';
import '../../../../../../core/services/pptx_import_service.dart';
import '../../../../../../core/models/collection.dart';
import '../../../../../../core/models/collection_item_type.dart';
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
    this.gridZoom = 0,
    this.collapsedMoments = const {},
    this.openedMoments = const {},
    this.userTemplates = const [],
    this.countdownActive = false,
    this.countdownEnd,
    this.overlayVisible = false,
    this.overlayText,
    this.stageMessage,
    this.waiting = const WaitingConfig(),
    this.offline = false,
    this.pendingWrites = 0,
    this.rehearsing = false,
    this.looseSlides = const [],
    this.looseReferences = const [],
    this.looseIndex = 0,
  });

  final List<Collection> collections;
  final Collection? activeCollection;

  /// A passage put on the screen without being added to the service.
  ///
  /// The pastor asks for a verse nobody planned; the operator keeps the Bible
  /// open and sends it up. It never enters the running order, and the screen
  /// returns to the service the moment it is taken down.
  final List<String> looseSlides;
  final List<String> looseReferences;
  final int looseIndex;

  bool get looseActive => looseSlides.isNotEmpty;

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

  /// How much bigger the operator wants the slides in the grid, in columns
  /// taken away from what fits.
  ///
  /// Zero is what the app always did: as many as the window holds. One means
  /// one column fewer and so larger slides, which is what a laptop at the desk
  /// needs; below zero means smaller.
  final int gridZoom;
  final List<SlideTemplate> userTemplates;
  final bool countdownActive;
  final DateTime? countdownEnd;
  final bool overlayVisible;
  final String? overlayText;

  /// A line for the platform that the congregation never sees.
  ///
  /// The overlay goes to the projector, which is everyone. Telling the
  /// preacher they have five minutes left needed somewhere else to go.
  final String? stageMessage;

  /// The animated scene shown while nothing else is on the screen.
  final WaitingConfig waiting;

  /// True when the last read came from the cache because the server could not
  /// be reached.
  ///
  /// Everything needed to run the service is on the disk, so the presenter
  /// keeps working. What does not work is writing, and an operator who removes
  /// an item and sees nothing happen deserves to know why.
  final bool offline;

  /// Changes made with no network, waiting to be sent. Shown next to the
  /// offline mark so the operator knows there is work that has not landed yet.
  final int pendingWrites;

  /// A rehearsal is running: time goes on each item as the band works through
  /// the plan, and nothing that goes on the screen counts towards the licence
  /// report, because nobody is singing it in a service.
  final bool rehearsing;

  SlideTemplate? findTemplate(String id) =>
      SlideTemplate.findPreset(id) ?? userTemplates.where((t) => t.id == id).firstOrNull;

  /// The design [item] will be drawn with: its own, else its moment's, else
  /// the collection's, else the built-in default. One that has been deleted
  /// is passed over for the next.
  SlideTemplate templateFor(CollectionItem? item) {
    final collection = activeCollection;
    final ids = item != null && collection != null
        ? collection.designsFor(item)
        : [?collection?.templateId];
    for (final id in ids) {
      final template = findTemplate(id);
      if (template != null) return template;
    }
    return SlideTemplate.defaultTemplate;
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

  /// What the congregation is reading. A loose passage covers the service
  /// while it is up, so the operator's own output panel has to show it too:
  /// a black preview beside a screen full of words reads as a fault.
  String? get liveSlideContent {
    if (looseActive) return looseSlides[looseIndex.clamp(0, looseSlides.length - 1)];
    return liveSlides.isNotEmpty
        ? liveSlides[liveSlideIndex.clamp(0, liveSlides.length - 1)]
        : null;
  }

  String get liveSlideReference {
    if (looseActive) {
      final refs = looseReferences;
      return refs.isEmpty ? '' : refs[looseIndex.clamp(0, refs.length - 1)];
    }
    final refs = liveItem?.slideReferences ?? [];
    if (refs.isEmpty) return liveItem?.displayTitle ?? '';
    final ref = refs[liveSlideIndex.clamp(0, refs.length - 1)];
    return ref.isNotEmpty ? ref : (liveItem?.displayTitle ?? '');
  }

  /// The design the screen is using. A loose passage takes the service's
  /// design, not the design of whatever item it is covering.
  SlideTemplate get liveTemplate => templateFor(looseActive ? null : liveItem);

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
    // What comes next is what the next press puts on the screen, so a moment
    // in between is stepped over exactly as the arrows step over it.
    for (var i = currentItemIndex + 1; i < collection.items.length; i++) {
      if (!collection.items[i].isSection) return (item: collection.items[i], slide: 0);
    }
    return null;
  }

  bool get hasPrevSlide {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    if (items.isEmpty) return false;
    if (currentSlideIndex > 0) return true;
    for (var i = currentItemIndex - 1; i >= 0; i--) {
      if (!items[i].isSection) return true;
    }
    return false;
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

  /// The items the operator can actually put on the screen: the moments that
  /// divide the service are marks in the list, not things to project.
  List<CollectionItem> get playableItems => [
    for (final item in activeCollection?.items ?? const <CollectionItem>[])
      if (!item.isSection) item,
  ];

  /// Where [index] lands once the moments in front of it are not counted, so
  /// the badges read 1, 2, 3 down a service that is divided.
  int playableNumber(int index) {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    var number = 0;
    for (var i = 0; i <= index && i < items.length; i++) {
      if (!items[i].isSection) number++;
    }
    return number;
  }

  /// The moment [index] belongs to: the nearest mark above it. Null while the
  /// service has none, or for the items before the first one.
  CollectionItem? momentOf(int index) {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    for (var i = index.clamp(0, items.length - 1); i >= 0; i--) {
      if (items[i].isSection) return items[i];
    }
    return null;
  }

  /// Where a moment's items end: the next mark, or the end of the service.
  int momentEnd(int start) {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    for (var i = start + 1; i < items.length; i++) {
      if (items[i].isSection) return i - 1;
    }
    return items.length - 1;
  }

  /// The moments the operator has folded away. Held here rather than on the
  /// server: it is how one person is looking at the list right now, not
  /// something about the service.
  final Set<String> collapsedMoments;

  /// The moments the operator opened again after the service folded them on
  /// its own. What they opened stays open.
  final Set<String> openedMoments;

  /// Whether moment [id] is folded: because the operator folded it, or
  /// because the service is on the screen and has gone past it. Worship is
  /// over once the sermon starts, and the list is shorter without it.
  bool isMomentFolded(String id) {
    if (collapsedMoments.contains(id)) return true;
    if (!isLive || openedMoments.contains(id)) return false;
    final items = activeCollection?.items ?? const <CollectionItem>[];
    final at = items.indexWhere((item) => item.id == id);
    return at >= 0 && momentEnd(at) < liveItemIndex;
  }

  /// Whether [index] is inside a folded moment, which hides it unless it is
  /// the one on the screen.
  bool isFolded(int index) {
    final moment = momentOf(index);
    return moment != null && isMomentFolded(moment.id);
  }

  /// Which moment this is, counting from the top, so each one keeps its colour
  /// however the service is rearranged.
  int momentOrder(String id) {
    var order = 0;
    for (final item in activeCollection?.items ?? const <CollectionItem>[]) {
      if (!item.isSection) continue;
      if (item.id == id) return order;
      order++;
    }
    return 0;
  }

  /// How long the items under a moment are planned to take, and how many of
  /// them there are.
  ({int items, Duration planned, int unplanned}) momentLength(int start) {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    var count = 0;
    var planned = Duration.zero;
    var unplanned = 0;
    for (var i = start + 1; i <= momentEnd(start) && i < items.length; i++) {
      if (items[i].isSection) break;
      count++;
      final secs = items[i].plannedSecs;
      if (secs == null || secs <= 0) {
        unplanned++;
      } else {
        planned += Duration(seconds: secs);
      }
    }
    return (items: count, planned: planned, unplanned: unplanned);
  }

  bool get hasNextSlide {
    final items = activeCollection?.items ?? const <CollectionItem>[];
    if (items.isEmpty) return false;
    if (currentSlideIndex < currentSlides.length - 1) return true;
    // Whatever is left has to be something that can be shown: a service that
    // ends with a moment has no slide after the last song.
    for (var i = currentItemIndex + 1; i < items.length; i++) {
      if (!items[i].isSection) return true;
    }
    return false;
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
    int? gridZoom,
    Set<String>? collapsedMoments,
    Set<String>? openedMoments,
    List<SlideTemplate>? userTemplates,
    bool? countdownActive,
    DateTime? countdownEnd,
    bool clearCountdownEnd = false,
    bool? overlayVisible,
    String? overlayText,
    bool clearOverlayText = false,
    String? stageMessage,
    WaitingConfig? waiting,
    bool clearStageMessage = false,
    bool? offline,
    int? pendingWrites,
    bool? rehearsing,
    List<String>? looseSlides,
    List<String>? looseReferences,
    int? looseIndex,
    bool clearLoose = false,
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
      gridZoom: gridZoom ?? this.gridZoom,
      collapsedMoments: collapsedMoments ?? this.collapsedMoments,
      openedMoments: openedMoments ?? this.openedMoments,
      userTemplates: userTemplates ?? this.userTemplates,
      countdownActive: countdownActive ?? this.countdownActive,
      countdownEnd: clearCountdownEnd ? null : countdownEnd ?? this.countdownEnd,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      overlayText: clearOverlayText ? null : overlayText ?? this.overlayText,
      stageMessage: clearStageMessage ? null : stageMessage ?? this.stageMessage,
      waiting: waiting ?? this.waiting,
      offline: offline ?? this.offline,
      pendingWrites: pendingWrites ?? this.pendingWrites,
      looseSlides: clearLoose ? const [] : looseSlides ?? this.looseSlides,
      looseReferences: clearLoose ? const [] : looseReferences ?? this.looseReferences,
      looseIndex: clearLoose ? 0 : looseIndex ?? this.looseIndex,
      rehearsing: rehearsing ?? this.rehearsing,
    );
  }

  @override
  List<Object?> get props => [
    looseSlides,
    looseReferences,
    looseIndex,
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
    gridZoom,
    collapsedMoments,
    openedMoments,
    userTemplates,
    countdownActive,
    countdownEnd,
    overlayVisible,
    overlayText,
    stageMessage,
    waiting,
    offline,
    pendingWrites,
    rehearsing,
  ];
}

/// What opening a file actually produced, so the app can say so plainly
/// instead of "listo".
typedef ImportedService = ({
  String name,
  int items,
  int newSongs,
  int newDesigns,
  int missingMedia,
});

class ControlCubit extends Cubit<ControlState> {
  ControlCubit(
    this._repository,
    this._templateRepository,
    this._prefs,
    this._socket, {
    PendingWrites? pending,
    SongsListRepository? songs,
    ServiceClock? clock,
    DateTime Function()? now,
    String? Function()? currentOrg,
    PdfImportService? pdfImport,
    BibleRepository? bible,
  }) : _pending = pending ?? PendingWrites(),
       _bible = bible,
       _pdfImport = pdfImport ?? const PdfImportService(),
       _songs = songs,
       _clock = clock ?? ServiceClock(),
       _now = now ?? DateTime.now,
       _currentOrg = currentOrg ?? _signedInOrg,
       super(const ControlLoadingState());

  final ControlRepository _repository;
  final TemplateRepository _templateRepository;
  final AppPrefsService _prefs;
  final PresentationSocket _socket;

  /// Changes made while the server could not be reached, waiting to be sent.
  final PendingWrites _pending;

  /// Draws the pages of a PDF. Held here so a test can hand over its own.
  final PdfImportService _pdfImport;

  /// Only needed when a service is opened from a file, so it is resolved then
  /// rather than held by every presenter that never imports anything.
  final SongsListRepository? _songs;
  SongsListRepository get _songLibrary => _songs ?? Modular.get<SongsListRepository>();

  final BibleRepository? _bible;
  BibleRepository get _bibleLibrary => _bible ?? Modular.get<BibleRepository>();

  final ServiceClock _clock;
  final DateTime Function() _now;

  /// The church signed in now, which queued changes are checked against.
  final String? Function() _currentOrg;

  static String? _signedInOrg() {
    try {
      return Modular.get<ApiClient>().orgId;
    } catch (_) {
      return null;
    }
  }

  /// When the item on the screen went on it; null while nothing is live.
  DateTime? get itemStartedAt => _clock.itemStartedAt;

  DateTime? get rehearsalStartedAt => _clock.rehearsalStartedAt;

  /// Time spent on [itemId] in the rehearsal running now.
  Duration rehearsedOn(String itemId) => _clock.spentOn(itemId, _now());

  /// Every change of state passes through here, so the clock sees each move
  /// of the output without every method that moves it having to remember to
  /// say so.
  @override
  void onChange(Change<ControlState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is! ControlLoadedState) return;
    final model = next.model;
    final live = model.isLive ? model.liveItem : null;
    _clock.observe(
      collection: model.activeCollection,
      onAir: live,
      rehearsed: live ?? model.currentItem,
      now: _now(),
    );
  }

  // ── Rehearsal ─────────────────────────────────────────────────────────────

  /// Starts timing a rehearsal of the open plan.
  void startRehearsal() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final collection = model.activeCollection;
    if (collection == null || model.rehearsing) return;
    _clock.startRehearsal(collection, _now());
    emit(ControlLoadedState(model.copyWith(rehearsing: true)));
    _syncState();
  }

  /// Stops the rehearsal and returns what it measured.
  RehearsalResult? endRehearsal() {
    if (state is! ControlLoadedState) return null;
    final model = (state as ControlLoadedState).model;
    final result = _clock.endRehearsal(_now());
    emit(ControlLoadedState(model.copyWith(rehearsing: false)));
    _syncState();
    return result;
  }

  /// Keeps rehearsed lengths as the plan: [planned] maps item ids to seconds.
  Future<void> setPlannedTimes(Map<String, int?> planned) async {
    for (final entry in planned.entries) {
      await setItemPlanned(entry.key, entry.value);
    }
  }

  Future<void> setItemPlanned(String itemId, int? secs) async {
    await _write(
      PendingWrite(kind: PendingKind.itemPlanned, target: itemId, args: {'planned_secs': secs}),
      reload: false,
    );
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    CollectionItem apply(CollectionItem i) =>
        i.id == itemId ? i.copyWith(plannedSecs: secs, clearPlanned: secs == null) : i;
    Collection applyTo(Collection c) => c.copyWith(items: [for (final i in c.items) apply(i)]);
    emit(
      ControlLoadedState(
        model.copyWith(
          collections: [for (final c in model.collections) applyTo(c)],
          activeCollection: model.activeCollection == null
              ? null
              : applyTo(model.activeCollection!),
        ),
      ),
    );
    // The stage display counts the item on the screen against this.
    _syncState();
  }

  WindowController? _displayController;
  Timer? _autoAdvanceTimer;
  Timer? _overlayTimer;

  Player? _audioPlayer;

  // ── Writing with no network ───────────────────────────────────────────────

  /// Sends a change, or remembers it if the server cannot be reached.
  ///
  /// The change is applied on screen either way. Before this, an edit made in
  /// a building with no internet threw into nothing: the operator saw the old
  /// title, assumed the click had missed, and did it again.
  ///
  /// A change goes out through the same [_send] that replays the queue, so
  /// the path a Sunday with no internet takes is the one every weekday takes.
  /// Callers that already put the change on screen themselves pass
  /// `reload: false`: reloading the whole plan after a slider moves costs a
  /// round trip and makes the set list jump under the operator's hand.
  Future<void> _write(PendingWrite change, {bool reload = true}) async {
    final flushed = await _serially(() async {
      final waiting = (await _myPending()).length;
      // Anything still waiting goes first. An item sent ahead of the new
      // service it belongs to, still in the queue, would land on nothing.
      if (await _flushPendingNow() > 0) {
        await _queue(change);
        return null;
      }
      try {
        await _send(change);
      } catch (error) {
        if (!isNetworkFailure(error)) rethrow;
        await _queue(change);
        return null;
      }
      return waiting > 0;
    });
    if (flushed == null) return;
    // Emptying the queue on the way is news too: the offline mark comes off.
    if (reload || flushed) await refresh();
  }

  Future<void> _queue(PendingWrite change) async {
    final stamped = change.forOrg(_currentOrg());
    await _pending.add(stamped);
    _applyLocally(stamped, (await _myPending()).length);
  }

  /// The queued changes that belong to the church signed in now. Another
  /// church's stay on the disk, untouched, until that church signs in again.
  Future<List<PendingWrite>> _myPending() async {
    final org = _currentOrg();
    return [
      for (final change in await _pending.load())
        if (change.org == null || change.org == org) change,
    ];
  }

  /// Runs [task] after every other queue operation has finished.
  ///
  /// Two flushes at once - a refresh and an edit landing together - would
  /// each send the same queue and each save what they thought was left,
  /// and a change queued between the two would be written over.
  Future<T> _serially<T>(Future<T> Function() task) async {
    final previous = _queueLock;
    final done = Completer<void>();
    _queueLock = done.future;
    try {
      if (previous != null) await previous;
      return await task();
    } finally {
      // Let go once nothing is waiting, rather than keep a finished future
      // around: one made in another zone never runs a callback in this one.
      if (identical(_queueLock, done.future)) _queueLock = null;
      done.complete();
    }
  }

  Future<void>? _queueLock;

  /// Shows a queued change immediately, and says the app is offline.
  void _applyLocally(PendingWrite change, int waiting) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final collections = applyPendingWriteToAll(model.collections, change);
    final active = model.activeCollection == null
        ? null
        : collections.where((c) => c.id == model.activeCollection!.id).firstOrNull;
    final last = (active?.items.length ?? 1) - 1;
    emit(
      ControlLoadedState(
        model.copyWith(
          collections: collections,
          activeCollection: active,
          clearCollection: active == null,
          // An item taken out from above the cursor must not leave it pointing
          // past the end of the plan.
          currentItemIndex: model.currentItemIndex.clamp(0, last < 0 ? 0 : last),
          liveItemIndex: model.liveItemIndex.clamp(0, last < 0 ? 0 : last),
          offline: true,
          pendingWrites: waiting,
        ),
      ),
    );
  }

  /// [collections] with everything still in the queue applied over them.
  ///
  /// Over a download as well as over the cache: a change the flush could not
  /// send is still the operator's plan, and a reload must not hide it.
  static List<Collection> _withPending(List<Collection> collections, List<PendingWrite> queue) =>
      queue.fold(collections, applyPendingWriteToAll);

  /// Sends everything that was made offline, oldest first, and returns how
  /// many are still waiting.
  ///
  /// Before the fetch, never after: a reload that ran first would hand back
  /// the server's older copy and quietly undo the work on screen.
  Future<int> _flushPending() => _serially(_flushPendingNow);

  Future<int> _flushPendingNow() async {
    final queue = await _pending.load();
    if (queue.isEmpty) return 0;
    final mine = await _myPending();
    final kept = <PendingWrite>[];
    var stillWaiting = 0;
    for (final change in queue) {
      if (!mine.contains(change)) {
        kept.add(change);
        continue;
      }
      // The network gone for one change is gone for the ones after it, and
      // trying them anyway could put an item on the server before the service
      // it belongs to, if the wifi came back halfway down the list.
      if (stillWaiting > 0) {
        kept.add(change);
        stillWaiting++;
        continue;
      }
      try {
        await _send(change);
      } catch (error) {
        // Still no network: keep it. Anything else means the server has an
        // opinion about this change - a delete of something already gone, an
        // edit to an item someone else removed - and retrying it every
        // refresh forever would be worse than dropping it.
        if (isNetworkFailure(error)) {
          kept.add(change);
          stillWaiting++;
        }
      }
    }
    await _pending.save(kept);
    return stillWaiting;
  }

  Future<void> _send(PendingWrite change) async {
    final args = change.args;
    switch (change.kind) {
      case PendingKind.collectionCreate:
        final date = args['service_date'] as String?;
        await _repository.createCollection(
          id: change.target,
          name: args['name'] as String? ?? '',
          serviceDate: date == null ? null : DateTime.tryParse(date),
        );
      case PendingKind.collectionDelete:
        await _repository.deleteCollection(change.target);
      case PendingKind.collectionDetails:
        final date = args['service_date'] as String?;
        await _repository.updateCollection(
          id: change.target,
          name: args['name'] as String? ?? '',
          serviceDate: date == null ? null : DateTime.tryParse(date),
        );
      case PendingKind.collectionBgAudio:
        await _repository.updateCollectionBgAudio(change.target, args['path'] as String?);
      case PendingKind.collectionTemplate:
        await _templateRepository.setCollectionTemplate(
          change.target,
          args['template_id'] as String?,
        );
      case PendingKind.itemsAdd:
        await _repository.addItems(change.target, change.addedItems);
      case PendingKind.itemRemove:
        await _repository.removeItemFromCollection(change.target);
      case PendingKind.itemTemplate:
        await _templateRepository.setItemTemplate(change.target, args['template_id'] as String?);
      case PendingKind.itemTitle:
        await _repository.updateItemTitle(change.target, args['title'] as String? ?? '');
      case PendingKind.itemContent:
        await _repository.updateItemContent(
          change.target,
          Map<String, dynamic>.from(args['content'] as Map? ?? const {}),
        );
      case PendingKind.itemNotes:
        await _repository.updateItemNotes(change.target, args['notes'] as String?);
      case PendingKind.itemAutoAdvance:
        await _repository.updateItemAutoAdvance(change.target, args['auto_advance_secs'] as int?);
      case PendingKind.itemPlanned:
        await _repository.updateItemPlanned(change.target, args['planned_secs'] as int?);
      case PendingKind.songVerses:
        final edit = change.songEdit;
        final details = change.args['details'];
        if (details is Map) {
          // A new title or author, made on the song as the server has it.
          final current = await _repository.getSong(change.target);
          final author = details['author'] as String?;
          final renamed = current.copyWith(
            title: details['title'] as String?,
            author: author,
            clearAuthor: author == null,
          );
          if (renamed != current) await _repository.updateSong(renamed);
        } else if (edit == null) {
          // An undo: the song as it was, whole.
          final song = change.editedSong;
          if (song != null) await _repository.updateSong(song);
        } else {
          final current = await _repository.getSong(change.target);
          final replayed = edit.applyTo(current);
          if (replayed != null && replayed != current) await _repository.updateSong(replayed);
        }
      case PendingKind.itemOrder:
        await _repository.reorderItems(
          change.target,
          List<String>.from(args['item_ids'] as List? ?? const []),
        );
    }
  }

  /// How many changes are waiting for the network to come back.
  Future<int> pendingCount() async => (await _myPending()).length;

  /// Full load with a loading state. Use only for the first load and for
  /// recovering from an error screen.
  Future<void> load() async {
    // How big this machine's operator wants the slides, from the last time
    // they said so.
    _savedGridZoom = await _prefs.loadGridZoom();
    await _fetch(showSpinner: true);
  }

  int? _savedGridZoom;

  bool _passagesChecked = false;

  /// Passages saved before 1.2.0 under "RVR1960" carry the words of the
  /// Reina-Valera 1909: until then that code named only the Bible that came
  /// with the app, which was the 1909 all along. Once per session, each one
  /// whose words are the included 1909's, and not those of a 1960 the church
  /// has imported since, is given its real name.
  Future<void> _relabelMislabelledPassages(List<Collection> collections) async {
    if (_passagesChecked) return;
    _passagesChecked = true;
    try {
      final bible = _bibleLibrary;
      var relabelled = 0;
      for (final item in [for (final collection in collections) ...collection.items]) {
        final content = item.contentJson;
        if (item.type != CollectionItemType.bibleVerse || content?['version'] != 'RVR1960') {
          continue;
        }
        final book = (content?['bookIndex'] as num?)?.toInt();
        final chapter = (content?['chapter'] as num?)?.toInt();
        final start = (content?['verse'] as num?)?.toInt();
        final texts = [for (final text in content?['texts'] as List? ?? const []) '$text'];
        if (book == null || chapter == null || start == null || texts.isEmpty) continue;
        Future<bool> isIn(String code) =>
            bible.hasText(code, bookIndex: book, chapter: chapter, start: start, texts: texts);
        if (!await isIn(bundledBibleCode) || await isIn('RVR1960')) continue;
        await _write(
          PendingWrite(
            kind: PendingKind.itemContent,
            target: item.id,
            args: {
              'content': {'version': bundledBibleCode, 'versionName': bundledBibleName},
            },
          ),
          reload: false,
        );
        relabelled++;
      }
      if (relabelled > 0) await refresh();
    } catch (e) {
      // Only a label; a service must never fail to open because of it.
      appLogger.d('ControlCubit._relabelMislabelledPassages | $e');
    }
  }

  /// Reloads from the server while keeping the current screen on display.
  ///
  /// Every mutation goes through this. Emitting a loading state after an edit
  /// blanks the set list mid-service, which reads as a crash to the operator.
  Future<void> refresh() => _fetch(showSpinner: false);

  Future<void> _fetch({required bool showSpinner}) async {
    final before = state is ControlLoadedState ? (state as ControlLoadedState).model : null;
    // Read again when the answer arrives, not kept from when the question
    // left: a slide changed while the plan was loading must not be put back.
    ControlModel? previous() =>
        state is ControlLoadedState ? (state as ControlLoadedState).model : before;
    if (showSpinner) emit(const ControlLoadingState());
    try {
      final stillWaiting = await _flushPending();
      final rawCollections = await _repository.getCollectionsRaw();
      final rawTemplates = await _templateRepository.getTemplatesRaw();
      final userTemplates = TemplateRepository.parseTemplates(rawTemplates);
      final collections = _withPending(
        rawCollections.map(Collection.fromJson).toList(),
        await _myPending(),
      );
      await _prefs.saveCollections(rawCollections);
      await _prefs.saveTemplates(rawTemplates);
      emit(
        ControlLoadedState(
          _reloaded(
            previous(),
            collections: collections,
            userTemplates: userTemplates,
            // Reads worked but writes did not: as far as the operator's
            // changes are concerned, that is still no network.
            offline: stillWaiting > 0,
            pendingWrites: stillWaiting,
            savedGridZoom: _savedGridZoom,
          ),
        ),
      );
      unawaited(_relabelMislabelledPassages(collections));
    } catch (e) {
      final s = e.toString();
      if (e is ApiException && e.isAuthFailure) {
        await Modular.get<ApiClient>().signOut();
        AuthNavigator.goToLogin();
        return;
      }
      if (isNetworkFailure(e)) {
        final cached = await _prefs.loadCollections();
        if (cached != null && cached.isNotEmpty) {
          final queue = await _myPending();
          final cachedTemplates = await _prefs.loadTemplates() ?? const [];
          emit(
            ControlLoadedState(
              _reloaded(
                previous(),
                // The last download with what was done since on top: a service
                // made or an item added with no network is still there after
                // the laptop has been closed and opened again.
                collections: _withPending(cached.map(Collection.fromJson).toList(), queue),
                userTemplates: previous()?.userTemplates.isNotEmpty == true
                    ? previous()!.userTemplates
                    : TemplateRepository.parseTemplates(cachedTemplates),
                // Everything needed to run the service is on the disk. Writing
                // still works, it just waits: the queue holds it until the
                // network is back, and the operator is told how much is waiting.
                offline: true,
                pendingWrites: queue.length,
              ),
            ),
          );
          return;
        }
        emit(
          const ControlErrorState('Sin conexión y sin datos en caché.', offlineWithoutCache: true),
        );
        return;
      }
      emit(ControlErrorState('Error al cargar: ${s.split('\n').first}', error: e));
    }
  }

  /// A fresh model over [collections] that keeps everything the operator set.
  ///
  /// A refresh must not move the projector: the cursor and every broadcast
  /// flag stay exactly where they were left.
  static ControlModel _reloaded(
    ControlModel? previous, {
    required List<Collection> collections,
    required List<SlideTemplate> userTemplates,
    required bool offline,
    required int pendingWrites,
    int? savedGridZoom,
  }) {
    final activeId = previous?.activeCollection?.id;
    final active = activeId == null ? null : collections.where((c) => c.id == activeId).firstOrNull;
    final last = (active?.items.length ?? 0) - 1;
    // Never on a mark: a service that opens with "Alabanza" would otherwise
    // start with nothing to project and an output panel reading "1 of 0".
    int clampItem(int? index) {
      if (last < 0) return 0;
      final wanted = (index ?? 0).clamp(0, last);
      final items = active?.items ?? const <CollectionItem>[];
      return _skipMoments(items, wanted, forward: true) ??
          _skipMoments(items, wanted, forward: false) ??
          wanted;
    }

    return ControlModel(
      collections: collections,
      activeCollection: active,
      userTemplates: userTemplates,
      currentItemIndex: clampItem(previous?.currentItemIndex),
      currentSlideIndex: previous?.currentSlideIndex ?? 0,
      liveItemIndex: clampItem(previous?.liveItemIndex),
      liveSlideIndex: previous?.liveSlideIndex ?? 0,
      followCursor: previous?.followCursor ?? true,
      offline: offline,
      pendingWrites: pendingWrites,
      isLive: previous?.isLive ?? false,
      blankScreen: previous?.blankScreen ?? false,
      gridView: previous?.gridView ?? true,
      gridZoom: previous?.gridZoom ?? savedGridZoom ?? 0,
      collapsedMoments: previous?.collapsedMoments ?? const {},
      openedMoments: previous?.openedMoments ?? const {},
      countdownActive: previous?.countdownActive ?? false,
      countdownEnd: previous?.countdownEnd,
      overlayVisible: previous?.overlayVisible ?? false,
      overlayText: previous?.overlayText,
      stageMessage: previous?.stageMessage,
      waiting: previous?.waiting ?? const WaitingConfig(),
      rehearsing: previous?.rehearsing ?? false,
    );
  }

  void selectCollection(Collection collection) {
    if (state is! ControlLoadedState) return;
    final current = (state as ControlLoadedState).model;
    // The first thing that can go on the screen, which is not the first row
    // when the service opens with a moment.
    final first = _skipMoments(collection.items, 0, forward: true) ?? 0;
    emit(
      ControlLoadedState(
        current.copyWith(
          activeCollection: collection,
          currentItemIndex: first,
          currentSlideIndex: 0,
          liveItemIndex: first,
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
    // A moment has nothing to project. Landing on one would blank the screen,
    // so the cursor carries on to the first item under it.
    final landing = _skipMoments(items, itemIndex, forward: true);
    if (landing == null) return;
    _moveCursor(current, landing, 0);
  }

  /// The first item at or after [from] that can go on the screen, looking the
  /// way [forward] says. Null when there is none that way.
  static int? _skipMoments(List<CollectionItem> items, int from, {required bool forward}) {
    for (var i = from; i >= 0 && i < items.length; i += forward ? 1 : -1) {
      if (!items[i].isSection) return i;
    }
    return null;
  }

  /// Jumps to the nth thing that can go on the screen, counting from one and
  /// skipping the marks that divide the service.
  void selectPlayable(int number) {
    if (state is! ControlLoadedState) return;
    final items = (state as ControlLoadedState).model.activeCollection?.items;
    if (items == null) return;
    var seen = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].isSection) continue;
      if (++seen == number) {
        selectItem(i);
        return;
      }
    }
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
    // Going back to the service is how a loose passage ends.
    if (model.looseActive) model = model.copyWith(clearLoose: true);
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
    if (_moveLoose(1)) return;
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
    if (_moveLoose(-1)) return;
    final model = (state as ControlLoadedState).model;
    if (!model.hasPrevSlide) return;

    if (model.currentSlideIndex > 0) {
      selectSlide(model.currentSlideIndex - 1);
    } else {
      final items = model.activeCollection!.items;
      final prevItem = _skipMoments(items, model.currentItemIndex - 1, forward: false);
      if (prevItem == null) return;
      _moveCursor(model, prevItem, items[prevItem].slides.length - 1);
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

  /// Makes the slides in the grid bigger or smaller.
  ///
  /// The grid fits the slides to the window, which on a laptop at the desk can
  /// leave them too small to read from where the operator sits. Each step up
  /// takes a column away, so every slide grows and the grid scrolls.
  void zoomGrid(int delta) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final zoom = (model.gridZoom + delta).clamp(minGridZoom, maxGridZoom);
    if (zoom == model.gridZoom) return;
    emit(ControlLoadedState(model.copyWith(gridZoom: zoom)));
    _prefs.saveGridZoom(zoom);
  }

  /// How far the slides can be pushed either way. Three columns fewer than
  /// what fits is a single slide filling the panel; two more than fits is as
  /// small as anything is worth drawing.
  static const maxGridZoom = 3;
  static const minGridZoom = -2;

  /// Makes a new service and opens it. Works with no network: the service is
  /// named here, so everything added to it before the server hears about it
  /// already points at the right place.
  Future<void> createCollection(String name, {DateTime? serviceDate}) async {
    final id = newId();
    await _write(
      PendingWrite(
        kind: PendingKind.collectionCreate,
        target: id,
        args: {'name': name, 'service_date': serviceDate?.toIso8601String()},
      ),
    );
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final created = model.collections.where((c) => c.id == id).firstOrNull;
    if (created == null) return;
    emit(
      ControlLoadedState(
        model.copyWith(activeCollection: created, currentItemIndex: 0, currentSlideIndex: 0),
      ),
    );
  }

  Future<void> updateCollection(String id, String name, {DateTime? serviceDate}) {
    return _write(
      PendingWrite(
        kind: PendingKind.collectionDetails,
        target: id,
        args: {'name': name, 'service_date': serviceDate?.toIso8601String()},
      ),
    );
  }

  /// Copies a whole plan into a new one and opens it.
  ///
  /// Most services share a skeleton, and rebuilding it every week is the kind
  /// of work an app is for. The design and the background audio come along:
  /// a copy that loses how the slides look is not a copy of the service.
  Future<Collection?> duplicateCollection(
    Collection source, {
    required String name,
    DateTime? serviceDate,
  }) async {
    final id = newId();
    await _write(
      PendingWrite(
        kind: PendingKind.collectionCreate,
        target: id,
        args: {'name': name, 'service_date': serviceDate?.toIso8601String()},
      ),
      reload: false,
    );
    await _addItems(id, [
      for (final item in source.items) item.copiedInto(id, newId()),
    ], reload: false);
    if (source.templateId != null) {
      await _write(
        PendingWrite(
          kind: PendingKind.collectionTemplate,
          target: id,
          args: {'template_id': source.templateId},
        ),
        reload: false,
      );
    }
    if (source.bgAudioPath != null) {
      await _write(
        PendingWrite(
          kind: PendingKind.collectionBgAudio,
          target: id,
          args: {'path': source.bgAudioPath},
        ),
        reload: false,
      );
    }
    await refresh();

    if (state is! ControlLoadedState) return null;
    final model = (state as ControlLoadedState).model;
    final copy = model.collections.where((c) => c.id == id).firstOrNull;
    if (copy != null) selectCollection(copy);
    return copy;
  }

  // ── A service in a file ───────────────────────────────────────────────────

  /// The file for [collection], ready to be written to disk.
  ///
  /// Reads the designs from the current state, so what lands in the file is
  /// what the operator is actually looking at.
  String exportService(Collection collection) {
    final designs = state is ControlLoadedState
        ? (state as ControlLoadedState).model.userTemplates
        : const <SlideTemplate>[];
    return encodeService(collection, designs: [...SlideTemplate.presets, ...designs]);
  }

  /// Builds a service out of a file and opens it.
  ///
  /// Songs and designs come across as copies in this church's own library,
  /// because the church opening the file is usually not the one that made it.
  /// A song it already has is reused rather than duplicated: importing the
  /// same plan twice should not leave two of every chorus.
  Future<ImportedService> importService(String source) async {
    final file = decodeService(source);

    // Designs first: the items point at them. A design this church already
    // has is reused, the same way a song it already has is: importing the same
    // plan twice must not leave two of every background.
    final known = state is ControlLoadedState
        ? (state as ControlLoadedState).model.userTemplates
        : const <SlideTemplate>[];
    final designIds = <String, String>{};
    var newDesigns = 0;
    for (final design in file.designs) {
      final match = known.where((existing) => _sameDesign(existing, design)).firstOrNull;
      if (match != null) {
        designIds[design.id] = match.id;
        continue;
      }
      final saved = await _templateRepository.saveTemplate(design.copyWith(id: ''));
      designIds[design.id] = saved.id;
      newDesigns++;
    }

    final library = await _songLibrary.getSongs();
    // The file's song ids, mapped to this church's copy of each song.
    final songs = <String, Song>{};
    var newSongs = 0;
    for (final song in file.songs) {
      final known = library.where((existing) => _sameSong(existing, song)).firstOrNull;
      if (known != null) {
        songs[song.id] = known;
        continue;
      }
      final saved = await _songLibrary.saveSong(
        title: song.title,
        author: song.author,
        copyright: song.copyright,
        ccliNumber: song.ccliNumber,
        language: song.language,
        tags: song.tags,
        verses: [
          for (final verse in song.verses)
            (type: verse.type.value, content: verse.content, chords: verse.chords),
        ],
      );
      songs[song.id] = saved;
      newSongs++;
    }

    final id = newId();
    await _write(
      PendingWrite(
        kind: PendingKind.collectionCreate,
        target: id,
        args: {'name': file.name, 'service_date': file.serviceDate?.toIso8601String()},
      ),
      reload: false,
    );
    if (file.designId != null && designIds[file.designId] != null) {
      await _write(
        PendingWrite(
          kind: PendingKind.collectionTemplate,
          target: id,
          args: {'template_id': designIds[file.designId]},
        ),
        reload: false,
      );
    }

    await _addItems(id, [
      for (final (order, item) in file.items.indexed)
        CollectionItem(
          id: newId(),
          collectionId: id,
          type: item.type,
          order: order,
          song: songs[item.songId],
          templateId: designIds[item.designId],
          contentJson: item.content,
          notes: item.notes,
          autoAdvanceSecs: item.autoAdvanceSecs,
          plannedSecs: item.plannedSecs,
        ),
    ], reload: false);

    await refresh();
    if (state is ControlLoadedState) {
      final model = (state as ControlLoadedState).model;
      final opened = model.collections.where((c) => c.id == id).firstOrNull;
      if (opened != null) selectCollection(opened);
    }

    return (
      name: file.name,
      items: file.items.where((item) => item.type != CollectionItemType.section).length,
      newSongs: newSongs,
      newDesigns: newDesigns,
      missingMedia: file.items
          .where((item) => _carriesMedia(item.type) && !_mediaIsReachable(item.content))
          .length,
    );
  }

  /// Two designs are the same design when they are named the same and look
  /// the same. Ids never match across churches, and a name on its own would
  /// merge two different backgrounds that a church happened to call "Fondo".
  static bool _sameDesign(SlideTemplate a, SlideTemplate b) =>
      a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
      a.toJson().toString() == b.toJson().toString();

  /// Two songs are the same song when the church would say so: same title,
  /// same author. Ids never match across churches.
  static bool _sameSong(Song a, Song b) =>
      a.title.trim().toLowerCase() == b.title.trim().toLowerCase() &&
      (a.author ?? '').trim().toLowerCase() == (b.author ?? '').trim().toLowerCase();

  static bool _carriesMedia(CollectionItemType type) =>
      type == CollectionItemType.imageSlide || type == CollectionItemType.videoSlide;

  /// Whether the photo or video an item points at can still be found.
  ///
  /// A file served by the church's own API travels; a path on somebody's
  /// laptop does not, and the operator should be told before Sunday rather
  /// than seeing a broken slide during it.
  static bool _mediaIsReachable(Map<String, dynamic>? content) {
    final paths = <String>[
      ?content?['path'] as String?,
      for (final path in content?['paths'] as List? ?? const []) path as String,
    ];
    if (paths.isEmpty) return true;
    return paths.every(
      (path) =>
          path.startsWith('http://') || path.startsWith('https://') || File(path).existsSync(),
    );
  }

  Future<void> deleteCollection(String id) =>
      _write(PendingWrite(kind: PendingKind.collectionDelete, target: id, args: const {}));

  // ── Adding and removing items ─────────────────────────────────────────────

  /// The open service, when there is one to add to.
  Collection? get _openCollection =>
      state is ControlLoadedState ? (state as ControlLoadedState).model.activeCollection : null;

  /// A new item at the end of [collection], named here so it can be added
  /// with no network.
  static CollectionItem _draft(
    Collection collection,
    CollectionItemType type, {
    Song? song,
    Map<String, dynamic>? content,
    String? templateId,
  }) => CollectionItem(
    id: newId(),
    collectionId: collection.id,
    type: type,
    order: collection.items.length,
    song: song,
    templateId: templateId,
    contentJson: content,
  );

  /// Adds [items] to the end of a collection, in one request.
  ///
  /// The whole items go in the queue, songs and verses included, so what was
  /// added offline can be shown and projected before the server has it.
  Future<void> _addItems(String collectionId, List<CollectionItem> items, {bool reload = true}) {
    if (items.isEmpty) return Future.value();
    return _write(
      PendingWrite(
        kind: PendingKind.itemsAdd,
        target: collectionId,
        args: {
          'items': [for (final item in items) item.toJson()],
        },
      ),
      reload: reload,
    );
  }

  /// Adds [item] to [collection] and puts it at [index].
  ///
  /// The server only ever appends, so anything that belongs somewhere else
  /// gets there by a new running order sent straight after. The add goes
  /// first: if the order is what fails, the item is there but misplaced, which
  /// an operator can fix by dragging; the other way round it would be gone.
  Future<void> _addAt(Collection collection, CollectionItem item, int index) async {
    final ids = [
      for (final existing in collection.items)
        if (existing.id != item.id) existing.id,
    ];
    final at = index.clamp(0, ids.length);
    if (at == ids.length) return _addItems(collection.id, [item]);
    await _addItems(collection.id, [item], reload: false);
    ids.insert(at, item.id);
    await _write(
      PendingWrite(kind: PendingKind.itemOrder, target: collection.id, args: {'item_ids': ids}),
    );
  }

  Future<void> addSong(Song song) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [_draft(collection, CollectionItemType.song, song: song)]);
  }

  Future<int> importPptx(String filePath, {String? templateId}) async {
    final collection = _openCollection;
    if (collection == null) return 0;
    final slides = await PptxImportService().extractSlides(filePath);
    if (slides.isEmpty) return 0;
    await _addItems(collection.id, [
      for (final (offset, text) in slides.indexed)
        _draft(
          collection,
          CollectionItemType.freeSlide,
          content: {'text': text},
          templateId: templateId,
        ).copyWith(order: collection.items.length + offset),
    ]);
    return slides.length;
  }

  Future<int> importPptxAsImages(String filePath) async {
    final collection = _openCollection;
    if (collection == null) return 0;
    final imagePaths = await PptxImportService().extractSlidesAsImages(filePath);
    if (imagePaths.isEmpty) return 0;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.imageSlide,
        content: {'title': p.basename(filePath), 'paths': imagePaths},
      ),
    ]);
    return imagePaths.length;
  }

  /// Adds a PDF as one presentation, a page per slide.
  ///
  /// Announcements arrive as a PDF far more often than as a PowerPoint, and
  /// the page has to reach the screen as it was designed: one element with its
  /// pages, not one element per page.
  Future<int> importPdfAsImages(String filePath) async {
    final collection = _openCollection;
    if (collection == null) return 0;
    final imagePaths = await _pdfImport.renderPages(filePath);
    if (imagePaths.isEmpty) return 0;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.imageSlide,
        content: {'title': p.basenameWithoutExtension(filePath), 'paths': imagePaths},
      ),
    ]);
    return imagePaths.length;
  }

  Future<void> addAnnouncement(String message, {String? title, DateTime? timerTarget}) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.announcement,
        content: {
          'message': message,
          'title': ?title,
          'timerTarget': ?timerTarget?.toIso8601String(),
        },
      ),
    ]);
  }

  Future<void> addFreeSlide(String text, {String? title}) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(collection, CollectionItemType.freeSlide, content: {'text': text, 'title': ?title}),
    ]);
  }

  Future<void> addImageSlide(String imagePath, {String? title}) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.imageSlide,
        content: {
          'title': title ?? p.basenameWithoutExtension(imagePath),
          'paths': [imagePath],
        },
      ),
    ]);
  }

  Future<void> importVideo(String filePath) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.videoSlide,
        content: {'path': filePath, 'title': p.basenameWithoutExtension(filePath)},
      ),
    ]);
  }

  /// Adds a folder as one presentation of its images, followed by each of its
  /// videos - in one request, not one per video.
  Future<({int images, int videos})> importFolder({
    required String folderTitle,
    required List<String> imagePaths,
    required List<String> videoPaths,
  }) async {
    final collection = _openCollection;
    if (collection == null) return (images: 0, videos: 0);

    final items = [
      if (imagePaths.isNotEmpty)
        _draft(
          collection,
          CollectionItemType.imageSlide,
          content: {'title': folderTitle, 'paths': imagePaths},
        ),
      for (final videoPath in videoPaths)
        _draft(
          collection,
          CollectionItemType.videoSlide,
          content: {'path': videoPath, 'title': p.basenameWithoutExtension(videoPath)},
        ),
    ];
    await _addItems(collection.id, [
      for (final (offset, item) in items.indexed)
        item.copyWith(order: collection.items.length + offset),
    ]);
    return (images: imagePaths.isNotEmpty ? 1 : 0, videos: videoPaths.length);
  }

  Future<void> removeItem(String itemId) =>
      _write(PendingWrite(kind: PendingKind.itemRemove, target: itemId, args: const {}));

  /// Puts [item] back at [index], under its own id.
  ///
  /// The same id, so a note or a new order queued for it before it was
  /// removed still finds it, and undo works with no network as well.
  Future<void> restoreItem(CollectionItem item, int index) async {
    if (state is! ControlLoadedState) return;
    final collection = (state as ControlLoadedState).model.collections
        .where((c) => c.id == item.collectionId)
        .firstOrNull;
    if (collection == null) return;
    await _addAt(collection, item, index);
  }

  /// Adds a reading straight after the item on screen, and goes to it.
  ///
  /// Left at the end of the plan it would be out of order, and the press after
  /// it would land past the end of the service. This is the path a preacher
  /// naming a verse mid-sermon takes, so it has to come out where the service
  /// actually is.
  Future<void> addBibleVerseAfterCurrent(BibleVerseRef ref, {bool together = false}) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final collection = model.activeCollection;
    if (collection == null) return;

    final target = collection.items.isEmpty ? 0 : model.currentItemIndex + 1;
    final verse = _draft(
      collection,
      CollectionItemType.bibleVerse,
      content: {...ref.toJson(), 'together': together},
    );
    await _addAt(collection, verse, target);
    selectItem(target);
  }

  Future<void> setItemTitle(String itemId, String title) {
    return _write(
      PendingWrite(kind: PendingKind.itemTitle, target: itemId, args: {'title': title}),
    );
  }

  /// Rewrites a text slide that is already in the service.
  ///
  /// Operator and pastor write these together, and a point always comes out
  /// wrong the first time. Before this the only way to fix one was to delete
  /// the item and type the whole thing again.
  Future<void> updateFreeSlide(String itemId, {required String text, String? title}) {
    return _write(
      PendingWrite(
        kind: PendingKind.itemContent,
        target: itemId,
        args: {
          'content': {'text': text, 'title': title},
        },
      ),
    );
  }

  Future<void> updateSermon(String itemId, {required String title, required List<String> points}) {
    return _write(
      PendingWrite(
        kind: PendingKind.itemContent,
        target: itemId,
        args: {
          'content': {'title': title, 'points': points},
        },
      ),
    );
  }

  /// What the last slide edit replaced, so the operator can take it back.
  ({String itemId, Song? song, Map<String, dynamic>? content, int currentSlide, int liveSlide})?
  _lastSlideEdit;

  /// Whether there is a slide edit to take back.
  bool get canUndoSlideEdit => _lastSlideEdit != null;

  /// Corrects, splits or takes out slide [slideIndex] of item [itemId]:
  /// [parts] is what the slide becomes - one text, several, or none.
  /// Returns whether anything changed.
  ///
  /// A song's words are the church's, so the song itself changes, in every
  /// service that sings it; a sermon, a slide libre and an announcement keep
  /// their words in the item. When the item is on the screen, the screen
  /// follows at once: a typo the congregation is reading is the reason to
  /// open the editor in the middle of a service.
  Future<bool> editSlide(String itemId, int slideIndex, List<String> parts) =>
      _changeSlide(itemId, slideIndex, SlideAction.replace, parts: parts);

  /// Puts a new slide of [text] after slide [after]: a stanza the song file
  /// never had, a point the pastor added at the last minute.
  Future<bool> insertSlide(String itemId, {required int after, required String text}) =>
      _changeSlide(itemId, after, SlideAction.insert, parts: [text]);

  /// Moves slide [index] one place back ([offset] -1) or forward (1).
  Future<bool> moveSlide(String itemId, int index, int offset) =>
      _changeSlide(itemId, index, SlideAction.move, offset: offset);

  Future<bool> _changeSlide(
    String itemId,
    int slideIndex,
    SlideAction action, {
    List<String> parts = const [],
    int offset = 0,
  }) async {
    if (state is! ControlLoadedState) return false;
    final before = (state as ControlLoadedState).model;
    final items = before.activeCollection?.items ?? const <CollectionItem>[];
    final at = items.indexWhere((item) => item.id == itemId);
    if (at < 0) return false;
    final item = items[at];
    if (slideIndex < 0 || slideIndex >= item.slides.length) return false;
    final words = [
      for (final part in parts)
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final allowed = switch (action) {
      SlideAction.replace =>
        words.isEmpty
            ? item.canRemoveSlide(slideIndex)
            : item.slidesEditable && (words.length == 1 || item.canSplitSlide(slideIndex)),
      SlideAction.insert => words.length == 1 && item.canInsertSlide(slideIndex),
      SlideAction.move => offset != 0 && item.canMoveSlide(slideIndex, offset),
    };
    if (!allowed) return false;

    final song = item.song;
    if (item.type == CollectionItemType.song && song != null) {
      final edited = switch (action) {
        SlideAction.replace => song.withSlide(slideIndex, words),
        SlideAction.insert => song.withSlideInserted(slideIndex + 1, words.single),
        SlideAction.move => song.withSlideMoved(slideIndex, slideIndex + offset),
      };
      if (edited == song) return false;
      final verse = song.verses[slideIndex];
      _lastSlideEdit = (
        itemId: itemId,
        song: song,
        content: null,
        currentSlide: before.currentSlideIndex,
        liveSlide: before.liveSlideIndex,
      );
      await _write(
        PendingWrite(
          kind: PendingKind.songVerses,
          target: song.id,
          args: {
            'id': newId(),
            'song': edited.toJson(),
            'edit': SongSlideEdit(
              index: slideIndex,
              type: verse.type,
              original: verse.content,
              parts: words,
              action: action,
              offset: offset,
            ).toJson(),
          },
        ),
      );
    } else {
      final content = switch (action) {
        SlideAction.replace => item.contentWithSlide(slideIndex, words),
        SlideAction.insert => item.contentWithInsert(slideIndex, words.single),
        SlideAction.move => item.contentWithMove(slideIndex, offset),
      };
      if (content == null) return false;
      _lastSlideEdit = (
        itemId: itemId,
        song: null,
        content: {for (final key in content.keys) key: item.contentJson?[key]},
        currentSlide: before.currentSlideIndex,
        liveSlide: before.liveSlideIndex,
      );
      await _write(
        PendingWrite(kind: PendingKind.itemContent, target: itemId, args: {'content': content}),
      );
    }

    if (state is! ControlLoadedState) return true;
    final after = (state as ControlLoadedState).model;
    final updated = after.activeCollection?.items.where((i) => i.id == itemId).firstOrNull;
    if (updated == null) return true;
    final last = updated.slides.length - 1;
    int follow(int position) {
      final moved = switch (action) {
        SlideAction.replace => item.slidePositionAfterEdit(slideIndex, words, position),
        SlideAction.insert => CollectionItem.positionAfterInsert(slideIndex, position),
        SlideAction.move => CollectionItem.positionAfterMove(
          slideIndex,
          slideIndex + offset,
          position,
        ),
      };
      return moved.clamp(0, last < 0 ? 0 : last);
    }

    final editingCurrent = after.currentItemIndex == at;
    final editingLive = after.liveItemIndex == at;
    emit(
      ControlLoadedState(
        after.copyWith(
          currentSlideIndex: editingCurrent ? follow(before.currentSlideIndex) : null,
          liveSlideIndex: editingLive ? follow(before.liveSlideIndex) : null,
        ),
      ),
    );
    if (after.isLive && editingLive) _syncState();
    return true;
  }

  /// Gives the song in item [itemId] a new [title] and [author]. The song is
  /// the library's, so the name changes in every service that sings it, and
  /// on the licence report.
  Future<void> updateSongDetails(String itemId, {required String title, String? author}) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final song = model.activeCollection?.items.where((i) => i.id == itemId).firstOrNull?.song;
    final cleanTitle = title.trim();
    final cleanAuthor = author?.trim().isEmpty ?? true ? null : author!.trim();
    if (song == null || cleanTitle.isEmpty) return;
    if (song.title == cleanTitle && song.author == cleanAuthor) return;
    await _write(
      PendingWrite(
        kind: PendingKind.songVerses,
        target: song.id,
        args: {
          'id': newId(),
          'song': song
              .copyWith(title: cleanTitle, author: cleanAuthor, clearAuthor: cleanAuthor == null)
              .toJson(),
          'details': {'title': cleanTitle, 'author': cleanAuthor},
        },
      ),
    );
  }

  /// Puts back what the last slide edit changed: the song as it was, or the
  /// item's words as they were, with the operator's place and the screen
  /// where they were before it.
  Future<void> undoSlideEdit() async {
    final last = _lastSlideEdit;
    if (last == null || state is! ControlLoadedState) return;
    _lastSlideEdit = null;
    final before = last.song;
    if (before != null) {
      await _write(
        PendingWrite(
          kind: PendingKind.songVerses,
          target: before.id,
          args: {'id': newId(), 'song': before.toJson()},
        ),
      );
    } else if (last.content != null) {
      await _write(
        PendingWrite(
          kind: PendingKind.itemContent,
          target: last.itemId,
          args: {'content': last.content},
        ),
      );
    }

    if (state is! ControlLoadedState) return;
    final after = (state as ControlLoadedState).model;
    final items = after.activeCollection?.items ?? const <CollectionItem>[];
    final at = items.indexWhere((item) => item.id == last.itemId);
    if (at < 0) return;
    final end = items[at].slides.length - 1;
    int clamp(int position) => position.clamp(0, end < 0 ? 0 : end);
    emit(
      ControlLoadedState(
        after.copyWith(
          currentSlideIndex: after.currentItemIndex == at ? clamp(last.currentSlide) : null,
          liveSlideIndex: after.liveItemIndex == at ? clamp(last.liveSlide) : null,
        ),
      ),
    );
    if (after.isLive && after.liveItemIndex == at) _syncState();
  }

  /// Marks a moment of the service: "Alabanza", "Prédica", "Anuncios".
  ///
  /// It goes in the running order like everything else, and what is added
  /// after it belongs to it until the next one.
  ///
  /// With [before], it goes in front of that item: marking a service that is
  /// already made up, which used to take adding the moment at the end and
  /// dragging it up.
  Future<void> addSection(String title, {int? before}) async {
    final collection = _openCollection;
    if (collection == null) return;
    final moment = _draft(collection, CollectionItemType.section, content: {'title': title});
    if (before == null) {
      await _addItems(collection.id, [moment]);
    } else {
      await _addAt(collection, moment, before);
    }
  }

  /// Moves to the first item of the next moment, or back: to the start of
  /// this moment, or to the one before when already there. "Vamos a la
  /// ofrenda" is one key, not a scroll through the list.
  void jumpMoment({required bool forward}) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final items = model.activeCollection?.items ?? const <CollectionItem>[];
    final current = model.currentItemIndex;
    final marks = [
      for (var i = 0; i < items.length; i++)
        if (items[i].isSection) i,
    ];
    if (marks.isEmpty) return;
    if (forward) {
      final next = marks.where((m) => m > current).firstOrNull;
      if (next != null) selectItem(next);
      return;
    }
    final above = marks.where((m) => m < current).toList();
    if (above.isEmpty) return;
    final start = _skipMoments(items, above.last, forward: true);
    final atStart = start == null || current <= start;
    selectItem(atStart && above.length > 1 ? above[above.length - 2] : above.last);
  }

  /// Folds a moment away, or opens it again.
  ///
  /// Local to this operator and this sitting: what one person has folded is
  /// not something about the service, and it is not worth a round trip.
  void toggleMoment(String id) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final folded = Set<String>.from(model.collapsedMoments);
    final opened = Set<String>.from(model.openedMoments);
    if (model.isMomentFolded(id)) {
      folded.remove(id);
      opened.add(id);
    } else {
      folded.add(id);
      opened.remove(id);
    }
    emit(ControlLoadedState(model.copyWith(collapsedMoments: folded, openedMoments: opened)));
  }

  /// Adds a sermon and, right after it, the [passages] its outline names, in
  /// the order it names them: when the pastor says "Hebreos 11:6" it is the
  /// next thing in the list, not a search.
  Future<void> addSermon(
    String title,
    List<String> points, {
    List<BibleVerseRef> passages = const [],
  }) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(collection, CollectionItemType.sermon, content: {'title': title, 'points': points}),
      for (final (offset, passage) in passages.indexed)
        _draft(
          collection,
          CollectionItemType.bibleVerse,
          content: {...passage.toJson(), 'together': false},
        ).copyWith(order: collection.items.length + offset + 1),
    ]);
  }

  /// Puts a passage on the screen without adding it to the service.
  ///
  /// What the pastor asks for mid-sermon is not part of the plan and should
  /// not end up in it. The slides are built exactly as they would be for an
  /// item, so a projected loose passage looks like every other passage.
  void projectLoose(BibleVerseRef ref, {bool together = false}) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final item = CollectionItem(
      id: 'loose',
      collectionId: model.activeCollection?.id ?? '',
      type: CollectionItemType.bibleVerse,
      order: 0,
      contentJson: {...ref.toJson(), 'together': together},
    );
    if (item.slides.isEmpty) return;

    emit(
      ControlLoadedState(
        model.copyWith(
          looseSlides: item.slides,
          looseReferences: item.slideReferences,
          looseIndex: 0,
          // A verse sent to a dark screen would look like the app ignored it.
          isLive: true,
          blankScreen: false,
        ),
      ),
    );
    _syncState();
  }

  /// Takes a loose passage down. The screen goes back to the service, exactly
  /// where it was.
  void clearLoose() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.looseActive) return;
    emit(ControlLoadedState(model.copyWith(clearLoose: true)));
    _syncState();
  }

  /// Moves inside a loose passage, and says whether it could.
  bool _moveLoose(int delta) {
    if (state is! ControlLoadedState) return false;
    final model = (state as ControlLoadedState).model;
    if (!model.looseActive) return false;
    final next = model.looseIndex + delta;
    if (next < 0 || next >= model.looseSlides.length) return true;
    emit(ControlLoadedState(model.copyWith(looseIndex: next)));
    _syncState();
    return true;
  }

  Future<void> addBibleVerse(BibleVerseRef ref, {bool together = false}) async {
    final collection = _openCollection;
    if (collection == null) return;
    await _addItems(collection.id, [
      _draft(
        collection,
        CollectionItemType.bibleVerse,
        content: {...ref.toJson(), 'together': together},
      ),
    ]);
  }

  /// Moves the text of the design on the screen up or down, mid-service.
  ///
  /// The room decides this, not the desk: a banner, a row of heads, a beam
  /// that does not reach the bottom of the wall. Asking the operator to leave
  /// the presenter, find the design, open the editor and come back is asking
  /// them to do it after the service, which means never.
  ///
  /// The designs the app ships with belong to every church, so one of those is
  /// copied under [copyName] and the copy is what moves, applied wherever the
  /// original was in use.
  Future<void> nudgeLiveText(double delta, {required String copyName}) async {
    if (_nudging || state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final collection = model.activeCollection;
    if (collection == null) return;

    final design = model.liveTemplate;
    final offset = (design.textOffsetY + delta).clamp(-maxTextOffsetY, maxTextOffsetY);
    if (offset == design.textOffsetY) return;

    _nudging = true;
    try {
      if (SlideTemplate.findPreset(design.id) == null) {
        await _templateRepository.saveTemplate(design.copyWith(textOffsetY: offset));
        await refreshTemplates();
        return;
      }
      final copy = await _templateRepository.saveTemplate(
        design.copyWith(id: '', name: copyName, textOffsetY: offset),
      );
      await refreshTemplates();
      // Where the preset was chosen is where its copy goes: on the item if
      // that item had its own design, on the service otherwise.
      final item = model.looseActive ? null : model.liveItem;
      if (item?.templateId != null) {
        await setItemTemplate(collection.id, item!.id, copy.id);
      } else {
        await setCollectionTemplate(collection.id, copy.id);
      }
    } catch (_) {
      // Designs live on the server. With no network the screen keeps the one
      // it has, which is the design the church already approved.
    } finally {
      _nudging = false;
    }
  }

  /// Guards the copy a nudge may have to make: three presses on the arrow
  /// would otherwise leave three copies of the same design behind.
  bool _nudging = false;

  /// Reads the church's designs again, after one was made, changed or deleted
  /// somewhere the presenter was not looking - the library, the design picker.
  ///
  /// Without it a design made in the library and applied straight away was
  /// drawn as the built-in default, and a design changed mid-service kept its
  /// old look on the projector, both until the next full refresh.
  Future<void> refreshTemplates() async {
    if (state is! ControlLoadedState) return;
    try {
      final raw = await _templateRepository.getTemplatesRaw();
      await _prefs.saveTemplates(raw);
      if (isClosed || state is! ControlLoadedState) return;
      final model = (state as ControlLoadedState).model;
      emit(
        ControlLoadedState(model.copyWith(userTemplates: TemplateRepository.parseTemplates(raw))),
      );
      _syncState();
    } catch (_) {
      // Offline, the designs already on hand are the ones there are.
    }
  }

  /// Makes sure [templateId] is a design the presenter can draw.
  Future<void> _knowTemplate(String? templateId) async {
    if (templateId == null || state is! ControlLoadedState) return;
    if ((state as ControlLoadedState).model.findTemplate(templateId) != null) return;
    await refreshTemplates();
  }

  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    await _write(
      PendingWrite(
        kind: PendingKind.collectionTemplate,
        target: collectionId,
        args: {'template_id': templateId},
      ),
      reload: false,
    );
    await _knowTemplate(templateId);
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
    // Applying a design is asking to see it: the projector changes now, not
    // at the next slide.
    _syncState();
  }

  Future<void> setItemTemplate(String collectionId, String itemId, String? templateId) async {
    await _write(
      PendingWrite(
        kind: PendingKind.itemTemplate,
        target: itemId,
        args: {'template_id': templateId},
      ),
      reload: false,
    );
    await _knowTemplate(templateId);
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
    _syncState();
  }

  // ── Stream output ─────────────────────────────────────────────────────────

  StreamStyle? _streamStyle;
  WindowController? _streamController;

  /// The look of the streaming window on this computer.
  Future<StreamStyle> streamStyle() async =>
      _streamStyle ??= StreamStyle.fromJson(await _prefs.loadStreamStyle());

  /// Keeps [style] and applies it to the streaming window straight away.
  Future<void> setStreamStyle(StreamStyle style) async {
    _streamStyle = style;
    _syncState();
    await _prefs.saveStreamStyle(style.toJson());
  }

  /// Opens the window a streaming program captures, or brings it back.
  Future<void> openStreamWindow() async {
    if (_streamController != null) {
      try {
        await _streamController!.show();
        return;
      } catch (_) {
        // Closed from its own title bar since.
        _streamController = null;
      }
    }
    _streamController = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'type': 'stream', 'style': (await streamStyle()).toJson()}),
      ),
    );
    await _streamController!.show();
    // It opens knowing its style but not the service; this tells it both.
    _syncState();
  }

  Future<void> openStageMonitor() async {
    // The window reads the stored session itself, so it only needs to be told
    // which kind of window to be.
    final controller = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: jsonEncode({'type': 'stage'})),
    );
    await controller.show();
  }

  /// Every screen the projector window could be opened on.
  Future<List<Display>> projectorDisplays() => screenRetriever.getAllDisplays();

  /// The screen last chosen for the projector, if it is still plugged in.
  Future<Display?> rememberedProjector() async {
    final id = await _prefs.getProjectorDisplay();
    if (id == null) return null;
    final displays = await screenRetriever.getAllDisplays();
    return displays.where((d) => d.id == id).firstOrNull;
  }

  Future<void> rememberProjector(Display display) => _prefs.setProjectorDisplay(display.id);

  Future<void> openDisplayWindow({Display? on}) async {
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

    // The chosen screen, else the one chosen last time, else the second one,
    // which is the guess this used to make every time and get wrong in any
    // room wired with three.
    final displays = await screenRetriever.getAllDisplays();
    final target = on ?? await rememberedProjector() ?? (displays.length > 1 ? displays[1] : null);
    if (target != null) await rememberProjector(target);

    Map<String, dynamic> screenData = {};
    if (target != null) {
      final pos = target.visiblePosition ?? Offset.zero;
      final size = target.visibleSize ?? target.size;
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

  Future<void> updateItemNotes(String itemId, String? notes) {
    return _write(
      PendingWrite(kind: PendingKind.itemNotes, target: itemId, args: {'notes': notes}),
    );
  }

  Future<void> reorderItem(int oldIndex, int newIndex) async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final col = model.activeCollection;
    if (col == null) return;

    final items = List<CollectionItem>.from(col.items);
    // Dragging a moment carries what belongs to it. Moving the mark alone
    // would silently hand its songs to the moment above.
    final block = items[oldIndex].isSection
        ? items.sublist(oldIndex, (model.momentEnd(oldIndex) + 1).clamp(oldIndex + 1, items.length))
        : [items[oldIndex]];
    items.removeRange(oldIndex, oldIndex + block.length);
    // Where it lands, once the gap the block left is taken out of the count.
    var target = (newIndex > oldIndex ? newIndex - block.length + 1 : newIndex).clamp(
      0,
      items.length,
    );
    // A moment can only land where another one starts, or at the end. Dropped
    // halfway down "Alabanza" it would leave that moment empty and quietly
    // adopt its songs, which is not what dragging a moment means.
    if (block.first.isSection) {
      final stops = [
        0,
        for (var i = 0; i < items.length; i++)
          if (items[i].isSection) i,
        items.length,
      ];
      target = stops.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);
    }
    items.insertAll(target, block);

    final updated = col.copyWith(items: items);
    emit(ControlLoadedState(model.copyWith(activeCollection: updated)));

    final ids = items.map((i) => i.id).toList();
    await _write(
      PendingWrite(kind: PendingKind.itemOrder, target: col.id, args: {'item_ids': ids}),
      reload: false,
    );
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

  // ── Waiting screen ────────────────────────────────────────────────────────

  /// Puts a waiting scene on the screen, and remembers it for next time.
  ///
  /// Remembered on this machine because the same church opens the same loop
  /// before every service, and choosing it again each Sunday is a step
  /// somebody will skip.
  void showWaiting(WaitingConfig config) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final up = config.copyWith(active: true);
    // Putting the loop up means putting it on the screen: the signal goes live
    // and black comes off. Cutting the signal still takes everything down,
    // the loop included, because that is what cutting means.
    emit(ControlLoadedState(model.copyWith(waiting: up, isLive: true, blankScreen: false)));
    unawaited(_prefs.saveWaiting(up.copyWith(active: false).toJson()));
    _syncState();
  }

  void hideWaiting() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.waiting.active) return;
    emit(ControlLoadedState(model.copyWith(waiting: model.waiting.copyWith(active: false))));
    _syncState();
  }

  /// Up with whatever was chosen last, or down.
  Future<void> toggleWaiting() async {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.waiting.active) {
      hideWaiting();
      return;
    }
    showWaiting(await lastWaiting());
  }

  /// The scene and words chosen last time, for the picker to open on.
  Future<WaitingConfig> lastWaiting() async {
    if (state is ControlLoadedState) {
      final current = (state as ControlLoadedState).model.waiting;
      if (current.title.isNotEmpty || current.scene != MotionScene.aurora) return current;
    }
    return WaitingConfig.fromJson(await _prefs.loadWaiting());
  }

  void toggleOverlay() {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (model.overlayVisible) _overlayTimer?.cancel();
    emit(ControlLoadedState(model.copyWith(overlayVisible: !model.overlayVisible)));
    _syncState();
  }

  /// Puts a notice over whatever is projected, optionally on a clock.
  ///
  /// The clock is what makes a saved notice usable during a service: an
  /// operator who has to remember to take it down again will not.
  void showOverlay(String text, {int autoHideSecs = 0}) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    _overlayTimer?.cancel();

    emit(ControlLoadedState(model.copyWith(overlayText: text, overlayVisible: true)));
    _syncState();

    if (autoHideSecs > 0) {
      _overlayTimer = Timer(Duration(seconds: autoHideSecs), hideOverlay);
    }
  }

  void hideOverlay() {
    _overlayTimer?.cancel();
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    if (!model.overlayVisible) return;
    emit(ControlLoadedState(model.copyWith(overlayVisible: false)));
    _syncState();
  }

  /// Sends a line to the stage monitor, or clears it.
  void setStageMessage(String? message) {
    if (state is! ControlLoadedState) return;
    final model = (state as ControlLoadedState).model;
    final text = message?.trim();
    emit(
      ControlLoadedState(
        text == null || text.isEmpty
            ? model.copyWith(clearStageMessage: true)
            : model.copyWith(stageMessage: text),
      ),
    );
    _syncState();
  }

  Future<void> setCollectionBgAudio(String collectionId, String? path) async {
    await _write(
      PendingWrite(kind: PendingKind.collectionBgAudio, target: collectionId, args: {'path': path}),
      reload: false,
    );
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

  /// Tries the server again every [every] while it cannot be reached.
  ///
  /// Without it, what was queued went out only when someone next changed
  /// something or reopened the app - so a service planned offline on Saturday
  /// could still be missing from the other computers on Sunday, with the wifi
  /// back all along. Started and stopped by the presenter screen, which is
  /// what lives as long as a service does.
  void keepRetrying({Duration every = const Duration(seconds: 30)}) {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(every, (_) => _retry());
  }

  void stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Timer? _retryTimer;
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying || state is! ControlLoadedState) return;
    if (!(state as ControlLoadedState).model.offline) return;
    _retrying = true;
    try {
      await refresh();
    } finally {
      _retrying = false;
    }
  }

  @override
  Future<void> close() {
    stopRetrying();
    _autoAdvanceTimer?.cancel();
    _overlayTimer?.cancel();
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
    await _write(
      PendingWrite(
        kind: PendingKind.itemAutoAdvance,
        target: itemId,
        args: {'auto_advance_secs': secs},
      ),
      reload: false,
    );
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
      'stage_message': model.stageMessage,
      'waiting': model.waiting.toJson(),
      'loose_verse': model.looseActive
          ? {
              'content': model.looseSlides[model.looseIndex],
              'reference': model.looseReferences.length > model.looseIndex
                  ? model.looseReferences[model.looseIndex]
                  : '',
              'template_id': model.activeCollection?.templateId,
            }
          : null,
      'timing': {
        'item_started_at': _clock.itemStartedAt?.toUtc().toIso8601String(),
        'planned_secs': model.isLive ? model.liveItem?.plannedSecs : null,
        'rehearsal': model.rehearsing,
      },
    };

    // The other windows first, and over the local link, which is the only path
    // that works in a building with no internet. It carries the plan and the
    // designs with the position so nothing has to be fetched at the far end.
    unawaited(
      WindowLink.broadcast({
        ...position,
        'collection': ?_collectionRow(model.activeCollection),
        'stream_style': ?_streamStyle?.toJson(),
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
      _repository.upsertPresentationState(position).catchError((Object e) {
        appLogger.w('ControlCubit._syncState | state not written: $e');
      }),
    );
  }

  /// The plan handed to the projector and stage windows, so they never have
  /// to resolve an id over a network that, in most of these rooms, is not
  /// there.
  ///
  /// Built from the plan on the operator's screen, not kept from the last
  /// download: an item moved with no network has to be item four on the
  /// projector as well. Remembered per collection, because this goes out on
  /// every slide change and the plan changes far less often.
  Map<String, dynamic>? _collectionRow(Collection? collection) {
    if (collection == null) return null;
    if (!identical(collection, _rowFor)) {
      _rowFor = collection;
      _row = collection.toJson();
    }
    return _row;
  }

  Collection? _rowFor;
  Map<String, dynamic>? _row;

  /// The plan as the projector window is handed it now.
  @visibleForTesting
  Map<String, dynamic>? get projectedCollection => state is ControlLoadedState
      ? _collectionRow((state as ControlLoadedState).model.activeCollection)
      : null;
}
