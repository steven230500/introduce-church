import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/utils/fuzzy_match.dart';

void main() {
  group('finding what was typed', () {
    test('the beginning of a name is the best kind of match', () {
      expect(matchScore('nada', 'NADA ES IMPOSIBLE'), isNotNull);
    });

    test('accents are not how anyone types in a hurry', () {
      // The operator is mid-service. Nobody reaches for the accent key.
      expect(matchScore('cancion', 'Canción nueva'), isNotNull);
      expect(matchScore('CANCIÓN', 'cancion nueva'), isNotNull);
    });

    test('a word in the middle still counts', () {
      expect(matchScore('imposible', 'NADA ES IMPOSIBLE'), isNotNull);
    });

    test('words in any order find the name', () {
      expect(matchScore('imposible nada', 'NADA ES IMPOSIBLE'), isNotNull);
    });

    test('initials find a long title', () {
      expect(matchScore('nei', 'Nada Es Imposible'), isNotNull);
    });

    test('something that is not there does not match', () {
      expect(matchScore('bautismo', 'NADA ES IMPOSIBLE'), isNull);
    });

    test('an empty query matches everything, so the list shows as it is', () {
      expect(matchScore('', 'lo que sea'), isNotNull);
    });
  });

  group('which one comes first', () {
    List<String> ranked(String query, List<String> names) =>
        rankByMatch(query, names, (name) => name);

    test('a name that starts with the query beats one that contains it', () {
      expect(ranked('coro', ['Sin coro alguno', 'Coro de ángeles']), [
        'Coro de ángeles',
        'Sin coro alguno',
      ]);
    });

    test('the start of a word beats the middle of one', () {
      // "cor" is a deliberate match on "Cordero" and an accident inside
      // "Incorruptible".
      expect(ranked('cor', ['Incorruptible', 'Grande es el Cordero']), [
        'Grande es el Cordero',
        'Incorruptible',
      ]);
    });

    test('the shorter of two equally good matches comes first', () {
      // Typing "santo" and getting a six-word title before "Santo" is the
      // kind of thing that makes people stop using the search.
      expect(ranked('santo', ['Santo santo santo es el Señor', 'Santo']), [
        'Santo',
        'Santo santo santo es el Señor',
      ]);
    });

    test('what does not match is left out, not sorted to the bottom', () {
      expect(ranked('coro', ['Coro', 'Salmo 23']), ['Coro']);
    });

    test('an empty query keeps the order it was given', () {
      // The library arrives sorted by name; a search box nobody has typed in
      // must not shuffle it.
      expect(ranked('', ['Bautizados', 'Alfa', 'Coro']), ['Bautizados', 'Alfa', 'Coro']);
    });

    test('ties keep the order they came in', () {
      expect(ranked('a', ['Alfa', 'Amor']), ['Alfa', 'Amor']);
    });
  });

  group('folding for comparison', () {
    test('drops accents and case', () {
      expect(foldForSearch('Génesis'), 'genesis');
      expect(foldForSearch('AÑO'), 'ano');
    });

    test('collapses the spaces somebody typed twice', () {
      expect(foldForSearch('  1   Juan '), '1 juan');
    });
  });
}
