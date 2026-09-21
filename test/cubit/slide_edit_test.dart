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

  group('a song edit made with no network', () {
    /// Someone at another computer changes the song's first verse while this
    /// one is offline.
    void editedElsewhere() {
      final row = repo.rows.first['collection_items'][0] as Map<String, dynamic>;
      ((row['songs'] as Map)['verses'] as List)[0]['content'] = 'Santo, santo, santo, Señor';
    }

    test('is made again on the song as the server has it, keeping the other change', () async {
      repo.failWritesWith = const SocketException('Network is unreachable');
      await control.editSlide('i1', 1, ['Señor omnipotente']);
      editedElsewhere();

      repo.failWritesWith = null;
      await control.refresh();

      final song = model(control).currentItem!.song!;
      expect(song.slides, [
        'Santo, santo, santo, Señor',
        'Señor omnipotente',
        'Santo, santo, santo',
      ]);
    });

    test('is not made twice when the first attempt did reach the server', () async {
      repo.failWritesWith = const SocketException('Network is unreachable');
      await control.editSlide('i1', 1, ['Señor omnipotente']);
      // The words it changes are already gone: nothing left to do.
      ((repo.rows.first['collection_items'][0]['songs'] as Map)['verses'] as List)[1]['content'] =
          'Señor omnipotente';

      repo.failWritesWith = null;
      repo.calls.clear();
      await control.refresh();

      expect(repo.calls.where((c) => c.startsWith('song:')), isEmpty);
      expect(model(control).pendingWrites, 0);
    });

    test('two edits in a row are both kept, in order', () async {
      repo.failWritesWith = const SocketException('Network is unreachable');
      await control.editSlide('i1', 1, ['Señor omnipotente']);
      await control.editSlide('i1', 0, ['¡Santo, santo, santo!']);
      expect(model(control).pendingWrites, 2);

      repo.failWritesWith = null;
      await control.refresh();

      expect(model(control).currentItem!.song!.slides, [
        '¡Santo, santo, santo!',
        'Señor omnipotente',
        '¡Santo, santo, santo!',
      ]);
    });
  });

  group('undo', () {
    test('puts a song back as it was, split included', () async {
      await control.editSlide('i1', 1, ['Señr', 'omnipotente']);
      expect(control.canUndoSlideEdit, isTrue);

      await control.undoSlideEdit();

      expect(model(control).currentItem!.slides, [
        'Santo, santo, santo',
        'Señr omnipotente',
        'Santo, santo, santo',
      ]);
      expect(slidesOf('c2')[1], 'Señr omnipotente');
      expect(control.canUndoSlideEdit, isFalse);
    });

    test('puts a sermon point back', () async {
      control.selectItem(1);
      await control.editSlide('i2', 1, const []);
      await control.undoSlideEdit();
      expect(model(control).currentItem!.slides, ['El amor', 'Uno', 'Dos']);
    });

    test('puts the screen back on the slide it was on', () async {
      control.toggleLive();
      control.selectSlide(1);
      await control.editSlide('i1', 0, ['Santo,', 'santo, santo']);
      expect(model(control).liveSlideIndex, 2);

      await control.undoSlideEdit();
      expect(model(control).liveSlideIndex, 1);
      expect(repo.lastSync, (0, 1));
    });
  });

  group('adding, moving, renaming', () {
    test('a slide added after another goes to the song, and the screen stays put', () async {
      control.toggleLive();
      control.selectSlide(2);
      await control.insertSlide('i1', after: 0, text: 'Verso nuevo');

      expect(model(control).currentItem!.slides, [
        'Santo, santo, santo',
        'Verso nuevo',
        'Señr omnipotente',
        'Santo, santo, santo',
      ]);
      expect(model(control).liveSlideIndex, 3, reason: 'still on the last chorus');
      expect(slidesOf('c2')[1], 'Verso nuevo');
    });

    test('a slide moved, and moved back with undo', () async {
      await control.moveSlide('i1', 1, 1);
      expect(model(control).currentItem!.slides[2], 'Señr omnipotente');
      await control.undoSlideEdit();
      expect(model(control).currentItem!.slides[1], 'Señr omnipotente');
    });

    test('with no network, an added slide is sent once when it comes back', () async {
      repo.failWritesWith = const SocketException('Network is unreachable');
      await control.insertSlide('i1', after: 1, text: 'Coda');
      repo.failWritesWith = null;
      await control.refresh();
      await control.refresh();
      expect(model(control).currentItem!.slides.where((s) => s == 'Coda'), hasLength(1));
    });

    test('a sermon point is added and moved', () async {
      control.selectItem(1);
      await control.insertSlide('i2', after: 2, text: 'Tres');
      await control.moveSlide('i2', 3, -1);
      expect(model(control).currentItem!.slides, ['El amor', 'Uno', 'Tres', 'Dos']);
    });

    test('a song gets a new title and author, in every service', () async {
      await control.updateSongDetails('i1', title: 'Santo, Santo, Santo', author: 'R. Heber');
      final song = model(control).currentItem!.song!;
      expect(song.title, 'Santo, Santo, Santo');
      expect(song.author, 'R. Heber');
      expect(
        model(control).collections.firstWhere((c) => c.id == 'c2').items.first.song!.title,
        'Santo, Santo, Santo',
      );
    });
  });

  test('a page comes out of a presentation, in this service only', () async {
    repo.rows.first['collection_items'].add(
      itemRow(
        id: 'i3',
        collectionId: 'c1',
        type: 'image_slide',
        order: 2,
        contentJson: {
          'title': 'Anuncios',
          'paths': ['/a.png', '/b.png', '/c.png'],
        },
      ),
    );
    await control.refresh();
    control.selectItem(2);

    await control.editSlide('i3', 1, const []);
    expect(model(control).currentItem!.slides, ['/a.png', '/c.png']);
    await control.undoSlideEdit();
    expect(model(control).currentItem!.slides, ['/a.png', '/b.png', '/c.png']);
  });
}
