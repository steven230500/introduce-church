import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/repository.dart';

part 'state.dart';

/// Whether the form signs in or opens a new account.
enum LoginMode { signIn, register }

class LoginModel extends Equatable {
  const LoginModel({
    this.mode = LoginMode.signIn,
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.displayName = '',
  });

  final LoginMode mode;
  final String email;
  final String password;
  final String confirmPassword;
  final String displayName;

  bool get isRegistering => mode == LoginMode.register;

  /// Mirrors what the server enforces. A shorter minimum here would let the
  /// operator submit a password the API is going to reject anyway.
  static const minPasswordLength = 8;

  bool get emailLooksValid => email.contains('@') && email.trim().length >= 5;

  bool get passwordsMatch => password == confirmPassword;

  bool get isValid {
    if (!emailLooksValid) return false;
    if (password.length < minPasswordLength) return false;
    if (isRegistering && !passwordsMatch) return false;
    return true;
  }

  /// What to tell the operator about the form as it stands, or null when the
  /// form is fine. Shown under the fields rather than only on submit, so a
  /// mismatch is visible while they are still typing.
  String? get hint {
    if (email.isEmpty && password.isEmpty) return null;
    if (email.isNotEmpty && !emailLooksValid) return 'El correo no parece válido.';
    if (password.isNotEmpty && password.length < minPasswordLength) {
      return 'La contraseña necesita al menos $minPasswordLength caracteres.';
    }
    if (isRegistering && confirmPassword.isNotEmpty && !passwordsMatch) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  LoginModel copyWith({
    LoginMode? mode,
    String? email,
    String? password,
    String? confirmPassword,
    String? displayName,
  }) {
    return LoginModel(
      mode: mode ?? this.mode,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [mode, email, password, confirmPassword, displayName];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginIdleState());

  final LoginRepository _repository;

  LoginModel get _model => switch (state) {
    LoginIdleState s => s.model,
    LoginErrorState s => s.model,
    LoginLoadingState s => s.model,
    LoginSuccessState s => s.model,
  };

  void onEmailChanged(String value) => _update(_model.copyWith(email: value));
  void onPasswordChanged(String value) => _update(_model.copyWith(password: value));
  void onConfirmPasswordChanged(String value) => _update(_model.copyWith(confirmPassword: value));
  void onDisplayNameChanged(String value) => _update(_model.copyWith(displayName: value));

  /// Switches between signing in and creating an account, keeping whatever the
  /// operator already typed.
  void toggleMode() {
    final model = _model;
    _update(
      model.copyWith(
        mode: model.isRegistering ? LoginMode.signIn : LoginMode.register,
        confirmPassword: '',
      ),
    );
  }

  void _update(LoginModel model) => emit(LoginIdleState(model));

  Future<void> submit() async {
    if (state is LoginLoadingState) return;
    final model = _model;
    if (!model.isValid) return;

    emit(LoginLoadingState(model));
    try {
      final email = model.email.trim();
      final name = model.displayName.trim();
      final result = model.isRegistering
          ? await _repository.register(
              email: email,
              password: model.password,
              displayName: name.isEmpty ? null : name,
            )
          : await _repository.signIn(email: email, password: model.password);
      emit(LoginSuccessState(model, hasOrg: result.hasOrg));
    } catch (e) {
      emit(LoginErrorState(model, e.toString()));
    }
  }
}
