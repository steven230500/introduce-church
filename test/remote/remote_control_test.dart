import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/remote/remote_control.dart';
import 'package:introduce_church/core/remote/remote_protocol.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakePrefsService prefs;
  late ControlCubit control;

  setUp(() async {
    prefs = FakePrefsService();
    control = ControlCubit(
      FakeControlRepository(
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
                verses: ['Sublime gracia del Señor', 'que a un infeliz salvó'],
              ),
              songItemRow(
                id: 'i2',
                collectionId: 'c1',
                order: 1,
                title: 'Cuán grande',
                verses: ['Señor mi Dios'],
              ),
            ],
          ),
        ],
      ),
      FakeTemplateRepository(),
      prefs,
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    await control.load();
    control.selectCollection((control.state as ControlLoadedState).model.collections.first);
  });

  tearDown(() => control.close());

  ControlModel model() => (control.state as ControlLoadedState).model;

  group('what a phone sees', () {
    test('the words on the screen and what comes next, across the end of an item', () {
      control.toggleLive();
      control.nextSlide();

      final snapshot = remoteSnapshot(model());

      expect(snapshot['text'], 'que a un infeliz salvó');
      expect(snapshot['next'], 'Señor mi Dios');
      expect(snapshot['collection'], 'Domingo');
      expect(snapshot['items'], [
        {'title': 'Sublime gracia', 'slides': 2, 'number': 1},
        {'title': 'Cuán grande', 'slides': 1, 'number': 2},
      ]);
      expect(snapshot['is_live'], isTrue);
    });

    test('a moment is a heading, and what comes next is past it', () async {
      final rows = [
        collectionRow(
          id: 'c2',
          name: 'Con momentos',
          items: [
            itemRow(
              id: 'm1',
              collectionId: 'c2',
              type: 'section',
              order: 0,
              contentJson: {'title': 'Alabanza'},
            ),
            songItemRow(id: 'i3', collectionId: 'c2', order: 1, title: 'Una', verses: ['Única']),
            itemRow(
              id: 'm2',
              collectionId: 'c2',
              type: 'section',
              order: 2,
              contentJson: {'title': 'Prédica'},
            ),
            songItemRow(id: 'i4', collectionId: 'c2', order: 3, title: 'Dos', verses: ['Segunda']),
          ],
        ),
      ];
      final withMoments = ControlCubit(
        FakeControlRepository(rows: rows),
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      addTearDown(withMoments.close);
      await withMoments.load();
      ControlModel state() => (withMoments.state as ControlLoadedState).model;
      withMoments.selectCollection(state().collections.first);
      withMoments.toggleLive();

      final snapshot = remoteSnapshot(state());
      expect(snapshot['items'], [
        {'title': 'Alabanza', 'moment': true},
        {'title': 'Una', 'slides': 1, 'number': 1},
        {'title': 'Prédica', 'moment': true},
        {'title': 'Dos', 'slides': 1, 'number': 2},
      ]);
      expect(snapshot['text'], 'Única');
      expect(snapshot['next'], 'Segunda', reason: 'the mark between them is not shown next');
    });

    test('messages it does not understand are ignored, not guessed at', () {
      expect(RemoteCommand.parse({'type': 'delete_everything'}), isNull);
      expect(RemoteCommand.parse({'type': 'goto', 'item': 'uno'}), isNull);
      expect(RemoteCommand.parse('next'), isNull);
    });

    test('a jump goes where the keyboard would', () {
      applyRemoteCommand(control, RemoteCommand.parse({'type': 'goto', 'item': 1, 'slide': 0})!);
      expect(model().currentItemIndex, 1);

      applyRemoteCommand(control, const RemotePrev());
      expect((model().currentItemIndex, model().currentSlideIndex), (0, 1));

      applyRemoteCommand(control, const RemoteToggleBlank());
      expect(model().blankScreen, isTrue);
    });
  });

  group('the remote', () {
    RemoteControl remote() =>
        RemoteControl(control, prefs, port: 0, addresses: () async => ['192.168.1.20']);

    test('is off until turned on, and remembered once it is', () async {
      final first = remote();
      await first.restore();
      expect(first.status.value.enabled, isFalse);
      expect(first.status.value.pin, hasLength(6));

      await first.enable();
      expect(first.status.value.pairingUrl, startsWith('http://192.168.1.20:'));
      expect(first.status.value.pairingUrl, endsWith('/#pin=${first.status.value.pin}'));
      await first.dispose();

      final next = remote();
      addTearDown(next.dispose);
      await next.restore();
      expect(next.status.value.enabled, isTrue, reason: 'on again after a restart');
      expect(next.status.value.pin, first.status.value.pin, reason: 'the same PIN');
    });

    test('a phone on the network moves the slide', () async {
      final r = remote();
      addTearDown(r.dispose);
      await r.restore();
      await r.enable();
      final port = r.status.value.port!;

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/pair'));
      request.write(jsonEncode({'pin': r.status.value.pin}));
      final token =
          (jsonDecode(await utf8.decoder.bind(await request.close()).join()) as Map)['token'];
      client.close(force: true);

      final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws?token=$token');
      addTearDown(socket.close);
      final states = socket
          .map((m) => jsonDecode(m as String) as Map)
          .where((m) => m['type'] == 'state');
      final updates = StreamIterator(states);
      expect(await updates.moveNext(), isTrue);

      socket.add(jsonEncode({'type': 'next'}));
      expect(await updates.moveNext(), isTrue);

      expect(model().currentSlideIndex, 1);
      expect((updates.current['state'] as Map)['slide'], 1);
    });

    test('a new PIN is saved, and the phones paired before are forgotten', () async {
      prefs.remote = {
        'enabled': false,
        'pin': '123456',
        'tokens': ['old-phone'],
      };
      final r = remote();
      addTearDown(r.dispose);
      await r.restore();

      await r.renewPin();

      expect(r.status.value.pin, isNot('123456'));
      expect(prefs.remote!['pin'], r.status.value.pin);
      expect(prefs.remote!['tokens'], isEmpty);
    });
  });
}
