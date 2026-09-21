import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/song.dart';
import 'package:introduce_church/core/song_import/imported_song.dart';
import 'package:introduce_church/core/utils/rtf.dart';
import 'package:introduce_church/core/song_import/section_names.dart';

void main() {
  group('RTF', () {
    test('what ProPresenter on a Mac writes', () {
      const rtf = r'''{\rtf1\ansi\ansicpg1252\cocoartf2639
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;\red255\green255\blue255;}
{\*\expandedcolortbl;;\csgenericrgb\c100000\c100000\c100000;}
\deftab1680
\pard\pardeftab1680\pardirnatural\qc\partightenfactor0

\f0\fs120 \cf2 Oh Dios eterno, tu misericordia\
ni una sombra de duda tendr\uc0\u225 }''';

      expect(
        tidyLyrics(rtfToText(rtf)),
        'Oh Dios eterno, tu misericordia\nni una sombra de duda tendrá',
      );
    });

    test('what ProPresenter on Windows writes', () {
      const rtf = r'''{\rtf1\ansi\ansicpg1252\deff0\nouicompat{\fonttbl{\f0\fnil\fcharset0 Arial;}}
{\colortbl ;\red255\green255\blue255;}
{\*\generator Riched20 10.0.19041}\viewkind4\uc1
\pard\qc\cf1\f0\fs120\lang3082 Cu\'e1n grande es \'c9l\par
Se\'f1or, mi Dios\par
}''';

      expect(tidyLyrics(rtfToText(rtf)), 'Cuán grande es Él\nSeñor, mi Dios');
    });

    test('escaped braces and quotes survive; the header does not leak', () {
      expect(
        tidyLyrics(rtfToText(r'{\rtf1{\fonttbl{\f0 Arial;}}\ldblquote Santo\rdblquote  \{x\}}')),
        '“Santo” {x}',
      );
    });
  });

  group('section labels', () {
    test('in the languages the files come in', () {
      final cases = {
        'Verse 1': VerseType.verse,
        'Estrofa 2': VerseType.verse,
        'Verso': VerseType.verse,
        'Chorus': VerseType.chorus,
        'CORO': VerseType.chorus,
        'Coro 2': VerseType.chorus,
        'Refrão': VerseType.chorus,
        'Coro x2': VerseType.chorus,
        'Pre-Chorus': VerseType.preCHORUS,
        'Pre coro': VerseType.preCHORUS,
        'Precoro': VerseType.preCHORUS,
        'Puente': VerseType.bridge,
        'Bridge 2': VerseType.bridge,
        'Intro': VerseType.intro,
        'Introducción': VerseType.intro,
        'Ending': VerseType.outro,
        'Tag': VerseType.tag,
        '[Chorus]': VerseType.chorus,
        'Coro:': VerseType.chorus,
      };
      for (final entry in cases.entries) {
        expect(sectionType(entry.key), entry.value, reason: entry.key);
      }
    });

    test('a line of lyrics is not a label', () {
      for (final line in [
        'Cuán grande es Él',
        'Verso a verso te alabaré',
        'Coro de ángeles canta',
      ]) {
        expect(sectionType(line), isNull, reason: line);
      }
    });

    test('a name the operator made up is still a slide', () {
      expect(sectionTypeOr('Coro final lento'), VerseType.chorus);
      expect(sectionTypeOr('Blank'), VerseType.verse);
    });
  });
}
