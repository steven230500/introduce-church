import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/modules/display/presenter/display_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late OfflineApiClient api;
  late DisplayCubit cubit;

  /// A message of the shape the control window sends over the local link.
  Map<String, dynamic> operatorState({
    int itemIndex = 0,
    int slideIndex = 0,
    bool isLive = true,
    bool blank = false,
    List<Map<String, dynamic>> templates = const [],
    String? templateId,
  }) => {
    'collection_id': 'c1',
    'current_item_index': itemIndex,
    'current_slide_index': slideIndex,
    'is_live': isLive,
    'blank_screen': blank,
    'countdown_active': false,
    'overlay_visible': false,
    'collection': collectionRow(
      id: 'c1',
      templateId: templateId,
      items: [
        songItemRow(
          id: 'i1',
          collectionId: 'c1',
          order: 0,
          title: 'Sublime Gracia',
          verses: ['Primera estrofa', 'Segunda estrofa'],
        ),
      ],
    ),
    'templates': templates,
  };

  setUp(() {
    api = OfflineApiClient();
    cubit = DisplayCubit(api, FakePresentationSocket());
  });

  tearDown(() => cubit.close());

  group('with no internet at all', () {
    test('draws the slide the operator sent, without reaching for the network', () async {
      await cubit.applyLocalState(operatorState());

      final state = cubit.state;
      expect(state, isA<DisplaySlideState>());
      expect((state as DisplaySlideState).content, 'Primera estrofa');
      expect(api.calls, 0, reason: 'a projector must never wait on a server');
    });

    test('follows the operator to the next slide', () async {
      await cubit.applyLocalState(operatorState());
      await cubit.applyLocalState(operatorState(slideIndex: 1));

      expect((cubit.state as DisplaySlideState).content, 'Segunda estrofa');
      expect(api.calls, 0);
    });

    test('uses the design that travelled with the message', () async {
      final custom = SlideTemplate.blueNight;
      await cubit.applyLocalState(
        operatorState(
          templateId: 'custom_1',
          templates: [
            {'id': 'custom_1', 'name': 'De la iglesia', 'config': custom.toJson()},
          ],
        ),
      );

      final state = cubit.state as DisplaySlideState;
      expect(state.template.id, 'custom_1');
      expect(state.template.name, 'De la iglesia');
      expect(api.calls, 0);
    });

    test('goes black when told to, and comes back', () async {
      await cubit.applyLocalState(operatorState());
      await cubit.applyLocalState(operatorState(blank: true));
      expect(cubit.state, isA<DisplayBlankState>());

      await cubit.applyLocalState(operatorState());
      expect(cubit.state, isA<DisplaySlideState>());
    });

    test('shows nothing while the operator is off air', () async {
      await cubit.applyLocalState(operatorState(isLive: false));

      expect(cubit.state, isA<DisplayIdleState>());
    });
  });

  test('the same position twice does not redraw', () async {
    // It arrives twice whenever there is internet: once over the local link
    // and again over the socket. For a video a redraw tears down a playing
    // decoder and starts it again.
    final seen = <DisplayState>[];
    final sub = cubit.stream.listen(seen.add);

    await cubit.applyLocalState(operatorState());
    await cubit.applyLocalState(operatorState());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, hasLength(1));
  });
}
