import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/local_db/bible_reference.dart';
import 'package:introduce_church/core/local_db/bible_repository.dart' show spanishBookName;

void main() {
  _suggestions();
  _inRunningText();
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

    test('an English name, for the church that reads the English Bible', () {
      expect(read('john 3:16')?.bookIndex, 42);
      expect(read('Psalm 23')?.bookIndex, 18);
      expect(read('Revelation 1:8')?.bookIndex, 65);
      expect(read('1 Corinthians 13:4')?.bookIndex, 45);
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

void _suggestions() {
  group('offering the books a half-typed name could be', () {
    test('"cor" is not a book, and offers the two it could be', () {
      // The books are "1 Corintios" and "2 Corintios", so a prefix match finds
      // neither, and the operator is left with nothing.
      expect(matchBooks('cor'), isEmpty);
      expect(booksMatching('cor').map(spanishBookName), ['1 Corintios', '2 Corintios']);
    });

    test('a name that is already a book offers only that one', () {
      expect(booksMatching('juan').map(spanishBookName), ['Juan']);
      expect(booksMatching('jn').map(spanishBookName), ['Juan']);
    });

    test('a single letter offers nothing, since it would offer everything', () {
      expect(booksMatching('j'), matchBooks('j'));
      expect(booksMatching(''), isEmpty);
    });
  });
}

void _inRunningText() {
  List<String> found(String text) => [for (final f in findBibleReferences(text)) '${f.reference}'];

  group('references in someone\'s notes', () {
    test('inside a sentence, in brackets, with an abbreviation', () {
      expect(found('La fe agrada a Dios (He 11:6)'), ['Hebreos 11:6']);
      expect(found('Como dice Juan 3:16, de tal manera amó'), ['Juan 3:16']);
      expect(found('Mt. 5:3-12 y Lc 6:20'), ['Mateo 5:3-12', 'Lucas 6:20']);
    });

    test('numbered books, with the number in digits, glued or in Roman numerals', () {
      expect(found('1 Corintios 13:4-7'), ['1 Corintios 13:4-7']);
      expect(found('1Co 13:13'), ['1 Corintios 13:13']);
      expect(found('II Timoteo 3:16'), ['2 Timoteo 3:16']);
      expect(found('lee III Juan 1:2'), ['3 Juan 1:2']);
    });

    test('more of the same book after a semicolon', () {
      expect(found('Romanos 8:28; 12:1-2'), ['Romanos 8:28', 'Romanos 12:1-2']);
    });

    test('a whole chapter only by its book\'s name', () {
      expect(found('Salmo 23'), ['Salmos 23']);
      expect(found('Hebreos 11'), ['Hebreos 11']);
      // A short abbreviation and a number are too easy to meet in a sentence.
      expect(found('am 5'), isEmpty);
    });

    test('what only looks like one', () {
      expect(found('a las 10:30 en punto'), isEmpty);
      expect(found('la 3:16'), isEmpty, reason: 'not Lamentaciones');
      expect(found('Punto 1: la fe'), isEmpty);
      expect(found('1. La fe es certeza'), isEmpty);
      expect(found('versión 2:0'), isEmpty);
    });

    test('where each one is, so the rest of the line can be read', () {
      final hit = findBibleReferences('Texto: Juan 3:16').single;

      expect(hit.start, 7);
      expect(hit.end, 16);
    });
  });
}
