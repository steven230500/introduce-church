import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/widgets/template_picker/template_editor_cubit.dart';
import 'package:introduce_church/core/widgets/template_picker/template_picker_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late TemplateEditorCubit editor;

  setUp(() {
    editor = TemplateEditorCubit(
      FakeTemplateRepository(),
      FakeOrganizationRepository(),
      SlideTemplate.darkClassic,
    );
  });

  tearDown(() => editor.close());

  Future<void> pumpEditor(WidgetTester tester, {Locale locale = const Locale('es')}) async {
    // A laptop screen: the editor has to fit one without anything running off.
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(value: editor, child: const TemplateEditorDialog(isNew: true)),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens as a dialog like the others, with its controls in sections', (tester) async {
    await pumpEditor(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Nuevo diseño'), findsOneWidget);
    for (final section in ['NOMBRE', 'FONDO', 'TEXTO', 'MÁRGENES', 'REFERENCIA', 'TRANSICIÓN']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('alignment is one press on a segment', (tester) async {
    await pumpEditor(tester);

    await tester.ensureVisible(find.byIcon(Icons.format_align_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.format_align_left));
    await tester.pumpAndSettle();

    expect(editor.state.template.textAlign, TextAlign.left);
  });

  testWidgets('the weight is chosen from a list that names each one', (tester) async {
    await pumpEditor(tester);

    await tester.ensureVisible(find.text('Fino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bold').last);
    await tester.pumpAndSettle();

    expect(editor.state.template.fontWeight, 700);
  });

  testWidgets('the reference position is picked by icon, named in a tooltip', (tester) async {
    await pumpEditor(tester);

    await tester.ensureVisible(find.byIcon(Icons.align_horizontal_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.align_horizontal_left));
    await tester.pumpAndSettle();

    expect(editor.state.template.referencePosition, ReferencePosition.bottomLeft);
    expect(find.byTooltip('Inf. izq.'), findsOneWidget);
  });

  testWidgets('layers mode fits too, and shows what the chosen layer can change', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('Capas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(editor.state.template.layers, isNotEmpty);
    expect(find.text('CAPAS'), findsOneWidget);

    await tester.tap(find.text('Texto').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('PROPIEDADES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in English as well', (tester) async {
    await pumpEditor(tester, locale: const Locale('en'));

    expect(find.text('New design'), findsOneWidget);
    expect(find.text('BACKGROUND'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
