import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late Directory dir;
  late FakeControlRepository repo;
  late ControlCubit control;

  /// What a machine with no route to the server actually throws.
  const noNetwork = SocketException('Failed host lookup: api.example.com');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('offline_writes');
    repo = FakeControlRepository(
      rows: [
        collectionRow(
          id: 'c1',
          items: [
            // Free slides, not songs: a song's name comes from the song row,
            // so renaming the item would not be visible on either path.
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'free_slide',
              order: 0,
              contentJson: {'text': 'algo', 'title': 'Uno'},
            ),
            itemRow(
              id: 'i2',
              collectionId: 'c1',
              type: 'free_slide',
              order: 1,
              contentJson: {'text': 'otra cosa', 'title': 'Dos'},
            ),
          ],
        ),
      ],
    );
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites(file: File('${dir.path}/pending.json')),
    );
  });

  tearDown(() async {
    await control.close();
    dir.deleteSync(recursive: true);
  });

  ControlModel model() => (control.state as ControlLoadedState).model;

  Future<void> open() async {
    await control.load();
    control.selectCollection(model().collections.first);
  }

  test('a rename with no network is kept, not lost', () async {
    // Before this, the request threw into nothing: the operator saw the old
    // title, assumed the click had missed, and renamed it again.
    await open();
    repo.failWritesWith = noNetwork;

    await control.setItemTitle('i1', 'Bienvenida');

    expect(model().activeCollection!.items.first.displayTitle, 'Bienvenida');
    expect(model().offline, isTrue);
    expect(model().pendingWrites, 1);
  });

  test('it is sent by itself when the network comes back', () async {
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls, contains('title:i1:Bienvenida'));
    expect(model().pendingWrites, 0);
    expect(model().offline, isFalse);
  });

  test('the same rename four times is one request', () async {
    await open();
    repo.failWritesWith = noNetwork;
    for (final title in ['B', 'Bi', 'Bien', 'Bienvenida']) {
      await control.setItemTitle('i1', title);
    }

    expect(model().pendingWrites, 1);

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls.where((c) => c.startsWith('title:')), hasLength(1));
    expect(repo.calls, contains('title:i1:Bienvenida'));
  });

  test('two different changes both arrive, oldest first', () async {
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');
    await control.updateItemNotes('i2', 'leer lento');

    expect(model().pendingWrites, 2);

    repo.failWritesWith = null;
    await control.refresh();

    final sent = repo.calls.where((c) => c.startsWith('title:') || c.startsWith('notes:')).toList();
    expect(sent, ['title:i1:Bienvenida', 'notes:i2:leer lento']);
  });

  test('what was queued survives the app being closed', () async {
    // The network usually comes back after the laptop has been shut and
    // reopened, which is the case a queue in memory would not survive.
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');
    await control.close();

    final reopened = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites(file: File('${dir.path}/pending.json')),
    );
    addTearDown(reopened.close);
    repo.failWritesWith = null;
    await reopened.load();

    expect(repo.calls, contains('title:i1:Bienvenida'));
  });

  test('a request the server refuses is not retried forever', () async {
    // A 400 means the server has an opinion about this change. Replaying it on
    // every refresh would fail exactly the same way, every time, for good.
    await open();
    repo.failWritesWith = noNetwork;
    await control.setItemTitle('i1', 'Bienvenida');

    repo.failWritesWith = StateError('400 bad request');
    await control.refresh();

    expect(model().pendingWrites, 0, reason: 'dropped rather than stuck');
  });

  test('an error that is not the network still reaches the caller', () async {
    // Queuing a genuine failure would hide a real bug behind an offline mark.
    await open();
    repo.failWritesWith = StateError('column does not exist');

    await expectLater(control.setItemTitle('i1', 'Bienvenida'), throwsStateError);
    expect(model().offline, isFalse);
  });

  test('a new order made offline is kept in the order it was made', () async {
    await open();
    repo.failWritesWith = noNetwork;

    await control.reorderItem(0, 1);

    expect(model().activeCollection!.items.map((i) => i.id), ['i2', 'i1']);
    expect(model().pendingWrites, 1);

    repo.failWritesWith = null;
    await control.refresh();

    expect(repo.calls, contains('reorder:i2,i1'));
  });
}
