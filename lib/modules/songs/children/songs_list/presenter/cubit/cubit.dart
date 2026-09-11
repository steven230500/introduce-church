import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/models/song.dart';
import '../../repository/repository.dart';

part 'state.dart';

class SongsListModel extends Equatable {
  const SongsListModel({this.songs = const [], this.search = ''});

  final List<Song> songs;
  final String search;

  SongsListModel copyWith({List<Song>? songs, String? search}) {
    return SongsListModel(songs: songs ?? this.songs, search: search ?? this.search);
  }

  @override
  List<Object?> get props => [songs, search];
}

class SongsListCubit extends Cubit<SongsListState> {
  SongsListCubit(this._repository) : super(const SongsListLoadingState());

  final SongsListRepository _repository;

  Future<void> load() async {
    emit(const SongsListLoadingState());
    try {
      final songs = await _repository.getSongs();
      emit(SongsListLoadedState(SongsListModel(songs: songs)));
    } catch (e) {
      emit(SongsListErrorState(e.toString()));
    }
  }

  Future<void> onSearchChanged(String value) async {
    if (state is! SongsListLoadedState) return;
    final current = (state as SongsListLoadedState).model;
    try {
      final songs = await _repository.getSongs(search: value);
      emit(SongsListLoadedState(current.copyWith(songs: songs, search: value)));
    } catch (e) {
      emit(SongsListErrorState(e.toString()));
    }
  }

  Future<void> deleteSong(String id) async {
    await _repository.deleteSong(id);
    await load();
  }
}
