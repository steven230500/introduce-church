import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/utils/image_palette.dart';

/// A run of pixels of one colour, in the RGBA order a decoded image gives back.
Uint8List pixels(List<(int r, int g, int b, int howMany)> runs) {
  final out = <int>[];
  for (final (r, g, b, howMany) in runs) {
    for (var i = 0; i < howMany; i++) {
      out.addAll([r, g, b, 255]);
    }
  }
  return Uint8List.fromList(out);
}

void main() {
  group('the colours a photo is made of', () {
    test('a picture of one colour offers that colour', () {
      final result = photoColorsFrom(pixels([(200, 80, 20, 100)]));

      expect(result.palette, hasLength(1));
      expect(result.palette.single, 0xFFC85014);
      expect(result.average, 0xFFC85014);
    });

    test('the colour there is most of comes first', () {
      // A sunset: mostly orange sky, a strip of dark ground.
      final result = photoColorsFrom(pixels([(20, 20, 30, 30), (230, 120, 40, 70)]));

      expect(result.palette.first, 0xFFE67828, reason: 'the orange is most of the picture');
      expect(result.palette, hasLength(2));
    });

    test('a stray highlight is not one of the colours', () {
      // Two pixels of white in a thousand is a lens flare, and a swatch for it
      // is a swatch nobody wanted.
      final result = photoColorsFrom(pixels([(10, 40, 90, 998), (255, 255, 255, 2)]));

      expect(result.palette, hasLength(1));
    });

    test('two colours the eye cannot tell apart become one swatch', () {
      final result = photoColorsFrom(pixels([(100, 100, 100, 50), (108, 104, 102, 50)]));

      expect(result.palette, hasLength(1));
    });

    test('see-through pixels are not a colour', () {
      final buffer = Uint8List.fromList([
        ...[10, 40, 90, 255],
        ...[10, 40, 90, 255],
        ...[255, 0, 0, 0],
      ]);

      final result = photoColorsFrom(buffer);

      expect(result.palette.single, 0xFF0A285A);
    });

    test('nothing readable gives nothing rather than a wrong answer', () {
      final result = photoColorsFrom(Uint8List(0));

      expect(result.palette, isEmpty);
    });

    test('a photo never offers more swatches than a row can hold', () {
      final result = photoColorsFrom(
        pixels([
          (255, 0, 0, 100),
          (0, 255, 0, 100),
          (0, 0, 255, 100),
          (255, 255, 0, 100),
          (255, 0, 255, 100),
          (0, 255, 255, 100),
          (255, 255, 255, 100),
          (0, 0, 0, 100),
        ]),
        most: 4,
      );

      expect(result.palette, hasLength(4));
    });
  });

  group('what the text really sits on', () {
    test('with no darkening the photo is the backdrop', () {
      expect(backdropUnderOverlay(0xFFC85014, 0), 0xFFC85014);
    });

    test('a heavy overlay makes a bright photo dark', () {
      // A white photo under the default overlay is mid grey, which is why grey
      // text on it is unreadable and white text on it is fine.
      expect(backdropUnderOverlay(0xFFFFFFFF, 0.5), 0xFF808080);
    });

    test('full darkening leaves black whatever the photo was', () {
      expect(backdropUnderOverlay(0xFFFFCC00, 1), 0xFF000000);
    });
  });
}
