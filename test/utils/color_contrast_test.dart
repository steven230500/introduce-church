import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/utils/color_contrast.dart';

void main() {
  group('reading a colour someone typed', () {
    test('takes the forms a brand guide hands out', () {
      expect(parseHexColor('#1A73E8'), 0xFF1A73E8);
      expect(parseHexColor('1a73e8'), 0xFF1A73E8);
      expect(parseHexColor('  #1A73E8  '), 0xFF1A73E8);
    });

    test('expands the three digit shorthand', () {
      expect(parseHexColor('#fff'), 0xFFFFFFFF);
      expect(parseHexColor('f00'), 0xFFFF0000);
    });

    test('takes eight digits as RRGGBBAA, which is what design tools copy', () {
      expect(parseHexColor('1A73E880'), 0x801A73E8);
    });

    test('refuses anything else rather than guessing', () {
      expect(parseHexColor('azul'), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
    });

    test('writes back what it read', () {
      expect(hexOf(0xFF1A73E8), '#1A73E8');
      expect(hexOf(0xFF000000), '#000000');
      expect(hexOf(parseHexColor('#abc')!), '#AABBCC');
    });
  });

  group('judging a pairing', () {
    test('black on white is as far apart as colours get', () {
      expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 0.1));
    });

    test('a colour against itself is as close as they get', () {
      expect(contrastRatio(0xFF1A73E8, 0xFF1A73E8), closeTo(1, 0.001));
    });

    test('the order of the two colours does not matter', () {
      expect(
        contrastRatio(0xFF1A73E8, 0xFFFFFFFF),
        closeTo(contrastRatio(0xFFFFFFFF, 0xFF1A73E8), 0.0001),
      );
    });

    test('white on black reads, grey on black does not', () {
      // The thing this exists to catch: a design that looks fine on a laptop
      // and disappears on a wall.
      expect(verdictFor(contrastRatio(0xFFFFFFFF, 0xFF000000)), ContrastVerdict.good);
      expect(verdictFor(contrastRatio(0xFF444444, 0xFF000000)), ContrastVerdict.poor);
    });

    test('every verdict says something in Spanish', () {
      for (final verdict in ContrastVerdict.values) {
        expect(verdict.label, isNotEmpty);
      }
    });
  });
}
