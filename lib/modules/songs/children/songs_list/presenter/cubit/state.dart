part of 'cubit.dart';

sealed class SongsListState extends Equatable {
  const SongsListState();
}

final class SongsListLoadingState extends SongsListState {
  const SongsListLoadingState();

  @override
  List<Object?> get props => [];
}

final class SongsListLoadedState extends SongsListState {
  const SongsListLoadedState(this.model);

  final SongsListModel model;

  @override
  List<Object?> get props => [model];
}

final class SongsListErrorState extends SongsListState {
  const SongsListErrorState(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
