import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/display/presenter/display_cubit.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// Juan 3:16-17, as the Bible panel hands it over.
BibleVerseRef passage() => const BibleVerseRef(
  versionCode: 'rvr1960',
  versionName: 'Reina Valera 1960',
  bookIndex: 42,
  bookName: 'Juan',
  bookAbbrev: 'Jn',
  chapter: 3,
  verseStart: 16,
  verseEnd: 17,
  texts: ['Porque de tal manera amó Dios al mundo', 'Porque no envió Dios a su Hijo al mundo'],
);

ControlModel model(ControlCubit cubit) => (cubit.state as ControlLoadedState).model;

void main() {
  group('a verse the pastor asks for mid-sermon', () {
    late ControlCubit control;

    setUp(() async {
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
                  verses: ['Primera', 'Segunda'],
                ),
              ],
            ),
          ],
        ),
        FakeTemplateRepository(),
        FakePrefsService(),
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
      control.selectCollection(model(control).collections.first);
    });

    tearDown(() => control.close());

    test('goes on the screen without joining the service', () {
      final before = model(control).activeCollection!.items.length;

      control.projectLoose(passage());

      expect(model(control).activeCollection!.items.length, before);
      expect(model(control).looseActive, isTrue);
      expect(model(control).looseSlides.length, 2, reason: 'one slide per verse');
      expect(model(control).looseReferences.first, 'Juan 3:16 • rvr1960');
      expect(model(control).isLive, isTrue, reason: 'a verse sent to a dark screen looks broken');
    });

    test('together, the passage is one slide', () {
      control.projectLoose(passage(), together: true);

      expect(model(control).looseSlides.length, 1);
      expect(model(control).looseReferences, ['Juan 3:16-17 • rvr1960']);
    });

    test('the arrows move through the passage, not through the service', () {
      control.projectLoose(passage());
      final item = model(control).currentItemIndex;
      final slide = model(control).currentSlideIndex;

      control.nextSlide();
      expect(model(control).looseIndex, 1);

      // The end of the passage holds; it does not fall into the next song.
      control.nextSlide();
      expect(model(control).looseIndex, 1);
      expect(model(control).currentItemIndex, item);
      expect(model(control).currentSlideIndex, slide);

      control.prevSlide();
      expect(model(control).looseIndex, 0);
    });

    test('taking it down leaves the service where it was', () {
      control.selectItem(0);
      control.selectSlide(1);
      control.projectLoose(passage());

      control.clearLoose();

      expect(model(control).looseActive, isFalse);
      expect(model(control).currentItemIndex, 0);
      expect(model(control).currentSlideIndex, 1);
    });

    test('going back to the service takes it down by itself', () {
      control.projectLoose(passage());

      control.selectItem(0);

      expect(model(control).looseActive, isFalse);
    });
  });

  group('the projector window', () {
    test('shows a loose passage over the service, and the service again after', () async {
      final api = OfflineApiClient();
      final cubit = DisplayCubit(api, FakePresentationSocket());
      addTearDown(cubit.close);

      Map<String, dynamic> state({Map<String, dynamic>? loose}) => {
        'collection_id': 'c1',
        'current_item_index': 0,
        'current_slide_index': 0,
        'is_live': true,
        'blank_screen': false,
        'countdown_active': false,
        'overlay_visible': false,
        'loose_verse': loose,
        'collection': collectionRow(
          id: 'c1',
          items: [
            songItemRow(
              id: 'i1',
              collectionId: 'c1',
              order: 0,
              title: 'Sublime gracia',
              verses: ['Primera estrofa'],
            ),
          ],
        ),
      };

      await cubit.applyLocalState(
        state(
          loose: {
            'content': '"Porque de tal manera amó Dios al mundo"',
            'reference': 'Juan 3:16 • RVR1960',
          },
        ),
      );
      expect(cubit.state, isA<DisplaySlideState>());
      expect(
        (cubit.state as DisplaySlideState).content,
        '"Porque de tal manera amó Dios al mundo"',
      );
      expect((cubit.state as DisplaySlideState).reference, 'Juan 3:16 • RVR1960');

      await cubit.applyLocalState(state());
      expect((cubit.state as DisplaySlideState).content, 'Primera estrofa');
    });
  });
}
