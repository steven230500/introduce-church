import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/auth/children/login/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/auth/children/login/presenter/page.dart';

import '../cubit/login_cubit_test.dart' show FakeLoginRepository;

void main() {
  late FakeLoginRepository repo;
  late LoginCubit cubit;

  setUp(() {
    repo = FakeLoginRepository();
    cubit = LoginCubit(repo);
  });

  tearDown(() => cubit.close());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: BlocProvider.value(value: cubit, child: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on sign in and offers to create an account', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿Primera vez? Crea una cuenta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('the submit button stays disabled until the form is valid', (tester) async {
    await pumpLogin(tester);

    FilledButton button() => tester.widget<FilledButton>(
          find.ancestor(of: find.text('Entrar'), matching: find.byType(FilledButton)),
        );

    expect(button().onPressed, isNull, reason: 'an empty form must not submit');

    cubit.onEmailChanged('operador@iglesia.test');
    cubit.onPasswordChanged('clave-segura-123');
    await tester.pumpAndSettle();

    expect(button().onPressed, isNotNull);
  });

  testWidgets('the link switches the form to creating an account', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('¿Primera vez? Crea una cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsNWidgets(2), reason: 'title and button');
    expect(find.text('Repetir contraseña'), findsOneWidget);
    expect(find.text('Nombre (opcional)'), findsOneWidget);
    expect(find.text('¿Ya tienes cuenta? Inicia sesión'), findsOneWidget);
  });

  testWidgets('says what is wrong while the operator types', (tester) async {
    await pumpLogin(tester);

    cubit.onEmailChanged('operador@iglesia.test');
    cubit.onPasswordChanged('corta');
    await tester.pumpAndSettle();

    expect(find.textContaining('al menos 8'), findsOneWidget);
  });

  testWidgets('a mismatch is called out before submitting', (tester) async {
    await pumpLogin(tester);
    cubit.toggleMode();
    cubit.onEmailChanged('nuevo@iglesia.test');
    cubit.onPasswordChanged('clave-segura-123');
    cubit.onConfirmPasswordChanged('clave-distinta-9');
    await tester.pumpAndSettle();

    expect(find.textContaining('no coinciden'), findsOneWidget);
  });

  testWidgets('a server error reaches the operator', (tester) async {
    await pumpLogin(tester);
    repo.failWith = Exception('correo o contraseña incorrectos');
    cubit.onEmailChanged('operador@iglesia.test');
    cubit.onPasswordChanged('clave-segura-123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('incorrectos'), findsOneWidget);
  });
}
