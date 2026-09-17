import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

ControlModel model(ControlCubit cubit) => (cubit.state as ControlLoadedState).model;

void main() {
  group('a sermon written beside the pastor', () {
    late FakeControlRepository repository;
    late ControlCubit control;

    setUp(() async {
      repository = FakeControlRepository(
        rows: [
          collectionRow(
            id: 'c1',
            name: 'Domingo',
            items: [
              itemRow(
                id: 'i1',
                collectionId: 'c1',
                type: 'sermon',
                order: 0,
                contentJson: {
                  'title': 'El llamado',
                  'points': ['Mateo 9:9'],
                },
              ),
              itemRow(
                id: 'i2',
                collectionId: 'c1',
                type: 'free_slide',
                order: 1,
                contentJson: {'title': 'Bienvenida', 'text': 'Bienvenidos'},
              ),
            ],
          ),
        ],
      );
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

    test('takes a corrected point without being deleted and typed again', () async {
      final before = model(control).activeCollection!.items.first.id;

      await control.updateSermon(
        'i1',
        title: 'El llamado de Mateo',
        points: ['Mateo 9:9', 'Lucas 5:27'],
      );

      final item = model(control).activeCollection!.items.first;
      expect(item.id, before, reason: 'the same item, not a new one');
      expect(item.slides, ['El llamado de Mateo', 'Mateo 9:9', 'Lucas 5:27']);
    });

    test('a text slide is rewritten the same way', () async {
      await control.updateFreeSlide('i2', text: 'Bienvenidos a la casa de Dios', title: 'Saludo');

      final item = model(control).activeCollection!.items[1];
      expect(item.slides.single, 'Bienvenidos a la casa de Dios');
      expect(item.displayTitle, 'Saludo');
    });

    test('a correction made with no network is kept and shown', () async {
      repository.failWritesWith = const SocketException('Failed host lookup: api.example.com');

      await control.updateSermon('i1', title: 'El llamado', points: ['Mateo 9:9', 'Lucas 5:27']);

      expect(model(control).activeCollection!.items.first.slides.length, 3);
      expect(model(control).offline, isTrue);
      expect(await control.pendingCount(), 1);

      repository.failWritesWith = null;
      await control.refresh();

      expect(await control.pendingCount(), 0);
      expect(repository.calls, contains('content:i1:title,points'));
    });
  });

  group('moving the text on the screen mid-service', () {
    late FakeTemplateRepository templates;
    late ControlCubit control;

    ControlCubit build({String? collectionTemplateId, List<SlideTemplate> designs = const []}) {
      templates = FakeTemplateRepository(templates: designs);
      return ControlCubit(
        FakeControlRepository(
          rows: [
            collectionRow(
              id: 'c1',
              name: 'Domingo',
              templateId: collectionTemplateId,
              items: [
                songItemRow(
                  id: 'i1',
                  collectionId: 'c1',
                  order: 0,
                  title: 'Sublime gracia',
                  verses: ['Primera'],
                ),
              ],
            ),
          ],
        ),
        templates,
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
    }

    Future<void> open(ControlCubit cubit) async {
      await cubit.load();
      cubit.selectCollection(model(cubit).collections.first);
    }

    tearDown(() => control.close());

    test("the church's own design is moved where it is", () async {
      final own = SlideTemplate.darkClassic.copyWith(id: 'custom_1', name: 'Nuestro');
      control = build(collectionTemplateId: 'custom_1', designs: [own]);
      await open(control);

      await control.nudgeLiveText(-0.02, copyName: 'no hace falta copiar');

      expect(templates.calls, contains('saveTemplate:custom_1'));
      expect(model(control).liveTemplate.textOffsetY, closeTo(-0.02, 0.0001));
    });

    test('a built-in design is copied first, and the copy is what the service uses', () async {
      control = build();
      await open(control);

      await control.nudgeLiveText(-0.02, copyName: 'Clásico oscuro (ajustado)');

      final saved = templates.templates.single;
      expect(saved.name, 'Clásico oscuro (ajustado)');
      expect(saved.textOffsetY, closeTo(-0.02, 0.0001));
      expect(
        templates.calls,
        contains('collectionTemplate:c1:${saved.id}'),
        reason: 'the service has to be pointed at the copy, or nothing changes on screen',
      );
    });

    test('it stops at the end of its range instead of drifting off the slide', () async {
      final own = SlideTemplate.darkClassic.copyWith(
        id: 'custom_1',
        name: 'Nuestro',
        textOffsetY: -maxTextOffsetY,
      );
      control = build(collectionTemplateId: 'custom_1', designs: [own]);
      await open(control);

      await control.nudgeLiveText(-0.02, copyName: 'copia');

      expect(templates.calls, isEmpty, reason: 'nothing to save, so nothing was written');
      expect(model(control).liveTemplate.textOffsetY, -maxTextOffsetY);
    });

    test('with no network the screen keeps the design it has', () async {
      control = build();
      await open(control);
      templates.failSaveWith = const SocketException('Failed host lookup: api.example.com');

      await control.nudgeLiveText(-0.02, copyName: 'copia');

      expect(model(control).liveTemplate.textOffsetY, 0);
    });
  });
}
