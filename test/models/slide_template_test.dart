import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';

void main() {
  group('parsing a stored design', () {
    test('reads a complete config', () {
      final t = SlideTemplate.fromJson(
        id: 'custom-1',
        name: 'Mi diseño',
        json: {
          'bgType': 'solid',
          'bgColor': 0xFF101010,
          'fontSize': 52.0,
          'fontWeight': 700,
          'textColor': 0xFFFFFFFF,
          'paddingH': 40.0,
          'paddingV': 30.0,
          'referenceFontSize': 20.0,
          'referenceColor': 0xFFAAAAAA,
        },
      );

      expect(t.id, 'custom-1');
      expect(t.name, 'Mi diseño');
      expect(t.bgColor, 0xFF101010);
      expect(t.fontSize, 52.0);
    });

    test('survives a config missing most of its fields', () {
      // The presenter reloads every design on each refresh. One row written by
      // an older build used to throw here and blank the whole set list.
      final t = SlideTemplate.fromJson(
        id: 'half-written',
        name: 'A medias',
        json: {'bgColor': 0xFF000000},
      );

      expect(t.fontSize, SlideTemplate.defaultTemplate.fontSize);
      expect(t.textColor, SlideTemplate.defaultTemplate.textColor);
      expect(t.paddingH, SlideTemplate.defaultTemplate.paddingH);
      expect(t.referenceColor, SlideTemplate.defaultTemplate.referenceColor);
    });

    test('survives a completely empty config', () {
      final t = SlideTemplate.fromJson(id: 'empty', name: 'Vacío', json: {});

      expect(t.bgColor, SlideTemplate.defaultTemplate.bgColor);
      expect(t.fontSize, SlideTemplate.defaultTemplate.fontSize);
    });

    test('an unknown enum value falls back instead of throwing', () {
      final t = SlideTemplate.fromJson(
        id: 'odd',
        name: 'Raro',
        json: {'bgType': 'holograma', 'textAlign': 'diagonal'},
      );

      expect(t.bgType, BackgroundType.solid);
    });

    test('a bad layer is dropped and the rest of the design survives', () {
      final t = SlideTemplate.fromJson(
        id: 'layered',
        name: 'Con capas',
        json: {
          'bgColor': 0xFF000000,
          'layers': [
            {'nonsense': true},
            'not even a map',
          ],
        },
      );

      expect(t.layers, isEmpty);
      expect(t.bgColor, 0xFF000000);
    });
  });

  group('presets', () {
    test('every preset is findable by its id', () {
      for (final preset in SlideTemplate.presets) {
        expect(SlideTemplate.findPreset(preset.id)?.name, preset.name);
      }
    });

    test('an unknown id finds nothing', () {
      expect(SlideTemplate.findPreset('preset_inexistente'), isNull);
    });

    test('a design round-trips through its own json', () {
      final original = SlideTemplate.light;
      final restored = SlideTemplate.fromJson(
        id: original.id,
        name: original.name,
        json: original.toJson(),
      );

      expect(restored.bgColor, original.bgColor);
      expect(restored.fontSize, original.fontSize);
      expect(restored.textColor, original.textColor);
      expect(restored.paddingH, original.paddingH);
      expect(restored.bgType, original.bgType);
    });
  });
}
