import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/api_client.dart';
import 'package:introduce_church/modules/auth/children/login/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/auth/children/login/repository/repository.dart';

import '../helpers/fakes.dart';

/// Login repository that records what it was asked and answers as told.
class FakeLoginRepository extends LoginRepository {
  FakeLoginRepository() : super(fakeApiClient());

  final List<String> calls = [];
  bool hasOrg = false;
  Object? failWith;

  ({Session session, bool hasOrg}) _answer(String label) {
    calls.add(label);
    final failure = failWith;
    if (failure != null) throw failure;
    return (
      session: Session(
        accessToken: 'a',
        refreshToken: 'r',
        user: const AuthUser(id: 'u1', email: 'operador@iglesia.test'),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        orgId: hasOrg ? 'org-1' : null,
      ),
      hasOrg: hasOrg,
    );
  }

  @override
  Future<({Session session, bool hasOrg})> signIn({
    required String email,
    required String password,
  }) async => _answer('signIn:$email');

  @override
  Future<({Session session, bool hasOrg})> register({
    required String email,
    required String password,
    String? displayName,
  }) async => _answer('register:$email:${displayName ?? "-"}');
}

void main() {
  late FakeLoginRepository repo;
  late LoginCubit cubit;

  setUp(() {
    repo = FakeLoginRepository();
    cubit = LoginCubit(repo);
  });

  tearDown(() => cubit.close());

  LoginModel model() => cubit.state.model;

  void fillSignIn() {
    cubit.onEmailChanged('operador@iglesia.test');
    cubit.onPasswordChanged('clave-segura-123');
  }

  group('validation', () {
    test('starts invalid and silent', () {
      expect(model().isValid, isFalse);
      expect(model().hint, isNull, reason: 'an untouched form must not scold');
    });

    test('rejects a password shorter than the server accepts', () {
      cubit.onEmailChanged('operador@iglesia.test');
      cubit.onPasswordChanged('corta');

      expect(model().isValid, isFalse);
      expect(model().hint, LoginHint.password);
    });

    test('rejects an address with no @', () {
      cubit.onEmailChanged('operador');
      cubit.onPasswordChanged('clave-segura-123');

      expect(model().isValid, isFalse);
      expect(model().hint, LoginHint.email);
    });

    test('accepts a filled sign-in form', () {
      fillSignIn();

      expect(model().isValid, isTrue);
      expect(model().hint, isNull);
    });
  });

  group('registering', () {
    test('needs both passwords to match', () {
      cubit.toggleMode();
      cubit.onEmailChanged('nuevo@iglesia.test');
      cubit.onPasswordChanged('clave-segura-123');
      cubit.onConfirmPasswordChanged('clave-distinta-9');

      expect(model().isValid, isFalse);
      expect(model().hint, LoginHint.mismatch);

      cubit.onConfirmPasswordChanged('clave-segura-123');
      expect(model().isValid, isTrue);
    });

    test('switching modes keeps the typing but clears the confirmation', () {
      fillSignIn();
      cubit.onConfirmPasswordChanged('algo');

      cubit.toggleMode();

      expect(model().isRegistering, isTrue);
      expect(model().email, 'operador@iglesia.test');
      expect(model().password, 'clave-segura-123');
      expect(model().confirmPassword, isEmpty);
    });

    test('calls register, not sign in, and passes the name', () async {
      cubit.toggleMode();
      cubit.onEmailChanged('nuevo@iglesia.test');
      cubit.onDisplayNameChanged('Operador');
      cubit.onPasswordChanged('clave-segura-123');
      cubit.onConfirmPasswordChanged('clave-segura-123');

      await cubit.submit();

      expect(repo.calls, ['register:nuevo@iglesia.test:Operador']);
    });

    test('sends no name when the field was left blank', () async {
      cubit.toggleMode();
      cubit.onEmailChanged('nuevo@iglesia.test');
      cubit.onPasswordChanged('clave-segura-123');
      cubit.onConfirmPasswordChanged('clave-segura-123');

      await cubit.submit();

      expect(repo.calls.single, endsWith(':-'));
    });
  });

  group('submitting', () {
    test('trims the address before sending it', () async {
      cubit.onEmailChanged('  operador@iglesia.test  ');
      cubit.onPasswordChanged('clave-segura-123');

      await cubit.submit();

      expect(repo.calls, ['signIn:operador@iglesia.test']);
    });

    test('reports whether the account already has an organization', () async {
      repo.hasOrg = true;
      fillSignIn();

      await cubit.submit();

      expect(cubit.state, isA<LoginSuccessState>());
      expect((cubit.state as LoginSuccessState).hasOrg, isTrue);
    });

    test('surfaces the server message and keeps what was typed', () async {
      repo.failWith = const ApiException('correo o contraseña incorrectos');
      fillSignIn();

      await cubit.submit();

      expect(cubit.state, isA<LoginErrorState>());
      expect((cubit.state as LoginErrorState).message, contains('incorrectos'));
      expect(model().email, 'operador@iglesia.test');
    });

    test('does nothing when the form is incomplete', () async {
      cubit.onEmailChanged('operador@iglesia.test');

      await cubit.submit();

      expect(repo.calls, isEmpty);
    });

    test('ignores a second submit while the first is in flight', () async {
      fillSignIn();

      final first = cubit.submit();
      await cubit.submit();
      await first;

      expect(repo.calls, hasLength(1));
    });
  });
}
