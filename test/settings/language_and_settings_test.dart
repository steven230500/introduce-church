import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/api_client.dart';
import 'package:introduce_church/core/services/locale_controller.dart';
import 'package:introduce_church/modules/auth/children/language/language_page.dart';
import 'package:introduce_church/modules/auth/children/splash/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/auth/children/splash/presenter/cubit/state.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/settings_dialog.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  group('the first time the app opens', () {
    Future<SplashState> launch(FakePrefsService prefs) async {
      final splash = SplashCubit(ApiClient(Dio(), prefs), prefs);
      addTearDown(splash.close);
      await splash.check();
      return splash.state;
    }

    test('a new computer is asked its language before anything else', () async {
      expect(await launch(FakePrefsService()), isA<SplashNavigateLanguage>());
    });

    test('once answered, it goes on to sign in', () async {
      final prefs = FakePrefsService();
      await LocaleController(prefs).choose(const Locale('en'));

      expect(await launch(prefs), isA<SplashNavigateLogin>());
    });

    test('following the computer is an answer too', () async {
      final prefs = FakePrefsService();
      await LocaleController(prefs).choose(null);

      expect(await launch(prefs), isA<SplashNavigateLogin>());
    });

    test('a computer already in use is not asked, and not asked later either', () async {
      // Churches that have read the app in Spanish for months should not be
      // stopped by a question the day they update.
      final prefs = FakePrefsService()..saved = const [];

      expect(await launch(prefs), isNot(isA<SplashNavigateLanguage>()));
      expect(prefs.languageWasAsked, isTrue);
    });
  });

  group('the language screen', () {
    testWidgets('speaks both languages before one is chosen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localizedApp(
          LanguagePage(controller: LocaleController(FakePrefsService()), onChosen: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elige el idioma'), findsOneWidget);
      expect(find.text('Choose your language'), findsOneWidget);
    });

    testWidgets('choosing one keeps it and moves on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final prefs = FakePrefsService();
      final controller = LocaleController(prefs);
      var movedOn = false;
      await tester.pumpWidget(
        localizedApp(LanguagePage(controller: controller, onChosen: () => movedOn = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(controller.value?.languageCode, 'en');
      expect(prefs.locale, 'en');
      expect(movedOn, isTrue);
    });
  });

  group('settings', () {
    Future<LocaleController> pumpSettings(
      WidgetTester tester, {
      List<Display> displays = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = LocaleController(FakePrefsService());
      await tester.pumpWidget(
        localizedApp(
          SettingsDialog(
            user: null,
            locale: controller,
            displays: () async => displays,
            rememberedDisplay: () async => null,
            rememberDisplay: (_) async {},
            onChangePassword: () {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('the language can be changed there', (tester) async {
      final controller = await pumpSettings(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(controller.value?.languageCode, 'en');

      await tester.tap(find.text('El del sistema'));
      await tester.pumpAndSettle();
      expect(controller.value, isNull);
    });

    testWidgets('with one screen there is no projector to choose', (tester) async {
      await pumpSettings(
        tester,
        displays: [Display(id: '1', size: const Size(1440, 900))],
      );

      expect(find.text('Solo hay una pantalla conectada.'), findsOneWidget);
      expect(find.text('Elegir pantalla'), findsNothing);
    });

    testWidgets('with two, the projector screen can be chosen', (tester) async {
      await pumpSettings(
        tester,
        displays: [
          Display(id: '1', size: const Size(1440, 900)),
          Display(id: '2', name: 'Proyector', size: const Size(1920, 1080)),
        ],
      );

      expect(find.text('Se elige la primera vez que proyectas.'), findsOneWidget);
      expect(find.text('Elegir pantalla'), findsOneWidget);
    });
  });
}
