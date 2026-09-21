import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/collection_item_type.dart';
import 'package:introduce_church/core/models/song.dart';

Verse verse(String id, VerseType type, String content, {String? chords}) =>
    Verse(id: id, songId: 's', type: type, order: 0, content: content, chords: chords);

/// Verse, chorus, verse, chorus: the chorus written out each time it is sung,
/// as an imported song keeps it.
Song hymn() => Song(
  id: 's',
  title: 'Himno',
  language: 'es',
  tags: const ['himnario'],
  verses: [
    verse('v1', VerseType.verse, 'Primera estrofa', chords: 'G D'),
    verse('c1', VerseType.chorus, 'Santo es el Señr'),
    verse('v2', VerseType.verse, 'Segunda estrofa'),
    verse('c2', VerseType.chorus, 'Santo es el Señr'),
  ],
);

CollectionItem sermon() => const CollectionItem(
  id: 'i',
  collectionId: 'c',
  type: CollectionItemType.sermon,
  order: 0,
  contentJson: {
    'title': 'El amor que envía',
    'points': ['Dios amó primero', 'Dios dio lo mejor'],
  },
);

void main() {
  group('a song slide', () {
    test('corrected, keeps its place, its id and its chords', () {
      final song = hymn().withSlide(0, ['Primera estrofa corregida']);
      expect(song.slides.first, 'Primera estrofa corregida');
      expect(song.verses.first.id, 'v1');
      expect(song.verses.first.chords, 'G D');
      expect(song.tags, ['himnario'], reason: 'nothing else about the song changes');
    });

    test('corrected in the chorus, is corrected every time the chorus is sung', () {
      final song = hymn().withSlide(1, ['Santo es el Señor']);
      expect(song.slides, [
        'Primera estrofa',
        'Santo es el Señor',
        'Segunda estrofa',
        'Santo es el Señor',
      ]);
      expect(hymn().repeatsOf(1), 1);
      expect(hymn().repeatsOf(0), 0);
    });

    test('split in two, becomes two slides of the same kind', () {
      final song = hymn().withSlide(0, ['Primera', 'estrofa']);
      expect(song.slides.take(3), ['Primera', 'estrofa', 'Santo es el Señr']);
      expect(song.verses[1].type, VerseType.verse);
      expect(song.verses[1].chords, isNull, reason: 'the chords were written over the first half');
      expect([for (final v in song.verses) v.order], [0, 1, 2, 3, 4]);
    });

    test('taken out, goes only that time: dropping a repeat is not changing the words', () {
      final song = hymn().withSlide(3, const []);
      expect(song.slides, ['Primera estrofa', 'Santo es el Señr', 'Segunda estrofa']);
    });

    test('the same words under another kind are not a repeat', () {
      final song = Song(
        id: 's',
        title: 'x',
        verses: [verse('a', VerseType.chorus, 'Aleluya'), verse('b', VerseType.tag, 'Aleluya')],
      ).withSlide(0, ['¡Aleluya!']);
      expect(song.slides, ['¡Aleluya!', 'Aleluya']);
    });

    test('the operator\'s place stays on the same words after a split above it', () {
      // The second verse was slide 2; the chorus above it, split in two in
      // both places it is sung, pushes it to slide 3.
      expect(hymn().positionAfter(1, ['Santo', 'es el Señor'], 2), 3);
      // Below the edit, nothing moves.
      expect(hymn().positionAfter(3, ['a', 'b'], 1), 1);
      // A slide taken out lands on the one that followed it.
      expect(hymn().positionAfter(1, const [], 1), 1);
    });
  });

  group('a sermon slide', () {
    test('a point corrected, split or taken out', () {
      expect(sermon().contentWithSlide(1, ['Dios nos amó primero']), {
        'title': 'El amor que envía',
        'points': ['Dios nos amó primero', 'Dios dio lo mejor'],
      });
      expect(sermon().contentWithSlide(2, ['Dios dio', 'lo mejor'])!['points'], [
        'Dios amó primero',
        'Dios dio',
        'lo mejor',
      ]);
      expect(sermon().contentWithSlide(1, const [])!['points'], ['Dios dio lo mejor']);
    });

    test('the title split keeps its first half and the rest become the first points', () {
      expect(sermon().contentWithSlide(0, ['El amor', 'que envía']), {
        'title': 'El amor',
        'points': ['que envía', 'Dios amó primero', 'Dios dio lo mejor'],
      });
    });

    test('the title cannot be taken out, a point can', () {
      expect(sermon().canRemoveSlide(0), isFalse);
      expect(sermon().canRemoveSlide(1), isTrue);
      expect(sermon().contentWithSlide(0, const []), isNull);
    });
  });

  test('a slide libre is corrected but not split, and keeps its title', () {
    const item = CollectionItem(
      id: 'i',
      collectionId: 'c',
      type: CollectionItemType.freeSlide,
      order: 0,
      contentJson: {'text': 'Bienvenidos', 'title': 'Saludo'},
    );
    expect(item.canSplitSlide(0), isFalse);
    expect(item.contentWithSlide(0, ['¡Bienvenidos!']), {
      'text': '¡Bienvenidos!',
      'title': 'Saludo',
    });
    expect(item.contentWithSlide(0, ['a', 'b']), isNull);
  });

  test('a passage and a picture are not edited', () {
    const passage = CollectionItem(
      id: 'i',
      collectionId: 'c',
      type: CollectionItemType.bibleVerse,
      order: 0,
    );
    const pictures = CollectionItem(
      id: 'j',
      collectionId: 'c',
      type: CollectionItemType.imageSlide,
      order: 0,
    );
    expect(passage.slidesEditable, isFalse);
    expect(pictures.slidesEditable, isFalse);
  });

  test('the last slide of a song cannot be taken out', () {
    final item = CollectionItem(
      id: 'i',
      collectionId: 'c',
      type: CollectionItemType.song,
      order: 0,
      song: Song(id: 's', title: 'x', verses: [verse('a', VerseType.verse, 'solo')]),
    );
    expect(item.canRemoveSlide(0), isFalse);
    expect(item.canSplitSlide(0), isTrue);
  });

  test('a verse missing from the version has no slide, and the others keep their numbers', () {
    const item = CollectionItem(
      id: 'i',
      collectionId: 'c',
      type: CollectionItemType.bibleVerse,
      order: 0,
      contentJson: {
        'book': 'Mateo',
        'chapter': 17,
        'verse': 20,
        'texts': ['Veinte', '', 'Veintidós'],
        'version': 'X',
      },
    );
    expect(item.slides, ['"Veinte"', '"Veintidós"']);
    expect(item.slideReferences, ['Mateo 17:20 • X', 'Mateo 17:22 • X']);
  });
}
