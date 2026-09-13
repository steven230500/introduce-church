import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/history/projection_event.dart';
import 'package:introduce_church/core/history/projection_recorder.dart';
import 'package:introduce_church/modules/presentation/shell/history_page.dart';

import '../helpers/builders.dart';

class _History implements HistoryRepository {
  _History(this.events);
  final List<ProjectionEvent> events;
  Object? failWith;
  DateTime? askedFrom;

  @override
  Future<List<ProjectionEvent>> between(DateTime from, DateTime to) async {
    askedFrom = from;
    final failure = failWith;
    if (failure != null) throw failure;
    return events;
  }

  @override
  Future<void> send(List<ProjectionEvent> events) async {}
}

void main() {
  final now = DateTime(2026, 7, 5, 13);
  final lastSunday = DateTime(2026, 6, 28, 10);

  ProjectionEvent use(String title, DateTime at, {String type = 'song', String? ccli}) =>
      ProjectionEvent(
        id: newProjectionId(),
        collectionId: '3f2b8c1e-9a4d-4e5f-8b6a-1c2d3e4f5a6b',
        collectionName: 'Domingo 28 junio',
        itemType: type,
        title: title,
        ccliNumber: ccli,
        startedAt: at,
        endedAt: at.add(const Duration(minutes: 4)),
      );

  Future<_History> pump(WidgetTester tester, List<ProjectionEvent> events) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final history = _History(events);
    await tester.pumpWidget(localizedApp(HistoryPage(repository: history, now: () => now)));
    await tester.pumpAndSettle();
    return history;
  }

  testWidgets('last Sunday reads as the running order it was', (tester) async {
    await pump(tester, [
      use('Nada es imposible', lastSunday),
      use('Juan 3:16', lastSunday.add(const Duration(minutes: 5)), type: 'bible_verse'),
    ]);

    expect(find.text('Domingo 28 junio'), findsOneWidget);
    expect(find.text('Nada es imposible'), findsOneWidget);
    expect(find.text('Juan 3:16'), findsOneWidget);
  });

  testWidgets('the licence report lists songs, not verses', (tester) async {
    await pump(tester, [
      use('Nada es imposible', lastSunday, ccli: '7654321'),
      use('Juan 3:16', lastSunday.add(const Duration(minutes: 5)), type: 'bible_verse'),
    ]);

    await tester.tap(find.text('Reporte de licencias'));
    await tester.pumpAndSettle();

    expect(find.text('Nada es imposible'), findsOneWidget);
    expect(find.textContaining('CCLI 7654321'), findsOneWidget);
    expect(find.text('Juan 3:16'), findsNothing);
  });

  testWidgets('a song with no licence number says so instead of leaving a gap', (tester) async {
    // The gap is exactly what the person filling in the report needs to see.
    await pump(tester, [use('Sin número', lastSunday)]);

    await tester.tap(find.text('Reporte de licencias'));
    await tester.pumpAndSettle();

    expect(find.text('Sin número de licencia'), findsOneWidget);
  });

  testWidgets('it opens on the last three months, the window a report asks for', (tester) async {
    final history = await pump(tester, const []);

    expect(now.difference(history.askedFrom!).inDays, 92);
  });

  testWidgets('an empty period explains how things get into it', (tester) async {
    await pump(tester, const []);

    expect(find.textContaining('se va anotando solo'), findsOneWidget);
  });

  testWidgets('a failed load says so rather than showing an empty history', (tester) async {
    // "Nothing was projected" and "could not ask" are different answers.
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final history = _History(const [])..failWith = Exception('sin red');
    await tester.pumpWidget(localizedApp(HistoryPage(repository: history, now: () => now)));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo cargar'), findsOneWidget);
    expect(find.textContaining('se va anotando solo'), findsNothing);
  });
}
