part of 'cubit.dart';

sealed class LoginState extends Equatable {
  const LoginState(this.model);
  final LoginModel model;
}

final class LoginIdleState extends LoginState {
  const LoginIdleState([super.model = const LoginModel()]);

  @override
  List<Object?> get props => [model];
}

final class LoginLoadingState extends LoginState {
  const LoginLoadingState(super.model);

  @override
  List<Object?> get props => [model];
}

final class LoginSuccessState extends LoginState {
  const LoginSuccessState(super.model, {this.hasOrg = false});

  final bool hasOrg;

  @override
  List<Object?> get props => [model, hasOrg];
}

final class LoginErrorState extends LoginState {
  const LoginErrorState(super.model, this.error);

  /// What went wrong, kept whole so the screen can say it in the operator's
  /// language by its code.
  final Object error;

  String get message => error is ApiException ? (error as ApiException).message : '$error';

  @override
  List<Object?> get props => [model, error];
}
