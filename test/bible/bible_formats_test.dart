import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/bible_import/bible_files.dart';
import 'package:introduce_church/core/bible_import/imported_bible.dart';
import 'package:sqlite3/sqlite3.dart';

ImportedBible read(String path, List<int> bytes) {
  final result = readBibleBytes(path, Uint8List.fromList(bytes));
  expect(result.failure, isNull, reason: 'expected $path to read');
  return result.bible!;
}

/// A SQLite Bible written the way [build] says, as the bytes of its file.
List<int> sqliteFile(void Function(Database db) build) {
  final dir = Directory.systemTemp.createTempSync('bible_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  final path = '${dir.path}/bible.db';
  final db = sqlite3.open(path);
  build(db);
  db.close();
  return File(path).readAsBytesSync();
}

void main() {
  test('USFX, as eBible publishes it: milestones, Strong\'s words, headings left out', () {
    final bible = read(
      '/descargas/spaRV1909_usfx.xml',
      utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<usfx><languageCode>spa</languageCode>
<book id="GEN"><id id="GEN"> Genesis</id><h>Génesis</h><p sfm="mt">Génesis</p>
<c id="1" /><p>
<v id="1" /><w s="H7225">En el principio</w> <w s="H1254">crió</w> Dios los cielos.<f>nota</f>
<ve /><v id="2" />Y la tierra <add>estaba</add> desordenada.
<ve /></p></book>
<book id="JON"><c id="1" /><p><v id="17" /></p><c id="2" /><p><v id="1" />Mas Jehová había prevenido un gran pez.<ve /></p></book>
</usfx>'''),
    );
    expect(bible.format, BibleFormat.usfx);
    expect(bible.title, 'RV1909', reason: "eBible's name, without the language and the format");
    expect(bible.books[0]![0], [
      'En el principio crió Dios los cielos.',
      'Y la tierra estaba desordenada.',
    ]);
    expect(bible.books[31]![1][0], 'Mas Jehová había prevenido un gran pez.');
    expect(bible.books[31]![0], everyElement(isEmpty), reason: 'a verse marker with no words');
  });

  test('USFM, one file per book in a zip, read together', () {
    final archive = Archive();
    void add(String name, String text) {
      final bytes = utf8.encode(text);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('01-GENspa.usfm', r'''\id GEN Reina-Valera
\h Génesis
\mt1 Génesis
\c 1
\s1 La creación
\p
\v 1 \w En el principio|strong="H7225"\w* crió Dios\f + \fr 1.1 \ft nota\f* los cielos.
\v 2 Y la tierra
\q1 estaba desordenada.
''');
    add('44-JHNspa.usfm', r'''\id JHN
\c 3
\v 16 Porque de tal manera amó Dios \x - \xo 3.16 \xt Ro 5.8\x* al mundo.
''');
    add('LEEME.txt', 'hola');
    final bible = read('/descargas/spaRV1909_usfm.zip', ZipEncoder().encode(archive)!);

    expect(bible.format, BibleFormat.usfm);
    expect(bible.books[0]![0], [
      'En el principio crió Dios los cielos.',
      'Y la tierra estaba desordenada.',
    ]);
    expect(bible.books[42]![2][15], 'Porque de tal manera amó Dios al mundo.');
  });

  test('MySword: a Bible table with GBF markup, and Details naming it', () {
    final bible = read(
      '/descargas/LBLA.bbl.mybible',
      sqliteFile((db) {
        db.execute('create table Bible (Book int, Chapter int, Verse int, Scripture text)');
        db.execute('create table Details (Title text, Abbreviation text, Description text)');
        db.execute("insert into Details values ('La Biblia de las Américas', 'LBLA', '')");
        db.execute(
          "insert into Bible values (43, 3, 16, '<TS>El amor de Dios<Ts>Porque de tal manera amó Dios<RF>nota<Rf> al <FI>mundo<Fi><WG2889>')",
        );
        db.execute("insert into Bible values (67, 1, 1, 'Tobías')");
      }),
    );
    expect(bible.format, BibleFormat.mySword);
    expect(bible.title, 'La Biblia de las Américas');
    expect(bible.abbreviation, 'LBLA');
    expect(bible.books[42]![2][15], 'Porque de tal manera amó Dios al mundo');
    expect(bible.skippedBooks, 1);
  });

  test('e-Sword: the same table with RTF, Strong\'s numbers in superscript groups', () {
    final bible = read(
      '/descargas/rv60.bblx',
      sqliteFile((db) {
        db.execute('create table Bible (Book int, Chapter int, Verse int, Scripture text)');
        db.execute(
          r"insert into Bible values (19, 23, 1, 'Jehová es mi pastor;{\cf11\super H7462} nada me faltará.\par')",
        );
      }),
    );
    expect(bible.format, BibleFormat.eSword);
    expect(bible.title, 'rv60');
    expect(bible.books[18]![22][0], 'Jehová es mi pastor; nada me faltará.');
  });

  test('MyBible: its own book numbers, notes and Strong\'s numbers out', () {
    final bible = read(
      '/descargas/NVI.SQLite3',
      sqliteFile((db) {
        db.execute('create table verses (book_number int, chapter int, verse int, text text)');
        db.execute('create table info (name text, value text)');
        db.execute("insert into info values ('description', 'Nueva Versión Internacional')");
        db.execute(
          "insert into verses values (500, 3, 16, 'Porque tanto amó<S>25</S> Dios al mundo<f>[1]</f>')",
        );
        db.execute(
          "insert into verses values (10, 1, 1, 'Dios, en el principio,<br/>creó los cielos')",
        );
      }),
    );
    expect(bible.format, BibleFormat.myBible);
    expect(bible.title, 'Nueva Versión Internacional');
    expect(bible.books[42]![2][15], 'Porque tanto amó Dios al mundo');
    expect(bible.books[0]![0][0], 'Dios, en el principio, creó los cielos');
  });

  test('a MyBible books table is believed over the usual numbers', () {
    final bible = read(
      '/descargas/raro.SQLite3',
      sqliteFile((db) {
        db.execute('create table verses (book_number int, chapter int, verse int, text text)');
        db.execute('create table books (book_number int, short_name text, long_name text)');
        db.execute("insert into books values (999, 'Jn', 'Juan')");
        db.execute("insert into verses values (999, 1, 1, 'En el principio era el Verbo')");
      }),
    );
    expect(bible.books[42]![0][0], 'En el principio era el Verbo');
  });

  test('a database that is not a Bible says so', () {
    final result = readBibleBytes(
      '/descargas/otra.sqlite',
      Uint8List.fromList(sqliteFile((db) => db.execute('create table cosas (x int)'))),
    );
    expect(result.failure?.problem, BibleFileProblem.unreadable);
  });

  test('names from files', () {
    expect(bibleNameFromFile('/x/spaRV1909_usfx.xml'), 'RV1909');
    expect(
      bibleNameFromFile('/x/engwebp_usfm.zip'),
      'engwebp',
      reason: 'a lower-case name is kept whole',
    );
    expect(bibleNameFromFile('/x/La_Biblia_de_Las_Americas.xml'), 'La Biblia de Las Americas');
    expect(bibleNameFromFile('/x/LBLA.bbl.mybible'), 'LBLA');
    expect(bibleNameFromFile('/x/World_English_Bible.xml'), 'World English Bible');
  });

  test('what language a Bible is in: from the file, or from its words', () {
    final usfx = read(
      '/x/engwebp_usfx.xml',
      utf8.encode(
        '<usfx><languageCode>eng</languageCode><book id="JHN"><c id="3"/>'
        '<v id="16"/>For God so loved the world.<ve/></book></usfx>',
      ),
    );
    expect(usfx.language, 'en');

    final unmarked = read(
      '/x/biblia.xml',
      utf8.encode(
        '<XMLBIBLE><BIBLEBOOK bnumber="43"><CHAPTER cnumber="3">'
        '<VERS vnumber="16">Porque de tal manera amó Dios al mundo, que ha dado á su Hijo</VERS>'
        '</CHAPTER></BIBLEBOOK></XMLBIBLE>',
      ),
    );
    expect(unmarked.language, isNull);
    expect(unmarked.probableLanguage, 'es');
  });
}
