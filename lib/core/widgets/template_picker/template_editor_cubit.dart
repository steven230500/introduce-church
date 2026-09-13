import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/slide_layer.dart';
import '../../models/slide_template.dart';
import '../../repositories/organization_repository.dart';
import '../../repositories/template_repository.dart';
import '../../motion/motion_scenes.dart';
import '../../utils/image_palette.dart';

class TemplateEditorState extends Equatable {
  const TemplateEditorState({
    required this.template,
    this.saving = false,
    this.selectedLayerId,
    this.palette = const [],
    this.photoPalette = const [],
    this.photoAverage,
    this.canUndo = false,
    this.canRedo = false,
    this.dirty = false,
  });

  final SlideTemplate template;
  final bool saving;
  final String? selectedLayerId;

  /// The colours this church has saved, offered before the built-in swatches.
  final List<int> palette;

  /// The colours the background photo is made of, when there is one.
  final List<int> photoPalette;

  /// The one colour that stands for that photo, used to judge readability.
  final int? photoAverage;

  /// Whether there is a step to go back to, and one to come forward to.
  final bool canUndo;
  final bool canRedo;

  /// Whether anything has been changed since the editor opened. Closing on a
  /// design in this state throws work away, so it is worth one question.
  final bool dirty;

  SlideLayer? get selectedLayer =>
      template.layers.where((l) => l.id == selectedLayerId).firstOrNull;

  /// What text on this design will actually sit on.
  ///
  /// A photo has no single colour, but it has an average, and under the
  /// darkening layer that average is close enough to tell an operator whether
  /// their grey text is going to disappear.
  int? get backdrop => switch (template.bgType) {
    BackgroundType.image || BackgroundType.video =>
      photoAverage == null ? null : backdropUnderOverlay(photoAverage!, template.bgOverlayOpacity),
    // A scene never holds still long enough to be measured, so it is judged by
    // the colour it was drawn around.
    BackgroundType.motion => backdropUnderOverlay(
      MotionSceneX.fromId(template.bgMotion).baseColor,
      template.bgOverlayOpacity,
    ),
    _ => template.bgColor,
  };

  TemplateEditorState copyWith({
    SlideTemplate? template,
    bool? saving,
    Object? selectedLayerId = _unset,
    List<int>? palette,
    List<int>? photoPalette,
    Object? photoAverage = _unset,
    bool? canUndo,
    bool? canRedo,
    bool? dirty,
  }) => TemplateEditorState(
    template: template ?? this.template,
    saving: saving ?? this.saving,
    selectedLayerId: selectedLayerId == _unset ? this.selectedLayerId : selectedLayerId as String?,
    palette: palette ?? this.palette,
    photoPalette: photoPalette ?? this.photoPalette,
    photoAverage: photoAverage == _unset ? this.photoAverage : photoAverage as int?,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    dirty: dirty ?? this.dirty,
  );

  static const _unset = Object();

  @override
  List<Object?> get props => [
    template,
    saving,
    selectedLayerId,
    palette,
    photoPalette,
    photoAverage,
    canUndo,
    canRedo,
    dirty,
  ];
}

class TemplateEditorCubit extends Cubit<TemplateEditorState> {
  TemplateEditorCubit(this._repo, this._orgRepo, SlideTemplate initial)
    : _opened = _fingerprint(initial),
      super(TemplateEditorState(template: initial));

  final TemplateRepository _repo;
  final OrganizationRepository _orgRepo;

  // ── History ──────────────────────────────────────────────────────────────
  //
  // Designing is trying things. Without a way back, an operator who nudges a
  // slider and does not like it has to remember the number it was on, and one
  // that they cannot remember means starting the design again.

  /// The design as the editor opened it, so undoing all the way back is known
  /// to be back and not merely earlier.
  final String _opened;

  final _past = <SlideTemplate>[];
  final _future = <SlideTemplate>[];

  /// Deep enough to cover an evening's fiddling, shallow enough that a hundred
  /// copies of a design never sit in memory.
  static const _depth = 60;

  String? _lastTag;
  var _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  static String _fingerprint(SlideTemplate t) => t.toJson().toString();

  /// Keeps the current design so the change about to be made can be taken back.
  ///
  /// [tag] says what kind of change it is. Two changes of the same kind, close
  /// together, are one step: a slider dragged across the panel is one thing the
  /// operator did, not forty presses of undo.
  void _remember(String tag) {
    final now = DateTime.now();
    final continuing =
        tag == _lastTag && now.difference(_lastAt) < const Duration(milliseconds: 700);
    _lastTag = tag;
    _lastAt = now;
    _future.clear();
    if (continuing && _past.isNotEmpty) return;
    _past.add(state.template);
    if (_past.length > _depth) _past.removeAt(0);
  }

  void undo() {
    if (_past.isEmpty) return;
    _future.add(state.template);
    _restore(_past.removeLast());
  }

  void redo() {
    if (_future.isEmpty) return;
    _past.add(state.template);
    _restore(_future.removeLast());
  }

  void _restore(SlideTemplate t) {
    // The next change starts a new step even if it is the same kind as the one
    // just undone.
    _lastTag = null;
    // A layer that the step being restored does not have cannot stay selected.
    final selected = t.layers.any((l) => l.id == state.selectedLayerId)
        ? state.selectedLayerId
        : null;
    emit(
      state.copyWith(
        template: t,
        selectedLayerId: selected,
        canUndo: _past.isNotEmpty,
        canRedo: _future.isNotEmpty,
        dirty: _fingerprint(t) != _opened,
      ),
    );
    readPhoto(photoOf(t));
  }

  /// Emits a change that undo can take back.
  void _change(SlideTemplate next, String tag, {Object? select = _keep}) {
    _remember(tag);
    emit(
      state.copyWith(
        template: next,
        selectedLayerId: select == _keep ? _keep : select as String?,
        canUndo: true,
        canRedo: false,
        dirty: _fingerprint(next) != _opened,
      ),
    );
  }

  /// Passed through to copyWith's own sentinel so "leave the selection alone"
  /// stays different from "clear it".
  static const _keep = TemplateEditorState._unset;

  /// Reads the church's colours. A church that cannot be reached simply gets
  /// the built-in swatches, so this never blocks the editor.
  Future<void> loadPalette() async {
    readPhoto(photoOf(state.template));
    final colors = await _orgRepo.getPalette();
    if (isClosed || colors.isEmpty) return;
    emit(state.copyWith(palette: colors));
  }

  /// The picture whose colours are worth reading for [t]: its photo, or the
  /// still frame of its loop. Nothing for a colour or a scene.
  static String? photoOf(SlideTemplate t) => switch (t.bgType) {
    BackgroundType.image => t.bgImagePath,
    BackgroundType.video => t.bgPosterPath,
    _ => null,
  };

  /// The path whose colours are in the state, so a photo is read once and a
  /// slider drag does not decode it on every frame.
  String? _photoFor;

  /// Pulls the colours out of the background photo.
  ///
  /// Nothing waits on this: the swatches appear when the file has been read,
  /// and a photo that cannot be read costs the extra swatches and nothing else.
  Future<void> readPhoto(String? path) async {
    if (path == _photoFor) return;
    _photoFor = path;
    if (path == null || path.isEmpty) {
      emit(state.copyWith(photoPalette: const [], photoAverage: null));
      return;
    }
    final colors = await readPhotoColors(path);
    // A second photo may have been chosen while this one was being read.
    if (isClosed || _photoFor != path) return;
    emit(state.copyWith(photoPalette: colors?.palette ?? const [], photoAverage: colors?.average));
  }

  /// Keeps a colour for the whole church, so the next design can reach it.
  Future<void> saveColor(int colour) async {
    if (state.palette.contains(colour)) return;
    final next = [...state.palette, colour];
    emit(state.copyWith(palette: next));
    final saved = await _orgRepo.setPalette(next);
    if (!isClosed) emit(state.copyWith(palette: saved));
  }

  Future<void> forgetColor(int colour) async {
    final next = [...state.palette]..remove(colour);
    emit(state.copyWith(palette: next));
    final saved = await _orgRepo.setPalette(next);
    if (!isClosed) emit(state.copyWith(palette: saved));
  }

  // ── Flat template update ──────────────────────────────────────────────────

  void update(SlideTemplate t) {
    _change(t, _whatChanged(state.template, t));
    readPhoto(photoOf(t));
  }

  /// Which fields differ, as a tag. Dragging one slider reports the same tag
  /// every frame, which is what lets those frames collapse into one step.
  static String _whatChanged(SlideTemplate before, SlideTemplate after) {
    final a = before.toJson();
    final b = after.toJson();
    final keys = {...a.keys, ...b.keys}.where((k) => '${a[k]}' != '${b[k]}').toList()..sort();
    return keys.join(',');
  }

  // ── Layers: activation ───────────────────────────────────────────────────

  void enableLayers() {
    final layers = SlideLayer.defaultLayers();
    _change(state.template.copyWith(layers: layers), 'mode', select: layers.first.id);
  }

  void disableLayers() {
    _change(state.template.copyWith(layers: []), 'mode', select: null);
  }

  // ── Layers: selection ────────────────────────────────────────────────────

  void selectLayer(String? id) => emit(state.copyWith(selectedLayerId: id ?? _sentinel));

  static const _sentinel = null;

  // ── Layers: add ──────────────────────────────────────────────────────────

  void addTextLayer() {
    final layers = List<SlideLayer>.from(state.template.layers);
    final layer = TextSlideLayer(
      id: newLayerId(),
      x: 0.1,
      y: 0.1,
      width: 0.8,
      height: 0.5,
      zIndex: layers.length,
      fontSize: 48,
      fontWeight: 300,
      textColor: 0xFFFFFFFF,
      textAlign: TextAlign.center,
      textShadow: true,
    );
    layers.add(layer);
    _change(state.template.copyWith(layers: layers), 'add:${layer.id}', select: layer.id);
  }

  void addReferenceLayer() {
    final layers = List<SlideLayer>.from(state.template.layers);
    final layer = ReferenceSlideLayer(
      id: newLayerId(),
      x: 0.05,
      y: 0.87,
      width: 0.90,
      height: 0.09,
      zIndex: layers.length,
      fontSize: 15,
      textColor: 0xFFAAAAAA,
      textAlign: TextAlign.right,
    );
    layers.add(layer);
    _change(state.template.copyWith(layers: layers), 'add:${layer.id}', select: layer.id);
  }

  // ── Layers: update ───────────────────────────────────────────────────────

  void updateLayer(SlideLayer layer) {
    final layers = state.template.layers.map((l) => l.id == layer.id ? layer : l).toList();
    _change(state.template.copyWith(layers: layers), 'layer:${layer.id}');
  }

  // ── Layers: remove ───────────────────────────────────────────────────────

  void removeLayer(String id) {
    final layers = state.template.layers.where((l) => l.id != id).toList();
    final newSelected = state.selectedLayerId == id ? null : state.selectedLayerId;
    _change(state.template.copyWith(layers: layers), 'remove:$id', select: newSelected);
  }

  // ── Layers: reorder (swap zIndex) ────────────────────────────────────────

  void reorderLayers(int oldIndex, int newIndex) {
    final layers = List<SlideLayer>.from(state.template.layers);
    if (newIndex > oldIndex) newIndex--;
    final moved = layers.removeAt(oldIndex);
    layers.insert(newIndex, moved);
    final reindexed = layers.asMap().entries.map((e) => e.value.copyWithZIndex(e.key)).toList();
    _change(state.template.copyWith(layers: reindexed), 'reorder');
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<SlideTemplate?> save(String name) async {
    emit(state.copyWith(saving: true));
    try {
      final named = state.template.copyWith(
        name: name.trim().isEmpty ? 'Mi template' : name.trim(),
      );
      return await _repo.saveTemplate(named);
    } catch (_) {
      return null;
    } finally {
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }
}
