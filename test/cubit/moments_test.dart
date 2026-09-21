import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/timing/service_clock.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

ControlModel model(ControlCubit cubit) => (cubit.state as ControlLoadedState).model;

/// Alabanza: two songs. Prédica: the sermon. The marks sit in the same list.
Map<String, dynamic> serviceWithMoments() => collectionRow(
  id: 'c1',
  name: 'Domingo',
  items: [
    itemRow(
      id: 'm1',
      collectionId: 'c1',
      type: 'section',
      order: 0,
      contentJson: {'title': 'Alabanza'},
    ),
    songItemRow(id: 'i1', collectionId: 'c1', order: 1, title: 'Sublime gracia', verses: ['Una']),
    songItemRow(id: 'i2', collectionId: 'c1', order: 2, title: 'Grande es', verses: ['Dos']),
    itemRow(
      id: 'm2',
      collectionId: 'c1',
      type: 'section',
      order: 3,
      contentJson: {'title': 'Prédica'},
    ),
    itemRow(
      id: 'i3',
      collectionId: 'c1',
      type: 'free_slide',
      order: 4,
      contentJson: {'text': 'El llamado'},
    ),
  ],
);

void main() {
  late FakeControlRepository repository;
  late ControlCubit control;

  setUp(() async {
    repository = FakeControlRepository(rows: [serviceWithMoments()]);
    control = ControlCubit(
      repository,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
    await control.load();
    control.selectCollection(model(control).collections.first);
  });

  tearDown(() => control.close());

  group('a service divided into moments', () {
    test('the marks are not things that can go on the screen', () {
      expect(model(control).playableItems.length, 3);
      expect(
        model(control).playableItems.every((i) => i.type != CollectionItemType.section),
        isTrue,
      );
    });

    test('the service says how many things it puts on the screen, not how many rows', () {
      final service = model(control).activeCollection!;
      expect(service.items.length, 5);
      expect(service.playableCount, 3);
    });

    test('a moment is not an item without a planned time', () {
      // The songs and the slide have none either; the two marks must not add to them.
      expect(plannedLength(model(control).activeCollection!).unplanned, 3);
    });

    test('the badges count what the operator counts', () {
      expect(model(control).playableNumber(1), 1, reason: 'the first song, under a mark');
      expect(model(control).playableNumber(2), 2);
      expect(model(control).playableNumber(4), 3, reason: 'a second mark does not take a number');
    });

    test('each item knows the moment it belongs to', () {
      expect(model(control).momentOf(1)?.displayTitle, 'Alabanza');
      expect(model(control).momentOf(4)?.displayTitle, 'Prédica');
      expect(model(control).momentEnd(0), 2, reason: 'Alabanza ends where Prédica starts');
    });

    test('opening a service that starts with a mark lands on its first item', () {
      expect(model(control).currentItemIndex, 1);
      expect(model(control).currentSlides, isNotEmpty, reason: 'there is something to project');
    });

    test('landing on a mark carries on to what it opens', () {
      control.selectItem(0);

      expect(model(control).currentItemIndex, 1, reason: 'a mark has nothing to project');
    });

    test('the arrows step over the marks', () {
      control.selectItem(2); // the second song, last slide of it

      control.nextSlide();

      expect(model(control).currentItemIndex, 4, reason: 'straight past the Prédica mark');

      control.prevSlide();
      expect(model(control).currentItemIndex, 2);
    });

    test('the last item is the last slide, however the service ends', () async {
      await control.addSection('Despedida');
      control.selectItem(4);

      expect(model(control).hasNextSlide, isFalse, reason: 'a mark at the end is not a slide');
    });

    test('the number keys count the items, not the marks', () {
      control.selectPlayable(3);

      expect(model(control).currentItemIndex, 4);
    });

    test('folding one is remembered, and it is not sent anywhere', () {
      control.toggleMoment('m1');

      expect(model(control).collapsedMoments, {'m1'});
      expect(model(control).isFolded(1), isTrue);
      expect(model(control).isFolded(4), isFalse, reason: 'the other moment is open');
      expect(repository.calls.where((c) => c.contains('m1')), isEmpty);

      control.toggleMoment('m1');
      expect(model(control).collapsedMoments, isEmpty);
    });

    test('a folded moment still shows itself, and what is on the screen', () {
      control.selectItem(1); // the first song, inside Alabanza
      control.toggleMoment('m1');

      final model_ = model(control);
      expect(model_.isFolded(0), isTrue, reason: 'the mark reports its own state');
      expect(model_.isFolded(2), isTrue, reason: 'the song nobody is looking at is folded away');
      expect(model_.currentItemIndex, 1, reason: 'folding does not move the cursor');
    });

    test('what comes next skips the mark in between', () {
      control.selectItem(2); // the last song of Alabanza

      expect(model(control).upNext?.item.displayTitle, 'El llamado');
    });

    test('dragging a moment carries its items', () async {
      // Prédica, with its one item, moved above Alabanza.
      await control.reorderItem(3, 0);

      final titles = model(control).activeCollection!.items.map((i) => i.displayTitle).toList();
      expect(titles, ['Prédica', 'El llamado', 'Alabanza', 'Sublime gracia', 'Grande es']);
    });

    test('a moment dropped among another moment\'s items lands at its edge', () async {
      // Prédica let go over the first song of Alabanza: it goes above the
      // whole moment rather than splitting it and stealing its songs.
      await control.reorderItem(3, 1);

      final titles = model(control).activeCollection!.items.map((i) => i.displayTitle).toList();
      expect(titles, ['Prédica', 'El llamado', 'Alabanza', 'Sublime gracia', 'Grande es']);
      expect(model(control).momentLength(2).items, 2, reason: 'Alabanza kept its songs');
    });

    test('dragging an item into another moment just moves it', () async {
      await control.reorderItem(1, 4);

      final titles = model(control).activeCollection!.items.map((i) => i.displayTitle).toList();
      expect(titles, ['Alabanza', 'Grande es', 'Prédica', 'El llamado', 'Sublime gracia']);
      expect(model(control).momentOf(4)?.displayTitle, 'Prédica');
    });

    test('how long a moment takes is the sum of what is under it', () async {
      await control.setItemPlanned('i1', 240);
      await control.setItemPlanned('i2', 180);

      final length = model(control).momentLength(0);
      expect(length.items, 2);
      expect(length.planned, const Duration(minutes: 7));
      expect(length.unplanned, 0);
    });
  });

  group('working with moments', () {
    test('a moment can go in front of an item, not only at the end', () async {
      await control.addSection('Bienvenida', before: 1);
      final titles = model(control).activeCollection!.items.map((i) => i.displayTitle).toList();
      expect(titles, [
        'Alabanza',
        'Bienvenida',
        'Sublime gracia',
        'Grande es',
        'Prédica',
        'El llamado',
      ]);
      expect(model(control).momentOf(2)?.displayTitle, 'Bienvenida');
    });

    test('a moment\'s design draws its items that have none of their own', () async {
      control.setItemTemplate('c1', 'm1', 'preset_motion_mist');
      await pumpEventQueue();
      final m = model(control);
      final items = m.activeCollection!.items;
      expect(m.templateFor(items[1]).id, 'preset_motion_mist', reason: 'a song under Alabanza');
      expect(m.templateFor(items[4]).id, isNot('preset_motion_mist'), reason: 'under Prédica');
    });

    test('while on the screen, the moments already past fold on their own', () async {
      control.toggleLive();
      control.selectItem(4); // "El llamado", under Prédica
      expect(model(control).isMomentFolded('m1'), isTrue);
      expect(model(control).isMomentFolded('m2'), isFalse);

      // Opened again by hand, it stays open.
      control.toggleMoment('m1');
      expect(model(control).isMomentFolded('m1'), isFalse);
      control.selectSlide(0);
      expect(model(control).isMomentFolded('m1'), isFalse);
    });

    test('M goes to the next moment and back', () {
      control.selectItem(1);
      control.jumpMoment(forward: true);
      expect(model(control).currentItemIndex, 4, reason: 'the first item of Prédica');

      control.jumpMoment(forward: false);
      expect(model(control).currentItemIndex, 1, reason: 'already at its start: Alabanza');

      control.selectItem(2);
      control.jumpMoment(forward: false);
      expect(model(control).currentItemIndex, 1, reason: 'back to the start of this moment');
    });
  });
}
