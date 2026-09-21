import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

ControlModel model(ControlCubit cubit) => (cubit.state as ControlLoadedState).model;

void main() {
  group('the slides in the grid', () {
    late FakePrefsService prefs;
    late ControlCubit control;

    setUp(() async {
      prefs = FakePrefsService();
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
                  verses: ['Una', 'Dos', 'Tres', 'Cuatro'],
                ),
              ],
            ),
          ],
        ),
        FakeTemplateRepository(),
        prefs,
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
      control.selectCollection(model(control).collections.first);
    });

    tearDown(() => control.close());

    test('start at whatever fits the window', () {
      expect(model(control).gridZoom, 0);
    });

    test('grow a step at a time, and it is remembered', () async {
      control.zoomGrid(1);

      expect(model(control).gridZoom, 1);
      expect(await prefs.loadGridZoom(), 1);
    });

    test('stop growing at the end of the range', () {
      for (var i = 0; i < 6; i++) {
        control.zoomGrid(1);
      }

      expect(model(control).gridZoom, ControlCubit.maxGridZoom);
    });

    test('going back to zero stops overriding what fits', () async {
      control.zoomGrid(1);
      control.zoomGrid(-1);

      expect(model(control).gridZoom, 0, reason: 'the window decides again');
      expect(await prefs.loadGridZoom(), isNull);
    });

    test('a refresh does not undo the choice', () async {
      control.zoomGrid(1);

      await control.refresh();

      expect(model(control).gridZoom, 1);
    });
  });
}
