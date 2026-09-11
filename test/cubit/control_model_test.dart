import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';

void main() {
  Collection collection({
    String? templateId,
    List<Map<String, dynamic>> items = const [],
  }) =>
      Collection.fromJson(
        collectionRow(id: 'c1', templateId: templateId, items: items),
      );

  final song = songItemRow(
    id: 'i1',
    collectionId: 'c1',
    order: 0,
    verses: ['a', 'b', 'c'],
  );

  group('with no collection open', () {
    const empty = ControlModel();

    test('reports nothing to show and nowhere to go', () {
      expect(empty.currentItem, isNull);
      expect(empty.currentSlideContent, isNull);
      expect(empty.hasNextSlide, isFalse);
      expect(empty.hasPrevSlide, isFalse);
    });

    test('falls back to the default design', () {
      expect(empty.activeTemplate.id, SlideTemplate.defaultTemplate.id);
    });
  });

  test('items are ordered by item_order, not by the order rows arrive', () {
    final model = ControlModel(
      activeCollection: collection(
        items: [
          songItemRow(id: 'third', collectionId: 'c1', order: 2, title: 'C'),
          songItemRow(id: 'first', collectionId: 'c1', order: 0, title: 'A'),
          songItemRow(id: 'second', collectionId: 'c1', order: 1, title: 'B'),
        ],
      ),
    );

    expect(
      model.activeCollection!.items.map((i) => i.displayTitle),
      ['A', 'B', 'C'],
    );
  });

  group('slide cursor', () {
    test('clamps an out-of-range slide index instead of throwing', () {
      final model = ControlModel(
        activeCollection: collection(items: [song]),
        currentSlideIndex: 99,
      );

      expect(model.currentSlideContent, 'c');
    });

    test('clamps an out-of-range item index instead of throwing', () {
      final model = ControlModel(
        activeCollection: collection(items: [song]),
        currentItemIndex: 99,
      );

      expect(model.currentItem, isNotNull);
    });
  });

  group('design resolution', () {
    final custom = SlideTemplate.light.copyWith(id: 'custom-1', name: 'Mi diseño');

    test('an item design wins over the collection design', () {
      final model = ControlModel(
        activeCollection: collection(
          templateId: SlideTemplate.blueNight.id,
          items: [
            songItemRow(id: 'i1', collectionId: 'c1', order: 0)
              ..['template_id'] = custom.id,
          ],
        ),
        userTemplates: [custom],
      );

      expect(model.activeTemplate.id, custom.id);
    });

    test('the collection design applies when the item has none', () {
      final model = ControlModel(
        activeCollection: collection(
          templateId: SlideTemplate.blueNight.id,
          items: [song],
        ),
      );

      expect(model.activeTemplate.id, SlideTemplate.blueNight.id);
    });

    test('a design id that no longer exists falls back to the default', () {
      final model = ControlModel(
        activeCollection: collection(templateId: 'deleted-design', items: [song]),
      );

      expect(model.activeTemplate.id, SlideTemplate.defaultTemplate.id);
    });

    test('findTemplate looks in presets and in the user designs', () {
      final model = ControlModel(userTemplates: [custom]);

      expect(model.findTemplate(SlideTemplate.light.id), isNotNull);
      expect(model.findTemplate(custom.id)?.name, 'Mi diseño');
      expect(model.findTemplate('nope'), isNull);
    });
  });

  group('slide references', () {
    test('a song slide falls back to the item title', () {
      final model = ControlModel(
        activeCollection: collection(
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              title: 'Sublime Gracia',
            ),
          ],
        ),
      );

      expect(model.currentSlideReference, 'Sublime Gracia');
    });

    test('a bible slide carries its own verse reference', () {
      final model = ControlModel(
        activeCollection: collection(
          items: [
            itemRow(
              id: 'i1',
              collectionId: 'c1',
              type: 'bible_verse',
              order: 0,
              contentJson: {
                'version': 'RVR1960',
                'book': 'Salmos',
                'chapter': 23,
                'verse': 1,
                'texts': ['Jehová es mi pastor', 'En lugares de delicados pastos'],
              },
            ),
          ],
        ),
        currentSlideIndex: 1,
      );

      expect(model.currentSlideReference, 'Salmos 23:2 • RVR1960');
    });
  });
}
