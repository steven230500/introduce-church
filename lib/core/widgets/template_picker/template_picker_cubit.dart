import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/slide_template.dart';
import '../../repositories/template_repository.dart';

sealed class TemplatePickerState extends Equatable {
  const TemplatePickerState();
}

class TemplatePickerLoadingState extends TemplatePickerState {
  const TemplatePickerLoadingState();
  @override
  List<Object?> get props => [];
}

class TemplatePickerLoadedState extends TemplatePickerState {
  const TemplatePickerLoadedState({required this.custom, required this.selectedId});
  final List<SlideTemplate> custom;
  final String? selectedId;

  List<SlideTemplate> get all => [...SlideTemplate.presets, ...custom];

  TemplatePickerLoadedState copyWith({List<SlideTemplate>? custom, String? selectedId}) =>
      TemplatePickerLoadedState(
        custom: custom ?? this.custom,
        selectedId: selectedId ?? this.selectedId,
      );

  @override
  List<Object?> get props => [custom, selectedId];
}

class TemplatePickerCubit extends Cubit<TemplatePickerState> {
  TemplatePickerCubit(this._repo, {required String? initialId})
    : _initialId = initialId,
      super(const TemplatePickerLoadingState());

  final TemplateRepository _repo;
  final String? _initialId;

  TemplateRepository get repo => _repo;

  Future<void> load() async {
    final custom = await _repo.getTemplates();
    emit(
      TemplatePickerLoadedState(
        custom: custom,
        selectedId: _initialId ?? SlideTemplate.defaultTemplate.id,
      ),
    );
  }

  void select(String id) {
    if (state is TemplatePickerLoadedState) {
      emit((state as TemplatePickerLoadedState).copyWith(selectedId: id));
    }
  }

  Future<SlideTemplate?> saveNew(SlideTemplate t) async {
    final saved = await _repo.saveTemplate(t);
    if (state is TemplatePickerLoadedState) {
      final s = state as TemplatePickerLoadedState;
      emit(s.copyWith(custom: [...s.custom, saved], selectedId: saved.id));
    }
    return saved;
  }

  Future<void> updateCustom(SlideTemplate updated) async {
    await _repo.saveTemplate(updated);
    if (state is TemplatePickerLoadedState) {
      final s = state as TemplatePickerLoadedState;
      emit(s.copyWith(custom: [for (final c in s.custom) c.id == updated.id ? updated : c]));
    }
  }

  Future<void> duplicate(SlideTemplate source) async {
    final copy = source.copyWith(id: '', name: '${source.name} (copia)');
    final saved = await _repo.saveTemplate(copy);
    if (state is TemplatePickerLoadedState) {
      final s = state as TemplatePickerLoadedState;
      emit(s.copyWith(custom: [...s.custom, saved], selectedId: saved.id));
    }
  }

  Future<void> deleteCustom(String id) async {
    await _repo.deleteTemplate(id);
    if (state is TemplatePickerLoadedState) {
      final s = state as TemplatePickerLoadedState;
      emit(
        s.copyWith(
          custom: s.custom.where((c) => c.id != id).toList(),
          selectedId: s.selectedId == id ? SlideTemplate.defaultTemplate.id : s.selectedId,
        ),
      );
    }
  }
}
