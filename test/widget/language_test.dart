import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/locale_controller.dart';
import 'package:introduce_church/l10n/l10n_en.dart';
import 'package:introduce_church/l10n/l10n_es.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/live_bar.dart';
import 'package:introduce_church/core/services/pending_writes.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late ControlCubit control;
  late ShellCubit shell;

  setUp(() {
    control = ControlCubit(
      FakeControlRepository(rows: [collectionRow(id: 'c1')]),
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    shell = ShellCubit(prefs: FakePrefsService());
  });

  tearDown(() async {
    await control.close();
    await shell.close();
  });

  Future<void> pumpBar(WidgetTester tester, Locale locale) async {
    await tester.binding.setSurfaceSize(const Size(1400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await control.load();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: control),
          BlocProvider.value(value: shell),
        ],
        child: localizedApp(const LiveBar(), locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the language the operator picked', () {
    testWidgets('the bar is in Spanish by default', (tester) async {
      await pumpBar(tester, const Locale('es'));

      expect(find.text('En vivo'), findsOneWidget);
      expect(find.text('Negro'), findsOneWidget);
    });

    testWidgets('the bar is in English when English is chosen', (tester) async {
      // The point of the whole thing: the strings a church reads during a
      // service come from the .arb, not from the source.
      await pumpBar(tester, const Locale('en'));

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('En vivo'), findsNothing);
    });
  });

  group('every language is complete', () {
    test('no string falls back to Spanish inside the English app', () {
      // A missing key silently serves the template's text, so an English
      // operator gets a Spanish word in the middle of a sentence and nothing
      // anywhere says so.
      final es = L10nEs();
      final en = L10nEn();

      expect(en.barLive, isNot(es.barLive));
      expect(en.menuSignOut, isNot(es.menuSignOut));
      expect(en.offlineTip, isNot(es.offlineTip));
    });

    test('the plural reads correctly at one and at many', () {
      final en = L10nEn();

      expect(en.offlineWithChanges(1), contains('1 change'));
      expect(en.offlineWithChanges(4), contains('4 changes'));
    });

    test('each language is named in its own words', () {
      // "Spanish" in an English list is no use to someone who only reads
      // Spanish, which is exactly the person looking for it.
      expect(L10nEs().languageName, 'Español');
      expect(L10nEn().languageName, 'English');
    });

    test('the picker offers every language the app has strings for', () {
      expect(LocaleController.supported.map((l) => l.languageCode), ['es', 'en']);
    });
  });

  group('remembering the choice', () {
    test('a machine that was never told follows the computer', () async {
      final controller = LocaleController(FakePrefsService());
      await controller.load();

      expect(controller.value, isNull);
    });

    test('a chosen language survives the app being closed', () async {
      final prefs = FakePrefsService();
      await LocaleController(prefs).choose(const Locale('en'));

      final reopened = LocaleController(prefs);
      await reopened.load();

      expect(reopened.value?.languageCode, 'en');
    });

    test('going back to the computer forgets the choice', () async {
      final prefs = FakePrefsService();
      final controller = LocaleController(prefs);
      await controller.choose(const Locale('en'));

      await controller.choose(null);

      final reopened = LocaleController(prefs);
      await reopened.load();
      expect(reopened.value, isNull);
    });
  });
}
