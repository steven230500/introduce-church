import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

ControlModel model(ControlCubit cubit) => (cubit.state as ControlLoadedState).model;

/// This Sunday sings "Santo" and so does next Sunday: one song, two services.
List<Map<String, dynamic>> twoServices() {
  final santo = songItemRow(
    id: 'i1',
    collectionId: 'c1',
    order: 0,
    title: 'Santo',
    verses: ['Santo, santo, santo', 'Señr omnipotente', 'Santo, santo, santo'],
    verseTypes: ['chorus', 'verse', 'chorus'],
  );
  final nextSunday = jsonDecode(jsonEncode(santo)) as Map<String, dynamic>
    ..['id'] = 'j1'
    ..['collection_id'] = 'c2';
  return [
    collectionRow(
      id: 'c1',
      name: 'Este domingo',
      items: [
        santo,
        itemRow(
          id: 'i2',
          collectionId: 'c1',
          type: 'sermon',
          order: 1,
          contentJson: {
            'title': 'El amor',
            'points': ['Uno', 'Dos'],
          },
        ),
      ],
    ),
    collectionRow(id: 'c2', name: 'Próximo domingo', items: [nextSunday]),
  ];
}

void main() {
  late FakeControlRepository repo;
  late ControlCubit control;

  setUp(() async {
    repo = FakeControlRepository(rows: twoServices());
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    await control.load();
    control.selectCollection(model(control).collections.firstWhere((c) => c.id == 'c1'));
  });

  tearDown(() => control.close());

  List<String> slidesOf(String collectionId) =>
      model(control).collections.firstWhere((c) => c.id == collectionId).items.first.slides;

  group('a song slide corrected from the grid', () {
    test('corrects the song, in every service that sings it', () async {
      await control.editSlide('i1', 1, ['Señor omnipotente']);

      expect(repo.calls, contains('song:song-i1:3'));
      expect(model(control).currentItem!.slides[1], 'Señor omnipotente');
      expect(slidesOf('c2')[1], 'Señor omnipotente');
    });

    test('with no network, is kept and shown at once, and sent when it comes back', () async {
      repo.failWritesWith = const SocketException('Network is unreachable');
      await control.editSlide('i1', 1, ['Señor omnipotente']);

      expect(model(control).currentItem!.slides[1], 'Señor omnipotente');
      expect(slidesOf('c2')[1], 'Señor omnipotente');
      expect(model(control).pendingWrites, 1);

      repo.failWritesWith = null;
      await control.refresh();
      expect(repo.calls, contains('song:song-i1:3'));
      expect(model(control).pendingWrites, 0);
    });

    test('left as it was, sends nothing', () async {
      await control.editSlide('i1', 1, ['Señr omnipotente']);
      expect(repo.calls.where((c) => c.startsWith('song:')), isEmpty);
    });
  });

  test('a sermon point is corrected in the item, not anywhere else', () async {
    control.selectItem(1);
    await control.editSlide('i2', 2, ['Dos, corregido']);
    expect(repo.calls, contains('content:i2:title,points'));
    expect(model(control).currentItem!.slides, ['El amor', 'Uno', 'Dos, corregido']);
  });

  test('the screen stays on the same words when a slide above it is split', () async {
    control.toggleLive();
    control.selectSlide(1); // "Señr omnipotente" on the screen

    // The chorus is split in both places it is sung; the verse on the screen
    // is now the third slide, and the projector is told so.
    await control.editSlide('i1', 0, ['Santo, santo,', 'santo']);

    expect(model(control).liveSlideIndex, 2);
    expect(model(control).liveItem!.slides[2], 'Señr omnipotente');
    expect(repo.lastSync, (0, 2));
  });

  test('taking out the slide on the screen lands on the one that followed', () async {
    control.toggleLive();
    control.selectSlide(2);
    await control.editSlide('i1', 2, const []);
    expect(model(control).liveSlideIndex, 1);
    expect(model(control).liveItem!.slides.length, 2);
  });

  test('what cannot be done is not done', () async {
    control.selectItem(1);
    // The title is what the sermon is called.
    await control.editSlide('i2', 0, const []);
    expect(model(control).currentItem!.slides.first, 'El amor');
    expect(repo.calls.where((c) => c.startsWith('content:')), isEmpty);
  });
}
