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
  const ControlErrorState(this.message, {this.error, this.offlineWithoutCache = false});

  final String message;

  /// The failure itself, so the screen can word it in the operator's language.
  final Object? error;

  /// No network and nothing saved from an earlier visit: the one case where
  /// the plan really cannot be shown.
  final bool offlineWithoutCache;

  String describe(L10n t) =>
      offlineWithoutCache ? t.errorOfflineNoCache : t.errorLoading(errorText(t, error ?? message));

  @override
  List<Object?> get props => [message, error, offlineWithoutCache];
}
