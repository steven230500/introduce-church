import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/modules/songs/children/song_form/presenter/cubit/cubit.dart';

import '../helpers/fakes.dart';

void main() {
  test('saving an edited song keeps what the form does not show', () async {
    final repo = FakeSongsRepository();
    final form = SongFormCubit(repo);
    addTearDown(form.close);

    // The form has no field for the language or the tags; saving used to
    // make every edited song Spanish and untagged.
    form.init(
      const Song(
        id: 's1',
        title: 'Amazing Grace',
        language: 'en',
        tags: ['himnario', 'clásico'],
        verses: [
          Verse(id: 'v', songId: 's1', type: VerseType.verse, order: 0, content: 'Amazing grace'),
        ],
      ),
    );
    form.updateTitle('Amazing Grace (how sweet)');
    await form.save();

    expect(repo.saved.single['language'], 'en');
    expect(repo.saved.single['tags'], ['himnario', 'clásico']);
  });
}
