import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/stage/presenter/stage_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late OfflineApiClient api;
  late StageCubit cubit;

  Map<String, dynamic> operatorState({int itemIndex = 0, int slideIndex = 0}) => {
    'collection_id': 'c1',
    'current_item_index': itemIndex,
    'current_slide_index': slideIndex,
    'is_live': true,
    'blank_screen': false,
    'countdown_active': false,
    'overlay_visible': false,
    'collection': collectionRow(
      id: 'c1',
      items: [
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          title: 'Sublime Gracia',
          verses: ['Primera estrofa', 'Segunda estrofa'],
        ),
        itemRow(
          id: 'i2',
          collectionId: 'c1',
          type: 'free_slide',
          order: 1,
          contentJson: {'title': 'Anuncios', 'text': 'Reunión de jóvenes'},
          notes: 'Bajar el volumen',
        ),
      ],
    ),
    'templates': const <Map<String, dynamic>>[],
  };

  setUp(() {
    api = OfflineApiClient();
    cubit = StageCubit(api, FakePresentationSocket());
  });

  tearDown(() => cubit.close());

  test('shows the slide and the one after it, with no network', () async {
    await cubit.applyLocalState(operatorState());

    expect(cubit.state.current?.content, 'Primera estrofa');
    expect(cubit.state.next?.content, 'Segunda estrofa');
    expect(api.calls, 0, reason: 'the stage monitor must not wait on a server');
  });

  test('looks across the item boundary for what comes next', () async {
    await cubit.applyLocalState(operatorState(slideIndex: 1));

    expect(cubit.state.current?.content, 'Segunda estrofa');
    expect(cubit.state.next?.itemTitle, 'Anuncios');
  });

  test('carries the note for the item the team is on', () async {
    await cubit.applyLocalState(operatorState(itemIndex: 1));

    expect(cubit.state.current?.notes, 'Bajar el volumen');
  });

  test('the same position twice does not redraw', () async {
    final seen = <StageState>[];
    final sub = cubit.stream.listen(seen.add);

    await cubit.applyLocalState(operatorState());
    await cubit.applyLocalState(operatorState());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, hasLength(1));
  });
}
