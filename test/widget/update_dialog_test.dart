import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/locale_controller.dart';
import 'package:introduce_church/core/services/update_checker.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/settings_dialog.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/update_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

const _update = AvailableUpdate(
  version: '1.2.0',
  pageUrl: 'https://github.com/steven230500/introduce-church/releases/tag/v1.2.0',
  downloadUrl:
      'https://github.com/steven230500/introduce-church/releases/download/v1.2.0/Introduce-macOS-1.2.0.zip',
);

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {Locale locale = const Locale('es')}) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(localizedApp(child, locale: locale));
    await tester.pumpAndSettle();
  }

  group('the update dialog', () {
    testWidgets('says which version is out and which one is here', (tester) async {
      await pump(tester, UpdateDialog(update: _update, current: '1.0.1', open: (_) async {}));

      expect(find.text('Introduce 1.2.0'), findsOneWidget);
      expect(find.textContaining('1.0.1'), findsOneWidget);
      expect(find.textContaining('Aplicaciones'), findsOneWidget);
    });

    testWidgets('download opens the zip, and what changed opens the release', (tester) async {
      final opened = <String>[];
      await pump(
        tester,
        UpdateDialog(update: _update, current: '1.0.1', open: (url) async => opened.add(url)),
      );

      await tester.tap(find.text('Qué cambió'));
      await tester.tap(find.text('Descargar'));

      expect(opened, [_update.pageUrl, _update.downloadUrl]);
    });

    testWidgets('on Windows it explains replacing the folder', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pump(
        tester,
        UpdateDialog(update: _update, current: '1.0.1', open: (_) async {}),
        locale: const Locale('en'),
      );

      expect(find.textContaining('replace its folder'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('the version in settings', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      UpdateChecker updates, {
      void Function(AvailableUpdate)? onOpen,
    }) => pump(
      tester,
      SettingsDialog(
        user: null,
        locale: LocaleController(FakePrefsService()),
        displays: () async => const [],
        rememberedDisplay: () async => null,
        rememberDisplay: (_) async {},
        onChangePassword: () {},
        onSignOut: () {},
        updates: updates,
        version: '1.0.1',
        onOpenUpdate: onOpen,
      ),
    );

    testWidgets('shows the version, and says when it is the latest', (tester) async {
      await pumpSettings(
        tester,
        UpdateChecker(
          fetchLatest: () async => const {'tag_name': 'v1.0.1', 'html_url': 'x', 'assets': []},
          current: '1.0.1',
          platform: 'macos',
        ),
      );

      expect(find.text('Introduce 1.0.1'), findsOneWidget);

      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Es la versión más reciente.'), findsOneWidget);
    });

    testWidgets('says so plainly when GitHub cannot be reached', (tester) async {
      await pumpSettings(
        tester,
        UpdateChecker(
          fetchLatest: () async => throw Exception('offline'),
          current: '1.0.1',
          platform: 'macos',
        ),
      );

      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo llegar a GitHub'), findsOneWidget);
    });

    testWidgets('a found update is one click from its dialog', (tester) async {
      final updates = UpdateChecker(
        fetchLatest: () async => const {},
        current: '1.0.1',
        platform: 'macos',
      )..available.value = _update;
      AvailableUpdate? opened;
      await pumpSettings(tester, updates, onOpen: (update) => opened = update);

      await tester.tap(find.text('Actualizar a la 1.2.0'));

      expect(opened, same(_update));
    });
  });
}
