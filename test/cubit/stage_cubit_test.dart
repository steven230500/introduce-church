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

  test('a line for the platform reaches this screen and only this one', () async {
    // The overlay goes to the projector, which is everyone. Telling the
    // preacher they have five minutes needed somewhere else to go.
    await cubit.applyLocalState({...operatorState(), 'stage_message': 'Quedan 5 minutos'});

    expect(cubit.state.stageMessage, 'Quedan 5 minutos');
    expect(cubit.state.overlayVisible, isFalse);
  });

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

  test('names the moment, and looks past its mark for what comes next', () async {
    final state = operatorState(slideIndex: 1);
    final items = (state['collection'] as Map<String, dynamic>)['collection_items'] as List;
    items.insert(
      0,
      itemRow(
        id: 'm1',
        collectionId: 'c1',
        type: 'section',
        order: 0,
        contentJson: {'title': 'Alabanza'},
      ),
    );
    items.insert(
      2,
      itemRow(
        id: 'm2',
        collectionId: 'c1',
        type: 'section',
        order: 2,
        contentJson: {'title': 'Anuncios'},
      ),
    );
    for (final (order, item) in items.indexed) {
      (item as Map<String, dynamic>)['item_order'] = order;
    }
    await cubit.applyLocalState({...state, 'current_item_index': 1});

    expect(cubit.state.current?.moment, 'Alabanza');
    expect(cubit.state.next?.itemTitle, 'Anuncios', reason: 'the slide after the mark');
    expect(cubit.state.next?.content, 'Reunión de jóvenes');
    expect(cubit.state.next?.moment, 'Anuncios');
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
