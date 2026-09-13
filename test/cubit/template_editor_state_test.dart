import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/widgets/template_picker/template_editor_cubit.dart';

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
}
