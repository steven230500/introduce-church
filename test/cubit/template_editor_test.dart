import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/widgets/template_picker/template_editor_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  TemplateEditorState stateFor(
    SlideTemplate template, {
    int? photoAverage,
  }) => TemplateEditorState(template: template, photoAverage: photoAverage);

  final base = SlideTemplate.defaultTemplate;

  group('what the text sits on', () {
    test('on a plain background it is that colour', () {
      final state = stateFor(base.copyWith(bgType: BackgroundType.solid, bgColor: 0xFF102030));

      expect(state.backdrop, 0xFF102030);
    });

    test('on a photo it is the photo seen through the darkening layer', () {
      // The operator slides Oscuridad up precisely so text can be read, so a
      // verdict taken against the bare photo is wrong by exactly that amount.
      final state = stateFor(
        base.copyWith(bgType: BackgroundType.image, bgOverlayOpacity: 0.5),
        photoAverage: 0xFFFFFFFF,
      );

      expect(state.backdrop, 0xFF808080);
    });

    test('on a photo that has not been read yet there is no answer', () {
      final state = stateFor(base.copyWith(bgType: BackgroundType.image));

      expect(state.backdrop, isNull, reason: 'better nothing than a wrong verdict');
    });
  });

  group('taking a change back', () {
    late TemplateEditorCubit cubit;

    setUp(() {
      cubit = TemplateEditorCubit(
        FakeTemplateRepository(),
        FakeOrganizationRepository(),
        SlideTemplate.defaultTemplate.copyWith(fontSize: 40),
      );
    });

    tearDown(() => cubit.close());

    SlideTemplate get() => cubit.state.template;

    test('an editor that has just opened has nothing to undo', () {
      expect(cubit.state.canUndo, isFalse);
      expect(cubit.state.dirty, isFalse);
    });

    test('a change can be taken back', () {
      cubit.update(get().copyWith(fontSize: 90));
      expect(cubit.state.canUndo, isTrue);

      cubit.undo();

      expect(get().fontSize, 40);
      expect(cubit.state.canRedo, isTrue);
    });

    test('a slider dragged across the panel is one step, not forty', () {
      // Undo pressed forty times to get back to where a single drag started is
      // undo that nobody uses.
      for (var size = 41; size <= 80; size++) {
        cubit.update(get().copyWith(fontSize: size.toDouble()));
      }

      cubit.undo();

      expect(get().fontSize, 40);
      expect(cubit.state.canUndo, isFalse);
    });

    test('two different things changed are two steps', () async {
      cubit.update(get().copyWith(fontSize: 90));
      // Far enough apart that they are not the same gesture.
      await Future<void>.delayed(const Duration(milliseconds: 750));
      cubit.update(get().copyWith(textColor: 0xFFFF0000));

      cubit.undo();

      expect(get().textColor, isNot(0xFFFF0000));
      expect(get().fontSize, 90, reason: 'only the last step came off');
    });

    test('what was undone can be put back', () {
      cubit.update(get().copyWith(fontSize: 90));
      cubit.undo();

      cubit.redo();

      expect(get().fontSize, 90);
      expect(cubit.state.canRedo, isFalse);
    });

    test('changing something after undoing drops what was ahead', () {
      cubit.update(get().copyWith(fontSize: 90));
      cubit.undo();

      cubit.update(get().copyWith(fontSize: 60));

      expect(cubit.state.canRedo, isFalse);
      expect(get().fontSize, 60);
    });

    test('undoing all the way back is back, and closing costs nothing', () {
      cubit.update(get().copyWith(fontSize: 90));
      expect(cubit.state.dirty, isTrue);

      cubit.undo();

      expect(cubit.state.dirty, isFalse, reason: 'nothing left to lose');
    });

    test('a layer that was deleted comes back', () {
      cubit.enableLayers();
      final id = cubit.state.template.layers.first.id;

      cubit.removeLayer(id);
      expect(cubit.state.template.layers.any((l) => l.id == id), isFalse);

      cubit.undo();

      expect(cubit.state.template.layers.any((l) => l.id == id), isTrue);
    });

    test('undoing past a layer does not leave it selected', () {
      cubit.enableLayers();

      cubit.undo();

      expect(cubit.state.template.layers, isEmpty);
      expect(cubit.state.selectedLayerId, isNull);
    });

    test('choosing which layer to look at is not a change to the design', () {
      cubit.enableLayers();
      final second = cubit.state.template.layers.last.id;

      cubit.selectLayer(second);

      expect(cubit.state.canUndo, isTrue, reason: 'from turning layers on, not from selecting');
      cubit.undo();
      expect(cubit.state.canUndo, isFalse);
    });
  });
}
