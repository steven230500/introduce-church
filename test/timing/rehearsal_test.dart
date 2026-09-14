import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/history/projection_recorder.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/services/service_file.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/timing/service_clock.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/rehearsal_summary_dialog.dart';
import 'package:introduce_church/modules/stage/presenter/stage_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;
  var now = DateTime(2026, 9, 13, 10);

  setUp(() async {
    now = DateTime(2026, 9, 13, 10);
    repo = FakeControlRepository(
      rows: [
        collectionRow(
          id: 'c1',
          name: 'Domingo',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              title: 'Sublime gracia',
              verses: ['Primera', 'Segunda'],
            ),
            songItemRow(id: 'i2', collectionId: 'c1', order: 1, title: 'Cuán grande'),
          ],
        ),
      ],
    );
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
      now: () => now,
    );
    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);
  });

  tearDown(() => control.close());

  ControlModel model() => (control.state as ControlLoadedState).model;

  group('the presenter', () {
    test('a rehearsal times each item and nothing of it reaches the licence report', () {
      control.startRehearsal();
      control.toggleLive();
      expect(model().rehearsing, isTrue);
      expect(onAirIn(control.state), isNull, reason: 'rehearsing is not using a song');

      now = now.add(const Duration(minutes: 4, seconds: 10));
      control.selectItem(1);
      now = now.add(const Duration(minutes: 5));

      final result = control.endRehearsal()!;

      expect(model().rehearsing, isFalse);
      expect(result.items.map((e) => e.spent), const [
        Duration(minutes: 4, seconds: 10),
        Duration(minutes: 5),
      ]);
      expect(onAirIn(control.state), isNotNull, reason: 'after the rehearsal it counts again');
    });

    test('the time on screen starts over with each item', () {
      control.toggleLive();
      final first = control.itemStartedAt;
      now = now.add(const Duration(minutes: 3));
      control.nextSlide();
      expect(control.itemStartedAt, first, reason: 'a new slide of the same song');

      control.selectItem(1);
      expect(control.itemStartedAt, now);
    });

    test('the state written without the live link carries the timing too', () async {
      // The HTTP fallback used to send a chosen few fields, so a stage display
      // on another machine never heard about the clock, the waiting screen or
      // the message meant for it unless the socket happened to be connected.
      await control.setItemPlanned('i1', 240);
      control.startRehearsal();
      control.toggleLive();
      await Future<void>.delayed(Duration.zero);

      final written = repo.lastState!;
      expect(written['timing'], {
        'item_started_at': now.toUtc().toIso8601String(),
        'planned_secs': 240,
        'rehearsal': true,
      });
      expect(written.keys, containsAll(['waiting', 'stage_message']));
    });

    test('rehearsed times kept as the plan, even with no network', () async {
      repo.failWritesWith = Exception('Failed host lookup');

      await control.setPlannedTimes({'i1': 250, 'i2': 300});

      expect(model().activeCollection!.items.map((i) => i.plannedSecs), [250, 300]);
      expect(model().pendingWrites, 2, reason: 'waiting to be sent');
    });

    test('a plan can be taken away', () async {
      await control.setItemPlanned('i1', 240);
      await control.setItemPlanned('i1', null);

      expect(model().activeCollection!.items.first.plannedSecs, isNull);
      expect(repo.calls, containsAll(['planned:i1:240', 'planned:i1:null']));
    });
  });

  group('the stage display', () {
    test('reads when the item started, its plan, and whether it is a rehearsal', () async {
      final stage = StageCubit(OfflineApiClient(), FakePresentationSocket());
      addTearDown(stage.close);

      await stage.applyLocalState({
        'collection_id': 'c1',
        'current_item_index': 0,
        'current_slide_index': 0,
        'is_live': true,
        'blank_screen': false,
        'collection': repo.rows.first,
        'templates': const <Map<String, dynamic>>[],
        'timing': {
          'item_started_at': '2026-09-13T15:00:00Z',
          'planned_secs': 2100,
          'rehearsal': true,
        },
      });

      expect(stage.state.itemStartedAt, DateTime.utc(2026, 9, 13, 15).toLocal());
      expect(stage.state.plannedSecs, 2100);
      expect(stage.state.rehearsal, isTrue);
    });

    test('a message from an older app, with no timing, shows no clock', () async {
      final stage = StageCubit(OfflineApiClient(), FakePresentationSocket());
      addTearDown(stage.close);
      await stage.applyLocalState({
        'collection_id': 'c1',
        'is_live': true,
        'collection': repo.rows.first,
        'templates': const <Map<String, dynamic>>[],
      });
      expect(stage.state.itemStartedAt, isNull);
      expect(stage.state.rehearsal, isFalse);
    });
  });

  group('the plan travels', () {
    test('a service file keeps each item\'s planned length', () async {
      await control.setItemPlanned('i2', 300);
      final source = control.exportService(model().activeCollection!);
      final file = decodeService(source);
      expect(file.items.map((i) => i.plannedSecs), [null, 300]);
    });

    test('a queued plan shows before it is sent', () {
      final collection = Collection.fromJson(repo.rows.first);
      final after = applyPendingWrite(
        collection,
        const PendingWrite(kind: PendingKind.itemPlanned, target: 'i2', args: {'planned_secs': 95}),
      );
      expect(after.items.last.plannedSecs, 95);
    });
  });

  group('the summary', () {
    RehearsalResult result() {
      final plan = Collection.fromJson(repo.rows.first);
      return RehearsalResult(
        collection: plan,
        items: [
          RehearsedItem(item: plan.items[0], spent: const Duration(minutes: 4, seconds: 38)),
          RehearsedItem(item: plan.items[1], spent: const Duration(seconds: 3)),
        ],
        total: const Duration(minutes: 6),
      );
    }

    testWidgets('keeps what was rehearsed, rounded, and leaves what was only passed', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, int>? kept;
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => kept = await showDialog<Map<String, int>>(
                context: context,
                builder: (_) => RehearsalSummaryDialog(result: result()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('El ensayo duró 6:00'), findsOneWidget);
      expect(find.text('4:40'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Guardar 1 tiempo'));
      await tester.pumpAndSettle();

      expect(kept, {'i1': 280});
    });
  });
}
