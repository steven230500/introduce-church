import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/models/song.dart';
import '../../../../../../core/services/lyric_import_service.dart';
import '../../../songs_list/repository/repository.dart';

part 'state.dart';

class SongFormCubit extends Cubit<SongFormState> {
  SongFormCubit(this._repository) : super(const SongFormLoadingState());

  final SongsListRepository _repository;

  void init(Song? existing) {
    if (existing == null) {
      emit(const SongFormReadyState(SongFormModel()));
      return;
    }
    emit(
      SongFormReadyState(
        SongFormModel(
          id: existing.id,
          title: existing.title,
          author: existing.author ?? '',
          verses: existing.verses
              .map((v) => SongFormVerse(type: v.type, content: v.content, chords: v.chords))
              .toList(),
        ),
      ),
    );
  }

  void initPrefilled(SongFormModel model) {
    emit(SongFormReadyState(model));
  }

  void updateTitle(String v) => _update((m) => m.copyWith(title: v));
  void updateAuthor(String v) => _update((m) => m.copyWith(author: v));

  void addVerse() {
    _update((m) {
      final verses = List<SongFormVerse>.from(m.verses)
        ..add(SongFormVerse(type: VerseType.verse, content: ''));
      return m.copyWith(verses: verses);
    });
  }

  void removeVerse(int index) {
    _update((m) {
      final verses = List<SongFormVerse>.from(m.verses)..removeAt(index);
      return m.copyWith(verses: verses);
    });
  }

  void updateVerseType(int index, VerseType type) {
    _update((m) {
      final verses = List<SongFormVerse>.from(m.verses);
      verses[index].type = type;
      return m.copyWith(verses: verses);
    });
  }

  void updateVerseChords(int index, String? chords) {
    if (state is! SongFormReadyState) return;
    final verses = List<SongFormVerse>.from((state as SongFormReadyState).model.verses);
    verses[index].chords = chords?.isEmpty == true ? null : chords;
    _update((m) => m.copyWith(verses: verses));
  }

  void updateVerseContent(int index, String content) {
    _update((m) {
      final verses = List<SongFormVerse>.from(m.verses);
      verses[index].content = content;
      return m.copyWith(verses: verses);
    });
  }

  void moveVerse(int oldIndex, int newIndex) {
    _update((m) {
      final verses = List<SongFormVerse>.from(m.verses);
      final item = verses.removeAt(oldIndex);
      verses.insert(newIndex, item);
      return m.copyWith(verses: verses);
    });
  }

  Future<int> importLyrics(String filePath) async {
    if (state is! SongFormReadyState) return 0;
    final model = (state as SongFormReadyState).model;
    emit(SongFormReadyState(model.copyWith(isImporting: true)));
    try {
      final result = await LyricImportService().extract(filePath);
      final verses = result.verses
          .map((v) => SongFormVerse(type: v.type, content: v.content))
          .toList();
      _update(
        (m) => m.copyWith(
          verses: verses,
          isImporting: false,
          title: (result.title?.isNotEmpty == true && m.title.isEmpty) ? result.title : null,
          author: (result.author?.isNotEmpty == true && m.author.isEmpty) ? result.author : null,
        ),
      );
      return verses.length;
    } catch (e) {
      _update((m) => m.copyWith(isImporting: false));
      emit(SongFormErrorState('Error al importar: $e'));
      return 0;
    }
  }

  Future<void> save() async {
    if (state is! SongFormReadyState) return;
    final model = (state as SongFormReadyState).model;
    if (!model.canSave) return;

    emit(SongFormReadyState(model.copyWith(isSaving: true)));
    try {
      await _repository.saveSong(
        id: model.id,
        title: model.title.trim(),
        author: model.author.trim().isEmpty ? null : model.author.trim(),
        verses: [
          for (final verse in model.verses)
            (
              type: switch (verse.type) {
                VerseType.chorus => 'chorus',
                VerseType.bridge => 'bridge',
                VerseType.preCHORUS => 'pre-chorus',
                VerseType.tag => 'tag',
                VerseType.intro => 'intro',
                VerseType.outro => 'outro',
                VerseType.verse => 'verse',
              },
              content: verse.content,
              chords: verse.chords?.isNotEmpty == true ? verse.chords : null,
            ),
        ],
      );
      emit(const SongFormSavedState());
    } catch (e) {
      final current = (state as SongFormReadyState).model;
      emit(SongFormReadyState(current.copyWith(isSaving: false)));
      emit(SongFormErrorState(e.toString()));
    }
  }

  void _update(SongFormModel Function(SongFormModel) fn) {
    if (state is! SongFormReadyState) return;
    final current = (state as SongFormReadyState).model;
    emit(SongFormReadyState(fn(current)));
  }
}
