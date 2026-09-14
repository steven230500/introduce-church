import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/models/song.dart';

import '../helpers/builders.dart';

void main() {
  // What the projector window reads is the operator's plan written back out.
  // Anything the round trip loses is something the projector gets wrong.
  test('a service written out reads back as the same service', () {
    final row = collectionRow(
      id: 'c1',
      name: 'Domingo',
      serviceDate: '2026-09-13',
      templateId: 'design-1',
      bgAudioPath: '/música/pad.mp3',
      items: [
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          title: 'Cuán grande es Él',
          author: 'Carl Boberg',
          verses: ['Señor mi Dios', 'Mi corazón'],
          verseTypes: ['verse', 'pre-chorus'],
          templateId: 'design-2',
          notes: 'Empieza el piano',
          autoAdvanceSecs: 8,
          plannedSecs: 240,
        ),
        itemRow(
          id: 'i2',
          collectionId: 'c1',
          type: 'image_slide',
          order: 1,
          contentJson: {
            'title': 'Anuncios',
            'paths': ['/a.png', '/b.png'],
          },
        ),
      ],
    );
    final original = Collection.fromJson(row);

    final back = Collection.fromJson(original.toJson());

    expect(back, original);
    expect(back.serviceDate, DateTime(2026, 9, 13));
    expect(back.bgAudioPath, '/música/pad.mp3');
    final song = back.items.first;
    expect(song.song!.author, 'Carl Boberg');
    expect(song.song!.verses.map((v) => v.type.value), ['verse', 'pre-chorus']);
    expect(song.plannedSecs, 240);
    expect(song.slides, ['Señor mi Dios', 'Mi corazón']);
    expect(back.items.last.slides, ['/a.png', '/b.png']);
  });
}
