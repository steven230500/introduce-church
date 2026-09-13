import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/song_import/imported_song.dart';
import 'package:introduce_church/core/song_import/song_files.dart';

/// Writes protobuf the way ProPresenter 7 does, for the fields the reader uses.
class _Proto {
  final _bytes = BytesBuilder();

  void _varint(int value) {
    var v = value;
    while (v >= 0x80) {
      _bytes.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _bytes.addByte(v);
  }

  _Proto bytes(int field, List<int> data) {
    _varint(field << 3 | 2);
    _varint(data.length);
    _bytes.add(data);
    return this;
  }

  _Proto string(int field, String value) => bytes(field, utf8.encode(value));
  _Proto message(int field, _Proto value) => bytes(field, value.build());
  _Proto number(int field, int value) {
    _varint(field << 3);
    _varint(value);
    return this;
  }

  Uint8List build() => _bytes.toBytes();
}

_Proto _uuid(String id) => _Proto().string(1, id);

/// A cue whose slide says [rtf], with a note the congregation must not see.
_Proto _cue(String id, String rtf) => _cueBytes(id, latin1.encode(rtf));

_Proto _cueBytes(String id, List<int> rtf) => _Proto()
    .message(1, _uuid(id))
    .message(
      10,
      _Proto().message(
        23,
        _Proto().message(
          2,
          _Proto()
              .message(
                1,
                _Proto().message(
                  1,
                  _Proto().message(
                    1,
                    _Proto().string(2, 'Letra').message(13, _Proto().bytes(5, rtf)),
                  ),
                ),
              )
              .message(2, _Proto().bytes(1, latin1.encode(r'{\rtf1 NOTA PARA EL EQUIPO}'))),
        ),
      ),
    );

_Proto _group(String id, String name, List<String> cues) =>
    _Proto().message(1, _Proto().message(1, _uuid(id)).string(2, name)).also((g) {
      for (final cue in cues) {
        g.message(2, _uuid(cue));
      }
    });

extension on _Proto {
  _Proto also(void Function(_Proto) f) {
    f(this);
    return this;
  }
}

String rtf(String text) =>
    '{\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\fs120 ${text.replaceAll('\n', '\\\n')}}';

ImportedSong read(String path, List<int> bytes) {
  final result = readSongBytes(path, Uint8List.fromList(bytes));
  expect(result.failure, isNull, reason: 'failed: ${result.failure?.problem}');
  return result.song!;
}

void main() {
  test('ProPresenter 7: groups, the chosen arrangement, and the CCLI details', () {
    final doc = _Proto()
        .string(3, 'grande es tu fidelidad (nombre del archivo)')
        .message(10, _uuid('arr-live'))
        .message(
          11,
          _Proto().message(1, _uuid('arr-short')).string(2, 'Corta').message(3, _uuid('g-v1')),
        )
        .message(
          11,
          _Proto()
              .message(1, _uuid('arr-live'))
              .string(2, 'En vivo')
              .message(3, _uuid('g-v1'))
              .message(3, _uuid('g-c'))
              .message(3, _uuid('g-v2'))
              .message(3, _uuid('g-c')),
        )
        .message(12, _group('g-v1', 'Verse 1', ['cue-1', 'cue-2']))
        .message(12, _group('g-c', 'Chorus', ['cue-3']))
        .message(12, _group('g-v2', 'Verse 2', ['cue-4']))
        .message(13, _cue('cue-1', rtf('Oh Dios eterno\ntu misericordia')))
        .message(13, _cue('cue-2', rtf('ni una sombra')))
        .message(13, _cue('cue-3', rtf("Grande es tu fidelidad")))
        .message(13, _cue('cue-4', rtf('La noche oscura')))
        .message(
          14,
          _Proto()
              .string(1, 'Thomas O. Chisholm')
              .string(3, 'Grande Es Tu Fidelidad')
              .string(4, 'Hope Publishing Company')
              .number(5, 1923)
              .number(6, 18723),
        )
        .build();

    final song = read('/lib/Grande.pro', doc);

    expect(song.format, SongFormat.proPresenter7);
    expect(song.title, 'Grande Es Tu Fidelidad');
    expect(song.author, 'Thomas O. Chisholm');
    expect(song.copyright, '© 1923 Hope Publishing Company');
    expect(song.ccliNumber, '18723');
    // The live arrangement, chorus repeated; the slide notes nowhere.
    expect(song.verses.map((v) => v.content), [
      'Oh Dios eterno\ntu misericordia',
      'ni una sombra',
      'Grande es tu fidelidad',
      'La noche oscura',
      'Grande es tu fidelidad',
    ]);
    expect(song.verses.map((v) => v.type), [
      VerseType.verse,
      VerseType.verse,
      VerseType.chorus,
      VerseType.verse,
      VerseType.chorus,
    ]);
    expect(song.verses.any((v) => v.content.contains('NOTA')), isFalse);
  });

  test('ProPresenter 7: a publisher written with its year, and UTF-8 straight in the RTF', () {
    // RTF is meant to escape everything past ASCII. ProPresenter does; files
    // written by other tools put UTF-8 in as it is, next to the escapes.
    final doc = _Proto()
        .message(12, _group('g', 'Verse', ['c1']))
        .message(13, _cueBytes('c1', utf8.encode("{\\rtf1\\ansi Se\\'f1or\\\ncuán grande}")))
        .message(14, _Proto().string(3, 'Oceans').string(4, '2012 Hillsong Music').number(5, 2012))
        .build();

    final song = read('/lib/oceans.pro', doc);

    expect(song.copyright, '© 2012 Hillsong Music');
    expect(song.verses.single.content, 'Señor\ncuán grande');
  });

  test('ProPresenter 7 without CCLI details takes its name', () {
    final doc = _Proto()
        .string(3, 'Cuán Grande Es Él')
        .message(12, _group('g', 'Coro', ['c1']))
        .message(13, _cue('c1', rtf('Señor mi Dios')))
        .build();

    final song = read('/lib/x.pro', doc);
    expect(song.title, 'Cuán Grande Es Él');
    expect(song.ccliNumber, isNull);
    expect(song.verses.single, const ImportedVerse(VerseType.chorus, 'Señor mi Dios'));
  });

  test('ProPresenter 6: plain text beside the RTF, and the arrangement', () {
    String b64(String s) => base64.encode(utf8.encode(s));
    final xml =
        '''<?xml version="1.0" encoding="utf-8"?>
<RVPresentationDocument height="1080" width="1920" CCLISongTitle="Cornerstone" CCLIAuthor="Edward Mote"
    CCLIPublisher="Hillsong" CCLICopyrightYear="2011" CCLISongNumber="6158927" selectedArrangementID="A1">
  <array rvXMLIvarName="groups">
    <RVSlideGrouping name="Verse 1" uuid="G1">
      <array rvXMLIvarName="slides">
        <RVDisplaySlide UUID="S1"><array rvXMLIvarName="displayElements">
          <RVTextElement><NSString rvXMLIvarName="PlainText">${b64('My hope is built\non nothing less')}</NSString>
          <NSString rvXMLIvarName="RTFData">${b64(r'{\rtf1 ignored}')}</NSString></RVTextElement>
        </array></RVDisplaySlide>
      </array>
    </RVSlideGrouping>
    <RVSlideGrouping name="Chorus" uuid="G2">
      <array rvXMLIvarName="slides">
        <RVDisplaySlide UUID="S2"><array rvXMLIvarName="displayElements">
          <RVTextElement><NSString rvXMLIvarName="RTFData">${b64(r'{\rtf1\ansi Christ alone\par Cornerstone}')}</NSString></RVTextElement>
        </array></RVDisplaySlide>
      </array>
    </RVSlideGrouping>
  </array>
  <array rvXMLIvarName="arrangements">
    <RVSongArrangement name="Default" uuid="A1">
      <array rvXMLIvarName="groupIDs"><NSMutableString>G2</NSMutableString><NSMutableString>G1</NSMutableString><NSMutableString>G2</NSMutableString></array>
    </RVSongArrangement>
  </array>
</RVPresentationDocument>''';

    final song = read('/lib/Cornerstone.pro6', utf8.encode(xml));

    expect(song.format, SongFormat.proPresenter6);
    expect(song.title, 'Cornerstone');
    expect(song.copyright, '© 2011 Hillsong');
    expect(song.ccliNumber, '6158927');
    expect(song.verses.map((v) => v.content), [
      'Christ alone\nCornerstone',
      'My hope is built\non nothing less',
      'Christ alone\nCornerstone',
    ]);
  });

  test('OpenLyrics from OpenLP: chords out, verse order spelled out, first language only', () {
    const xml = '''<?xml version='1.0' encoding='UTF-8'?>
<song xmlns="http://openlyrics.info/namespace/2009/song" version="0.9" createdIn="OpenLP 3.0">
  <properties>
    <titles><title>Sublime Gracia</title><title lang="en">Amazing Grace</title></titles>
    <authors><author type="words">John Newton</author><author type="music">Tradicional</author></authors>
    <copyright>Dominio público</copyright>
    <ccliNo>22025</ccliNo>
    <verseOrder>v1 c v2 c</verseOrder>
  </properties>
  <lyrics>
    <verse name="v1" lang="es">
      <lines>Sublime <chord root="G"/>gracia del Señor<br/>que a <chord root="D">mí</chord> pecador salvó</lines>
    </verse>
    <verse name="v1" lang="en"><lines>Amazing grace</lines></verse>
    <verse name="c" lang="es"><lines><comment>suave</comment>Fui ciego mas hoy veo yo</lines></verse>
    <verse name="v2" lang="es">
      <lines>
        Su gracia me enseñó a temer
      </lines>
    </verse>
  </lyrics>
</song>''';

    final song = read('/lib/sublime.xml', utf8.encode(xml));

    expect(song.format, SongFormat.openLyrics);
    expect(song.title, 'Sublime Gracia');
    expect(song.author, 'John Newton, Tradicional');
    expect(song.copyright, 'Dominio público');
    expect(song.ccliNumber, '22025');
    expect(song.verses.map((v) => v.content), [
      'Sublime gracia del Señor\nque a mí pecador salvó',
      'Fui ciego mas hoy veo yo',
      'Su gracia me enseñó a temer',
      'Fui ciego mas hoy veo yo',
    ]);
    expect(song.verses[1].type, VerseType.chorus);
  });

  test('SongSelect .usr', () {
    const usr =
        '[File]\r\nType=SongSelect Import File\r\nVersion=3.0\r\n[S A18723]\r\n'
        'Title=Grande Es Tu Fidelidad\r\nAuthor=Thomas O. Chisholm | William M. Runyan\r\n'
        'Copyright=© 1923. Ren. 1951 Hope Publishing Company\r\nAdmin=Hope Publishing\r\nKeys=D\r\n'
        'Fields=Estrofa 1/tCoro\r\n'
        'Words=Oh Dios eterno/ntu misericordia/tGrande es tu fidelidad/nGrande es tu fidelidad\r\n';

    final song = read('/lib/grande.usr', utf8.encode(usr));

    expect(song.format, SongFormat.songSelect);
    expect(song.author, 'Thomas O. Chisholm, William M. Runyan');
    expect(song.ccliNumber, '18723');
    expect(song.verses, const [
      ImportedVerse(VerseType.verse, 'Oh Dios eterno\ntu misericordia'),
      ImportedVerse(VerseType.chorus, 'Grande es tu fidelidad\nGrande es tu fidelidad'),
    ]);
  });

  test('SongSelect text download, in UTF-16 the way Windows saves it', () {
    const text =
        'Cuán Grande Es Él\n\nVerse 1\nSeñor mi Dios al contemplar los cielos\nEl firmamento\n\n'
        'Chorus\nMi corazón entona la canción\n\nCCLI Song # 14181\nStuart K. Hine\n'
        '© 1953 The Stuart Hine Trust\nFor use solely with the SongSelect® Terms of Use. All rights reserved.\n'
        'CCLI License # 1234567\n';
    final units = [
      0xFF,
      0xFE,
      for (final u in text.codeUnits) ...[u & 0xFF, u >> 8],
    ];

    final song = read('/lib/cuan.txt', units);

    expect(song.format, SongFormat.songSelect);
    expect(song.title, 'Cuán Grande Es Él');
    expect(song.author, 'Stuart K. Hine');
    expect(song.copyright, '© 1953 The Stuart Hine Trust');
    expect(song.ccliNumber, '14181');
    expect(song.verses.map((v) => v.type), [VerseType.verse, VerseType.chorus]);
    expect(song.verses.first.content, 'Señor mi Dios al contemplar los cielos\nEl firmamento');
  });

  test('ChordPro, including a .pro that is text and not ProPresenter', () {
    const cho =
        '{title: Renuévame}\n{artist: Marcos Witt}\n{ccli: 1234}\n\n'
        '[G]Renuéva[D]me Señor Jesús\n[Em]ya no quiero ser igual\n\n'
        '{start_of_chorus}\nPon en [C]mí tu corazón\n{end_of_chorus}\n\n[Puente]\n[G] [D]\nSolo tú\n';

    for (final path in ['/lib/renuevame.cho', '/lib/renuevame.pro']) {
      final song = read(path, utf8.encode(cho));
      expect(song.format, SongFormat.chordPro, reason: path);
      expect(song.title, 'Renuévame');
      expect(song.ccliNumber, '1234');
      expect(song.verses, const [
        ImportedVerse(VerseType.verse, 'Renuévame Señor Jesús\nya no quiero ser igual'),
        ImportedVerse(VerseType.chorus, 'Pon en mí tu corazón'),
        ImportedVerse(VerseType.bridge, 'Solo tú'),
      ]);
    }
  });

  test('plain text in Latin-1, with a title line and labels', () {
    final text =
        'Al Que Está Sentado\n\nCoro\nAl que está sentado en el trono\n\nVerso 1\nDigno eres\n';

    final song = read('/lib/al que esta.txt', latin1.encode(text));

    expect(song.format, SongFormat.plainText);
    expect(song.title, 'Al Que Está Sentado');
    expect(song.verses, const [
      ImportedVerse(VerseType.chorus, 'Al que está sentado en el trono'),
      ImportedVerse(VerseType.verse, 'Digno eres'),
    ]);
  });

  test('plain text with no title line is named after its file', () {
    final song = read(
      '/lib/Te Alabaré.txt',
      utf8.encode('Te alabaré\nte bendeciré\n\nCon todo mi ser\n'),
    );

    expect(song.title, 'Te Alabaré');
    expect(song.verses, hasLength(2));
  });

  test('ProPresenter 4: slides with no groups', () {
    String b64(String s) => base64.encode(utf8.encode(s));
    final xml =
        '<?xml version="1.0"?><RVPresentationDocument versionNumber="401" artist="John Newton">'
        '<slides><RVDisplaySlide><displayElements>'
        '<RVTextElement RTFData="${b64(r'{\rtf1\ansi{\fonttbl{\f0 Georgia;}}\f0 Sublime gracia\par}')}"/>'
        '</displayElements></RVDisplaySlide></slides></RVPresentationDocument>';

    final song = read('/lib/Sublime.pro4', utf8.encode(xml));

    expect(song.author, 'John Newton');
    expect(song.verses.single.content, 'Sublime gracia');
  });

  test('SongSelect since 2023: the authors above the number', () {
    const text =
        'Renuévame\n\n\nVerse 1\nRenuévame Señor Jesús\n\n'
        'Marcos Witt\nCCLI Song #123456\n© 1990 CanZion\n'
        'For use solely with the SongSelect® Terms of Use.  All rights reserved.\nCCLI License #00000\n';

    final song = read('/lib/renuevame.txt', utf8.encode(text));

    expect(song.author, 'Marcos Witt');
    expect(song.copyright, '© 1990 CanZion');
    expect(song.ccliNumber, '123456');
    expect(
      song.verses.single.content,
      'Renuévame Señor Jesús',
      reason: 'the authors are not lyrics',
    );
  });

  test('SongSelect .bin is read; any other .bin is not a song', () {
    const usr =
        '[File]\nType=SongSelect Import File\n[S A1]\nTitle=Tu fidelidad\nFields=Coro\nWords=Tu fidelidad\n';
    expect(read('/lib/x.bin', utf8.encode(usr)).title, 'Tu fidelidad');
    expect(
      readSongBytes('/lib/firmware.bin', Uint8List.fromList([0, 1, 2, 3])).failure?.problem,
      SongFileProblem.unsupported,
    );
  });

  test('ChordPro: {c: Chorus} alone between verses sings the chorus again', () {
    const cho =
        '{title: Cristo vive}\n\n{soc}\nCristo [D]vive\n{eoc}\n\nPrimera estrofa\n\n{c: Coro}\n\n'
        'Segunda estrofa\n{c: Coro}\n';

    final song = read('/lib/vive.chordpro', utf8.encode(cho));

    expect(song.verses, const [
      ImportedVerse(VerseType.chorus, 'Cristo vive'),
      ImportedVerse(VerseType.verse, 'Primera estrofa'),
      ImportedVerse(VerseType.chorus, 'Cristo vive'),
      ImportedVerse(VerseType.verse, 'Segunda estrofa'),
      ImportedVerse(VerseType.chorus, 'Cristo vive'),
    ]);
  });

  test('ChordPro: {c: Coro} right above words labels them', () {
    const cho = '{title: Santo}\n{c: Coro}\nSanto santo santo\n';
    expect(read('/lib/santo.cho', utf8.encode(cho)).verses.single.type, VerseType.chorus);
  });

  test('older OpenLyrics with the chords written into the words', () {
    const xml =
        '<?xml version="1.0"?><song xmlns="http://openlyrics.info/namespace/2009/song" version="0.8">'
        '<properties><titles><title>Espíritu Santo</title></titles></properties><lyrics>'
        '<verse name="v1"><lines><tag name="c">[D]</tag>Espíritu <tag name="c">[Ami]</tag>ven</lines></verse>'
        '</lyrics></song>';

    expect(read('/lib/espiritu.xml', utf8.encode(xml)).verses.single.content, 'Espíritu ven');
  });

  test('what cannot be read says why', () {
    SongFileProblem? problem(String path, List<int> bytes) =>
        readSongBytes(path, Uint8List.fromList(bytes)).failure?.problem;

    expect(problem('/x/foto.jpg', [0xFF, 0xD8, 0xFF]), SongFileProblem.unsupported);
    expect(
      problem('/x/roto.pro', [0x0A, 0xFF, 0xFF, 0xFF, 0x01, 0x02]),
      SongFileProblem.unreadable,
    );
    // Text, but not ChordPro: a damaged ProPresenter file, not a one-slide song.
    expect(problem('/x/roto.pro', utf8.encode('basura')), SongFileProblem.unreadable);
    expect(problem('/x/vacio.txt', utf8.encode('\n\n  \n')), SongFileProblem.empty);
    expect(
      problem('/x/otro.xml', utf8.encode('<?xml version="1.0"?><playlist/>')),
      SongFileProblem.unreadable,
    );
  });
}
