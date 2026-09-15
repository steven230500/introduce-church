import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';

import '../helpers/builders.dart';

void main() {
  _versesTogether();
  group('content_json parsing', () {
    test('accepts a Map, which is what Supabase returns for a jsonb column', () {
      final item = CollectionItem.fromJson(
        itemRow(
          id: 'i1',
          collectionId: 'c1',
          type: 'free_slide',
          order: 0,
          contentJson: {'text': 'Hola'},
        ),
      );

      expect(item.contentJson, {'text': 'Hola'});
      expect(item.slides, ['Hola']);
    });

    test('accepts a JSON string, so rows written by an older build still read', () {
      final row = itemRow(id: 'i1', collectionId: 'c1', type: 'free_slide', order: 0)
        ..['content_json'] = jsonEncode({'text': 'Hola'});

      expect(CollectionItem.fromJson(row).slides, ['Hola']);
    });

    test('treats a null content_json as empty rather than throwing', () {
      final item = CollectionItem.fromJson(
        itemRow(id: 'i1', collectionId: 'c1', type: 'free_slide', order: 0),
      );

      expect(item.contentJson, isNull);
      expect(item.slides, ['']);
    });
  });

  group('song items', () {
    test('one slide per verse, in verse order', () {
      final item = CollectionItem.fromJson(
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          title: 'Sublime Gracia',
          author: 'John Newton',
          verses: ['Primera', 'Segunda', 'Tercera'],
        ),
      );

      expect(item.slides, ['Primera', 'Segunda', 'Tercera']);
      expect(item.displayTitle, 'Sublime Gracia');
      expect(item.displaySubtitle, 'John Newton');
    });

    test('numbers repeated verse types so the operator can tell them apart', () {
      final item = CollectionItem.fromJson(
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          verses: ['a', 'b', 'c', 'd'],
          verseTypes: ['verse', 'chorus', 'verse', 'chorus'],
        ),
      );

      expect(item.slideLabels, ['Verso', 'Coro', 'Verso (2)', 'Coro (2)']);
    });
  });

  group('bible items', () {
    Map<String, dynamic> passage() => itemRow(
      id: 'i1',
      collectionId: 'c1',
      type: 'bible_verse',
      order: 0,
      contentJson: {
        'version': 'RVR1960',
        'book': 'Juan',
        'book_id': 'JHN',
        'chapter': 3,
        'verse': 16,
        'verseEnd': 18,
        'texts': ['Porque de tal manera', 'Porque no envió', 'El que en él cree'],
      },
    );

    test('splits a passage into one slide per verse', () {
      final item = CollectionItem.fromJson(passage());

      expect(item.slides, hasLength(3));
      expect(item.slides.first, '"Porque de tal manera"');
    });

    test('numbers each slide reference up from the starting verse', () {
      final item = CollectionItem.fromJson(passage());

      expect(item.slideReferences, [
        'Juan 3:16 • RVR1960',
        'Juan 3:17 • RVR1960',
        'Juan 3:18 • RVR1960',
      ]);
    });

    test('shows a range in the title only when the passage spans verses', () {
      expect(CollectionItem.fromJson(passage()).displayTitle, 'Juan 3:16-18');

      final single = itemRow(
        id: 'i2',
        collectionId: 'c1',
        type: 'bible_verse',
        order: 1,
        contentJson: {
          'version': 'RVR1960',
          'book': 'Juan',
          'chapter': 3,
          'verse': 16,
          'text': 'Porque de tal manera',
        },
      );
      expect(CollectionItem.fromJson(single).displayTitle, 'Juan 3:16');
    });
  });

  group('other item types', () {
    test('a sermon leads with its title, then one slide per point', () {
      final item = CollectionItem.fromJson(
        itemRow(
          id: 'i1',
          collectionId: 'c1',
          type: 'sermon',
          order: 0,
          contentJson: {
            'title': 'El buen pastor',
            'points': ['Conoce', 'Guía', 'Da la vida'],
          },
        ),
      );

      expect(item.slides, ['El buen pastor', 'Conoce', 'Guía', 'Da la vida']);
      expect(item.slideLabels, ['Título', 'Punto 1', 'Punto 2', 'Punto 3']);
      expect(item.displaySubtitle, '4 puntos');
    });

    test('an imported deck keeps one slide per image path', () {
      final item = CollectionItem.fromJson(
        itemRow(
          id: 'i1',
          collectionId: 'c1',
          type: 'image_slide',
          order: 0,
          contentJson: {
            'title': 'anuncios.pptx',
            'paths': ['/tmp/s1.png', '/tmp/s2.png'],
          },
        ),
      );

      expect(item.type, CollectionItemType.imageSlide);
      expect(item.slides, ['/tmp/s1.png', '/tmp/s2.png']);
      expect(item.slideLabels, ['Slide 1', 'Slide 2']);
      // The slide count belongs to the row, which shows one for every type.
      expect(item.displaySubtitle, '');
    });

    test('an announcement says when it carries a countdown', () {
      final plain = CollectionItem.fromJson(
        itemRow(
          id: 'i1',
          collectionId: 'c1',
          type: 'announcement',
          order: 0,
          contentJson: {'message': 'Bienvenidos'},
        ),
      );
      final timed = CollectionItem.fromJson(
        itemRow(
          id: 'i2',
          collectionId: 'c1',
          type: 'announcement',
          order: 1,
          contentJson: {'message': 'Empezamos pronto', 'timerTarget': '2026-09-11T10:00:00Z'},
        ),
      );

      expect(plain.displaySubtitle, '');
      expect(timed.displaySubtitle, 'Con cuenta regresiva');
    });

    test('an unknown item_type falls back to song instead of crashing', () {
      final item = CollectionItem.fromJson(
        itemRow(id: 'i1', collectionId: 'c1', type: 'quantum_slide', order: 0),
      );

      expect(item.type, CollectionItemType.song);
    });
  });

  group('per-item overrides', () {
    test('withTemplateId replaces the design and keeps everything else', () {
      final item = CollectionItem.fromJson(
        songItemRow(id: 'i1', collectionId: 'c1', order: 0, notes: 'Entra suave'),
      );

      final overridden = item.withTemplateId('preset_light');

      expect(overridden.templateId, 'preset_light');
      expect(overridden.notes, 'Entra suave');
      expect(overridden.slides, item.slides);
    });

    test('clearAutoAdvance turns the timer off, which a null value cannot', () {
      final item = CollectionItem.fromJson(
        songItemRow(id: 'i1', collectionId: 'c1', order: 0, autoAdvanceSecs: 15),
      );

      expect(item.copyWith(autoAdvanceSecs: null).autoAdvanceSecs, 15);
      expect(item.copyWith(clearAutoAdvance: true).autoAdvanceSecs, isNull);
    });
  });
}

void _versesTogether() {
  group('a passage on one slide', () {
    CollectionItem passage({required bool together}) => CollectionItem(
      id: 'i1',
      collectionId: 'c1',
      type: CollectionItemType.bibleVerse,
      order: 0,
      contentJson: {
        'book': 'Juan',
        'chapter': 3,
        'verse': 16,
        'verseEnd': 17,
        'version': 'RVR1960',
        'texts': ['Porque de tal manera amó Dios al mundo', 'Porque no envió Dios a su Hijo'],
        'together': together,
      },
    );

    test('a verse at a time is what a passage does by default', () {
      final item = passage(together: false);

      expect(item.slides.length, 2);
      expect(item.slideLabels, ['Juan 3:16 • RVR1960', 'Juan 3:17 • RVR1960']);
    });

    test('together, the whole passage is one slide with one reference', () {
      final item = passage(together: true);

      expect(item.slides, [
        '"Porque de tal manera amó Dios al mundo Porque no envió Dios a su Hijo"',
      ]);
      expect(item.slideLabels, ['Juan 3:16-17 • RVR1960']);
    });

    test('a single verse is the same either way', () {
      const one = CollectionItem(
        id: 'i1',
        collectionId: 'c1',
        type: CollectionItemType.bibleVerse,
        order: 0,
        contentJson: {
          'book': 'Juan',
          'chapter': 3,
          'verse': 16,
          'version': 'RVR1960',
          'texts': ['Porque de tal manera amó Dios al mundo'],
          'together': true,
        },
      );

      expect(one.slides.length, 1);
      expect(one.slideLabels, ['Juan 3:16 • RVR1960']);
    });
  });
}
