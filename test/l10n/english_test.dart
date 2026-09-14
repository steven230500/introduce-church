import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/labels.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/l10n/l10n_en.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/page.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// Screens that have been moved to the .arb files. A Spanish word typed back
/// into one of them is what this is here to catch.
const _swept = [
  'lib/modules/presentation/shell/library/bible_panel.dart',
  'lib/modules/presentation/shell/library/library_dock.dart',
  'lib/modules/presentation/shell/library/media_panel.dart',
  'lib/modules/presentation/shell/library/songs_panel.dart',
  'lib/modules/presentation/shell/library/templates_panel.dart',
  'lib/modules/presentation/children/control/presenter/widgets/set_list/add_menu.dart',
  'lib/modules/presentation/children/control/presenter/widgets/set_list/importers.dart',
  'lib/modules/presentation/children/control/presenter/widgets/set_list/items.dart',
  'lib/modules/presentation/children/control/presenter/widgets/body.dart',
  'lib/modules/presentation/children/control/presenter/widgets/slide_queue.dart',
  'lib/modules/presentation/children/control/presenter/widgets/up_next.dart',
  'lib/modules/presentation/children/control/presenter/widgets/slide_preview.dart',
  'lib/core/widgets/free_slide_dialog.dart',
  'lib/core/widgets/template_picker/template_picker_dialog.dart',
  'lib/core/widgets/template_picker/color_field.dart',
  'lib/modules/presentation/children/control/presenter/widgets/set_list/export.dart',
  'lib/core/utils/color_contrast.dart',
  'lib/modules/auth/children/login/presenter/widgets/body.dart',
  'lib/modules/auth/children/login/presenter/cubit/cubit.dart',
  'lib/modules/org_setup/org_setup_page.dart',
  'lib/modules/presentation/shell/widgets/change_password_dialog.dart',
  'lib/modules/presentation/shell/org_admin_dialog.dart',
  'lib/modules/presentation/shell/widgets/shortcuts_dialog.dart',
  'lib/modules/presentation/shell/shell_page.dart',
  'lib/modules/presentation/shell/collections_library_page.dart',
  'lib/modules/presentation/shell/widgets/collection_dialog.dart',
  'lib/modules/presentation/shell/widgets/projector_picker_dialog.dart',
  'lib/modules/presentation/shell/widgets/notices_dialog.dart',
  'lib/modules/presentation/shell/widgets/quick_verse_dialog.dart',
  'lib/modules/presentation/shell/bible_versions_dialog.dart',
  'lib/modules/songs/children/song_form/presenter/page.dart',
  'lib/modules/songs/children/song_form/presenter/widgets/body.dart',
  'lib/modules/songs/children/song_form/presenter/widgets/verse_editor.dart',
  'lib/modules/songs/children/song_form/presenter/widgets/paste_lyrics_dialog.dart',
  'lib/modules/stage/presenter/stage_page.dart',
  'lib/modules/display/presenter/display_page.dart',
  'lib/core/widgets/app_dialog.dart',
  'lib/core/widgets/ui/app_search_field.dart',
];

/// Spanish that gives itself away: an accent or an opening mark, or one of the
/// words these screens used most.
final _spanish = RegExp(
  r"[áéíóúñÁÉÍÓÚÑ¿¡]|\b(Agregar|Editar|Eliminar|Guardar|Cancelar|Buscar|Subir|Nuevo|Nueva|Fondo|"
  r'Texto|Sombra|Capas|Mostrar|Tipo|Sin|Elige|Importar|Quitar)\b',
);

final _literal = RegExp(
  r"'((?:\\.|[^'\\])*)'"
  '|'
  r'"((?:\\.|[^"\\])*)"',
);

void main() {
  group('screens moved to the translation files', () {
    for (final path in _swept) {
      test('$path has no Spanish typed into it', () {
        final found = <String>[];
        for (final (index, line) in File(path).readAsLinesSync().indexed) {
          final code = line.trimLeft();
          if (code.startsWith('//') || code.startsWith('import ') || code.startsWith('part ')) {
            continue;
          }
          for (final match in _literal.allMatches(line)) {
            final text = match.group(1) ?? match.group(2) ?? '';
            if (_spanish.hasMatch(text)) found.add('${index + 1}: $text');
          }
        }
        expect(found, isEmpty, reason: 'these belong in lib/l10n/app_es.arb');
      });
    }
  });

  group('the names of things, in English', () {
    final en = L10nEn();

    test('an announcement with no title is an Announcement', () {
      const item = CollectionItem(
        id: 'i1',
        collectionId: 'c1',
        type: CollectionItemType.announcement,
        order: 0,
        contentJson: {'message': 'Hola', 'timerTarget': '2026-09-13T10:00:00'},
      );

      expect(item.titleIn(en), 'Announcement');
      expect(item.subtitleIn(en), 'With a countdown');
    });

    test('a title the church typed stays as typed', () {
      const item = CollectionItem(
        id: 'i1',
        collectionId: 'c1',
        type: CollectionItemType.sermon,
        order: 0,
        contentJson: {
          'title': 'La fe',
          'points': ['Uno', 'Dos'],
        },
      );

      expect(item.titleIn(en), 'La fe');
      expect(item.slideLabelsIn(en), ['Title', 'Point 1', 'Point 2']);
      expect(item.subtitleIn(en), '2 points');
    });

    test('a built-in design has an English name, a church\'s own keeps its own', () {
      expect(SlideTemplate.darkClassic.nameIn(en), 'Classic dark');
      expect(SlideTemplate.darkClassic.copyWith(id: 'mine').nameIn(en), 'Oscuro clásico');
    });

    test('verses of a song are counted in the language', () {
      final item = Collection.fromJson(
        collectionRow(
          id: 'c1',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              verses: ['a', 'b', 'c'],
              verseTypes: ['verse', 'chorus', 'chorus'],
            ),
          ],
        ),
      ).items.single;

      expect(item.slideLabelsIn(en), ['Verse', 'Chorus', 'Chorus (2)']);
    });
  });

  group('the presenter, in English', () {
    late ControlCubit control;
    late ShellCubit shell;

    setUp(() {
      control = ControlCubit(
        FakeControlRepository(
          rows: [
            collectionRow(
              id: 'c1',
              name: 'Sunday',
              items: [
                songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Amazing Grace'),
                itemRow(
                  id: 'i2',
                  collectionId: 'c1',
                  type: 'announcement',
                  order: 1,
                  contentJson: {'message': 'Welcome'},
                ),
              ],
            ),
          ],
        ),
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      shell = ShellCubit();
    });

    tearDown(() async {
      await control.close();
      await shell.close();
    });

    Future<void> pump(WidgetTester tester, {bool open = true}) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: control),
            BlocProvider.value(value: shell),
          ],
          child: localizedApp(const ControlPage(), locale: const Locale('en')),
        ),
      );
      await control.load();
      if (open) {
        control.selectCollection((control.state as ControlLoadedState).model.collections.first);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('the empty workspace speaks English', (tester) async {
      await pump(tester, open: false);

      expect(find.text('Nothing on screen'), findsOneWidget);
      expect(find.text('Nada en pantalla'), findsNothing);
    });

    testWidgets('the running order names and counts in English', (tester) async {
      await pump(tester);

      expect(find.text('Announcement'), findsWidgets);
      expect(find.textContaining('1 slide'), findsWidgets);
      expect(find.text('Anuncio'), findsNothing);
    });

    testWidgets('the add menu is in English', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Add item').first);
      await tester.pumpAndSettle();

      expect(find.text('FROM THE LIBRARY'), findsOneWidget);
      expect(find.text('Text slide'), findsOneWidget);
      expect(find.text('Whole folder'), findsOneWidget);
      expect(find.text('Carpeta completa'), findsNothing);
    });
  });
}
