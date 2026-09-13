import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/bible_reference.dart';

void main() {
  BibleReference? read(String input) => parseBibleReference(input).reference;
  ReferenceProblem? problem(String input) => parseBibleReference(input).problem;

  group('what an operator types mid-sermon', () {
    test('a full name with chapter and verse', () {
      final ref = read('Juan 3:16')!;

      expect(ref.bookName, 'Juan');
      expect(ref.chapter, 3);
      expect(ref.verseStart, 16);
      expect(ref.verseEnd, 16);
    });

    test('the Spanish abbreviation, not the one in the file', () {
      // The bible file abbreviates Jonás as "jn" and Jueces as "jud", which is
      // English-derived. Handing an operator Jonás when they asked for Juan is
      // worse than not finding it.
      expect(read('jn 3:16')!.bookName, 'Juan');
      expect(read('jon 1:17')!.bookName, 'Jonás');
      expect(read('jud 1:3')!.bookName, 'Judas');
      expect(read('jue 6:12')!.bookName, 'Jueces');
    });

    test('a range', () {
      final ref = read('1 co 13:4-7')!;

      expect(ref.bookName, '1 Corintios');
      expect(ref.chapter, 13);
      expect(ref.verseStart, 4);
      expect(ref.verseEnd, 7);
    });

    test('a whole chapter', () {
      final ref = read('salmos 23')!;

      expect(ref.bookName, 'Salmos');
      expect(ref.chapter, 23);
      expect(ref.verseStart, isNull);
    });

    test('accents and capitals are not required', () {
      expect(read('exodo 20:3')!.bookName, 'Éxodo');
      expect(read('GÉNESIS 1:1')!.bookName, 'Génesis');
      expect(read('gálatas 5:22')!.bookName, 'Gálatas');
    });

    test('a dot instead of a colon, and a dash instead of a hyphen', () {
      expect(read('sal 23.1')!.verseStart, 1);
      expect(read('sal 23:1–3')!.verseEnd, 3);
    });

    test('the numbered books are told apart', () {
      expect(read('1 juan 4:8')!.bookName, '1 Juan');
      expect(read('2 juan 1:6')!.bookName, '2 Juan');
      expect(read('3jn 1:4')!.bookName, '3 Juan');
      expect(read('juan 1:1')!.bookName, 'Juan');
    });

    test('a backwards range is read as the verse that was typed first', () {
      // A typo, not a request for nothing.
      final ref = read('jn 3:16-2')!;

      expect(ref.verseStart, 16);
      expect(ref.verseEnd, 16);
    });
  });

  group('what it refuses to guess', () {
    test('a book nobody has', () {
      expect(problem('zzz 1:1'), ReferenceProblem.noBook);
    });

    test('letters that could be several books', () {
      // "j" is Josué, Jueces, Job, Joel, Jonás, Juan, Judas and more.
      expect(problem('j 1:1'), ReferenceProblem.ambiguous);
    });

    test('a book with no chapter', () {
      expect(problem('juan'), ReferenceProblem.noChapter);
    });

    test('nothing at all', () {
      expect(problem('   '), ReferenceProblem.empty);
    });
  });

  test('it reads back the way it would be shown', () {
    expect(read('jn 3:16').toString(), 'Juan 3:16');
    expect(read('1 co 13:4-7').toString(), '1 Corintios 13:4-7');
    expect(read('sal 23').toString(), 'Salmos 23');
  });
}
