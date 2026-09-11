part of 'cubit.dart';

class SongFormVerse {
  SongFormVerse({required this.type, required this.content, this.chords});
  VerseType type;
  String content;
  String? chords;
}

class SongFormModel extends Equatable {
  const SongFormModel({
    this.id,
    this.title = '',
    this.author = '',
    this.verses = const [],
    this.isSaving = false,
    this.isImporting = false,
  });

  final String? id;
  final String title;
  final String author;
  final List<SongFormVerse> verses;
  final bool isSaving;
  final bool isImporting;

  bool get isEditing => id != null;
  bool get canSave => title.trim().isNotEmpty && !isSaving && !isImporting;

  SongFormModel copyWith({
    String? id,
    String? title,
    String? author,
    List<SongFormVerse>? verses,
    bool? isSaving,
    bool? isImporting,
  }) {
    return SongFormModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      verses: verses ?? this.verses,
      isSaving: isSaving ?? this.isSaving,
      isImporting: isImporting ?? this.isImporting,
    );
  }

  @override
  List<Object?> get props => [id, title, author, verses, isSaving, isImporting];
}

sealed class SongFormState extends Equatable {
  const SongFormState();
  @override
  List<Object?> get props => [];
}

class SongFormLoadingState extends SongFormState {
  const SongFormLoadingState();
}

class SongFormReadyState extends SongFormState {
  const SongFormReadyState(this.model);
  final SongFormModel model;
  @override
  List<Object?> get props => [model];
}

class SongFormSavedState extends SongFormState {
  const SongFormSavedState();
}

class SongFormErrorState extends SongFormState {
  const SongFormErrorState(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
