import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/repository.dart';

part 'state.dart';

class LoginModel extends Equatable {
  const LoginModel({this.email = '', this.password = ''});

  final String email;
  final String password;

  bool get isValid => email.isNotEmpty && password.length >= 6;

  LoginModel copyWith({String? email, String? password}) {
    return LoginModel(email: email ?? this.email, password: password ?? this.password);
  }

  @override
  List<Object?> get props => [email, password];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginIdleState());

  final LoginRepository _repository;

  void onEmailChanged(String value) {
    final current = _model;
    emit(LoginIdleState(current.copyWith(email: value)));
  }

  void onPasswordChanged(String value) {
    final current = _model;
    emit(LoginIdleState(current.copyWith(password: value)));
  }

  LoginModel get _model => switch (state) {
    LoginIdleState s => s.model,
    LoginErrorState s => s.model,
    _ => const LoginModel(),
  };

  Future<void> submit() async {
    if (state is LoginLoadingState) return;
    final model = _model;
    if (!model.isValid) return;

    emit(LoginLoadingState(model));
    try {
      final result = await _repository.signIn(email: model.email, password: model.password);
      emit(LoginSuccessState(model, hasOrg: result.hasOrg));
    } catch (e) {
      emit(LoginErrorState(model, e.toString()));
    }
  }
}
