import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/session.dart';
import 'package:introduce_church/core/services/locale_controller.dart';
import 'package:introduce_church/l10n/l10n.dart';
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

  Future<void> pumpLogin(WidgetTester tester, {Locale locale = const Locale('es')}) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        locale: locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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

  group('in English', () {
    testWidgets('the form reads in English', (tester) async {
      await pumpLogin(tester, locale: const Locale('en'));

      expect(find.text('Sign in'), findsNWidgets(2), reason: 'title and button');
      expect(find.text('First time? Create an account'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);
    });

    testWidgets('a wrong password is said in English, not in the server\'s Spanish', (
      tester,
    ) async {
      // The server words it in Spanish; its code is what the screen reads.
      await pumpLogin(tester, locale: const Locale('en'));
      repo.failWith = const ApiException(
        'correo o contraseña incorrectos',
        statusCode: 401,
        code: 'invalid_credentials',
      );
      cubit.onEmailChanged('operator@church.test');
      cubit.onPasswordChanged('a-safe-password');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Wrong email or password.'), findsOneWidget);
    });

    testWidgets('a short password is explained in English while typing', (tester) async {
      await pumpLogin(tester, locale: const Locale('en'));
      cubit.onEmailChanged('operator@church.test');
      cubit.onPasswordChanged('short');
      await tester.pumpAndSettle();

      expect(find.text('The password needs at least 8 characters.'), findsOneWidget);
    });
  });

  testWidgets('switching to a new account keeps each word in its own field', (tester) async {
    // The name field appears above the others, and the text typed into the
    // email field used to move up into it.
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'operador@iglesia.test');
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿Primera vez? Crea una cuenta'));
    await tester.pumpAndSettle();

    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextField, 'Nombre (opcional)'),
        matching: find.byType(EditableText),
      ),
    );
    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextField, 'Email'),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, isEmpty);
    expect(email.controller.text, 'operador@iglesia.test');
  });
}
