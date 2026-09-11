import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/slide_template.dart';
import '../../../core/repositories/template_repository.dart';

sealed class TemplatesLibraryState extends Equatable {
  const TemplatesLibraryState();
}

class TemplatesLibraryLoadingState extends TemplatesLibraryState {
  const TemplatesLibraryLoadingState();
  @override
  List<Object?> get props => [];
}

class TemplatesLibraryLoadedState extends TemplatesLibraryState {
  const TemplatesLibraryLoadedState(this.customTemplates);
  final List<SlideTemplate> customTemplates;
  @override
  List<Object?> get props => [customTemplates];
}

class TemplatesLibraryCubit extends Cubit<TemplatesLibraryState> {
  TemplatesLibraryCubit(this._repo) : super(const TemplatesLibraryLoadingState());

  final TemplateRepository _repo;
  TemplateRepository get repo => _repo;

  Future<void> load() async {
    emit(const TemplatesLibraryLoadingState());
    final custom = await _repo.getTemplates();
    emit(TemplatesLibraryLoadedState(custom));
  }

  Future<SlideTemplate?> save(SlideTemplate t) async {
    final saved = await _repo.saveTemplate(t);
    if (state is TemplatesLibraryLoadedState) {
      final current = (state as TemplatesLibraryLoadedState).customTemplates;
      final isNew = !current.any((c) => c.id == saved.id);
      final updated = isNew
          ? [...current, saved]
          : [for (final c in current) c.id == saved.id ? saved : c];
      emit(TemplatesLibraryLoadedState(updated));
    }
    return saved;
  }

  Future<void> delete(String id) async {
    await _repo.deleteTemplate(id);
    if (state is TemplatesLibraryLoadedState) {
      final current = (state as TemplatesLibraryLoadedState).customTemplates;
      emit(TemplatesLibraryLoadedState(current.where((c) => c.id != id).toList()));
    }
  }
}
