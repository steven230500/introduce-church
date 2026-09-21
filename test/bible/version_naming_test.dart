import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/version_naming.dart';

void main() {
  group('the code offered for a version', () {
    test('is the one churches know it by, when it is a known version', () {
      expect(suggestVersionCode('La Biblia de Las Americas'), 'LBLA');
      expect(suggestVersionCode('Nueva Biblia de las Américas'), 'NBLA');
      expect(suggestVersionCode('Nueva Versión Internacional 1999'), 'NVI');
      expect(suggestVersionCode('Traducción en Lenguaje Actual'), 'TLA');
    });

    test('carries the year of a Reina-Valera revision', () {
      expect(suggestVersionCode('Reina-Valera 1909'), 'RV1909');
      expect(suggestVersionCode('Santa Biblia Reina Valera 1960'), 'RVR1960');
      expect(suggestVersionCode('Reina Valera 1995'), 'RVR1995');
    });

    test('is the file name when the file is named with a code', () {
      expect(suggestVersionCode('rvr1960'), 'RVR1960');
      expect(suggestVersionCode('NTV'), 'NTV');
    });

    test('is what the file calls itself, when that is short enough to print', () {
      expect(suggestVersionCode('Mi Biblia', abbreviation: 'MB2020'), 'MB2020');
      // A catalogue id is not something to put under a verse.
      expect(
        suggestVersionCode('Mi Biblia', abbreviation: 'SF_2009-01-20_SPA_LBLA'),
        isNot(contains('SF')),
      );
    });

    test('falls back to initials and year', () {
      expect(suggestVersionCode('Sagradas Escrituras 1569'), 'SE1569');
      expect(suggestVersionCode('Biblia del Oso'), 'BO');
    });
  });

  test('a code is printed in capitals, letters and digits only', () {
    expect(cleanVersionCode(' lbla '), 'LBLA');
    expect(cleanVersionCode('rvr-1960'), 'RVR1960');
    expect(cleanVersionCode('Ñandú'), 'NANDU');
    expect(cleanVersionCode('una sigla demasiado larga'), 'UNASIGLADE');
  });
}
