import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/ui/app_buttons.dart';
import 'package:introduce_church/core/widgets/ui/app_search_field.dart';
import 'package:introduce_church/core/widgets/ui/empty_state.dart';
import 'package:introduce_church/core/widgets/ui/page_header.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('PageHeader', () {
    testWidgets('shows the title, the subtitle and the actions', (tester) async {
      await tester.pumpWidget(host(const PageHeader(
        title: 'Colecciones',
        subtitle: '3 servicios planificados',
        actions: [Text('Nueva')],
      )));

      expect(find.text('Colecciones'), findsOneWidget);
      expect(find.text('3 servicios planificados'), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
    });

    testWidgets('omits the subtitle line when there is none', (tester) async {
      await tester.pumpWidget(host(const PageHeader(title: 'Colecciones')));

      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('offers the next step when one is given', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Sin colecciones',
        message: 'Crea la primera.',
        actionLabel: 'Crear',
        onAction: () => tapped = true,
      )));

      expect(find.text('Sin colecciones'), findsOneWidget);
      expect(find.text('Crea la primera.'), findsOneWidget);

      await tester.tap(find.text('Crear'));
      expect(tapped, isTrue);
    });

    testWidgets('renders without an action', (tester) async {
      await tester.pumpWidget(host(const EmptyState(
        icon: Icons.music_off_rounded,
        title: 'Sin canciones',
      )));

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('ErrorStateView', () {
    testWidgets('retry calls back', (tester) async {
      var retried = false;
      await tester.pumpWidget(host(ErrorStateView(
        message: 'Sin conexión',
        onRetry: () => retried = true,
      )));

      await tester.tap(find.text('Reintentar'));
      expect(retried, isTrue);
    });

    testWidgets('hides retry when there is nothing to retry', (tester) async {
      await tester.pumpWidget(host(const ErrorStateView(message: 'Sin conexión')));

      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('AppSearchField', () {
    testWidgets('waits for typing to settle before searching', (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(host(AppSearchField(
        onChanged: queries.add,
        debounce: const Duration(milliseconds: 200),
      )));

      await tester.enterText(find.byType(TextField), 'sub');
      await tester.pump(const Duration(milliseconds: 100));
      expect(queries, isEmpty, reason: 'should not query on every keystroke');

      await tester.pump(const Duration(milliseconds: 150));
      expect(queries, ['sub']);
    });

    testWidgets('only the newest keystroke queries', (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(host(AppSearchField(
        onChanged: queries.add,
        debounce: const Duration(milliseconds: 200),
      )));

      await tester.enterText(find.byType(TextField), 's');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'su');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'sub');
      await tester.pump(const Duration(milliseconds: 300));

      expect(queries, ['sub']);
    });

    testWidgets('the clear button empties the field and the query', (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(host(AppSearchField(
        onChanged: queries.add,
        debounce: const Duration(milliseconds: 50),
      )));

      await tester.enterText(find.byType(TextField), 'sub');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(queries.last, '');
      expect(find.text('sub'), findsNothing);
    });
  });

  group('AppIconButton', () {
    testWidgets('a null callback makes it inert', (tester) async {
      await tester.pumpWidget(host(const AppIconButton(
        icon: Icons.tv_outlined,
        tooltip: 'Proyección',
        onTap: null,
      )));

      await tester.tap(find.byIcon(Icons.tv_outlined));
      // Nothing to assert beyond not throwing: a disabled button must not act.
      expect(find.byType(AppIconButton), findsOneWidget);
    });

    testWidgets('carries a tooltip, since the button is icon-only', (tester) async {
      await tester.pumpWidget(host(AppIconButton(
        icon: Icons.tv_outlined,
        tooltip: 'Abrir pantalla de proyección',
        onTap: () {},
      )));

      expect(
        find.byTooltip('Abrir pantalla de proyección'),
        findsOneWidget,
      );
    });
  });
}
