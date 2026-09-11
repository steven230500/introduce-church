import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/slide_layer.dart';
import '../../models/slide_template.dart';
import '../../repositories/template_repository.dart';

class TemplateEditorState extends Equatable {
  const TemplateEditorState({required this.template, this.saving = false, this.selectedLayerId});

  final SlideTemplate template;
  final bool saving;
  final String? selectedLayerId;

  SlideLayer? get selectedLayer =>
      template.layers.where((l) => l.id == selectedLayerId).firstOrNull;

  TemplateEditorState copyWith({
    SlideTemplate? template,
    bool? saving,
    Object? selectedLayerId = _unset,
  }) => TemplateEditorState(
    template: template ?? this.template,
    saving: saving ?? this.saving,
    selectedLayerId: selectedLayerId == _unset ? this.selectedLayerId : selectedLayerId as String?,
  );

  static const _unset = Object();

  @override
  List<Object?> get props => [template, saving, selectedLayerId];
}

class TemplateEditorCubit extends Cubit<TemplateEditorState> {
  TemplateEditorCubit(this._repo, SlideTemplate initial)
    : super(TemplateEditorState(template: initial));

  final TemplateRepository _repo;

  // ── Flat template update ──────────────────────────────────────────────────

  void update(SlideTemplate t) => emit(state.copyWith(template: t));

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
