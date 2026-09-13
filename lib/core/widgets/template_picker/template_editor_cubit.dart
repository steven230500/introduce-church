import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/slide_layer.dart';
import '../../models/slide_template.dart';
import '../../repositories/organization_repository.dart';
import '../../repositories/template_repository.dart';
import '../../utils/image_palette.dart';

class TemplateEditorState extends Equatable {
  const TemplateEditorState({
    required this.template,
    this.saving = false,
    this.selectedLayerId,
    this.palette = const [],
    this.photoPalette = const [],
    this.photoAverage,
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

  SlideLayer? get selectedLayer =>
      template.layers.where((l) => l.id == selectedLayerId).firstOrNull;

  /// What text on this design will actually sit on.
  ///
  /// A photo has no single colour, but it has an average, and under the
  /// darkening layer that average is close enough to tell an operator whether
  /// their grey text is going to disappear.
  int? get backdrop => switch (template.bgType) {
    BackgroundType.image =>
      photoAverage == null ? null : backdropUnderOverlay(photoAverage!, template.bgOverlayOpacity),
    _ => template.bgColor,
  };

  TemplateEditorState copyWith({
    SlideTemplate? template,
    bool? saving,
    Object? selectedLayerId = _unset,
    List<int>? palette,
    List<int>? photoPalette,
    Object? photoAverage = _unset,
  }) => TemplateEditorState(
    template: template ?? this.template,
    saving: saving ?? this.saving,
    selectedLayerId: selectedLayerId == _unset ? this.selectedLayerId : selectedLayerId as String?,
    palette: palette ?? this.palette,
    photoPalette: photoPalette ?? this.photoPalette,
    photoAverage: photoAverage == _unset ? this.photoAverage : photoAverage as int?,
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
  ];
}

class TemplateEditorCubit extends Cubit<TemplateEditorState> {
  TemplateEditorCubit(this._repo, this._orgRepo, SlideTemplate initial)
    : super(TemplateEditorState(template: initial));

  final TemplateRepository _repo;
  final OrganizationRepository _orgRepo;

  /// Reads the church's colours. A church that cannot be reached simply gets
  /// the built-in swatches, so this never blocks the editor.
  Future<void> loadPalette() async {
    readPhoto(state.template.bgImagePath);
    final colors = await _orgRepo.getPalette();
    if (isClosed || colors.isEmpty) return;
    emit(state.copyWith(palette: colors));
  }

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
    emit(
      state.copyWith(
        photoPalette: colors?.palette ?? const [],
        photoAverage: colors?.average,
      ),
    );
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
    emit(state.copyWith(template: t));
    readPhoto(t.bgImagePath);
  }

  // ── Layers: activation ───────────────────────────────────────────────────

  void enableLayers() {
    final layers = SlideLayer.defaultLayers();
    emit(
      state.copyWith(
        template: state.template.copyWith(layers: layers),
        selectedLayerId: layers.first.id,
      ),
    );
  }

  void disableLayers() {
    emit(state.copyWith(template: state.template.copyWith(layers: []), selectedLayerId: null));
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
    emit(
      state.copyWith(
        template: state.template.copyWith(layers: layers),
        selectedLayerId: layer.id,
      ),
    );
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
    emit(
      state.copyWith(
        template: state.template.copyWith(layers: layers),
        selectedLayerId: layer.id,
      ),
    );
  }

  // ── Layers: update ───────────────────────────────────────────────────────

  void updateLayer(SlideLayer layer) {
    final layers = state.template.layers.map((l) => l.id == layer.id ? layer : l).toList();
    emit(state.copyWith(template: state.template.copyWith(layers: layers)));
  }

  // ── Layers: remove ───────────────────────────────────────────────────────

  void removeLayer(String id) {
    final layers = state.template.layers.where((l) => l.id != id).toList();
    final newSelected = state.selectedLayerId == id ? null : state.selectedLayerId;
    emit(
      state.copyWith(
        template: state.template.copyWith(layers: layers),
        selectedLayerId: newSelected ?? _sentinel,
      ),
    );
  }

  // ── Layers: reorder (swap zIndex) ────────────────────────────────────────

  void reorderLayers(int oldIndex, int newIndex) {
    final layers = List<SlideLayer>.from(state.template.layers);
    if (newIndex > oldIndex) newIndex--;
    final moved = layers.removeAt(oldIndex);
    layers.insert(newIndex, moved);
    final reindexed = layers.asMap().entries.map((e) => e.value.copyWithZIndex(e.key)).toList();
    emit(state.copyWith(template: state.template.copyWith(layers: reindexed)));
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
