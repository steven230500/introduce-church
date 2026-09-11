part of 'cubit.dart';

sealed class ControlState extends Equatable {
  const ControlState();
}

final class ControlLoadingState extends ControlState {
  const ControlLoadingState();

  @override
  List<Object?> get props => [];
}

final class ControlLoadedState extends ControlState {
  const ControlLoadedState(this.model);

  final ControlModel model;

  @override
  List<Object?> get props => [model];
}

final class ControlErrorState extends ControlState {
  const ControlErrorState(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
