import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/session.dart';
import 'package:introduce_church/core/history/projection_event.dart';
import 'package:introduce_church/core/history/projection_recorder.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// A history server that can be switched off, or made to refuse.
class FakeHistory implements HistoryRepository {
  final received = <ProjectionEvent>[];
  Object? failWith;

  @override
  Future<void> send(List<ProjectionEvent> events) async {
    final failure = failWith;
    if (failure != null) throw failure;
    received.addAll(events);
  }

  @override
  Future<List<ProjectionEvent>> between(DateTime from, DateTime to) async => received;
}

void main() {
  late ControlCubit control;
  late FakeHistory history;
  late ProjectionOutbox outbox;
  late DateTime now;

  setUp(() async {
    control = ControlCubit(
      FakeControlRepository(
        rows: [
          collectionRow(
            id: 'c1',
            name: 'Domingo',
            items: [
              songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Primera'),
              songItemRow(id: 'i2', collectionId: 'c1', order: 1, title: 'Segunda'),
            ],
          ),
        ],
      ),
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    history = FakeHistory();
    outbox = ProjectionOutbox.inMemory();
    now = DateTime(2026, 6, 28, 10);

    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);
  });

  tearDown(() => control.close());

  ProjectionRecorder recorder() => ProjectionRecorder(control, history, outbox, clock: () => now);

  /// Lets the stream deliver and the outbox write settle.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('a song that was live is recorded and sent when the next one goes up', () async {
    final rec = recorder()..start();
    control.toggleLive();
    await settle();

    now = now.add(const Duration(minutes: 4));
    control.nextSlide();
    // A song item has several slides; step until the live item moves on.
    while ((control.state as ControlLoadedState).model.liveItemIndex == 0) {
      control.nextSlide();
    }
    await settle();

    expect(history.received.map((e) => e.title), ['Primera']);
    await rec.stop();
  });

  test('browsing with the output off records nothing', () async {
    // An operator preparing before the service is not showing anyone anything.
    final rec = recorder()..start();

    now = now.add(const Duration(minutes: 10));
    control.selectItem(1);
    await settle();
    await rec.stop();

    expect(history.received, isEmpty);
  });

  test('blacking out the screen closes what was on it', () async {
    final rec = recorder()..start();
    control.toggleLive();
    await settle();

    now = now.add(const Duration(minutes: 2));
    control.toggleBlank();
    await settle();

    expect(history.received.map((e) => e.title), ['Primera']);
    await rec.stop();
  });

  test('with no network the service is kept and sent once it comes back', () async {
    // The room where the service happens is usually the one with no internet.
    history.failWith = const ApiException('sin red');
    final rec = recorder()..start();
    control.toggleLive();
    await settle();

    now = now.add(const Duration(minutes: 3));
    control.toggleLive();
    await settle();

    expect(history.received, isEmpty);
    expect(await outbox.load(), hasLength(1));

    history.failWith = null;
    await rec.flush();

    expect(history.received.map((e) => e.title), ['Primera']);
    expect(await outbox.load(), isEmpty);
    await rec.stop();
  });

  test('an expired session keeps the record rather than dropping it', () async {
    history.failWith = const ApiException('no autenticado', statusCode: 401);
    final rec = recorder()..start();
    control.toggleLive();
    await settle();
    now = now.add(const Duration(minutes: 3));
    control.toggleLive();
    await settle();

    expect(await outbox.load(), hasLength(1), reason: 'signing in again must not lose Sunday');
    await rec.stop();
  });

  test('a batch the server refuses is dropped so the ones behind it can land', () async {
    history.failWith = const ApiException('inválido', statusCode: 400);
    final rec = recorder()..start();
    control.toggleLive();
    await settle();
    now = now.add(const Duration(minutes: 3));
    control.toggleLive();
    await settle();

    expect(await outbox.load(), isEmpty);
    await rec.stop();
  });

  test('closing the presenter with a song still up records that song', () async {
    final rec = recorder()..start();
    control.toggleLive();
    await settle();

    now = now.add(const Duration(minutes: 6));
    await rec.stop();

    expect(history.received.map((e) => e.title), ['Primera']);
  });

  test('what could not be sent survives the app being closed', () async {
    final dir = Directory.systemTemp.createTempSync('outbox');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/outbox.json');

    await ProjectionOutbox(file: file).add(
      ProjectionEvent(
        id: newProjectionId(),
        itemType: 'song',
        title: 'Guardada',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 4)),
      ),
    );

    final reopened = await ProjectionOutbox(file: file).load();
    expect(reopened.single.title, 'Guardada');
  });
}
