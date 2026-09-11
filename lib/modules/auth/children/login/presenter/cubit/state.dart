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
  const LoginErrorState(super.model, this.message);

  final String message;

  @override
  List<Object?> get props => [model, message];
}
