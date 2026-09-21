import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/bible_files.dart';
import 'package:introduce_church/core/bible_import/imported_bible.dart';

BibleFileResult read(String path, String text) =>
    readBibleBytes(path, Uint8List.fromList(utf8.encode(text)));

ImportedBible bible(String path, String text) {
  final result = read(path, text);
  expect(result.failure, isNull, reason: 'expected $path to read');
  return result.bible!;
}

const _zefania = '''<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE biblename="Biblia de prueba">
  <INFORMATION>
    <title>La Biblia de las Américas</title>
    <identifier>LBLA</identifier>
  </INFORMATION>
  <BIBLEBOOK bnumber="1" bname="Génesis">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">
 En el principio creó Dios los cielos y la tierra. </VERS>
      <VERS vnumber="3">Entonces dijo Dios: <STYLE fs="italic">Sea</STYLE> la luz.<NOTE>nota al pie</NOTE></VERS>
    </CHAPTER>
  </BIBLEBOOK>
  <BIBLEBOOK bnumber="43" bname="Juan">
    <CHAPTER cnumber="3">
      <VERS vnumber="16">Porque de tal manera<BR/>amó Dios al mundo</VERS>
    </CHAPTER>
  </BIBLEBOOK>
  <BIBLEBOOK bnumber="67" bname="Tobías">
    <CHAPTER cnumber="1"><VERS vnumber="1">Libro de Tobit.</VERS></CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>''';

void main() {
  group('Zefania', () {
    late ImportedBible read;
    setUp(() => read = bible('/descargas/lbla.xml', _zefania));

    test('takes its title and code from the INFORMATION block', () {
      expect(read.format, BibleFormat.zefania);
      expect(read.title, 'La Biblia de las Américas');
      expect(read.abbreviation, 'LBLA');
    });

    test('puts each book in its place among the 66', () {
      expect(read.books.keys, [0, 42]);
      expect(read.books[42]![2][15], 'Porque de tal manera amó Dios al mundo');
    });

    test('keeps the numbering when a verse is missing', () {
      // Verse 2 is not in the file: verse 3 must still be verse 3.
      expect(read.books[0]![0], [
        'En el principio creó Dios los cielos y la tierra.',
        '',
        'Entonces dijo Dios: Sea la luz.',
      ]);
    });

    test('leaves out footnotes, and books that are not among the 66', () {
      expect(read.books[0]![0][2], isNot(contains('nota')));
      expect(read.skippedBooks, 1);
      expect(read.missingBooks, 64);
      expect(read.verseCount, 3);
    });

    test('an empty chapter before the first one read is still a chapter', () {
      // John starts at chapter 3 in the file.
      expect(read.books[42]!.length, 3);
      expect(read.books[42]![0], isEmpty);
    });
  });

  test('drops the asterisk the LBLA puts after a verb in the historical present', () {
    final read = bible(
      '/lbla.xml',
      '<XMLBIBLE><BIBLEBOOK bnumber="43"><CHAPTER cnumber="3">'
          '<VERS vnumber="4">Nicodemo le dijo*: ¿Cómo puede un hombre nacer siendo ya viejo?</VERS>'
          '</CHAPTER></BIBLEBOOK></XMLBIBLE>',
    );
    expect(read.books[42]![2][3], 'Nicodemo le dijo: ¿Cómo puede un hombre nacer siendo ya viejo?');
  });

  group('OSIS', () {
    test('reads verses marked by start and end milestones', () {
      final read = bible('/rv1909.osis', '''<?xml version="1.0"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="RV1909">
    <header><work osisWork="RV1909"><title>Reina-Valera 1909</title></work></header>
    <div type="book" osisID="Ps">
      <chapter sID="Ps.23" osisID="Ps.23"/>
      <verse sID="Ps.23.1" osisID="Ps.23.1"/><title type="psalm">Salmo de David.</title>JEHOVÁ es mi pastor;<note>nota</note> nada me faltará.<verse eID="Ps.23.1"/>
      <title>Un encabezado</title>
      <verse sID="Ps.23.2" osisID="Ps.23.2"/><l>En lugares de delicados pastos</l><l>me hará yacer</l><verse eID="Ps.23.2"/>
      <chapter eID="Ps.23"/>
    </div>
    <div type="book" osisID="Tob"><chapter osisID="Tob.1"><verse osisID="Tob.1.1">Tobit.</verse></chapter></div>
  </osisText>
</osis>''');
      expect(read.format, BibleFormat.osis);
      expect(read.title, 'Reina-Valera 1909');
      expect(read.abbreviation, 'RV1909');
      expect(read.books[18]![22], [
        'JEHOVÁ es mi pastor; nada me faltará.',
        'En lugares de delicados pastos me hará yacer',
      ]);
      expect(read.skippedBooks, 1);
    });

    test('reads verses that are elements around their text', () {
      final read = bible(
        '/nt.xml',
        '<osis><osisText><div type="book" osisID="John"><chapter osisID="John.1">'
            '<verse osisID="John.1.1">En el principio era el Verbo</verse>'
            '</chapter></div></osisText></osis>',
      );
      expect(read.books[42]![0], ['En el principio era el Verbo']);
      expect(read.title, 'nt');
    });
  });

  test('OpenSong names its books, in English or in Spanish', () {
    final read = bible(
      '/opensong.xml',
      '<bible><b n="Genesis"><c n="1"><v n="1">In the beginning</v></c></b>'
          '<b n="I Samuel"><c n="1"><v n="1">There was a man</v></c></b>'
          '<b n="Juan"><c n="1"><v n="1">En el principio</v></c></b></bible>',
    );
    expect(read.format, BibleFormat.openSong);
    expect(read.books.keys, [0, 8, 42]);
  });

  test('Beblia numbers its books', () {
    final read = bible(
      '/beblia.xml',
      '<bible translation="Biblia Beblia"><testament name="New">'
          '<book number="43"><chapter number="3"><verse number="16">Porque de tal manera</verse>'
          '</chapter></book></testament></bible>',
    );
    expect(read.format, BibleFormat.beblia);
    expect(read.title, 'Biblia Beblia');
    expect(read.books[42]![2][15], 'Porque de tal manera');
  });

  test('FreeShow keeps numbers on everything and markup in the verse', () {
    final read = bible(
      '/nvi.fsb',
      jsonEncode({
        'name': 'Nueva Versión Internacional',
        'metadata': {'abbreviation': 'NVI'},
        'books': [
          {
            'number': 43,
            'name': 'Juan',
            'chapters': [
              {
                'number': 3,
                'verses': [
                  {'number': 16, 'text': 'Porque tanto amó Dios <i>al mundo</i>'},
                ],
              },
            ],
          },
        ],
      }),
    );
    expect(read.format, BibleFormat.freeShow);
    expect(read.abbreviation, 'NVI');
    expect(read.books[42]![2][15], 'Porque tanto amó Dios al mundo');
  });

  test('a list of 66 books is read in order', () {
    final books = [
      for (var i = 0; i < 66; i++)
        {
          'abbrev': 'b$i',
          'chapters': [
            ['libro $i'],
          ],
        },
    ];
    final read = bible('/biblia_propia.json', jsonEncode(books));
    expect(read.format, BibleFormat.bookList);
    expect(read.title, 'biblia propia');
    expect(read.missingBooks, 0);
    expect(read.books[65]![0], ['libro 65']);
  });

  test('a zipped Bible is read from the file inside', () {
    final archive = Archive()
      ..addFile(ArchiveFile('LEEME.txt', 4, utf8.encode('hola')))
      ..addFile(ArchiveFile('lbla.xml', utf8.encode(_zefania).length, utf8.encode(_zefania)));
    final result = readBibleBytes(
      '/descargas/lbla.zip',
      Uint8List.fromList(ZipEncoder().encode(archive)!),
    );
    expect(result.bible?.abbreviation, 'LBLA');
    expect(result.bible?.source, '/descargas/lbla.zip');
  });

  test('a UTF-16 file from Windows reads the same', () {
    final units = '﻿$_zefania'.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = units[i] >> 8;
    }
    final result = readBibleBytes('/lbla.xml', bytes);
    expect(result.bible?.books[42]![2][15], 'Porque de tal manera amó Dios al mundo');
  });

  group('what is not a Bible says why', () {
    test('an extension no reader knows', () {
      expect(read('/notas.txt', 'hola').failure?.problem, BibleFileProblem.unsupported);
    });

    test('an XML file of something else', () {
      expect(
        read('/cancion.xml', '<song><lyrics/></song>').failure?.problem,
        BibleFileProblem.unsupported,
      );
    });

    test('a damaged file', () {
      expect(
        read('/lbla.xml', '<XMLBIBLE><BIBLEBOOK bnumber="1"><CHAP').failure?.problem,
        BibleFileProblem.unreadable,
      );
    });

    test('a Bible with no verses in it', () {
      expect(
        read('/vacia.xml', '<XMLBIBLE><BIBLEBOOK bnumber="1"/></XMLBIBLE>').failure?.problem,
        BibleFileProblem.empty,
      );
    });
  });
}
